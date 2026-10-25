"""specter_loader.lua in a mock gamesense (menu, clipboard, http answered by a fake license server):

  - the Paste key button / spec_key with the workshop clipboard, the vgui2 fallback (a fake VGUI_System010 vtable), no
    clipboard at all (gamesense textboxes take no Ctrl+V, so the key gets in through the button or the console command)
  - Register with the pasted key, the script runs, then every item of the login menu is hidden (the script's own menu is in
    the same tabs); a wrong key keeps the menu; two clicks while the download runs start the script once

    pip install lupa
    python3 tests/loader_menu.py [path to the loader]
"""
import os
import sys
import lupa.luajit21 as L

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = open(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "specter_loader.lua"), encoding="utf-8").read()
MOCK = r'''
return function(src, mode, clip)
  local ffi = require("ffi")
  local W = { logs = {}, gets = {}, pending = {}, els = {}, cb = {}, drawn = {} }
  local function el(kind, name, val)
    local e = { kind = kind, name = name, v = val, enabled = true, visible = true }
    function e:set_visible(b) self.visible = b end
    function e:get() return self.v end
    function e:set(v) self.v = v end
    function e:set_callback(f) self.cb = f end
    function e:set_enabled(b) self.enabled = b end
    W.els[#W.els + 1] = e
    return e
  end
  local group = {}
  function group:label(t) return el("label", t, t) end
  function group:textbox(n, v) return el("textbox", n, v or "") end
  function group:button(n) return el("button", n) end
  local pui = { macros = {}, group = function() return setmetatable({}, { __index = group }) end }
  local keep = {}
  local env = setmetatable({
    client = {
      color_log = function(r, g, b, m) W.logs[#W.logs + 1] = m end,
      set_event_callback = function(n, f) W.cb[n] = f end,
      unset_event_callback = function(n, f) if W.cb[n] == f then W.cb[n] = nil end end,
      screen_size = function() return 1920, 1080 end,
      create_interface = function(mod, name)
        if mode ~= "vgui" or mod ~= "vgui2.dll" or name ~= "VGUI_System010" then return nil end
        local text = clip
        local count = ffi.cast("int(*)(void*)", function() return text and #text + 1 or 0 end)
        local read = ffi.cast("int(*)(void*, int, char*, int)", function(_, _, buf, size)
          ffi.copy(buf, text, math.min(#text, size - 1)); return 0 end)
        local vt = ffi.new("void*[12]")
        vt[7], vt[11] = ffi.cast("void*", count), ffi.cast("void*", read)
        local obj = ffi.new("void*[1]"); obj[0] = vt
        keep[#keep + 1] = { count, read, vt, obj }
        return ffi.cast("void*", obj)
      end,
    },
    database = { read = function() return nil end, write = function() end },
    globals = { realtime = function() return W.t or 0 end },
    renderer = { text = function(...) local t = { ... } W.drawn[#W.drawn + 1] = t[#t] end },
    panorama = { open = function() return { MyPersonaAPI = { GetXuid = function() return "76561198000000001" end } } end },
    entity = { get_local_player = function() return nil end },
    require = function(n)
      if n == "gamesense/http" then return { get = function(url, cb)
        W.gets[#W.gets + 1] = url; W.pending[#W.pending + 1] = { url = url, cb = cb } end } end
      if n == "json" then return { parse = function(b)
        if b == "VERIFY" then return { valid = true, plan = "nightly", ticket = "t", nonce = "n", loader_gs = 1 } end
        if b == "VERIFY_OLD" then return { valid = true, plan = "nightly", ticket = "t", nonce = "n", loader_gs = 9 } end
        if b == "VERIFY_PM" then return { valid = true, plan = "pm_nightly", lua = "primordial", ticket = "t", nonce = "n", loader_gs = 1 } end
        if b == "VERIFY_BOTH" then return { valid = true, plan = "nightly", lua = "gamesense", discord_linked = true, ticket = "t", nonce = "n", loader_gs = 1,
          access = { { lua = "gamesense", plan = "nightly" }, { lua = "primordial", plan = "pm_beta" } } } end
        if b == "VERIFY_UNLINKED" then return { valid = true, plan = "nightly", lua = "gamesense", discord_linked = false, ticket = "t", nonce = "n", loader_gs = 1,
          access = { { lua = "gamesense", plan = "nightly" } } } end
        if b == "BAD" then return { valid = false, reason = "invalid_key" } end
        return {} end } end
      if n == "gamesense/pui" then return pui end
      if n == "ffi" then return ffi end
      if n == "gamesense/clipboard" then
        if mode == "lib" then return { get = function() return clip end } end
        error("module not found")
      end
      error("no " .. n)
    end,
  }, { __index = _G })
  local fn = assert(load(src, "@loader", "t", env))
  fn()
  function W.button(name) for _, e in ipairs(W.els) do if e.kind == "button" and e.name == name then return e.cb() end end end
  function W.box(name) for _, e in ipairs(W.els) do if e.kind == "textbox" and e.name == name then return e end end end
  -- the fake license server answers every request in order (the verify answer given, then the script)
  function W.answer(verify)
    while #W.pending > 0 do
      local r = table.remove(W.pending, 1)
      if r.url:find("/verify?", 1, true) then r.cb(true, { status = 200, body = verify })
      else r.cb(true, { status = 200, body = "SPECTER_TEST_RAN = (SPECTER_TEST_RAN or 0) + 1\n--" .. ("x"):rep(300) }) end
    end
  end
  function W.hidden()
    local n = 0
    for _, e in ipairs(W.els) do if not e.visible then n = n + 1 end end
    return n, #W.els
  end
  function W.status() W.cb.paint_ui()
    for _, e in ipairs(W.els) do if e.kind == "label" and tostring(e.name):find("Ready.", 1, true) then return e.v end end end
  return W
end
'''
KEY = "AbC123-def456-GHI789-jkl012"
fails = []

