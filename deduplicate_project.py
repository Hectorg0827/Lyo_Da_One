
import re

project_path = "/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj/project.pbxproj"

def deduplicate_project():
    try:
        with open(project_path, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"Error: Project file not found at {project_path}")
        return

    # 1. Find the PBXSourcesBuildPhase
    # section looks like:
    # 5A5D48925F6459B724CC5F4C /* Sources */ = {
    #    isa = PBXSourcesBuildPhase;
    #    buildActionMask = 2147483647;
    #    files = (
    #        567890123456789012345678 /* SomeFile.swift in Sources */,
    #        ...
    #    );
    #    runOnlyForDeploymentPostprocessing = 0;
    # };

    sources_phase_pattern = r'(isa = PBXSourcesBuildPhase;[^}]*?files = \()([^)]+)(\);)'
    match = re.search(sources_phase_pattern, content, re.DOTALL)
    
    if not match:
        print("Could not find PBXSourcesBuildPhase")
        return

    full_match = match.group(0)
    files_core_content = match.group(2)
    
    # 2. Parse lines (file refs)
    # Line format: UUID /* Name in Sources */,
    lines = [line.strip() for line in files_core_content.split('\n') if line.strip()]
    
    seen_filenames = set()
    unique_lines = []
    removed_count = 0
    
    for line in lines:
        # Extract filename from comment: "UUID /* Filename.swift in Sources */,"
        # Regex to capture content between /* and */
        comment_match = re.search(r'/\* (.+?) in Sources \*/', line)
        if comment_match:
            filename = comment_match.group(1)
            if filename in seen_filenames:
                removed_count += 1
                # print(f"Removing duplicate: {filename}")
                continue
            seen_filenames.add(filename)
            unique_lines.append(line)
        else:
            # Fallback if regex fails (keep it to be safe)
            unique_lines.append(line)

    if removed_count == 0:
        print("No duplicates found in Compile Sources phase.")
        return

    print(f"Removed {removed_count} duplicates.")

    # 3. Reconstruct the section
    new_files_content = "\n\t\t\t\t" + "\n\t\t\t\t".join(unique_lines) + "\n\t\t\t"
    
    # Replace only the files section inside the sources build phase
    # Be careful to replace ONLY the match inside the Sources Phase, not elsewhere.
    
    # We reconstruct the whole match block
    original_start = match.group(1) # isa ... files = (
    original_end = match.group(3)   # );
    
    new_block = f"{original_start}{new_files_content}{original_end}"
    
    new_project_content = content.replace(full_match, new_block)
    
    with open(project_path, 'w') as f:
        f.write(new_project_content)
        
    print("Project file updated successfully.")

if __name__ == "__main__":
    deduplicate_project()
