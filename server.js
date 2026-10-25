const express = require('express')
const cors    = require('cors')
const crypto  = require('crypto')

const app  = express()

// a variable pasted as NAME=value or with quotes around it ("value") still works: both are cut off
function env(name, fallback) {
    let v = String(process.env[name] || '').trim()
    if (v.startsWith(name)) v = v.slice(name.length).replace(/^[\s=:]+/, '')   // "NAME=value", "NAME value" or "NAME<newline>value" pasted into the value box
    if (v.length >= 2 && ((v[0] === '"' && v[v.length - 1] === '"') || (v[0] === "'" && v[v.length - 1] === "'"))) v = v.slice(1, -1).trim()
    return v || fallback
}

const PORT = env('PORT', 3000)

// A failed request (a Redis answer that errors, a bad body) must never take the whole server down: Express 4 does not catch a
// rejected async handler, and since Node 15 an unhandled rejection ends the process = a crash loop on Railway ("502 Application
// failed to respond" for every key check). Log it and keep serving.
process.on('unhandledRejection', e => console.error('Unhandled rejection:', e && e.stack || e))
process.on('uncaughtException', e => console.error('Uncaught exception:', e && e.stack || e))

const ADMIN_SECRET  = env('ADMIN_SECRET', 'change_this_secret_now')
const SCRIPT_SECRET = env('SCRIPT_SECRET', 'change_this_script_secret_now')

// Tamper reports: a Discord webhook URL (Channel settings > Integrations > Webhooks). It lives HERE and never in the
// Lua: a client side webhook can be read out of the script by the very person cracking it, who can then flood the
// channel with fake reports or drop the request. The server sees every verify, so its own signals can not be patched out.
const TAMPER_WEBHOOK  = env('TAMPER_WEBHOOK', '')
// after this many reports on one key the license is revoked by itself; 0 = report only (a false positive would ban a
// paying customer, so it is off unless you turn it on)
const TAMPER_AUTO_BAN = parseInt(env('TAMPER_AUTO_BAN', '0'), 10) || 0

// ── PERSISTENT DB via Railway env var ────────────────────────────────────
// Since Railway filesystem resets on redeploy, we store licenses in
// a KV store. Simplest free option: store in memory + sync to
// environment variable via Railway API, OR use a free Redis/Upstash.
// 
// SIMPLEST FIX: Use Upstash Redis (free tier, 10k commands/day)
// npm install @upstash/redis
// Set env: UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN

const { Redis } = require('@upstash/redis')

const redis = new Redis({
    url:   env('UPSTASH_REDIS_REST_URL', ''),
    token: env('UPSTASH_REDIS_REST_TOKEN', ''),
})

const DB_KEY = 'specter:licenses'

async function db_read() {
    try {
        const data = await redis.get(DB_KEY)
        return data || {}
    } catch(e) {
        console.error('DB read error:', e.message)
        return {}
    }
}

async function db_write(data) {
    try {
        await redis.set(DB_KEY, data)
    } catch(e) {
        console.error('DB write error:', e.message)
    }
}

// ── Script storage — also in Redis ───────────────────────────────────────
// The script is ~800 KB: it is kept in parts (specter:script:<plan>:<i> + :parts = the count) so no single Redis request
// gets near a size limit. A script stored the old way (one key) is still read.
const SCRIPT_PART = 300000
async function put_script(plan, script) {
    const n = Math.ceil(script.length / SCRIPT_PART)
    for (let i = 0; i < n; i++)
        await redis.set(`specter:script:${plan}:${i}`, script.slice(i * SCRIPT_PART, (i + 1) * SCRIPT_PART))
    await redis.set(`specter:script:${plan}:parts`, n)
    await redis.set(`specter:script:${plan}:sha256`, sha256(script))
    await redis.del(`specter:script:${plan}`)
    return n
}
async function read_script(plan) {
    const n = Number(await redis.get(`specter:script:${plan}:parts`)) || 0
    if (n > 0) {
        const parts = await Promise.all(Array.from({ length: n }, (_, i) => redis.get(`specter:script:${plan}:${i}`)))
        if (parts.some(p => typeof p !== 'string')) return null
        return parts.join('')
    }
    const val = await redis.get(`specter:script:${plan}`)
    return typeof val === 'string' ? val : null
}
async function get_script(plan) {
    try {
        return (await read_script(plan)) || (await read_script('default'))
    } catch(e) {
        console.error('Script read error:', e.message)
        return null
    }
}

// pm_*: Specter for Primordial (specter_primordial_loader.lua), nightly = everything, beta = no resolver page, dev = the newest
// (main) build. A key's plan decides which BUILDS its owner can load (owners, Oct 21 2026: "dev kulcs: mind a 3, nightly: beta es
// nightly, beta: csak beta"); the loader asks for one of them with `build`
const VALID_PLANS = ['beta', 'nightly', 'specter', 'debug', 'pm_dev', 'pm_nightly', 'pm_beta']
const PM_BUILDS = {
    pm_dev:     ['pm_dev', 'pm_nightly', 'pm_beta'],
    pm_nightly: ['pm_nightly', 'pm_beta'],
    pm_beta:    ['pm_beta'],
}

function parse_duration(dur) {
    if (!dur || dur === 'lifetime') return null
    const m = dur.match(/^(\d+)(d|w|m)$/i)
    if (!m) throw new Error('Invalid duration. Use: 1d 7d 30d 1w 1m lifetime')
    const n  = parseInt(m[1], 10)
    const ms = m[2].toLowerCase()==='d' ? n*86400000
             : m[2].toLowerCase()==='w' ? n*604800000
             : m[2].toLowerCase()==='m' ? n*2592000000 : null
    if (!ms) throw new Error('Bad unit')
    return Date.now() + ms
}

function gen_key() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    const bytes = crypto.randomBytes(24)
    let parts = ['','','','']
    for (let i = 0; i < 24; i++) {
        parts[Math.floor(i/6)] += chars[bytes[i] % chars.length]
    }
    return parts.join('-')
}

// which Lua a plan belongs to: pm_* = Specter for Primordial, the rest = Specter for Gamesense
function lua_of(plan) { return String(plan).startsWith('pm_') ? 'primordial' : 'gamesense' }

// The licenses are ONE json value in Redis, so every read-change-write has to run alone (this server is one process):
// two creates at the same moment would otherwise lose one of the keys.
let db_chain = Promise.resolve()
function with_db(fn) {
    const run = db_chain.then(fn, fn)
    db_chain = run.catch(() => {})
    return run
}

const DISCORD_ID_RE = /^\d{15,25}$/

// the Luas a Discord account can use right now: every key bound to it that is neither revoked nor expired
function access_of(db, discord_id, extra) {
    const now = Date.now()
    const list = []
    for (const [key, v] of Object.entries(db)) {
        const mine = key === extra || (discord_id && v.discord_id === discord_id)
        if (!mine || v.revoked || (v.expires_at && now > v.expires_at)) continue
        list.push({ lua: lua_of(v.plan), plan: v.plan, expires_at: v.expires_at || null })
    }
    return list
}

function sha256(text) {
    return crypto.createHash('sha256').update(String(text)).digest('hex')
}
function sign_ticket(key, hwid, plan, ticket_exp, nonce) {
    return sha256(`${key}|${hwid}|${plan}|${ticket_exp}|${nonce}|${SCRIPT_SECRET}`)
}

// ── tamper reports ───────────────────────────────────────────────────────
const TAMPER_KINDS = {
    hwid_mismatch:   'Key used on a second machine',
    integrity:       'Script integrity check failed (in-game memory / globals changed)',
    fake_auth:       'Auth globals pre-set before the loader ran (forged login)',
    script_error:    'Downloaded script was modified (does not compile / run)',
    bad_ticket:      'Script requested with a wrong or replayed ticket',
    no_ticket:       'Script requested without verifying first',
}

