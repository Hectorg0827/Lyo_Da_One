#!/usr/bin/env python3
"""Add SmartBlock-related Swift files to project.pbxproj."""
import hashlib

pbxproj = "Lyo.xcodeproj/project.pbxproj"

# New files to add
new_files = [
    ("SmartBlock.swift", "Sources/Models"),
    ("UnifiedBlockRenderer.swift", "Sources/Views/Shared"),
    ("LegacyBlockMigrator.swift", "Sources/Services"),
]


def make_id(seed):
    """Generate a 24-char hex ID deterministically."""
    return hashlib.md5(seed.encode()).hexdigest()[:24].upper()


with open(pbxproj) as f:
    content = f.read()

for filename, parent_path in new_files:
    # Skip if already present
    if filename in content:
        print(f"SKIP (already present): {filename}")
        continue

    file_ref_id = make_id(f"{filename}_fileref_smartblock")
    build_file_id = make_id(f"{filename}_buildfile_smartblock")
    full_path = f"{parent_path}/{filename}"

    # 1. Add PBXFileReference
    file_ref_line = f'\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};\n'

    # Insert after last PBXFileReference entry
    marker = "/* End PBXFileReference section */"
    idx = content.find(marker)
    if idx == -1:
        print(f"ERROR: Cannot find PBXFileReference section end for {filename}")
        continue
    content = content[:idx] + file_ref_line + content[idx:]

    # 2. Add PBXBuildFile
    build_file_line = f'\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};\n'

    marker = "/* End PBXBuildFile section */"
    idx = content.find(marker)
    if idx == -1:
        print(f"ERROR: Cannot find PBXBuildFile section end for {filename}")
        continue
    content = content[:idx] + build_file_line + content[idx:]

    # 3. Add to Sources build phase
    # Find "/* Begin PBXSourcesBuildPhase section */" and add within the files list
    sources_marker = "/* Sources */ = {"
    sources_idx = content.find(sources_marker)
    if sources_idx != -1:
        # Find the "files = (" after the sources marker
        files_start = content.find("files = (", sources_idx)
        if files_start != -1:
            insert_point = files_start + len("files = (\n")
            source_line = f'\t\t\t\t{build_file_id} /* {filename} in Sources */,\n'
            content = content[:insert_point] + source_line + content[insert_point:]

    # 4. Add to parent group
    # Find the group that matches the parent path
    # Look for the group's children array
    group_name = parent_path.split("/")[-1]
    # Try to find a group with matching path
    group_pattern = f'path = {group_name};'
    group_idx = content.find(group_pattern)
    if group_idx != -1:
        # Find the children = ( before this
        # Go backwards to find "children = ("
        search_start = max(0, group_idx - 2000)
        children_marker = "children = ("
        children_idx = content.rfind(children_marker, search_start, group_idx)
        if children_idx != -1:
            insert_point = children_idx + len(children_marker) + 1  # after newline
            child_line = f'\t\t\t\t{file_ref_id} /* {filename} */,\n'
            content = content[:insert_point] + child_line + content[insert_point:]
            print(f"ADDED to group '{group_name}': {filename}")
        else:
            print(f"WARNING: Could not find children array for group '{group_name}', added to build phase only: {filename}")
    else:
        print(f"WARNING: Could not find group '{group_name}', added to build phase only: {filename}")

with open(pbxproj, "w") as f:
    f.write(content)

print("Done. Run 'plutil -lint Lyo.xcodeproj/project.pbxproj' to verify.")
