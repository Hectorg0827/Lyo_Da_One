import re

text = open("/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj/project.pbxproj").read()

# Find PBXGroup section
group_section_match = re.search(r'Begin PBXGroup section(.*?)End PBXGroup section', text, re.DOTALL)
if not group_section_match:
    print("No PBXGroup section found")
    exit()

group_section = group_section_match.group(1)

# Build a map of UUID -> group UUID (which group contains this UUID)
# Parse all groups
group_blocks = re.findall(r'([A-F0-9]{24}) /\*.*?\*/ = \{[^{]*?children = \([^)]*?\);[^}]*?\};', group_section, re.DOTALL)

uuid_to_group = {}
for block_match in re.finditer(r'([A-F0-9]{24}) /\* (.*?) \*/ = \{.*?children = \((.*?)\);', group_section, re.DOTALL):
    group_uuid = block_match.group(1)
    group_name = block_match.group(2)
    children_str = block_match.group(3)
    children = re.findall(r'([A-F0-9]{24})', children_str)
    for child in children:
        uuid_to_group[child] = (group_uuid, group_name)

# Get group paths
group_paths = {}
for m in re.finditer(r'([A-F0-9]{24}) /\* (.*?) \*/ = \{.*?(?:path = ([^;]+);)?.*?\};', group_section, re.DOTALL):
    g_uuid = m.group(1)
    g_name = m.group(2)
    g_path = m.group(3)
    group_paths[g_uuid] = (g_name, g_path)

all_uuids = [
    ("EnhancedCameraManager.swift", ["5D949ECDB1A8A859D7238B60", "2F363D631F20871271C52060", "9FEDD03DE424106917F863D2"]),
    ("ContentStorageService.swift", ["5AB078523E95BE2C374F4CF9", "83CD1864418D8A3A4288A53A", "23821B56B350C3049BDD0D79"]),
    ("CalendarService.swift", ["28324C8FE07C6F01DA495801", "655C8DCE33476459BB8F34C3", "F08756E3E7819C0E73E63769"]),
]

for fname, uuids in all_uuids:
    print(f"\n=== {fname} ===")
    for uuid in uuids:
        parent = uuid_to_group.get(uuid)
        if parent:
            g_uuid, g_name = parent
            g_info = group_paths.get(g_uuid, ("?", "?"))
            print(f"  {uuid} -> in group '{g_name}' ({g_uuid}), path={g_info[1]}")
        else:
            print(f"  {uuid} -> NOT FOUND in any group!")