async function discord_post(license, key, kind, detail, count) {
    if (!TAMPER_WEBHOOK) return
    const body = {
        username: 'Specter Guard',
        embeds: [{
            title: 'Tamper attempt',
            color: 0xFF5050,
            fields: [
                { name: 'User',  value: '`' + (license.note || 'unknown') + '`', inline: true },
                { name: 'Plan',  value: '`' + (license.plan || '?') + '`',       inline: true },
                { name: 'Count', value: String(count),                           inline: true },
                { name: 'Key',   value: '```' + key + '```' },
                { name: 'HWID',  value: '```' + (license.hwid || '-') + '```' },
                { name: 'What',  value: (TAMPER_KINDS[kind] || kind) + (detail ? ('\n`' + detail + '`') : '') },
            ],
            footer: { text: 'Revoke with /key_revoke' },
            timestamp: new Date().toISOString(),
        }],
    }
    try {
        const r = await fetch(TAMPER_WEBHOOK, {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body: JSON.stringify(body),
        })
        if (!r.ok) console.error('[TAMPER] webhook ' + r.status)
    } catch (e) {
        console.error('[TAMPER] webhook error:', e.message)
    }
}

// Records one report on a key. The same kind is only reported once every 5 minutes so a loop in the client (or someone
// replaying the request) can not flood the channel. Returns false when nothing was recorded.
async function tamper_report(key, kind, detail) {
    if (!key || !TAMPER_KINDS[kind]) return false
    return with_db(() => tamper_report_locked(key, kind, detail))
}

async function tamper_report_locked(key, kind, detail) {
    const db = await db_read()
    const license = db[key]
    if (!license) return false                       // unknown key: nothing to ban, nothing to report

    const now  = Date.now()
    const list = Array.isArray(license.tamper) ? license.tamper : []
    const last = list.filter(t => t.kind === kind).pop()
    if (last && now - last.at < 300000) return false

    detail = String(detail || '').slice(0, 120)
    list.push({ kind, detail, at: now })
    while (list.length > 20) list.shift()
    license.tamper = list

    if (TAMPER_AUTO_BAN > 0 && list.length >= TAMPER_AUTO_BAN && !license.revoked) {
        license.revoked = true
        console.log(`[TAMPER] auto-revoked key=${key} after ${list.length} reports`)
    }
    await db_write(db)

    console.log(`[TAMPER] key=${key} kind=${kind} count=${list.length} ${detail}`)
    await discord_post(license, key, kind, detail, list.length)
    return true
}

app.use(cors())
// Accept JSON, urlencoded, and raw text (GS http.post sends no content-type)
app.use((req, res, next) => {
    const ct = req.headers['content-type'] || ''
    if (ct.includes('application/json')) {
        express.json({ limit: '50mb' })(req, res, next)
    } else if (ct.includes('urlencoded')) {
        express.urlencoded({ limit: '50mb', extended: true })(req, res, next)
    } else if (req.method === 'POST' || req.method === 'PUT') {
        // GS http.post sends raw JSON with no content-type header
        let raw = ''
        req.on('data', d => { raw += d })
        req.on('end', () => {
            try { req.body = JSON.parse(raw) }
            catch { req.body = {} }
            next()
        })
    } else {
        next()
    }
})

// ── POST /admin/create ────────────────────────────────────────────────────
app.post('/admin/create', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    const { plan, duration, note } = req.body
    // `ref` makes the call safe to repeat (a payment webhook is delivered more than once): the same ref always gives the same key
    const ref = typeof req.body.ref === 'string' ? req.body.ref.trim().slice(0, 80) : ''
    if (!VALID_PLANS.includes(plan))
        return res.status(400).json({ error: 'invalid plan' })
    let expires_at
    try { expires_at = parse_duration(duration || 'lifetime') }
    catch(e) { return res.status(400).json({ error: e.message }) }

    let lock = false
    if (ref) {
        const known = Object.entries(await db_read()).find(([, v]) => v.ref === ref)
        if (known) return res.json({ key: known[0], plan: known[1].plan, expires_at: known[1].expires_at, note: known[1].note || '', existing: true })
        try { lock = !!(await redis.set(`specter:ref:${ref}`, '1', { nx: true, ex: 30 })) } catch (e) { lock = true }
        if (!lock) return res.status(409).json({ error: 'busy' })
    }
    const key = gen_key()
    await with_db(async () => {
        const db = await db_read()
        db[key] = {
            plan, expires_at, hwid: null, note: note||'',
            created_at: Date.now(), revoked: false,
            last_ticket: null, last_ticket_exp: null, last_nonce: null,
            discord_id: null, ref: ref || null,
        }
        await db_write(db)
    })
    res.json({ key, plan, expires_at, note: note||'', existing: false })
    console.log(`[CREATE] ${key}${ref ? ' ref=' + ref : ''}`)
})

// ── POST /admin/bind — a key belongs to ONE Discord account ───────────────
// The bot calls it for /register. The first account that registers a key owns it; another account gets bound_to_other,
// so the key can not be shared through Discord (the HWID lock covers the machine side).
app.post('/admin/bind', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    const key = String(req.body.key || '').trim()
    const discord_id = String(req.body.discord_id || '').trim()
    if (!key || !DISCORD_ID_RE.test(discord_id)) return res.status(400).json({ ok: false, reason: 'missing_params' })
    const out = await with_db(async () => {
        const db = await db_read()
        const l = db[key]
        if (!l)         return { status: 404, body: { ok: false, reason: 'invalid_key' } }
        if (l.revoked)  return { status: 403, body: { ok: false, reason: 'revoked' } }
        if (l.expires_at && Date.now() > l.expires_at) return { status: 403, body: { ok: false, reason: 'expired' } }
        if (l.discord_id && l.discord_id !== discord_id) return { status: 409, body: { ok: false, reason: 'bound_to_other' } }
        const already = l.discord_id === discord_id
        if (!already) { l.discord_id = discord_id; l.discord_at = Date.now(); await db_write(db) }
        return { status: 200, body: { ok: true, already, key, plan: l.plan, lua: lua_of(l.plan), expires_at: l.expires_at, hwid_locked: !!l.hwid, note: l.note || '' } }
    })
    res.status(out.status).json(out.body)
    if (out.status === 200 && !out.body.already) console.log(`[BIND] ${key} -> ${discord_id}`)
})

// ── POST /admin/unbind — support moves a key to another account ───────────
app.post('/admin/unbind', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    const key = String(req.body.key || '').trim()
    const found = await with_db(async () => {
        const db = await db_read()
        if (!db[key]) return null
        const was = db[key].discord_id || null
        db[key].discord_id = null; db[key].discord_at = null
        await db_write(db)
        return { was }
    })
    if (!found) return res.status(404).json({ error: 'key not found' })
    res.json({ unbound: key, was: found.was })
})

// ── GET /admin/by_discord?discord_id= — the keys of one Discord account ───
app.get('/admin/by_discord', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    const id = String(req.query.discord_id || '')
    if (!DISCORD_ID_RE.test(id)) return res.status(400).json({ error: 'bad discord_id' })
    const db = await db_read()
    const now = Date.now()
    res.json(Object.entries(db).filter(([, v]) => v.discord_id === id).map(([key, v]) => ({
        key, plan: v.plan, lua: lua_of(v.plan), expires_at: v.expires_at,
        expired: v.expires_at ? now > v.expires_at : false, revoked: !!v.revoked, hwid_locked: !!v.hwid,
    })))
})

