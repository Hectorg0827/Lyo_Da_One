#!/usr/bin/env python3
"""
Script to add missing Swift files to Xcode project
"""
import os
import re
import uuid

# Files that are missing from the Xcode project
MISSING_FILES = [
    "Sources/Core/Services/CourseSocialService.swift",
    "Sources/Core/Services/CourseLibraryService.swift",
    "Sources/Core/Services/CourseShareService.swift",
    "Sources/Core/Networking/OfflineQueueManager.swift",
    "Sources/Services/UserContextService.swift",
    "Sources/Services/SmartMemoryService.swift",
    "Sources/Services/SoftSkillsService.swift",
    "Sources/Views/Main/AdaptiveHomeView.swift",
    "Sources/Views/Components/ProactiveHintBanner.swift",
    "Sources/Views/Profile/HolisticProfileView.swift",
    "Sources/Views/Main/Creation/CreateHubView.swift",
    "Sources/Views/Main/Creation/MultiModeCreationView.swift",
]

def generate_uuid():
    """Generate a UUID in Xcode format (24 hex chars)"""
    return uuid.uuid4().hex[:24].upper()

def read_project_file(project_path):
    """Read the project.pbxproj file"""
    with open(project_path, 'r', encoding='utf-8') as f:
        return f.read()

def write_project_file(project_path, content):
    """Write the project.pbxproj file"""
    with open(project_path, 'w', encoding='utf-8') as f:
        f.write(content)

def add_files_to_project(project_path, base_dir):
    """Add all missing files to the Xcode project"""
    print(f"Reading project file: {project_path}")
    content = read_project_file(project_path)

    # Extract the main group UUID for Sources
    sources_group_match = re.search(r'([A-F0-9]{24}) /\* Sources \*/', content)
    if not sources_group_match:
        print("ERROR: Could not find Sources group")
        return False
    sources_group_uuid = sources_group_match.group(1)
    print(f"Found Sources group UUID: {sources_group_uuid}")

    # Extract the PBXSourcesBuildPhase UUID
    build_phase_match = re.search(r'([A-F0-9]{24}) /\* Sources \*/ = \{[^}]+isa = PBXSourcesBuildPhase', content, re.DOTALL)
    if not build_phase_match:
        print("ERROR: Could not find PBXSourcesBuildPhase")
        return False
    build_phase_uuid = build_phase_match.group(1)
    print(f"Found PBXSourcesBuildPhase UUID: {build_phase_uuid}")

    # Storage for new entries
    file_references = []
    build_files = []
    file_refs_by_uuid = {}

    # Generate UUIDs and entries for each missing file
    for file_path in MISSING_FILES:
        filename = os.path.basename(file_path)
        file_ref_uuid = generate_uuid()
        build_file_uuid = generate_uuid()

        file_refs_by_uuid[file_ref_uuid] = (filename, file_path)

        # Create PBXFileReference entry (use full path from project root)
        file_ref_entry = f"\t\t{file_ref_uuid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{file_path}\"; sourceTree = SOURCE_ROOT; }};"
        file_references.append(file_ref_entry)

        # Create PBXBuildFile entry
        build_file_entry = f"\t\t{build_file_uuid} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* {filename} */; }};"
        build_files.append(build_file_entry)

        print(f"Generated entries for: {filename}")

    # Find insertion points and add entries

    # 1. Add PBXBuildFile entries
    pbx_build_file_section = re.search(r'(/\* Begin PBXBuildFile section \*/\n)', content)
    if pbx_build_file_section:
        insert_pos = pbx_build_file_section.end()
        content = content[:insert_pos] + '\n'.join(build_files) + '\n' + content[insert_pos:]
        print(f"Added {len(build_files)} PBXBuildFile entries")
    else:
        print("ERROR: Could not find PBXBuildFile section")
        return False

    # 2. Add PBXFileReference entries
    pbx_file_ref_section = re.search(r'(/\* Begin PBXFileReference section \*/\n)', content)
    if pbx_file_ref_section:
        insert_pos = pbx_file_ref_section.end()
        content = content[:insert_pos] + '\n'.join(file_references) + '\n' + content[insert_pos:]
        print(f"Added {len(file_references)} PBXFileReference entries")
    else:
        print("ERROR: Could not find PBXFileReference section")
        return False

    # 3. Add files to PBXSourcesBuildPhase
    build_phase_pattern = rf'({build_phase_uuid} /\* Sources \*/ = \{{[^}}]+files = \(\n)'
    build_phase_match = re.search(build_phase_pattern, content, re.DOTALL)
    if build_phase_match:
        insert_pos = build_phase_match.end()
        build_file_refs = [f"\t\t\t\t{uuid.uuid4().hex[:24].upper()} /* {filename} in Sources */,"
                          for uuid_val, (filename, _) in file_refs_by_uuid.items()]
        # Use the actual build file UUIDs
        build_file_refs = []
        for file_path in MISSING_FILES:
            filename = os.path.basename(file_path)
            build_file_uuid = [line.split()[0] for line in build_files if filename in line][0]
            build_file_refs.append(f"\t\t\t\t{build_file_uuid} /* {filename} in Sources */,")

        content = content[:insert_pos] + '\n'.join(build_file_refs) + '\n' + content[insert_pos:]
        print(f"Added {len(build_file_refs)} build file references to PBXSourcesBuildPhase")
    else:
        print("ERROR: Could not find PBXSourcesBuildPhase files array")
        return False

    # 4. Add file references to appropriate PBXGroup sections
    # We need to organize files by their directory structure

    # For simplicity, add all files to the Sources group's children array
    sources_group_pattern = rf'({sources_group_uuid} /\* Sources \*/ = \{{[^}}]+children = \(\n)'
    sources_group_match = re.search(sources_group_pattern, content, re.DOTALL)
    if sources_group_match:
        insert_pos = sources_group_match.end()
        file_ref_children = []
        for file_ref_uuid, (filename, file_path) in file_refs_by_uuid.items():
            file_ref_children.append(f"\t\t\t\t{file_ref_uuid} /* {filename} */,")

        content = content[:insert_pos] + '\n'.join(file_ref_children) + '\n' + content[insert_pos:]
        print(f"Added {len(file_ref_children)} file references to Sources group")
    else:
        print("WARNING: Could not find Sources group children array, files may not appear in navigator")

    # Write the updated project file
    print(f"Writing updated project file...")
    write_project_file(project_path, content)
    print("✅ Successfully added all missing files to Xcode project!")
    return True

if __name__ == '__main__':
    project_path = '/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj/project.pbxproj'
    base_dir = '/Users/hectorgarcia/LYO_Da_ONE'

    if not os.path.exists(project_path):
        print(f"ERROR: Project file not found at {project_path}")
        exit(1)

    # Backup the project file first
    backup_path = project_path + '.backup'
    print(f"Creating backup at: {backup_path}")
    with open(project_path, 'r') as src, open(backup_path, 'w') as dst:
        dst.write(src.read())

    success = add_files_to_project(project_path, base_dir)
    exit(0 if success else 1)
