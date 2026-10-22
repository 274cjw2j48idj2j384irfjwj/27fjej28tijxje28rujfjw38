// Tests of server.js with an in-memory Redis: idempotent create, Discord binding, the access list of /verify, the cloud config gate.
// node tests/license_server.js
const assert = require('assert')
const Module = require('module')
const http = require('http')

const store = new Map()
class FakeRedis {
    constructor() {}
    async get(k) { return store.has(k) ? JSON.parse(JSON.stringify(store.get(k))) : null }
    async set(k, v, opts) {
        if (opts && opts.nx && store.has(k)) return null
        store.set(k, JSON.parse(JSON.stringify(v))); return 'OK'
    }
    async del(k) { store.delete(k) }
    async mget(...ks) { return ks.map(k => (store.has(k) ? store.get(k) : null)) }
}
const real = Module._load
Module._load = function (request, ...rest) {
    if (request === '@upstash/redis') return { Redis: FakeRedis }
    return real.call(this, request, ...rest)
}
process.env.ADMIN_SECRET = 'adm'
process.env.SCRIPT_SECRET = 'scr'
process.env.PORT = '0'
const { app } = require('../server.js')

let passed = 0
const test = async (name, fn) => { await fn(); passed++; console.log('ok  ' + name) }

async function main() {
    const server = http.createServer(app)
    await new Promise(r => server.listen(0, r))
    const base = 'http://127.0.0.1:' + server.address().port
    const admin = { 'x-admin-secret': 'adm', 'content-type': 'application/json' }
    const post = (path, body, headers = admin) => fetch(base + path, { method: 'POST', headers, body: JSON.stringify(body) }).then(async r => ({ status: r.status, body: await r.json() }))
    const get = (path, headers) => fetch(base + path, { headers }).then(async r => ({ status: r.status, body: await r.json() }))
    const A = '111111111111111111', B = '222222222222222222'

    await test('create needs the admin secret', async () => {
        assert.strictEqual((await post('/admin/create', { plan: 'specter' }, {})).status, 403)
    })

    let key1
    await test('create with a ref is idempotent: the same ref gives the same key', async () => {
        const a = await post('/admin/create', { plan: 'specter', duration: '30d', note: 'web order 1', ref: 'order-1' })
        assert.strictEqual(a.status, 200); assert.strictEqual(a.body.existing, false)
        const b = await post('/admin/create', { plan: 'specter', duration: '30d', note: 'web order 1', ref: 'order-1' })
        assert.strictEqual(b.body.key, a.body.key); assert.strictEqual(b.body.existing, true)
        key1 = a.body.key
        assert.strictEqual(Object.keys(store.get('specter:licenses')).length, 1)
    })

    await test('five parallel creates of one ref make exactly one key', async () => {
        const out = await Promise.all([1, 2, 3, 4, 5].map(() => post('/admin/create', { plan: 'pm_nightly', duration: '7d', ref: 'order-par' })))
        const keys = new Set(out.filter(o => o.status === 200).map(o => o.body.key))
        assert.strictEqual(keys.size, 1)
        assert.ok(out.every(o => o.status === 200 || (o.status === 409 && o.body.error === 'busy')))
        const dbkeys = Object.values(store.get('specter:licenses')).filter(l => l.ref === 'order-par')
        assert.strictEqual(dbkeys.length, 1)
    })

    await test('parallel creates of different refs do not lose keys', async () => {
        const before = Object.keys(store.get('specter:licenses')).length
        const out = await Promise.all(Array.from({ length: 12 }, (_, i) => post('/admin/create', { plan: 'beta', duration: '1d', ref: 'many-' + i })))
        assert.ok(out.every(o => o.status === 200))
        assert.strictEqual(Object.keys(store.get('specter:licenses')).length, before + 12)
    })

    await test('bind: the first Discord account owns the key, another one is refused', async () => {
        const a = await post('/admin/bind', { key: key1, discord_id: A })
        assert.strictEqual(a.status, 200); assert.strictEqual(a.body.already, false); assert.strictEqual(a.body.lua, 'gamesense')
        const again = await post('/admin/bind', { key: key1, discord_id: A })
        assert.strictEqual(again.status, 200); assert.strictEqual(again.body.already, true)
        const other = await post('/admin/bind', { key: key1, discord_id: B })
        assert.strictEqual(other.status, 409); assert.strictEqual(other.body.reason, 'bound_to_other')
    })

    await test('bind refuses an unknown, revoked or expired key and a bad id', async () => {
        assert.strictEqual((await post('/admin/bind', { key: 'nope', discord_id: A })).body.reason, 'invalid_key')
        assert.strictEqual((await post('/admin/bind', { key: key1, discord_id: 'abc' })).status, 400)
        const k = (await post('/admin/create', { plan: 'beta', duration: '1d' })).body.key
        await post('/admin/revoke', { key: k })
        assert.strictEqual((await post('/admin/bind', { key: k, discord_id: A })).body.reason, 'revoked')
        const e = (await post('/admin/create', { plan: 'beta', duration: '1d' })).body.key
        store.get('specter:licenses')[e].expires_at = Date.now() - 1000
        assert.strictEqual((await post('/admin/bind', { key: e, discord_id: A })).body.reason, 'expired')
    })

    await test('by_discord lists the keys of an account, unbind frees a key for another account', async () => {
        const list = await get('/admin/by_discord?discord_id=' + A, admin)
        assert.deepStrictEqual(list.body.map(x => x.key), [key1])
        assert.strictEqual((await post('/admin/unbind', { key: key1 })).body.was, A)
        assert.strictEqual((await post('/admin/bind', { key: key1, discord_id: B })).status, 200)
        assert.strictEqual((await get('/admin/by_discord?discord_id=' + A, admin)).body.length, 0)
        assert.strictEqual((await get('/admin/by_discord?discord_id=x', admin)).status, 400)
        assert.strictEqual((await get('/admin/by_discord?discord_id=' + A, {})).status, 403)
    })

    await test('/admin/list shows the Discord account', async () => {
        const row = (await get('/admin/list', admin)).body.find(r => r.key === key1)
        assert.strictEqual(row.discord_id, B)
    })

    let pm
    await test('/verify tells which Luas the Discord account unlocks and whether it is linked', async () => {
        pm = (await post('/admin/create', { plan: 'pm_nightly', duration: '30d' })).body.key
        const unlinked = await get('/verify?key=' + pm + '&hwid=H2')
        assert.strictEqual(unlinked.body.valid, true); assert.strictEqual(unlinked.body.discord_linked, false)
        assert.deepStrictEqual(unlinked.body.access.map(a => a.lua), ['primordial'])
        await post('/admin/bind', { key: pm, discord_id: B })
        const linked = await get('/verify?key=' + pm + '&hwid=H2')
        assert.strictEqual(linked.body.discord_linked, true)
        assert.deepStrictEqual(linked.body.access.map(a => a.lua).sort(), ['gamesense', 'primordial'])
        assert.strictEqual(linked.body.lua, 'primordial')
    })

    await test('/verify does not drop a Discord link written a moment before (no lost updates)', async () => {
        const k = (await post('/admin/create', { plan: 'specter', duration: '30d' })).body.key
        const out = await Promise.all([get('/verify?key=' + k + '&hwid=H9'), post('/admin/bind', { key: k, discord_id: A }), get('/verify?key=' + k + '&hwid=H9')])
        assert.ok(out.every(o => o.status === 200))
        assert.strictEqual(store.get('specter:licenses')[k].discord_id, A)
    })

    await test('a revoked key stops showing in the access list', async () => {
        const k = (await post('/admin/create', { plan: 'nightly', duration: '30d' })).body.key
        await post('/admin/bind', { key: k, discord_id: A })
        await post('/admin/revoke', { key: k })
        const r = await get('/verify?key=' + pm + '&hwid=H2')
        assert.ok(!r.body.access.some(a => a.plan === 'nightly'))
    })

    await test('cloud config upload / delete need a linked Discord account', async () => {
        const k = (await post('/admin/create', { plan: 'specter', duration: '30d' })).body.key
        await get('/verify?key=' + k + '&hwid=HX')
        const data = Buffer.from('{"a":1,"b":2,"c":3}').toString('base64')
        const part = n => get('/configs/upload_part?key=' + k + '&hwid=HX&name=' + n + '&idx=0&total=1&data=' + encodeURIComponent(data))
        const denied = await part('cfg')
        assert.strictEqual(denied.status, 403); assert.strictEqual(denied.body.reason, 'discord_not_linked')
        assert.strictEqual((await get('/configs/upload?key=' + k + '&hwid=HX&name=cfg&data=' + encodeURIComponent(data))).body.reason, 'discord_not_linked')
        assert.strictEqual((await get('/configs/delete?key=' + k + '&hwid=HX&name=cfg')).body.reason, 'discord_not_linked')
        await post('/admin/bind', { key: k, discord_id: A })
        const ok = await part('cfg')
        assert.strictEqual(ok.status, 200); assert.strictEqual(ok.body.done, true)
        assert.strictEqual((await get('/configs/delete?key=' + k + '&hwid=HX&name=cfg')).body.ok, true)
    })

    await test('listing configs stays open', async () => {
        assert.strictEqual((await get('/configs')).status, 200)
    })

    server.close()
    console.log(`\n${passed} tests passed`)
    process.exit(0)
}
main().catch(e => { console.error(e); process.exit(1) })
