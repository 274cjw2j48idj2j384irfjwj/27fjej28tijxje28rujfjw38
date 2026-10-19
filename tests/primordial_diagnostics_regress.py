"""LuaJIT tests of the per-shot fault classifier (shotlog.diagnose); no game, no FFI."""
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
    lua.execute('shotlog = {}')
    lua.execute(function('shotlog.num'))
    lua.execute(function('shotlog.diagnose'))
    lua.execute("""
function verdict(row, snap, reason)
    local v, c, d = shotlog.diagnose(row, snap, { reason_string = reason }, false)
    return v, c, d
end
function base_row() return { hc = 80, bt = 2, ping = 40, eye = 100 } end
function base_snap()
    return { candidate = 3, desync = 29, key = "move", misses = 0,
             dg = { fresh = true, age = 0.05, eye = 100, jit = false, jc = 0.1 } }
end
""")
    return lua


class DiagnoseTests(unittest.TestCase):
    def check(self, expected, cls, setup):
        lua = runtime()
        lua.execute('row, snap, reason = base_row(), base_snap(), "resolver"')
        lua.execute(setup)
        verdict, klass, _ = lua.eval('function() return verdict(row, snap, reason) end')()
        self.assertEqual(verdict, expected)
        self.assertEqual(klass, cls)

    def test_hit_has_no_fault(self):
        lua = runtime()
        self.assertEqual(lua.eval('shotlog.diagnose(base_row(), base_snap(), {}, true)'), 'hit')

    def test_lost_attribution_is_reported(self):
        self.check('attr_lost', 'data', 'snap = nil')

    def test_host_reasons_are_data(self):
        self.check('spread', 'data', 'reason = "spread"')
        self.check('occlusion', 'data', 'reason = "occlusion"')
        self.check('death_race', 'data', 'reason = "ping (target death)"')
        self.check('server_reject', 'data', 'reason = "server rejection"')

    def test_low_hitchance_spread_is_an_inference(self):
        self.check('low_hitchance', 'infer', 'reason = "spread"; row.hc = 40')

    def test_enemy_shift_is_not_blamed_on_the_angle(self):
        self.check('enemy_defensive', 'data', 'snap.defensive = true')
        self.check('enemy_lagbreak', 'data', 'snap.lagbreak = true')

    def test_missing_held_and_stale_values_are_data(self):
        self.check('no_value', 'data', 'snap.candidate = nil; snap.vw = "stale"')
        self.check('held_value', 'data', 'snap.vw = "held"; snap.dg.held = 0.4')
        self.check('stale_record', 'data', 'snap.dg.fresh = false; snap.dg.age = 0.3')

    def test_turn_after_fire_is_inferred(self):
        self.check('target_turned', 'infer', 'row.eye = 150')
        self.check('angle_wrong', 'infer', 'row.eye = 110')

    def test_jitter_and_streak_and_latency_causes(self):
        self.check('jitter_side', 'infer', 'snap.kind = "jitter"; snap.dg.jit = true; snap.dg.jc = 0.9')
        self.check('repeat_miss', 'infer', 'snap.misses = 3')
        self.check('old_record', 'infer', 'row.bt = 20')
        self.check('high_latency', 'infer', 'row.ping = 120')

    def test_source_wires_the_logger_after_the_snapshot(self):
        result = function('shotlog.result')
        self.assertIn('pcall(shotlog.diagnose', result)
        self.assertLess(result.index('local snap = resolver.last_result'), result.index('pcall(shotlog.diagnose'))
        self.assertIn('row.dx, row.dxc, row.dxd', result)
        capture = function('resolver.capture')
        self.assertIn('s.dg = dg', capture)
        self.assertIn('pcall(function()', capture)


if __name__ == '__main__':
    unittest.main(verbosity=2)
