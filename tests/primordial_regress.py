"""Checks for specter_primordial.lua (the Primordial script): it compiles under LuaJIT, it survives the bot's comment stripping, the
removed parts stay out, and the menu shows the right groups / page buttons on every page.

    pip install lupa
    python3 tests/primordial_regress.py

No simulations (owners, Oct 2026: the mock only confuses): resolver / anti-aim / backtrack decisions come from how
Primordial and CS:GO work and from the game."""
import ast
import os
import re
import sys

import lupa.luajit21 as L

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = open(os.path.join(ROOT, "specter_primordial.lua"), encoding="utf-8").read()
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
check(r[1], "specter_primordial.lua compiles under LuaJIT (%s)" % r[2])
r = compiles(strip_like_the_bot(SRC))
check(r[1], "specter_primordial.lua without comments (the #staff post) compiles (%s)" % r[2])
for gone in ("udp_connect", "auth.check_user", "send_logs", "sigmoid_adjustment", "resolver_helper", "cmd.tick_count ="):
    check(gone not in SRC, "no %s (login / server / old random resolver / tick count override)" % gone)

# the loader's two versions, built like the bot does (primordial_builds): beta has no resolver code at all
tree = ast.parse(open(os.path.join(ROOT, "discord_bot.py"), encoding="utf-8").read())
want = {"strip_lua_comments", "make_primordial_beta", "primordial_builds", "PM_BETA_STUB", "PM_AUTH_GATE",
        "is_primordial_script"}
body = [n for n in tree.body if (isinstance(n, ast.FunctionDef) and n.name in want)
        or (isinstance(n, ast.Assign) and any(getattr(t, "id", "") in want for t in n.targets))]
ns = {"re": re}
exec(compile(ast.Module(body=body, type_ignores=[]), "builds", "exec"), ns)
builds = ns["primordial_builds"](SRC)
for plan in ("pm_nightly", "pm_beta"):
    r = compiles(builds[plan])
    check(r[1], "%s build compiles (%s)" % (plan, r[2]))
check("resolver.update = function" in builds["pm_nightly"] and "resolver.update = function" not in builds["pm_beta"]
      and "RES_NOCHOKE" not in builds["pm_beta"] and "lets_resolve = function() end" in builds["pm_beta"],
      "pm_beta: the resolver code is cut out (a stub with the same names), pm_nightly keeps it")

# auth gate (owners, Oct 2026: "amint alapból a cloud scriptet töltik be ... kicrashel"): the customer builds
# (pm_nightly / pm_beta) carry it, the repo file / #staff dev build never do (it runs without a key)
check("[pm-auth:begin]" in builds["pm_nightly"] and "[pm-auth:begin]" in builds["pm_beta"]
      and "[pm-auth:begin]" not in SRC and ns["is_primordial_script"](SRC)
      and not ns["is_primordial_script"](builds["pm_nightly"]),
      "auth gate: in both customer builds, not in the repo file / dev build")
# with the loader (the server sets _auth_ok / _auth_alive / a fresh _auth_ts) the script runs; standalone (nothing set)
# or with a stale token it returns at once
GATE = ns["PM_AUTH_GATE"]
gl = L.LuaRuntime(unpack_returned_tuples=True)
gl.execute("NOW = 1000 client = { get_unix_time = function() return NOW end, log = function() end }")
def run_gate(setup):
    return gl.eval("""(function()
        _auth_ok, _auth_alive, _auth_ts, _auth_key, _server_url, RAN = nil, nil, nil, nil, nil, false
        %s
        local fn = assert(loadstring(GATE .. "\\nRAN = true\\nreturn _auth_ok, _auth_key, _server_url"))
        fn()
        return RAN, _auth_ok, _auth_key, _server_url
    end)()""" % setup)
gl.globals().GATE = GATE
ran_ok = run_gate('_auth_ok, _auth_alive, _auth_ts, _auth_key, _server_url = true, true, 995, "k", "u"')
ran_none = run_gate('')
ran_stale = run_gate('_auth_ok, _auth_alive, _auth_ts = true, true, 900')
ran_future = run_gate('_auth_ok, _auth_alive, _auth_ts = true, true, 1010')
check(tuple(ran_ok) == (True, None, None, None) and ran_none[0] is False
      and ran_stale[0] is False and ran_future[0] is False,
      "auth gate: loader + fresh token runs and wipes the globals; standalone / stale / future token stops (%s %s %s %s)"
      % (ran_ok[0], ran_none[0], ran_stale[0], ran_future[0]))

# ── menu: four main points, the pages of the active one ───────────────

NAV = chunk("-- menu (owners, Oct 2026): four main points", "--- @endregion")
MENU_HANDLE = chunk("menu_handle = function()", "\nend\n") + "\nend\n"
MENU_MOCK = r'''
PAGE = 0
local function proxy()
    return setmetatable({}, { __index = function(t, k)
        if k == "get" then return function(_, i) if t == ui.nav.slider then return PAGE end return i == nil and true or false end end
        local p = proxy(); rawset(t, k, p); return p end,
        __call = function() return nil end })
end
local function holds(conds)
    for _, c in ipairs(conds) do
        if #c == 1 then if not c[1] then return false end
        elseif c[1]:get() ~= c[2] then return false end
    end
    return true
end
SHOWN = {}
local function element(name)
    local e = proxy()
    rawset(e, "depend", function(_, ...) SHOWN[name] = holds({...}) end)
    return e
end
groups = setmetatable({}, { __index = function(t, k)
    local g = element("group:" .. k)
    rawset(g, "button", function(_, label) return element("button:" .. label) end)
    rawset(t, k, g); return g end })
ui = proxy()
info = { beta_build = true, beta_text2 = " (beta)" }
client_version = "5.5"
menu_add_separator = function() return proxy() end
menu_is_open = function() return true end
menu_set_group_column = function() end
handle_dragging = function() end
cl_logs = { c_logs = setmetatable({}, { __index = function() return 0 end }) }
states = {"Global", "Stand", "Move", "Slow walk", "Duck", "Duck move", "Air", "Air duck", "Fakelag", "Manual", "Freestand"}
'''
lua = L.LuaRuntime()
lua.execute(MENU_MOCK)
lua.execute(NAV + MENU_HANDLE)  # one chunk, like the file: menu_handle sees nav_main_of
EXPECT = {  # page -> (main point, groups that show)
    1: ("Config", {"configs", "cloud_configs"}), 2: ("Config", {"statistics"}),
    3: ("Ragebot", {"resolver", "resolver_beta", "reso_cfg"}), 10: ("Ragebot", {"ragebot"}), 11: ("Ragebot", {"tickbase"}),
    5: ("Ragebot", {"exploits", "helpers"}),
    4: ("Anti-Aim", {"settings", "antiaim", "features"}), 12: ("Anti-Aim", {"settings", "yaw", "jitter"}),
    13: ("Anti-Aim", {"settings", "desync"}), 14: ("Anti-Aim", {"settings", "defensive"}),
    6: ("Misc", {"visuals", "customization"}), 7: ("Misc", {"player", "communication"}), 8: ("Misc", {"misc", "movement"}),
    9: ("Misc", {"utils", "sync"}),
}
SUBS = {"Config": {"Configs", "Statistics"}, "Ragebot": {"Resolver", "Aimbot", "Tickbase", "Exploits"},
        "Anti-Aim": {"Builder", "Yaw / Jitter", "Desync", "Defensive"}, "Misc": {"Visuals", "Player", "Movement", "Utils"}}
for page, (main, want) in sorted(EXPECT.items()):
    lua.execute("PAGE = %d; SHOWN = {}; menu_handle()" % page)
    shown = {k.split(":", 1)[1] for k, v in dict(lua.globals().SHOWN).items() if v}
    groups_shown = {g for g in shown if g in {n for _, gs in EXPECT.values() for n in gs}}
    buttons = {b[2:] for b in shown if b.startswith("› ")}
    check(groups_shown == want and buttons == SUBS[main],
          "menu page %2d (%s): groups %s, pages %s" % (page, main, sorted(groups_shown), sorted(buttons)))

# the loader's beta version (BUILD_VERSION pm_beta): no Resolver page and no resolver groups, the helpers stay
beta = L.LuaRuntime()
beta.execute(MENU_MOCK.replace('info = { beta_build = true', 'info = { plan = "beta", beta_build = true'))
beta.execute(NAV + MENU_HANDLE)
for page, want in ((3, set()), (10, {"ragebot"}), (5, {"exploits", "helpers"})):
    beta.execute("PAGE = %d; SHOWN = {}; menu_handle()" % page)
    shown = {k.split(":", 1)[1] for k, v in dict(beta.globals().SHOWN).items() if v}
    groups_shown = shown & {"resolver", "resolver_beta", "reso_cfg", "ragebot", "exploits", "helpers"}
    buttons = {b[2:] for b in shown if b.startswith("› ")}
    check(groups_shown == want and (page == 3 or buttons == {"Aimbot", "Tickbase", "Exploits"}),
          "beta page %2d: groups %s, pages %s" % (page, sorted(groups_shown), sorted(buttons)))
