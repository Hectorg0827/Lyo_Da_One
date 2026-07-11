import re

text = open("/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj/project.pbxproj").read()

# Find all file references for our targets and show their sourceTree/path details
targets = {
    "EnhancedCameraManager.swift": ["5D949ECDB1A8A859D7238B60", "2F363D631F20871271C52060", "9FEDD03DE424106917F863D2"],
    "ContentStorageService.swift": ["5AB078523E95BE2C374F4CF9", "83CD1864418D8A3A4288A53A", "23821B56B350C3049BDD0D79"],
    "CalendarService.swift": ["28324C8FE07C6F01DA495801", "655C8DCE33476459BB8F34C3", "F08756E3E7819C0E73E63769"],
}

for fname, uuids in targets.items():
    print(f"\n=== {fname} ===")
    for uuid in uuids:
        # Find line in pbxproj
        idx = text.find(uuid)
        if idx >= 0:
            line_start = text.rfind('\n', 0, idx) + 1
            line_end = text.find('\n', idx)
            line = text[line_start:line_end].strip()
            print(f"  {uuid}: {line}")
        else:
            print(f"  {uuid}: NOT FOUND")
