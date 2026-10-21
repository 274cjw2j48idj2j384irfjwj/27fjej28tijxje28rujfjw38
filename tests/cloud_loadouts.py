"""Cloud loadouts in the Loadouts list (the dev build in the mock game of tests/perf/mock.lua, http answered here):

  - at load the list asks the server and shows the shared ones after the own ones: "☁ name  by user"
  - a cloud row selected: Load imports it, Export copies it, Delete asks the server (only the own ones go)
  - Share uploads the loadout named in the box in parts with the key + HWID, then the list is asked again
  - without a key Share / Delete only say so; garbage from the server changes nothing

    pip install lupa
    python3 tests/cloud_loadouts.py
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
    assert f'local DEV_SERVER_URL = "{SERVER}"' in src
    if key:
        src = src.replace('local DEV_KEY        = ""', f'local DEV_KEY        = "{key}"', 1)
        src = src.replace('local DEV_HWID       = ""', 'local DEV_HWID       = "HW1"', 1)
    rt = L.LuaRuntime(unpack_returned_tuples=True)
    mock = rt.eval("function(src) return load(src)() end")(open(os.path.join(HERE, "perf", "mock.lua")).read())
    pending, clip = [], {"v": ""}

    def to_lua(v):
        if isinstance(v, dict):
            return rt.table_from({k: to_lua(x) for k, x in v.items()})
        if isinstance(v, list):
            return rt.table_from([to_lua(x) for x in v])
        return v

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
        "gamesense/clipboard": rt.table_from({"get": lambda: clip["v"], "set": lambda s: clip.update(v=s)}),
        "json": rt.table_from({
            "parse": lambda s: to_lua(json.loads(s)),
            "stringify": lambda t: json.dumps(from_lua(t)),
        }),
    })
    w = mock.new(src, rt.table_from({"enemies": 1, "seed": 1, "libs": libs}))
    assert w.loaded, w.load_error
    for _ in range(10):
        w.tick()
        w.frame()
    return rt, w, pending, clip


def item(w, name):
    for i, it in w["items"].items():
        if it.name == name:
            return i, it
    raise KeyError(name)


def status(w):
    for _, it in w["items"].items():
        if it.kind == "label" and "shared loadouts" in str(it.name):
            return str(it.value)
    raise KeyError("status")


def answer(rt, pending, body, ok=True):
    url, cb = pending.pop(0)
    cb(ok, rt.table_from({"status": 200, "body": body}))
    return url


def shared(name, author, data):
    return {"name": name, "author": author, "data": base64.b64encode(data.encode()).decode(), "plan": "debug", "ts": 1}


def run():
    rt, w, pending, clip = make()
    lb, lst = item(w, "\nloadouts_list")
    check(len(pending) == 1 and pending[0][0] == SERVER + "/configs", "at load the list asks the server for the shared loadouts")

    # a real config: the one the script exports now (the Export of the full config puts it on the clipboard)
    w.ui.set(item(w, "Export to clipboard")[0], True)
    cfg = clip["v"]
    check(cfg.endswith("_Specter"), "the full config export works in the mock")

    # one own loadout, then the server answers with two shared ones (+ garbage)
    w.ui.set(item(w, "\nloadout_name")[0], "mine")
    w.ui.set(item(w, "Create\nloadout")[0], True)
    answer(rt, pending, json.dumps([shared("old", "bob", cfg), {"name": 5}, "x", shared("Distort hvh\n", "peter", cfg)]))
    names = list(lst.list.values())
    check(names == ["mine", "☁ Distort hvh  by peter", "☁ old  by bob"], f"own first, then the shared ones newest first: {names}")
    check("2 shared" in status(w), "status says how many are shared: " + status(w))

    # select the cloud row and load it
    w.ui.set(lb, 1)
    check(w["items"][item(w, "\nloadout_name")[0]].value == "Distort hvh", "selecting a cloud row puts its name in the box")
    w.ui.set(item(w, "Load\nloadout")[0], True)
    # a console line is several color_log calls (one per colour, "\0" = the line goes on): join them like the console
    console = "".join(str(m) for m in w.logs.values()).replace("\0", "")
    check("Cloud loadout \"Distort hvh\" by peter loaded" in console, "Load imports the cloud loadout")
    check(not list(w.errors.values()) or all("math_floor" in e or "compare number" in e for e in w.errors.values()),
          "no script errors: " + str(list(w.errors.values()))[:200])

    clip["v"] = ""
    w.ui.set(item(w, "Export\nloadout")[0], True)
    check(clip["v"] == cfg, "Export copies the cloud loadout's config")

    # no key = the dev build (owners, Oct 2026: "dev can upload to cloud too"): share / delete go out as dev=1 + who, no key
    w.ui.set(item(w, "Delete\nloadout")[0], True)
    dq = parse_qs(urlparse(pending[0][0]).query) if pending else {}
    check(len(pending) == 1 and "/configs/delete" in pending[0][0] and dq.get("dev") == ["1"] and "who" in dq and "key" not in dq and "hwid" not in dq,
          "Delete without a key goes out as dev: " + str(pending[0][0] if pending else status(w)))
    answer(rt, pending, json.dumps({"ok": False, "reason": "not_found"}))
    w.ui.set(lb, 0)
    w.ui.set(item(w, "☁ Share to cloud")[0], True)
    sent = []
    while pending and "/configs/upload_part" in pending[0][0]:
        sent.append(parse_qs(urlparse(pending[0][0]).query))
        answer(rt, pending, json.dumps({"ok": True}))
    check(len(sent) >= 1 and all(q.get("dev") == ["1"] and "who" in q and "key" not in q and "hwid" not in q for q in sent),
          f"Share without a key goes out as dev in {len(sent)} part(s)")
    while pending:
        answer(rt, pending, json.dumps([]))
    check([n for n in lst.list.values()][0] == "mine", "the own loadout is still first")

    # with a key
    rt, w, pending, clip = make(key="KEY123")
    lb, lst = item(w, "\nloadouts_list")
    answer(rt, pending, "not json")
    check("unreachable" in status(w) and list(lst.list.values())[0].startswith("No loadouts yet"), "garbage answer: nothing listed")
    w.ui.set(item(w, "\nloadout_name")[0], "my hvh")
    w.ui.set(item(w, "Create\nloadout")[0], True)
    w.ui.set(item(w, "☁ Share to cloud")[0], True)
    sent = []
    while pending and "/configs/upload_part" in pending[0][0]:
        q = parse_qs(urlparse(pending[0][0]).query)
        sent.append(q)
        answer(rt, pending, json.dumps({"ok": True}))
    check(len(sent) >= 1 and all(q["key"] == ["KEY123"] and q["hwid"] == ["HW1"] and q["name"] == ["my hvh"] for q in sent),
          f"Share uploads in {len(sent)} part(s) with key, hwid and name")
    check([int(q["idx"][0]) for q in sent] == list(range(len(sent))) and all(q["total"] == [str(len(sent))] for q in sent), "parts in order")
    data = "".join(q["data"][0] for q in sent)
    check(base64.b64decode(data).decode().endswith("_Specter"), "the shared data is the loadout's export string")
    check(pending and pending[0][0] == SERVER + "/configs", "after sharing the list is asked again")
    answer(rt, pending, json.dumps([shared("my hvh", "user-1a2b3c", base64.b64decode(data).decode())]))
    check(list(lst.list.values()) == ["my hvh", "☁ my hvh  by user-1a2b3c"], "the shared one is in the list: " + str(list(lst.list.values())))

    # delete: someone else's -> the server says not_found
    w.ui.set(lb, 1)
    w.ui.set(item(w, "Delete\nloadout")[0], True)
    url = answer(rt, pending, json.dumps({"ok": False, "reason": "not_found"}))
    check("/configs/delete" in url and "only delete your own" in status(w), "Delete of someone else's: " + status(w))
    check(list(lst.list.values())[0] == "my hvh", "the own local loadout stays")
    w.ui.set(lb, 1)
    w.ui.set(item(w, "Delete\nloadout")[0], True)
    answer(rt, pending, json.dumps({"ok": True}))
    answer(rt, pending, json.dumps([]))
    check(list(lst.list.values()) == ["my hvh"], "deleted from the cloud, the local one stays")
    # a server error while sharing
    w.ui.set(lb, 0)
    w.ui.set(item(w, "☁ Share to cloud")[0], True)
    answer(rt, pending, json.dumps({"ok": False, "reason": "hwid_mismatch"}))
    check(not pending and "hwid_mismatch" in status(w), "a refused share stops: " + status(w))


run()
print("\nCLOUD LOADOUTS", "PASSED" if not fails else f"FAILED ({len(fails)})")
sys.exit(1 if fails else 0)
