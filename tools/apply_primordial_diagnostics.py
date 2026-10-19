"""Add the per-shot fault logger to specter_primordial.lua (uniquely matched fragments, rest of the source untouched)."""
import argparse
import json
from pathlib import Path
from primordial_safety_patch import tokens, semantic_hash

EDITS = [{'name': 'fire_time_diagnostics', 'before': '    s.misses = resolver.misses[idx] or 0', 'after': '    s.misses = resolver.misses[idx] or 0\n    -- fire-time facts for the per-shot diagnosis (shotlog.diagnose): age of the newest record, jitter state, eye yaw at fire\n    local okd, dg = pcall(function()\n        local now_t = globals.real_time()\n        local pv = resolver.previous[idx]\n        return {\n            age = p and p.updated and now_t - p.updated or nil,\n            fresh = resolver.fresh(p) and true or false,\n            smp = p and p.samples or nil, nc = p and p.nochoke or nil, ck = p and p.choke or nil,\n            jit = p and p.jitter and true or false, jc = p and p.confidence or nil,\n            eye = tonumber(shot.player:get_prop("m_angEyeAngles[1]")),\n            held = pv and pv.held_at and now_t - pv.held_at or nil,\n        }\n    end)\n    if (okd) then s.dg = dg end'}, {'name': 'diagnosis_function', 'before': 'shotlog.result = function(shot, hit)', 'after': '-- Per-shot diagnosis (dev build): names the most likely cause of a miss from what was logged. class "data" = shown by the\n-- logged values (a missing / held / stale angle, an enemy defensive, a host reason), "infer" = the most likely cause, NOT\n-- proven (the real angle of the enemy is not readable)\nshotlog.diagnose = function(row, snap, shot, hit)\n    if (hit) then\n        return "hit", "data", nil\n    end\n    local function n(v, digits)\n        v = shotlog.num(v, digits or 1)\n        return v == nil and "?" or tostring(v)\n    end\n    local reason = tostring(shot and shot.reason_string or "?")\n    local hc, bt, ping = tonumber(row.hc), tonumber(row.bt), tonumber(row.ping)\n    if (snap == nil) then\n        return "attr_lost", "data", "no snapshot (shot id missing or ambiguous), host: " .. reason\n    end\n    if (reason == "spread" or reason == "spread (missed safe)") then\n        if (hc ~= nil and hc < 60) then\n            return "low_hitchance", "infer", "spread at hit chance " .. n(hc, 0)\n        end\n        return "spread", "data", "host: spread at hit chance " .. n(hc, 0)\n    elseif (reason == "occlusion") then\n        return "occlusion", "data", "host: the bullet was blocked"\n    elseif (reason:find("death", 1, true)) then\n        return "death_race", "data", "host: " .. reason\n    elseif (reason == "server rejection") then\n        return "server_reject", "data", "host: server rejection"\n    end\n    if (snap.defensive) then\n        return "enemy_defensive", "data", "target shifted ticks at fire, lag comp not angle"\n    elseif (snap.lagbreak) then\n        return "enemy_lagbreak", "data", "target teleported (lag break) at fire"\n    end\n    local dg = snap.dg\n    if (snap.candidate == nil) then\n        return "no_value", "data", "no angle written (" .. tostring(snap.vw or "?") .. ")"\n    end\n    if (snap.vw == "held") then\n        return "held_value", "data", "held angle, " .. n(dg and dg.held, 2) .. " s old"\n    end\n    if (dg ~= nil and dg.fresh == false) then\n        return "stale_record", "data", "newest record " .. n(dg.age, 2) .. " s old at fire"\n    end\n    local eye_now, eye_fire = tonumber(row.eye), dg and tonumber(dg.eye) or nil\n    if (eye_now ~= nil and eye_fire ~= nil) then\n        local drift = (eye_now - eye_fire + 180) % 360 - 180\n        if (math.abs(drift) >= 25) then\n            return "target_turned", "infer", "eye yaw moved " .. n(drift, 0) .. " deg after the shot"\n        end\n    end\n    if (dg ~= nil and dg.jit and (reason == "jitter" or snap.kind == "jitter")) then\n        return "jitter_side", "infer", "jitter conf " .. n(dg.jc, 2) .. ", hypothesis " .. tostring(snap.candidate)\n    end\n    if ((tonumber(snap.misses) or 0) >= 2) then\n        return "repeat_miss", "infer", tostring(snap.misses) .. " misses in a row, hypothesis " .. tostring(snap.candidate)\n    end\n    if (bt ~= nil and bt >= 14) then\n        return "old_record", "infer", "shot at a " .. n(bt, 0) .. " tick old record"\n    end\n    if (ping ~= nil and ping >= 90) then\n        return "high_latency", "infer", "ping " .. n(ping, 0) .. " ms"\n    end\n    if (reason == "extrapolation") then\n        return "extrapolation", "infer", "host: movement prediction"\n    end\n    return "angle_wrong", "infer", "hypothesis " .. tostring(snap.candidate) .. " value " .. n(snap.desync, 0) .. " in " .. tostring(snap.key)\nend\nshotlog.result = function(shot, hit)'}, {'name': 'log_the_diagnosis', 'before': '    if (hit) then\n        row.hg, row.dmg = shot.hitgroup, shotlog.num(shot.damage)', 'after': '    local usable = (snap ~= nil and snap.idx == idx) and snap or nil\n    local okx, dxv, dxc, dxd = pcall(shotlog.diagnose, row, usable, shot, hit)\n    if (okx) then\n        row.dx, row.dxc, row.dxd = dxv, dxc, dxd\n    else\n        row.dx, row.dxc = "diag_error", "data"\n    end\n    local fire = usable ~= nil and usable.dg or nil\n    if (fire ~= nil) then\n        row.fa, row.fr, row.jc = shotlog.num(fire.age, 3), fire.fresh and 1 or 0, shotlog.num(fire.jc, 2)\n        row.fe, row.hl = shotlog.num(fire.eye, 1), shotlog.num(fire.held, 2)\n    end\n    if (not hit and ui.utils.event_logs:get(5)) then\n        pcall(function()\n            print("dx ", get_text_color(), tostring(row.dx), specter_color_t(168, 168, 168), "  " .. tostring(row.dxd or row.dxc or ""))\n        end)\n    end\n    if (hit) then\n        row.hg, row.dmg = shot.hitgroup, shotlog.num(shot.damage)'}]


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
            raise ValueError('Expected one unchanged or one patched fragment: ' + edit['name'])
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
