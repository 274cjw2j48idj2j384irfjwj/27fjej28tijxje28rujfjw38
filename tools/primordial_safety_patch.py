"""Fail-closed, comment-preserving Primordial safety patch; no network access."""
import argparse
import hashlib
import json
import re
from pathlib import Path

def tokens(text):
    result = []
    i, n = 0, len(text)
    word_pattern = re.compile(r'[A-Za-z_][A-Za-z_0-9]*|[0-9]+')
    bracket_pattern = re.compile(r'\[(=*)\[')
    while i < n:
        if text[i].isspace():
            i += 1
            continue
        comment = text.startswith('--', i)
        j = i + 2 if comment else i
        bracket = bracket_pattern.match(text, j)
        if bracket:
            closer = ']' + bracket.group(1) + ']'
            end = text.find(closer, bracket.end())
            if end < 0:
                raise ValueError('Unterminated Lua long string/comment')
            end += len(closer)
            if not comment:
                result.append((text[i:end], i, end))
            i = end
        elif comment:
            end = text.find('\n', j)
            i = n if end < 0 else end
        elif text[i] in "\"'":
            quote, end = text[i], i + 1
            while end < n:
                if text[end] == '\\':
                    end += 2
                elif text[end] == quote:
                    end += 1
                    break
                else:
                    end += 1
            else:
                raise ValueError('Unterminated Lua quoted string')
            result.append((text[i:end], i, end))
            i = end
        else:
            word = word_pattern.match(text, i)
            end = word.end() if word else i + 1
            result.append((text[i:end], i, end))
            i = end
    return result

def semantic_hash(text):
    return hashlib.sha256(json.dumps([t[0] for t in tokens(text)], ensure_ascii=True, separators=(',', ':')).encode()).hexdigest()

