"""Point three older checks at the per state jitter slot (a detected jitterer is learned per movement state)."""
import argparse
import json
from pathlib import Path

REPLACEMENTS = [
    ('resolver.previous[3] = { key = "jitter", kind = "jitter", candidate = 1, m_flDesync = 20, rel = 1 }\nlocal mem = resolver.memory(3, "jitter")',
     'resolver.previous[3] = { key = "jitter", kind = "jitter", candidate = 1, m_flDesync = 20, rel = 1 }\nlocal mem = resolver.memory(3, "jitter@stand")'),
    ('    local mem = resolver.memory(3, key)\n    local good = mem.candidates[1].good',
     '    local mem = resolver.memory(3, key .. "@stand")\n    local good = mem.candidates[1].good'),
    ('local mem4 = resolver.memory(3, "learn4")',
     'local mem4 = resolver.memory(3, "learn4@stand")'),
]


def build(text):
    done = []
    for old, new in REPLACEMENTS:
        if text.count(old) == 1 and text.count(new) == 0:
            text = text.replace(old, new)
            done.append(new.splitlines()[-1].strip())
        elif text.count(new) == 1 and text.count(old) == 0:
            continue
        else:
            raise ValueError('Expected exactly one old or one new text: ' + old.splitlines()[-1].strip())
    return text, done


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', default='tests/primordial_regress.py')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    path = Path(args.source)
    updated, done = build(path.read_bytes().decode('utf-8'))
    if args.apply and done:
        path.write_bytes(updated.encode('utf-8'))
    print(json.dumps({'applied': bool(args.apply and done), 'changes': done}))


if __name__ == '__main__':
    main()
