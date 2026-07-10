#!/usr/bin/env python3
"""Remove GamificationService duplicates from pbxproj"""
from pathlib import Path

PBXPROJ = Path("/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj/project.pbxproj")
text = PBXPROJ.read_text()

GAMI_REMOVE_UUIDS = {
    "3DA2CF11C9CA0E5FA172D531",  # file ref (includeInIndex = 1)
    "C5DF74961052428829A540A0",  # file ref (includeInIndex = 1)
    "AA0667A2297EDDD11C1354E3",  # build file for 3DA2...
    "1F0D2CD00E405BF6E6C05C6B",  # build file for C5DF...
}

lines = text.splitlines(keepends=True)
original_len = len(lines)
new_lines = []
removed = []

for i, line in enumerate(lines):
    should_remove = any(uuid in line for uuid in GAMI_REMOVE_UUIDS)
    if should_remove:
        removed.append((i+1, line.rstrip()))
    else:
        new_lines.append(line)

print(f"Original: {original_len} lines, removing {len(removed)}")
for lineno, line in removed:
    print(f"  L{lineno}: {line.strip()[:100]}")

# Verify canonical still there
canonical = "36802A4CB8DACDB3E49673EF"
canonical_build = "682FE0A80A1D1DAD98476679"
new_text = "".join(new_lines)
print(f"\nCanonical fileRef {canonical}: {'✓' if canonical in new_text else '✗ MISSING!'}")
print(f"Canonical buildFile {canonical_build}: {'✓' if canonical_build in new_text else '✗ MISSING!'}")

PBXPROJ.write_text(new_text)
print(f"\n✅ Wrote updated pbxproj ({len(new_lines)} lines)")
