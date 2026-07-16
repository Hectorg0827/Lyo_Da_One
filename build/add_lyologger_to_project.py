#!/usr/bin/env python3
"""Add LyoLogger.swift to the Xcode project build target."""
import hashlib
import os

pbxproj_path = "Lyo.xcodeproj/project.pbxproj"

with open(pbxproj_path, "r") as f:
    content = f.read()

# Generate deterministic unique IDs (24 hex chars like Xcode)
def make_id(seed):
    return hashlib.md5(seed.encode()).hexdigest()[:24].upper()

file_ref_id = make_id("LyoLogger.swift_fileref")
build_file_id = make_id("LyoLogger.swift_buildfile")

print(f"File Reference ID: {file_ref_id}")
print(f"Build File ID:     {build_file_id}")

# Check if already added
if "LyoLogger.swift" in content:
    print("LyoLogger.swift already in project.pbxproj!")
    exit(0)

lines = content.split("\n")
new_lines = []
added_build_file = False
added_file_ref = False
added_to_core_group = False
added_to_sources_phase = False

i = 0
while i < len(lines):
    line = lines[i]

    # 1. Add PBXBuildFile entry (after the last existing one before the section ends)
    #    We'll add it after AppConfig.swift build file line
    if not added_build_file and "AppConfig.swift in Sources */" in line and "PBXBuildFile" in line:
        new_lines.append(line)
        new_lines.append(f"\t\t\t{build_file_id} /* LyoLogger.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* LyoLogger.swift */; }};")
        added_build_file = True
        i += 1
        continue

    # 2. Add PBXFileReference entry (after AppConfig.swift file ref)
    if not added_file_ref and "AppConfig.swift */" in line and "PBXFileReference" in line and "lastKnownFileType" in line:
        new_lines.append(line)
        new_lines.append(f"\t\t\t{file_ref_id} /* LyoLogger.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LyoLogger.swift; sourceTree = \"<group>\"; }};")
        added_file_ref = True
        i += 1
        continue

    # 3. Add to Core group children (after AppUIState.swift in the Core group)
    if not added_to_core_group and "AppUIState.swift */" in line:
        # Check if next lines are in Core group context
        new_lines.append(line)
        new_lines.append(f"\t\t\t\t{file_ref_id} /* LyoLogger.swift */,")
        added_to_core_group = True
        i += 1
        continue

    # 4. Add to Sources build phase (after AppConfig.swift in Sources)
    if not added_to_sources_phase and "AppConfig.swift in Sources */" in line and "Sources */" in line and "PBXBuildFile" not in line:
        new_lines.append(line)
        new_lines.append(f"\t\t\t\t\t\t{build_file_id} /* LyoLogger.swift in Sources */,")
        added_to_sources_phase = True
        i += 1
        continue

    new_lines.append(line)
    i += 1

# Write back
with open(pbxproj_path, "w") as f:
    f.write("\n".join(new_lines))

print(f"\nResults:")
print(f"  PBXBuildFile added:     {added_build_file}")
print(f"  PBXFileReference added: {added_file_ref}")
print(f"  Core group added:       {added_to_core_group}")
print(f"  Sources phase added:    {added_to_sources_phase}")

if all([added_build_file, added_file_ref, added_to_core_group, added_to_sources_phase]):
    print("\nAll 4 entries added successfully!")
else:
    print("\nWARNING: Some entries were not added!")
