"""Regression tests for the resolver block of specter_cloud.lua (computed body yaw + learned models + side switches).

Runs the real code (the part between the `-- [resolver:begin]` / `-- [resolver:end]` markers) on a mocked gamesense API
with simulated enemies (tests/resolver_world.lua: hidden tick level AA, a copy of the server feet logic for the true body
yaw, fakelag, tickbase shifts, an aimbot with backtrack and ping delayed results), under LuaJIT 2.1 like gamesense uses.

    pip install lupa
    python3 tests/resolver_regress.py

This checks the learning and the player list handling, not the real game. Exit code is non-zero when a check fails.
Native alone (nothing forced) hits ~0.23 in this world; the ceiling is ~0.92 (6% spread misses + the tolerance).
"""
import os
import random
import re
import sys

import lupa.luajit21 as L

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

src = open(os.path.join(ROOT, "specter_cloud.lua"), encoding="utf-8").read()
m = re.search(r"-- \[resolver:begin\]\n(.*?)\n\s*-- \[resolver:end\]", src, re.S)
if not m:
    sys.exit("resolver markers not found in specter_cloud.lua")
BLOCK = m.group(1)

# what the main script gives the block: the `resolver` table, the menu items (config.resolver), the logger; and the
# event wiring of the main script (miscellaneous:aim_* -> resolver.on_*, round start -> resolver.new_round)
PRELUDE = '''
local resolver = {}
local enable_item = ui.new_checkbox("RAGE", "Other", "Resolver")
local log_item = ui.new_checkbox("RAGE", "Other", "Resolver log")
local jitter_item = ui.new_slider("RAGE", "Other", "Resolver jitter", 5, 60, 30)
local override_item = ui.new_checkbox("RAGE", "Other", "Resolver override")
local size_item = ui.new_slider("RAGE", "Other", "Resolver size", 0, 60, 35)
local function wrap(it) return { get = function() return ui.get(it) end } end
local config = { resolver = { enabled = wrap(enable_item), log = wrap(log_item), jitter = wrap(jitter_item),
                              override = wrap(override_item), override_size = wrap(size_item) } }
local c_logger = { log = function(fmt, ...) client.color_log(255, 255, 255, string.format(fmt, ...)) end }
local hooks = { fire = 0, hit = 0, miss = 0 }
resolver.stats_hook = function(kind) hooks[kind] = hooks[kind] + 1 end
'''
EPILOGUE = '''
client.set_event_callback("aim_fire", function(e) resolver.on_fire(e) end)
client.set_event_callback("aim_hit", function(e) resolver.on_hit(e) end)
client.set_event_callback("aim_miss", function(e) resolver.on_miss(e) end)
client.set_event_callback("round_prestart", function() resolver.new_round() end)
return { resolver = resolver, hooks = hooks }
'''
SCRIPT = PRELUDE + BLOCK + EPILOGUE

rt = L.LuaRuntime(unpack_returned_tuples=True)
H = rt.eval("function(src) return load(src)() end")(open(os.path.join(HERE, "resolver_world.lua")).read())
lua = rt.eval

fails = []


def check(cond, msg):
    if not cond:
        fails.append(msg)
        print("   FAIL:", msg)


def errors_of(s):
    return list(s.ctl.errors.values())


def run(scn=None, driver=None, **kw):
    o = dict(kw)
    if scn:
        o["scenario"] = scn
        o["driver_opts"] = rt.table_from(driver or {})
    return H.run(SCRIPT, rt.table_from(o))


def avg(scn, d, ping, seeds=(1, 2, 3), **kw):
    vals = []
    for sd in seeds:
        s = run(scn, dict(d, seed=7 + sd * 13), ticks=4000, ping=ping, seed=sd, **kw)
        check(s.errors == 0 and not errors_of(s), f"{scn}{d} {ping}ms: errors {errors_of(s)[:2]}")
        vals.append(s.late_rate)
    return sum(vals) / len(vals)


def pl(s, idx, field):
    t = s.ctl.plist[idx]
    return t[field] if t is not None else None


def parts(*names):
    t = "{" + ", ".join(f'"{n}"' for n in names) + "}"
    return lua(f"function(ctl) ctl.item('Resolver parts').value = {t} end")


