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
# the real ping helper the block uses (defined before the modules, shared with Predict enemies)
mp = re.search(r"-- \[ping:begin\]\n(.*?)\n\s*-- \[ping:end\]", src, re.S)
if not mp:
    sys.exit("ping markers not found in specter_cloud.lua")
PING = mp.group(1)

# what the main script gives the block: the `resolver` table, the menu items (config.resolver), the logger; and the
# event wiring of the main script (miscellaneous:aim_* -> resolver.on_*, round start -> resolver.new_round)
PRELUDE = '''
local resolver = {}
local enable_item = ui.new_checkbox("RAGE", "Other", "Resolver")
local log_item = ui.new_checkbox("RAGE", "Other", "Resolver log")
local function wrap(it) return { get = function() return ui.get(it) end } end
local config = { resolver = { enabled = wrap(enable_item), log = wrap(log_item) } }
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
SCRIPT = PRELUDE + PING + "\n" + BLOCK + EPILOGUE

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


def avg(scn, d, ping, seeds=(1, 2, 3), metric="late_rate", **kw):
    vals = []
    for sd in seeds:
        s = run(scn, dict(d, seed=7 + sd * 13), ticks=4000, ping=ping, seed=sd, **kw)
        check(s.errors == 0 and not errors_of(s), f"{scn}{d} {ping}ms: errors {errors_of(s)[:2]}")
        vals.append(getattr(s, metric))
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
    # defensive: tickbase shift windows with flicked angles. The server has no lag record of them: a shot at the shifted
    # model is a lag comp miss for everyone (the "valid" rate below counts the shots at real records)
    ("defensive", dict(flick=110), 0.82), ("defensive", dict(flick=90), 0.82), ("defensive", dict(flick=-70, back=6), 0.82),
    ("defensive", dict(flick=110, base="jitter"), 0.82),
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

# ── defensive (tickbase shift): no angle of its own, shots judged by the server's lag record ──────────
# jitter with micromovement + an always-on defensive with a pitch flick (owners, Oct 2026: "a jittert es a defensive
# resot osszekeveri", a "res 0" shot at a 58 tick backtrack): the shifted updates used to get their own "def" angle
# (computed body yaw of the flick, often ~0, exempt from the zero rule: 16% of the shots near 0 on a real desync) and
# shots at normal records were judged by a shifted update with the same sim tick (10-15% of them, reason "defensive")
print("== defensive: shifted updates keep the jitter / desync angle, shots judged by the normal record")
DEF = lua('''function(acc)
    return function(k, e, r, hit, ctl, S)
        local best, bt = nil, -1
        for _, s in pairs(S.resolver.shots) do if s.time > bt then best, bt = s, s.time end end
        if not best or r.applied == nil then return end
        acc.n = acc.n + 1
        if math.abs(r.applied) < 20 and math.abs(r.T) >= 30 then acc.z = acc.z + 1 end
        if r.shifted then
            acc.sh = acc.sh + 1
            if best.reason ~= "defensive" then acc.unmarked = acc.unmarked + 1 end
            -- the shifted model kept the value of the newest normal record
            if r.applied ~= e.valid[#e.valid].applied then acc.moved = acc.moved + 1 end
            -- judged and logged (bt, angle) by the server's lag record: the newest normal one at or before its sim time.
            -- gamesense says 0 ticks back for the drawn shifted model ("missed: defensive  bt 0t")
            if r.srv and r.srv.applied ~= nil and (best.value ~= r.srv.applied or best.bt ~= e.max_st - r.srv.st) then
                acc.srv = acc.srv + 1
            end
        elseif best.value ~= nil and best.value ~= r.applied then
            acc.bad = acc.bad + 1
        end
    end
end''')
for d in (dict(body="static"), dict(body="opp"), dict(body="coin"), dict(body="static", choke=0, every=48, len=6),
          dict(body="static", back=12, len=6)):
    acc = lua("function() return { n = 0, z = 0, sh = 0, unmarked = 0, moved = 0, bad = 0, srv = 0 } end")()
    vals = []
    for sd in (1, 2, 3):
        for ping in (20, 80):
            s = run("jitter_defensive", dict(d, seed=sd * 31), ticks=3000, ping=ping, seed=sd, on_shot=DEF(acc))
            check(s.errors == 0 and not errors_of(s), f"jitter_defensive{d}: errors {errors_of(s)[:2]}")
            vals.append(s.valid_rate)
    v = sum(vals) / len(vals)
    print(f"   {str(d):<52} valid {v:.2f}  near 0 {acc.z}/{acc.n}  at shifted {acc.sh} (unmarked {acc.unmarked}, "
          f"value moved {acc.moved}, not the server's record {acc.srv})  misjudged {acc.bad}")
    need = 0.42 if d["body"] == "coin" else 0.88
    check(v >= need, f"jitter_defensive{d}: valid hit rate {v:.2f} < {need}")
    check(acc.z <= 0.02 * acc.n, f"jitter_defensive{d}: {acc.z} of {acc.n} shots near 0 on a real desync")
    check(acc.sh > 10 and acc.unmarked == 0, f"jitter_defensive{d}: {acc.unmarked} of {acc.sh} shots at a shifted model not marked defensive")
    check(acc.moved == 0, f"jitter_defensive{d}: the forced value moved on {acc.moved} shifted updates")
    check(acc.srv == 0, f"jitter_defensive{d}: {acc.srv} of {acc.sh} shots at a shifted model not judged by the server's record")
    check(acc.bad == 0, f"jitter_defensive{d}: {acc.bad} shots judged by another value than their record got")
# a target that moves left and right while it shifts (jiggle peek), aim points: the drawn shifted model lies near an
# older record, its shots were taken for backtracked ones (14-16% of them not marked defensive, learned as resolver misses)
for d in (dict(body="static"), dict(body="static", back=12, len=6)):
    acc = lua("function() return { n = 0, z = 0, sh = 0, unmarked = 0, moved = 0, bad = 0, srv = 0 } end")()
    for sd in (1, 2, 3):
        for ping in (20, 80):
            drv = H.drivers["jitter_defensive"](rt.table_from(dict(d, seed=sd * 31)))
            spec = rt.table_from([rt.table_from({"driver": drv, "move": True})])
            s = H.run(SCRIPT, rt.table_from(dict(enemies=spec, ticks=3000, ping=ping, seed=sd, on_shot=DEF(acc), aim=True)))
            check(s.errors == 0 and not errors_of(s), f"jitter_defensive{d} moving: errors {errors_of(s)[:2]}")
    print(f"   moving {str(d):<45} at shifted {acc.sh} (unmarked {acc.unmarked}, not the server's record {acc.srv})")
    check(acc.sh > 10 and acc.unmarked == 0, f"jitter_defensive{d} moving: {acc.unmarked} of {acc.sh} shots at a shifted model not marked defensive")
    check(acc.srv == 0, f"jitter_defensive{d} moving: {acc.srv} of {acc.sh} shots at a shifted model not judged by the server's record")
for scn, d in (("defensive", dict(flick=110)), ("defensive", dict(flick=110, base="jitter")), ("choke_defensive", dict(choke=6))):
    c = avg(scn, d, 40, metric="valid_rate")
    print(f"   {scn + str(d):<52} valid {c:.2f}")
    check(c >= 0.88, f"{scn}{d}: valid hit rate {c:.2f} < 0.88")
# a defensive that keeps the angles (only the lag record breaks): a shot at the shifted model is tested against the
# record before it with the value the shifted model kept
c = avg("jitter_defensive", dict(body="static"), 40, def_head="same")
print(f"   jitter_defensive, angles kept on the shifted packets          late {c:.2f}")
check(c >= 0.85, f"jitter_defensive def_head=same: hit rate {c:.2f} < 0.85")
# "Force pitch" froze CS:GO when the owners joined a game (Oct 2026, it was written on every defensive burst): the
# resolver never touches the pitch
for scn, d in (("jitter_defensive", dict(body="static")), ("defensive", dict(flick=110)), ("choke_static", dict(choke=6))):
    s = run(scn, d, ticks=800)
    check(pl(s, 2, "Force pitch") is None and pl(s, 2, "Force pitch value") is None,
          f"{scn}: the pitch must never be written ({pl(s, 2, 'Force pitch')})")

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

# ── info / automatic jitter detection (owners, Oct 2026: the resolver needs nothing but its switch: no jitter
# sensitivity, hide head predictor or override size any more) ──────────────────────────────────────────────────
print("== info, jitter detection")
SET = lambda name, v: lua(f"function(ctl) ctl.item('{name}').value = {v} end")
s = run("choke_static", dict(choke=6), ticks=3000)
d = s.S.resolver.database[2]
check(d.method in ("Static", "LBY", "Dynamic") and d.phit is not None and d.phit > 0.5, f"info: method {d.method} confidence {d.phit}")
s = run("jitter_tick", {}, ticks=2000)
check(s.S.resolver.database[2].method == "Jitter" and s.S.resolver.database[2].mode == "j", "jitter target: method Jitter")
s = run("jitter_tick", dict(amp=10), ticks=2000)
check(s.S.resolver.database[2].mode == "d", "a 20 degree jitter (below the fixed 30 degree spread) is not a jitterer")
print(f"   info (method / confidence), jitter detection")

# a shot at a record 60 ticks old is still judged by what that record got: 1 s of history (64 ticks on 64 tick)
s = run("jitter_tick", {}, ticks=1500)
p = s.S.resolver.database[2]
span = p.max_st - p.hist[1].st
check(span == 64 and len(list(p.hist.keys())) == 65, f"history: {span} ticks, {len(list(p.hist.keys()))} records (1 s = 64 ticks)")

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

# ── a standing target: the aim point can not tell the record, the shots at a moving one teach how gamesense's number /
# the shot's tick relate to the record (owners, Oct 2026: "rosszul logolja a shotokra az anglet, bt is": with a ping
# spike gamesense says 0 for a record ~fake latency old, the jitter side of the newest record was logged and learned)
print("== standing target: backtrack learned from the shots at a moving one")
STAND = lua('''function(acc)
    return function(k, e, r, hit, ctl, S)
        local best, t = nil, -1
        for _, s in pairs(S.resolver.shots) do if s.time > t then best, t = s, s.time end end
        -- after the first 800 ticks: until 8 shots at the moving one were measured gamesense's number is used
        if not best or r.applied == nil or r.shifted or k <= 800 then return end
        local who = e.move and "run" or "stand"
        acc[who] = acc[who] + 1
        if best.value ~= r.applied or best.bt ~= e.max_st - r.st then acc[who .. "_bad"] = acc[who .. "_bad"] + 1 end
    end
end''')
TWO = lua('''function(drivers)
    return { { driver = drivers.choke_static({ choke = 2 }), name = "runner", move = true },
             { driver = drivers.jitter_tick({}), name = "stander" } }
end''')(H.drivers)
for what, kw, stand_max in (
        ("no ping spike, tick = fired", dict(aim=True), 0.0),
        ("ping spike 12t, tick = fired", dict(aim=True, native_off=12, bt_min=12, bt_max=24), 0.01),
        ("ping spike 12t, tick = record + 1", dict(aim=True, native_off=12, bt_min=12, bt_max=24, ev_tick="record"), 0.01)):
    acc = lua("function() return { run = 0, run_bad = 0, stand = 0, stand_bad = 0 } end")()
    for sd in (1, 2):
        s = run(enemies=TWO, ticks=4000, ping=40, seed=sd, on_shot=STAND(acc), **kw)
        check(s.errors == 0 and not errors_of(s), f"standing target {what}: errors {errors_of(s)[:2]}")
    print(f"   {what:<36} moving: {acc.run_bad}/{acc.run} misjudged   standing: {acc.stand_bad}/{acc.stand} misjudged")
    check(acc.stand > 100, f"standing target {what}: too few shots")
    check(acc.stand_bad <= stand_max * acc.stand, f"standing target {what}: {acc.stand_bad} of {acc.stand} shots judged by another record")

# ── 128 tick, long backtrack: the server lag compensates up to 1 s (sv_maxunlag), on 128 tick that is 128 ticks; a
# shot at a 58+ tick old record used to fall out of the 64 records / 64 ticks the resolver kept ("bt 58t res 0")
print("== 128 tick, shots up to 120 ticks back")
for scn, d in (("choke_static", dict(choke=1)), ("jitter_rperiod", {}), ("jitter_tick", {})):
    acc = lua("function() return { n = 0, bad = 0, bt = 0 } end")()
    s = run(scn, dict(d), ticks=6000, ping=40, tickrate=128, bt_max=120, on_shot=ATTR(acc))
    p = s.S.resolver.database[2]
    span = p.max_st - p.hist[1].st
    print(f"   {scn}: {acc.n} shots ({acc.bt} backtracked), {acc.bad} misjudged, history {span} ticks, late {s.late_rate:.2f}")
    check(s.errors == 0 and not errors_of(s), f"128 tick {scn}: errors {errors_of(s)[:2]}")
    check(span >= 120, f"128 tick {scn}: history {span} ticks < 120")
    check(acc.bad == 0 and acc.bt > 100, f"128 tick {scn}: {acc.bad} of {acc.n} shots misjudged ({acc.bt} backtracked)")
    check(s.late_rate >= 0.85, f"128 tick {scn}: late rate {s.late_rate:.2f}")

# ── ping spike: the scoreboard ping has the fake ping, the ping profile takes the real one ───────────
print("== ping profile with a ping spike")
for ping, fake in ((20, 0), (40, 200), (80, 150), (110, 100)):
    s = run("jitter_tick", {}, ticks=1500, ping=ping, fake_ping=fake)
    b = s.S.resolver.ping_state.bucket
    print(f"   real {ping} ms + fake {fake} ms (scoreboard {ping + fake}): profile {b} ms, late {s.late_rate:.2f}")
    check(b is not None and abs(b - ping) <= 5, f"ping spike {fake} on {ping} ms: profile {b} ms")
    check(s.late_rate >= 0.85, f"ping spike {fake} on {ping} ms: late rate {s.late_rate:.2f}")

# ── when gamesense reads the forced value: after net_update_end (apply_lag 0) or before it (1: the record gets what was
# set at net_update_start). Owners, Oct 2026: "a hitlog nem jol detektalja a szoget", many resolver misses on HvH; with
# the value written only at net_update_end and a gamesense that reads it before, every jitter record got the angle of the
# record before it (0.08-0.15). The predicted value is written at net_update_start, the shots tell which one is read
print("== forced value timing (read after / before net_update_end)")
for scn, d in [("jitter_tick", {}), ("jitter_delay", dict(period=3)), ("jitter_choke", dict(choke=3)), ("moving_jitter", {}),
               ("choke_static", dict(choke=6)), ("anti_miss", dict(choke=6))]:
    cells = [avg(scn, d, 50, apply_lag=lag) for lag in (0, 1)]
    print(f"   {scn + (str(d) if d else ''):<30} after {cells[0]:.2f}  before {cells[1]:.2f}")
    for lag, c in zip((0, 1), cells):
        check(c >= 0.85, f"timing {lag}: {scn}{d} hit rate {c:.2f} < 0.85")
# a random jitter can not be predicted: there the shots tell the timing, and the log / learning take the value read
for lag in (0, 1):
    s = run("jitter_random", dict(seed=20), ticks=4000, ping=50, seed=1, apply_lag=lag)
    t = s.S.resolver.timing
    check(bool(t.pre) == (lag == 1), f"timing {lag}: learned pre={t.pre} (s {t.s:.1f})")
    print(f"   jitter_random {'before' if lag else 'after'}: learned {'before' if t.pre else 'after'} (s {t.s:.1f}), hit rate {s.late_rate:.2f}")

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
