"""Remove the random writes into the enemies' animation state (uniquely matched fragment, the rest of the source stays as it is)."""
import argparse
import json
from pathlib import Path
from primordial_safety_patch import tokens, semantic_hash

EDITS = [{'name': 'no_random_animation_writes', 'before': 'team_animation = function()\n    if (resolver.active) then return end\n    if (ui.player.team_anim:get()) then\n        local players = entity_list_get_players()\n        local teams = entity_list_get_players(true)\n        if (players ~= nil and teams ~= nil) then\n            for _, v in pairs(players) do\n                local is_teammate = false\n                for _, teammate in pairs(teams) do\n                    if (v == teammate) then\n                        is_teammate = true\n                        break\n                    end\n                end\n                if (v:is_alive()) then\n                    if (not is_teammate) then\n                        local anim_fix = ffi.cast("CPlayer_animation_State**", ffi.cast("uintptr_t", get_entity_address(v:get_index())) + 0x9960)[0]\n                        anim_fix.m_flGoalFeetYaw = 549\n                        anim_fix.m_flCurrentFeetYaw = -256\n                        anim_fix.m_fDuckAmount = client_random_float(0, 1)\n                        anim_fix.m_flHeadHeightOrOffsetFromHittingGroundanimation = client_random_float(-34.91, 50.6)\n                        anim_fix.m_flPitch = client_random_float(-91, 34)\n                        anim_fix.m_flanimUpdateDelta = client_random_float(-2.758, 3.985)\n                        anim_fix.m_flLeanAmount = client_random_float(-29.15, 51.63)\n                        anim_fix.m_vOriginZ = client_random_float(-8726, 87269)\n                        anim_fix.m_vOriginY = client_random_float(-2154, 21543)\n                        anim_fix.m_vOriginX = client_random_float(-6978, 69781)\n                        anim_fix.m_vvelocity_x = client_random_float(-3410, 34109)\n                        anim_fix.m_vvelocity_y = client_random_float(-9842, 98421)\n                        anim_fix.m_flCurrentTorsoYaw = client_random_float(-789, 654)\n                        anim_fix.m_flFeetYawRate = client_random_float(-987, 876)\n                        anim_fix.m_flFeetCycle = client_random_float(0.194, 0.957)\n                        anim_fix.m_flMagicFraction = client_random_float(-4.456, 7.987)\n                        anim_fix.m_flSpeed2D = client_random_float(-10, 2450)\n                        anim_fix.m_flUpVelocity = client_random_float(-20, 100)\n                        anim_fix.m_flSpeedNormalized = client_random_float(-2.456, 5.789)\n                        anim_fix.m_flFeetSpeedForwardsOrsideWays = client_random_float(-30, 80)\n                        anim_fix.m_flFeetSpeedUnknownForwardOrsideways = client_random_float(-40, 60)\n                    end\n                end\n            end\n        else\n            return\n        end\n    else\n        return\n    end\nend', 'after': 'team_animation = function()\n    -- the old version wrote RANDOM numbers into the animation state of every enemy (a random "resolver" that fought the real one,\n    -- some of the values are far outside what the game allows). The angle of an enemy is decided by resolver.update only: nothing\n    -- is written here any more\n    return\nend'}]


def matches(stream, needle):
    size = len(needle)
    return [i for i, token in enumerate(stream) if token == needle[0] and stream[i:i + size] == needle]


def build_patch(text):
    stream = tokens(text)
    values = [item[0] for item in stream]
    changes, occupied = [], []
    for edit in EDITS:
        before = [item[0] for item in tokens(edit['before'])]
        after = [item[0] for item in tokens(edit['after'])]
        old, new = matches(values, before), matches(values, after)
        if len(new) == 1:
            start, stop = new[0], new[0] + len(after)
            if any(not (start <= i and i + len(before) <= stop) for i in old):
                raise ValueError('Old and patched copies coexist: ' + edit['name'])
            occupied.append((start, stop))
            continue
        if new or len(old) != 1:
            raise ValueError('Expected one unchanged or one patched fragment: ' + edit['name'] + ' (old %d, new %d)' % (len(old), len(new)))
        start, stop = old[0], old[0] + len(before)
        occupied.append((start, stop))
        changes.append((stream[start][1], stream[stop - 1][2], edit['after'], edit['name']))
    occupied.sort()
    if any(a[1] > b[0] for a, b in zip(occupied, occupied[1:])):
        raise ValueError('Overlapping edit regions')
    result = text
    for start, stop, replacement, _ in sorted(changes, reverse=True):
        result = result[:start] + replacement + result[stop:]
    final = [item[0] for item in tokens(result)]
    for edit in EDITS:
        after = [item[0] for item in tokens(edit['after'])]
        if len(matches(final, after)) != 1:
            raise ValueError('Final fragment verification failed: ' + edit['name'])
    return result, [change[3] for change in sorted(changes)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', default='specter_primordial.lua')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    path = Path(args.source)
    original = path.read_bytes().decode('utf-8')
    updated, edits = build_patch(original)
    if args.apply and edits:
        path.write_bytes(updated.encode('utf-8'))
    print(json.dumps({'applied': bool(args.apply and edits), 'edits': edits,
                      'before': semantic_hash(original), 'after': semantic_hash(updated)}))


if __name__ == '__main__':
    main()
