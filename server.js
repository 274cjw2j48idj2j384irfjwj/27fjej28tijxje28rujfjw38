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
    nix: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAEx0lEQVR42u1XXWyTZRR+znnffutKu25lfw42Ohg/MUGQOVwcxEEGAxxTBBVwZCzg1JjgpYm33hsNV4qZfyNgApgQTfxBSVggA6I3DhEhOteVgcvoOraOffv6Hi86oIOVFli80ZO8adqcnvO8zzkn53mB/7pReg8CgehBggtEIHL/AIgVW1n+OmVl7yRwhTD5AVb3l97EyUhUxFyMOzfa7RuD34qJm7QAWGfNyPYWf8fKekpgAHl4jgkME7c7R4ev1BlnbCQlAGLFHt+sM6ytShEnBrB1E9c9KnQvlidubGwi7TGOfTY2FK4Wuc3EpMAut38966ybyT0A9MThqQ4RsUjiM4XPxP/ZI+LEWGdVudz++kmMJ3/RruyXBcYArNMxqxQjL9ePkkeK4XJpUNo+ZUtgjLY8LVMCIGIQuAJyC3nqUMyAAJs3NeD9d99Bjs8HpdL2KEPABAomCLubARJif/qpJIgIiooK0NK8FevWrsaG9XVgJijm9KOZyEFTlgBEGY0aM8G2x9Eb7gMAtO7egdLZsxLMpL+BStkDmZjWClprjIzE8FHbfkSHrmPJ4kex5fkGKK0yKQUeGIDWCpbLwp43dqP26RqcPvszjnz5NQCgueklLFo4H0SUQUM+AIBEYEblssfw9ltv4tVXdsDtdmP/gcMIh/tQWlqC5qYXkZ3thlI8/QCUUvD5vHittRlaa6ysqUb9mlqcv3AR7QcOAwC2bN6Iqsql98UCZ9Z0DCJC3aqVqF9TCwCwLBd27dyOwoJ8HDryFbq6ziPXn4NdLduRk+PLuBc4s9sziosK0Lp7ByzLwi9d5zFwLYJljy/Gc43rEb7ch7ZPD8IYg3VrV2F17QoQUUZTwZkkZ1Z4duM6LF++DGNjY3hv74f44XjHRPO9gIq55fjm++M40dEJy7LQuqsJxUUF0wOAmVEeLENL8zYQgC8OHcWJjk4cOHgEAwPXEAyWYdvWTRgZiWFfWzuuRQZR/eQTaGyoh1Lpx1IldTm53P49RBxAYgmT1gou7cLrrc1oeGYNotEhnDx1Blf/7kfXuQsIBPJQVbkU5cEyuLRClmWhqDAfJSXFKCudjR+PdyAyGIUk1qUARAKJODeie+/a80RMnrzgJW9gnngDc+O+mfMkt3CBbGjcLoPRIUmYERGRjpOnZeHiGqmp3Sh/dvdIKvtg32dSMmeJ5ORXiDcwN+4NzBNPXvASEVNGJdBao7GhHvaYjb96ehEKXUZPKIzgnNlYUFGOc79ewL62dly92o/u7h70hMII9V5GT6gXoVAYq1etQDBYCsdxUo4lJTOQ7S/9jVkvAMQAYMtyobAwHzM8nlu1FAFsewwDAxGMxEbh9c5AQcFM6Em1JogY2PY4+vsHcH14GCJiAGJjnN9Ho6FFIkZwx9oVEhNNRjduj6O3t+8u9BM1BRFhcDCKSCQ6pWwVkVvb8/bKNVEkNQDfdjYQSDcI5qaUkqRAyQd3/J7QvzKlX5K/A4IRyB8iZuoxdOzYxwRmwNjT/wIwDoHZGY99nlqUkmJPzqxO1lZVpqI0XdY7ROlPsevh5cnyPJUsP8bKqp5mWX5qdPjK2nvK8kkPE3duvdLuJiKe/1APE5hLcXv0E3sseiyjh8m//TT73/4BqsYVtcGhFk4AAAAASUVORK5CYII=', 'base64'),
    nl: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAEFElEQVR42u2XS4xUVRCGv6r7GPoxdgQcA2gyPGY2E8mgDhKXSgR1RWLEqAt158KNC+OOaIwmhrA0PhLFR9wrgUSCoHFUxGAMjpDImw0xMGSaTN9m7u1zykV3z3TPi55hcKOV3MU5996q/1TVX1UH/usiHX0inXw3ixgGtggAohrE+a0E8QsiukHMSiDBAq07Eymb+dO49AuXJt9g3t8UgGhUCHJ3HBSNHsZs8ii35GARzGdHXfX6VvNZZU4AIqpBfvkx0eABzBIgbrzSRSJonjhFJG/e/eqSa1usxRNtijXKPy4aNo3ngbDx6CKf5v95zBLRYEij/LY2m214w/g5zHzjp6WWGMMTxi/ODkAEEd3QgnypRQEV0V5kKvJhWwqYlZCZCaeqiAhmhm+ET1TRlr3p67l4WWcU0szsaSedhWrmmRhPwNcgiIgLBcw50moCWQYSEBXypEkFajXQgKhQYIpBM5jRZmNuV4sg2QSud5DBR7bTX4BLvxzh6I/DBHf30vvoDh5aU2L0+HccPnGO9U89zVBPgcu/fc/w8M8EUYTZQugrIlF+5Zmo2GNRscdFd6yyXFwwhp6xvRfNzMxGx67b2t5+k+UD9vK3l83M7Icjh407B+zV4atmZrbvwEGDZbastMoaumxSZ7HHovzKM8hUEtyc32ZMpA7nUpaXunnnrV3YjQTnPc45xscrIJDWavV1pdJZhV9IgVEVgiCmmtXY+exO7n9yO+WxMkEQoKpNB7atlxRAM5QH/g5wErBn12sU4qjzfjaPdMR310Bw+NgI5Wo/Lw30Uu5O6wq0HYBKfS9UEAKc9/MmY2f+avC6+PvXvP7xfirAE6tnb1OVzFPzKeOJo1ouk2UprYVn4QBEJ4tLKfRc+egN3j05QRgq3vt65a5XUbz3bHxwM29++hVvf/Yluz94n751a3ETE6jKYkIgkN0gjmNUQbtXIKMn2L3nQ3a89wqDMcTLcpCldMUhqsqmdavZtG71pIZD+/fx18lTSC4HuHkGEhGJcitOo7q+0UZVzPBBTN99G7mnlOP8xUtcOH8WHxe5d2CQ/lLIlaujjPzxJ2sGBum7q5us5iZLsaowMnKK8tgYGobezBTvz2bV0b5mYswLoBnlLEnqeRB3EXV1Ib5Rij0QBET5PFlSATezB2guRxCGNLrsDADh9DFqtjB0FbsRkUbMDZOArmIJESbzIy4U0VmSzc9gQbuNsI3uImWZalRtSqZ3Ne/dtJ7lZ4nwzMOYSLnVgLZWGzN/oeF+fxvmgRrgzfy51k7ZTsNa+gmCAultASCi1NLPbzaUHhUNhm7TUHrcJdc2tw6lc43lh0SjLUs8lv/kqtcfm3csn3Yx2UYQPy+ifbd4MTmDS/e6NDnU0cXk376a/S//AAJ2ALNoDeoVAAAAAElFTkSuQmCC', 'base64'),
    ot: Buffer.from('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', 'base64'),
    fat: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAADfUlEQVR42s2XT48UVRTFf+e+V9XV3QOD4sKFEjWYuDQhEOKaSPgMuNCPYPwWfgeiiS7duVKJ7ghhwloTDRh1I4nK0DPdXd3vvetieqAGpqV7+GclN6nUn3dO3Tr33XPh/3vouaz1WBTJFs+tS8gB3L2sT80sWr/38oVYbXwYCKcx2xQe1oNXpuTtTPk5zXe/nLR/fVNKKo8lEEMzPL5x6tsYeu85jrs/WfIlhEi5vX5v9/cLKU12lxIwRTtx7K0bIdZn3NMYrN6/dUT8xReXmRQHObVbd0e3zxd/kAnr8uj3T14KsbcPPgDiImw/1DlfIRbv28A9jUNszvabkxe7mNYRDDEOL4MXsHjYX3UvZM9kzxTP+NIo99fs5LcGL1U1+OgAZlftgXDa3a17/T68F9wL5g44GUj4IyISwmRAQDr4h93djPiGZOxXR+zKBbPNQ6sC2KHwbq65Mj3F1CJTi0ysIlmPWaiZW00bahQ2+HT2PT+VPxmqoTxaYpsg7acgHmS/pNQcCoXG4Z0yoFVF8oZEQ6s+UzW01mNiDYRN+lTkJfX/MEZcV9JTg7HE2JwdJVrNaCVmiClCTJjj2Ir7Vlx3Sy0YA9Vc1T98Yj8y9Ip5BrLwOaDADi2NasrTJuCCIsMUGQN/sMtQ9ULPjiHMjWgRU3hGGVAgyYgKnKDHMa/J2lP/nEIWQFi5mcX199bASM45e5Wv7RIpNIytookvcWW+xVfzLU7YxkrpX4+AgyOKjCSjVs1rGtJaj93QowmvMEg9nLJXYM9GhJAVcAIjnDsakUhMfE7tFSNm2JqdO67ZYkkYjfX4jjt8nK6xkevFfiiyCkP1KWukIK6ovftpzQpIkSQx9UylgiMcMNnCwOjZZICFBlhEkBEUcR21W69BQDgOzBdfmZ8AdCkBR1n/ScJorEHqU6s+EqCjvISAO6VsEw63l4YYK3NTdxEttxlhRzFKpWzDA58Xu/2+kH4N6p1ZWFnrEmhUcYsxl/0HPO8RalThWllwSVLMpFtdp3zAks3n48/2FFZmh7hLTIHKKmqriVYhC2soviSQpTT+oot5iCl983qIvbPLTamvM7g8ZEpnN++Obp3rmtJHbXnsD48PX78aQ+/8U7bl1+7t/PZ+ytPdFQeTkxdjNfwgYG9j4YiDSdnO5F/SfOfzSfv31ZUGk+c9mr3w4fSFH/8C5XmOq9Zq+x8AAAAASUVORK5CYII=', 'base64'),
    aw: Buffer.from('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', 'base64'),
    pan: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAEgUlEQVR42u2XTWxUVRiGn+/cn7kznekMpfwVxfJTjSJgIhBE4wo0URPShRt1AQluXGhcmLAzrFhowkYWogaixkSjRJSqNSQkIKSoCEIjKCAQLBT565RhOnPn3vO5oJROW+i0JW70W07u3Pf53nO/c94D//WSWh4RqeW54aWKgo4dQMQY102sEOOvFsM81GQBZ4z6MWLzavW42ujjKCq1q1o7KoAxbp2fSH9vjLNcFUbroEYHsTbuCMuFFdZG128LIGKMH2R+NMZ9FNUi4N/kuvUyGcXzKuCbHYcikopt9FNY6l2mqnZEAM9PPet5yR16Qzw1tBPViDiOGOyL6i1B1/FwXR9r7UjOFUUkVakUn6mEfd8O/KfaAe9FVezQ328IxSSCLOn0FFDFEcEIGBEMIAKXerq5mj9PENRjxAx1w1fFGvHXwIgAghjmgZqhAMY4FIt5Hnv8FVauXIeW82QSCbKeS8Z3SLsugSPkCxfZsfdTPmzbgNUYEWewEwbUYGi+YbxWA4ggqGRHmgtVxRiPGTMexjUOySCJ77gkkhnuyRrqHLhSgKvlBlpXvIHvpdn02eskk/VYGw95mWRFEO23Z4jVMuKoqY0JgnoaG+di45DAM9zfUM/Pv3dwstCNaxxcfyozpi7kSm+RxfNbyWY2UCz14jhu1XcyVMMddYjEUIn6mDzpXnLZ6RhbIRdkqJSLvLVlNd0X/gAngeu4vP3qNyx56Ek6z/wNYmoaUjM6gBBFZWY2LWJKwyxcYqZnAvZ37qT74inq66eTyzQShX2USlcIfIhikEHrPCEAVcVxPMrlaxw89DlJ18E30N7xCUYEVaWnp4v5LU+waP5KLlyDc5dOUShexnG8IfYPL3d0AEsikabzyHZ6e8/TuryV03+d5MCxXYjjUolCFi14jrXPb6QYe8RhTNuejURxGc8LUI0nBjCwFMZlzn2Laco5vNe+jeuFi6x9YTOzm5fSNGUOkxN1JMSwuf1NDh37jrpkbvgEjB9AUBszu+lB4hC+3rOFluYlvLbqZVAIK3Duci/vbF9P255NpIL6msRrB1ALjsfCucv45bef6Oo+yppV6zl/6Sxnuy9w6Pg+vvphK2e6jpBK5Ri01d8NACG2EalUjuZpc/jgi3UgDtt3v8+2Xe/SF14nLBVw/YC6ukk1dz6GfUAohyVaZi4gLF9j769t+Ik0xVIBRXGMQzrdgFUds3jN+4CNyjww6xEOHt3F1Z4ufDeBiOD0b2qxjcdk+9gA+g+HaZNmsvvgl4jxBsR0wmFlGMDwoY1tRJDMUa700XlyP36iDjvObkfSMFVhRjQ/7AOMK+QyjZw4e5hCXx7HuBNrWTSvWnVGDyCA5TSIvRWlFGNcCsU8h0/sxfcS415rIAKxavlz8BlRtQRWwy39ASesOoziClFUYZzpfABABKNa+egOoVSMH9R3OMZdoiOG0jHXQChFJGVtdCAsXVs6OJ7fLpbvNMZZdpdj+b6wXHjqjrG8+mISPC3GfUmMtEzsYsIJteHWKCrvrOli8m9fzf6vfwAEDgN57ASAoQAAAABJRU5ErkJggg==', 'base64'),
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
