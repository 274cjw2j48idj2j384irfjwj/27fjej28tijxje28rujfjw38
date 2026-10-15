const express = require('express')
const cors    = require('cors')
const crypto  = require('crypto')

const app  = express()

// a variable pasted as NAME=value or with quotes around it ("value") still works: both are cut off
function env(name, fallback) {
    let v = String(process.env[name] || '').trim()
    if (v.startsWith(name + '=')) v = v.slice(name.length + 1).trim()
    if (v.length >= 2 && ((v[0] === '"' && v[v.length - 1] === '"') || (v[0] === "'" && v[v.length - 1] === "'"))) v = v.slice(1, -1).trim()
    return v || fallback
}

const PORT = env('PORT', 3000)

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

// pm_*: Specter for Primordial (specter_primordial_loader.lua), nightly = everything, beta = no resolver page
const VALID_PLANS = ['beta', 'nightly', 'specter', 'debug', 'pm_nightly', 'pm_beta']

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
    if (!VALID_PLANS.includes(plan))
        return res.status(400).json({ error: 'invalid plan' })
    let expires_at
    try { expires_at = parse_duration(duration || 'lifetime') }
    catch(e) { return res.status(400).json({ error: e.message }) }
    const key = gen_key()
    const db  = await db_read()
    db[key] = {
        plan, expires_at, hwid: null, note: note||'',
        created_at: Date.now(), revoked: false,
        last_ticket: null, last_ticket_exp: null, last_nonce: null,
    }
    await db_write(db)
    res.json({ key, plan, expires_at, note: note||'' })
    console.log(`[CREATE] ${key}`)
})

// ── POST /admin/revoke ────────────────────────────────────────────────────
app.post('/admin/revoke', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    const { key } = req.body
    const db = await db_read()
    if (!db[key]) return res.status(404).json({ error: 'key not found' })
    db[key].revoked = true; db[key].last_ticket = null
    await db_write(db)
    res.json({ revoked: key })
})

// ── POST /admin/reset_hwid ────────────────────────────────────────────────
app.post('/admin/reset_hwid', async (req, res) => {
    if (req.headers['x-admin-secret'] !== ADMIN_SECRET)
        return res.status(403).json({ error: 'forbidden' })
    const { key } = req.body
    const db = await db_read()
    if (!db[key]) return res.status(404).json({ error: 'key not found' })
    db[key].hwid = null; db[key].last_ticket = null
    await db_write(db)
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
        tamper: Array.isArray(v.tamper) ? v.tamper : []
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
        res.status(500).json({ ok: false, error: 'redis: ' + e.message })
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
app.get('/verify', async (req, res) => {
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
        loader_gs: loader.gs, loader_pm: loader.pm,
    })
})

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

    const raw = await get_script(plan)
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
        `rawset(_G, "BUILD_VERSION",    ${JSON.stringify(plan)})`,
        `rawset(_G, "_server_url",      ${JSON.stringify(public_url)})`,
    ].join('\n')

    // burn ticket
    license.last_ticket = null; license.last_ticket_exp = null; license.last_nonce = null
    await db_write(db)

    console.log(`[SCRIPT DELIVERED] key=${key} plan=${plan}`)
    res.type('text/plain').send(prefix + '\n\n' + raw)
})


// the name shown on a shared config ("by ..." in the Loadouts list, everyone sees it): the key's note (who it is for),
// else a name made from the key's hash (a part of the key itself must not be public)
function config_author(license, key) {
    return license.note || 'user-' + sha256(key).slice(0, 6)
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
    const name  = typeof req.query.name === 'string' ? req.query.name.trim() : ''
    const part  = req.query.data
    const idx   = parseInt(req.query.idx, 10)
    const total = parseInt(req.query.total, 10)
    if (!key || !hwid || !name || typeof part !== 'string' || !part)
        return res.status(400).json({ ok: false, reason: 'missing_params' })
    if (name.length < 1 || name.length > 32)
        return res.status(400).json({ ok: false, reason: 'invalid_name' })
    if (!Number.isInteger(idx) || !Number.isInteger(total) || total < 1 || total > 150 || idx < 0 || idx >= total || part.length > 6000)
        return res.status(400).json({ ok: false, reason: 'invalid_part' })

    const db = await db_read()
    const license = db[key]
    if (!license || license.revoked) return res.status(403).json({ ok: false, reason: 'invalid_key' })
    if (license.expires_at && Date.now() > license.expires_at) return res.status(403).json({ ok: false, reason: 'expired' })
    if (license.hwid !== hwid) return res.status(403).json({ ok: false, reason: 'hwid_mismatch' })

    // the first part always starts a fresh upload, so an abandoned one cannot mix into the next
    const id = `${key}|${name}|${config_lua(req.query.lua)}`
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
    if (!key || !hwid || !name)
        return res.status(400).json({ ok: false, reason: 'missing_params' })
    const db = await db_read()
    const license = db[key]
    if (!license || license.revoked) return res.status(403).json({ ok: false, reason: 'invalid_key' })
    if (license.hwid !== hwid) return res.status(403).json({ ok: false, reason: 'hwid_mismatch' })
    const author = config_author(license, key)
    const lua = config_lua(req.query.lua)
    try {
        let configs = await redis.get('specter:configs') || []
        const before = configs.length
        configs = configs.filter(c => !(c.name === name && c.author === author && (c.lua || 'gs') === lua))
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
    const tag = ['nightly', 'beta', 'dev'].includes(req.query.t) ? req.query.t : 'dev'
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

// ── GET /moon.png — the scoreboard icon of a Specter user ─────────────────
// the crescent of the watermark (accent 180 160 255), 64 x 64; the script saves it into the game's panorama icons
const MOON_PNG = Buffer.from('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', 'base64')
app.get('/moon.png', (req, res) => {
    res.set('Cache-Control', 'public, max-age=86400')
    res.type('png').send(MOON_PNG)
})

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

app.listen(PORT, () => console.log(`Specter License Server on :${PORT}`))
