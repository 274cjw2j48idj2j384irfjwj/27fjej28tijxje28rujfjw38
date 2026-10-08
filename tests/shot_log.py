"""Shot logs of the dev build (the whole dev build in the mock game of tests/perf/mock.lua, http answered here):

  - one JSON line per shot with a result: the shot, the resolver's angle of its record, the target's netvars, the result
  - sent to the license server (/shotlog) in base64 parts every 40 shots and at round end; the parts decode to the lines
  - no player names, the target is a hash; a shot without a result is dropped
  - with a key (the cloud script) nothing is sent

    pip install lupa
    python3 tests/shot_log.py
"""
import base64
import json
import os
import sys
from urllib.parse import parse_qs, urlparse

import lupa.luajit21 as L

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SERVER = "https://specter-license-mh111-production.up.railway.app"

fails = []


def check(cond, what):
    print(("ok   " if cond else "FAIL ") + what)
    if not cond:
        fails.append(what)


def make(key=""):
    src = open(os.path.join(ROOT, "specter_dev.lua"), encoding="utf-8").read()
    if key:
        src = src.replace('local DEV_KEY        = ""', f'local DEV_KEY        = "{key}"', 1)
        src = src.replace('local DEV_HWID       = ""', 'local DEV_HWID       = "HW1"', 1)
    rt = L.LuaRuntime(unpack_returned_tuples=True)
    mock = rt.eval("function(src) return load(src)() end")(open(os.path.join(HERE, "perf", "mock.lua")).read())
    pending = []

    def from_lua(v):
        if L.lua_type(v) == "table":
            keys = list(v.keys())
            if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
                return [from_lua(v[k]) for k in sorted(keys)]
            return {str(k): from_lua(x) for k, x in v.items()}
        return v

    libs = rt.table_from({
        "gamesense/http": rt.table_from({"get": lambda url, cb: pending.append((url, cb))}),
        "gamesense/base64": rt.table_from({
            "encode": lambda s: base64.b64encode(s.encode()).decode(),
            "decode": lambda s: base64.b64decode(s.encode()).decode(),
        }),
        "json": rt.table_from({"parse": lambda s: None, "stringify": lambda t: json.dumps(from_lua(t))}),
    })
    w = mock.new(src, rt.table_from({"enemies": 2, "seed": 1, "libs": libs}))
    assert w.loaded, w.load_error
    for _ in range(20):
        w.tick()
        w.frame()
    pending.clear()                             # the cloud loadout list asked at load
    return rt, w, pending


def drain(rt, pending):
    """Answers the shot log requests; -> the lines of each batch."""
    batches, cur = [], []
    while pending:
        url, cb = pending.pop(0)
        if "/shotlog?" not in url:
            cb(True, rt.table_from({"status": 200, "body": "[]"}))
            continue
        q = parse_qs(urlparse(url).query)
        cur.append(q)
        cb(True, rt.table_from({"status": 200, "body": '{"ok":true}'}))
        if int(q["idx"][0]) == int(q["total"][0]) - 1:
            data = "".join(p["data"][0] for p in cur)
            ok_parts = [int(p["idx"][0]) for p in cur] == list(range(len(cur))) and len({p["id"][0] for p in cur}) == 1
            batches.append((ok_parts, base64.b64decode(data).decode().split("\n")))
            cur = []
    return batches


def run():
    rt, w, pending = make()
    en = [w.enemies[i] for i in range(1, len(w.enemies) + 1)]
    for i in range(39):
        for _ in range(3):
            w.tick()
        w.shoot(en[i % 2], i % 3 == 0)
    w.fire("aim_fire", rt.table_from({"id": 9999, "target": en[0], "hit_chance": 70, "hitgroup": 1, "damage": 80, "backtrack": 0, "tick": 1}))
    check(not any("/shotlog" in u for u, _ in pending), "39 shots with a result + one without: nothing sent yet")
    w.tick()
    w.shoot(en[0], False)
    batches = drain(rt, pending)
    check(len(batches) == 1 and batches[0][0], f"40 shots: one batch, parts in order ({len(batches)})")
    lines = batches[0][1] if batches else []
    rows = [json.loads(x) for x in lines]
    check(len(rows) == 40, f"40 lines, the shot without a result not among them ({len(rows)})")
    r = rows[0] if rows else {}
    print("   sample:", json.dumps(r)[:400])
    need = ["t", "map", "tr", "ping", "tg", "hc", "hg", "bt", "val", "ctx", "st", "eye", "lby", "r"]
    check(all(k in r for k in need), "a line has the shot, the resolver and the result: missing " + str([k for k in need if k not in r]))
    check(sum(x["r"] == "hit" for x in rows) == 13 and all(x["r"] == "miss" and x["why"] == "?" for x in rows if x["r"] != "hit"),
          "hits and misses with their reason")
    names = [str(w.ents[i].name) for i in en if w.ents[i] and w.ents[i].name]
    text = "\n".join(lines)
    check(all(n not in text for n in names) and len({x["tg"] for x in rows}) == 2, "no player names, the two targets hashed apart")
    check(not list(w.errors.values()) or all("math_floor" in e or "compare number" in e for e in w.errors.values()),
          "no script errors: " + str(list(w.errors.values()))[:300])

    # round end sends what is there
    w.shoot(en[1], True)
    w.fire("round_end", rt.table_from({"winner": 2}))
    batches = drain(rt, pending)
    check(len(batches) == 1 and len(batches[0][1]) == 1, "round end sends the rest")

    # with a key: nothing
    rt, w, pending = make(key="KEY123")
    en = [w.enemies[i] for i in range(1, len(w.enemies) + 1)]
    for i in range(45):
        w.tick()
        w.shoot(en[i % 2], True)
    w.fire("round_end", rt.table_from({"winner": 2}))
    check(not any("/shotlog" in u for u, _ in pending), "with a key (the cloud script) nothing is sent")


run()
print("\nSHOT LOG", "PASSED" if not fails else f"FAILED ({len(fails)})")
sys.exit(1 if fails else 0)
