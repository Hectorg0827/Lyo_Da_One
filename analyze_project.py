import os
import re

def parse_pbxproj(pbxproj_path):
    try:
        with open(pbxproj_path, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"Error: Could not find {pbxproj_path}")
        return []

    file_refs = []
    lines = content.split('\n')
    for line in lines:
        if 'isa = PBXFileReference' in line:
            match = re.search(r'path = ([^;]+);', line)
            if match:
                path = match.group(1).strip('"')
                file_refs.append(path)
    
    return file_refs

def get_files_on_disk(root_dir):
    file_list = []
    for root, dirs, files in os.walk(root_dir):
        for file in files:
            if file.endswith('.swift') or file.endswith('.xcassets') or file.endswith('.plist'):
                file_list.append(file)
    return file_list

def main():
    # Use relative paths assuming we run from the root
    project_path = 'Lyo.xcodeproj/project.pbxproj'
    sources_path = 'Sources'
    
    project_files = parse_pbxproj(project_path)
    disk_files = get_files_on_disk(sources_path)
    
    print(f"Found {len(project_files)} file references in project.")
    print(f"Found {len(disk_files)} files on disk in {sources_path}.")
    
    from collections import Counter
    counts = Counter(project_files)
    duplicates = [f for f, c in counts.items() if c > 1]
    
    if duplicates:
        print("\nDuplicate file references in project:")
        for d in duplicates:
            print(f"DUPLICATE: {d}")
    else:
        print("\nNo duplicate file references found in project.")

    project_filenames = set([os.path.basename(f) for f in project_files])
    
    missing_in_project = []
    for f in disk_files:
        if f not in project_filenames:
            missing_in_project.append(f)
            
    if missing_in_project:
        print("\nFiles on disk but NOT in project (candidates to add):")
        for f in missing_in_project:
            print(f"MISSING_IN_PROJECT: {f}")

    disk_filenames = set(disk_files)
    missing_on_disk = []
    for f in project_files:
        if '.' not in f: continue 
        if os.path.basename(f) not in disk_filenames:
             if not f.endswith('.framework') and not f.endswith('.appiconset') and not f.endswith('.colorset'):
                missing_on_disk.append(f)

    if missing_on_disk:
        print("\nFiles in project but NOT on disk (candidates to remove):")
        for f in missing_on_disk:
            print(f"MISSING_ON_DISK: {f}")

if __name__ == '__main__':
    main()