check('info.plan ~= "dev"' in SRC.split("shotlog.result = function")[1][:300], "beta / nightly (a key) send no shot logs")

# the loader (specter_primordial_loader.lua): compiles, asks the server for a pm_* plan, and runs the script it downloads
LOADER = open(os.path.join(ROOT, "specter_primordial_loader.lua"), encoding="utf-8").read()
ok, err = compiles(LOADER)
check(ok, "loader compiles under LuaJIT" + ("" if ok else ": " + str(err)))
check("/verify?key=" in LOADER and "/script?key=" in LOADER and 'plan:find("^pm_")' in LOADER,
      "loader: verify -> script, only pm_ keys")
check("[resolver:begin]" not in LOADER and "shotlog" not in LOADER, "loader carries no script code")

# the advanced anti-aim's deciding functions (builder.adv: X-Way, Distort, Random hold, lua jitter, defensive picks): pure
# lua, run here with a seeded math.random. Not a simulation of the game: only the numbers they give
ADV = chunk("builder.xw_st, builder.ds_st", "-- \"Apply advanced preset\"")
adv = L.LuaRuntime(unpack_returned_tuples=True)
adv.execute("builder = {} globals = { tick_count = function() return 0 end } math.randomseed(7)\n" + ADV)
R = adv.eval("""function(code) return assert(loadstring(code))() end""")
xw = R("""local st, out = {}, {}
for n = 1, 2000 do out[n] = builder.adv.xway(st, 5, 50, 10, 1, builder.rnd) end
local seen, rep, lo, hi = {}, 0, 1e9, -1e9
for n = 1, #out do seen[out[n]] = (seen[out[n]] or 0) + 1; if n > 1 and out[n] == out[n-1] then rep = rep + 1 end
  lo = math.min(lo, out[n]); hi = math.max(hi, out[n]) end
local kinds, minc = 0, 1e9
for _, c in pairs(seen) do kinds = kinds + 1; minc = math.min(minc, c) end
return kinds, rep, lo, hi, minc""")
check(xw[0] == 5 and xw[1] == 0 and xw[2] == -40 and xw[3] == 60 and xw[4] == 400,
      "X-Way: 5 positions over centre +- range, each once a round, never twice in a row (%s)" % (xw,))
g = R("""local nan = 0 / 0
local st, a, b = {}, builder.adv.def_yaw({}, 11, 30, 0, false, 0, builder.rnd), builder.adv.def_yaw({}, 11, 30, 0, false, 1, builder.rnd)
return builder.adv.norm(nan), builder.adv.norm(math.huge), builder.adv.norm(190), builder.rnd(nan, 5) == 0 or builder.rnd(nan, 5) == 5, a, b""")
check(g[0] == 0 and g[1] == 0 and g[2] == -170 and g[3] and g[4] == -g[5],
      "AA numbers: NaN / inf give 0, the defensive jitter flick follows the packet parity and flips every sent packet (%s)" % (list(g),))
hold = R("""local st, run, worst, prev = {}, 0, 0, nil
for n = 1, 3000 do local v = builder.adv.xway(st, 3, 30, 0, 4, builder.rnd)
  if v == prev then run = run + 1 else run = 1 end; worst = math.max(worst, run); prev = v end
return worst""")
check(hold <= 8 and hold >= 2, "X-Way: a position is held at most hold packets (twice in a row only across a round: %d)" % hold)
ds = R("""local st, bad, lo, hi = {}, 0, 1e9, -1e9
for n = 1, 3000 do local v = builder.adv.distort(st, 40, 5, 35, 15, builder.rnd)
  if v ~= v then bad = bad + 1 end; lo = math.min(lo, v); hi = math.max(hi, v) end
local st2 = {}; builder.adv.distort(st2, 40, 0, 35, 15, builder.rnd)
local inside = builder.adv.distort(st2, 0, 0, 35, 15, builder.rnd)
return bad, lo, hi, inside""")
check(ds[0] == 0 and ds[1] >= -35 and ds[2] <= 45 and ds[3] == 0, "Distort: inside centre +- range, no NaN, a smaller range pulls it in (%s)" % (ds,))
hd = R("""local st, run, worst, prev, sides = {}, 0, 0, nil, {}
for n = 1, 3000 do local v = builder.adv.hold(st, -30, 30, 3, builder.rnd); sides[v] = true
  if v == prev then run = run + 1 else run = 1 end; worst = math.max(worst, run); prev = v end
return worst, sides[-30] and sides[30] and true or false""")
check(hd[0] == 3 and hd[1], "Random hold: both sides, each held at most hold packets (%s)" % (hd,))
jt = R("""local st, ok = {}, true
for n = 1, 500 do local v = builder.adv.jitter(st, 6, -12, 0, builder.rnd); ok = ok and v >= -12 and v <= 12 end
local prev = nil
for n = 1, 500 do local v = builder.adv.jitter(st, 7, 15, 10, builder.rnd)
  ok = ok and math.abs(v) >= 15 and math.abs(v) <= 25 and (prev == nil or (v > 0) ~= (prev > 0)); prev = v end
return ok""")
check(jt, "lua jitter: Random inside +- degree, Switch random changes side every packet with degree .. degree + random")
df = R("""local st, ok = {}, true
local a = builder.adv.def_pitch(st, 11, 0, 0, true, 0, builder.rnd)
ok = ok and (a == 89 or a == -89) and builder.adv.def_pitch(st, 11, 0, 0, false, 0, builder.rnd) == a
for t = 0, 5, 0.01 do local p = builder.adv.def_pitch(st, 12, -60, 80, false, t, builder.rnd); ok = ok and p >= -60 and p <= 80 end
local s1 = builder.adv.def_yaw(st, 10, 0, 0, true, 0, builder.rnd)
ok = ok and math.abs(s1) >= 90 and math.abs(s1) <= 150 and builder.adv.def_yaw(st, 10, 0, 0, false, 1, builder.rnd) == s1
ok = ok and builder.adv.def_yaw(st, 9, 0, 170, false, 0, builder.rnd) == -10 and builder.adv.def_yaw(st, 9, 0, -30, false, 0, builder.rnd) == 150
ok = ok and builder.adv.def_yaw(st, 11, 140, 0, false, 2, builder.rnd) == 140 and builder.adv.def_yaw(st, 11, -140, 0, false, 3, builder.rnd) == -140
for n = 1, 500 do local d = builder.adv.def_yaw(st, 12, 120, 0, n % 50 == 0, n, builder.rnd); ok = ok and d >= -120 and d <= 120 and d == d end
return ok""")
check(df, "defensive: Random up/down holds its pick, Sway stays between the values, Opposite / Random side / Jitter flick / Distort angles")
aim = R("""return builder.adv.aims_at(0, 100, 5, 20), builder.adv.aims_at(90, 100, 0, 20), builder.adv.aims_at(0/0, 1, 1, 20),
  builder.adv.aims_at(179, -100, 1, 20), builder.rnd(5, -5) >= -5, builder.adv.norm(540), builder.adv.norm(-190)""")
check(aim[0] and not aim[1] and not aim[2] and aim[3] and aim[4] and aim[5] == -180 and aim[6] == 170,
      "threat aim / rnd with b < a / yaw normalising (%s)" % (aim,))

# default.cfg (owners: "csináld meg a legjobb configot ezzel"): it decodes, every anti-aim item it sets exists, states 1-8 use
# the advanced engine with the same values as the "Apply advanced preset" button
import base64, json
cfg = json.loads(base64.b64decode(re.search(r'configs\.default_config\s*=\s*"([^"]+)"', SRC).group(1)))
labels = set(re.findall(r'shortstates\[i\] \.\. " \| ([^"]+)"', SRC))
bad = [n[0] for g in ("Yaw", "Jitter", "Desync", "Defensive") for n in cfg[g]
       if not n[0].startswith("Override - ") and n[0].split(" | ", 1)[1] not in labels]
check(not bad, "default.cfg: every anti-aim item it sets exists (%s)" % bad[:5])
get = lambda g, n: next((it[1] for it in cfg[g] if it[0] == n), None)
pre = SRC[SRC.index("    local P = {"):SRC.index("    }\n", SRC.index("    local P = {"))]
rows = re.findall(r"\[(\d)\] = \{ ([-\d, ]+), \{", pre)
same = len(rows) == 8
for i, vals in rows:
    v = [int(x) for x in vals.split(",") if x.strip()]
    p = ["G", "S", "M", "SW", "D", "DM", "A", "AD"][int(i) - 1]
    same = same and [get("Yaw", p + " | Yaw mode"), get("Yaw", p + " | Range"), get("Jitter", p + " | Modifier mode"),
                     get("Desync", p + " | Desync"), get("Defensive", p + " | Defensive")] == [v[0], v[3], v[9], 5, 6]
