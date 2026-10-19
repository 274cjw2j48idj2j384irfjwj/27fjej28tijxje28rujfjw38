"""Real LuaJIT regression tests for reviewed functions, without game/FFI execution."""
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
    lua.execute('''
NOW, TICK = 10, 640
resolver = { K = { ev_margin = 0.05 }, data = {}, previous = {}, shots = {}, misses = {}, epoch = 1 }
builder = { aa_stats = {} }
globals = { real_time = function() return NOW end, tick_count = function() return TICK end }
ui = { antiaim = { builder = { enable = { get = function() return ENABLED ~= false end } } },
       utils = { aa_stats = { get = function() return false end } } }
shotlog = { aa = function() end }
''')
    return lua

class SafetyTests(unittest.TestCase):
    def test_full_file_luajit_syntax(self):
        lua = runtime()
        lua.eval('function(s) assert(loadstring(s, "specter_primordial.lua")); return true end')(SOURCE)

    def test_defensive_window_excludes_later_event(self):
        lua = runtime()
        lua.execute(function('resolver.spoiled'))
        self.assertFalse(lua.eval('resolver.spoiled({ events={{kind="def",obs=10.8,dur=0.2}} },10,0.1,11,"def")'))

    def test_defensive_window_includes_overlapping_event(self):
        lua = runtime()
        lua.execute(function('resolver.spoiled'))
        self.assertTrue(lua.eval('resolver.spoiled({ events={{kind="def",obs=10.1,dur=0.2}} },10,0.1,11,"def")'))
        self.assertFalse(lua.eval('resolver.spoiled({ events={{kind="lc",obs=10.1,dur=0.2}} },10,0.1,11,"def")'))
        self.assertFalse(lua.eval('resolver.spoiled({ events={{kind="def",obs=9.5,dur=0.1}} },10,0.1,11,"def")'))

    def test_capture_uses_original_held_owner(self):
        lua = runtime()
        lua.execute('''
resolver.prune_shots = function() end
resolver.shot_id = function(s) return s.id end
resolver.network = function() return {ping=40} end
resolver.state_of = function() return "move" end
resolver.confidence = function() return 50 end
ENT = { get_index=function() return 2 end, get_hitbox_pos=function() return {} end }
resolver.data[2] = {}
resolver.previous[2] = {key="move",candidate=8,m_flDesync=29,vwhy="held",
 held_context={key="stand",kind="fs",candidate=3,m_flDesync=29,rel=-1,model=17,nxt=1,phase="lby",reliab=0.8}}
''')
        lua.execute(function('resolver.capture'))
        lua.execute('resolver.capture({id=7,player=ENT})')
        self.assertEqual(lua.eval('resolver.shots[1].key'), 'stand')
        self.assertEqual(lua.eval('resolver.shots[1].candidate'), 3)
        self.assertEqual(lua.eval('resolver.shots[1].state'), 'move')
        self.assertEqual(lua.eval('resolver.shots[1].desync'), 29)
        lua.execute('resolver.previous[2].vwhy=nil; resolver.capture({id=8,player=ENT})')
        self.assertEqual(lua.eval('resolver.shots[2].key'), 'move')
        self.assertEqual(lua.eval('resolver.shots[2].candidate'), 8)

    def test_fresh_update_is_not_labeled_held(self):
        lua = runtime()
        lua.execute('''
bit = require("bit")
math.vec_length2d = function() return 0 end
res_custom = function() return false end
res_sign = function(v) return v < 0 and -1 or 1 end
res_norm = function(v) return (v+180)%360-180 end
RES_NOCHOKE, RES_FS_TICKS = 8, 4
RES_STATE_NUM = {stand=1,move=2}
STATE, FRESH = "stand", true
P = {samples=3,nochoke=0,confidence=0,choke=0,fs_tick=640,fs=0,feet_n=1,rec_n=1,feet_steps=6,model=20}
ST = {m_flEyeYaw=10}
resolver.K.idle=2; resolver.K.idle_tau=8
resolver.STATE_PRIOR={}; resolver.MIRROR={}
resolver.animstate=function() return ST end
resolver.track=function() return P end
resolver.state_of=function() return STATE end
resolver.fresh=function() return FRESH end
resolver.profile=function() return {zero=12,rel=0.5,phase="eye"} end
resolver.memory=function() return {candidates={},misses=0} end
resolver.choose=function() return 3 end
resolver.max_desync=function() return 58 end
resolver.hypothesis=function() return 29 end
ui.ragebot={reso_cfg={yaw_calc={get=function() return 3 end}}}
ENT={get_index=function() return 2 end,get_prop=function(_,name)
 if name=="m_vecVelocity" then return {x=0,y=0} end
 if name=="m_fFlags" then return 1 end
end}
''')
        lua.execute(function('resolver.update'))
        lua.execute('resolver.update({},ENT)')
        self.assertIsNone(lua.eval('resolver.previous[2].vwhy'))
        self.assertEqual(lua.eval('resolver.previous[2].held_context.key'), 'stand')
        lua.execute('STATE="move"; FRESH=false; NOW=10.2; resolver.update({},ENT)')
        self.assertEqual(lua.eval('resolver.previous[2].vwhy'), 'held')
        self.assertEqual(lua.eval('resolver.previous[2].held_context.key'), 'stand')

    def test_one_learning_update_per_incoming_snapshot(self):
        lua = runtime()
        lua.execute('''
LEARN_CALLS=0
builder.adv={arm_group=function() return 1 end,brain_learn=function() LEARN_CALLS=LEARN_CALLS+1 end}
builder.brain={}
SNAP={arm_index=2,n=3,name="Move",arm="Delay tied"}
''')
        lua.execute(function('builder.aa_record'))
        lua.execute('builder.aa_record("hit",3,20,nil,SNAP)')
        self.assertEqual(lua.eval('LEARN_CALLS'), 0)
        lua.execute('builder.aa_record("hit",1,80,nil,SNAP); builder.aa_record("hit",1,80,nil,SNAP)')
        self.assertEqual(lua.eval('LEARN_CALLS'), 1)
        self.assertEqual(lua.eval('builder.aa_stats["Move · Delay tied"].hit'), 3)
        lua.execute('SNAP={arm_index=2,n=3,name="Move",arm="Delay tied"}; builder.aa_record("evaded",nil,nil,nil,SNAP); builder.aa_record("evaded",nil,nil,nil,SNAP)')
        self.assertEqual(lua.eval('LEARN_CALLS'), 2)

    def near_miss_runtime(self):
        lua = runtime()
        lua.execute('''
TRIGGERS, RECORDS, hurt_tick = 0,0,-1000
ME={is_player=function() return true end,is_alive=function() return ALIVE~=false end,get_eye_position=function() return {} end}
ENEMY={is_player=function() return true end,is_enemy=function() return true end,get_eye_position=function() return {} end,get_index=function() return 2 end}
LOCAL=ME; SHOOTER=ENEMY
entity_list_get_local_player=function() return LOCAL end
entity_list_get_player_from_userid=function() return SHOOTER end
vec3_t=function() return {} end
builder.miss_claim=function() return 1 end
builder.miss_current=function() return true end
builder.incoming_snapshot=function() return SNAP end
builder.closest_point_on_ray=function() return {dist=function() return 0 end} end
builder.anti_brute_trigger=function() TRIGGERS=TRIGGERS+1 end
builder.aa_record=function() RECORDS=RECORDS+1 end
builder.misses=0; builder.anti_bruteforce={{},{},{}}
client_delay_call=function(fn) DEFERRED=fn end
SNAP={hurt=false,evaded=false}
''')
        lua.execute(function('on_miss'))
        lua.execute('on_miss({userid=9,x=0,y=0,z=0}); NOW=10.15')
        return lua

    def test_valid_near_miss_still_reacts(self):
        lua = self.near_miss_runtime()
        lua.execute('DEFERRED()')
        self.assertEqual(lua.eval('TRIGGERS'),1)
        self.assertEqual(lua.eval('RECORDS'),1)

    def test_delayed_hurt_does_not_trigger_second_reaction(self):
        lua = self.near_miss_runtime()
        lua.execute('SNAP.hurt=true; DEFERRED()')
        self.assertEqual(lua.eval('TRIGGERS'),0)
        self.assertEqual(lua.eval('RECORDS'),0)

    def test_stale_callbacks_do_not_mutate_aa(self):
        for setup in ('ALIVE=false','LOCAL={}','SHOOTER={}','ENABLED=false','NOW=11','NOW=9'):
            with self.subTest(setup=setup):
                lua = self.near_miss_runtime()
                lua.execute(setup+'; DEFERRED()')
                self.assertEqual(lua.eval('TRIGGERS'),0)
                self.assertEqual(lua.eval('RECORDS'),0)

if __name__ == '__main__':
    unittest.main(verbosity=2)
