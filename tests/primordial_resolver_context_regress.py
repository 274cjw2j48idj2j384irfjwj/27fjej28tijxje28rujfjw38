"""LuaJIT tests of the resolver context fixes: confidence of the decision, jitter memory per state, animation layers in the shot; no game, no FFI."""
import re
import sys
import unittest
from pathlib import Path
from lupa.luajit21 import LuaRuntime

SOURCE = Path(sys.argv[1] if len(sys.argv) > 1 else 'specter_primordial.lua').read_text(encoding='utf-8')
sys.argv = [sys.argv[0]]


def function(name):
    start = SOURCE.index(name + ' = function')
    match = re.search(r'\n[A-Za-z_][A-Za-z_0-9.]* = function', SOURCE[start + 1:])
    if not match:
        raise AssertionError('Missing function boundary: ' + name)
    return SOURCE[start:start + 1 + match.start()]


def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('resolver = { mem = {}, previous = {}, NCAND = 9 }')
    lua.execute(function('resolver.slot'))
    lua.execute(function('resolver.confidence'))
    lua.execute(function('resolver.memory').split('\nresolver.NCAND')[0])
    return lua


class ResolverContextTests(unittest.TestCase):
    def test_jitter_slot_is_per_state(self):
        lua = runtime()
        self.assertEqual(lua.eval('resolver.slot("jitter", "jitter", "move")'), 'jitter@move')
        self.assertEqual(lua.eval('resolver.slot("move", nil, "move")'), 'move')
        self.assertEqual(lua.eval('resolver.slot("jitter", "jitter", nil)'), 'jitter')
        self.assertEqual(lua.eval('resolver.slot("move fs", "fs", "move")'), 'move fs')

    def test_memory_keeps_states_apart_and_old_calls_work(self):
        lua = runtime()
        lua.execute('a = resolver.memory(2, "jitter", "jitter", "move")')
        lua.execute('b = resolver.memory(2, "jitter", "jitter", "air")')
        lua.execute('c = resolver.memory(2, "jitter", "jitter", "move")')
        lua.execute('d = resolver.memory(2, "jitter", "jitter")')
        lua.execute('e = resolver.memory(2, "stand")')
        self.assertTrue(lua.eval('a ~= b and a == c and d ~= a and d ~= b'))
        self.assertTrue(lua.eval('resolver.mem[2]["jitter@move"] == a and resolver.mem[2]["jitter"] == d and resolver.mem[2].stand == e'))
        self.assertEqual(lua.eval('#a.candidates'), 9)

    def test_confidence_follows_the_decision_not_the_current_state(self):
        lua = runtime()
        lua.execute("""
resolver.mem[2] = {
    stand = { candidates = { { good = 9, bad = 1 } }, selected = 1 },
    move = { candidates = { { good = 1, bad = 9 } }, selected = 1 },
}
resolver.previous[2] = { key = "move", state = "move", candidate = 1 }
""")
        self.assertAlmostEqual(lua.eval('resolver.confidence(2)'), 10, places=6)
        lua.execute('resolver.previous[2].vwhy = "held"')
        lua.execute('resolver.previous[2].held_context = { key = "stand", state = "stand", candidate = 1 }')
        self.assertAlmostEqual(lua.eval('resolver.confidence(2)'), 90, places=6)
        lua.execute('resolver.previous[2].vwhy = nil')
        self.assertAlmostEqual(lua.eval('resolver.confidence(2)'), 10, places=6)

    def test_jitter_confidence_reads_the_state_slot(self):
        lua = runtime()
        lua.execute("""
resolver.mem[2] = {
    ["jitter@move"] = { candidates = { { good = 3, bad = 1 } }, selected = 1 },
    jitter = { candidates = { { good = 1, bad = 3 } }, selected = 1 },
}
resolver.previous[2] = { key = "jitter", kind = "jitter", state = "move", candidate = 1 }
""")
        self.assertAlmostEqual(lua.eval('resolver.confidence(2)'), 75, places=6)
        lua.execute('resolver.previous[2].state = "air"')
        self.assertIsNone(lua.eval('resolver.confidence(2)'))

    def test_result_trains_the_slot_of_the_decision(self):
        lua = runtime()
        lua.execute("""
res_clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end
NOW = 10
globals = { real_time = function() return NOW end }
ui = { ragebot = { learn_rate = { get = function() return 100 end } } }
resolver.K = { forget = 0.97 }
resolver.data, resolver.misses = {}, {}
TRACK = {}
resolver.data[2] = TRACK
resolver.take_shot = function() return { idx = 2, track = TRACK, key = "jitter", kind = "jitter", candidate = 1,
    dstate = "air", state = "move", time = 9.9, rtt = 0.05 } end
resolver.spoiled = function() return false end
resolver.record = function() end
TARGET = { get_index = function() return 2 end }
""")
        lua.execute(function('resolver.on_result'))
        lua.execute('resolver.on_result(TARGET, true, false, {}, nil)')
        self.assertEqual(lua.eval('resolver.mem[2]["jitter@air"].candidates[1].good'), 2)
        self.assertIsNone(lua.eval('resolver.mem[2]["jitter@move"]'))

    def capture_runtime(self):
        lua = runtime()
        lua.execute("""
NOW = 10
globals = { real_time = function() return NOW end }
resolver.shots, resolver.misses, resolver.data, resolver.epoch = {}, {}, {}, 1
resolver.prune_shots = function() end
resolver.shot_id = function(s) return s.id end
resolver.network = function() return { ping = 40 } end
resolver.state_of = function() return "move" end
resolver.fresh = function() return true end
resolver.confidence = function() return 50 end
get_entity_address = function() return 1 end
get_anim_layer = function(address, i)
    return { m_flWeight = (i == 3 or i == 6) and 0.5 or 0, m_nSequence = i * 10, m_flCycle = 0.25, m_flPlaybackRate = 1.0 }
end
ENT = { get_index = function() return 2 end, get_hitbox_pos = function() return {} end,
        get_prop = function() return 100 end }
resolver.data[2] = { updated = 9.95, samples = 3, nochoke = 0, choke = 0, jitter = false, confidence = 0 }
resolver.previous[2] = { key = "move", state = "move", candidate = 3, m_flDesync = 29 }
""")
        lua.execute(function('resolver.capture'))
        return lua

    def test_layers_are_logged_at_fire(self):
        lua = self.capture_runtime()
        lua.execute('resolver.capture({ id = 7, player = ENT })')
        self.assertEqual(lua.eval('resolver.shots[1].ly'), '3:30:0.50:0.25:1.000;6:60:0.50:0.25:1.000')
        self.assertEqual(lua.eval('resolver.shots[1].dstate'), 'move')

    def test_held_shot_keeps_the_state_of_its_decision(self):
        lua = self.capture_runtime()
        lua.execute('resolver.previous[2].vwhy = "held"')
        lua.execute('resolver.previous[2].held_context = { key = "stand", kind = nil, state = "stand", candidate = 5, m_flDesync = 12 }')
        lua.execute('resolver.capture({ id = 9, player = ENT })')
        self.assertEqual(lua.eval('resolver.shots[1].dstate'), 'stand')
        self.assertEqual(lua.eval('resolver.shots[1].key'), 'stand')
        self.assertEqual(lua.eval('resolver.shots[1].candidate'), 5)

    def test_a_failing_layer_read_does_not_break_the_shot(self):
        lua = self.capture_runtime()
        lua.execute('get_anim_layer = function() error("bad layer") end')
        lua.execute('resolver.capture({ id = 8, player = ENT })')
        self.assertEqual(lua.eval('#resolver.shots'), 1)
        self.assertIsNone(lua.eval('resolver.shots[1].ly'))

    def test_callers_and_log_are_wired(self):
        update = function('resolver.update')
        self.assertIn('resolver.memory(idx, key, kind, state)', update)
        self.assertIn('state = state,', update)
        self.assertIn('snapshot.dstate or snapshot.state', function('resolver.on_result'))
        self.assertIn('row.ly = snap.ly', function('shotlog.result'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