check(same and get("Settings", "Anti brute mode") == 2 and get("Features", "Fakelag variance") is True
      and get("Settings", "Adaptive AA") is True and "set(b.adaptive, true)" in SRC
      and (get("Yaw", "M | Left"), get("Yaw", "M | Right"), get("Yaw", "M | Left randomization")) == (-10, 10, -18),
      "default.cfg: the advanced anti-aim + Adaptive AA with the owner's old left / right, the same as the preset button")

# direct control (dev build): the anti-aim code writes into recorders, the lua sends yaw / pitch / desync itself
DIRECT = chunk("-- the Primordial jitter types (yaw add", "run_antiaim = function(ctx, cmd, unpredicted)")
dr = L.LuaRuntime(unpack_returned_tuples=True)
dr.execute("""builder = {} globals = { tick_count = function() return 0 end }
info = { plan = "dev" }
local function item(v) return { v = v, get = function(self) return self.v end, set = function(self, x) self.v = x end } end
ui = { antiaim = { builder = { enable = item(true), direct = item(true) } } }
REAL = {}
refs = {}
for _, f in ipairs({ "pitch", "yawbase", "yawadd", "rotate", "rotaterange", "rotatespeed", "jittermode", "jittertype",
    "jitterrange", "desyncside", "leftamount", "rightamount" }) do refs[f] = item(0); REAL[f] = refs[f] end
refs.left, refs.right, refs.back = item(false), item(false), item(false)
engine_get_view_angles = function() return { y = 30 } end
entity_list_get_players = function() return {} end
""" + ADV + DIRECT + """
function CTX()
    local c = { calls = {} }
    for _, m in ipairs({ "set_yaw", "set_pitch", "set_desync", "set_invert_desync", "set_fakelag" }) do
        c[m] = function(self, v) self.calls[m] = v end
    end
    return c
end""")
D = dr.eval("""function(code) return assert(loadstring(code))() end""")
r = D("""
builder.fresh = true
builder.direct_begin()
local swapped = refs.yawadd ~= REAL.yawadd
local ctx = CTX()
local dctx = builder.direct_ctx(ctx)
refs.yawbase:set(2) refs.yawadd:set(15) refs.pitch:set(2) refs.jittermode:set(1)
refs.desyncside:set(2) refs.leftamount:set(80) refs.rightamount:set(60)
dctx:set_fakelag(true)
builder.direct_restore()
local restored = refs.yawadd == REAL.yawadd
builder.direct_apply(ctx, { get_eye_position = function() return { x = 0, y = 0 } end })
local c = ctx.calls
return swapped, restored, c.set_yaw, c.set_pitch, c.set_desync, c.set_invert_desync, c.set_fakelag, REAL.yawadd.v, REAL.desyncside.v, REAL.leftamount.v
""")
check(r[0] and r[1] and r[2] == -135 and r[3] == 89 and abs(r[4] + 0.8) < 1e-9 and r[5] is False and r[6] is True
      and r[7] == 0 and r[8] == 2 and r[9] == 100,
      "direct control: recorders swapped in and back, yaw = view 30 + 180 + 15, pitch down, desync left 80 %% (%s)" % (r,))
r = D("""
builder.direct_begin()
local ctx = CTX()
local dctx = builder.direct_ctx(ctx)
refs.desyncside:set(2) refs.leftamount:set(80) refs.rightamount:set(60)
dctx:set_invert_desync(true)
dctx:set_yaw(200)
dctx:set_pitch(-45)
builder.direct_restore()
builder.direct_apply(ctx, {})
return ctx.calls.set_yaw, ctx.calls.set_pitch, ctx.calls.set_desync
""")
check(r[0] == -160 and r[1] == -45 and abs(r[2] - 0.6) < 1e-9,
      "direct control: an own set_yaw / set_pitch wins, the random side flips the desync to the right 60 %% (%s)" % (r,))
r = D("""
builder.direct_begin()
local ctx = CTX()
refs.desyncside:set(5) refs.yawbase:set(1)
builder.direct_restore()
builder.direct_apply(ctx, {})
return ctx.calls.set_desync == nil, ctx.calls.set_yaw == nil, REAL.desyncside.v
""")
check(r[0] and r[1] and r[2] == 5, "direct control: peek fake stays Primordial's, yaw base 1 (round end) sends no yaw (%s)" % (r,))
r = D("""
local function key(v) return { get = function() return v end } end
refs.left, refs.right, refs.back, refs.freestand = key(false), key(false), key(false), key(true)
vec3_t = function(x, y, z) return { x = x, y = y, z = z } end
e_hitboxes = { HEAD = 0 }
builder.direct_begin()
local ctx = CTX()
refs.yawbase:set(2) refs.yawadd:set(15) refs.jittermode:set(1) refs.desyncside:set(2) refs.leftamount:set(80)
builder.direct_restore()
builder.direct_apply(ctx, { get_hitbox_pos = function() return { x = 0, y = 0, z = 64 } end })
local no_wall = ctx.calls.set_yaw
-- a threat straight ahead (+x), a wall on our left only: the head goes left (to + 90)
local enemy = { is_alive = function() return true end, is_dormant = function() return false end,
    get_render_origin = function() return { x = 500, y = 0, z = 0 } end,
    get_eye_position = function() return { x = 500, y = 0, z = 64 } end }
entity_list_get_players = function() return { enemy } end
trace_line = function(_, to) return { fraction = to.y > 0 and 0.5 or 1 } end
builder.own_fs.tick = -100
local ctx2 = CTX()
builder.direct_begin() builder.direct_restore()
builder.direct_apply(ctx2, { get_hitbox_pos = function() return { x = 0, y = 0, z = 64 } end })
local fs_yaw = ctx2.calls.set_yaw
-- manual right: view 30 - 90
refs.right = key(true)
local ctx3 = CTX()
builder.direct_begin() builder.direct_restore()
builder.direct_apply(ctx3, {})
refs.right, refs.freestand = key(false), nil
entity_list_get_players = function() return {} end
return no_wall, fs_yaw, ctx3.calls.set_yaw, ctx.calls.set_desync, REAL.yawadd.v
""")
check(r == (-135, 90, -60, -0.8, 0), "direct control, own: Freestand without a wall = the normal yaw, a wall on the left = "
      "the head left (90), manual right = view - 90, the desync still ours, Primordial's yaw add 0 (%s)" % (r,))
r = D("""
local P = builder.adv.fs_pick
return P(0.5, 1, 0), P(1, 0.4, 0), P(1, 1, 1), P(0.5, 0.52, -1), P(0.3, 0.9, 1)
""")
check(r == (1, -1, 0, -1, 1), "own freestand: the covered side, both covered = keep the side, none = normal AA (%s)" % (r,))
r = D("""
local st, a = {}, {}
for n = 1, 6 do a[#a + 1] = builder.adv.native_jitter(st, 3, 30, true) end
local st2, b = {}, {}
for n = 1, 5 do b[#b + 1] = builder.adv.native_jitter(st2, 4, 40, true) end
local st3 = {}
local c1 = builder.adv.native_jitter(st3, 2, 30, true)
local c2 = builder.adv.native_jitter(st3, 2, 30, false)
return table.concat(a, ","), table.concat(b, ","), c1 == c2
""")
check(r[0] == "0,30,-30,0,30,-30" and r[1] == "-20,0,20,40,-40" and r[2],
      "direct control jitter: 3Way / 5Way steps once per packet (%s)" % (r,))
check("render_circle_filled = function(pos, radius" in SRC, "circle radii are rounded (Primordial wants an int)")


# Fresh jitter evidence is tracked per target. Safety is gated by resolver state
# and fast-peek policy; health-threshold body aim works independently.
RES = chunk("local RES_JIT_N = 12", "resolver.update = function(local_player, ent)") + \
      chunk("resolver.body_damage = function(ent)", "-- safe points / smart body aim for the aimbot's target.") + \
      chunk("-- safe points / smart body aim for the aimbot's target.", "resolver.reset = function()")
