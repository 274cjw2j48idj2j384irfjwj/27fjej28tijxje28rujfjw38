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
check(same and get("Settings", "Anti brute mode") == 2 and get("Features", "Fakelag variance") is True,
      "default.cfg: the advanced anti-aim, the same values as the preset button")

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

print("\n%d failed" % len(FAILS) if FAILS else "\nall passed")
sys.exit(1 if FAILS else 0)
