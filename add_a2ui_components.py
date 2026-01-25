#!/usr/bin/env python3
"""
Script to add A2UIComponentViews.swift to Xcode project
"""
import os
import re
import uuid

# Files that are missing from the Xcode project
MISSING_FILES = [
    "Sources/Components/AITutor/A2UIComponentViews.swift"
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
    
    # Extract the main Sources build phase UUID
    build_phase_match = re.search(r'([A-F0-9]{24}) /\* Sources \*/ = \{\s*isa = PBXSourcesBuildPhase;', content)
    if not build_phase_match:
        print("ERROR: Could not find PBXSourcesBuildPhase")
        return False
    build_phase_uuid = build_phase_match.group(1)
    
    new_files_content = ""
    new_build_files_content = ""
    build_phase_additions = ""
    group_children_additions = ""
    
    for file_path in MISSING_FILES:
        filename = os.path.basename(file_path)
        file_uuid = generate_uuid()
        build_uuid = generate_uuid()
        
        # Entry for PBXFileReference
        # C8FAC8232D305D6D00BD8023 /* CourseSocialService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = CourseSocialService.swift; sourceTree = "<group>"; };
        new_files_content += f'\t\t{file_uuid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};\n'
        
        # Entry for PBXBuildFile
        # C8FAC82E2D305D6D00BD8023 /* CourseSocialService.swift in Sources */ = {isa = PBXBuildFile; fileRef = C8FAC8232D305D6D00BD8023 /* CourseSocialService.swift */; };
        new_build_files_content += f'\t\t{build_uuid} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuid} /* {filename} */; }};\n'
        
        # Addition to PBXSourcesBuildPhase
        build_phase_additions += f'\t\t\t\t{build_uuid} /* {filename} in Sources */,\n'
        
        # Addition to Sources Group
        group_children_additions += f'\t\t\t\t{file_uuid} /* {filename} */,\n'
        
        print(f"Generated entries for: {filename}")

    # Inject into PBXBuildFile section
    marker = "/* Begin PBXBuildFile section */"
    if marker in content:
        content = content.replace(marker, marker + "\n" + new_build_files_content)
        print(f"Added {len(MISSING_FILES)} PBXBuildFile entries")
    
    # Inject into PBXFileReference section
    marker = "/* Begin PBXFileReference section */"
    if marker in content:
        content = content.replace(marker, marker + "\n" + new_files_content)
        print(f"Added {len(MISSING_FILES)} PBXFileReference entries")
        
    # Inject into PBXSourcesBuildPhase
    marker = f"{build_phase_uuid} /* Sources */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = ("
    if marker in content:
        content = content.replace(marker, marker + "\n" + build_phase_additions)
        print(f"Added {len(MISSING_FILES)} build file references to PBXSourcesBuildPhase")
        
    # Inject into Sources Group
    marker = f"{sources_group_uuid} /* Sources */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = ("
    if marker in content:
        content = content.replace(marker, marker + "\n" + group_children_additions)
        print(f"Added {len(MISSING_FILES)} file references to Sources group")

    # Write back
    write_project_file(project_path, content)
    return True

if __name__ == "__main__":
    project_path = os.path.join(os.getcwd(), "Lyo.xcodeproj/project.pbxproj")
    if os.path.exists(project_path):
        # Create backup
        backup_path = project_path + ".backup"
        content = read_project_file(project_path)
        write_project_file(backup_path, content)
        print(f"Creating backup at: {backup_path}")
        
        if add_files_to_project(project_path, os.getcwd()):
            print("✅ Successfully added A2UI components to Xcode project!")
    else:
        print(f"ERROR: Project file not found at {project_path}")