jr = L.LuaRuntime(unpack_returned_tuples=True)
jr.execute("""RES_FS_TICKS = 16 SIM = 0
resolver = { data = {}, misses = {}, mem = {}, previous = {}, active = false }
resolver.state_of = function() return "stand" end
resolver.fast_target = function() return false end
TICKS = 0
globals = { real_time = function() return SIM end, tick_count = function() TICKS = TICKS + 1 return TICKS end, interval_per_tick = function() return 1 / 64 end }
local function item(v) return { get = function() return v end } end
ui = { ragebot = { logic_reso = item(false), smart_baim = item(true),
    smart_baim_hp = item(40), smart_baim_lethal = item(true), resolver = { shot_pred = item(4) } } }
HP = 100
damage = { calculate = function(_, _, box) return box == "chest" and 70 or 87 end }
res_custom = function() return false end
res_clamp = function(v, a, b) return math.max(a, math.min(b, v)) end
res_norm = function(v) return (v + 180) % 360 - 180 end
res_sign = function(v) return v < 0 and -1 or 1 end
time_to_ticks = function(t) return math.floor(t * 64 + 0.5) end
e_hitscan_groups = { HEAD = 0, CHEST = 1, STOMACH = 2 }
e_hitboxes = { CHEST = 1, PELVIS = 2 }
entity_list_get_local_player = function() return { get_eye_position = function() return 0 end } end
trace_bullet = function(_, point) return { valid = true, damage = point == 1 and 70 or 87,
    hitgroup = point == 1 and 2 or 3 } end
ENT = { get_index = function() return 3 end, get_hitbox_pos = function(_, b) return b end,
    get_prop = function(_, n)
        if n == "m_iHealth" then return HP end
        if n == "m_flSimulationTime" then return SIM end
        if n == "m_flSpawnTime" then return 1 end
        return 0
    end }
function HS()
    local c = { safe = {}, groups = {} }
    c.player = ENT
    c.set_safepoint_state = function(self, on, g) self.safe[g] = on end
    c.set_hitscan_group_state = function(self, g, on) self.groups[g] = on end
    resolver.hitscan(c)
    LAST = c
    return c.safe[0] == true, c.safe[1] == true
end
-- a target that shows these eye yaws one record (2 ticks) apart: is it a jitter target at the end?
function RUN(yaws)
    resolver.data = {} SIM = 0
    for i, y in ipairs(yaws) do SIM = i * 2 / 64 resolver.track(ENT, y) end
    return resolver.data[3].jitter
end
function SEQ(n, f) local t = {} for i = 1, n do t[i] = f(i) end return t end
""" + RES)
J = jr.eval("function(code) return assert(loadstring(code))() end")
r = J("""
math.randomseed(7)
local still = RUN(SEQ(20, function() return 10 end))
local turn = RUN(SEQ(20, function(i) return i * 25 end))          -- a fast mouse turn, 25 deg a record one way
local spin = RUN(SEQ(20, function(i) return (i * 70) % 360 end))  -- a spin
local center = RUN(SEQ(20, function(i) return i % 2 == 0 and 30 or -30 end))
local three = RUN(SEQ(20, function(i) return ({ -35, 0, 35 })[i % 3 + 1] end))
local rnd = RUN(SEQ(20, function() return math.random(-40, 40) end))
local small = RUN(SEQ(20, function() return 10 + math.random() - 0.5 end))   -- aim noise under a degree
local wide = RUN(SEQ(20, function(i) return i % 2 == 0 and 150 or -150 end)) -- +-30 around 180
-- small jitter (owners: "small jitter ... 5-6"): +-5 / +-3 around a slowly moving base, a small 3-way, and against them a
-- mouse that sweeps back and forth (+-60 deg, 0.6 s, aim noise): it passes the same angles but never returns to one in
-- 2-4 records (small steps in random directions every record is not a hand, it is a random jitter and counts as one)
local s5 = RUN(SEQ(20, function(i) return 90 + i * 0.2 + (i % 2 == 0 and 5 or -5) end))
local s3 = RUN(SEQ(20, function(i) return -170 + (i % 2 == 0 and 3 or -3) end))
local s3way = RUN(SEQ(20, function(i) return 40 + ({ -6, 0, 6 })[i % 3 + 1] end))
local aim = RUN(SEQ(60, function(i) return 60 * math.sin(2 * math.pi * (i * 2 / 64) / 0.6) + math.random() - 0.5 end))
return still, turn, spin, center, three, rnd, small, wide, s5, s3, s3way, aim
""")
check(r == (False, False, False, True, True, True, False, True, True, True, True, False),
      "jitter detector: still / mouse turn / spin / mouse aim no, centre / 3-way / random / +-30 over 180 / small +-3..6 "
      "yes (%s)" % (r,))
r = J("""
RUN(SEQ(20, function(i) return i % 2 == 0 and 30 or -30 end))
local base = SIM
local held = {}
for i = 1, 60 do SIM = base + i * 2 / 64 resolver.track(ENT, 30) held[#held + 1] = resolver.data[3].jitter end
return held[5], held[40]   -- initially held, then expired after the short hold plus bounded history
""")
check(r == (True, False) and "local RES_JIT_HOLD = 0.25" in SRC,
      "jitter detector: short 250 ms hold after evidence stops, no one-second stale safety (%s)" % (r,))
r = J("""
RUN(SEQ(20, function() return 10 end))
local h0, c0 = HS()
local sure_head = LAST.groups[0] == nil
resolver.misses[3] = 1
local h1, c1 = HS()
local head_100 = LAST.groups[0] == nil                       -- 100 hp: a body hit (70) does not kill, the head stays
HP = 60
HS()
local body_60 = LAST.groups[0] == false and LAST.groups[1] == true and LAST.groups[2] == true and resolver.safe[3] == 3
resolver.misses[3] = 0
HP = 100
resolver.active = true
RUN(SEQ(20, function(i) return i % 2 == 0 and 30 or -30 end))
local h2, c2 = HS()
local jit_head_100 = LAST.groups[0] == nil and resolver.safe[3] == 2
HP = 50
HS()
local jit_body_50 = LAST.groups[0] == false
-- a jittering target gets head + chest safe points even with every resolver toggle off (owners: ALWAYS, not beta):
-- the real shot logs had jitter as the top miss cause with almost no safe point because it was gated behind the toggle
HP = 100
resolver.active = false
HS()
local jit_offtoggle = resolver.safe[3] == 2 and LAST.safe[0] == true and LAST.safe[1] == true
return h0, c0, sure_head, h1, c1, head_100, body_60, h2, c2, jit_head_100, jit_body_50, jit_offtoggle
""")
check(r == (False, False, True, False, False, True, True, True, True, True, True, True),
      "smart body aim: independent lethal-body fallback; inactive safety stays off, a jittering target gets head + chest "
      "safe points even with every resolver toggle off (%s)" % (r,))

# FPS (owners, Oct 2026: "70 fpsem"): menu.find is asked once per item, the profiler only times while it runs
MF = chunk("-- menu.find walks Primordial's whole menu by name", "-- FPS profiler (dev build")
mf = L.LuaRuntime(unpack_returned_tuples=True)
mf.execute("CALLS = 0 menu_find = function(...) CALLS = CALLS + 1 return { name = table.concat({ ... }, '/') } end\n" + MF)
r = mf.eval("""(function()
    local a = menu_find("misc", "main", "movement", "autostrafer")
    local b = menu_find("misc", "main", "movement", "autostrafer")
    local c = menu_find("aimbot", "auto", "accuracy")
    return a == b, CALLS, c.name
end)()""")
check(r == (True, 2, "aimbot/auto/accuracy"), "menu_find: each item looked up once (%s)" % (r,))
check('perf.add(e_callbacks.PAINT, "PAINT"' in SRC and "perf.span(\"watermark\", draw_watermark)" in SRC
      and "    callbacks.add(e_callbacks.PAINT, function()" not in SRC, "FPS profiler wraps the callbacks and the PAINT parts")

# body hits (owners, Oct 2026: "nagyon sok a body hit"): Multipoint correction pushes the head first when it is
# shootable, the body only when Smart body aim took the head out
DP = chunk("-- HITSCAN runs per command and target", "--- @endregion")
dp = L.LuaRuntime(unpack_returned_tuples=True)
dp.execute("""
local function item(v) return { get = function() return v end } end
ui = { ragebot = { multipoint_pred = item(true) } }
defensive = { is_active = function() return false end }
local LP = { get_eye_position = function() return 0 end }
entity_list_get_local_player = function() return LP end
e_hitboxes = { HEAD = "head", CHEST = "chest", PELVIS = "stomach" }
e_hitscan_groups = { HEAD = 0, CHEST = 1, STOMACH = 2 }
damage = { calculate = function(_, _, box) return ({ head = 300, chest = 80, stomach = 100 })[box] end }
get_dmg = function() return 40 end
TICK, TRACES = 0, 0
globals = { tick_count = function() return TICK end }
trace_bullet = function(_, pos) TRACES = TRACES + 1 return { valid = true, hitgroup = pos } end
client_get_hitgroup_name = function(g) return g end
resolver = { safe = {}, fast_target = function() return false end }
ENEMY = { get_index = function() return 5 end, get_hitbox_pos = function(_, b) return b end,
    get_prop = function() return 100 end }
""" + DP + """
function RUNDP()
    local c = { hc = {}, on = {} }
    c.player = ENEMY
    c.set_hitchance = function(self, v, g) self.hc[#self.hc + 1] = g end
    c.set_hitscan_group_state = function(self, g, on) self.on[#self.on + 1] = g end
    dmg_prediction(c)
    return c.hc[1], #c.on
end""")
r = [tuple(dp.eval("RUNDP()")) for _ in range(20)]
same_tick = dp.eval("TRACES")
dp.execute("TICK = 1")
dp.eval("RUNDP()")
next_tick = dp.eval("TRACES")
dp.execute("resolver.safe[5] = 3")
r2 = dp.eval("RUNDP()")
check(all(x == (0, 1) for x in r) and tuple(r2) == (1, 1) and same_tick == 1 and next_tick == 2,
      "Multipoint correction: the head first every time, the chest when Smart body aim took the head out, one trace "
      "per tick and target however many commands (double tap) (%s %s %s %s)" % (r[0], r2, same_tick, next_tick))

