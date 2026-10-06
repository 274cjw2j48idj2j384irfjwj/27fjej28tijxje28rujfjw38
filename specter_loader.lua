-- ======================================================================
--  SPECTER | Cloud Loader  v3.0.0
--  Auth: key + HWID verified against the license server
--  Script fetched from server (not GitHub) — requires valid license
-- ======================================================================

local AUTH_VER   = 3
local DB_USERS   = "specter_users_v3"
local DB_SESSION = "specter_session_v3"

-- Luraph defines these when the loader is obfuscated; without it they are plain pass-throughs
if not LPH_OBFUSCATED then
    LPH_ENCSTR = function(...) return ... end
    LPH_NO_VIRTUALIZE = function(...) return ... end
end

-- ██ THE LICENSE SERVER (Railway domain of the server service, no "/" at the end) ██
local SERVER_URL = LPH_ENCSTR("https://specter-license-mh111-production.up.railway.app")

-- ── LIBS ─────────────────────────────────────────────────────────────
local http  = require "gamesense/http"
local json  = require "json"
local pui   = require "gamesense/pui"
local _sf   = string.format
local _bxor = bit.bxor
local _band = bit.band
local _flr  = math.floor

-- ── HELPERS ──────────────────────────────────────────────────────────
local function clog(r,g,b,m) client.color_log(r,g,b,"[Specter] "..tostring(m)) end
local function info(m) clog(130,195,255,m) end
local function warn(m) clog(255,200,80,m) end
local function err(m)  clog(255,60,60,m)  end

-- our steam id: from panorama (works in the main menu too), else from the local player in a match. The same id both ways,
-- so a key registered in the menu still matches in game
local function get_steam_id()
    local ok, xuid = pcall(function() return panorama.open().MyPersonaAPI.GetXuid() end)
    if ok and xuid ~= nil and tostring(xuid):match("^%d+$") and tostring(xuid) ~= "0" then return tostring(xuid) end
    local lp = entity.get_local_player()
    local ok2, sid = pcall(function() return lp and entity.get_steam64(lp) end)
    if ok2 and sid then
        sid = type(sid) == "number" and _sf("%.0f", sid) or tostring(sid)
        if sid:match("^%d+$") and sid ~= "0" then return sid end
    end
    return nil
end

local function get_hwid()
    local steam = get_steam_id() or "0"
    local raw   = "SPEC_HWID:"..tostring(steam)..":v"..AUTH_VER
    local h = 5381
    for i=1,#raw do h = _band(_bxor(h*33,string.byte(raw,i)),0xFFFFFFFF) end
    local hi = _band(_flr(h/0x10000),0xFFFF)
    local lo = _band(h,0xFFFF)
    return _sf("%04X%04X-%04X%04X",hi,lo,_bxor(hi,0xA5A5),_bxor(lo,0x5A5A))
end

local function hash_pw(pw)
    local h = 0xDEAD1337
    for i=1,#pw do h = _band(_bxor(h*31, string.byte(pw,i)+i*13), 0xFFFFFFFF) end
    return _sf("%08X", h)
end

local function db_read(k)
    local ok,r = pcall(database.read,k)
    return ok and type(r)=="table" and r or {}
end
local function db_write(k,v) pcall(database.write,k,v) end

-- gamesense textboxes take no Ctrl+V: the "Paste key" button reads the clipboard. The workshop library first (the script
-- needs it anyway), else the same vgui2 calls it makes; nil when neither is there (then: spec_key <key> in the console)
local clipboard_get do
    local ok, lib = pcall(require, "gamesense/clipboard")
    if ok and type(lib) == "table" and type(lib.get) == "function" then
        clipboard_get = lib.get
    else
        pcall(function()
            local ffi = require "ffi"
            local sys = ffi.cast("void***", client.create_interface("vgui2.dll", "VGUI_System010") or error("no VGUI_System010"))
            local count = ffi.cast("int(__thiscall*)(void*)", sys[0][7])
            local read  = ffi.cast("int(__thiscall*)(void*, int, char*, int)", sys[0][11])
            clipboard_get = function()
                local n = count(sys)
                if n <= 0 or n > 4096 then return nil end
                local buf = ffi.new("char[?]", n + 1)
                read(sys, 0, buf, n + 1)
                return ffi.string(buf)
            end
        end)
    end
end