// ── POST /admin/extend — add hours to a running key (the web roulette) ────
// Only a key of that Discord account that is not revoked, not lifetime and not ended; `ref` makes a repeated call a no-op
// (the same spin is never paid twice). Hours, because the roulette has 5 h and 12 h prizes (parse_duration knows d / w / m).
app.post('/admin/extend', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    const key = String(req.body.key || '').trim()
    const discord_id = String(req.body.discord_id || '').trim()
    const ref = typeof req.body.ref === 'string' ? req.body.ref.trim().slice(0, 80) : ''
    const hours = Number(req.body.hours)
    if (!key || !ref || !DISCORD_ID_RE.test(discord_id) || !Number.isInteger(hours) || hours < 1 || hours > 24 * 90)
        return res.status(400).json({ ok: false, reason: 'missing_params' })
    const out = await with_db(async () => {
        const db = await db_read()
        const l = db[key]
        if (!l)         return { status: 404, body: { ok: false, reason: 'invalid_key' } }
        if (l.discord_id !== discord_id) return { status: 403, body: { ok: false, reason: 'not_your_key' } }
        const refs = Array.isArray(l.ext_refs) ? l.ext_refs : []
        if (refs.includes(ref)) return { status: 200, body: { ok: true, already: true, key, expires_at: l.expires_at } }
        if (l.revoked)  return { status: 403, body: { ok: false, reason: 'revoked' } }
        if (!l.expires_at) return { status: 409, body: { ok: false, reason: 'lifetime' } }
        if (Date.now() > l.expires_at) return { status: 403, body: { ok: false, reason: 'expired' } }
        l.expires_at += hours * 3600000
        l.ext_refs = [...refs, ref].slice(-50)
        await db_write(db)
        return { status: 200, body: { ok: true, already: false, key, expires_at: l.expires_at } }
    })
    res.status(out.status).json(out.body)
    if (out.status === 200 && !out.body.already) console.log(`[EXTEND] ${key} +${hours}h ref=${ref}`)
})

// ── POST /admin/revoke ────────────────────────────────────────────────────
app.post('/admin/revoke', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    const { key } = req.body
    const found = await with_db(async () => {
        const db = await db_read()
        if (!db[key]) return false
        db[key].revoked = true; db[key].last_ticket = null
        await db_write(db)
        return true
    })
    if (!found) return res.status(404).json({ error: 'key not found' })
    res.json({ revoked: key })
})

// ── POST /admin/reset_hwid ────────────────────────────────────────────────
app.post('/admin/reset_hwid', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    const { key } = req.body
    const found = await with_db(async () => {
        const db = await db_read()
        if (!db[key]) return false
        db[key].hwid = null; db[key].last_ticket = null
        await db_write(db)
        return true
    })
    if (!found) return res.status(404).json({ error: 'key not found' })
    res.json({ reset: key })
})

// ── GET /admin/list ───────────────────────────────────────────────────────
app.get('/admin/list', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    const db  = await db_read()
    const now = Date.now()
    res.json(Object.entries(db).map(([key, v]) => ({
        key, plan: v.plan, expires_at: v.expires_at,
        expired: v.expires_at ? now > v.expires_at : false,
        hwid_locked: !!v.hwid, revoked: !!v.revoked, note: v.note||'',
        tamper: Array.isArray(v.tamper) ? v.tamper : [],
        discord_id: v.discord_id || null,
    })))
})

// ── POST /admin/upload_script ─────────────────────────────────────────────
// Upload the cloud Lua scripts so they live in Redis, not on disk
app.post('/admin/upload_script', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    const { plan, script } = req.body
    if (!VALID_PLANS.includes(plan))
        return res.status(400).json({ error: 'invalid plan' })
    if (!script || script.length < 100)
        return res.status(400).json({ error: 'script too short' })
    try {
        const parts = await put_script(plan, script)
        res.json({ ok: true, plan, bytes: script.length, parts })
        console.log(`[SCRIPT UPLOAD] plan=${plan} bytes=${script.length} parts=${parts}`)
    } catch(e) {
        console.error('Script upload error:', e.message)
        res.status(500).json({ ok: false, error: 'redis: ' + String(e.message).split(', command was')[0].slice(0, 200) })   // the Redis error repeats the command = the whole script
    }
})

// ── GET /admin/script_info ────────────────────────────────────────────────
// The SHA-256 of the script each plan has (set by upload_script; null = not known): the bot uploads a new
// specter_cloud.lua only when it differs. Hashes only, never the script
app.get('/admin/script_info', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    try {
        const hashes = await redis.mget(...VALID_PLANS.map(p => `specter:script:${p}:sha256`))
        res.json(Object.fromEntries(VALID_PLANS.map((p, i) => [p, typeof hashes[i] === 'string' ? hashes[i] : null])))
    } catch(e) {
        res.status(500).json({ error: 'redis: ' + e.message })
    }
})

// ── GET /version?build=<plan> — the short SHA-256 of the script a plan has on the server ──────────────────
// No script and no secret: the loaders ask it every few minutes to tell a player that a newer version is out (Primordial can not
// reload a script by itself: its callbacks and menu items can not be removed). A hash only moves when the bot uploads a new script.
const version_cache = new Map()
app.get('/version', async (req, res) => {
    const plan = String(req.query.build || '')
    if (!VALID_PLANS.includes(plan))
        return res.status(400).json({ error: 'invalid build' })
    const hit = version_cache.get(plan)
    if (hit && Date.now() - hit.at < 30000)
        return res.json({ hash: hit.hash })
    try {
        const h = await redis.get(`specter:script:${plan}:sha256`)
        const hash = typeof h === 'string' ? h.slice(0, 16) : null
        version_cache.set(plan, { at: Date.now(), hash })
        res.json({ hash })
    } catch(e) {
        res.status(500).json({ error: 'redis' })
    }
})

// ── POST /admin/loader_version ────────────────────────────────────────────
// The LOADER_VERSION of the newest specter_loader.lua ("gs") / specter_primordial_loader.lua ("pm") of the cloud branch,
// set by the bot. /verify hands it out, a loader with a lower number tells its user to download the new one
const LOADERS = ['gs', 'pm']
app.post('/admin/loader_version', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    const { lua, version } = req.body
    const v = parseInt(version, 10)
    if (!LOADERS.includes(lua) || !(v >= 1))
        return res.status(400).json({ error: 'bad lua / version' })
    try {
        await redis.set(`specter:loader:${lua}`, String(v))
        res.json({ ok: true, lua, version: v })
    } catch(e) {
        res.status(500).json({ error: 'redis: ' + e.message })
    }
})

app.get('/admin/loader_version', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    res.json(await loader_versions())
})

async function loader_versions() {
    try {
        const v = await redis.mget(...LOADERS.map(l => `specter:loader:${l}`))
        return Object.fromEntries(LOADERS.map((l, i) => [l, parseInt(v[i], 10) || 0]))
    } catch {
        return Object.fromEntries(LOADERS.map(l => [l, 0]))       // unknown: no loader is told to update
    }
}

