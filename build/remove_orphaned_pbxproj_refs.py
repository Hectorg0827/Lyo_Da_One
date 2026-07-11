#!/usr/bin/env python3
"""
Remove orphaned file references from Xcode pbxproj
"""
import re
from pathlib import Path

pbxproj_path = Path("/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj/project.pbxproj")

# Files to remove and their IDs
files_to_remove = {
    "ChatBubbleView.swift": {
        "build_id": "3762036A4644DA8A4251DFDD",
        "ref_id": "0DA3DF9BA88DE65E82CC45DB"
    },
    "ChatHistoryView.swift": {
        "build_id": "9910F0100122BEA735C31270",
        "ref_id": "7083C463CB880165A70D6626"
    },
    "HapticManager.swift": {
        "build_id": "0041454849867A8C24EEC7AE",
        "ref_id": "9793EECAFF67A8F1002513DE"
    },
    "LioChatService.swift": {
        "build_id": "A5839961C49574ACB849FF88",
        "ref_id": "653AF7B3538339B65F0F5EA0"
    },
    "SpeechToTextService.swift": {
        "build_id": "2F51F8C4644026ADD9294B1E",
        "ref_id": "80390B560A0117C7D4006D4A"
    }
}

content = pbxproj_path.read_text(encoding='utf-8')
original_size = len(content)

# Remove PBXBuildFile entries
for filename, ids in files_to_remove.items():
    build_id = ids["build_id"]
    # Match the PBXBuildFile entry with this ID
    pattern = rf'\t\t{build_id} /\* .+? \*/ = \{{isa = PBXBuildFile; fileRef = .+? /\* .+? \*/; \}};\n'
    content = re.sub(pattern, '', content)
    print(f"Removed PBXBuildFile entry for {filename}")

# Remove PBXFileReference entries
for filename, ids in files_to_remove.items():
    ref_id = ids["ref_id"]
    # Match the PBXFileReference entry with this ID
    pattern = rf'\t\t{ref_id} /\* .+? \*/ = \{{isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = .+?; sourceTree = SOURCE_ROOT; \}};\n'
    content = re.sub(pattern, '', content)
    print(f"Removed PBXFileReference entry for {filename}")

# Remove group references (files in groups)
for filename, ids in files_to_remove.items():
    ref_id = ids["ref_id"]
    # Match group reference: "\t\t\t\t{ref_id} /* filename */,"
    pattern = rf'\t\t\t\t{ref_id} /\* .+? \*/,\n'
    content = re.sub(pattern, '', content)
    # Also try without the trailing comma
    pattern = rf'\t\t\t\t{ref_id} /\* .+? \*/\n'
    content = re.sub(pattern, '', content)
    print(f"Removed group reference for {filename}")

# Remove build phase references
for filename, ids in files_to_remove.items():
    build_id = ids["build_id"]
    # Match build phase reference: "\t\t\t\t{build_id} /* filename in Sources */,"
    pattern = rf'\t\t\t\t{build_id} /\* .+? in .+? \*/,\n'
    content = re.sub(pattern, '', content)
    # Also try without the trailing comma
    pattern = rf'\t\t\t\t{build_id} /\* .+? in .+? \*/\n'
    content = re.sub(pattern, '', content)
    print(f"Removed build phase reference for {filename}")

new_size = len(content)
bytes_removed = original_size - new_size

# Write back
pbxproj_path.write_text(content, encoding='utf-8')

print(f"\n✅ Done!")
print(f"Original size: {original_size} bytes")
print(f"New size: {new_size} bytes")
print(f"Removed: {bytes_removed} bytes")
