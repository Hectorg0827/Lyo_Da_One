#!/usr/bin/env python3
"""
Fix duplicate file references in Lyo.xcodeproj/project.pbxproj.
These duplicates (with includeInIndex = 1) prevent the Swift compiler from
building those files, causing "cannot find type in scope" errors.
"""
import re
import shutil
from pathlib import Path

PBXPROJ = Path("/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj/project.pbxproj")

# Backup
backup = PBXPROJ.with_suffix(".pbxproj.bak")
shutil.copy2(PBXPROJ, backup)
print(f"Backup saved to {backup}")

text = PBXPROJ.read_text()
original_len = len(text.splitlines())

# UUIDs to completely remove (duplicate fileRefs, build files, group refs, build phase refs)
# Format: (file_ref_uuid, build_file_uuid, comment_name)
TO_REMOVE = [
    # EnhancedCameraManager.swift duplicates (includeInIndex = 1)
    ("5D949ECDB1A8A859D7238B60", "7A2AE120CB97A00E231F7709", "EnhancedCameraManager.swift"),
    ("9FEDD03DE424106917F863D2", "8F31212AC5CC4485C92A33D5", "EnhancedCameraManager.swift"),
    # ContentStorageService.swift duplicates (includeInIndex = 1)
    ("5AB078523E95BE2C374F4CF9", "10F6419D735A27B27BC59340", "ContentStorageService.swift"),
    ("83CD1864418D8A3A4288A53A", "11FD511831D61F3F70FDA705", "ContentStorageService.swift"),
    # CalendarService.swift duplicates (includeInIndex = 1)
    ("28324C8FE07C6F01DA495801", "5ABBBD63C3A5CA729DBBDDA7", "CalendarService.swift"),
    ("655C8DCE33476459BB8F34C3", "6E6ACF2C248A926BA2F3D2DF", "CalendarService.swift"),
]

# Also check GamificationService for duplicates
gami_check = re.findall(r'([A-F0-9]{24}) /\* GamificationService\.swift \*/ = \{isa = PBXFileReference;(.*?)\};', text, re.DOTALL)
print(f"\nGamificationService file refs: {len(gami_check)}")
for uuid, content in gami_check:
    has_index = 'includeInIndex' in content
    print(f"  {uuid}: includeInIndex={has_index}")

gami_build_files = re.findall(r'([A-F0-9]{24}) /\* GamificationService\.swift in Sources \*/', text)
print(f"GamificationService build files: {gami_build_files}")

lines = text.splitlines(keepends=True)
removed_lines = []

# Track which UUIDs are being removed
all_remove_uuids = set()
for file_ref_uuid, build_file_uuid, _ in TO_REMOVE:
    all_remove_uuids.add(file_ref_uuid)
    all_remove_uuids.add(build_file_uuid)

new_lines = []
for i, line in enumerate(lines):
    should_remove = False
    for uuid in all_remove_uuids:
        if uuid in line:
            should_remove = True
            removed_lines.append((i+1, line.rstrip()))
            break
    if not should_remove:
        new_lines.append(line)

new_text = "".join(new_lines)
new_len = len(new_lines)

print(f"\nOriginal lines: {original_len}")
print(f"New lines: {new_len}")
print(f"Removed {original_len - new_len} lines:")
for lineno, line in removed_lines:
    print(f"  L{lineno}: {line.strip()[:100]}")

# Verify the canonical entries still exist
print("\nVerifying canonical entries remain:")
for fname, keep_uuids in [
    ("EnhancedCameraManager.swift", ["2F363D631F20871271C52060", "2C8EA58DBC072781B8EDEB12"]),
    ("ContentStorageService.swift", ["23821B56B350C3049BDD0D79", "C7E9B400C4E62B2A77D66F11"]),
    ("CalendarService.swift", ["F08756E3E7819C0E73E63769", "7D48CAE59A4F83A7F44F5EBF"]),
]:
    for uuid in keep_uuids:
        if uuid in new_text:
            print(f"  ✓ {uuid} ({fname})")
        else:
            print(f"  ✗ MISSING {uuid} ({fname}) - ERROR!")

PBXPROJ.write_text(new_text)
print(f"\n✅ Wrote updated pbxproj ({new_len} lines)")
