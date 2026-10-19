"""Apply only uniquely matched reviewed edits, preserving unrelated Lua source."""
import argparse
import json
from pathlib import Path
from primordial_safety_patch import EDITS, tokens, semantic_hash


def matches(stream, needle):
    size = len(needle)
    return [i for i, token in enumerate(stream) if token == needle[0] and stream[i:i+size] == needle]


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
        changes.append((stream[start][1], stream[stop-1][2], edit['after'], edit['name']))
    occupied.sort()
    if any(a[1] > b[0] for a, b in zip(occupied, occupied[1:])):
        raise ValueError('Overlapping reviewed edit regions')
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