# ── hit rates ───────────────────────────────────────────────────────────────────
print("== late hit rate (second half of the run), 3 seeds")
RATES = [
    # static desync -> desync part
    ("choke_static", dict(choke=6), 0.88), ("choke_static", dict(choke=2), 0.88), ("low_delta", {}, 0.88),
    ("choke_defensive", dict(choke=6), 0.80), ("lby_flick", {}, 0.88), ("lby_flick", dict(flick=60), 0.88),
    # side switching (anti-bruteforce, random): this version does not track it, the side is only measured -> lower
    ("anti_brute", dict(choke=6), 0.15), ("anti_miss", dict(choke=6), 0.55), ("choke_random", dict(choke=6), 0.35),
    # defensive: tickbase shift windows with flicked angles (the body yaw of those records from the server feet logic)
    ("defensive", dict(flick=110), 0.88), ("defensive", dict(flick=90), 0.88), ("defensive", dict(flick=-70, back=6), 0.85),
    ("defensive", dict(flick=110, base="jitter"), 0.88),
    # jitter -> jitter part
    ("jitter_tick", {}, 0.88), ("jitter_tick", dict(amp=58), 0.88), ("jitter_delay", dict(period=3), 0.88),
    ("jitter_delay", dict(period=5), 0.88), ("jitter_choke", dict(choke=3), 0.88), ("moving_jitter", {}, 0.88),
    ("jitter_random", {}, 0.85), ("jitter_rperiod", {}, 0.88), ("jitter_drift", {}, 0.88), ("jitter_multi", {}, 0.80),
    ("aa_sim", dict(scheme="current"), 0.85),
    # no anti-aim (every tick sent: no desync possible), the body yaw is the server's own and often ~0
    ("legit", {}, 0.85), ("legit", dict(vel=150), 0.85),
]
print(f"{'scenario':<34}{'20ms':>7}{'80ms':>7}")
for scn, d, need in RATES:
    cells = [avg(scn, d, ping) for ping in (20, 80)]
    print(f"{scn + (str(d) if d else ''):<34}" + "".join(f"{c:>7.2f}" for c in cells))
    for ping, c in zip((20, 80), cells):
        check(c >= need, f"{scn}{d} {ping}ms: hit rate {c:.2f} < {need}")

# ── noise: 15% spread + 10% misses for other reasons, inverted sign ──────────────
print("== noise, inverted sign")
for scn, need in (("choke_static", 0.70),):
    c = avg(scn, dict(choke=6), 20, spread_p=0.15, noise_p=0.10)
    print(f"   noise {scn:<12} {c:.2f}")
    check(c >= need, f"noise {scn}: hit rate {c:.2f} < {need}")
c = avg("lby_flick", dict(choke=6), 20, truth_pol=-1)
print(f"   inverted sign lby_flick    {c:.2f}")
check(c >= 0.88, f"inverted sign lby_flick: hit rate {c:.2f}")

# ── zero rule: a near-0 angle has to be earned, on jitter records too ──────────
# new players (a fresh script each) with a jitter AA and micromovement: the netvars show no desync, with fakelag the feet
# model lands near 0 on many records. The first 10 shots of each: how many went near 0 while the target really desynced
# (that was 9-14%), the hit rate; and players who do not desync must still be hit
print("== zero rule: jitter + micromovement, 60 new players, first 10 shots")
FIRST10 = lua('''function(acc)
    return function(k, e, r, hit, ctl, S)
        if r.applied == nil or acc.k >= 10 then return end
        acc.k, acc.n = acc.k + 1, acc.n + 1
        if hit then acc.h = acc.h + 1 end
        if math.abs(r.applied) < 20 and math.abs(r.T) >= 30 then acc.z = acc.z + 1 end
    end
end''')


def zero_pop(bodies, chokes, players=60):
    rnd = random.Random(5)
    acc = lua("function() return { n = 0, z = 0, h = 0, k = 0 } end")()
    for i in range(players):
        d = dict(amp=rnd.randint(15, 44), choke=rnd.randint(*chokes), body=rnd.choice(bodies), side=rnd.choice((1, -1)),
                 size=rnd.randint(40, 58), seed=rnd.randint(1, 10 ** 6), center=rnd.randint(-10, 10))
        if rnd.random() < 0.5:
            d["hold"] = rnd.randint(1, 4)
        else:
            d["rhold"] = rnd.randint(2, 5)
        acc.k = 0
        s = run("micro_jitter", d, ticks=330, ping=rnd.choice((20, 40, 80)), seed=i + 1, on_shot=FIRST10(acc))
        check(s.errors == 0 and not errors_of(s), f"micro_jitter{d}: errors {errors_of(s)[:2]}")
    return acc.z / acc.n, acc.h / acc.n


