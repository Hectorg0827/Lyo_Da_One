import re

text = open("Lyo.xcodeproj/project.pbxproj").read()

# Find the PBXSourcesBuildPhase section
src_match = re.search(r'Begin PBXSourcesBuildPhase section(.*?)End PBXSourcesBuildPhase section', text, re.DOTALL)
if src_match:
    src_section = src_match.group(1)
    files_in_phase = re.findall(r'([A-F0-9]{24})\s*/\*.*?\*/', src_section)
    print(f"Total files in Sources build phase: {len(files_in_phase)}")
    
    for target in ["EnhancedCameraManager.swift", "ContentStorageService.swift", "CalendarService.swift"]:
        build_file_uuids = re.findall(rf'([A-F0-9]{{24}}) /\* {re.escape(target)} in Sources \*/', text)
        print(f"\n{target}:")
        print(f"  PBXBuildFile entries: {build_file_uuids}")
        for uuid in build_file_uuids:
            in_phase = uuid in src_section
            print(f"  {uuid} in Sources phase: {in_phase}")
        
        # Find file references
        file_refs = re.findall(rf'([A-F0-9]{{24}}) /\* {re.escape(target)} \*/ = \{{.*?path = {re.escape(target)}.*?\}};', text)
        print(f"  FileRef entries: {len(file_refs)}")