# our resolver (owners, Oct 2026: "mindegyiket csináld meg"): feet model, jitter period / phase, relearning per round
FM = chunk("resolver.memory = function(idx, key, kind)", "resolver.shot_id = function(event)") + \
     chunk("resolver.K = {", "-- one record: its eye yaw step, the jitter state") + \
     chunk("resolver.reset = function()", "resolver.native = function(off, fallback)")
fm = L.LuaRuntime(unpack_returned_tuples=True)
fm.execute("""
res_clamp = function(v, a, b) v = tonumber(v) or a return math.max(a, math.min(b, v)) end
res_norm = function(v) return (v + 180) % 360 - 180 end
res_sign = function(v) return v < 0 and -1 or 1 end
resolver = { data = {}, mem = {}, previous = {}, misses = {}, shots = {}, epoch = 0, trust = {} }
backtrack = { peekers = {}, records = {}, peek_until = 0, predict_tick = 0, high_until = 0 }
""" + FM)
F = fm.eval("function(code) return assert(loadstring(code))() end")

# feet model: standing, the feet go to the LBY target at 100 deg/s but never further than the max body yaw from the eye
r = F("""
local p = {}
local d1 = resolver.feet_step(p, 0, 100, 0, false, 58, 100, 1 / 64)        -- first record: feet = the target, clamped to 58
local d2 = resolver.feet_step(p, 0, -40, 0, false, 58, 164, 1 / 64)         -- 1 s later (capped to 0.25 s = 25 deg): 58 -> 33
local d3 = resolver.feet_step(p, 0, -40, 0, false, 58, 228, 1 / 64)         -- 33 -> 8 (another 25 deg)
local m = {}
resolver.feet_step(m, 90, 0, 250, false, 58, 100, 1 / 64)                  -- running: feet follow the EYE yaw
local m2 = resolver.feet_step(m, 120, 0, 250, false, 58, 112, 1 / 64)       -- 30 deg turn in 12 ticks: the feet lag
local nolby = resolver.feet_step({}, 0, nil, 0, false, 58, 1, 1 / 64)
return d1, d2, d3, m2, nolby, resolver.feet_limit(0, 0), resolver.feet_limit(250, 0)
""")
check(abs(r[0] + 58) < 1e-6 and abs(r[1] + 33) < 1e-6 and abs(r[2] + 8) < 1e-6 and r[3] is not None and 0 < r[3] <= 58
      and r[4] is None and abs(r[5] - 58) < 1e-6 and abs(r[6] - 58 * 0.65) < 1e-6,
      "feet model: standing feet go to the LBY target at 100 deg/s inside the max body yaw, running they follow the eye "
      "yaw, no LBY = no model, the max body yaw shrinks with speed (%s)" % (r,))

# per state profile: standing = LBY phase, full trust once the model converged; moving / air = eye phase, less trust; a crouched
# walker is its own state
r = F("""
local st = resolver.profile(0, false, 12, false)
local fresh = resolver.profile(0, false, 0, false)
local mv = resolver.profile(250, false, 12, false)
local cm = resolver.profile(120, false, 12, true)
local air = resolver.profile(0, true, 12, false)
local p = {}
for i = 1, 5 do resolver.feet_step(p, 0, 30, 0, false, 58, 100 + i, 1 / 64) end
return st.phase, st.rel, fresh.rel, mv.phase, mv.rel, mv.zero, cm.rel, air.phase, p.feet_steps
""")
check(r[0] == "lby" and r[1] == 1 and abs(r[2] - 0.25) < 1e-6 and r[3] == "eye" and abs(r[4] - 0.35) < 1e-6 and r[5] == 12
      and abs(r[6] - 0.5) < 1e-6 and r[7] == "eye" and r[8] == 5,
      "state profile: the LBY phase is fully trusted once the feet model converged, the eye phase (moving / air) less, a "
      "fresh model little, the steps are counted (%s)" % (r,))

# per state priors: every state the owners listed has one, air / moving lean on the half size + jitter pattern, standing on the
# side hint + feet model
r = F("""
local n = 0
for _, st in ipairs({ "stand", "slow", "move", "duck", "cmove", "air", "airduck" }) do
    if resolver.STATE_PRIOR[st] ~= nil then n = n + 1 end
end
local P = resolver.STATE_PRIOR
return n, P.stand[6] > (P.air[6] or 0) and 1 or 0, P.air[8] > (P.stand[8] or 0) and 1 or 0
""")
check(r[0] == 7 and r[1] == 1 and r[2] == 1,
      "state priors: all 7 states have one, standing trusts the feet model more than air, air the jitter pattern more than standing (%s)" % (r,))

# jitter period / phase
r = F("""
local a, pa, ca = resolver.run_predict({ 3, 3, 3 }, 3, 1)       -- delay 3: the run reached it: switches now
local b, pb = resolver.run_predict({ 3, 3, 3 }, 2, 1)           -- not yet
local c, pc = resolver.run_predict({ 1, 1, 1, 1 }, 1, -1)      -- every record
local d, pd, cd = resolver.run_predict({ 1, 4, 2, 3, 1, 2 }, 2, 1)   -- no fixed period: statistics only
local e = resolver.run_predict({ 3 }, 1, 1)
return a, pa, ca, b, pb, c, pc, d, pd, cd, e
""")
check(r[0] == -1 and r[1] == 3 and r[2] >= 0.8 and r[3] == 1 and r[4] == 3 and r[5] == 1 and r[6] == 1
      and r[7] in (1, -1) and r[8] is None and 0 <= r[9] <= 0.5 and r[10] is None,
      "jitter period: a fixed delay switches exactly when the run reaches it, a tick jitter every record, no period = "
      "a low confidence guess, too little history = nothing (%s)" % (r,))
r = F("""
local p = { jitter = true }
local out = {}
for i = 1, 30 do
    p.dir = ((math.floor((i - 1) / 3) % 2) == 0) and 1 or -1      -- a delay 3 jitter: 1 1 1 -1 -1 -1 ...
    resolver.run_update(p)
    out[i] = p.next_side or 0
end
local last_in_run = out[30]        -- record 30 is the 3rd of a -1 run: the next one switches to +1
local mid_run = out[29]            -- the 2nd of that run: stays -1
p.jitter = false
resolver.run_update(p)
return last_in_run, mid_run, p.next_side, p.period
""")
check(r[0] == 1 and r[1] == -1 and r[2] is None and r[3] is None,
      "jitter period: run_update follows a delay 3 jitter (stays inside a run) and forgets when the jitter ends (%s)" % (r,))

# the yaw pattern changed: only while the jitter detector holds, 10 records in a row with another pattern
r = F("""
local function window(list, n) local t = {} for i = 1, 12 do t[i] = list((n - i + 1)) end return t end
local p = { jitter = true, jy = {} }
local two = function(i) return (i % 2 == 0) and 30 or -30 end
local multi = function(i) return ({ 0, 40, -40, 80, -80 })[i % 5 + 1] end
local fired, first = 0, nil
for n = 1, 20 do p.jy = window(two, n) if resolver.pattern_update(p) then fired = fired + 1 end end
for n = 21, 60 do p.jy = window(multi, n) if resolver.pattern_update(p) then fired = fired + 1 first = first or n end end
local q = { jitter = false, jy = window(multi, 99) }
local mouse = resolver.pattern_update(q)
local same = { jitter = true, jy = {} }
local f2 = 0
for n = 1, 60 do same.jy = window(two, n) if resolver.pattern_update(same) then f2 = f2 + 1 end end
return fired, first, mouse, f2
""")
check(r[0] == 1 and r[1] is not None and 30 <= r[1] <= 36 and r[2] is False and r[3] == 0,
      "pattern change: fires once, after 10 records of the new pattern; a steady jitterer and a non-jitterer never do (%s)" % (r,))

# the learning comes back per player after a round change, halved; hypotheses 6 / 7 only with a visible body yaw
r = F("""
resolver.data[3] = { sid = "S1" }
resolver.data[4] = {}                                          -- no steam id: not carried
local m = resolver.memory(3, "stand")
m.candidates[1].good, m.candidates[1].bad, m.misses, m.last_failed = 11, 5, 3, 1
resolver.memory(4, "stand").candidates[1].good = 9
resolver.new_round()
local gone = next(resolver.mem) == nil and next(resolver.data) == nil
local c = resolver.carry["S1"] and resolver.carry["S1"].stand
local kept = c ~= nil and math.abs(c.candidates[1].good - 6) < 1e-9 and math.abs(c.candidates[1].bad - 3) < 1e-9
    and c.misses == 0 and c.last_failed == nil
local none = resolver.carry["nobody"] == nil and #resolver.carry == 0
local mem = resolver.memory(5, "stand")
local with = resolver.choose(mem, 0.25, true, { skip = {}, bonus = { [6] = 0.12 } })
local without = resolver.choose(mem, 0.25, true, { skip = { [6] = true, [7] = true }, bonus = { [6] = 0.12 } })
mem.candidates[with].bad = 30
local after = resolver.choose(mem, 0.25, true, { skip = {}, bonus = { [6] = 0.12 } })
return gone, kept, none, with, without, after, resolver.hypothesis(6, 1, 0, 0.5, 58, 40), resolver.hypothesis(7, 1, 0, 0.5, 58, 40),
    resolver.hypothesis(6, 1, 0, 0.5, 58, 90), resolver.hypothesis(8, 1, -1, 0.5, 58, 0), resolver.hypothesis(9, 1, -1, 0.5, 58, 0)
""")
check(r[0] and r[1] and r[2] and r[3] == 6 and r[4] != 6 and r[4] != 7 and r[5] != 6
      and r[6] == -40 and r[7] == 40 and r[8] == -58 and r[9] == -58 and r[10] == 58,
      "round change: what was learned about a player comes back halved, the feet hypothesis wins first with a visible "
      "body yaw, loses after misses, is skipped without one; hypothesis values (%s)" % (r,))

