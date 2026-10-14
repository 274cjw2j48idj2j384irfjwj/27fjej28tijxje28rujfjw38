-- mock Primordial for the resolver block: enemies with a known body side, an aimbot that hits when the forced side is right
local block, mode, seed = ...
math.randomseed(seed or 1)

local TICK = 1 / 64
local tick = 0
globals = { tick_count = function() return tick end }
global_vars_interval_per_tick = function() return TICK end
time_to_ticks = function(t) return math.floor(0.5 + t / TICK) end
math.vec_length2d = function(v) return math.sqrt(v.x * v.x + v.y * v.y) end
vec3_t = function(x, y, z) return { x = x, y = y, z = z } end
e_hitboxes = { HEAD = 0 }
auto_cfg = { resolve_antiaim = true }
local native = true
menu_find = function() return { set = function(_, v) native = v end } end
local function opt(v) return { get = function(_, i) if type(v) == "table" then return v[i] or false end return v end } end
local logic = mode ~= "no_logic"
ui = { ragebot = {
    nexzu_reso = opt(true), logic_reso = opt(logic), pose_reso = opt(true),
    resolver = { enable_resolver = opt(false), unsafe_reso = opt(true), duck_mode = opt(false), auto_duck = opt(false),
                 safe_peek = opt(false), pred_sel = opt(50), calc_box = opt(25), shot_pred = opt(30), hit_sens = opt(2), safe_mode = opt(1) },
    reso_cfg = { yaw_calc = opt(2), disablers = opt({ [9] = true }), at_disabler = opt(1) },
} }
e_player_flags = { ON_GROUND = 1, DUCKING = 2 }
e_hitscan_groups = { HEAD = 0 }
ragebot_get_autopeek_pos = function() return nil end
ragebot_get_active_cfg = function() return 0 end
client_get_fps = function() return 200 end
get_user_ping = function() return 30 end
table.contains = function(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
reso = {}
get_entity_address = function() return nil end
resolver = { data = {}, mem = {}, previous = {}, trust = { fs = 0, jitter = 0 } }

-- CONV: which way round the freestanding / jitter sign maps to the real side (the resolver has to learn it)
local CONV_FS, CONV_JIT = -1, 1
local enemies, current_fs = {}, {}
local local_player = { get_eye_position = function() return vec3_t(0, 0, 64) end,
    has_player_flag = function(_, f) return f == 1 end, get_prop = function() return 0 end }

local function new_enemy(idx, kind)
    local e = { idx = idx, kind = kind, side = math.random(2) == 1 and 1 or -1, sim = 10, eye = math.random() * 360 - 180,
                st = { m_flEyeYaw = 0, m_flGoalFeetYaw = 0, m_flFeetSpeedForwardsOrsideWays = 0,
                       m_flStopToFullRunningFraction = 0, m_fDuckAmount = 0 }, jit = 1 }
    e.ent = {
        get_index = function() return idx end,
        get_prop = function(_, name)
            if name == "m_flSimulationTime" then return e.sim end
            if name == "m_fFlags" then return 1 end
            if name == "m_vecVelocity" then return vec3_t(0, 0, 0) end
        end,
        get_hitbox_pos = function() return vec3_t(500, idx * 40, 64) end,
        is_alive = function() return true end,
        is_dormant = function() return false end,
    }
    return e
end

trace_line = function(a, b)
    -- the covered side of the current enemy is the one its freestanding sign names
    local fs = current_fs.v or 0
    local left = b.y > current_fs.y
    if fs == 0 then return { fraction = 1 } end
    return { fraction = ((fs > 0) == left) and 0.3 or 1 }
end

entity_list_get_local_player = function() return local_player end
entity_list_get_players = function()
    local t = {}
    for _, e in ipairs(enemies) do t[#t + 1] = e.ent end
    return t
end

assert(loadstring(block))()
resolver.animstate = function(idx) return enemies[idx].st end
local real_freestand = resolver.freestand
resolver.freestand = function(lp, ent)
    local e = enemies[ent:get_index()]
    current_fs.y = e.idx * 40
    if e.kind == "freestand" or e.kind == "anti_brute" then
        current_fs.v = (math.random() < 0.85) and e.side * CONV_FS or 0
    else
        current_fs.v = 0
    end
    return real_freestand(lp, ent)
end

-- one enemy update: choke 1-3 ticks (legit: none), eye yaw / side by AA kind
local function step(e)
    local ticks = e.kind == "legit" and 1 or math.random(2, 4)
    e.sim = e.sim + ticks * TICK
    if e.kind == "jitter" then
        e.jit = -e.jit
        e.st.m_flEyeYaw = e.eye + 35 * e.jit
        e.side = e.jit * CONV_JIT * -1
    else
        e.st.m_flEyeYaw = e.eye
    end
end

local function true_body(e)
    if e.kind == "legit" then return 0 end
    return e.side * 58
end

if mode == "disabler" then
    client_get_fps = function() return 40 end
    for i = 1, 3 do enemies[i] = new_enemy(i, "static") end
    lets_resolve()
    assert(resolver.active == false and native == true, "a disabler (Disable) must turn the resolver off and give the native back")
    ui.ragebot.reso_cfg.at_disabler = opt(2)
    lets_resolve()
    local set = false
    resolver.hitscan({ player = enemies[1].ent, set_safepoint_state = function(_, on) set = on end })
    assert(resolver.active and set, "At disabler = Safe point must keep resolving and set the head safe point")
    return "disabler    ok"
end
if mode == "no_logic" then mode = "static" end
local N, SHOTS = 40, 12
local hits, shots, first3 = 0, 0, 0
for i = 1, N do enemies[i] = new_enemy(i, mode) end
for _ = 1, SHOTS do
    for _ = 1, 6 do
        tick = tick + 1
        for _, e in ipairs(enemies) do step(e) end
        lets_resolve()
    end
    for _, e in ipairs(enemies) do
        -- AIMBOT_SHOOT: what the hitlog / feedback takes from the resolver
        local p = resolver.previous[e.idx]
        reso.idx, reso.key, reso.kind, reso.rel = e.idx, p.key, p.kind, p.rel
        local forced = p.m_flDesync
        local ok = math.abs(forced - true_body(e)) <= 20
        local spread = math.random() < 0.08
        shots = shots + 1
        if ok and not spread then
            hits = hits + 1
            resolver.on_result(e.ent, true, false)
        else
            resolver.on_result(e.ent, false, not spread)
            if e.kind == "anti_brute" and not spread then e.side = -e.side end
        end
    end
end
assert(native == false, "native resolver must be off while the lua one runs")
return string.format("%-11s hit rate %.2f  (trust fs %+.1f jitter %+.1f)", mode, hits / shots, resolver.trust.fs, resolver.trust.jitter)