for name, bodies, chokes, max_zero, need in (("desync, choke 1-3", ("static", "opp", "same"), (1, 3), 0.02, 0.66),
                                             ("desync, choke 6-14", ("static", "opp", "same"), (6, 14), 0.05, 0.46),
                                             ("no desync, choke 1-3", ("none",), (1, 3), 1, 0.50),
                                             ("no desync, choke 6-14", ("none",), (6, 14), 1, 0.35)):
    z, h = zero_pop(bodies, chokes)
    print(f"   {name:<22} near 0 on a real desync {z * 100:4.1f}%   hit {h:.2f}")
    check(z <= max_zero, f"zero rule {name}: {z * 100:.1f}% of the shots near 0 on a real desync")
    check(h >= need, f"zero rule {name}: hit rate of the first shots {h:.2f} < {need}")

# a target we never hit (its body yaw is out of reach: like lag comp breakers whose misses count as resolver misses):
# the near-0 try used to come after every 2-3 misses (21% of the shots), each failed try now doubles the misses it takes
NEAR0_ALL = lua('''function(acc)
    return function(k, e, r, hit, ctl, S)
        if r.applied == nil then return end
        acc.n = acc.n + 1
        if math.abs(r.applied) < 20 then acc.z = acc.z + 1 end
    end
end''')
acc = lua("function() return { n = 0, z = 0 } end")()
for sd in (1, 2, 3):
    for d in (dict(amp=30, choke=6, size=100), dict(amp=0, choke=6, size=100)):
        run("micro_jitter", dict(d, seed=sd), ticks=3000, ping=40, seed=sd, on_shot=NEAR0_ALL(acc))
print(f"   never hit target: {acc.z / acc.n * 100:.1f}% of {acc.n} shots near 0")
check(acc.z / acc.n <= 0.12, f"never hit target: {acc.z / acc.n * 100:.1f}% of the shots near 0")

G0 = lua('''function(tick, ent, name)
    local r = (tick * 7 + ent * 13 + #name) % 19
    if r == 0 then return 0/0 elseif r == 1 then return math.huge elseif r == 2 then return -1e30 end
    return nil
end''')

# ── options ─────────────────────────────────────────────────────────────────────
print("== options")
SET = lambda name, v: lua(f"function(ctl) ctl.item('{name}').value = {v} end")
s = run("anti_brute", dict(choke=6), ticks=3000, configure=SET("Resolver override", "true"))
vals = set()
for _, h in s.S.resolver.database[2].hist.items():
    vals.add(h.value)
check(vals and all(abs(v) == 35 for v in vals), f"override size: forced values {sorted(vals)[:6]} should all be +-35")
s = run("choke_static", dict(choke=6), ticks=3000)
d = s.S.resolver.database[2]
check(d.method in ("Static", "LBY", "Dynamic") and d.phit is not None and d.phit > 0.5, f"info: method {d.method} confidence {d.phit}")
s = run("jitter_tick", {}, ticks=2000)
check(s.S.resolver.database[2].method == "Jitter" and s.S.resolver.database[2].mode == "j", "jitter target: method Jitter")
s = run("jitter_tick", {}, ticks=2000, configure=SET("Resolver jitter", "90"))
check(s.S.resolver.database[2].mode == "d", "jitter sensitivity 90: a 70 degree jitter is not a jitterer any more")
print(f"   override size, info (method / confidence), jitter sensitivity")

# a shot at a record 60 ticks old is still judged by what that record got (64 ticks of history)
s = run("jitter_tick", {}, ticks=1500)
check(len(list(s.S.resolver.database[2].hist.keys())) == 64, "64 records of history")

