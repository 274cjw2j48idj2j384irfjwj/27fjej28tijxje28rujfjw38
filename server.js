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
    gs: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAE4ElEQVR42s2XW2xUVRSGv73Pmen0zEhpZjoElAb1QW6GIBQvQDAWL2giGB98wERUIoaYGF8MD8anRiEhEB/UF17wmgAmJZootwgJNChoFBQBL0BLBDoMSNuZzu3s7cM6Y6fl1EIo1f1y5szZe69//Wv9a6+tkKGCp00mky2u66601rYCzYBb8/16hwUqQKdSak+lUtmUzWYP1dpTNS8qnU6vBV5VSkUBrLWMxlBKTFhrS8A73d3dawJwKMABbFNT02eO4ywzxgD4gL4Bz8OYMICjtcb3/fZMJvM0oBzAptPpdY7jvGiMKQWGR9N41VEtJNiy4zgzPM/zcrncTpVKpWZrrQ8HKEfb8L+xoYwxc51EItGmlJpTA+BmDwVYpZSjlHI10Gol28bCeHXowGarC0weA9rDWACY7AYqGB5qNSusxEgx8C6CuXpuVb2B+rAWrAnd3nGH1648831gKjJTaTA++L6819UPzFMa+vvkm+sGmeYLyEhU5oaVlVAASoNfhkoZ7p4PM+6H1K0QrYP+HHR3wsnv4Y8jYlApKOZh5nyYsxjGp4SJ3suQ/ROOH4Lfjwbu2hEAKCWGYx6sehPuaYX6hCyulEC74EaElbdXwA/7ZN3Dz8LyNQJSO+BXwIlAogH2b4e3npN11l4DA9bAyjZoeURoPXYQ9m6DS+eFykl3wIKlEK2HchEmNMPjLwjlR/bD7k+h0AeJRpi1UMLgOFd7fxUArSHfCy2PwuwHIdcDZ3+F9aug55J4Zy0c2gF7twoAx4XGCQLMicDBL2H3NogFqd3xOTQkIVJ3LTmgBO3MB2RyJAq7P4beS9CYhkJOvHQ96PsLdK9s3HdFlhf6YMkKSE2E08fg3Ck4fxquZCWMYUoYBMBayeDxaXkvFaC7S7zL98LSl2HaPPldn5BEbH8XLnTC/nZ4YiXUebBsNRT7Zd7Zk9D+Ppw4LN+GgnDDCvU/VKlAZkqSrnkqzFokjCQaxYhfgVgCtm6UcM17THKiMQ3xcTDtXmieBm3LBWgkOjgUeqgC/IpIByAag0l3CvWJBvhkHbzxFGTPQSkv0gM5Wsol+HoLbFwNa5+HDavh6AFJ4ngDTL8PSv0i8UF5N9R9x4Ef9wkT5YLIq+k2uJyBrhNCuzUiNZTUgXgDTJ0roSr2w4Uz0LETdn0k/xk/UAEj5IAxQudPHXBgOzz0jOj+9U3Q8YXIMDUJYnGhMRZs7o2D196DUz/DL99ANpDr/CeFmWgMzhwXlYxYiAiy/4M2KBZg4VKYMh3umjMQu1wPFPLQeUKYKPZL1Zu1COYuBmMlnOUClIrw1WY4+Z0Ut6Hnh0qn0zasGhojMb59JkxtgeRE8SDfI6X4tyNCdbW6NSRhygwpUuOSskfvZTF87FuRa9iRGwqgCkIp8a5crO1j5Xe0bnBx8cvirTGDT0HXHQjZiDkwtCZYK9Wuzgsv17WbulGIxMIbMGOGP+7doAMetiewJrSEhwP2r7sx8TXQVa0/Y9gRVe11aWCPkpuDGUMAJrC5579vy/P5/Pl4PJ7QWi+w1pZvMggLlLXWEWvt+kwm8+H/4momzWc+v8XzPA9oUUpFVPVGOTqXU6WU0kDJWrshk8m8VE1Ep7ZPz+Vyu2Kx2A6ttbXWjgduuUEmqtfz00qpbb7vv3Lx4sXNtd//BthLDUK1Z7dPAAAAAElFTkSuQmCC', 'base64'),
    prim: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAFAElEQVR42sWXa4ycUxjHf8857zvvzOzM7JZaqlpSopjGxqWRICIq4oMImkoFIchG9IMgNhIJ+oHwgQZtCOLyCbtpKhFfaIU2cSmybttqpPRi7dq67E73MjPve87jw7TT1u5sp7HWk5y8mff853n+57meV6iJHHjqjcVXlwYmukvVLVN0IWhw2P6xioIkguwRsZsSX3mlu++OLw63J7UFj/KY7Fhy+pNGzL1WgpTTBK8JMyFGAqwEOE2qXv2zi7/f+dBqHlMAu4KiXUGRHcU96zNh4c7YT1jvY6d4AZGZIKA49T7xioaZoHDJ4PHZjuX7Orrb6TF2Gz164pJTn8qEbXeWk+EqiEHEzJTxAxGWmk408eU4HbYWB+Z+mu0ZuuV9WXn2G+eJlS9BVVHzL+LdtEME8SCiTi80WLfKmsgonlkwDiCKx5rIYN0qA2aZ11gBw+yJqdk0ywLQBV4TmZ3DH8qJWoXpggDETknRCiICenjVgqKoV1Sbw3qn0xGxQaOt0eFK7c/CEYqNNWSyATYweK/TYm1gyLSEiAiqUxNpSOC6znPJt0Wg4A+cOK46BnaV+PbTXxkvVYmyAep1Smx5PKZ/5zDffTZAXHWEKTsliYYEru88l7a5mSn3+n8aYc39H/Fz3++ks+G02B29Qzx1z0bGRqrYQPgnh4aZv3+4gks8+4crrH/xG95c8xXffzaAemX+olZWPXEpxhpUayFwiWd0uML6F76hZ93XDOwawSWexee1c9XKsxgfrWKMad4Dxgg2MFQmYrqf72VspEKuLc0z717HvFMLLDxzDiefVqD/5xFMUMOWJ2J61vYy1D/K9i8HeeS1q3GJ56SFhVqSMjkEpslGirGGajkhiX29SxtrjtApIoSRJZsLaT8lX0/EX3YOH3sSHpR0JuSK5WcyMRZz/mWnMH9RKyKwr3+Ugd0lwsjWSeTb0jz0wpWICGd0nEBcdXy9pZ8P3t5BNp+qV01TBA6OolxbROfqi4/Mj78qvPToJ1QmErL5sP4+lbYUL5pX/136s8yGl77lr6FxCnMinNNj90B5LObzjbtxsSeuOn7dVWLrB7v5be9+MrkQ7w41pdKfZZ7r2kz7/By3di2lcFyah1++igeu3cAfg+NTlmJDAgdxo6UKa7u2MDEeY22toUSZkExLOMml1Yqjb+sAH+6pkbv1waW0FFLccHcHz3dtJkoHk7zQMAm90/rp8nMiCvWVJkzZI4zXsV7JZEPa5+d4/80f+H1gDJd4Lr1mEQvOaKM8HiNGmiPQ0prCWCFXiPBece7Q+qcb69jWCO8UYw0jf5R5740+bGDI5lLcdN8FxLGbdM1pGILXH/+cbD5FZSIhqfoD/bwJbOxRVbK5kA/X/8hYqYoYqJYdLflo0nCSlUten1LtxGiM94oIZHOpaad1I6yqMr4/rldVNp9qvgpaWlP14Tb9SG2MFSPk50TT6glA3VR3gqMZbQqrR9OjzoDsNRIoDSP8n9xLtWZT9hrwm4yEArVb6SyJr9n0mwzOrnO+4qVWkbPhBRUMzlc8zq4zb22/rdeRPB0FBQsa/8ckFDSOgoJ1JE+/tf22XruCbnvO0M0bfzt+a0cmbC0mviKoOgSZua8jVRSPiMkEbbYcl945q+/2znaKxm6jm4+B5fs2dA/ObckasUsDE4UgojOUFkZCCUxkgGrsK88s7vupczWX6zaKKv/35/nflWiT+6t53iEAAAAASUVORK5CYII=', 'base64'),
    nix: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAFbUlEQVR42s2XW2wd1RWGv7X3zBybJCexjWODcsGJw0UWNxW3AqrGiSuERFER0EpIlcoD4gGDQCAQSAjSPkDaEq4NpRf1rX1IlICEBFJJUu5IBBFESAgBEhKbxIkd29iJ7TOz9159mIN94mOD2iaG/TKaWTPr/2ft9e+1lgCACgiAsv7VdhJ7Cy50omEJaETZ+D8sBXGIOUhktpL6v9HVsT33p4CogAoKrFkjNK9ai7V3EsUJWQrecUqWjSBOwGUp3j9F77/vZ80aRUDYsMGy6xdK82ubmLfgOoYHQNUDBhE5JQRUFQiIWIr1MDL0Ar0rb6BtYxngmS2/p77xXob6U0Ti/yPk374lqhkLzkwY6PsDd/z0PuHZVy/F8B6KosGcRvBJEmICghC4zBB8F0mNIQRmATzHCIEc03cZhE6yVEENs7bUkKWK0BkhshjvBJHZwxcRvAORxRFgq1Qjk3xUwatO2IwIpmzzQdEp73/9bDpfQZWgVQKt2iF86sCH8isGSSyquS1knuB8bksiMIIfz3KmAiTxRCaJCD5z4Mq+YguRoZLhSQSMQMgCP1/RxCVnzkVE2HnsOJv2HiFKLC51rFzSQMfZCwD4y+5D9B4vcfcPW5gTW7KgPPFhN6XMY6zBlxwdSxtYefYCYmN46eAx3u4ZxMSWUI7qFAJCcIFfndvEjcsXApAFZVnvMIdPlMAFrl5Sz/2XLgXgX92DHO4/TmwNv2lvAaCxNububXuQBM4q1rD56gupK0QMZ44/f9SDGKEyBGa6LfgqdbigHM88sREebD8Hn3kwwonM44LiglIKAZKIte98zqZ9fShw10WL6VzeiDtR4q+rLqCuEOGCcu1LO+keOIGJzEl5MK30rAiREQo2N998XjNtzUUk9cTGEJncPuEksdz+2if0j2UIsO6KVu758blcs7QBgD/u+pLX9/URnZHgp2ShmaGEAXB0LGVLzyCFcog1hGq1qhJFlt6vxuh6cy8AFzfM5bHLl6PAx4OjPPDWZ9hCXAU+I4HKSPz2vS8YTh3XtzSybFEdQ6XqCumCEtXGbPzoS/756REUKPmAD8qvt+1mPHVgBZ0G4xsJFBPL9qPD/GnXIUTg4ctaZnSiXjmjNmHF/NpcjcZgBH7QOA+CzojxjQS8wtzY8tiOA4yknl+2LuTGZY3VTozgSxmPXNlK+8IiLihDmcOI8OSVKzi/qYhP8/v/ioCqMie29A+O8tTOHmqs4Yrm+SdHwQjpeEZn60LuvHARABv39bF68/tkQSlYw99XX4ARQVSrqt20BILmMnPlqySWxz84yJGxlCwomQ/58zwBmFMT89xPziOo0j+Wcd9bn/JBzwAPbd8PwOVNRe5tb8GPphgj305gXhwRGaG+ECMCag2DI+M8+v4BYiMkNpdibASjyj+uaqN1fi1GhK439tIzOEoyr5bfvbuf1w8PAbD2R8tYvaIJnzpsxVZEU/+cyPD0zh5ePniMLCgD4w4QpBDx3K5DDIw7bPn7PUOjxHMKvLi/n837+hhJPc9/fhSpiXCqqMBNr+zmqkV1iEjuX4TKciU8u606RZ3PM/DrglMZtUoZJhZEoJTlR6iAJNGkeylncubz08WY/JuZitHEvsQRJpnUeKU/WxtPqqRceqOaJG+0p5RuFMQKNorLEWaiCFUS8FN7gmnq9sQJ6aYxOFXQmZRUts+gdINqNzbScus8Sx2Zahmz26BsJU4EJMxiTxaIE0HZajB2Pel4wBiYMZCnuC03hhzTrjfc1rGDzK2jWGdRzU4ziXwwKdZZMreO2zp2WDZssBz42RbiPRdTrG+jNCbl0UxOw2hmmN9gGRl6gaOrbqWrzXwPhtPveDz/DwzmlLFx5qK0AAAAAElFTkSuQmCC', 'base64'),
    nl: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAEB0lEQVR42s2XT2hcVRTGf+feN+9NJk0xQwWLVEgRxAgSIQp1oxAXrRtDW1256EIXUmx30oVg7MZArZiUoqBboRAKbkSKjUIhCFboQihWEaXBaJs6UzWZeXl/7nFxXzNTMpM/OI0euLw37/775n3f+c59AgAq/irKscUnseEruHwM9CHUBUDRv+VQxGQg1zF2ljz5mOn7L7fvJ6CCAhMTQv34JNYex4Yh2Qq4lJ6EKUEQQZ4k5PkUg1MnmJhQBIQX1TKMUq+dp1Idp3EL0BwwINIbBKqAA7FUdkGj9imD1UNcRQwzklO7MUl/dZzlxcQPFtu7zcGvJRZUWV5M6K+OU7sxyYzkwuv1JzD6LaiizvwLvreiCwciOBk1kBylVDH+rd/zzf0emkOpYiA5ahAzRhar53zbwpDFipixANiDS2V7/nybJnyG7QkA22mINS1ICuSuDb74BpBrIdtiTqfx64QNurBE3lTIit8BSFl8Mgm4RHFJ0dcnYH3iZsu6Op6yeCQbxBoAptjghdGIkQcDROC7hYzzl1cI+oSsqTwzHPLswyUAPvo6ZmExZ1fV8NqBCkbg2s2cc9/ESKkAvXUA8PJoxOGRCIA0h72/1PjttoMM9j8acuK5PgAufJ+w8GvGAzsNJ5+vAPDlDynn5mJM6ClaX41dKPizqWQOllaUkoU391fIVxQMLCe+L3MeHOLv48xfbzd105rumnrWQGAgCvxKR56KeGwoQGKlVPQFbWYttJ5Zs5V87GpXPm4uOS5eS4kC4e0DFTTTnpr0hlitwMkLDf6KlYOPR+x9JPSveLsA7CwLl69nfDAXIwJvHejbUNk9BZAr7AiFdy82+DtWXhqJODwSbmD2LbO607rRtiEAVegP4dbvOVOXmpRLwtNDpXU9JnPgYiVdUVzRNNXN+cCdcMpqqmXOO+F7s01e3VemWjGogjEtsWrbnH1DARfeuA+xQua8jr76MWHyswa2LHd5Q9AtBQYiITBQrQgioCWhXne880WT9w/2txYwfnxgICyqyu6dht3Da2mazBueivUAOAUiYfpSzOdXU9JcqTX8DCkLH841qTUctiD1p0UHZWG+7jjyyRICOHRVqE69Bn7+w0Eka5xROLaoHVW0UhQjKQpLe2lsT8OyL0bkQKzrm360tkB1pcBEgim3RNV+urM7WpLOXVGOzd3PO4m5U10ICuy2ExVOOztk5jb/fKMsN8A8plQcK7YrVP2ezBvUzRKUvXa2LxxBWVA3ayA8S9pwiIVNnWF6cSy3kDYchGcNZwav4JLTVKoW1fTeUqGKakqlanHJac4MXvk/fJrhmEAZnD5Eo34KGyaEAxYT9q7qm1AIByw2TGjUTzE4fYgJlBmc/Nef5/8A28HfqgGBWhkAAAAASUVORK5CYII=', 'base64'),
    ot: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAEZ0lEQVR42sWXW4hVVRzGf/+19pzbzD5TYZb3NBNCo4SiIiFjFCLMjMKHCuxBepHoxaCesjclhQJ9KKQHe4nKCAvKB6MXFVNSFDEqiWbK8JKDc+bsc87ee61/D3s7M2fG42W8rZe92Re+b/2/71v/tQRAQQAEVD/gMQLWovShzEYJyN9PYihCitCPsIeU7fI2B8fiiYKgwAaEXjZieAtLgRRw3JhhgQBwxHg+4gLvsAFFQPQLLMdRquykh1XUAMUBBpn0zMfXQQGPYAmBYb5hiJdYiBhZjaObjYSsokacl83eMPCs1oJgAaVGTMgqutkoq3Gim1mM4RCKopjr0PtafOERBM+jBs86Chh8zvXmD8FDjrnOYOgjQREMt2oIhgTF0BcAs3C3ZObtFLKEzQrykHQQC7zP/8gpes3u7RjKTkH1ynMwopj2z2zQEfwiUDl/kBMxNrvX1igpWwACzRh3njPEQNrutKAjeADOwa6j3ewbKHG6brFGmVNNWXZ/gyVzm2gCYuD7ExWOny1Q6lJUwfmMiwDWZESbifDs/IhF02J8wkglJhDwCiaAU7WAtbumsK+/xHBiCERHyr/1UJXXHhpm0/LzFArK9sMhXx+pYioO7yEseEQg9UIUC8aCr1t6Xj7NotkxLu5AQHOtYye8sWsKe/tLhAXl9Ycv8OLCOlFi+PhglZ//KfLJL1V6i573nxtk5YKIGdWU7oISxcLukxXqiTA9dCyd28Ao1BNh8T0tSNv900bA+0zz3cfK7B0oUe5Sls1r8OEL/2V9IYAlM5v07ZgGtYDPjoasfaTGmsdrrPHZ++aQ8OOfZWqxZd4dLTY9fz7T3gBJ5oOxRrxk9n/6q4yRTMtXF9VQhbgptGoQVj0rFkQ0U2EoNhw4VcR7aEaCa8Bg04zon3hwEaQNSCPQdOJS11YBkczhp+tZMstdyrQeh3gITOYBVZhTTZHcrP8OBxiTmc2a9vJeNKGa0cRMiOYlEyOjpvBMTJcfl+3rGWZ8/LAwI0wBiFKh/0KAWEic4HxG7o/zXSPgs6rp5fN/LQQuTm/53AYKFCx8eiREEyh2K8UqnDob8O1vFYqBclfZ88TMFiSTr0SbB6wB34Jn5jdYMT9i56/d7P+7xCtfTmXlgxH1WNhxJORMZBlqGd59apCpdzpco93Z1kAwzg9XRWCkHytsXXGOwCrf/V7hqxM9fH68B4BSoNxdcbz39CBvPjmEb+VG01EZBxuGc5FhqHXlBiu6eaKCqiA2E+hAf5H9AyXO1C3WwOzelKX3NXjg3iTrB+PYNxPhh5MVokSY3uNYOq/R7tqrITBiSEAKeb/UMRlOaVvPJ5SwkF993oCuRYLxUfRx3oLHLNdGOoDnH7jG6LJ+JR8E+ebbdu7hlwHrtAu/+r2VM8AAFuW60jyJjWmGOWDw7KELQS9nlRsO7+lC8OwxGLYR4/MlSW8JvIEcc5uR9RwmZQshNm+YelPBISHEkrJF1nP4th/Nbv/h9HYfz/8HXjnle/ZS6kcAAAAASUVORK5CYII=', 'base64'),
    fat: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAD40lEQVR42sWXT0xcVRTGf+fc92bmMUOhFLqyJN0odmeiiTHu2PhnQyRduDRhUWThUtOFmYULkqaLxlS7IMa4MFFi0sTEjSEudKM1aY21RRa1gJAGClTKMJ15793j4g0CAjO0pfQkk8x79773fff7zjn3PgEwEAABm3l2+KXQuaHUfL9Br8cCGuOPEKZIIjDjRCfiNB3rnfr0ylY8yS6MMmUZ6lsYDXDv5VRzNUuJzXMQEYqSF0fd+3pCemFs8vgHZcoGghinHZyyv/sWvzkWRAOLyToGKaDy6CvfLgMY4AVcT9DGUlK9/MxkzyDcEBXG09t9d0a7g2hgIa7UDUzAHRR4Q2oRcAa2EFfq3UE0cLvvzqgwnspfz595ITT91cA8phwgcJO88AISi39R8YxEGmqKcQjgAJJiRBoqnhFVkf6aJQYohxdas8RUpD8ATsTmRQ4RXUAaFXYiANyeM50iIlke/+dO9t/MIPV7zNnF+DTNpvwPIWjG1N+rZCC7FrdDiwX8yhp4a615ewSB7iDRlMCRM6/hOktgtgliBiIks4tUvr1Cx8ibaLHQ6KcCqpvzthC7//VP+IV7ELptJJoS6Bh+HXfsyK5j8dQca5d/4ejZ0/vyvfrjDWpzd5FckJHbDwG/XEE7ili1TvWH3yFp+KgQT82DCquffZ/NqcWEvT3kX36uQXCe2rVbSD4EM9K7/0DgHs4CVJDA4VfXWRj6GFurZi/xhpYKaFc7yx9+CSr4lTVKb73C8VdPZSue+I2l9z9He45A4tFiYcfqWxNoJLUUC3S8+wZWizOfgfof09Svz6BHS41dQ5BStPlolEO72rPxxIP3u1VBKwIZmHYW6Sq/vW1o9ZPvqP08hUQ5SBsl6bdUjG/c2/jtEUGrbQzAHsTUrt1qgBioUJ+a25T0MdpYCwIZA79yn4V3LmCVB+Bcdj90SKmQEXJPisAWK6SYzyTZIGDsSKiDJ7DVQ99oLGJ7A2+0540ceFwC2tEGTtHOYuuN2gwJA3BZJ5S23L4Uakpg+aOv0PYIq9axWpIl224v9YZEeWrXp1k6+0XWiP6cR4qFlkrIdN/wnjP8WjUrMRW0FDVXQQSLE6xSyy7zYVaiLVRoYUFxez7swwLpCnfdjJoRSPc8E6QPeSw3yxTbf6QKzIaiG4V1KGFgoagBs+rNJvISCOA5vPB5CcSbTSjKxaqPvcsy7DBUMIdQ9bFHuagnb166GpOe7w4iZ2bxk7TCwMws7g4iF5OeP3nz0tWn/2kG4x7KNjbZM7iUrJ/L4ertGrqc6IGd1HOi0q6hy+HqS8n6ubHJnkEoG4x7edqf5/8C1w/siwNWZbAAAAAASUVORK5CYII=', 'base64'),
    aw: Buffer.from('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', 'base64'),
    pan: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAEpklEQVR42sWXTWxUVRTHf+fe9+az01JaCQXRAAURE5FUNCFxA0ETExMSIjGa6EZXLFyIiTsxbkiEhQt2biQSCcSPxLAEwS9M0GAU+RAoCBQoTvmYlk7nvXfvcfHa0mmntEQsZ/OSuf+553/P/5xzzxUAUEm/oh+9dnZVYMI31bu1qvqI4gNgeP2eTQWTiMgFMXZ/4uNP3t21+MhYfwIqCmx5f4u0nH59q7Hh29aEmcRFOB9zP8yakMBmcD6OvIs/vrVk53tbPtiiAsiel9X+uRxtPt39RVO+fX1/9R8UdYARRO4HAUUV8ILYUv4hBqrlrytLFm144jhiNu4VVzx1emsp376+v3otAlVB7P1yDiCICGJBtb96LSrl29cXT53eunGvONn2yrmVxvKLoqrqzX/Qe/p5IcYLIt7xtPGSbMrYvPHqmAHnAOLVkbF54yXZZIzI2tjXVMAwQyZgYl9TI7I2ABY4H8vMHH6UggxX2IIAsBOXQUxjQuqHc3oqrKa4sdhGFRo0cp5ESlxzjYgThEKYE9TfDSuIgSAUgqzAXYgE453HNaVjSZbOruLIQVCfrlcrjp6/hrhyZohswRBHSkdnjs6uAgw7cIkSDXkGbjiunatRvhQRZg3GNiZRT8AIceTp6MyxesPsSSSAI/tucmhXmSRSOjqzk2LjIc+JnwY48GmZuOaxgUwgMakE3qUaXjhW5e9jg5RmByx/rkS+ZHnmpVlc7R7i13238Amj2N5zNa6dr9HcHvLwshyZvOHJNc20doTs+fDy1BEYS8LYNLG6fxvku8/7sAH09UQ8/9Yc1MOiFQWOfHOzDnvihwEO7irT1BrQOjdk/TtzaV+QYcHjeVa+0MLhr25QaLZ4d4eJmUbNIibVLxrSOrnGV26YFQrNAfmSofd8jQM7yxibhn3ps00EoaBep47AmEpi3tIcK9e1UGoL6HpxVpr9Bi6drE7oHKqpHC6BfJOhrydi6LYnVzQ0tVoyeYNLtO6WmYKAsmx1E8tWN9X9fuLHAY4d6idbtHivjcMG6RUkd8hpgyQI7t6v4MqZGr3nathAGKwkXDxe5ezRQcLMRAnSpgRGoHLLs7grR7ZgUIVKOSEa9GQKZrSsp0FAOP59Pwc/66M4y+ISxVjIFgxiZbT2RyyJlajqyeYNS1YVWPNGG94pxqb7eA+CoGP+GEym/Uhog4xQaLHkSwbv0zCqB9F6rHp4al0LC1cUKLZa5jyaHd3v5M8D/PFthVzRTJAsaOQ8CAUz3N9tKLhE8Z668pmANTB7XsjseeHoeqWc8PuBCoe/vIEJhEbdWLa9ekbrmlCstM3PMP+xHAC93WkOBBmZcAmNxY6seZfKcPum4/rliP7rjlzRIDKNVjxyor6eiKvdtVEJwszEFtoIW9/IIAgNhVJaKdO6jMZuHGZNw+t3UqwOl58Oj6HjcmkyCwA3fiZQBXU6vQHvHrANzBngojXh1KPD/Z1LNfXJReNV94cmKwp+xtyDD01WvOp+YzTYEbmqN2IBZiIKasQSuao3Guwwm3cvPJq4eHsp12ZB4/9XClXQuJRrs4mLt2/evfDoA3+aPfjH6YN+nv8LI2+SDyawwlkAAAAASUVORK5CYII=', 'base64'),
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