-- the key out of whatever was copied (the Discord message, ```key```, spaces / new lines around it)
local function key_from_text(t)
    t = tostring(t or "")
    local k = t:match("%w%w%w%w%w%w%-%w%w%w%w%w%w%-%w%w%w%w%w%w%-%w%w%w%w%w%w")
    if k then return k end
    t = t:gsub("[`%c]", " "):match("^%s*(%S+)") or ""
    return t
end

local function url_encode(s)
    return tostring(s):gsub("([^%w%-_.~])", function(c)
        return _sf("%%%02X", string.byte(c))
    end)
end

-- ── AUTH STATE ───────────────────────────────────────────────────────
local auth_plan = nil
local script_running = false        -- set once the script runs: it can not be unloaded, so the login menu stays hidden

-- ── STATUS ───────────────────────────────────────────────────────────
local status_msg = "Ready."
local status_r, status_g, status_b = 160,160,200

local function set_status(r,g,b,msg)
    status_r,status_g,status_b = r,g,b
    status_msg = msg
end

-- ── SERVER AUTH: verify key → get ticket → fetch script ─────────────
local function load_from_server(key, hwid, on_plan)
    if hwid == nil or not get_steam_id() then
        set_status(255,120,50, "Steam id not ready, try again in a moment.")
        warn("Could not read your steam id yet.")
        return
    end
    set_status(255,200,80, "Verifying license...")
    info("Verifying key with server...")

    local verify_url = SERVER_URL .. "/verify?key=" .. url_encode(key) .. "&hwid=" .. url_encode(hwid)
    http.get(verify_url, function(ok1, resp1)
        if not ok1 then
            set_status(255,60,60, "Server unreachable.")
            err("Cannot reach license server.")
            return
        end
        local body1 = type(resp1)=="table" and resp1.body or resp1
        local ok_j, data = pcall(json.parse, body1)
        if not ok_j or type(data) ~= "table" then
            set_status(255,60,60, "Bad server response.")
            err("Invalid verify response.")
            return
        end
        if not data.valid then
            local reasons = {
                invalid_key    = "Invalid license key.",
                revoked        = "License revoked.",
                expired        = "License expired.",
                hwid_mismatch  = "Key locked to another PC.",
                missing_params = "Internal error.",
            }
            set_status(255,60,60, reasons[data.reason] or ("Denied: "..(data.reason or "?")))
            err("Verify failed: "..(data.reason or "unknown"))
            return
        end

        local plan    = data.plan or "beta"
        local ticket  = data.ticket
        local nonce   = data.nonce
        if not ticket or not nonce then
            set_status(255,60,60, "Server ticket missing.")
            return
        end

        if on_plan then on_plan(plan) end

        set_status(255,200,80, "Downloading script ["..plan.."]...")
        info("License OK, plan: "..plan..". Downloading script...")

        local script_url = SERVER_URL .. "/script"
            .. "?key="    .. url_encode(key)
            .. "&hwid="   .. url_encode(hwid)
            .. "&plan="   .. url_encode(plan)
            .. "&ticket=" .. url_encode(ticket)
            .. "&nonce="  .. url_encode(nonce)

        http.get(script_url, function(ok2, resp2)
            if not ok2 then
                set_status(255,60,60, "Script download failed.")
                err("Failed to download script.")
                return
            end
            local body2 = type(resp2)=="table" and resp2.body or resp2
            local status2 = type(resp2)=="table" and resp2.status or 200
            if status2 ~= 200 then
                local okj, d = pcall(json.parse, body2 or "")
                local reason = okj and type(d)=="table" and d.reason or ("http "..tostring(status2))
                local reasons = {
                    script_missing = "No script on the server yet (/script_upload in Discord).",
                    ticket_expired = "Too slow, try again.",
                    hwid_mismatch  = "Key locked to another PC.",
                    wrong_plan     = "Plan changed, try again.",
                }
                set_status(255,60,60, reasons[reason] or ("Download denied: "..tostring(reason)))
                err("Script download denied: "..tostring(reason))
                return
            end
            if not body2 or #body2 < 200 then
                set_status(255,60,60, "Script too short or missing.")
                err("Server returned empty script. Upload it first with /script_upload in Discord.")
                return
            end

            if script_running then return end       -- a second click while the first download ran
            info("Downloaded "..#body2.." bytes, starting...")
            local fn, lerr = (rawget(_G,"loadstring") or rawget(_G,"load") or load)(body2, "@specter_cloud")
            if not fn then
                set_status(255,60,60, "Script load error.")
                err("Load error: "..tostring(lerr))
                return
            end
            local ok3, rerr = pcall(fn)
            if not ok3 then
                set_status(255,60,60, "Script runtime error.")
                err("Runtime error: "..tostring(rerr))
                return
            end
            rawset(_G, "_specter_loader_loaded", true)
            script_running = true
            auth_plan = plan
            set_status(100,255,160, "Specter loaded! ["..plan.."]")
            info("Specter loaded successfully! Plan: "..plan)
        end)
    end)
end

-- ── REGISTER ─────────────────────────────────────────────────────────
local function do_register(key, name, pw)
    key  = (key  or ""):match("^%s*(.-)%s*$")
    name = (name or ""):match("^%s*(.-)%s*$")
    pw   = (pw   or ""):match("^%s*(.-)%s*$")

    if key  == "" then set_status(255,120,50,"Enter your license key."); return end
    if name == "" then set_status(255,120,50,"Enter a username."); return end
    if pw   == "" then set_status(255,120,50,"Enter a password."); return end
    if #name < 2  then set_status(255,120,50,"Username too short (min 2)."); return end
    if #pw   < 4  then set_status(255,120,50,"Password too short (min 4)."); return end

    local users = db_read(DB_USERS)
    local nl = name:lower()
    if users[nl] then
        set_status(255,60,60,"Username '"..name.."' already taken.")
        return
    end

    local hwid = get_hwid()

    load_from_server(key, hwid, function(plan)
        auth_plan = plan
        users[nl] = { display_name=name, pw_hash=hash_pw(pw), key=key, hwid=hwid, plan=plan }
        db_write(DB_USERS, users)
        db_write(DB_SESSION, { user=nl, pw_hash=hash_pw(pw), key=key, hwid=hwid, plan=plan, v=AUTH_VER })
        set_status(100,255,160,"Registered as '"..name.."'! Loading ["..plan.."]...")
        info("Registered: "..name.." (plan: "..plan..")")
    end)
end

-- ── LOGIN ────────────────────────────────────────────────────────────
local function do_login(name, pw)
    name = (name or ""):match("^%s*(.-)%s*$")
    pw   = (pw   or ""):match("^%s*(.-)%s*$")

    if name == "" then set_status(255,120,50,"Enter your username."); return end
    if pw   == "" then set_status(255,120,50,"Enter your password."); return end

    local users = db_read(DB_USERS)
    local nl = name:lower()
    local u  = users[nl]
    if not u then set_status(255,60,60,"Account '"..name.."' not found."); return end
    if u.pw_hash ~= hash_pw(pw) then set_status(255,60,60,"Wrong password."); return end

    local hwid = get_hwid()
    if u.hwid ~= hwid then set_status(255,60,60,"Account locked to another machine."); return end

    load_from_server(u.key, hwid, function(plan)
        auth_plan = plan
        u.plan = plan
        db_write(DB_USERS, users)
        db_write(DB_SESSION, { user=nl, pw_hash=hash_pw(pw), key=u.key, hwid=hwid, plan=plan, v=AUTH_VER })
        set_status(100,255,160,"Welcome back, '"..u.display_name.."'! ["..plan.."]")
        info("Logged in: "..u.display_name.." (plan: "..plan..")")
    end)
end

-- ── SESSION RESTORE ──────────────────────────────────────────────────
local function try_restore()
    local hwid = get_hwid()
    local sess = db_read(DB_SESSION)
    if not (sess.v==AUTH_VER and sess.user and sess.hwid==hwid and sess.key) then return false end
    local users = db_read(DB_USERS)
    local u = users[sess.user]
    if not u then db_write(DB_SESSION,nil); return false end
    if u.pw_hash ~= sess.pw_hash then db_write(DB_SESSION,nil); return false end
    if u.hwid ~= hwid then db_write(DB_SESSION,nil); return false end

    set_status(150,200,255, "Restoring session: "..u.display_name.."...")
    info("Restoring session for "..u.display_name.."...")
    load_from_server(sess.key, hwid, function(plan)
        auth_plan = plan
        u.plan = plan
        db_write(DB_USERS, users)
        sess.plan = plan
        db_write(DB_SESSION, sess)
    end)
    return true
end

-- ── PUI MENU ─────────────────────────────────────────────────────────
-- every item of the login menu is kept: once the script runs (its own menu is in the same tabs) they are hidden
local form = {}
local function group(tab, name)
    local g = pui.group(tab, name)
    local function add(kind)
        return function(_, ...) local e = g[kind](g, ...); form[#form + 1] = e; return e end
    end
    return { label = add("label"), textbox = add("textbox"), button = add("button") }
end
local grp_fl  = group('AA','Fake lag')
local grp_aa  = group('AA','Anti-aimbot angles')
local grp_oth = group('AA','Other')
pui.macros.dot = '\v•  \r'

grp_fl:label('      S  P  E  C  T  E  R')
grp_fl:label('\f<dot>\ac8c8c8ffAuthentication')
grp_fl:label(' ')

grp_fl:label('\f<dot>Auth:   \aff6060ff✗ Not logged in')
grp_fl:label(' ')
grp_fl:label('\f<dot>\ac8c8c8ffspec_key  spec_hwid  spec_plan  spec_logout')

grp_aa:label('\f<dot>License Key:')
local inp_key  = grp_aa:textbox('\nKey',  '', false)
local btn_paste = grp_aa:button('Paste key')
grp_aa:label('\f<dot>Username:')
local inp_name = grp_aa:textbox('\nUsername', '', false)
grp_aa:label('\f<dot>Password:')
local inp_pw   = grp_aa:textbox('\nPassword', '', false)
grp_aa:label(' ')

local btn_register = grp_aa:button('Register')
local btn_login    = grp_aa:button('Login')

grp_aa:label(' ')
local lbl_status = grp_aa:label('\f<dot>\ac8c8c8ffReady.')

grp_oth:label('\f<dot>How to use:')
grp_oth:label('\f<dot>\ac8c8c8ff1. Get key from Discord')
grp_oth:label('\f<dot>\ac8c8c8ff   (/redeem command)')
grp_oth:label('\f<dot>\ac8c8c8ff2. Copy it, click Paste key')
grp_oth:label('\f<dot>\ac8c8c8ff   (or console: spec_key <key>)')
grp_oth:label('\f<dot>\ac8c8c8ff3. Enter a username')
grp_oth:label('\f<dot>\ac8c8c8ff4. Enter a password')
grp_oth:label('\f<dot>\ac8c8c8ff5. Click Register')
grp_oth:label(' ')
grp_oth:label('\f<dot>\ac8c8c8ffNext time: just Login')
grp_oth:label('\f<dot>\ac8c8c8ffor it auto-restores.')
grp_oth:label(' ')
grp_oth:label('\f<dot>\ac8c8c8ffHWID locked on first use.')
grp_oth:label(' ')
grp_oth:label('\f<dot>\ac8c8c8ffPlans: debug > specter > nightly > beta')

local function put_key(text, from)
    local k = key_from_text(text)
    if k == "" then set_status(255,120,50, "No key in the "..from.."."); warn("No key in the "..from.."."); return end
    inp_key:set(k)
    set_status(100,255,160, "Key pasted ("..k:sub(1, 6).."...). Now username + password, then Register.")
    info("Key pasted: "..k:sub(1, 6).."...")
end

btn_paste:set_callback(function()
    if not clipboard_get then
        set_status(255,120,50, "Clipboard not readable: type spec_key <your key> in the console.")
        return
    end
    local ok, text = pcall(clipboard_get)
    put_key(ok and text, "clipboard")
end)

btn_register:set_callback(function()
    do_register(inp_key:get(), inp_name:get(), inp_pw:get())
end)

btn_login:set_callback(function()
    do_login(inp_name:get(), inp_pw:get())
end)

local form_hidden = false
client.set_event_callback('paint_ui', function()
    if form_hidden then return end
    if script_running then
        for i = 1, #form do pcall(function() form[i]:set_visible(false) end) end
        form_hidden = true
        return
    end
    lbl_status:set('\f<dot>\a'.._sf('%02x%02x%02xff',status_r,status_g,status_b)..status_msg)
end)

-- ── CONSOLE COMMANDS ─────────────────────────────────────────────────
client.set_event_callback("console_input", function(cmd)
    local t = cmd:match("^%s*(.-)%s*$")
    if t=="spec_logout" then
        db_write(DB_SESSION,nil)
        set_status(160,160,200,"Logged out."); warn("Logged out: the next load asks for a login again."); return true
    end
    local k = t:match("^spec_key%s+(.+)$")
    if k then put_key(k, "command"); return true end
    if t=="spec_hwid" then info("HWID: "..get_hwid()); return true end
    if t=="spec_plan" then info("Plan: "..(auth_plan or "none")); return true end
end)

-- ── STARTUP ──────────────────────────────────────────────────────────
if not try_restore() then
    set_status(160,160,200, "Enter key, then Register or Login.")
end
info("Loader v3.0.0 ready.")
