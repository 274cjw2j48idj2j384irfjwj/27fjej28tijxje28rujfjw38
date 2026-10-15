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

// ── GET /moon.png — the scoreboard icon of a Specter user ─────────────────
// the crescent of the watermark (accent 180 160 255), 64 x 64; the script saves it into the game's panorama icons
const MOON_PNG = Buffer.from('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', 'base64')
// ── GET /reveal/<key>.png — cheat revealer badges of specter_primordial.lua (tools/make_reveal_icons.py draws them) ──
const REVEAL_PNG = {
    gs: Buffer.from('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', 'base64'),
    prim: Buffer.from('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', 'base64'),
    nix: Buffer.from('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', 'base64'),
    nl: Buffer.from('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', 'base64'),
    ot: Buffer.from('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', 'base64'),
    fat: Buffer.from('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', 'base64'),
    aw: Buffer.from('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', 'base64'),
    pan: Buffer.from('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', 'base64'),
    ev: Buffer.from('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', 'base64'),
}
app.get('/reveal/:key.png', (req, res) => {
    const png = REVEAL_PNG[req.params.key]
    if (!png) return res.status(404).end()
    res.set('Cache-Control', 'public, max-age=86400')
    res.type('png').send(png)
})

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
