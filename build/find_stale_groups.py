#!/usr/bin/env python3
"""Find which PBXGroup each target file reference belongs to."""
import re

with open('Lyo.xcodeproj/project.pbxproj', 'r') as f:
    lines = f.readlines()

targets = [
    'CommunityPostModels',
    'PremiumQuizView', 
    'A2UIStudyPlanRenderers',
    'A2UIMistakeRenderers',
    'A2UIMiscRenderers',
    'A2UIHomeworkRenderers',
]

# Parse all PBXGroup blocks
# Format:  ID /* GroupName */ = {
#              isa = PBXGroup;
#              children = (
#                  CHILDID /* ChildName */,
#                  ...
#              );
#              path = "...";  (or name = "...")

in_group = False
group_id = None
group_name = None
group_start_line = None
group_path = None
group_children = []

for i, line in enumerate(lines):
    stripped = line.strip()
    
    # Detect group start
    m = re.match(r'\s*([A-F0-9]{24})\s*/\*\s*(.*?)\s*\*/\s*=\s*\{', stripped)
    if m and i + 1 < len(lines) and 'PBXGroup' in lines[i+1]:
        in_group = True
        group_id = m.group(1)
        group_name = m.group(2)
        group_start_line = i + 1
        group_path = None
        group_children = []
        continue
    
    if in_group:
        # Check for path
        pm = re.match(r'\s*path\s*=\s*"?([^";]+)"?\s*;', stripped)
        if pm:
            group_path = pm.group(1)
        
        # Check for child references
        cm = re.match(r'\s*([A-F0-9]{24})\s*/\*\s*(.*?)\s*\*/', stripped)
        if cm:
            group_children.append((cm.group(1), cm.group(2), i + 1))
        
        # Detect group end
        if stripped == '};':
            # Check if any of our targets are in this group's children
            for child_id, child_name, child_line in group_children:
                for t in targets:
                    if t in child_name:
                        print(f"File: {child_name} (ID: {child_id})")
                        print(f"  In group: {group_name} (ID: {group_id})")
                        print(f"  Group path: {group_path}")
                        print(f"  Group line: {group_start_line}, child line: {child_line}")
                        print()
            in_group = False

print("---")
print("Now finding what parent groups contain these groups...")
print()

# Find full path by tracing group hierarchy
# First, collect all group info
groups = {}
in_group = False
for i, line in enumerate(lines):
    stripped = line.strip()
    m = re.match(r'\s*([A-F0-9]{24})\s*/\*\s*(.*?)\s*\*/\s*=\s*\{', stripped)
    if m and i + 1 < len(lines) and 'PBXGroup' in lines[i+1]:
        in_group = True
        gid = m.group(1)
        gname = m.group(2)
        groups[gid] = {'name': gname, 'children': [], 'path': None, 'line': i+1}
        current_gid = gid
        continue
    if in_group:
        pm = re.match(r'\s*path\s*=\s*"?([^";]+)"?\s*;', stripped)
        if pm:
            groups[current_gid]['path'] = pm.group(1)
        cm = re.match(r'\s*([A-F0-9]{24})\s*/\*\s*(.*?)\s*\*/', stripped)
        if cm:
            groups[current_gid]['children'].append(cm.group(1))
        if stripped == '};':
            in_group = False

# Build parent map
parent_map = {}
for gid, ginfo in groups.items():
    for child in ginfo['children']:
        parent_map[child] = gid

def get_full_path(gid):
    path_parts = []
    current = gid
    while current in parent_map:
        g = groups.get(current)
        if g:
            path_parts.insert(0, g.get('path') or g['name'])
        current = parent_map[current]
    # Add the root
    g = groups.get(current)
    if g:
        path_parts.insert(0, g.get('path') or g['name'])
    return '/'.join(path_parts)

# Find the groups that contain our target files
target_file_ids = {
    '01F9AA72938357EAA357643A': 'CommunityPostModels.swift',
    '102D00F5D459B0EB25C13F29': 'PremiumQuizView.swift',
    '6C635A279950F3A4D52D7C11': 'PremiumQuizView.swift (dup)',
    '6E94A6F5F9E7E46D1A098465': 'A2UIStudyPlanRenderers.swift',
    '7092070FB1572A32B69851AA': 'A2UIHomeworkRenderers.swift',
    'E09D2C6CCC5884E56D1B8553': 'A2UIMiscRenderers.swift',
    'E0B86941AC5B2233ADF004E7': 'A2UIMistakeRenderers.swift',
}

for fid, fname in target_file_ids.items():
    if fid in parent_map:
        parent_gid = parent_map[fid]
        full_path = get_full_path(fid)
        print(f"{fname} (ID: {fid})")
        print(f"  Current full path: {full_path}")
        parent_g = groups.get(parent_gid, {})
        print(f"  Direct parent group: {parent_g.get('name')} (path={parent_g.get('path')})")
        print()
    else:
        print(f"{fname} (ID: {fid}) -- NOT found in any group children")
        print()
