"""specter_loader.lua in a mock gamesense: the Paste key button / spec_key with the workshop clipboard, the vgui2 fallback
(a fake VGUI_System010 vtable), no clipboard at all, then Register with the pasted key.
gamesense textboxes take no Ctrl+V, so the key gets in through the button (or the console command).

    pip install lupa
    python3 tests/loader_paste.py [path to the loader]
"""
import os
import sys
import lupa.luajit21 as L

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = open(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "specter_loader.lua"), encoding="utf-8").read()
MOCK = r'''
return function(src, mode, clip)
  local ffi = require("ffi")
  local W = { logs = {}, gets = {}, els = {}, cb = {} }
  local function el(kind, name, val)
    local e = { kind = kind, name = name, v = val, enabled = true }
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
    panorama = { open = function() return { MyPersonaAPI = { GetXuid = function() return "76561198000000001" end } } end },
    entity = { get_local_player = function() return nil end },
    require = function(n)
      if n == "gamesense/http" then return { get = function(url) W.gets[#W.gets + 1] = url end } end
      if n == "json" then return { parse = function() return {} end } end
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
  function W.status() W.cb.paint_ui()
    for _, e in ipairs(W.els) do if e.kind == "label" and tostring(e.name):find("Ready.", 1, true) then return e.v end end end
  return W
end
'''
KEY = "AbC123-def456-GHI789-jkl012"
fails = []

def world(mode, clip):
    rt = L.LuaRuntime(unpack_returned_tuples=True)
    return rt.execute(MOCK)(SRC, mode, clip)

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
print("FAILED: " + ", ".join(fails) if fails else "ALL OK")
sys.exit(1 if fails else 0)
