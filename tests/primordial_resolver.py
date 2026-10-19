#!/usr/bin/env python3
"""Recompute the Primordial shot log tables (owners: judge by the real logs, Oct 2026).

  python3 tests/primordial_resolver.py                 # reads origin/shotlogs (git fetch origin shotlogs first)
  python3 tests/primordial_resolver.py dump.txt        # a "### path" + lines dump of the log files
  python3 tests/primordial_resolver.py --since 2026-10-16

Shot rows: hit rate by day, miss reasons, native share, safe point, state, hypothesis, fake ping, hit chance, missing value reason.
AA rows (kind "aa"): the ENEMY hit rate on us per state / yaw mode / jitter / desync / profile: LOWER IS BETTER for us.
Fails (exit 1) when a shot row after --since lacks a required field.
"""
import collections, json, re, subprocess, sys

REQUIRED = ("r", "native", "ping", "hc", "fp", "sx")


def load(path):
    rows, day = [], None
    if path:
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    else:
        files = subprocess.run(["git", "ls-tree", "-r", "--name-only", "origin/shotlogs", "--", "shotlogs/primordial"],
                               capture_output=True, text=True, check=True).stdout.split()
        lines = []
        for f in sorted(files):
            lines.append("### " + f)
            lines += subprocess.run(["git", "show", "origin/shotlogs:" + f], capture_output=True, text=True).stdout.splitlines()
    for line in lines:
        if line.startswith("### "):
            m = re.search(r"primordial/(\d{4}-\d\d-\d\d)", line)
            day = m.group(1) if m else None
            continue
        if day is None or "\t" not in line:
            continue
        try:
            row = json.loads(line.split("\t")[-1])
        except ValueError:
            continue
        row["_day"] = day
        rows.append(row)
    return rows


def table(title, rows, key, hit, minimum=1, note=""):
    groups = collections.defaultdict(lambda: [0, 0])
    for row in rows:
        k = key(row)
        groups[k][1] += 1
        groups[k][0] += 1 if hit(row) else 0
    print("\n%s %s" % (title, note))
    for k, (h, n) in sorted(groups.items(), key=lambda x: -x[1][1]):
        if n >= minimum:
            print("  %-22s n=%-5d %5.1f %%" % (k, n, 100.0 * h / n))
    return groups


def main(argv):
    since = None
    path = None
    args = list(argv)
    while args:
        a = args.pop(0)
        if a == "--since":
            since = args.pop(0)
        else:
            path = a
    rows = load(path)
    shots = [r for r in rows if r.get("kind") not in ("aa", "perf") and "native" in r]
    aa = [r for r in rows if r.get("kind") == "aa"]
    if not shots:
        print("no shot rows")
        return 1
    is_hit = lambda r: r.get("r") == "hit"
    print("shot rows %d, hit %.1f %%, aa rows %d" % (len(shots), 100.0 * sum(map(is_hit, shots)) / len(shots), len(aa)))
    table("by day", shots, lambda r: r["_day"], is_hit)
    table("native (Primordial's own resolver applied)", shots, lambda r: "native" if r["native"] else "ours", is_hit)
    print("\nmiss reasons")
    for k, n in collections.Counter(r.get("why", "?") for r in shots if not is_hit(r)).most_common():
        print("  %-22s %d" % (k, n))
    table("state (sx)", shots, lambda r: r.get("sx"), is_hit, 5)
    table("safe point (sp: none / 1 head / 2 jitter / 3 smart body)", shots, lambda r: r.get("sp"), is_hit)
    table("policy at fire time (hd)", shots, lambda r: r.get("hd"), is_hit)
    table("hypothesis (cd)", shots, lambda r: r.get("cd"), is_hit, 5)
    table("value missing reason (vw)", shots, lambda r: r.get("vw"), is_hit)
    table("enemy defensive (df)", shots, lambda r: bool(r.get("df")), is_hit)
    table("fake ping (fp)", shots, lambda r: r.get("fp"), is_hit, 10)
    table("hit chance (hc)", shots, lambda r: r.get("hc"), is_hit, 20)
    table("confidence band (cf)", shots, lambda r: None if r.get("cf") is None else int(r["cf"]) // 20 * 20, is_hit)
    if aa:
        ehit = lambda r: r.get("r") == "hit"
        for key in ("st", "ym", "jm", "ds", "arm", "ab", "def"):
            table("AA by %s" % key, aa, lambda r, key=key: str(r.get(key)), ehit, 20, "(enemy hit rate on us: LOWER IS BETTER)")
    bad = 0
    if since:
        for r in shots:
            if r["_day"] >= since:
                missing = [k for k in REQUIRED if k not in r]
                if missing:
                    bad += 1
                    if bad <= 5:
                        print("missing %s in a row of %s" % (missing, r["_day"]))
        print("\nrequired fields since %s: %s" % (since, "OK" if bad == 0 else "%d rows miss some" % bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
