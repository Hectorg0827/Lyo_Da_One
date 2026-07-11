import re
from pathlib import Path

pbxproj_path = Path('/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj/project.pbxproj')
content = pbxproj_path.read_text(errors='ignore')

files_to_remove = [
    'CalendarService.swift',
    'GamificationService.swift',
    'EnhancedCameraManager.swift',
    'ContentStorageService.swift'
]

# Find the file references and build file IDs
file_ref_pattern = re.compile(r'([A-F0-9]{24})\s+/\* (.*?) \*/ = \{isa = PBXFileReference;.*?path = (.*?);.*?\}')
build_file_pattern = re.compile(r'([A-F0-9]{24})\s+/\* (.*?) in Sources \*/ = \{isa = PBXBuildFile; fileRef = ([A-F0-9]{24}) /\* .*? \*/; \}')

file_refs_to_remove = set()
build_files_to_remove = set()

for match in file_ref_pattern.finditer(content):
    file_id, name, path = match.groups()
    if any(f in path or f in name for f in files_to_remove):
        file_refs_to_remove.add(file_id)

for match in build_file_pattern.finditer(content):
    build_id, name, file_ref = match.groups()
    if file_ref in file_refs_to_remove:
        build_files_to_remove.add(build_id)

print(f"Found {len(file_refs_to_remove)} file references to remove")
print(f"Found {len(build_files_to_remove)} build files to remove")

# Remove lines containing these IDs
new_lines = []
for line in content.splitlines():
    should_keep = True
    for file_id in file_refs_to_remove:
        if file_id in line:
            should_keep = False
            break
    for build_id in build_files_to_remove:
        if build_id in line:
            should_keep = False
            break
    if should_keep:
        new_lines.append(line)

pbxproj_path.write_text('\n'.join(new_lines) + '\n')
print("Done removing missing files.")