// ── GET /verify ───────────────────────────────────────────────────────────
app.get('/verify', (req, res) => with_db(async () => {
    const { key, hwid } = req.query
    if (!key || !hwid) return res.json({ valid: false, reason: 'missing_params' })
    const db      = await db_read()
    const license = db[key]
    if (!license)                                             return res.json({ valid: false, reason: 'invalid_key' })
    if (license.revoked)                                      return res.json({ valid: false, reason: 'revoked' })
    if (license.expires_at && Date.now()>license.expires_at) return res.json({ valid: false, reason: 'expired' })
    if (!license.hwid) { license.hwid = hwid }
    if (license.hwid !== hwid) {
        await db_write(db)
        // the server's own signal: the key is being used on a machine it is not locked to (shared, resold or cracked).
        // The client can not patch this out, it happens here
        tamper_report(key, 'hwid_mismatch', 'tried from ' + String(hwid).slice(0, 40)).catch(() => {})
        return res.json({ valid: false, reason: 'hwid_mismatch' })
    }

    const nonce      = crypto.randomBytes(12).toString('hex')
    const ticket_exp = Date.now() + 20000
    const ticket     = sign_ticket(key, hwid, license.plan, ticket_exp, nonce)
    license.last_ticket = ticket; license.last_ticket_exp = ticket_exp; license.last_nonce = nonce
    await db_write(db)

    console.log(`[VERIFY OK] key=${key} plan=${license.plan}`)
    const loader = await loader_versions()
    res.json({
        valid: true, plan: license.plan, expires_at: license.expires_at,
        user: license.note||null, ticket, ticket_exp, nonce,
        builds: PM_BUILDS[license.plan] || null,
        loader_gs: loader.gs, loader_pm: loader.pm,
        // the Luas this key (and the other keys of the same Discord account) unlock; the cloud needs a linked Discord account
        lua: lua_of(license.plan),
        discord_linked: !!license.discord_id,
        access: access_of(db, license.discord_id, key),
    })
}).catch(e => { console.error('[VERIFY]', e.message); if (!res.headersSent) res.status(500).json({ valid: false, reason: 'server_error' }) }))

// ── GET /report ───────────────────────────────────────────────────────────
// The client says it caught something. Anything coming from a client can be faked or left out, so this is a nice-to-have
// on top of the server's own signals (hwid_mismatch / bad ticket below), never the only line.
app.get('/report', async (req, res) => {
    const { key, kind, detail } = req.query
    try {
        await tamper_report(key, kind, detail)
    } catch (e) {
        console.error('[TAMPER] report error:', e.message)
    }
    res.json({ ok: true })                            // always ok: never tell the client what was recorded
})

// ── GET /script ───────────────────────────────────────────────────────────
app.get('/script', async (req, res) => {
    const { key, hwid, plan, ticket, nonce } = req.query
    const build = String(req.query.build || plan || '')           // the build the loader picked (a Primordial key can load several)
    if (!key||!hwid||!plan||!ticket||!nonce)
        return res.status(400).json({ ok: false, reason: 'missing_params' })
    const db      = await db_read()
    const license = db[key]
    if (!license)                                              return res.status(404).json({ ok: false, reason: 'invalid_key' })
    if (license.revoked)                                       return res.status(403).json({ ok: false, reason: 'revoked' })
    if (license.expires_at && Date.now()>license.expires_at)  return res.status(403).json({ ok: false, reason: 'expired' })
    if (license.hwid !== hwid)                                 return res.status(403).json({ ok: false, reason: 'hwid_mismatch' })
    if (license.plan !== plan)                                 return res.status(403).json({ ok: false, reason: 'wrong_plan' })
    if (!license.last_ticket||!license.last_ticket_exp)       { tamper_report(key, 'no_ticket', '').catch(() => {}); return res.status(403).json({ ok: false, reason: 'no_ticket' }) }
    if (Date.now() > license.last_ticket_exp)                  return res.status(403).json({ ok: false, reason: 'ticket_expired' })
    const expected = sign_ticket(key, hwid, plan, license.last_ticket_exp, license.last_nonce)
    if (ticket!==expected || nonce!==license.last_nonce || ticket!==license.last_ticket) {
        tamper_report(key, 'bad_ticket', '').catch(() => {})
        return res.status(403).json({ ok: false, reason: 'bad_ticket' })
    }

    if (!(PM_BUILDS[plan] || [plan]).includes(build))
        return res.status(403).json({ ok: false, reason: 'wrong_build' })
    const raw = await get_script(build)
    if (!raw) return res.status(500).json({ ok: false, reason: 'script_missing' })

    // the script talks back to this server (cloud loadouts, tamper reports); without PUBLIC_URL: the host it was asked on
    const host = String(req.get('host') || '')
    const public_url = env('PUBLIC_URL', '') || (/^[A-Za-z0-9.:-]+$/.test(host) ? 'https://' + host : '')
    // the clock expression must match the auth gate of the plan's script. gamesense: client.unix_time (no `os`);
    // Primordial (pm_*): client.get_unix_time. The pm auth gate the bot prepends reads the clock the same way.
    const pm = String(plan).startsWith('pm_')
    const now_expr = pm
        ? `(client and client.get_unix_time and client.get_unix_time()) or 0`
        : `(client and client.unix_time and client.unix_time()) or (os and os.time and os.time()) or (client and client.timestamp and math.floor(client.timestamp() / 1000)) or 0`
    const prefix = [
        `rawset(_G, "_auth_ok",        true)`,
        `rawset(_G, "_auth_alive",      true)`,
        `rawset(_G, "_auth_ts",         ${now_expr})`,
        `rawset(_G, "_auth_ticket",     ${JSON.stringify(ticket)})`,
        `rawset(_G, "_auth_ticket_exp", ${license.last_ticket_exp})`,
        `rawset(_G, "_auth_nonce",      ${JSON.stringify(nonce)})`,
        `rawset(_G, "_auth_user",       ${JSON.stringify(license.note||"")})`,
        `rawset(_G, "_auth_key",        ${JSON.stringify(key)})`,
        `rawset(_G, "_auth_hwid",       ${JSON.stringify(hwid)})`,
        `rawset(_G, "BUILD_VERSION",    ${JSON.stringify(build)})`,
        `rawset(_G, "_server_url",      ${JSON.stringify(public_url)})`,
    ].join('\n')

    // burn ticket
    license.last_ticket = null; license.last_ticket_exp = null; license.last_nonce = null
    await db_write(db)

    console.log(`[SCRIPT DELIVERED] key=${key} plan=${plan} build=${build}`)
    res.type('text/plain').send(prefix + '\n\n' + raw)
})


// the name shown on a shared config ("by ..." in the Loadouts list, everyone sees it): the key's note (who it is for),
// else a name made from the key's hash (a part of the key itself must not be public)
function config_author(license, key) {
    return license.note || 'user-' + sha256(key).slice(0, 6)
}

// The dev build has no key (owners, Oct 2026: "fix that dev can upload to cloud too"): its config upload / delete come with
// dev=1 and who=<name> instead of key + hwid, the author is "dev-<name>", the plan "dev". The repo is public, so this is an open
// door and is kept small: a rate per IP, at most DEV_CFG_MAX dev configs on the list (the oldest DEV ones go first, never a
// customer's), and a dev request can only delete dev configs
const DEV_CFG_MAX  = 40
const DEV_CFG_RATE = 200                        // upload parts + deletes per IP in 10 minutes
const dev_cfg_rate = new Map()                  // ip -> { n, since }
setInterval(() => {
    const now = Date.now()
    for (const [ip, r] of dev_cfg_rate) if (now - r.since > 600000) dev_cfg_rate.delete(ip)
}, 60000).unref()
const dev_request = req => !req.query.key && !req.query.hwid && req.query.dev === '1'
function dev_license(req) {
    const who = String(req.query.who || '').replace(/[^A-Za-z0-9_ .-]/g, '').trim().slice(0, 16)
    return { plan: 'dev', note: 'dev-' + (who || 'dev') }
}
function dev_rate_ok(req) {
    const ip  = String(req.headers['x-forwarded-for'] || req.socket.remoteAddress || '?').split(',')[0].trim()
    const now = Date.now()
    let r = dev_cfg_rate.get(ip)
    if (!r || now - r.since > 600000) { r = { n: 0, since: now }; dev_cfg_rate.set(ip, r) }
    return ++r.n <= DEV_CFG_RATE
}
// keeps at most DEV_CFG_MAX configs of the dev plan, the oldest first
function dev_cap(configs) {
    const dev = configs.filter(c => c.plan === 'dev')
    if (dev.length <= DEV_CFG_MAX) return configs
    const drop = new Set(dev.sort((a, b) => (a.ts || 0) - (b.ts || 0)).slice(0, dev.length - DEV_CFG_MAX))
    return configs.filter(c => !drop.has(c))
}

