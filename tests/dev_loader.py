"""Tests for specter_dev_loader.lua (the login-free loader for the owners): download order, fallbacks, cache.

    pip install lupa
    python3 tests/dev_loader.py

The real http / file functions are replaced by fakes, the "script" is a small lua chunk. Exit code is non-zero on failure.
"""
import os
import sys

import lupa.luajit21 as L

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = open(os.path.join(ROOT, "specter_dev_loader.lua"), encoding="utf-8").read()
PAD = "-- padding\n" * 300
GOOD = "RAN = (RAN or 0) + 1\nWHICH = '%s'\n" + PAD

rt = L.LuaRuntime(unpack_returned_tuples=True)
RUN = rt.eval("""function(src, replies, files, with_http)
    local env = { logs = {}, requests = {}, files = files, ran = 0 }
    local g = setmetatable({}, { __index = _G })
    g.client = { color_log = function(r, gg, b, m) env.logs[#env.logs + 1] = m end, unix_time = function() return 1000 end }
    g.readfile = function(name) return env.files[name] end
    g.writefile = function(name, body) env.files[name] = body end
    g.require = function(name)
        if name == "gamesense/http" and with_http then
            return { get = function(url, opts, cb)
                env.requests[#env.requests + 1] = url
                local r = replies[#env.requests]
                if r == nil or r == false then cb(false, nil) else cb(true, { status = r.status, body = r.body }) end
            end }
        end
        error("module '" .. name .. "' not found")
    end
    local f = assert(loadstring(src, "@loader"))
    setfenv(f, g)
    f()
    env.G = g
    return env
end""")

fails = []


def check(cond, msg):
    if not cond:
        fails.append(msg)
        print("FAIL:", msg)


def go(replies, files=None, with_http=True):
    rep = rt.table_from([None if r is None else (False if r is False else rt.table_from(r)) for r in replies])
    fl = rt.table_from(files or {})
    return RUN(SRC, rep, fl, with_http)


def logs(env):
    return " | ".join(env.logs.values())


# 1) main answers: used, saved, the other source is never asked
e = go([dict(status=200, body=GOOD % "main")])
check(len(list(e.requests.values())) == 1, "main first, only one request when it works")
check("raw.githubusercontent.com/274cjw2j48idj2j384irfjwj/27fjej28tijxje28rujfjw38/main/specter_dev.lua?t=1000" in e.requests[1], "first url is main with a cache buster")
check(e.G.WHICH == "main" and e.G.RAN == 1, "the script from main ran once")
check(e.files["specter_dev_cache.lua"] is not None, "the downloaded script is saved")

# 2) main is 404 (the file is not merged yet): the branch is used
e = go([dict(status=404, body="404: Not Found"), dict(status=200, body=GOOD % "branch")])
check(len(list(e.requests.values())) == 2 and e.G.WHICH == "branch", "404 on main falls back to the branch")

# 3) an error page with status 200 is not a script
e = go([dict(status=200, body="<html>rate limited</html>" + PAD), dict(status=200, body=GOOD % "branch")])
check(e.G.WHICH == "branch", "an html page is skipped")

# 4) a broken script (does not compile) is skipped
e = go([dict(status=200, body="this is not lua !!!" + PAD), dict(status=200, body=GOOD % "branch")])
check(e.G.WHICH == "branch", "a script that does not compile is skipped")

# 5) offline: the saved copy
e = go([False, False], files={"specter_dev_cache.lua": GOOD % "cache"})
check(e.G.WHICH == "cache" and "saved copy" in logs(e), "offline: the saved copy runs and says so")

# 6) offline and nothing saved: a message, no error
e = go([False, False])
check("no saved copy" in logs(e), "offline without a saved copy says what to check")

# 7) no http library: the saved copy
e = go([], files={"specter_dev_cache.lua": GOOD % "cache"}, with_http=False)
check(e.G.WHICH == "cache" and "not installed" in logs(e), "no gamesense/http: the saved copy")

# 8) the downloaded script throws: reported, the loader itself does not
e = go([dict(status=200, body="error('boom')\n" + PAD)])
check("boom" in logs(e), "an error inside the script is reported, not thrown")

# 9) a bad saved copy does not throw either
e = go([False, False], files={"specter_dev_cache.lua": "garbage ((("})
check("saved copy failed" in logs(e), "a broken saved copy is reported")

print("ALL CHECKS PASSED" if not fails else f"{len(fails)} CHECK(S) FAILED")
sys.exit(1 if fails else 0)