# resolver.update end to end (animstate mock): a standing target with a visible body yaw gets the feet model's value written,
# a delay jitter fills the next side prediction, nothing breaks without an LBY / with garbage
UP = chunk("resolver.memory = function(idx, key, kind)", "resolver.shot_id = function(event)") + \
     chunk("resolver.max_desync = function(st)", "resolver.state_of = function(ent)") + \
     chunk("local RES_JIT_N = 12", "resolver.update = function(local_player, ent)") + \
     chunk("resolver.update = function(local_player, ent)", "resolver.on_result = function(")
um = L.LuaRuntime(unpack_returned_tuples=True)
um.execute("""
RES_NOCHOKE, RES_FS_TICKS, RES_STATE_NUM = 8, 16, { stand = 1 }
res_clamp = function(v, a, b) v = tonumber(v) or a return math.max(a, math.min(b, v)) end
res_norm = function(v) return (v + 180) % 360 - 180 end
res_sign = function(v) return v < 0 and -1 or 1 end
res_custom = function() return false end
time_to_ticks = function(t) return math.floor(t * 64 + 0.5) end
math.vec_length2d = function(v) return math.sqrt(v.x * v.x + v.y * v.y) end
SIM, NOW, TICK = 0, 0, 0
globals = { real_time = function() return NOW end, tick_count = function() return TICK end, interval_per_tick = function() return 1 / 64 end }
local function item(v) return { get = function() return v end } end
ui = { ragebot = { reso_cfg = { yaw_calc = item(1) }, resolver = { pred_sel = item(50), shot_pred = item(15) } } }
resolver = { data = {}, mem = {}, previous = {}, misses = {}, shots = {}, epoch = 0 }
resolver.state_of = function() return "stand" end
resolver.freestand = function() return 0 end
ST = { m_flEyeYaw = 0, m_flGoalFeetYaw = 0 }
resolver.animstate = function() return ST end
LBY = -58
ENT = { get_index = function() return 3 end,
    get_prop = function(_, n)
        if n == "m_flSimulationTime" then return SIM end
        if n == "m_flSpawnTime" then return 1 end
        if n == "m_vecVelocity" then return { x = 0, y = 0, z = 0 } end
        if n == "m_flLowerBodyYawTarget" then return LBY end
        if n == "m_fFlags" then return 1 end
        return 0
    end }
function STEP(eye) SIM, NOW, TICK = SIM + 2 / 64, NOW + 2 / 64, TICK + 2 ST.m_flEyeYaw = eye resolver.update({}, ENT) end
""" + UP)
U = um.eval("function(code) return assert(loadstring(code))() end")

# movement observer + forecast: a runner is predicted ahead along its velocity, a wall stops it, garbage is ignored
r = U("""
cvars = { sv_gravity = { get_float = function() return 800 end } }
WALL = false
trace_line = function(from, to) return { fraction = (WALL and to.x > 40) and 0.5 or 1, plane_normal = { x = -1, y = 0, z = 0 } } end
vec3_t = function(x, y, z) return { x = x, y = y, z = z } end
local X, S = 0, 100
local mover = { get_prop = function(_, n)
    if n == "m_flSimulationTime" then return S end
    if n == "m_vecOrigin" then return { x = X, y = 0, z = 0 } end
    if n == "m_vecVelocity" then return { x = 250, y = 0, z = 0 } end
    if n == "m_fFlags" then return 1 end
    return 0
end }
local p = {}
for i = 1, 6 do S = 100 + i / 64 X = i * 250 / 64 NOW = S resolver.advanced.observe(p, mover, 10) end
local f = resolver.advanced.forecast(p, mover, 10)
WALL = true
p.advanced.prediction = nil
local w = resolver.advanced.forecast(p, mover, 10)
local bad = {}
resolver.advanced.observe(bad, { get_prop = function() return nil end }, 10)
resolver.advanced.observe(bad, mover, 0 / 0)
return f.x > p.advanced.last.x + 10, f.blocked == false, w.blocked == true, w.x < f.x, #p.advanced.records, bad.advanced == nil,
    resolver.advanced.forecast(nil, mover, 10) == nil
""")
check(all(bool(v) for v in list(r)[:4]) and r[4] == 6 and r[5] and r[6],
      "movement forecast: a runner is predicted ahead along its velocity, a wall stops it, garbage netvars and no data give nothing (%s)" % (list(r),))
r = U("""
for _ = 1, 8 do STEP(0) end
local prev = resolver.previous[3]
local still = { prev.candidate, prev.model, ST.m_flGoalFeetYaw, prev.kind }
-- delay 3 jitter, +-30
resolver.data, resolver.mem, resolver.previous = {}, {}, {}
SIM, NOW, TICK = 0, 0, 0
for i = 1, 30 do STEP(((math.floor((i - 1) / 3) % 2) == 0) and 30 or -30) end
local p = resolver.data[3]
local jit = { p.jitter, p.next_side ~= nil, p.period, resolver.previous[3].kind, resolver.previous[3].nxt ~= nil,
    ST.m_flGoalFeetYaw == ST.m_flGoalFeetYaw }
LBY = nil
resolver.data, resolver.mem, resolver.previous = {}, {}, {}
SIM, NOW, TICK = 0, 0, 0
for _ = 1, 8 do STEP(0) end
local nolby = resolver.previous[3].model == nil
LBY = 0 / 0
for _ = 1, 3 do STEP(10) end
return still[1], still[2], still[3], still[4], jit[1], jit[2], jit[3], jit[4], jit[5], jit[6], nolby
""")
check(r[0] == 6 and abs(r[1] - 58) < 1e-6 and abs(r[2] + 58) < 1e-6 and r[3] is None
      and r[4] is True and r[5] is True and r[6] == 3 and r[7] == "jitter" and r[8] is True and r[9] is True and r[10] is True,
      "resolver.update: a standing target with a visible body yaw gets the feet model's value, a delay 3 jitter gets its "
      "period and next side, no / garbage LBY breaks nothing (%s)" % (r,))

# a tickbase shift keeps what was learned (it used to wipe it); a big jump back (a new map) still resets
r = J("""
RUN(SEQ(20, function(i) return i % 2 == 0 and 30 or -30 end))
local p = resolver.data[3]
resolver.mem[3] = { jitter = { candidates = { { good = 9, bad = 1 } } } }
local keep_sim = SIM
SIM = keep_sim - 0.1                                           -- a shifted update, 0.1 s back
local same = resolver.track(ENT, 30) == p
local kept = resolver.mem[3] ~= nil and resolver.mem[3].jitter.candidates[1].good == 9
local grace = p.defensive_until > SIM
SIM = keep_sim - 1                                              -- a second back: a new record, everything starts over
local fresh = resolver.track(ENT, 30)
return same, kept, grace, fresh ~= p, resolver.mem[3] == nil
""")
check(tuple(r) == (True, True, True, True, True),
      "tickbase shift: the target and what was learned stay with a short grace window, a big jump back starts over (%s)" % (r,))

# defensive / lag break detector (owners: "nem lesz defensive detectorunk?", the ENEMY's): the shift that spoils a shot fired
# at t is observed about a round trip later, inside [t + rtt - duration, t + rtt]; such a miss is no resolver miss and
# teaches nothing, a hit still counts; the stats show it as "defensive" / "lag break" per state
DF = chunk("resolver.memory = function(idx, key, kind)", "resolver.shot_id = function(event)") + \
     chunk("resolver.shot_id = function(event)", "local RES_JIT_N = 12") + \
     chunk("resolver.HYP = {", "--- @info: resolver: side from freestanding") + \
     chunk("local RES_JIT_N = 12", "resolver.update = function(local_player, ent)") + \
     chunk("resolver.on_result = function(target, hit_ok, resolver_miss, event, reason)", "resolver.body_damage = function(ent)")