# ── player list handling ──────────────────────────────────────────────────────
print("== player list")
s = run("choke_static", dict(choke=6), ticks=500, disabled=True)
check(len(list(s.ctl.plist.keys())) == 0, "disabled: the player list must not be touched")

# Correction active is given back with the value it had (false here), also when it was false
CORR = lua('''function(ctl) ctl.plist[2] = { ["Correction active"] = false } end''')
TOGGLE = lua('''function(state)
    return function(k, ctl, S)
        if k == 1500 then ctl.item("Resolver").value = false end
        if k == 1499 then state.mid = { ctl.plist[2]["Force body yaw"], ctl.plist[2]["Correction active"] } end
        if k == 1600 then state.off = { ctl.plist[2]["Force body yaw"], ctl.plist[2]["Correction active"] } end
    end
end''')
state = lua("function() return {} end")()
s = run("choke_static", dict(choke=6), ticks=1700, configure=CORR, on_tick=TOGGLE(state))
check(state.mid[1] is True and state.mid[2] is True, f"enabled: forced + correction on ({state.mid[1]}, {state.mid[2]})")
check(state.off[1] is False and state.off[2] is False, f"disabled mid-game: released, correction back to false ({state.off[1]}, {state.off[2]})")

# dead / dormant players are released (gamesense does not list them), forced again when they are back
for what in ("dead_fn", "dormant_fn"):
    state = lua("function() return {} end")()
    WATCH = lua('''function(state)
        return function(k, ctl, S)
            if k == 1100 then state.during = ctl.plist[2]["Force body yaw"] end
            if k == 1400 then state.after = ctl.plist[2]["Force body yaw"] end
        end
    end''')(state)
    gone = lua("function(tick, idx) return tick >= 1000 and tick < 1200 end")
    s = run("choke_static", dict(choke=6), ticks=2500, on_tick=WATCH, **{what: gone})
    check(s.errors == 0 and not errors_of(s), f"{what}: errors {errors_of(s)[:2]}")
    check(state.during is False, f"{what}: must be released while gone (Force body yaw = {state.during})")
    check(state.after is True, f"{what}: must be forced again when back (Force body yaw = {state.after})")
    check(s.late_rate >= 0.85, f"{what}: hit rate after coming back {s.late_rate:.2f}")
    print(f"   {what}: released while gone, back after; late rate {s.late_rate:.2f}")

s = run("choke_static", dict(choke=6), ticks=800)
check(pl(s, 2, "Force body yaw") is True, "forced while running")
s.fire("shutdown")
check(pl(s, 2, "Force body yaw") is False, "shutdown releases")

# ── shot attribution: a shot is judged by the value its record got ───────────
print("== shot attribution (half of the shots go at backtracked records)")
ATTR = lua('''function(acc)
    return function(k, e, r, hit, ctl, S)
        local best, bt = nil, -1
        for _, s in pairs(S.resolver.shots) do if s.time > bt then best, bt = s, s.time end end
        if best and best.mode and r.applied ~= nil then
            acc.n = acc.n + 1
            if best.value ~= r.applied then acc.bad = acc.bad + 1 end
            if best.bt > 0 then acc.bt = acc.bt + 1 end
        end
    end
end''')
for scn, d in (("choke_static", dict(choke=6)), ("choke_random", dict(choke=6)), ("anti_brute", dict(choke=6)), ("jitter_rperiod", {}), ("lby_flick", {})):
    acc = lua("function() return { n = 0, bad = 0, bt = 0 } end")()
    for ping in (20, 80):
        run(scn, dict(d), ticks=3000, ping=ping, on_shot=ATTR(acc))
    print(f"   {scn}: {acc.n} shots ({acc.bt} backtracked), {acc.bad} judged by a different value than their record got")
    check(acc.n > 100 and acc.bt > 30, f"{scn}: too few shots to judge attribution")
    check(acc.bad == 0, f"{scn}: {acc.bad} shots judged by the wrong value")

# ── robustness ────────────────────────────────────────────────────────────────
print("== robustness")
G = lua('''function(tick, ent, name)
    local r = (tick * 7 + ent * 13 + #name) % 19
    if r == 0 then return 0/0 elseif r == 1 then return math.huge elseif r == 2 then return -1e30 end
    return nil
end''')
for scn, d in (("choke_static", dict(choke=6)), ("jitter_tick", {}), ("jitter_choke", dict(choke=3)), ("moving_jitter", {})):
    s = run(scn, d, ticks=3000, ping=40, garbage=G)
    check(s.errors == 0 and not errors_of(s), f"garbage props {scn}: {errors_of(s)[:2]}")