// ── GET /configs ──────────────────────────────────────────────────────────
// Returns all public cloud configs
// ?lua=pm: the Primordial lua's configs (name / author / time only, the data through /configs/get); without it the
// gamesense ones with their data, like before (a Primordial config can not be imported by the gamesense lua)
const config_lua = q => (q === 'pm' ? 'pm' : 'gs')
app.get('/configs', async (req, res) => {
    try {
        const data = await redis.get('specter:configs') || []
        if (config_lua(req.query.lua) === 'pm')
            return res.json(data.filter(c => c.lua === 'pm').map(c => ({ name: c.name, author: c.author, ts: c.ts })))
        res.json(data.filter(c => (c.lua || 'gs') === 'gs'))
    } catch(e) {
        res.json([])
    }
})

// ── GET /configs/get — one config's data (the Primordial lua loads it by name + author) ──
app.get('/configs/get', async (req, res) => {
    const { name, author } = req.query
    const lua = config_lua(req.query.lua)
    try {
        const data = await redis.get('specter:configs') || []
        const c = data.find(c => c.name === name && c.author === author && (c.lua || 'gs') === lua)
        if (!c) return res.status(404).json({ ok: false, reason: 'not_found' })
        res.json({ ok: true, name: c.name, author: c.author, data: c.data })
    } catch(e) {
        res.status(500).json({ ok: false, reason: 'server_error' })
    }
})

// ── POST /configs ─────────────────────────────────────────────────────────
// Upload a config. Requires valid key+hwid (same as /verify auth)
// GET /configs/upload — used by GS loader (http.post has no content-type)
app.get('/configs/upload', async (req, res) => {
    const key  = req.query.key
    const hwid = req.query.hwid
    const name = req.query.name
    let   data = req.query.data
    if (data) { try { data = Buffer.from(data, 'base64').toString('utf8') } catch(e) {} }
    if (!key || !hwid || !name || !data)
        return res.status(400).json({ ok: false, reason: 'missing_params' })
    if (name.length < 1 || name.length > 32)
        return res.status(400).json({ ok: false, reason: 'invalid_name' })
    const db = await db_read()
    const license = db[key]
    if (!license || license.revoked) return res.status(403).json({ ok: false, reason: 'invalid_key' })
    if (license.expires_at && Date.now() > license.expires_at) return res.status(403).json({ ok: false, reason: 'expired' })
    if (license.hwid !== hwid) return res.status(403).json({ ok: false, reason: 'hwid_mismatch' })
    if (!license.discord_id) return res.status(403).json({ ok: false, reason: 'discord_not_linked' })
    const author = config_author(license, key)
    try {
        let configs = await redis.get('specter:configs') || []
        configs = configs.filter(c => !(c.name === name && c.author === author && (c.lua || 'gs') === 'gs'))
        if (configs.length >= 200) configs = configs.slice(-199)
        configs.push({ name, author, data, plan: license.plan, ts: Date.now() })
        await redis.set('specter:configs', configs)
        console.log(`[CONFIG UPLOAD] ${name} by ${author}`)
        res.json({ ok: true, name, author })
    } catch(e) {
        res.status(500).json({ ok: false, reason: 'server_error' })
    }
})

// ── GET /configs/upload_part — chunked upload ──────────────────────────────
// A whole config does not fit into one URL (and gamesense's http.post sends no content-type), so the script
// sends it in small parts, one GET each. The parts only live in memory between the requests of one upload.
const uploads = new Map()                       // `${key}|${name}` -> { total, parts, ts }
setInterval(() => {
    const now = Date.now()
    for (const [id, u] of uploads) if (now - u.ts > 120000) uploads.delete(id)
}, 30000).unref()

app.get('/configs/upload_part', async (req, res) => {
    const { key, hwid } = req.query
    const dev   = dev_request(req)
    const name  = typeof req.query.name === 'string' ? req.query.name.trim() : ''
    const part  = req.query.data
    const idx   = parseInt(req.query.idx, 10)
    const total = parseInt(req.query.total, 10)
    if ((!dev && (!key || !hwid)) || !name || typeof part !== 'string' || !part)
        return res.status(400).json({ ok: false, reason: 'missing_params' })
    if (name.length < 1 || name.length > 32)
        return res.status(400).json({ ok: false, reason: 'invalid_name' })
    if (!Number.isInteger(idx) || !Number.isInteger(total) || total < 1 || total > 150 || idx < 0 || idx >= total || part.length > 6000)
        return res.status(400).json({ ok: false, reason: 'invalid_part' })

    let license
    if (dev) {
        if (!dev_rate_ok(req)) return res.status(429).json({ ok: false, reason: 'rate' })
        license = dev_license(req)
    } else {
        const db = await db_read()
        license = db[key]
        if (!license || license.revoked) return res.status(403).json({ ok: false, reason: 'invalid_key' })
        if (license.expires_at && Date.now() > license.expires_at) return res.status(403).json({ ok: false, reason: 'expired' })
        if (license.hwid !== hwid) return res.status(403).json({ ok: false, reason: 'hwid_mismatch' })
        if (!license.discord_id) return res.status(403).json({ ok: false, reason: 'discord_not_linked' })
    }

    // the first part always starts a fresh upload, so an abandoned one cannot mix into the next
    const id = `${dev ? 'dev:' + license.note : key}|${name}|${config_lua(req.query.lua)}`
    let u = uploads.get(id)
    if (!u || idx === 0 || u.total !== total) {
        u = { total, parts: new Array(total).fill(null), ts: Date.now() }
        uploads.set(id, u)
    }
    u.parts[idx] = part
    u.ts = Date.now()
    if (u.parts.some(p => p === null)) return res.json({ ok: true, done: false })

    uploads.delete(id)
    let data = ''
    try { data = Buffer.from(u.parts.join(''), 'base64').toString('utf8') } catch (e) {}
    if (data.length < 10 || data.length > 200000)
        return res.status(400).json({ ok: false, reason: 'invalid_data' })

    const author = config_author(license, key)
    const lua = config_lua(req.query.lua)
    try {
        let configs = await redis.get('specter:configs') || []
        configs = configs.filter(c => !(c.name === name && c.author === author && (c.lua || 'gs') === lua))
        if (configs.length >= 200) configs = configs.slice(-199)
        configs.push(lua === 'pm' ? { name, author, data, plan: license.plan, ts: Date.now(), lua }
                                  : { name, author, data, plan: license.plan, ts: Date.now() })
        if (dev) configs = dev_cap(configs)
        await redis.set('specter:configs', configs)
        console.log(`[CONFIG UPLOAD] ${name} by ${author} (${total} parts, ${lua})`)
        res.json({ ok: true, done: true, name, author })
    } catch (e) {
        res.status(500).json({ ok: false, reason: 'server_error' })
    }
})