EXPECTED_BEFORE = '98f72fbfb305064fefe22b2ebaccd98b20e7516cca3b0e0b5b6f7026f4ec4aca'
EXPECTED_AFTER = '20b3902fda44c0047013b4971b9923ddf1d7d7f918c9f7934c1299f6e6f3dc70'
EDITS = [
    {'name': 'bound_defensive_attribution', 'before': '''resolver.spoiled = function(p, t_fire, rtt, now, kind)
    local m = resolver.K.ev_margin
    for _, ev in ipairs(p.events or {}) do
        if (ev.kind == kind and ev.obs >= t_fire + rtt - ev.dur - m and ev.obs <= now + m) then
            return true
        end
    end
    return false
end''', 'after': '''resolver.spoiled = function(p, t_fire, rtt, now, kind)
    local m = resolver.K.ev_margin
    local upper = math.min(now, t_fire + rtt) + m
    for _, ev in ipairs(p.events or {}) do
        if (ev.kind == kind and ev.obs >= t_fire + rtt - ev.dur - m and ev.obs <= upper) then
            return true
        end
    end
    return false
end'''},
    {'name': 'retain_held_decision_owner', 'before': '''        prev.held, prev.held_candidate, prev.held_at = value, candidate, globals.real_time()''', 'after': '''        prev.held, prev.held_candidate, prev.held_at = value, candidate, globals.real_time()
        prev.held_context = {
            key = key, kind = kind, rel = value ~= 0 and res_sign(value * hint) or 0,
            candidate = candidate, m_flDesync = value, model = c, nxt = nx,
            phase = prof.phase, reliab = prof.rel,
        }'''},
    {'name': 'correct_fresh_value_status', 'before': '''    prev.vwhy = fresh_value and nil or applied and "held" or (p.samples < 2 and "few") or (p.nochoke >= RES_NOCHOKE and "nochoke") or "stale"''', 'after': '''    if (fresh_value) then
        prev.vwhy = nil
    else
        prev.vwhy = applied and "held" or (p.samples < 2 and "few") or (p.nochoke >= RES_NOCHOKE and "nochoke") or "stale"
    end'''},
    {'name': 'credit_actual_held_hypothesis', 'before': '''    if (prev ~= nil) then
        s.key, s.kind, s.rel = prev.key, prev.kind, prev.rel
        s.candidate, s.desync = prev.candidate, prev.m_flDesync
        s.model, s.nxt = prev.model, prev.nxt
        s.phase, s.reliab = prev.phase, prev.reliab
        s.vw = prev.vwhy
    end''', 'after': '''    if (prev ~= nil) then
        local selected = (prev.vwhy == "held" and prev.held_context) or prev
        s.key, s.kind, s.rel = selected.key, selected.kind, selected.rel
        s.candidate, s.desync = selected.candidate, selected.m_flDesync
        s.model, s.nxt = selected.model, selected.nxt
        s.phase, s.reliab = selected.phase, selected.reliab
        s.vw = prev.vwhy
    end'''},
    {'name': 'one_bandit_update_per_incoming_shot', 'before': '''    if (snapshot ~= nil and snap.arm_index ~= nil) then
        builder.adv.brain_learn(builder.brain, builder.adv.arm_group(snap.n), kind, hitgroup,
            globals.real_time(), math.random, snap.arm_index)
    end''', 'after': '''    if (snapshot ~= nil and snap.arm_index ~= nil and not snap.learned
        and (kind == "evaded" or (kind == "hit" and hitgroup == 1))) then
        snap.learned = true
        builder.adv.brain_learn(builder.brain, builder.adv.arm_group(snap.n), kind, hitgroup,
            globals.real_time(), math.random, snap.arm_index)
    end'''},
    {'name': 'reject_stale_or_hurt_nearmiss_callbacks', 'before': '''                            client_delay_call(function()
                                if (builder.miss_current(attacker_idx, seq) and my_eye ~= nil) then
                                    if (builder.closest_point_on_ray(localorigin, bullet_impact, my_eye):dist(my_eye) < 50) then''', 'after': '''                            local scheduled_at = globals.real_time()
                            client_delay_call(function()
                                local now = globals.real_time()
                                if (not ui.antiaim.builder.enable:get() or now < scheduled_at or now - scheduled_at > 0.5) then return end
                                if (entity_list_get_local_player() ~= local_player or not local_player:is_alive()) then return end
                                if (entity_list_get_player_from_userid(userid) ~= entity or not entity:is_enemy()) then return end
                                if (snapshot ~= nil and (snapshot.hurt or snapshot.evaded)) then return end
                                if (builder.miss_current(attacker_idx, seq) and my_eye ~= nil) then
                                    if (builder.closest_point_on_ray(localorigin, bullet_impact, my_eye):dist(my_eye) < 50) then'''}
]

def build_patch(text):
    current = semantic_hash(text)
    if current == EXPECTED_AFTER:
        return text, []
    if current != EXPECTED_BEFORE:
        raise ValueError('Source differs from reviewed upload; refusing automatic modification')
    stream = tokens(text)
    values = [t[0] for t in stream]
    changes = []
    for edit in EDITS:
        needle = [t[0] for t in tokens(edit['before'])]
        matches = [i for i, value in enumerate(values) if value == needle[0] and values[i:i+len(needle)] == needle]
        if len(matches) != 1:
            raise ValueError('Expected exactly one match: ' + edit['name'])
        i = matches[0]
        changes.append((stream[i][1], stream[i+len(needle)-1][2], edit['after'], edit['name']))
    changes.sort()
    if any(a[1] > b[0] for a, b in zip(changes, changes[1:])):
        raise ValueError('Overlapping patch edits')
    result = text
    for start, end, replacement, _ in reversed(changes):
        result = result[:start] + replacement + result[end:]
    if semantic_hash(result) != EXPECTED_AFTER:
        raise ValueError('Patched source does not match reviewed result')
    return result, [c[3] for c in changes]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', default='specter_primordial.lua')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    path = Path(args.source)
    updated, names = build_patch(path.read_bytes().decode('utf-8'))
    if args.apply and names:
        path.write_bytes(updated.encode('utf-8'))
    print(json.dumps({'applied': bool(args.apply and names), 'edits': names, 'semantic_sha256': semantic_hash(updated)}))

if __name__ == '__main__':
    main()
