"""Resolver context fixes for specter_primordial.lua (uniquely matched fragments, the rest of the source stays as it is)."""
import argparse
import json
from pathlib import Path
from primordial_safety_patch import tokens, semantic_hash

EDITS = [{'name': 'confidence_follows_decision', 'before': 'resolver.confidence = function(idx)\n    local prev, all = resolver.previous[idx], resolver.mem[idx]\n    local mem = prev ~= nil and prev.key ~= nil and all ~= nil and all[prev.key] or nil\n    local c = mem ~= nil and mem.candidates[prev.candidate or mem.selected or 1] or nil\n    if (c == nil) then return nil end\n    return 100 * c.good / math.max(1e-6, c.good + c.bad)\nend', 'after': 'resolver.confidence = function(idx)\n    local prev, all = resolver.previous[idx], resolver.mem[idx]\n    -- a held angle belongs to the situation it was decided in, not to the current one\n    local owner = prev ~= nil and ((prev.vwhy == "held" and prev.held_context) or prev) or nil\n    local slot = owner ~= nil and owner.key ~= nil and resolver.slot(owner.key, owner.kind, owner.state) or nil\n    local mem = slot ~= nil and all ~= nil and all[slot] or nil\n    local c = mem ~= nil and mem.candidates[owner.candidate or mem.selected or 1] or nil\n    if (c == nil) then return nil end\n    return 100 * c.good / math.max(1e-6, c.good + c.bad)\nend'}, {'name': 'memory_slot_per_state', 'before': 'resolver.memory = function(idx, key, kind)', 'after': '-- the memory slot of a situation: a detected jitterer is learned per movement state (it was one shared slot for stand / move / air)\nresolver.slot = function(key, kind, state)\n    if (kind == "jitter" and type(state) == "string" and state ~= "") then\n        return key .. "@" .. state\n    end\n    return key\nend\nresolver.memory = function(idx, key, kind, state)\n    key = resolver.slot(key, kind, state)'}, {'name': 'update_uses_state_slot', 'before': 'local mem = resolver.memory(idx, key, kind)', 'after': 'local mem = resolver.memory(idx, key, kind, state)'}, {'name': 'result_uses_decision_slot', 'before': 'local mem = resolver.memory(snapshot.idx, snapshot.key, snapshot.kind)', 'after': 'local mem = resolver.memory(snapshot.idx, snapshot.key, snapshot.kind, snapshot.dstate or snapshot.state)'}, {'name': 'held_context_state', 'before': 'candidate = candidate, m_flDesync = value, model = c, nxt = nx,\n            phase = prof.phase, reliab = prof.rel,', 'after': 'candidate = candidate, m_flDesync = value, model = c, nxt = nx,\n            phase = prof.phase, reliab = prof.rel, state = state,'}, {'name': 'snapshot_decision_state', 'before': 's.phase, s.reliab = selected.phase, selected.reliab', 'after': 's.phase, s.reliab = selected.phase, selected.reliab\n        s.dstate = selected.state'}, {'name': 'layers_at_fire', 'before': '    s.state = resolver.state_of(shot.player)', 'after': '    s.state = resolver.state_of(shot.player)\n    -- every animation layer that has weight at the moment of the shot (index:sequence:weight:cycle:rate), read only: the log is\n    -- how a layer is proven to tell the side before it is used for a decision\n    local okly, ly = pcall(function()\n        local address = get_entity_address(idx)\n        local parts = {}\n        for i = 0, 12 do\n            local layer = get_anim_layer(address, i)\n            local w = tonumber(layer.m_flWeight)\n            if (w ~= nil and w == w and w > 0.001) then\n                parts[#parts + 1] = string.format("%d:%d:%.2f:%.2f:%.3f", i, tonumber(layer.m_nSequence) or -1, w,\n                    tonumber(layer.m_flCycle) or 0, tonumber(layer.m_flPlaybackRate) or 0)\n            end\n        end\n        return table.concat(parts, ";")\n    end)\n    if (okly and type(ly) == "string") then s.ly = ly end'}, {'name': 'layers_in_the_log', 'before': '        row.cf = shotlog.num(snap.conf, 0)', 'after': '        row.cf = shotlog.num(snap.conf, 0)\n        row.ly = snap.ly'}]


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