app.post('/configs', async (req, res) => {
    const { key, hwid, name, data } = req.body
    if (!key || !hwid || !name || !data)
        return res.status(400).json({ ok: false, reason: 'missing_params' })
    if (typeof name !== 'string' || name.trim().length < 1 || name.length > 32)
        return res.status(400).json({ ok: false, reason: 'invalid_name' })
    if (typeof data !== 'string' || data.length < 10 || data.length > 200000)
        return res.status(400).json({ ok: false, reason: 'invalid_data' })

    // validate key+hwid
    const db      = await db_read()
    const license = db[key]
    if (!license || license.revoked)
        return res.status(403).json({ ok: false, reason: 'invalid_key' })
    if (license.expires_at && Date.now() > license.expires_at)
        return res.status(403).json({ ok: false, reason: 'expired' })
    if (license.hwid !== hwid)
        return res.status(403).json({ ok: false, reason: 'hwid_mismatch' })
    if (!license.discord_id)
        return res.status(403).json({ ok: false, reason: 'discord_not_linked' })

    const author   = config_author(license, key)
    const cfg_name = name.trim()

    try {
        let configs = await redis.get('specter:configs') || []
        // prevent duplicates by same author+name
        configs = configs.filter(c => !(c.name === cfg_name && c.author === author && (c.lua || 'gs') === 'gs'))
        // max 200 total configs
        if (configs.length >= 200)
            configs = configs.slice(configs.length - 199)
        configs.push({
            name:   cfg_name,
            author: author,
            data:   data,
            plan:   license.plan,
            ts:     Date.now(),
        })
        await redis.set('specter:configs', configs)
        console.log(`[CONFIG UPLOAD] ${cfg_name} by ${author}`)
        res.json({ ok: true, name: cfg_name, author })
    } catch(e) {
        res.status(500).json({ ok: false, reason: 'server_error' })
    }
})

// ── GET /configs/delete — user deletes own config ────────────────────────
app.get('/configs/delete', async (req, res) => {
    const { key, hwid, name } = req.query
    const dev = dev_request(req)
    if ((!dev && (!key || !hwid)) || !name)
        return res.status(400).json({ ok: false, reason: 'missing_params' })
    let license
    if (dev) {
        if (!dev_rate_ok(req)) return res.status(429).json({ ok: false, reason: 'rate' })
        license = dev_license(req)
    } else {
        const db = await db_read()
        license = db[key]
        if (!license || license.revoked) return res.status(403).json({ ok: false, reason: 'invalid_key' })
        if (license.hwid !== hwid) return res.status(403).json({ ok: false, reason: 'hwid_mismatch' })
        if (!license.discord_id) return res.status(403).json({ ok: false, reason: 'discord_not_linked' })
    }
    const author = config_author(license, key)
    const lua = config_lua(req.query.lua)
    try {
        let configs = await redis.get('specter:configs') || []
        const before = configs.length
        configs = configs.filter(c => !(c.name === name && c.author === author && (c.lua || 'gs') === lua && (!dev || c.plan === 'dev')))
        if (configs.length === before) return res.json({ ok: false, reason: 'not_found' })
        await redis.set('specter:configs', configs)
        console.log(`[CONFIG DELETE] ${name} by ${author}`)
        res.json({ ok: true })
    } catch(e) {
        res.status(500).json({ ok: false, reason: 'server_error' })
    }
})

// ── GET /shotlog — the resolver's shot logs ───────────────────────────────
// The dev build sends one line (JSON) per shot of ours: what the resolver gave the record, the result. They come in
// base64 parts like a config (one GET each), a finished batch goes to a Redis list, the bot writes the list to GitHub
// (branch "shotlogs") and then drops what it wrote (/admin/shotlog). No player names in it (the script hashes the ids).
// Without a key (the dev build has none) a batch is "dev"; with key + hwid it is checked like a config upload.
// Per IP at most SHOTLOG_RATE parts in 10 minutes, the list keeps the newest SHOTLOG_MAX batches.
const SHOTLOG_KEY  = 'specter:shotlog'
const SHOTLOG_MAX  = 400
const SHOTLOG_RATE = 300
const shotlog_parts = new Map()                 // batch id -> { total, parts, ts }
const shotlog_rate  = new Map()                 // ip -> { n, since }
setInterval(() => {
    const now = Date.now()
    for (const [id, u] of shotlog_parts) if (now - u.ts > 120000) shotlog_parts.delete(id)
    for (const [ip, r] of shotlog_rate) if (now - r.since > 600000) shotlog_rate.delete(ip)
}, 30000).unref()

app.get('/shotlog', async (req, res) => {
    const { key, hwid } = req.query
    const id    = typeof req.query.id === 'string' ? req.query.id : ''
    const part  = req.query.data
    const idx   = parseInt(req.query.idx, 10)
    const total = parseInt(req.query.total, 10)
    if (!/^[A-Za-z0-9]{6,24}$/.test(id) || typeof part !== 'string' || !part)
        return res.status(400).json({ ok: false, reason: 'missing_params' })
    if (!Number.isInteger(idx) || !Number.isInteger(total) || total < 1 || total > 60 || idx < 0 || idx >= total || part.length > 4000)
        return res.status(400).json({ ok: false, reason: 'invalid_part' })

    const ip  = String(req.headers['x-forwarded-for'] || req.socket.remoteAddress || '?').split(',')[0].trim()
    const now = Date.now()
    let r = shotlog_rate.get(ip)
    if (!r || now - r.since > 600000) { r = { n: 0, since: now }; shotlog_rate.set(ip, r) }
    if (++r.n > SHOTLOG_RATE) return res.status(429).json({ ok: false, reason: 'rate' })

    let src = 'dev'
    if (key) {
        const db = await db_read()
        const license = db[key]
        if (!license || license.revoked || license.hwid !== hwid) return res.status(403).json({ ok: false, reason: 'invalid_key' })
        src = license.plan + ':' + config_author(license, key)
    }

    const bid = `${ip}|${id}`
    let u = shotlog_parts.get(bid)
    if (!u || u.total !== total) {
        u = { total, parts: new Array(total).fill(null), ts: now }
        shotlog_parts.set(bid, u)
    }
    u.parts[idx] = part
    u.ts = now
    if (u.parts.some(p => p === null)) return res.json({ ok: true, done: false })

    shotlog_parts.delete(bid)
    let text = ''
    try { text = Buffer.from(u.parts.join(''), 'base64').toString('utf8') } catch (e) {}
    if (text.length < 2 || text.length > 200000)
        return res.status(400).json({ ok: false, reason: 'invalid_data' })
    try {
        await redis.rpush(SHOTLOG_KEY, JSON.stringify({ at: now, src, id, lines: text }))
        await redis.ltrim(SHOTLOG_KEY, -SHOTLOG_MAX, -1)
        res.json({ ok: true, done: true })
    } catch (e) {
        res.status(500).json({ ok: false, reason: 'server_error' })
    }
})

// ── GET /admin/shotlog — the bot takes the stored batches (oldest first) ───
// ?n=<count> afterwards drops the first <count> once they are on GitHub (a failed write loses nothing)
app.get('/admin/shotlog', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    try {
        const n = parseInt(req.query.n, 10)
        if (Number.isInteger(n) && n > 0) {
            await redis.ltrim(SHOTLOG_KEY, n, -1)
            return res.json({ ok: true, dropped: n })
        }
        const items = await redis.lrange(SHOTLOG_KEY, 0, 99)
        res.json({ ok: true, items: (items || []).map(i => typeof i === 'string' ? JSON.parse(i) : i) })
    } catch (e) {
        res.status(500).json({ error: 'redis: ' + e.message })
    }
})

