"""No random numbers in the resolver side of the script; the enemy angle is decided by resolver.update only.

The anti-aim keeps its own random (a predictable anti-aim would be easy to hit); the shot log salt is a privacy salt."""
import re
import sys
import unittest
from pathlib import Path
from lupa.luajit21 import LuaRuntime

SOURCE = Path(sys.argv[1] if len(sys.argv) > 1 else 'specter_primordial.lua').read_text(encoding='utf-8')
sys.argv = [sys.argv[0]]
RANDOM = re.compile(r'math\.random|client_random|random_float|random_int|\.rnd\(')


def function(name):
    start = SOURCE.index(name + ' = function')
    match = re.search(r'\n[A-Za-z_][A-Za-z_0-9.]* = function', SOURCE[start + 1:])
    if not match:
        raise AssertionError('Missing function boundary: ' + name)
    return SOURCE[start:start + 1 + match.start()]


class NoRandomTests(unittest.TestCase):
    def test_resolver_region_has_no_random(self):
        region = SOURCE[SOURCE.index('resolver.animstate = function'):SOURCE.index('local shotlog = {')]
        self.assertEqual(RANDOM.findall(region), [])

    def test_enemy_animation_is_not_written_with_random_values(self):
        body = function('team_animation')
        self.assertEqual(RANDOM.findall(body), [])
        self.assertNotIn('ffi.cast', body)
        self.assertNotIn('m_flGoalFeetYaw', body)

    def test_team_animation_still_exists_and_writes_nothing(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute("""
CALLS = 0
ffi = { cast = function() CALLS = CALLS + 1 return {} end }
resolver = { active = false }
ui = { player = { team_anim = { get = function() return true end } } }
entity_list_get_players = function() return { { is_alive = function() return true end, get_index = function() return 2 end } } end
get_entity_address = function() return 1 end
""")
        lua.execute(function('team_animation'))
        lua.execute('team_animation()')
        self.assertEqual(lua.eval('CALLS'), 0)

    def test_resolver_choice_is_deterministic(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute('resolver = { PRIOR = { 0.14, 0.02, 0.08, 0, -0.03, 0, 0, 0, 0 } }')
        lua.execute(function('resolver.choose'))
        lua.execute("""
function fresh() local m = { candidates = {} } for i = 1, 9 do m.candidates[i] = { good = 1, bad = 1 } end return m end
FIRST = resolver.choose(fresh(), 0.5, true, nil)
SAME = true
for _ = 1, 200 do if resolver.choose(fresh(), 0.5, true, nil) ~= FIRST then SAME = false end end
""")
        self.assertTrue(lua.eval('SAME'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
