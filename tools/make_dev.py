#!/usr/bin/env python3
"""Builds specter_dev.lua from specter_cloud.lua.

specter_dev.lua is the NORMAL script for the owners / developers: no login, no loader, no auth gate, no integrity
monitor, every feature unlocked (debug tier). Nothing else differs - it is generated, so it can never drift.

    python3 tools/make_dev.py            rewrite specter_dev.lua
    python3 tools/make_dev.py --check    exit 1 when specter_dev.lua is not what this tool would write

Always edit specter_cloud.lua, never specter_dev.lua, and run this tool before committing.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "specter_cloud.lua")
DST = os.path.join(ROOT, "specter_dev.lua")

DEV_HEADER = """-- ── DEV BUILD ─────────────────────────────────────────────────────────
-- The normal Specter script without login, auth gate, integrity monitor or loader: every feature unlocked.
-- Generated from specter_cloud.lua by tools/make_dev.py - do not edit by hand, edit specter_cloud.lua and run the tool.
--
-- Only the cloud configs talk to the license server and need these. Leave them empty to run without cloud configs.
local DEV_SERVER_URL = ""
local DEV_KEY        = ""
local DEV_HWID       = ""

local _auth_data = { user = "dev", plan = "debug", key = DEV_KEY, hwid = DEV_HWID, server_url = DEV_SERVER_URL }
_USER_NAME = _auth_data.user
-- ── END DEV BUILD ─────────────────────────────────────────────────────"""

# the monitor's guards in the callbacks (they are all of these two shapes)
GUARD = re.compile(r"^\s*if _integrity( and not _integrity\.is_ok\(\))? then (return end|_integrity\.check\((tick|globals_tickcount\(\))\) end)\s*$")


def find_marker(lines, prefix, start=0):
    hits = [i for i in range(start, len(lines)) if lines[i].lstrip().startswith(prefix)]
    if len(hits) != 1:
        sys.exit(f"make_dev: expected exactly one line starting with {prefix!r}, found {len(hits)}")
    return hits[0]


def build(text):
    lines = text.split("\n")

    # 1) auth gate -> plain dev header
    a0 = find_marker(lines, "-- ── AUTH GATE")
    a1 = find_marker(lines, "-- ── END AUTH GATE")
    if not a0 < a1:
        sys.exit("make_dev: auth gate markers out of order")
    lines[a0:a1 + 1] = DEV_HEADER.split("\n")

    # 2) integrity monitor out
    i0 = find_marker(lines, "-- ── INTEGRITY MONITOR")
    i1 = find_marker(lines, "-- ── END INTEGRITY MONITOR")
    if not i0 < i1:
        sys.exit("make_dev: integrity markers out of order")
    del lines[i0:i1 + 1]

    # 3) its guards in the callbacks out
    kept, removed = [], 0
    for line in lines:
        if GUARD.match(line):
            removed += 1
        else:
            kept.append(line)
    if removed != 5:
        sys.exit(f"make_dev: expected 5 integrity guard lines, found {removed} - update tools/make_dev.py")
    out = "\n".join(kept)

    # nothing of the protection may be left behind
    for needle in ("_integrity", "_auth_ok", "_auth_alive", "_auth_ts", "AUTH GATE", "INTEGRITY", "LPH_CRASH()", "Unauthorized"):
        if needle in out:
            sys.exit(f"make_dev: {needle!r} is still in the dev build")
    return out


def main():
    built = build(open(SRC, encoding="utf-8").read())
    if "--check" in sys.argv:
        current = open(DST, encoding="utf-8").read() if os.path.exists(DST) else ""
        if current != built:
            print("specter_dev.lua is out of date: run  python3 tools/make_dev.py")
            return 1
        print("specter_dev.lua is up to date")
        return 0
    with open(DST, "w", encoding="utf-8", newline="\n") as f:
        f.write(built)
    print(f"wrote specter_dev.lua ({len(built.splitlines())} lines)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