// ── GET /presence — Specter user detection (specter_primordial.lua) ───────
// Every 30 s a running script says it is online (?me = a hash of its steam id, ?t = its version) and asks which of the
// players of its game are (?q = their hashes, at most 64): those get the moon on its scoreboard. Hashes only, no names.
// Kept in memory, not in Redis (it is gone after PRESENCE_TTL anyway, and Upstash counts every command).
const PRESENCE_TTL  = 75000
const PRESENCE_RATE = 120                       // requests per IP in 10 minutes
const presence      = new Map()                 // hash -> { tag, until }
const presence_rate = new Map()                 // ip -> { n, since }
setInterval(() => {
    const now = Date.now()
    for (const [h, p] of presence) if (now > p.until) presence.delete(h)
    for (const [ip, r] of presence_rate) if (now - r.since > 600000) presence_rate.delete(ip)
}, 30000).unref()

app.get('/presence', (req, res) => {
    const me  = typeof req.query.me === 'string' ? req.query.me : ''
    const tag = ['nightly', 'beta', 'dev', 'gs'].includes(req.query.t) ? req.query.t : 'dev'   // gs = the gamesense lua
    const q   = typeof req.query.q === 'string' && req.query.q ? req.query.q.split(',') : []
    if ((me && !/^[0-9a-f]{16}$/.test(me)) || q.length > 64 || q.some(h => !/^[0-9a-f]{16}$/.test(h)))
        return res.status(400).json({ ok: false, reason: 'bad_params' })

    const ip  = String(req.headers['x-forwarded-for'] || req.socket.remoteAddress || '?').split(',')[0].trim()
    const now = Date.now()
    let r = presence_rate.get(ip)
    if (!r || now - r.since > 600000) { r = { n: 0, since: now }; presence_rate.set(ip, r) }
    if (++r.n > PRESENCE_RATE) return res.status(429).json({ ok: false, reason: 'rate' })

    if (me) presence.set(me, { tag, until: now + PRESENCE_TTL })
    const on = {}
    for (const h of q) {
        const p = presence.get(h)
        if (p && now <= p.until) on[h] = p.tag
    }
    res.json({ ok: true, on })
})

// ── GET /servers — which server a Specter user is on (specter_primordial.lua, page "Servers") ─────────
// Opt-in: a script with "Share my server" on sends ?me=<hash>&srv=<ip:port>&nm=<name>&mp=<map>&pl=<players> every 20 s and gets
// the list of the others back; one without the option sends nothing about itself (and gets the list when the page is open).
// ?off=1 removes the entry at once. Kept in memory for SERVERS_TTL; the address must be a public ip:port (no private ranges,
// no console text: the script runs "connect <srv>" for it, so it is checked on both sides).
const SERVERS_TTL = 60000
const servers = new Map()                       // hash -> { tag, name, map, srv, players, until }
const servers_rate = new Map()                  // ip -> { n, since }
const public_srv = srv => {
    const m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3}):(\d{1,5})$/.exec(srv)
    if (!m) return false
    const o = m.slice(1, 5).map(Number), port = Number(m[5])
    if (o.some(x => x > 255) || port < 1 || port > 65535) return false
    if (o[0] === 0 || o[0] === 10 || o[0] === 127 || o[0] >= 224) return false
    if (o[0] === 192 && o[1] === 168) return false
    if (o[0] === 172 && o[1] >= 16 && o[1] <= 31) return false
    if (o[0] === 169 && o[1] === 254) return false
    if (o[0] === 100 && o[1] >= 64 && o[1] <= 127) return false
    return true
}
setInterval(() => {
    const now = Date.now()
    for (const [h, p] of servers) if (now > p.until) servers.delete(h)
    for (const [ip, r] of servers_rate) if (now - r.since > 600000) servers_rate.delete(ip)
}, 30000).unref()

