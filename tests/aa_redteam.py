"""How hittable is our own anti-aim? (red team)

The REAL anti-aim code of the dev build runs as the local player in the mock game of tests/perf/mock.lua: every tick it
picks its preset settings and writes them into gamesense's AA references; the mock chokes / sends packets like
gamesense does (allow_send_packet, fake lag limit). What gamesense would do with those settings is modelled per sent
packet (yaw base at targets + yaw offset + native yaw jitter, body yaw side from Static / Jitter / Opposite /
freestanding, max desync by speed) and becomes the enemy of tests/resolver_world.lua, where resolvers shoot at it with
backtrack and ping. Their hits / shots go back to the anti-aim as player_hurt / bullet_impact (its anti brute-force).

The attackers are the resolver of this script in two setups (full, without the jitter split). Lower hit
rate = harder to hit. This models the angles only: a real enemy cheat also reads animation layers, which the model
does not have.

    python3 tests/aa_redteam.py                 every preset, standing / moving / air, 3 attackers
    python3 tests/aa_redteam.py Delay Distort   only those presets
"""
import os
import re
import sys

import lupa.luajit21 as L

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

PRESETS = ["Specter Delay", "Specter 3-Way", "Specter Distort"]
STATES = {"stand": (0, 0, True, 0), "move": (230, 0, True, 0), "air": (180, 0, False, 0)}

src_cloud = open(os.path.join(ROOT, "specter_cloud.lua"), encoding="utf-8").read()
BLOCK = re.search(r"-- \[resolver:begin\]\n(.*?)\n\s*-- \[resolver:end\]", src_cloud, re.S).group(1)
PING = re.search(r"-- \[ping:begin\]\n(.*?)\n\s*-- \[ping:end\]", src_cloud, re.S).group(1)
T = open(os.path.join(HERE, "resolver_regress.py"), encoding="utf-8").read()
PRE = re.search(r"PRELUDE = '''(.*?)'''", T, re.S).group(1)
POST = re.search(r"EPILOGUE = '''(.*?)'''", T, re.S).group(1)
# the resolver as it is, and without the jitter split (a 90 degree spread before a target counts as a jitterer)
assert "local JITTER_SPREAD = 30" in BLOCK
ATTACKERS = {
    "full": PRE + PING + "\n" + BLOCK + POST,
    "nojit": PRE + PING + "\n" + BLOCK.replace("local JITTER_SPREAD = 30", "local JITTER_SPREAD = 90") + POST,
}

BRIDGE = r'''
return function(w, opts)
    -- gamesense's anti-aim on the settings the script wrote, once per sent packet
    local n, rel, side, rnd = 0, 0, 1, 7
    local function rand()
        rnd = (rnd * 1103515245 + 12345) % 2147483648
        return rnd / 2147483648
    end
    local function sgn(x) return x > 0 and 1 or (x < 0 and -1 or 0) end
    local d = {}
    local speed = math.sqrt((opts.vx or 0) ^ 2 + (opts.vy or 0) ^ 2)
    function d.eye(k)
        w.tick()
        w.frame()
        if w.sent then
            n = n + 1
            local yaw = tonumber((w.gs_ref("Yaw", 2))) or 0
            local jt, jv = (w.gs_ref("Yaw jitter", 1)) or "Off", tonumber((w.gs_ref("Yaw jitter", 2))) or 0
            local bt, bv = (w.gs_ref("Body yaw", 1)) or "Off", tonumber((w.gs_ref("Body yaw", 2))) or 0
            local fs = (w.gs_ref("Freestanding body yaw", 1))
            local add = 0
            if jt == "Offset" then add = (n % 2 == 0) and jv or 0
            elseif jt == "Center" then add = (n % 2 == 0) and jv / 2 or -jv / 2
            elseif jt == "Random" then add = (rand() - 0.5) * jv
            elseif jt == "Skitter" then add = ({ -jv, 0, jv })[n % 3 + 1] end
            rel = yaw + add
            if fs == true then side = 1
            elseif bt == "Static" then side = sgn(bv)
            elseif bt == "Jitter" then side = (n % 2 == 0) and 1 or -1
            elseif bt == "Opposite" then side = rel > 0 and -1 or 1
            else side = 0 end
            d.last = { rel = rel, side = side, bt = bt, jt = jt }
        end
        return rel
    end
    function d.sent(k) return w.sent end
    function d.vel(k) return speed end
    function d.truth(k) return side * 58 * (1 - 0.35 * math.min(speed / 250, 1)) end
    -- the attacker's shots reach our anti-aim like in the game
    local attacker = w.enemies[1]
    function d.on_hit(k)
        w.fire("player_hurt", { userid = 1, attacker = attacker, dmg_health = 90, health = 10, hitgroup = 1 })
    end
    function d.on_shot(k)
        w.fire("bullet_impact", { userid = attacker, x = 0, y = 0, z = 64 })
    end
    return d
end
'''


