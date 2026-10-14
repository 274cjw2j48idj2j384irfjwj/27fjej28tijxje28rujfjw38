"""Regression tests for azura.lua (the Primordial script): compiles under LuaJIT, survives the bot's comment stripping,
the resolver learns, and the anti-aim does not give its desync side away.

    pip install lupa
    python3 tests/azura_regress.py

Resolver: the block between "--- @info: resolver: side from" and its "--- @endregion" runs on a mock Primordial
(tests/azura/resolver_world.lua: enemies with a known body side, an aimbot that hits when the forced side is right,
8% spread misses, so ~0.92 is the ceiling).
Anti-aim: the real run_antiaim (+ the builder helpers) runs 6000 ticks per state on a mock Primordial with the default
config embedded in azura.lua (configs.default_config); the azura resolver then shoots at the angles it produced.
A forced side guess is a coin flip (~0.5); with the old "desync side follows the yaw side" behaviour it hit 0.81."""
import ast
import base64
import json
import os
import re
import sys

import lupa.luajit21 as L

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = open(os.path.join(ROOT, "azura.lua"), encoding="utf-8").read()
WORLD = open(os.path.join(ROOT, "tests", "azura", "resolver_world.lua"), encoding="utf-8").read()
FAILS = []


def check(ok, what):
    print(("ok   " if ok else "FAIL ") + what)
    if not ok:
        FAILS.append(what)


def chunk(start, end_marker):
    i = SRC.index(start)
    return SRC[i:SRC.index(end_marker, i)]


def compiles(src):
    lua = L.LuaRuntime()
    return lua.eval("function(s) local f, e = loadstring(s); return {f ~= nil, tostring(e)} end")(src)


def strip_like_the_bot(src):
    tree = ast.parse(open(os.path.join(ROOT, "discord_bot.py"), encoding="utf-8").read())
    fn = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "strip_lua_comments")
    ns = {"re": re}
    exec(compile(ast.Module(body=[fn], type_ignores=[]), "strip_lua_comments", "exec"), ns)
    return ns["strip_lua_comments"](src)


# ── compile ───────────────────────────────────────────────────────────

r = compiles(SRC)
check(r[1], "azura.lua compiles under LuaJIT (%s)" % r[2])
r = compiles(strip_like_the_bot(SRC))
check(r[1], "azura.lua without comments (the #staff post) compiles (%s)" % r[2])
for gone in ("udp_connect", "auth.check_user", "send_logs", "sigmoid_adjustment", "resolver_helper"):
    check(gone not in SRC, "no %s (login / server / old random resolver)" % gone)

# ── resolver ──────────────────────────────────────────────────────────

RESO = chunk("--- @info: resolver: side from", "--- @endregion")


def resolver_rate(mode, seed):
    lua = L.LuaRuntime()
    out = lua.eval("function(src, ...) return assert(loadstring(src))(...) end")(WORLD, RESO, mode, seed)
    return 1.0 if out.startswith("disabler") else float(out.split("hit rate ")[1].split()[0])


LIMITS = {"static": (0.80, 1), "freestand": (0.75, 1), "jitter": (0.85, 1), "anti_brute": (0.70, 1), "legit": (0.75, 1),
          "no_logic": (0, 0.60), "disabler": (1, 1)}
for mode, (lo, hi) in LIMITS.items():
    rate = sum(resolver_rate(mode, s) for s in range(1, 6)) / 5
    check(lo <= rate <= hi, "resolver %-10s %.2f (limit %.2f-%.2f)" % (mode, rate, lo, hi))

# ── anti-aim ──────────────────────────────────────────────────────────

CFG = json.loads(base64.b64decode(re.search(r'configs\.default_config = "([^"]+)"', SRC).group(1)))
HELPERS = chunk("builder.new_packet = function()", "builder.closest_point_on_ray = function")
RUN_AA = chunk("run_antiaim = function(ctx, cmd, unpredicted)", "\non_miss = function(event)")
SPIN = chunk("builder.spin = function(custom_speed)", "builder.clockpitch = function()")

