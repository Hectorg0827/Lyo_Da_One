import re

text = open("/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj/project.pbxproj").read()

# Parse all groups and their children
groups = {}  # uuid -> {name, path, sourceTree, children}
for m in re.finditer(r'([A-F0-9]{24}) /\* (.*?) \*/ = \{[^}]*?isa = PBXGroup;.*?(?:name = ([^;]+);)?.*?(?:path = ([^;]+);)?.*?(?:sourceTree = ([^;]+);)?.*?children = \((.*?)\);', text, re.DOTALL):
    uuid = m.group(1)
    comment = m.group(2)
    groups[uuid] = {
        'comment': comment,
        'children': re.findall(r'([A-F0-9]{24})', m.group(6))
    }

# Build reverse map: child_uuid -> parent_group_uuid
child_to_parent = {}
for g_uuid, g_data in groups.items():
    for child in g_data['children']:
        child_to_parent[child] = g_uuid

# Get full path for a group by walking up parents
def get_group_path(g_uuid, visited=None):
    if visited is None:
        visited = set()
    if g_uuid in visited:
        return "CYCLE"
    visited.add(g_uuid)
    
    # Find this group's entry in the raw text
    m = re.search(rf'{g_uuid} /\* (.*?) \*/ = \{{[^}}]*?isa = PBXGroup;.*?(?:path = ([^;]+);)?.*?sourceTree = ([^;]+);', text, re.DOTALL)
    if not m:
        return f"GROUP({g_uuid[:8]})"
    
    name = m.group(1)
    path = m.group(2) or ""
    source_tree = m.group(3).strip()
    
    path = path.strip().strip('"')
    
    if source_tree.strip() == '"SOURCE_ROOT"' or source_tree.strip() == 'SOURCE_ROOT':
        return path
    elif source_tree.strip() == '"<group>"' or source_tree.strip() == '<group>':
        parent = child_to_parent.get(g_uuid)
        if parent:
            parent_path = get_group_path(parent, visited)
            return f"{parent_path}/{path}" if path else parent_path
        return path
    else:
        return f"[{source_tree}]/{path}"

# Check our file references
file_uuids = {
    "EnhancedCameraManager.swift": ["5D949ECDB1A8A859D7238B60", "2F363D631F20871271C52060", "9FEDD03DE424106917F863D2"],
    "ContentStorageService.swift": ["5AB078523E95BE2C374F4CF9", "83CD1864418D8A3A4288A53A", "23821B56B350C3049BDD0D79"],
    "CalendarService.swift": ["28324C8FE07C6F01DA495801", "655C8DCE33476459BB8F34C3", "F08756E3E7819C0E73E63769"],
}

for fname, uuids in file_uuids.items():
    print(f"\n=== {fname} ===")
    for uuid in uuids:
        parent_group = child_to_parent.get(uuid)
        if parent_group:
            group_path = get_group_path(parent_group)
            print(f"  {uuid} -> group path: '{group_path}'")
        else:
            print(f"  {uuid} -> NOT IN ANY GROUP (orphan)")
