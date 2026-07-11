#!/usr/bin/env python3
"""Simple A2UI payload validator and logger.

Usage:
  python3 build/a2ui_validate_payload.py [path/to/payload.json]

This script loads the payload, prints a short summary of its top-level keys
and the components found so it can be shared with backend or used to debug
renderer decoding problems.
"""
from __future__ import annotations
import sys
import json
from pathlib import Path


def main():
    p = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("Tests/Fixtures/OpenClassroomSample.json")
    if not p.exists():
        print(f"ERROR: file not found: {p}")
        raise SystemExit(2)

    raw = p.read_text(encoding="utf-8")
    try:
        payload = json.loads(raw)
    except Exception as e:
        print("❌ Failed to parse JSON:", e)
        print("--- Raw start ---")
        print(raw[:1000])
        print("--- Raw end ---")
        raise

    print("✅ Parsed payload:")
    print("  - path:", p)
    print("  - top-level keys:", sorted(list(payload.keys())))

    cid = payload.get("id") or payload.get("courseId")
    if cid:
        print("  - id:", cid)

    comps = payload.get("components") or payload.get("items") or []
    print(f"  - components count: {len(comps)}")
    for i, c in enumerate(comps):
        if isinstance(c, dict):
            t = c.get("type") or c.get("componentType") or "<unknown>"
            keys = list(c.keys())
            print(f"    {i:02d}: type={t} keys={keys}")
        else:
            print(f"    {i:02d}: NON-OBJECT component: {repr(c)[:80]}")

    # Print sample of the first component for easier sharing
    if comps:
        print("\n--- First component (pretty) ---")
        print(json.dumps(comps[0], indent=2)[:2000])

    print("\nDone.")


if __name__ == '__main__':
    main()