AA_MOCK = r'''
local cfg_json, random_side = ...
local cfg = {}
for _, items in pairs(json_decode(cfg_json)) do
    for _, it in ipairs(items) do cfg[it[1]] = it[2] end
end
local function item(name, default)
    local v = cfg[name]
    if v == nil then v = default end
    return { get = function(_, i) if type(v) == "table" then for _, kv in ipairs(v) do if kv[1] == i then return kv[2] end end return false end return v end }
end
states = {"Global", "Stand", "Move", "Slow walk", "Duck", "Duck move", "Air", "Air duck", "Fakelag", "Manual", "Freestand"}
local short = {"G", "S", "M", "SW", "D", "DM", "A", "AD", "F", "MN", "FR"}
ui = { antiaim = { builder = {
        enable = item("Custom antiaim", true), edge_yaw = item("Edge yaw", false),
        random_side = { get = function() return random_side end }, anti_brute = item("Anti bruteforce", true),
        pitch = item("Pitch", 2), yaw = item("Base", 2), defensive_ping = item("Defensive mode", 1) },
    features = { antibackstab = item("Anti backstab", true), safehead = item("Safe head", {}), warmup = item("Randomization", {}),
                 correction = item("Crouch correction", {}) } } }
for i = 1, #states do
    local p = short[i] .. " | "
    ui.antiaim.builder[i] = {
        override = item("Override - " .. states[i], false), yaw_mode = item(p .. "Yaw mode", 1), yaw_val = item(p .. "Yaw", 0),
        yaw_left = item(p .. "Left", 0), yaw_right = item(p .. "Right", 0), yaw_meta_left = item(p .. "Left randomization", 0),
        yaw_meta_right = item(p .. "Right randomization", 0), yaw_delay = item(p .. "Delay", 2), meta_delay = item(p .. "Delay fluctuation", 0),
        yaw_modifier = item(p .. "Modifier mode", 1), modifier_degree = item(p .. "Modifier degree", 0), modifier_random = item(p .. "Modifier randomization", 0),
        desync = item(p .. "Desync", 1), desync_left = item(p .. "Fake left", 60), desync_right = item(p .. "Fake right", 60),
        desync_meta_left = item(p .. "Left randomization", 0), desync_meta_right = item(p .. "Right randomization", 0),
        trigger_defensive = item(p .. "Defensive", 1), defensive_pitch = item(p .. "Defensive pitch", 1),
        defensive_pitch_val = item(p .. "Pitch value (1)", 0), defensive_pitch_val2 = item(p .. "Pitch value (2)", 0),
        defensive_yaw = item(p .. "Defensive yaw", 1), defensive_yaw_val = item(p .. "Yaw value", 0),
        defensive_speed = item(p .. "Spin speed", 0), defensive_range = item(p .. "Spin range", 0) }
end
local function ref(v) local r = { v = v }
    function r:set(a, b) if b ~= nil then self[a] = b else self.v = a end end
    function r:get() return self.v end
    return r end
refs = { pitch = ref(1), yawbase = ref(1), yawadd = ref(0), rotate = ref(false), rotaterange = ref(0), rotatespeed = ref(0),
    jittermode = ref(1), jittertype = ref(1), jitterrange = ref(0), double_tap = ref(true), hide_shots = ref(false),
    fake_duck = ref(false), overridemove = ref(false), overridemovesw = ref(false), desyncside = ref(2), leftamount = ref(100),
    rightamount = ref(100), fsstate = ref(0), freestand = ref(false), slow_motion = ref(false) }
TICK, CHOKE = 0, 0
globals = { tick_count = function() return TICK end, interval_per_tick = function() return 1 / 64 end, server_tick = function() return TICK end }
time_to_ticks = function(t) return math.floor(0.5 + t * 64) end
engine_get_choked_commands = function() return CHOKE end
client_random_float = function(a, b) return a + math.random() * (b - a) end
client_random_int = function(a, b) return math.random(a, b) end
antiaim_get_desync_side = function() return refs.desyncside.v == 3 and 1 or 2 end
antiaim_get_real_angle = function() return 0 end
exploits_get_charge = function() return 14 end
exploits_get_max_charge = function() return 14 end
exploits = { force_anti_exploit_shift = function() end }
game_rules_get_prop = function(name) if name == "m_gamePhase" then return 1 end return 0 end
entity_list_get_players = function() return {} end
entity_list_get_entity = function() return nil end
e_cmd_buttons = { USE = 1, FORWARD = 2, MOVERIGHT = 3, MOVELEFT = 4, JUMP = 5 }
e_hitboxes = { BODY = 3 }
vec3_t = function(x, y, z) return { x = x, y = y, z = z } end
math.vec_length2d = function(v) return math.sqrt(v.x * v.x + v.y * v.y) end
local lp = { get_prop = function(_, name)
        if name == "m_vecVelocity" then local v = vec3_t(0, 0, 0); v.length = function() return 0 end; return v end
        if name == "m_flPoseParameter" then return 0.5 end
        return vec3_t(0, 0, 0) end,
    get_active_weapon = function() return nil end, get_render_origin = function() return vec3_t(0, 0, 0) end }
entity_list_get_local_player = function() return lp end
defensive = { is_active = function(_, _, _, mode) if mode then return { tick = 0, active = false } end return false end, trigger = function() end }
global = { current_state_number = 2 }
builder = { misses = 0, invert_defensive = false, old_defensive = false, invert_delay = true, target_delay = 0, speed = 0,
            current_pitch = 0, current_yaw = 0, goal_yaw = 0, save_yaw = 0, warmup = 0 }
'''

