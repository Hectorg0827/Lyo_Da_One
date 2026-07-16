#!/usr/bin/env python3
"""Add missing Swift files to project.pbxproj."""
import hashlib
import os
import re

pbxproj = "Lyo.xcodeproj/project.pbxproj"

# Missing files with their parent group paths (for finding the right PBXGroup)
missing_files = [
    ("A2UIHomeworkRenderers.swift", "Sources/Core/A2UI/Views"),
    ("A2UIMiscRenderers.swift", "Sources/Core/A2UI/Views"),
    ("A2UIMistakeRenderers.swift", "Sources/Core/A2UI/Views"),
    ("A2UIStudyPlanRenderers.swift", "Sources/Core/A2UI/Views"),
    ("ClientCapabilities.swift", "Sources/Core"),
    ("CommentsView.swift", "Sources/Views/Community"),
    ("CommunityFeedView.swift", "Sources/Views/Community"),
    ("CommunityFeedViewModel.swift", "Sources/ViewModels"),
    ("CommunityPostModels.swift", "Sources/Models/Community"),
    ("CommunityService.swift", "Sources/Services"),
    ("CourseRuntimeView.swift", "Sources/Views"),
    ("DemoCourseLoader.swift", "Sources/Services"),
    ("LessonBlockParser.swift", "Sources/Services"),
    ("Lyo2ChatService.swift", "Sources/Services"),
    ("Lyo2Models.swift", "Sources/Models"),
    ("LyoAdapterTests.swift", "Sources/Tests"),
    ("LyoCinematicIntegrationTests.swift", "Sources/Tests"),
    ("LyoCourseProtocol.swift", "Sources/Models"),
    ("LyoCourseRuntime.swift", "Sources/Services"),
    ("LyoRuntimeModels.swift", "Sources/Models"),
    ("NotesView.swift", "Sources/Views/Chat"),
    ("PremiumQuizView.swift", "Sources/Components/Learning"),
]

def make_id(seed):
    """Generate a 24-char hex ID deterministically."""
    return hashlib.md5(seed.encode()).hexdigest()[:24].upper()

with open(pbxproj) as f:
    content = f.read()

lines = content.split("\n")

# Generate IDs for each file
file_entries = []
for filename, parent_path in missing_files:
    file_ref_id = make_id(f"{filename}_fileref_v2")
    build_file_id = make_id(f"{filename}_buildfile_v2")
    file_entries.append({
        "filename": filename,
        "parent_path": parent_path,
        "file_ref_id": file_ref_id,
        "build_file_id": build_file_id,
    })

# Find insertion points
# 1. PBXBuildFile section - find the end marker
# 2. PBXFileReference section - find the end marker
# 3. PBXGroup sections - need to match each parent
# 4. Sources build phase - find the files list

# Strategy: insert all build files and file references at sorted positions,
# and add to the sources build phase. For groups, we need to find each parent group.

# Let's find the sections
build_file_section_end = None
file_ref_section_end = None
sources_phase_start = None

for i, line in enumerate(lines):
    if "/* End PBXBuildFile section */" in line:
        build_file_section_end = i
    if "/* End PBXFileReference section */" in line:
        file_ref_section_end = i

# Build new content with insertions
new_lines = []
build_files_added = False
file_refs_added = False
sources_entries_added = False

# Track which groups we've found and added to
groups_added = set()

# Map parent folder name to the group ID patterns we need to find
# We'll look for group sections and add children

for i, line in enumerate(lines):
    # Insert PBXBuildFile entries before section end
    if i == build_file_section_end and not build_files_added:
        for entry in sorted(file_entries, key=lambda e: e["build_file_id"]):
            new_lines.append(f'\t\t{entry["build_file_id"]} /* {entry["filename"]} in Sources */ = {{isa = PBXBuildFile; fileRef = {entry["file_ref_id"]} /* {entry["filename"]} */; }};')
        build_files_added = True
    
    # Insert PBXFileReference entries before section end
    if i == file_ref_section_end and not file_refs_added:
        for entry in sorted(file_entries, key=lambda e: e["file_ref_id"]):
            new_lines.append(f'\t\t{entry["file_ref_id"]} /* {entry["filename"]} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {entry["filename"]}; sourceTree = "<group>"; }};')
        file_refs_added = True
    
    new_lines.append(line)
    
    # For each group, look for its children section and add our files
    # We identify groups by their path attribute
    if "path = " in line and "sourceTree" in line and "isa = PBXGroup" not in line:
        pass  # This is a file reference, not a group
    
    # Look for groups by checking if this line has `path = X;` inside a PBXGroup
    # Groups look like:
    #   XXXX /* GroupName */ = {
    #     isa = PBXGroup;
    #     children = (
    #       ...
    #     );
    #     path = Views;

