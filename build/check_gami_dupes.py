#!/usr/bin/env python3
"""Fix GamificationService duplicates and validate pbxproj"""
import re
from pathlib import Path

PBXPROJ = Path("/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj/project.pbxproj")
text = PBXPROJ.read_text()

# GamificationService duplicates
# Canonical: 36802A4CB8DACDB3E49673EF (no includeInIndex)
# Duplicates: 3DA2CF11C9CA0E5FA172D531, C5DF74961052428829A540A0 (both includeInIndex = 1)
# Need their build file UUIDs
print("GamificationService build file search:")

# Find which build files reference the duplicate file refs
for fref in ["3DA2CF11C9CA0E5FA172D531", "C5DF74961052428829A540A0"]:
    m = re.search(rf'([A-F0-9]{{24}}) /\* GamificationService\.swift in Sources \*/ = \{{isa = PBXBuildFile; fileRef = {fref}', text)
    if m:
        print(f"  {fref} -> build file: {m.group(1)}")
    else:
        print(f"  {fref} -> NO BUILD FILE FOUND (might just be in group)")