def world(mode, clip, rt_out=None):
    rt = L.LuaRuntime(unpack_returned_tuples=True)
    if rt_out is not None:
        rt_out.append(rt)
    return rt.execute(MOCK)(SRC, mode, clip)


def login(verify, clicks=1):
    """Register with a key, the server answers: (the world, how often the script ran)"""
    rts = []
    w = world("none", None, rts)
    w.box("\nKey").v = KEY
    w.box("\nUsername").v = "tester"
    w.box("\nPassword").v = "secret1"
    for _ in range(clicks):
        w.button("Register")
    w.answer(verify)
    for _ in range(3):
        w.cb.paint_ui()
    return w, rts[0].globals().SPECTER_TEST_RAN or 0

def check(name, cond, extra=""):
    print(f"  {'ok  ' if cond else 'FAIL'} {name} {extra}")
    if not cond:
        fails.append(name)

for mode in ("lib", "vgui"):
    w = world(mode, "Your Specter key:\n```" + KEY + "```\nNever share it.")
    w.button("Paste key")
    check(f"{mode}: key from a Discord message", w.box("\nKey").v == KEY, repr(w.box("\nKey").v))
    w = world(mode, "  oldstylekey99 \r\n")
    w.button("Paste key")
    check(f"{mode}: key with spaces / new line", w.box("\nKey").v == "oldstylekey99", repr(w.box("\nKey").v))
    w = world(mode, "")
    w.button("Paste key")
    check(f"{mode}: empty clipboard", w.box("\nKey").v == "" and any("No key in the clipboard" in str(l) for l in w.logs.values()))

w = world("none", None)
w.button("Paste key")
check("no clipboard: tells to use spec_key", "spec_key" in str(w.status()), repr(w.status()))
r = w.cb.console_input("spec_key  `" + KEY + "` ")
check("spec_key <key>", r is True and w.box("\nKey").v == KEY, repr(w.box("\nKey").v))
w.box("\nUsername").v = "tester"
w.box("\nPassword").v = "secret1"
w.button("Register")
check("Register sends the pasted key", len(w.gets) == 1 and ("key=" + KEY) in w.gets[1], w.gets[1] if len(w.gets) else "no request")
check("other console input untouched", w.cb.console_input("say hi") is None)

w, ran = login("VERIFY")
hidden, total = w.hidden()
check("loaded: the script ran", ran == 1, f"ran {ran}x")
check("loaded: the whole login menu is hidden", hidden == total and total > 20, f"{hidden} / {total} hidden")
check("loaded: spec_plan still answers", w.cb.console_input("spec_plan") is True and "Plan: nightly" in str(w.logs[len(w.logs)]))
notice = [l for l in w.logs.values() if "new Specter loader" in str(l)]
check("loader up to date: no update notice", not notice and w.cb.paint is None, notice)
w, ran = login("VERIFY_OLD")
notice = [l for l in w.logs.values() if "new Specter loader" in str(l)]
w.cb.paint()
drawn = len(w.drawn)
w.t = 13
w.cb.paint()
check("older loader: console + on screen notice for 12 s, the script still loads",
      ran == 1 and len(notice) == 1 and "/download" in str(notice[0]) and drawn == 1 and w.cb.paint is None,
      (ran, notice, drawn))
w, ran = login("BAD")
hidden, total = w.hidden()
check("wrong key: the menu stays", ran == 0 and hidden == 0 and "Invalid license key" in str(w.status()), f"{hidden} hidden")
w, ran = login("VERIFY_PM")
check("a Primordial key is refused by the gamesense loader", ran == 0 and "Primordial" in str(w.status()), (ran, w.status()))
w, ran = login("VERIFY_BOTH")
listed = [l for l in w.logs.values() if "Gamesense + Primordial" in str(l)]
warned = [l for l in w.logs.values() if "/register" in str(l)]
check("the loader lists the Luas the account unlocks", ran == 1 and len(listed) == 1 and not warned, (ran, listed, warned))
w, ran = login("VERIFY_UNLINKED")
warned = [l for l in w.logs.values() if "/register" in str(l)]
check("a key with no Discord account is told to /register", ran == 1 and len(warned) == 1, (ran, warned))
w, ran = login("VERIFY", clicks=2)
check("two clicks while downloading: the script runs once", ran == 1, f"ran {ran}x")
print("FAILED: " + ", ".join(fails) if fails else "ALL OK")
sys.exit(1 if fails else 0)