AA_RUN = r'''
local state = ...
global.current_state_number = state
local ctx = { inv = false }
function ctx:set_invert_desync(v) self.inv = v end
function ctx:set_yaw() end
function ctx:set_pitch() end
local cmd = { has_button = function() return false end }
local yaws, sides = {}, {}
local base = TICK
for t = 1, 6000 do
    TICK = base + t
    CHOKE = (TICK % 2 == 0) and 1 or 0
    ctx.inv = false
    run_antiaim(ctx, cmd, nil)
    if CHOKE == 0 then
        local side = refs.desyncside.v == 3 and -1 or 1
        if ctx.inv then side = -side end
        if refs.desyncside.v == 4 then side = (TICK % 4 == 1) and 1 or -1 end  -- Primordial's jitter: every other packet
        yaws[#yaws + 1] = refs.yawadd.v
        sides[#sides + 1] = side
    end
end
return yaws, sides
'''

ATTACK = r'''
local block, yaws, sides = ...
local TICK = 0
globals = { tick_count = function() return TICK end }
time_to_ticks = function(x) return math.floor(0.5 + x * 64) end
math.vec_length2d = function(v) return math.sqrt(v.x * v.x + v.y * v.y) end
e_hitboxes = { HEAD = 0 }
auto_cfg = { resolve_antiaim = true }
menu_find = function() return { set = function() end, [2] = { get = function() return false end } } end
local function opt(v) return { get = function(_, i) if type(v) == "table" then return v[i] or false end return v end } end
ui = { ragebot = { nexzu_reso = opt(true), logic_reso = opt(true), pose_reso = opt(false),
    resolver = { enable_resolver = opt(false), unsafe_reso = opt(true) }, reso_cfg = { yaw_calc = opt(2), disablers = opt({}), at_disabler = opt(3) } } }
e_player_flags = { ON_GROUND = 1, DUCKING = 2 }
table.contains = function() return false end
reso = {}
get_entity_address = function() return nil end
resolver = { data = {}, mem = {}, previous = {}, trust = { fs = 0, jitter = 0 } }
assert(loadstring(block))()
local st = { m_flEyeYaw = 0, m_flGoalFeetYaw = 0, m_flFeetSpeedForwardsOrsideWays = 0, m_flStopToFullRunningFraction = 0, m_fDuckAmount = 0 }
resolver.animstate = function() return st end
local sim = 0
local ent = { get_index = function() return 1 end, get_prop = function(_, n)
    if n == "m_flSimulationTime" then return sim end
    if n == "m_fFlags" then return 1 end
    return { x = 0, y = 0, z = 0 } end }
local lp = { get_eye_position = function() return { x = 0, y = 0, z = 64 } end }
local hits, shots = 0, 0
for i = 1, #yaws do
    TICK = TICK + 2
    sim = sim + 2 / 64
    st.m_flEyeYaw = 180 + yaws[i]
    resolver.update(lp, ent)
    if i % 12 == 0 then
        local p = resolver.previous[1]
        reso.idx, reso.key, reso.kind, reso.rel = 1, p.key, p.kind, p.rel
        local ok = math.abs(p.m_flDesync - sides[i] * 58) <= 20
        shots = shots + 1
        if ok then hits = hits + 1 end
        resolver.on_result(ent, ok, not ok)
    end
end
return hits / shots
'''


def aa_rates(random_side):
    lua = L.LuaRuntime()
    lua.globals().json_decode = lambda s: lua.table_from(json.loads(s), recursive=True)
    lua.eval("function(src, ...) return assert(loadstring(src))(...) end")(AA_MOCK, json.dumps(CFG), random_side)
    for code in (SPIN, HELPERS, RUN_AA):
        lua.execute(code)
    run = lua.eval("function(src, s) return assert(loadstring(src))(s) end")
    rates = []
    for state in range(1, 9):
        lua.execute("math.randomseed(%d)" % state)
        yaws, sides = run(AA_RUN, state)
        att = L.LuaRuntime()
        rates.append(att.eval("function(src, ...) return assert(loadstring(src))(...) end")(
            ATTACK, RESO, att.table_from(list(yaws.values())), att.table_from(list(sides.values()))))
    return rates


NAMES = ["Global", "Stand", "Move", "Slow walk", "Duck", "Duck move", "Air", "Air duck"]
new = aa_rates(True)
for name, rate in zip(NAMES, new):
    check(rate <= 0.65, "anti-aim %-9s resolver hits %.2f (limit 0.65)" % (name, rate))
check(sum(new) / len(new) <= 0.58, "anti-aim mean %.2f (limit 0.58, a coin flip is ~0.5)" % (sum(new) / len(new)))
old = aa_rates(False)
check(sum(old) / len(old) >= 0.70, "Random desync side off: the side follows the yaw again, the resolver learns it (%.2f)"
      % (sum(old) / len(old)))

print("\n%d failed" % len(FAILS) if FAILS else "\nall passed")
sys.exit(1 if FAILS else 0)
