import re

text = open("/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj/project.pbxproj").read()

# Find PBXFileReference section
file_ref_section_match = re.search(r'Begin PBXFileReference section(.*?)End PBXFileReference section', text, re.DOTALL)
if not file_ref_section_match:
    print("No PBXFileReference section found")
    exit()

file_ref_section = file_ref_section_match.group(1)

uuids_to_check = {
    "EnhancedCameraManager.swift": ["5D949ECDB1A8A859D7238B60", "2F363D631F20871271C52060", "9FEDD03DE424106917F863D2"],
    "ContentStorageService.swift": ["5AB078523E95BE2C374F4CF9", "83CD1864418D8A3A4288A53A", "23821B56B350C3049BDD0D79"],
    "CalendarService.swift": ["28324C8FE07C6F01DA495801", "655C8DCE33476459BB8F34C3", "F08756E3E7819C0E73E63769"],
}

for fname, uuids in uuids_to_check.items():
    print(f"\n=== {fname} FileRef entries ===")
    for uuid in uuids:
        idx = file_ref_section.find(uuid)
        if idx >= 0:
            # Get the full line
            line_start = file_ref_section.rfind('\n', 0, idx) + 1
            line_end = file_ref_section.find('\n', idx)
            line = file_ref_section[line_start:line_end].strip()
            print(f"  FOUND: {line}")
        else:
            print(f"  NOT IN FileRef section: {uuid}")
            # Search in full text
            idx2 = text.find(uuid)
            if idx2 >= 0:
                line_start = text.rfind('\n', 0, idx2) + 1
                line_end = text.find('\n', idx2)
                line = text[line_start:line_end].strip()
                print(f"    Found elsewhere: {line}")
