import re

text = open("/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj/project.pbxproj").read()

# Find all PBXFileReference entries for our targets
targets = ["EnhancedCameraManager.swift", "ContentStorageService.swift", "CalendarService.swift"]
for target in targets:
    print(f"\n=== {target} ===")
    # Match file reference blocks
    pattern = rf'([A-F0-9]{{24}}) /\* {re.escape(target)} \*/ = \{{[^}}]+\}};'
    matches = re.findall(pattern, text)
    for uuid in matches:
        # Get full entry
        entry_pat = rf'{uuid} /\* {re.escape(target)} \*/ = \{{[^}}]+\}};'
        entry = re.search(entry_pat, text)
        if entry:
            print(f"  {entry.group()}")

    # Also check what build files reference these
    print(f"\n  Build files:")
    bf_pattern = rf'([A-F0-9]{{24}}) /\* {re.escape(target)} in Sources \*/ = \{{[^}}]+\}};'
    bf_matches = list(re.finditer(bf_pattern, text))
    for m in bf_matches:
        print(f"  {m.group()}")