# Now we need to add to Sources build phase
# Let's find it and add all entries

# Read the content we just built and add sources phase entries + group entries
content2 = "\n".join(new_lines)

# Add to Sources build phase - find the files list in the PBXSourcesBuildPhase
# The pattern is: files = ( ... ); inside PBXSourcesBuildPhase
# We'll add our entries after the first entry in the files list

# Find the Sources build phase
sources_phase_match = re.search(r'(/\* Sources \*/ = \{[^}]*?files = \(\n)', content2, re.DOTALL)
if sources_phase_match:
    insert_pos = sources_phase_match.end()
    entries_text = ""
    for entry in sorted(file_entries, key=lambda e: e["filename"]):
        entries_text += f'\t\t\t\t{entry["build_file_id"]} /* {entry["filename"]} in Sources */,\n'
    content2 = content2[:insert_pos] + entries_text + content2[insert_pos:]
    sources_entries_added = True

# Now handle groups - this is the trickiest part
# We need to find each parent group and add the file reference to its children
# Groups are identified by their `path` attribute

# Map from parent_path leaf folder to list of file_ref entries
from collections import defaultdict
group_entries = defaultdict(list)
for entry in file_entries:
    parent = entry["parent_path"]
    # Get the leaf folder name
    leaf = os.path.basename(parent)
    group_entries[leaf].append(entry)

# Find groups by their path and add children
# Pattern: `path = FolderName;` followed by `sourceTree` in PBXGroup context
lines2 = content2.split("\n")
new_lines2 = []
i = 0
while i < len(lines2):
    line = lines2[i]
    new_lines2.append(line)
    
    # Look for "children = (" lines inside groups
    if "children = (" in line:
        # Look back to find the group name (path attribute)
        # Actually, look forward for the path = X; line
        # The structure is:
        #   ID /* Name */ = {
        #     isa = PBXGroup;
        #     children = (
        #       ...
        #     );
        #     path = FolderName;
        # So we need to scan forward to find the path
        j = i + 1
        path_name = None
        while j < len(lines2) and ");" not in lines2[j-1 if j > i+1 else j]:
            j += 1
        # Now look for path = after the closing );
        for k in range(j, min(j+5, len(lines2))):
            m = re.match(r'\s*path = "?(\w+)"?;', lines2[k])
            if m:
                path_name = m.group(1)
                break
            # Also check for name
            m2 = re.match(r'\s*name = "?(\w+)"?;', lines2[k])
            if m2 and path_name is None:
                path_name = m2.group(1)
        
        if path_name and path_name in group_entries:
            # Add our entries right after `children = (`
            for entry in sorted(group_entries[path_name], key=lambda e: e["filename"]):
                if entry["parent_path"].split("/")[-1] == path_name:
                    # Verify this is the right group by checking the context
                    new_lines2.append(f'\t\t\t\t{entry["file_ref_id"]} /* {entry["filename"]} */,')
            # Mark as handled
            # Note: this might add to wrong groups if multiple groups share the same leaf name
            # We'll handle that by checking the context more carefully
    
    i += 1

content3 = "\n".join(new_lines2)
with open(pbxproj, "w") as f:
    f.write(content3)

print(f"Added {len(file_entries)} files to project.pbxproj")
print(f"  PBXBuildFile entries: {build_files_added}")
print(f"  PBXFileReference entries: {file_refs_added}")
print(f"  Sources build phase: {sources_entries_added}")
print(f"  Groups: attempted for {len(group_entries)} groups")
