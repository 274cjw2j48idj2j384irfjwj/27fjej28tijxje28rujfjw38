"""Freeze guard: the whole script in the mock game (tests/perf/mock.lua), every callback call on an instruction budget.

gamesense runs the script on the game's thread: a callback that never returns freezes CS:GO. The angle normalizer
looped "minus 360 until <= 180" and never ended on inf / ran for minutes on a huge value; a bad usercmd read through
ffi (a moved signature / vtable) gives exactly such values. This runs normal play and the bad inputs:

  - normal play, menu open, every option on, 10 enemies, shots, a round end / start
  - usercmd from the wrong memory (its number is not the command's): get_command must refuse it
  - usercmd with garbage view angles (inf, NaN, 1e30, 1e12)
  - garbage netvars (inf, -1e30, NaN, 3e17 for some of the reads)

and fails when any callback call runs over 20 M instructions (the game would stand still).

    pip install lupa
    python3 tests/freeze_guard.py                  specter_cloud.lua (as the dev build: tools/make_dev.py, in memory)
    python3 tests/freeze_guard.py --dev-file       specter_dev.lua as it is
"""
import os
import sys

import lupa.luajit21 as L

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "tools"))
import make_dev  # noqa: E402

BUDGET = 20000          # thousands of instructions in one callback call

if "--dev-file" in sys.argv:
    SRC = open(os.path.join(ROOT, "specter_dev.lua"), encoding="utf-8").read()
else:
    SRC = make_dev.build(open(os.path.join(ROOT, "specter_cloud.lua"), encoding="utf-8").read())

fails = []


def run(name, setup=None, per_tick=None, ticks=640, everything=True):
    rt = L.LuaRuntime(unpack_returned_tuples=True)
    rt.execute('pcall(function() require("jit").off() end)')      # compiled loops would not call the hook
    M = rt.eval("function(src) return load(src)() end")(open(os.path.join(HERE, "perf", "mock.lua")).read())
    w = M.new(SRC, rt.table_from(dict(enemies=10, mates=2)))
    if not w.loaded:
        fails.append(f"{name}: did not load: {w.load_error}")
        return
    for _ in range(40):
        w.tick(); w.frame()
    if everything:
        w.everything_on()
    w.menu_open = True
    w.budget = BUDGET
    if setup:
        setup(rt, w)
    errs = w["errors"]
    n0 = len(errs)
    for i in range(ticks):
        if per_tick:
            per_tick(rt, w, i)
        w.tick(); w.frame(); w.frame()
        if i % 25 == 0:
            en = w.enemies
            w.shoot(en[1 + (i // 25) % len(en)], i % 50 == 0)
        if i == ticks // 2:
            for ev in ("round_end", "round_prestart", "round_start"):
                w.fire(ev, rt.table_from({}))
    new = [errs[k] for k in range(n0 + 1, len(errs) + 1)]
    runaway = [e for e in new if "RUNAWAY" in e]
    print(f"   {name:<52} runaway calls {len(runaway)}   other errors {len(new) - len(runaway)}")
    if runaway:
        fails.append(f"{name}: a callback ran away (the game would freeze)")
        print("      " + "\n      ".join(runaway[0].split("\n")[:8]))


def usercmd(view, wrong=False):
    """the usercmd the script reads every tick: `view` = a Lua expression of i (the tick)"""
    fn = None

    def per_tick(rt, w, i):
        nonlocal fn
        if fn is None:
            fn = rt.eval(f'''function(w, i, wrong)
                local ffi = require("ffi")
                w.usercmd_wrong = wrong
                local c = ffi.cast("bt_cusercmd_t*", w.usercmd)
                if wrong then c.command_number = -12345 end
                local v = {view}
                c.view[0], c.view[1] = v, v
            end''')
        fn(w, i, wrong)
    return per_tick


GARBAGE = '''function(w, every)
    local k = 0
    w.garbage = function(ent, prop, idx)
        k = k + 1
        if k %% every ~= 0 then return nil end
        local r = (k / every) %% 4
        if r == 0 then return 1/0 elseif r == 1 then return -1e30 elseif r == 2 then return 0/0 end
        return 3e17
    end
end'''

print("== freeze guard (every callback call on a %d M instruction budget)" % (BUDGET // 1000))
run("normal play, every option on")
run("normal play, defaults", everything=False)
if "bt_cusercmd_t" in SRC:          # builds without the ffi usercmd read have nothing to test here
    run("usercmd from the wrong memory", per_tick=usercmd("(i % 2 == 0) and 1e30 or 10", wrong=True))
    for view in ("(i % 2 == 0) and 1/0 or 10", "(i % 2 == 0) and 1e30 or 10", "(i % 2 == 0) and 1e12 or -10", "0/0"):
        run(f"usercmd view angles {view.split(' or ')[0].replace('(i % 2 == 0) and ', '')}", per_tick=usercmd(view))
else:
    print("   (no ffi usercmd read in this build: usercmd cases skipped)")
for every in (7, 3):
    run(f"garbage netvars (1 read in {every})", setup=lambda rt, w, e=every: rt.eval(GARBAGE.replace('%%', '%'))(w, e))

print()
if fails:
    print(f"{len(fails)} CHECK(S) FAILED")
    for f in fails:
        print("  -", f)
    sys.exit(1)
print("ALL CHECKS PASSED")
