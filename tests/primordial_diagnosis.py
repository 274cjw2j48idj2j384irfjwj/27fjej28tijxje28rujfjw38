#!/usr/bin/env python3
"""Per-shot fault summary from the Primordial shot logs (row field `dx`).

  python3 tests/primordial_diagnosis.py dump.txt     # a "### path" + lines dump
  python3 tests/primordial_diagnosis.py              # reads origin/shotlogs

dxc "data" = shown by the logged values, "infer" = most likely cause, not proven.
"""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import primordial_resolver as pr


def main(argv):
    rows = pr.load(argv[0] if argv else None)
    misses = [r for r in rows if r.get("kind") not in ("aa", "perf") and r.get("r") == "miss"]
    known = [r for r in misses if "dx" in r]
    print("misses %d, with a diagnosis %d" % (len(misses), len(known)))
    if not known:
        return 1
    counts = collections.Counter((r["dx"], r.get("dxc", "?")) for r in known)
    for (cause, klass), n in counts.most_common():
        print("  %-18s %-6s %4d  %5.1f %%" % (cause, klass, n, 100.0 * n / len(known)))
    by_state = collections.defaultdict(collections.Counter)
    for r in known:
        by_state[r.get("sx", "?")][r["dx"]] += 1
    print("\nmain cause per state")
    for state, causes in sorted(by_state.items(), key=lambda x: -sum(x[1].values())):
        cause, n = causes.most_common(1)[0]
        print("  %-10s %-18s %d of %d" % (state, cause, n, sum(causes.values())))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