app.get('/servers', (req, res) => {
    const me  = typeof req.query.me === 'string' ? req.query.me : ''
    if (me && !/^[0-9a-f]{16}$/.test(me)) return res.status(400).json({ ok: false, reason: 'bad_params' })
    const ip  = String(req.headers['x-forwarded-for'] || req.socket.remoteAddress || '?').split(',')[0].trim()
    const now = Date.now()
    let r = servers_rate.get(ip)
    if (!r || now - r.since > 600000) { r = { n: 0, since: now }; servers_rate.set(ip, r) }
    if (++r.n > 120) return res.status(429).json({ ok: false, reason: 'rate' })

    if (me && req.query.off === '1') servers.delete(me)
    else if (me && typeof req.query.srv === 'string') {
        const srv = req.query.srv
        if (!public_srv(srv)) return res.status(400).json({ ok: false, reason: 'bad_srv' })
        const tag  = ['nightly', 'beta', 'dev'].includes(req.query.t) ? req.query.t : 'dev'
        const name = String(req.query.nm || '').replace(/[^\x20-\x7e]/g, '').replace(/[|~;"%\\]/g, '').trim().slice(0, 20) || 'user'
        const map  = /^[A-Za-z0-9_]{1,32}$/.test(req.query.mp || '') ? req.query.mp : '?'
        const pl   = Math.max(0, Math.min(64, parseInt(req.query.pl, 10) || 0))
        servers.set(me, { tag, name, map, srv, players: pl, until: now + SERVERS_TTL })
    }
    const list = []
    for (const [h, p] of servers) if (h !== me && now <= p.until)
        list.push({ name: p.name, map: p.map, srv: p.srv, players: p.players, tag: p.tag, until: p.until })
    list.sort((a, b) => b.until - a.until)
    res.json({ ok: true, list: list.slice(0, 60).map(({ until, ...rest }) => rest) })
})

// ── GET /hvhgg — the HvH servers of hvh.gg (owners, Oct 2026: "add to the lua like server connectors, must get ips from hvh.gg") ──
// The lua used to ask hvh.gg itself and the game crashed after a refresh (a big page through the steam http library), so the server
// asks the site: a fixed list of urls (nothing from a request goes into them), at most 1.5 MB read, cached 60 s, and the lua
// gets a small clean list { srv, name, map, players }. The shape of hvh.gg's answer is not known: a JSON list / object of servers
// (an ip:port in addr / address / connect / server, or ip + port; name / map / players when there are) at any depth, else every
// ip:port of the text. Only public addresses (public_srv).
// hvh.cat is the HvH server browser built on hvh.gg's data (its CS:GO page is /csgo); the real api behind it is not known yet:
// /hvhgg?debug=1 shows what each source answered (status, size, the start of the text) to find it
const HVH_SOURCES = ['https://hvh.gg/api/servers', 'https://hvh.gg/api/v1/servers', 'https://api.hvh.gg/servers', 'https://api.hvh.gg/v1/servers',
    'https://hvh.gg/servers', 'https://hvh.cat/api/servers', 'https://hvh.cat/csgo']
const hvh_addr = row => {
    for (const k of ['addr', 'address', 'ip_port', 'ipport', 'connect', 'server', 'endpoint']) {
        if (typeof row[k] === 'string') {
            const m = /(\d+\.\d+\.\d+\.\d+:\d+)/.exec(row[k])
            if (m) return m[1]
        }
    }
    const host = row.ip ?? row.host, port = Number(row.port)
    if (typeof host === 'string') {
        if (/^\d+\.\d+\.\d+\.\d+$/.test(host) && Number.isInteger(port) && port >= 1 && port <= 65535) return host + ':' + port
        const m = /^(\d+\.\d+\.\d+\.\d+:\d+)$/.exec(host)
        if (m) return m[1]
    }
    return null
}
// which servers the owners want (Oct 2026: "only eu servers ... showing cs2 2018 and every server only csgo 2023"): the fields of a row are not known, so
// by what the row says about itself - a row that names CS2 or the year 2018 is dropped, and when it names a region / country it has to be a
// European one; a row that says nothing of a kind is kept (so a missing field never empties the list)
const HVH_EU = new Set(['eu', 'europe', 'de', 'fr', 'nl', 'pl', 'se', 'no', 'fi', 'dk', 'es', 'it', 'pt', 'gb', 'uk', 'ie', 'at', 'ch', 'be',
    'cz', 'sk', 'hu', 'ro', 'bg', 'gr', 'rs', 'hr', 'si', 'lt', 'lv', 'ee', 'ru', 'ua', 'tr', 'by', 'lu', 'is', 'md', 'ba', 'mk', 'al', 'me',
    'germany', 'france', 'netherlands', 'poland', 'sweden', 'norway', 'finland', 'denmark', 'spain', 'italy', 'portugal', 'united kingdom',
    'ireland', 'austria', 'switzerland', 'belgium', 'czechia', 'czech republic', 'slovakia', 'hungary', 'romania', 'bulgaria', 'greece',
    'serbia', 'croatia', 'slovenia', 'lithuania', 'latvia', 'estonia', 'russia', 'ukraine', 'turkey', 'belarus', 'frankfurt', 'amsterdam',
    'london', 'paris', 'stockholm', 'warsaw', 'moscow', 'helsinki', 'madrid', 'vienna', 'prague'])
const hvh_wanted = flat => {
    const vals = Object.values(flat)
    if (vals.some(v => /\bcs\s?2\b|counter-strike 2/.test(v) || /\b2018\b/.test(v))) return false
    const geo = Object.entries(flat).filter(([k]) => /region|country|continent|location|geo|^loc$|^cc$|datacenter|^dc$|city/.test(k)).map(([, v]) => v)
    if (geo.length && !geo.some(v => HVH_EU.has(v.trim()) || /^eu[-_ ]|europe/.test(v.trim()))) return false
    return true
}
const hvh_parse = (body, debug) => {
    const out = [], seen = new Set()
    const add = (srv, name, map, players, flat) => {
        if (out.length >= 20 || seen.has(srv) || !public_srv(srv)) return
        const wanted = !flat || hvh_wanted(flat)
        if (debug && flat && debug.length < 8) debug.push({ srv, kept: wanted, ...flat })
        if (!wanted) return
        seen.add(srv)
        const pl = Array.isArray(players) ? players.length : Number(players)
        out.push({
            srv,
            name: String(name ?? 'hvh.gg').replace(/[^\x20-\x7e]/g, '').replace(/[|~;"%\\]/g, '').trim().slice(0, 32) || 'hvh.gg',
            map: /^[A-Za-z0-9_]{1,32}$/.test(String(map)) ? String(map) : '?',
            players: Number.isFinite(pl) ? Math.max(0, Math.min(128, Math.floor(pl))) : 0,
        })
    }
    let data = null
    try { data = JSON.parse(body) } catch (e) {}
    if (data && typeof data === 'object') {
        let nodes = 0
        const walk = (node, depth) => {
            if (!node || typeof node !== 'object' || depth > 6 || nodes++ > 5000) return
            const srv = hvh_addr(node)
            if (srv) {
                const flat = {}
                for (const [k, v] of Object.entries(node).slice(0, 40))
                    if (v !== null && typeof v !== 'object') flat[k.toLowerCase()] = String(v).toLowerCase().slice(0, 80)
                add(srv, node.name ?? node.hostname ?? node.title, node.map ?? node.map_name,
                    node.players ?? node.num_players ?? node.player_count ?? node.clients, flat)
            }
            for (const v of Object.values(node)) walk(v, depth + 1)
        }
        walk(data, 0)
    }
    if (out.length === 0 && typeof body === 'string' && !data) {
        for (const m of body.matchAll(/(\d+\.\d+\.\d+\.\d+:\d+)/g)) add(m[1])
    }
    return out.sort((a, b) => b.players - a.players)
}
const hvh = { at: 0, list: [], busy: null }
const hvh_fetch = async trace => {
    for (const url of HVH_SOURCES) {
        const t = { url }
        try {
            const r = await fetch(url, { signal: AbortSignal.timeout(8000), redirect: 'follow',
                headers: { 'user-agent': 'Mozilla/5.0 (compatible; Specter)', accept: 'application/json,text/html;q=0.8' } })
            t.status = r.status
            t.type = r.headers.get('content-type')
            if (!r.ok || Number(r.headers.get('content-length') || 0) > 5000000) { if (trace) trace.push(t); continue }
            const text = (await r.text()).slice(0, 1500000)
            const rows = []
            const list = hvh_parse(text, rows)
            t.rows = rows
            t.bytes = text.length
            t.found = list.length
            if (trace) t.sample = text.slice(0, 1500)
            if (trace) trace.push(t)
            if (list.length) return list
        } catch (e) {
            t.error = String(e && e.message || e).slice(0, 120)
            if (trace) trace.push(t)
        }
    }
    return []
}
const hvh_rate = new Map()
app.get('/hvhgg', async (req, res) => {
    const ip  = String(req.headers['x-forwarded-for'] || req.socket.remoteAddress || '?').split(',')[0].trim()
    const now = Date.now()
    let r = hvh_rate.get(ip)
    if (!r || now - r.since > 600000) { r = { n: 0, since: now }; hvh_rate.set(ip, r) }
    if (++r.n > 60) return res.status(429).json({ ok: false, reason: 'rate' })
    if (req.query.debug === '1') {
        const trace = []
        const list = await hvh_fetch(trace)
        return res.json({ ok: true, found: list.length, trace })
    }
    if (now - hvh.at > 60000) {
        if (!hvh.busy) hvh.busy = hvh_fetch().then(list => { hvh.list = list; hvh.at = Date.now() }).finally(() => { hvh.busy = null })
        await hvh.busy
    }
    res.json({ ok: true, list: hvh.list, at: hvh.at })
})
setInterval(() => {
    const now = Date.now()
    for (const [ip, r] of hvh_rate) if (now - r.since > 600000) hvh_rate.delete(ip)
}, 60000).unref()

// ── GET /moon_pm.png, /moon_gs.png (and /moon.png for older scripts) — the scoreboard moon of a Specter user ──
// the detailed moon, 64 x 64: lilac for a user of the Primordial lua, green for one of the gamesense lua; the script saves
// them into the game's panorama icons (specter_moon_pm.png / specter_moon_gs.png)
const MOON_PM_PNG = Buffer.from('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', 'base64')
const MOON_GS_PNG = Buffer.from('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', 'base64')
for (const [route, png] of [['/moon_pm.png', MOON_PM_PNG], ['/moon.png', MOON_PM_PNG], ['/moon_gs.png', MOON_GS_PNG]]) {
    app.get(route, (req, res) => {
        res.set('Cache-Control', 'public, max-age=86400')
        res.type('png').send(png)
    })
}

// ── DELETE /configs ───────────────────────────────────────────────────────
// Admin can delete any config
app.delete('/configs', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    const { name, author } = req.body
    try {
        let configs = await redis.get('specter:configs') || []
        configs = configs.filter(c => !(c.name === name && c.author === author))
        await redis.set('specter:configs', configs)
        res.json({ ok: true })
    } catch(e) {
        res.status(500).json({ ok: false })
    }
})

app.use((err, req, res, _next) => {
    console.error('Request error:', req.method, req.path, err && err.message)
    if (!res.headersSent) res.status(err && err.status === 413 ? 413 : 500).json({ error: 'server_error' })
})

if (require.main === module) app.listen(PORT, () => console.log(`Specter License Server on :${PORT}`))
module.exports = { app }