dm = L.LuaRuntime(unpack_returned_tuples=True)
dm.execute("""
RES_FS_TICKS = 16
res_clamp = function(v, a, b) v = tonumber(v) or a return math.max(a, math.min(b, v)) end
res_norm = function(v) return (v + 180) % 360 - 180 end
res_sign = function(v) return v < 0 and -1 or 1 end
res_custom = function() return false end
time_to_ticks = function(t) return math.floor(t * 64 + 0.5) end
SIM, NOW, ORIGIN = 0, 0, { x = 0, y = 0, z = 0 }
globals = { real_time = function() return NOW end, interval_per_tick = function() return 1 / 64 end }
local function item(v) return { get = function() return v end } end
ui = { ragebot = { resolver = { shot_pred = item(15) } } }
resolver = { data = {}, mem = {}, previous = {}, misses = {}, shots = {}, epoch = 0, stats = {} }
resolver.state_of = function() return "stand" end
resolver.network = function() return { ping = 100 } end
ENT = { get_index = function() return 3 end, get_hitbox_pos = function() return 0 end,
    get_prop = function(_, n)
        if n == "m_flSimulationTime" then return SIM end
        if n == "m_flSpawnTime" then return 1 end
        if n == "m_vecOrigin" then return ORIGIN end
        return 0
    end }
function REC(eye) SIM, NOW = SIM + 2 / 64, NOW + 2 / 64 return resolver.track(ENT, eye) end
function RESULT(id, hit, rr, reason, between)
    resolver.capture({ player = ENT, id = id })                  -- the shot is fired
    NOW = NOW + 0.1                                               -- a round trip later ...
    if between then between() end                                 -- ... what we observe of the target meanwhile
    resolver.on_result(ENT, hit, rr, { id = id }, reason)
    return resolver.last_result
end
""" + DF)
D = dm.eval("function(code) return assert(loadstring(code))() end")
r = D("""
for i = 1, 6 do REC(i % 2 == 0 and 30 or -30) end
local p = resolver.data[3]
resolver.previous[3] = { key = "jitter", kind = "jitter", candidate = 1, m_flDesync = 20, rel = 1 }
local mem = resolver.memory(3, "jitter")
-- 1. a plain resolver miss counts
local s1 = RESULT(1, false, true, "resolver")
local plain = resolver.misses[3] == 1 and mem.candidates[1].bad > 1 and not s1.defensive and s1.state == "stand"
-- 2. the target shifts its tickbase 0.1 s while the shot is on its way: observed a round trip after the shot
local bad, misses = mem.candidates[1].bad, resolver.misses[3]
local back = p.sim
local s2 = RESULT(2, false, true, "jitter", function() SIM = back - 0.1 resolver.track(ENT, 30) end)
local ev = p.events[#p.events]
local def_ignored = s2.defensive == true and ev.kind == "def" and math.abs(ev.dur - 0.1) < 1e-9
    and resolver.misses[3] == misses and mem.candidates[1].bad == bad
SIM = back
-- 3. a HIT in that window still counts
local good = mem.candidates[1].good
RESULT(3, true, false, nil)
local hit_counts = mem.candidates[1].good > good and resolver.misses[3] == 0
-- 4. a shift long before the shot spoils nothing
NOW = NOW + 1
SIM = SIM + 0.3
REC(30)
local s4 = RESULT(4, false, true, "resolver")
local old_ok = not s4.defensive and resolver.misses[3] == 1
-- 5. a teleport observed while the shot is on its way
NOW = NOW + 1
ORIGIN = { x = 0, y = 0, z = 0 }
REC(-30)
local s5 = RESULT(5, false, true, "jitter", function() ORIGIN = { x = 100, y = 0, z = 0 } REC(30) end)
local lb = s5.lagbreak == true and s5.defensive == nil and resolver.misses[3] == 1
-- 6. walking a few units is no lag break
local n_ev = #p.events
ORIGIN = { x = 105, y = 0, z = 0 }
REC(-30)
local walk = #p.events == n_ev
-- 7. a spread miss during a shift keeps its reason; the shift event after the result flags nothing
local s7 = RESULT(7, false, false, "spread")
local rows = resolver.stat_rows()
local stand = rows[1]
local why = {}
for _, m in ipairs(stand.miss) do why[m[1]] = m[2] end
local stats = { rows[1].name, stand.n, stand.hit, why.resolver, why.defensive, why["lag break"], why.spread, why.jitter,
    rows[2] and rows[2].name, rows[2] and rows[2].n }
local line = resolver.stat_lines()[1]
local text = line:find("stand: 6 shots, 17% hit", 1, true) ~= nil and line:find("defensive 1", 1, true) ~= nil
    and line:find("side 1/", 1, true) ~= nil
return plain, def_ignored, hit_counts, old_ok, lb, walk, table.concat({ tostring(stats[1]), stats[2], stats[3], stats[4], stats[5],
    stats[6], stats[7], tostring(stats[8]), tostring(stats[9]), tostring(stats[10]) }, ","), text
""")
check(tuple(r[:6]) == (True,) * 6 and r[6] == "stand,6,1,2,1,1,1,nil,jitter,6" and r[7] is True,
      "enemy defensive / lag break: the shift observed a round trip after the shot flags it, such a miss is no resolver miss "
      "and teaches nothing, a hit still counts, an old shift / walking flags nothing, the stats per state show it as "
      "defensive / lag break (%s)" % (r,))

# what was learned stays with the PLAYER: a dormant phase / respawn keeps it, another player in the slot does not
r = J("""
local SID = "76561198000000042"
local E = setmetatable({ get_steamids = function() return 42, SID end }, { __index = ENT })
resolver.data, resolver.mem, resolver.carry = {}, {}, {}
SIM = 1
local p1 = resolver.track(E, 0)
resolver.mem[3] = { stand = { candidates = { { good = 7, bad = 1 } } } }
SIM = 5                                                       -- came back after more than a second (dormant)
local p2 = resolver.track(E, 0)
local back = p2 ~= p1 and resolver.mem[3] ~= nil and resolver.mem[3].stand.candidates[1].good == 7
SID = "76561198000000099"                                     -- another player took the slot
SIM = 9
local p3 = resolver.track(E, 0)
local other = p3 ~= p2 and resolver.mem[3] == nil
-- a dead player's learning waits in the carry for his next life
SID = "76561198000000042"
resolver.mem[3] = { stand = { candidates = { { good = 5, bad = 1 } } } }
resolver.data[3].sid = SID
resolver.carry[SID] = resolver.mem[3]
resolver.data[3], resolver.mem[3] = nil, nil
SIM = 20
resolver.track(E, 0)
local revived = resolver.mem[3] ~= nil and resolver.mem[3].stand.candidates[1].good == 5 and resolver.carry[SID] == nil
return back, other, revived, p1.sid == "76561198000000042"
""")
check(tuple(r) == (True, True, True, True),
      "learning follows the player (steam id): kept over a dormant phase and a respawn, not given to another player in the slot (%s)" % (r,))

# DT lag (owners, Oct 2026: "lagging only in mid mirage with dt"): the on peek defensive check traces each enemy at
# most once per 4 ticks and 2 enemies per frame, however many commands double tap runs in one frame
PV = chunk("builder.peek_seen, builder.peek_budget = {}", "run_antiaim = function(")
pv = L.LuaRuntime(unpack_returned_tuples=True)
r = pv.eval("""(function()
    builder = {}
    TICK, FRAME, TRACES = 100, 1, 0
    globals = { tick_count = function() return TICK end, interval_per_tick = function() return 1 / 64 end }
    global_vars_frame_count = function() return FRAME end
    e_hitboxes = { BODY = 3 }
    vec3_t = function(x, y, z) return { x = x, y = y, z = z } end
    trace_bullet = function() TRACES = TRACES + 1 return { valid = true, damage = 30 } end
    """ + PV + """
    local function enemy(i) return { get_index = function() return i end, get_prop = function() return { x = 1, y = 0, z = 0 } end,
        get_eye_position = function() return setmetatable({}, { __add = function(a) return a end }) end,
        get_hitbox_pos = function() return {} end } end
    local origin = setmetatable({}, { __add = function(a) return a end })
    local E = { enemy(1), enemy(2), enemy(3), enemy(4), enemy(5) }
    for _ = 1, 14 do for _, e in ipairs(E) do builder.peek_visible({}, e, origin, {}) end end
    local one_frame = TRACES
    for f = 2, 4 do FRAME = f for _, e in ipairs(E) do builder.peek_visible({}, e, origin, {}) end end
    local three_more = TRACES
    TICK, FRAME = 104, 5
    for _, e in ipairs(E) do builder.peek_visible({}, e, origin, {}) end
    return one_frame, three_more, TRACES, builder.peek_visible({}, E[1], origin, {})
end)()""")
check(r[0] == 4 and r[1] == 10 and r[2] == 14 and r[3] == True,
      "on peek defensive: 14 commands x 5 enemies in one frame = 2 enemies traced, every enemy once per 4 ticks (%s)" % (r,))

