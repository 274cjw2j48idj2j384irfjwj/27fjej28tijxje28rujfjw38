-- A mock gamesense + game world for profiling the whole script (tests/perf_profile.py).
-- Unlike the "ghost" sandbox of load_smoke.py every API returns plausible concrete values, so the callbacks run their
-- real code paths: a local player, N enemies and M teammates that move, jitter their yaw and choke packets, menu items
-- that hold values, gamesense references with sensible defaults, renderer calls that cost nothing.
--
--   M = load(this)();  w = M.new(script_src, { enemies = 10, mates = 4, everything_on = true })
--   w.tick() / w.frame() / w.fire(name, ...);  w.timers[name] = seconds spent in that callback
local M = {}

function M.new(src, opts)
    opts = opts or {}
    local ffi = require("ffi")
    local real_G = _G
    local clock = real_G.os.clock
    local TI = 1 / 64

    local w = { tick_n = 1000, frame_n = 0, callbacks = {}, errors = {}, logs = {}, timers = {}, calls = {}, delayed = {} }
    local seed = opts.seed or 12345
    local function rnd()
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed / 2147483648
    end

    -- ── ghosts (only for the few libraries nothing measured depends on: panorama, materials) ──
    local ghost_mt = {}
    local function G() return setmetatable({}, ghost_mt) end
    ghost_mt.__index = function(t, k) if type(k) == "number" then return nil end local v = G(); rawset(t, k, v); return v end
    ghost_mt.__call = function() return G() end

    -- ── vector ───────────────────────────────────────────────────────────────────
    local V = {}
    V.__index = V
    local function vec(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, V) end
    V.__add = function(a, b) return vec(a.x + b.x, a.y + b.y, a.z + b.z) end
    V.__sub = function(a, b) return vec(a.x - b.x, a.y - b.y, a.z - b.z) end
    V.__mul = function(a, b)
        if type(a) == "number" then return vec(b.x * a, b.y * a, b.z * a) end
        if type(b) == "number" then return vec(a.x * b, a.y * b, a.z * b) end
        return vec(a.x * b.x, a.y * b.y, a.z * b.z)
    end
    V.__div = function(a, b) if type(b) == "number" then return vec(a.x / b, a.y / b, a.z / b) end return vec(a.x / b.x, a.y / b.y, a.z / b.z) end
    V.__unm = function(a) return vec(-a.x, -a.y, -a.z) end
    V.__eq = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
    V.__tostring = function(a) return string.format("vector(%g, %g, %g)", a.x, a.y, a.z) end
    function V:length() return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z) end
    function V:lengthsqr() return self.x * self.x + self.y * self.y + self.z * self.z end
    function V:length2d() return math.sqrt(self.x * self.x + self.y * self.y) end
    function V:length2dsqr() return self.x * self.x + self.y * self.y end
    function V:dist(o) return (o - self):length() end
    function V:dist2d(o) return (o - self):length2d() end
    function V:dot(o) return self.x * o.x + self.y * o.y + self.z * o.z end
    function V:cross(o) return vec(self.y * o.z - self.z * o.y, self.z * o.x - self.x * o.z, self.x * o.y - self.y * o.x) end
    function V:normalized() local l = self:length(); if l == 0 then return vec() end return self / l end
    function V:normalize() local l = self:length(); if l > 0 then self.x, self.y, self.z = self.x / l, self.y / l, self.z / l end return self end
    function V:to(o) return (o - self):normalized() end
    function V:angles()
        local pitch = math.deg(math.atan2(-self.z, math.sqrt(self.x * self.x + self.y * self.y)))
        return pitch, math.deg(math.atan2(self.y, self.x)), 0
    end
    function V:init(x, y, z) self.x, self.y, self.z = x or 0, y or 0, z or 0; return self end
    function V:init_from_angles(p, y)
        p, y = math.rad(p or 0), math.rad(y or 0)
        return self:init(math.cos(p) * math.cos(y), math.cos(p) * math.sin(y), -math.sin(p))
    end
    function V:unpack() return self.x, self.y, self.z end
    function V:clone() return vec(self.x, self.y, self.z) end
    function V:lerp(o, t) return self + (o - self) * t end
    function V:scale(s) self.x, self.y, self.z = self.x * s, self.y * s, self.z * s; return self end
    local vector = setmetatable({}, { __call = function(_, x, y, z) return vec(x, y, z) end })

    -- ── world ────────────────────────────────────────────────────────────────────
    local ME, RES, RULES = 1, 70, 71
    local ents = {}
    local function add_player(idx, team, ox, oy)
        ents[idx] = {
            cls = "CCSPlayer", team = team, alive = true, dormant = false, name = "player" .. idx,
            x = ox, y = oy, z = 0, vx = 0, vy = 0, yaw = 0, pitch = 89, health = 100, sim = 0, choke = 0,
            weapon = 100 + idx, lby = 0, duck = 0, flags = 1, phase = rnd() * 6.28,
        }
        ents[100 + idx] = { cls = "CWeaponSSG08", item = 40, owner = idx }
    end
    add_player(ME, 2, 0, 0)
    local enemies, mates = {}, {}
    for i = 1, opts.enemies or 10 do
        local idx = 1 + i
        local a = i / (opts.enemies or 10) * 6.28
        add_player(idx, 3, math.cos(a) * (600 + 90 * i), math.sin(a) * (600 + 90 * i))
        enemies[#enemies + 1] = idx
    end
    for i = 1, opts.mates or 4 do
        local idx = 40 + i
        add_player(idx, 2, -200 * i, 100)
        mates[#mates + 1] = idx
    end
    ents[RES] = { cls = "CCSPlayerResource" }
    ents[RULES] = { cls = "CCSGameRulesProxy" }

    local function advance_world()
        for idx, e in pairs(ents) do
            if e.cls == "CCSPlayer" and idx ~= ME then
                local t = w.tick_n * TI + e.phase
                e.vx, e.vy = math.cos(t * 0.7) * 180, math.sin(t * 0.5) * 120
                e.x, e.y = e.x + e.vx * TI, e.y + e.vy * TI
                e.choke = e.choke + 1
                if e.choke > 3 then
                    e.choke = 0
                    e.sim = w.tick_n
                    e.yaw = ((w.tick_n % 2 == 0) and 35 or -35) + 180
                end
            end
        end
        local me = ents[ME]
        me.sim = w.tick_n
    end

    -- ── ui ── (handles are numbers, like in gamesense; the data lives in `items`)
    local items = {}
    local function new_item(kind, tab, cont, name, extra)
        local it = { kind = kind, tab = tab, cont = cont, name = name, visible = true, callbacks = {} }
        for k, v in pairs(extra or {}) do it[k] = v end
        items[#items + 1] = it
        it.id = #items
        return #items
    end
    local function D(h) return type(h) == "number" and items[h] or nil end
    local function list_of(a, ...) if type(a) == "table" then return a end return { a, ... } end
    local ui = {}
    ui.new_checkbox = function(t, c, n) return new_item("checkbox", t, c, n, { value = false }) end
    ui.new_slider = function(t, c, n, lo, hi, init, ...) return new_item("slider", t, c, n, { min = lo, max = hi, value = init or lo }) end
    ui.new_combobox = function(t, c, n, ...) local l = list_of(...); return new_item("combobox", t, c, n, { list = l, value = l[1] }) end
    ui.new_multiselect = function(t, c, n, ...) local l = list_of(...); return new_item("multiselect", t, c, n, { list = l, value = {} }) end
    ui.new_hotkey = function(t, c, n, inline, key) return new_item("hotkey", t, c, n, { value = false, mode = 1, key = key or 0 }) end
    ui.new_button = function(t, c, n, cb) return new_item("button", t, c, n, { cb = cb }) end
    ui.new_label = function(t, c, n) return new_item("label", t, c, n, { value = n }) end
    ui.new_color_picker = function(t, c, n, r, g, b, a) return new_item("color_picker", t, c, n, { value = { r or 255, g or 255, b or 255, a or 255 } }) end
    ui.new_textbox = function(t, c, n) return new_item("textbox", t, c, n, { value = "" }) end
    ui.new_listbox = function(t, c, n, l) return new_item("listbox", t, c, n, { list = l or {}, value = 0 }) end
    ui.new_string = function(n, v) return new_item("string", "", "", n, { value = v or "" }) end
    -- gamesense's own items: kinds of the values each reference returns
    local REF = {
        ["Pitch"] = { { "combobox", "Down" }, { "slider", 0 } }, ["Yaw base"] = { { "combobox", "At targets" } },
        ["Yaw"] = { { "combobox", "180" }, { "slider", 0 } }, ["Yaw jitter"] = { { "combobox", "Off" }, { "slider", 0 } },
        ["Body yaw"] = { { "combobox", "Static" }, { "slider", 0 } }, ["Roll"] = { { "slider", 0 } },
        ["Amount"] = { { "combobox", "Dynamic" } }, ["Variance"] = { { "slider", 0 } }, ["Limit"] = { { "slider", 14 } },
        ["Leg movement"] = { { "combobox", "Off" } }, ["Player list"] = { { "listbox", 0 } },
        ["Hitchance"] = { { "slider", 60 } }, ["Minimum hit chance"] = { { "slider", 60 } }, ["Minimum damage"] = { { "slider", 30 } },
        ["Multi-point"] = { { "multiselect", { "Head" } }, { "hotkey", false }, { "combobox", "Low" } }, ["Multi-point scale"] = { { "slider", 60 } },
        ["Accuracy boost"] = { { "combobox", "Medium" } }, ["Double tap fake lag limit"] = { { "slider", 1 } },
        ["Force body aim"] = { { "hotkey", false } }, ["Force safe point"] = { { "hotkey", false } },
        ["Ping spike"] = { { "checkbox", false }, { "hotkey", false }, { "slider", 0 } },
        ["Minimum damage override"] = { { "checkbox", false }, { "hotkey", false }, { "slider", 0 } },
    }
    local refs = {}
    ui.reference = function(tab, cont, name)
        local key = tab .. "|" .. cont .. "|" .. name
        if not refs[key] then
            local spec = REF[name] or { { "checkbox", name == "Enabled" }, { "hotkey", false }, { "combobox", "Off" } }
            local out = {}
            for i, sp in ipairs(spec) do
                local v = sp[2]
                out[i] = new_item(sp[1], tab, cont, name, { value = v, list = type(v) == "table" and v or nil, ref = true })
            end
            refs[key] = out
        end
        return unpack(refs[key])
    end
    ui.get = function(h)
        local it = D(h)
        if not it then return nil end
        if it.kind == "multiselect" then local c = {}; for i, v in ipairs(it.value) do c[i] = v end return c end
        if it.kind == "hotkey" then return it.value, it.mode, it.key end
        if it.kind == "color_picker" then return unpack(it.value) end
        return it.value
    end
    ui.set = function(h, ...)
        local it = D(h)
        if not it then return end
        local v = ...
        if it.kind == "color_picker" then it.value = { ... }
        elseif it.kind == "multiselect" then it.value = type(v) == "table" and v or { ... }
        elseif it.kind == "hotkey" then it.mode = type(v) == "string" and v or it.mode
        elseif it.kind == "button" then if it.cb then it.cb() end
        else it.value = v end
        for _, cb in ipairs(it.callbacks) do cb(h) end
    end
    ui.set_callback = function(h, fn) local it = D(h); if it then it.callbacks[#it.callbacks + 1] = fn end end
    ui.set_visible = function(h, b) local it = D(h); if it then it.visible = b end end
    ui.set_enabled = function() end
    ui.update = function(h, l) local it = D(h); if it then it.list = l end end
    ui.type = function(h) local it = D(h); return it and it.kind or nil end
    ui.name = function(h) local it = D(h); return it and it.name or nil end
    ui.is_menu_open = function() return w.menu_open == true end
    ui.mouse_position = function() return 900, 500 end
    ui.menu_size = function() return 800, 600 end
    ui.menu_position = function() return 200, 100 end
    w.items = items

    -- calls that are expensive in the game (C boundary, bone setup, traces, menu / player list writes, draw calls)
    w.api = {}
    local function counted(tbl, prefix, names)
        for _, n in ipairs(names) do
            local f = tbl[n]
            if f then
                local key = prefix .. n
                tbl[n] = function(...)
                    w.api[key] = (w.api[key] or 0) + 1
                    if w.sites then
                        local info = real_G.debug.getinfo(2, "Sl")
                        if info and info.source == "@script" then
                            local sk = key .. "@" .. info.currentline
                            w.sites[sk] = (w.sites[sk] or 0) + 1
                        end
                    end
                    return f(...)
                end
            end
        end
    end
    w.counted = counted

    -- ── entity ───────────────────────────────────────────────────────────────────
    local entity = {}
    entity.get_local_player = function() return ME end
    entity.get_players = function(enemies_only)
        local l = {}
        for i = 1, 64 do
            local e = ents[i]
            if e and e.cls == "CCSPlayer" and e.alive and not e.dormant and i ~= ME and (not enemies_only or e.team ~= ents[ME].team) then l[#l + 1] = i end
        end
        if not enemies_only then table.insert(l, 1, ME) end
        return l
    end
    entity.get_all = function(cls)
        local l = {}
        for i, e in pairs(ents) do if cls == nil or e.cls == cls then l[#l + 1] = i end end
        return l
    end
    entity.get_classname = function(i) return ents[i] and ents[i].cls or nil end
    entity.is_alive = function(i) return ents[i] ~= nil and ents[i].alive == true end
    entity.is_dormant = function(i) return ents[i] ~= nil and ents[i].dormant == true end
    entity.is_enemy = function(i) return ents[i] ~= nil and ents[i].team ~= nil and ents[i].team ~= ents[ME].team end
    entity.get_player_name = function(i) return ents[i] and ents[i].name or "unknown" end
    entity.get_steam64 = function(i) return "765611980000" .. tostring(1000 + (i or 0)) end
    entity.get_player_weapon = function(i) return ents[i] and ents[i].weapon or nil end
    entity.get_player_resource = function() return RES end
    entity.get_game_rules = function() return RULES end
    entity.get_origin = function(i) local e = ents[i]; if not e or not e.x then return nil end return e.x, e.y, e.z end
    entity.hitbox_position = function(i, hb)
        local e = ents[i]; if not e or not e.x then return nil end
        return e.x, e.y, e.z + ((hb == 0 or hb == "head") and 64 or 40)
    end
    entity.get_bounding_box = function(i) return 800, 300, 860, 460, 1 end
    entity.get_esp_data = function(i) return { alpha = 1, health = 100, flags = 0, weapon_id = 40 } end
    entity.set_prop = function() end
    local function real_get_prop(i, prop, idx)
        local e = ents[i]
        if not e then return nil end
        if i == RES then
            if prop == "m_iPing" then return 40 end
            if prop == "m_iKills" or prop == "m_iDeaths" or prop == "m_iScore" then return 0 end
            return 0
        end
        if i == RULES then return 0 end
        if e.cls ~= "CCSPlayer" then
            if prop == "m_iItemDefinitionIndex" then return e.item end
            if prop == "m_flNextPrimaryAttack" then return w.tick_n * TI - 1 end
            if prop == "m_iClip1" then return 10 end
            if prop == "m_hOwnerEntity" then return e.owner end
            if prop == "m_fLastShotTime" then return 0 end
            return 0
        end
        if prop == "m_vecOrigin" then return e.x, e.y, e.z end
        if prop == "m_vecVelocity" or prop == "m_vecAbsVelocity" then return e.vx, e.vy, 0 end
        if prop == "m_vecVelocity[0]" then return e.vx end
        if prop == "m_vecVelocity[1]" then return e.vy end
        if prop == "m_fFlags" then return e.flags end
        if prop == "m_angEyeAngles" then return e.pitch, e.yaw, 0 end
        if prop == "m_angEyeAngles[1]" then return e.yaw end
        if prop == "m_flSimulationTime" then return e.sim * TI end
        if prop == "m_flOldSimulationTime" then return (e.sim - 4) * TI end
        if prop == "m_iHealth" then return e.health end
        if prop == "m_iTeamNum" then return e.team end
        if prop == "m_lifeState" then return 0 end
        if prop == "m_flDuckAmount" then return e.duck end
        if prop == "m_flLowerBodyYawTarget" then return e.lby end
        if prop == "m_hActiveWeapon" then return e.weapon end
        if prop == "m_nTickBase" then return w.tick_n end
        if prop == "m_flPoseParameter" then return 0.5 end
        if prop == "m_bIsScoped" or prop == "m_bResumeZoom" or prop == "m_bGunGameImmunity" or prop == "m_bHasDefuser" then return 0 end
        if prop == "m_ArmorValue" then return 100 end
        if prop == "m_flVelocityModifier" then return 1 end
        if prop == "m_vecViewOffset[2]" then return 64 end
        if prop == "m_MoveType" then return 2 end
        if prop == "m_flNextAttack" then return 0 end
        return 0
    end
    -- w.garbage (tests/freeze_guard.py): a value in place of the real one (inf / NaN / huge), nil = the real one
    entity.get_prop = function(i, prop, idx)
        if w.garbage then
            local g = w.garbage(i, prop, idx)
            if g ~= nil then return g end
        end
        return real_get_prop(i, prop, idx)
    end

    -- ── client / globals / renderer / misc ──────────────────────────────────────
    -- real memory behind the ffi helpers: entity -> animstate / animation layers / studio header, a usercmd vtable,
    -- C callbacks where the script calls into the game (sequence activity, GetUserCmd, timescale)
    local keep = {}
    local LAYERS_OFF = 0x2990
    local ent_mem = {}
    local function entity_ptr(idx)
        idx = tonumber(idx) or 0
        if not ents[idx] or ents[idx].cls ~= "CCSPlayer" then return ffi.cast("void*", 0) end
        local m = ent_mem[idx]
        if not m then
            m = { ent = ffi.new("char[?]", 0xA000), anim = ffi.new("char[?]", 0x400), layers = ffi.new("char[?]", 15 * 56), studio = ffi.new("char[?]", 64) }
            local function setptr(off, p) ffi.cast("uintptr_t*", m.ent + off)[0] = ffi.cast("uintptr_t", p) end
            setptr(0x9960, m.anim); setptr(LAYERS_OFF, m.layers); setptr(0x2950, m.studio)
            ent_mem[idx] = m
        end
        return ffi.cast("void*", m.ent)
    end
    local seq_cb = ffi.cast("int(*)(void*, void*, int)", function() return 0 end)
    local usercmd = ffi.new("char[256]")
    local get_cmd_cb = ffi.cast("void*(*)(void*, int, int)", function(_, _, number)
        if not w.usercmd_wrong then ffi.cast("int*", usercmd + ffi.sizeof("void*"))[0] = number end
        return ffi.cast("void*", usercmd)
    end)
    local fake_vtable = ffi.new("void*[128]")
    fake_vtable[8] = ffi.cast("void*", get_cmd_cb)
    local fake_holder = ffi.new("void*[4]")
    fake_holder[0] = ffi.cast("void*", fake_vtable)
    keep[1], keep[2], keep[3], keep[4], keep[5] = fake_vtable, fake_holder, seq_cb, get_cmd_cb, usercmd
    w.usercmd = usercmd
    local function sig_buffer(sig)
        if sig:sub(1, 3) == "\x55\x8B\xEC" then return ffi.cast("void*", seq_cb) end
        local b = ffi.new("char[64]")
        if sig:sub(1, 2) == "\x8B\x89" then
            ffi.cast("int*", b + 2)[0] = LAYERS_OFF
        else
            ffi.cast("uintptr_t*", b + 1)[0] = ffi.cast("uintptr_t", fake_holder)
        end
        keep[#keep + 1] = b
        return ffi.cast("void*", b)
    end
    local function nearest_enemy()
        local best, bd
        for _, i in ipairs(enemies) do
            local e = ents[i]
            local d = e.x * e.x + e.y * e.y
            if e.alive and (not bd or d < bd) then best, bd = i, d end
        end
        return best
    end
    local client = {
        unix_time = function() return 1700000000 + math.floor(w.tick_n * TI) end,
        timestamp = function() return math.floor(w.tick_n * TI * 1000) end,
        system_time = function() return 12, 30, 15, 0 end,
        error_log = function(m) w.errors[#w.errors + 1] = tostring(m) end,
        color_log = function(r, g, b, m) w.logs[#w.logs + 1] = tostring(m) end,
        log = function(m) w.logs[#w.logs + 1] = tostring(m) end,
        set_event_callback = function(name, fn) w.callbacks[name] = w.callbacks[name] or {}; table.insert(w.callbacks[name], fn) end,
        unset_event_callback = function(name, fn)
            local l = w.callbacks[name] or {}
            for i = #l, 1, -1 do if l[i] == fn then table.remove(l, i) end end
        end,
        delay_call = function(t, fn, ...) w.delayed[#w.delayed + 1] = { at = w.tick_n + math.max(1, math.floor((t or 0) / TI)), fn = fn, args = { ... } } end,
        random_int = function(a, b) a, b = a or 0, b or 1; return a + math.floor(rnd() * (b - a + 1)) end,
        random_float = function(a, b) a, b = a or 0, b or 1; return a + rnd() * (b - a) end,
        screen_size = function() return 1920, 1080 end,
        latency = function() return 0.02 end, real_latency = function() return 0.02 end,
        find_signature = function(mod, sig) return sig_buffer(sig) end,
        create_interface = function() return ffi.cast("void*", fake_holder) end,
        register_esp_flag = function() end,
        current_threat = function() return nearest_enemy() end,
        userid_to_entindex = function(u) return u end,
        eye_position = function() return 0, 0, 64 end,
        camera_angles = function() return 0, 0, 0 end,
        trace_line = function() return 1, -1 end,
        trace_bullet = function(from, x1, y1, z1, x2, y2, z2) return -1, 0 end,
        scale_damage = function(e, hg, d) return d end,
        key_state = function() return false end,
        exec = function() end, set_cvar = function() end, set_clan_tag = function() end,
        draw_hitboxes = function() end, update_player_list = function() end,
        camera_position = function() return 0, 0, 64 end,
        get_cvar = function() return "0" end,
        dll = G(),
    }
    local globals = {
        tickcount = function() return w.tick_n end, tickinterval = function() return TI end,
        curtime = function() return w.tick_n * TI end, realtime = function() return w.frame_n / 128 end,
        frametime = function() return 1 / 128 end, absoluteframetime = function() return 1 / 128 end,
        maxplayers = function() return 64 end, mapname = function() return "de_mirage" end,
        chokedcommands = function() return 0 end, oldcommandack = function() return w.tick_n end,
        lastoutgoingcommand = function() return w.tick_n end, framecount = function() return w.frame_n end,
    }
    w.render_calls = 0
    local renderer = setmetatable({
        measure_text = function(flags, ...) local s = table.concat({ ... }); return #s * 7, 12 end,
        world_to_screen = function(x, y, z) return 960 + (x or 0) * 0.1, 540 - (z or 0) * 0.1 end,
        load_svg = function() return 1 end, load_png = function() return 1 end, load_rgba = function() return 1 end,
    }, { __index = function(t, k) return function() w.render_calls = w.render_calls + 1 end end })
    local cvar = setmetatable({}, { __index = function(t, k)
        local c = { get_int = function() return 0 end, get_float = function() return k == "sv_gravity" and 800 or (k == "sv_jump_impulse" and 301.99 or 0) end,
                    get_string = function() return "0" end, set_int = function() end, set_float = function() end, set_string = function() end,
                    set_raw_int = function() end, set_raw_float = function() end, invoke_callback = function() end }
        rawset(t, k, c)
        return c
    end })
    local db, files = {}, {}
    local plist_store = {}

    local function b64(s) return s end
    local json = {}
    do
        local function enc(v)
            local t = type(v)
            if t == "table" then
                if #v > 0 or next(v) == nil then
                    local o = {}
                    for i = 1, #v do o[i] = enc(v[i]) end
                    return "[" .. table.concat(o, ",") .. "]"
                end
                local o = {}
                for k, x in pairs(v) do o[#o + 1] = string.format("%q", tostring(k)) .. ":" .. enc(x) end
                return "{" .. table.concat(o, ",") .. "}"
            elseif t == "string" then return string.format("%q", v)
            elseif t == "number" or t == "boolean" then return tostring(v)
            end
            return "null"
        end
        json.stringify = enc
        json.encode = enc
        json.parse = function(s) error("json.parse not available in the perf mock") end
        json.decode = json.parse
    end

    local libs = {
        vector = vector,
        json = json,
        ["gamesense/csgo_weapons"] = setmetatable({}, { __call = function(_, ent)
            return { name = "SSG 08", type = "sniperrifle", idx = 40, is_melee_weapon = false, max_player_speed = 230, max_player_speed_alt = 230,
                     damage = 88, range = 8192, armor_ratio = 1.7, penetration = 2.5, range_modifier = 0.98, cycletime = 1.25, is_full_auto = false, is_revolver = false }
        end, __index = function() return { name = "SSG 08", type = "sniperrifle", idx = 40 } end }),
        ["gamesense/base64"] = { encode = b64, decode = b64 },
        ["gamesense/clipboard"] = { get = function() return "" end, set = function() end },
        ["gamesense/surface"] = { create_font = function() return 1 end, draw_text = function() end, get_text_size = function(f, s) return #(s or "") * 7, 12 end },
    }

    -- ── sandbox ──────────────────────────────────────────────────────────────────
    local env = {}
    for _, name in ipairs({ "assert", "error", "ipairs", "pairs", "next", "pcall", "xpcall", "select", "tonumber", "tostring",
                            "type", "unpack", "rawget", "rawset", "rawequal", "setmetatable", "getmetatable",
                            "math", "string", "table", "bit", "coroutine", "collectgarbage", "gcinfo", "newproxy" }) do
        env[name] = real_G[name]
    end
    env.client, env.entity, env.globals, env.ui, env.renderer = client, entity, globals, ui, renderer
    env.plist = { get = function(i, k) return (plist_store[i] or {})[k] end, set = function(i, k, v) plist_store[i] = plist_store[i] or {}; plist_store[i][k] = v end }
    env.database = { read = function(k) return db[k] end, write = function(k, v) db[k] = v end, flush = function() end }
    env.cvar, env.materials, env.panorama = cvar, G(), G()
    env.json = json
    env.vtable_bind = function(mod, iface, index, typestr)
        if iface == "VClientEntityList003" then return function(a, b) return entity_ptr(b or a) end end
        if index == 91 then return function() return 1.0 end end
        return function() return 0 end
    end
    env.vtable_thunk = function() return function() return ffi.cast("void*", 0) end end
    env.vtable_entry = function() return ffi.cast("void*", 0) end
    env.toticks = function(t) return math.floor(0.5 + (t or 0) / TI) end
    env.totime = function(t) return (t or 0) * TI end
    env.readfile = function(n) return files[n] end
    env.writefile = function(n, s) files[n] = s end
    env.print = function() end
    env.loadstring = function(code, name) local f, e = real_G.loadstring(code, name); if f then setfenv(f, env) end return f, e end
    env.load = env.loadstring
    env.require = function(name)
        if name == "ffi" or name == "bit" then return real_G.require(name) end
        local m = libs[name]
        if m == nil then error("module '" .. tostring(name) .. "' not found") end
        return m
    end
    env._G = env
    w.env = env
    local allowed_nil = { LPH_OBFUSCATED = true, SPECTER_SHARED = true, debug = true, os = true, io = true, jit = true }
    setmetatable(env, { __index = function(t, k)
        if allowed_nil[k] then return nil end
        error("undefined global read: " .. tostring(k), 2)
    end })

    counted(client, "client.", { "trace_line", "trace_bullet", "current_threat", "eye_position", "camera_angles", "scale_damage" })
    counted(entity, "entity.", { "get_prop", "hitbox_position", "get_players", "get_all", "get_origin", "get_player_weapon", "get_classname",
                                "is_alive", "is_dormant", "get_player_name", "get_steam64", "get_esp_data", "get_bounding_box", "set_prop" })
    counted(ui, "ui.", { "get", "set", "set_visible", "set_callback", "update" })
    counted(env.plist, "plist.", { "get", "set" })
    local render_count = getmetatable(renderer).__index
    getmetatable(renderer).__index = function(t, k) return function(...)
        w.api["renderer." .. k] = (w.api["renderer." .. k] or 0) + 1
        if w.sites then
            local info = real_G.debug.getinfo(2, "Sl")
            if info and info.source == "@script" then
                local sk = "renderer." .. k .. "@" .. info.currentline
                w.sites[sk] = (w.sites[sk] or 0) + 1
            end
        end
    end end
    counted(renderer, "renderer.", { "measure_text", "world_to_screen" })

    local chunk, err = real_G.loadstring(src, "@script")
    assert(chunk, err)
    setfenv(chunk, env)
    local ok, lerr = xpcall(chunk, function(e) return tostring(e) .. "\n" .. real_G.debug.traceback("", 2) end)
    w.loaded, w.load_error = ok, lerr

    -- ── driving ──────────────────────────────────────────────────────────────────
    local function timed(name, ...)
        local list = w.callbacks[name]
        if not list then return end
        local t0 = clock()
        for i = 1, #list do
            local n = 0
            if w.budget then
                real_G.debug.sethook(function()
                    n = n + 1
                    if n > w.budget then
                        real_G.debug.sethook()
                        error("RUNAWAY (" .. w.budget .. "k instructions) in " .. name .. "\n" .. real_G.debug.traceback("", 2))
                    end
                end, "", 1000)
            end
            local okc, e = pcall(list[i], ...)
            if w.budget then real_G.debug.sethook() end
            if not okc then w.errors[#w.errors + 1] = name .. ": " .. tostring(e) end
        end
        w.timers[name] = (w.timers[name] or 0) + (clock() - t0)
        w.calls[name] = (w.calls[name] or 0) + 1
    end
    w.fire = timed

    -- packets: the script chokes with cmd.allow_send_packet = false; otherwise gamesense's fake lag (Enabled + Limit refs)
    w.choked, w.sent = 0, true
    local function gs_ref(name, i)
        for key, list in pairs(refs) do
            if key:sub(-#name - 1) == "|" .. name and key:sub(1, 3) == "AA|" then
                local it = items[list[i or 1]]
                return it and it.value, it
            end
        end
        return nil
    end
    w.gs_ref = gs_ref
    local function cmd()
        return { command_number = w.tick_n, tick_count = w.tick_n, chokedcommands = w.choked, pitch = 0, yaw = 0, roll = 0,
                 forwardmove = 450, sidemove = 0, upmove = 0, in_attack = 0, in_attack2 = 0, in_jump = 0, in_duck = 0, in_use = 0,
                 in_speed = 0, in_forward = 1, in_back = 0, in_moveleft = 0, in_moveright = 0, in_reload = 0, in_score = 0,
                 allow_send_packet = true, no_choke = false, quick_stop = false, weaponselect = 0, hasbeenpredicted = false,
                 move_yaw = 0, mousedx = 0, mousedy = 0, buttons = 0, force_defensive = false, discharge_pending = false }
    end

    function w.tick()
        w.tick_n = w.tick_n + 1
        for i = #w.delayed, 1, -1 do
            local d = w.delayed[i]
            if d.at <= w.tick_n then table.remove(w.delayed, i); pcall(d.fn, unpack(d.args)) end
        end
        advance_world()
        timed("net_update_start")
        timed("net_update_end")
        local c = cmd()
        timed("predict_command", c)
        timed("setup_command", c)
        timed("run_command", c)
        timed("finish_command", c)
        local fl_on = gs_ref("Enabled", 1)          -- AA|Fake lag|Enabled is found first only if it exists; fall back below
        local limit = 1
        for key, list in pairs(refs) do
            if key == "AA|Fake lag|Enabled" and items[list[1]].value then
                local lim = refs["AA|Fake lag|Limit"]
                limit = lim and items[lim[1]].value or 14
            end
        end
        local send
        if c.allow_send_packet == false then send = false
        elseif c.no_choke then send = true
        else send = w.choked >= math.max(1, (opts.limit or limit)) end
        w.last_cmd = c
        w.sent = send
        w.choked = send and 0 or w.choked + 1
    end

    -- the local player's movement (the AA picks its state from it)
    function w.set_local(vx, vy, on_ground, duck)
        local me = ents[ME]
        me.vx, me.vy = vx or 0, vy or 0
        me.flags = (on_ground == false) and 0 or 1
        me.duck = duck or 0
    end
    w.refs = refs
    w.ui = ui

    function w.frame()
        w.frame_n = w.frame_n + 1
        timed("pre_render")
        timed("paint")
        timed("paint_ui")
    end

    function w.shoot(target, hit)
        local id = w.tick_n
        timed("aim_fire", { id = id, target = target, hit_chance = 70, hitgroup = 1, damage = 80, backtrack = 0, tick = w.tick_n })
        if hit then
            timed("aim_hit", { id = id, target = target, hitgroup = 1, damage = 80 })
            timed("player_hurt", { userid = target, attacker = ME, dmg_health = 80, health = 20, hitgroup = 1 })
        else
            timed("aim_miss", { id = id, target = target, reason = "?", hitgroup = 1 })
        end
    end

    -- every checkbox on, every multiselect fully selected: the most expensive configuration
    function w.everything_on()
        for id, it in ipairs(items) do
            if not it.ref then
                if it.kind == "checkbox" then ui.set(id, true)
                elseif it.kind == "multiselect" and it.list then ui.set(id, it.list) end
            end
        end
    end

    w.ents, w.enemies, w.mates = ents, enemies, mates
    return w
end

return M