def item_named(w, name):
    for i, it in w["items"].items():
        if it.name == name:
            return i
    raise KeyError(name)


def make_rt():
    rt = L.LuaRuntime(unpack_returned_tuples=True)
    mock = rt.eval("function(src) return load(src)() end")(open(os.path.join(HERE, "perf", "mock.lua")).read())
    world = rt.eval("function(src) return load(src)() end")(open(os.path.join(HERE, "resolver_world.lua")).read())
    bridge = rt.eval("function(src) return load(src)() end")(BRIDGE)
    return rt, mock, world, bridge


def run(preset, state, attacker, ping=40, ticks=3000, seed=1, dev=None):
    rt, mock, world, bridge = make_rt()
    vx, vy, ground, duck = STATES[state]
    w = mock.new(dev, rt.table_from({"enemies": 1, "mates": 0, "seed": seed}))
    assert w.loaded, w.load_error
    for _ in range(30):
        w.tick()
        w.frame()
    w.ui.set(item_named(w, "Enable\nspecter_aa_master"), True)
    w.ui.set(item_named(w, "Preset\naa"), preset)
    w.set_local(vx, vy, ground, duck)
    for _ in range(30):
        w.tick()
        w.frame()
    d = bridge(w, rt.table_from({"vx": vx, "vy": vy}))
    spec = rt.table_from([rt.table_from({"driver": d, "name": "us"})])
    s = world.run(ATTACKERS[attacker], rt.table_from({"enemies": spec, "ticks": ticks, "ping": ping, "seed": seed}))
    errs = list(s.ctl.errors.values()) + list(w.errors.values())
    return s.late_rate, errs, d


def main():
    names = sys.argv[1:]
    presets = [p for p in PRESETS if not names or any(n.lower() in p.lower() for n in names)]
    dev = open(os.path.join(ROOT, "specter_dev.lua"), encoding="utf-8").read()
    print("late hit rate of the attacker against our anti-aim (lower = harder to hit), 40 ms, 2 seeds")
    print(f"{'preset':<18}{'state':<7}" + "".join(f"{a:>9}" for a in ATTACKERS) + "   last settings")
    worst = []
    for preset in presets:
        for state in STATES:
            cells, last = [], None
            for a in ATTACKERS:
                vals = []
                for seed in (1, 2):
                    r, errs, d = run(preset, state, a, seed=seed, dev=dev)
                    if errs:
                        print("   errors:", sorted(set(e[:150] for e in errs))[:3])
                    vals.append(r)
                    last = d.last
                cells.append(sum(vals) / len(vals))
            info = f"{last.jt}/{last.bt}" if last else ""
            print(f"{preset[8:]:<18}{state:<7}" + "".join(f"{c:>9.2f}" for c in cells) + f"   {info}", flush=True)
            worst.append(max(cells))
    print(f"\nmean of the best attacker per preset / state: {sum(worst) / len(worst):.2f}")
    # a resolver that has to guess the side randomly hits ~0.47 here (6% spread); clearly above that = something learnable
    bad = [w for w in worst if w > 0.60]
    print("RED TEAM", "PASSED" if not bad else f"FAILED ({len(bad)} preset / state above 0.60)")
    return 0 if not bad else 1


if __name__ == "__main__":
    sys.exit(main())