print("   garbage netvars (NaN / inf / huge): no errors")

s = run("jitter_tick", {}, ticks=3000, no_ids=True)
check(s.errors == 0 and s.late_rate >= 0.85, f"shots without ids: {s.late_rate:.2f} {errors_of(s)[:2]}")

ENEMIES = lua('''function(drivers)
    local specs = {}
    for i, name in ipairs({ 'choke_static', 'jitter_tick', 'jitter_delay', 'moving_jitter', 'jitter_rperiod' }) do
        specs[i] = { driver = drivers[name]({ period = 3, choke = 6, seed = 40 + i }), name = 'enemy' .. i }
    end
    return specs
end''')(H.drivers)
s = run(enemies=ENEMIES, ticks=12000, ping=30, shoot_every=4)
rates = [s.per[i].late_rate for i in range(2, 7)]
print("   5 enemies (static, jitter x4):", [round(x, 2) for x in rates])
check(s.errors == 0 and not errors_of(s), f"5 enemies: {errors_of(s)[:2]}")
check(min(rates) >= 0.85, f"5 enemies: lowest {min(rates):.2f}")
check(len(list(s.S.resolver.memory.keys())) == 5, "5 enemies: one memory per player")

# a new player in the slot of one who left (another steam id): a new memory, not the old one's
SID = lua('function(tick, idx) if tick >= 2000 then return "76561198999999999" end return "7656119800000000" .. idx end')
s = run("choke_static", dict(choke=6), ticks=3000, steam_fn=SID)
keys = sorted(s.S.resolver.memory.keys())
check(len(keys) == 2 and s.S.resolver.database[2].key == "id76561198999999999", f"slot reuse: keys {keys}")

# sim time jumping back (map change) and a long gap: the records start over, no errors
JUMP = lua('''function(drivers)
    local d = drivers.jitter_tick({})
    d.shift = function(k) if k == 1500 then return { back = 40, theta = 0 } end return nil end
    return { { driver = d, name = 'enemy1' } }
end''')(H.drivers)
s = run(enemies=JUMP, ticks=3000)
check(s.errors == 0 and s.late_rate >= 0.85, f"sim time jump: {s.late_rate:.2f} {errors_of(s)[:2]}")

# round reset, memory reset mid-game (results of shots fired before it arrive after it)
RESETS = lua('''function(k, ctl, S)
    if k == 1200 then for _, fn in ipairs(ctl.callbacks.round_prestart or {}) do fn() end end
    if k == 1700 then S.resolver.reset_all() end
end''')
s = run("jitter_tick", {}, ticks=4000, on_tick=RESETS)
check(s.errors == 0 and not errors_of(s), f"round / memory reset: {errors_of(s)[:2]}")
check(s.late_rate >= 0.85, f"after round / memory reset: {s.late_rate:.2f}")
check(s.S.hooks.fire == s.shots, f"stats hook: {s.S.hooks.fire} fire calls for {s.shots} shots")
check(s.S.hooks.hit + s.S.hooks.miss > 0.9 * s.shots, "stats hook: hit / miss calls")
print(f"   round + memory reset: {s.late_rate:.2f}; stats hook fire {s.S.hooks.fire} / {s.shots} shots")

# log only when the option is on
s = run("jitter_tick", {}, ticks=1500)
check(len(list(s.ctl.logs.values())) == 0, "log off: nothing printed")
s = run("jitter_tick", {}, ticks=1500, configure=SET("Resolver log", "true"))
logs = list(s.ctl.logs.values())
check(len(logs) == 0, f"resolver prints nothing of its own (the hitlog shows the angle): {logs[:2]}")
last = s.S.resolver.last_log
logs = [last] if last else []
check(bool(last) and ("j+" in last or "j-" in last), f"last_log: {last}")
print("   log line:", logs[0] if logs else "-")

print()
if fails:
    print(f"{len(fails)} CHECK(S) FAILED")
    sys.exit(1)
print("ALL CHECKS PASSED")
