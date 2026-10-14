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
want = {"strip_lua_comments", "make_primordial_beta", "primordial_builds", "PM_BETA_STUB"}
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


# jitter misses (shot logs, Oct 2026; owners: "max 1-2 jitter miss 20-30 lövésenként"): every enemy's eye yaw steps go
# through the jitter detector whichever resolver is on (also none); a jittering target gets head + chest safe points, any
# target after a resolver / jitter miss the head one. A mouse turn and a spin are not jitter, centre / 3-way / random are
RES = chunk("local RES_JIT_N = 12", "resolver.update = function(local_player, ent)") + \
      chunk("-- safe points / smart body aim for the aimbot's target.", "resolver.reset = function()")
jr = L.LuaRuntime(unpack_returned_tuples=True)
jr.execute("""RES_FS_TICKS = 16 SIM = 0
resolver = { data = {}, misses = {}, active = false }
local function item(v) return { get = function() return v end } end
ui = { ragebot = { logic_reso = item(false), smart_baim = item(true), resolver = { shot_pred = item(4) } } }
HP = 100
damage = { calculate = function(_, _, box) return box == "chest" and 70 or 87 end }
res_custom = function() return false end
res_clamp = function(v, a, b) return math.max(a, math.min(b, v)) end
res_norm = function(v) return (v + 180) % 360 - 180 end
time_to_ticks = function(t) return math.floor(t * 64 + 0.5) end
e_hitscan_groups = { HEAD = 0, CHEST = 1, STOMACH = 2 }
ENT = { get_index = function() return 3 end, get_prop = function(_, n) if n == "m_iHealth" then return HP end return SIM end }
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
return held[20], held[60]   -- 0.63 s / 1.9 s after it stopped (the last 12 steps leave the window first)
""")
check(r == (True, False), "jitter detector: a target stays a jitter target for 1 s after it stops (older records) (%s)" % (r,))
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
RUN(SEQ(20, function(i) return i % 2 == 0 and 30 or -30 end))
local h2, c2 = HS()
local jit_head_100 = LAST.groups[0] == nil and resolver.safe[3] == 2
HP = 50
HS()
local jit_body_50 = LAST.groups[0] == false
return h0, c0, sure_head, h1, c1, head_100, body_60, h2, c2, jit_head_100, jit_body_50
""")
check(r == (False, False, True, True, False, True, True, True, True, True, True),
      "jitter / smart body aim, every resolver off: a sure head stays, after a miss / on a jitter target the head is a safe "
      "point, the body only when a body hit kills (%s)" % (r,))

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
DP = chunk("dmg_prediction = function(ctx, cmd, unpredicted_data)", "--- @endregion")
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
trace_bullet = function(_, pos) return { valid = true, hitgroup = pos } end
client_get_hitgroup_name = function(g) return g end
resolver = { safe = {} }
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
dp.execute("resolver.safe[5] = 3")
r2 = dp.eval("RUNDP()")
check(all(x == (0, 1) for x in r) and tuple(r2) == (1, 1),
      "Multipoint correction: the head first every time, the chest when Smart body aim took the head out (%s %s)" % (r[0], r2))

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