# Adaptive AA (owners, Oct 2026: "nagyon advanced aa improve ... unhittable"): a Thompson sampling bandit over AA profiles
# per state group. Only the deciding maths here (the game decides how good a profile is): draws stay in 0..1, the
# profile the enemies keep head-hitting is dropped, a head hit switches at once, the side rules
r = R("""
math.randomseed(11)
local lo, hi, sum = 1, 0, 0
for n = 1, 2000 do local v = builder.adv.beta_sample(30, 3, math.random) lo = math.min(lo, v) hi = math.max(hi, v) sum = sum + v end
local g = {}
for i = 1, 8 do g[i] = builder.adv.arm_group(i) end
return lo >= 0, hi <= 1, sum / 2000, table.concat(g, ",")
""")
check(r[0] and r[1] and abs(r[2] - 30 / 33) < 0.02 and r[3] == "4,1,2,2,1,2,3,3",
      "Adaptive AA: Beta draws in 0..1 around the mean, state groups (%s)" % (r,))
r = R("""
math.randomseed(5)
local st, now, on = {}, 0, {}
local head = { 0.7, 0.1, 0.5, 0.5, 0.6 }       -- how often each profile gets head hit when a bullet comes
for n = 1, 600 do
    now = now + 1
    local arm = builder.adv.brain_arm(st, 2, now, math.random)
    on[arm] = (on[arm] or 0) + 1
    if (n % 2 == 0) then
        if (math.random() < head[arm]) then builder.adv.brain_learn(st, 2, "hit", 1, now, math.random)
        else builder.adv.brain_learn(st, 2, "evaded", nil, now, math.random) end
    end
end
local g = st.g[2]
local before = g.cur
builder.adv.brain_learn(st, 2, "hit", 1, now, math.random)
local switched = g.cur ~= before
local body_before = g.arms[g.cur].b
builder.adv.brain_learn(st, 2, "hit", 3, now, math.random)
local ok = true
for _, a in ipairs(g.arms) do ok = ok and a.a >= 1 and a.b >= 1 and a.a < 20 and a.b < 20 end
return (on[2] or 0) / 600, switched, g.arms[g.cur].b == body_before, ok
""")
check(r[0] > 0.5 and r[1] and r[2] and r[3],
      "Adaptive AA: plays the profile that is not head hit most of the time, a head hit switches at once, a body hit "
      "teaches nothing, the beliefs stay bounded (%s)" % (r,))
r = R("""
local A = builder.adv.arm_invert
return A("tied", true, true), A("tied", false, false), A("inverse", true, false), A("inverse", false, true),
    A("coin", true, true), A("coin", false, false)
""")
check(r == (False, True, True, False, True, False), "Adaptive AA: tied / inverse / coin desync side rules (%s)" % (r,))
BRAIN = chunk("-- Adaptive AA at run time", "-- anti bruteforce: an enemy bullet passing near the head")
br = L.LuaRuntime(unpack_returned_tuples=True)
br.execute("""builder = {} TICK = 0 NOW = 0
globals = { tick_count = function() return TICK end, real_time = function() return NOW end }
""" + ADV + """
local function item(v) return { v = v, get = function(self) return self.v end } end
ui = { antiaim = { builder = { adaptive = item(true), random_side = item(true) } } }
global = { current_state_number = 3 }
AA = { yaw_mode = item(4), yaw_val = item(0), yaw_delay = item(4), meta_delay = item(0), yaw_left = item(-20),
    yaw_right = item(20), yaw_meta_left = item(0), yaw_meta_right = item(0), desync = item(5) }
SIDE = nil
refs = { desyncside = { set = function(_, v) SIDE = v end } }
builder.set_yaw = function(v) builder.base_yaw = v end
builder.ab_active = function() return false end
""" + BRAIN + """
function STEP(fresh)
    local c = {}
    c.set_invert_desync = function(_, v) c.inv = v end
    builder.fresh = fresh
    builder.brain_apply(c, AA)
    return builder.base_yaw, c.inv
end""")
r = br.eval("""(function()
    builder.brain.g = { [2] = { arms = {}, cur = 2, until_t = 1000 } }      -- force "Delay tied" on the move group
    for i = 1, 5 do builder.brain.g[2].arms[i] = { a = 1, b = 1 } end
    local out = {}
    for t = 0, 12 do
        TICK = t
        local y, inv = STEP(t % 2 == 0)
        out[#out + 1] = y .. ":" .. tostring(inv)
    end
    return table.concat(out, " "), builder.brain_now, SIDE
end)()""")
seq = r[0].split()
yaws = [x.split(":")[0] for x in seq]
check(r[1] == "Delay tied" and r[2] == 2 and all(x.split(":")[1] == ("false" if x.startswith("-") else "true") for x in seq)
      and yaws[:4] == [yaws[0]] * 4 and yaws[4] != yaws[0],
      "Adaptive AA at run time: Delay tied switches only after its delay ticks, on a sent packet, the desync on the "
      "yaw side (%s)" % (r,))

# cloud configs (owners, Oct 2026: "a cloud cfg ... nem működik"): the old azura.uno socket is gone, they go through our
# server (lua=pm): the list, Use, the upload in parts (part 0 first, then the rest), no key = a message, nothing sent
CLOUD = chunk("-- cloud configs (owners, Oct 2026", "-- file based")
cl = L.LuaRuntime(unpack_returned_tuples=True)
cl.execute("""
ffi = require("ffi")
GETS, PENDING, NOTES, BUTTONS, IMPORTED, KEY = {}, {}, {}, {}, nil, "abc-key"
presence = { server = "https://srv" }
config_version, config_build, settings_file = "1.0", "beta", "settings.json"
notifications = { types = { success = "s", warning = "w", failure = "f", information = "i" },
    create = function(_, body) NOTES[#NOTES + 1] = body end }
JSON = {}
libs = {
    tools = { http = { get = function(_, url, cb) GETS[#GETS + 1] = url PENDING[#PENDING + 1] = { url = url, cb = cb } end } },
    json = { parse = function(b) local v = JSON[b] if v == nil then error("bad json") end return v end,
             encode = function(t) return "ENCODED" end },
    base64 = { encode = function(x) return string.rep("A", 7000) end, decode = function(x) return "CFG:" .. x end },
    eui = { export = function() return "EXPORT" end, import = function(x) IMPORTED = x end },
    filesystem = { exists = function() return KEY ~= nil end, read = function() return " " .. KEY .. " " end, write = function() end },
}
JSON["EXPORT"] = {}
local function item(v) return { v = v, get = function(self) return self.v end } end
local list = { items = {}, active = nil }
function list:set_items(t) self.items = t end
function list:get_active_item_name() return self.active end
local local_list = { get_active_item_name = function() return "my cfg.cfg" end }
ui = { configs = { cloud_list = { ref = list }, list = { ref = local_list } }, nav = { slider = { v = 3, get = function() return 3 end, ref = { set = function() end } } } }
configs = {}
menu_add_button = function(_, name, fn) BUTTONS[name] = fn return {} end
read_settings = function() return {} end
get_accent_color, get_text_color = function() return nil end, function() return nil end
function ANSWER(body, value) local r = table.remove(PENDING, 1) JSON[body] = value r.cb({ body = body }) return r.url end
""" + CLOUD)
r = cl.eval("""(function()
    configs.reload_cloud_configs(true)
    local list_url = ANSWER("L", { { name = "hvh", author = "bob", ts = 1 }, { name = "new", author = "ann", ts = 5 } })
    local rows = table.concat(ui.configs.cloud_list.ref.items, "|")
    ui.configs.cloud_list.ref.active = "bob ~ hvh"
    BUTTONS["Use"]()
    local get_url = ANSWER("G", { ok = true, data = "Zm9v" })
    local imported = IMPORTED
    -- Update (the selected one's name): 7000 chars = 3 parts, part 0 alone first, then 1 and 2 together
    BUTTONS["Update"]()
    local first = #PENDING
    local up0 = ANSWER("U0", { ok = true, done = false })
    local after = #PENDING
    local up1 = ANSWER("U1", { ok = true, done = false })
    ANSWER("U2", { ok = true, done = true, author = "me" })
    local refreshed = PENDING[1] and PENDING[1].url
    -- no saved key: nothing goes out
    KEY = nil
    PENDING = {}
    BUTTONS["Delete"]()
    return list_url, rows, get_url, imported, first, after, up0, up1, refreshed, #PENDING, NOTES[#NOTES]
end)()""")
check(r[0] == "https://srv/configs?lua=pm" and r[1] == "ann ~ new|bob ~ hvh"
      and r[2] == "https://srv/configs/get?lua=pm&name=hvh&author=bob" and r[3] == "CFG:Zm9v"
      and r[4] == 1 and r[5] == 2 and "upload_part?lua=pm&key=abc-key&hwid=PM-" in r[6] and "&name=hvh&total=3&idx=0&data=" in r[6]
      and "&idx=1&" in r[7] and r[8] == "https://srv/configs?lua=pm" and r[9] == 0 and "Log in once" in r[10],
      "cloud configs: list newest first, Use imports, upload in 3 parts (0 first), refresh after, no key = nothing sent (%s)"
      % (r[:6],))

print("\n%d failed" % len(FAILS) if FAILS else "\nall passed")
sys.exit(1 if FAILS else 0)
