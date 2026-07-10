#!/usr/bin/env python3
"""Fix PBXGroup assignments for the 7 new agentic pipeline files."""
import re, sys, os

PBXPROJ = os.path.join(os.path.dirname(__file__), "..", "Lyo.xcodeproj", "project.pbxproj")

# File ref IDs from the add script
FILES_TO_ADD = {
    # fref -> (filename, target_group_id)
    "64CAB44F5729FD106E3C9842": ("AgentBlock.swift", "DF435C208AF6FC140443C26B"),           # Models
    "ACE73BF794321E626A98FF15": ("GeneratedContentStore.swift", "8A978EE0169561752DD14E2B"),# Services
    "6C5E7B8EC97FABC580333785": ("MessageIntentClassifier.swift", "8A978EE0169561752DD14E2B"),# Services
    "66BC62302B031650D95F06E5": ("ChatRouter.swift", "8A978EE0169561752DD14E2B"),           # Services
    "4F78631CAF8C0B437480F6A5": ("AgenticClassroomViewModel.swift", "357CD9AF4B97AF23F9390299"),# ViewModels
}

# A2UIContentSynthesizer needs to MOVE from wrong group to right group
MOVE_FILE = {
    "fref": "DA4EB73E5C999B34EEDA2E3D",
    "filename": "A2UIContentSynthesizer.swift",
    "wrong_group": "A96E3673F86328A1F214797C",  # Services/A2UI
    "right_group": "0798296FFF0928DBC23F4D1E",  # Core/A2UI
}


def main():
    with open(PBXPROJ, "r") as f:
        lines = f.readlines()

    # Step 1: Remove A2UIContentSynthesizer from wrong A2UI group
    move_fref = MOVE_FILE["fref"]
    move_line = f"{move_fref} /* {MOVE_FILE['filename']} */"
    removed = False
    for i, line in enumerate(lines):
        if move_fref in line and "children" not in line and "isa = PBXGroup" not in line:
            # Check if this is in the children list (not the PBXFileReference or PBXBuildFile)
            # It should be a line like: \t\t\t\t<fref> /* filename */,
            stripped = line.strip()
            if stripped.startswith(move_fref) and stripped.endswith(","):
                # Make sure it's in the wrong group by checking nearby group ID
                # Look ahead for group ID
                for j in range(i+1, min(i+20, len(lines))):
                    if MOVE_FILE["wrong_group"] in lines[j]:
                        lines.pop(i)
                        removed = True
                        print(f"  Removed {MOVE_FILE['filename']} from wrong A2UI group at line {i+1}")
                        break
                if removed:
                    break

    if not removed:
        print(f"  WARNING: Could not find {MOVE_FILE['filename']} in wrong group to remove")

    # Step 2: For each file, find the target group and add to children
    # Also add A2UIContentSynthesizer to the right group
    all_files = dict(FILES_TO_ADD)
    all_files[MOVE_FILE["fref"]] = (MOVE_FILE["filename"], MOVE_FILE["right_group"])

    for fref, (filename, target_group_id) in all_files.items():
        # Check if already in the right group
        already_in = False
        for i, line in enumerate(lines):
            if fref in line and line.strip().startswith(fref) and line.strip().endswith(","):
                # Check if nearby group is the target
                for j in range(i+1, min(i+20, len(lines))):
                    if target_group_id in lines[j]:
                        already_in = True
                        break
                if already_in:
                    break

        if already_in:
            print(f"  {filename} already in correct group")
            continue

        # Find the target group and its children = ( line
        in_target = False
        inserted = False
        for i, line in enumerate(lines):
            if target_group_id in line and "isa = PBXGroup" in lines[i+1] if i+1 < len(lines) else False:
                in_target = True
                continue
            if in_target and "children = (" in line:
                # Insert right after children = (
                insert_line = f"\t\t\t\t{fref} /* {filename} */,\n"
                lines.insert(i+1, insert_line)
                inserted = True
                in_target = False
                print(f"  Added {filename} to group {target_group_id}")
                break

        if not inserted:
            print(f"  WARNING: Could not find group {target_group_id} for {filename}")

    with open(PBXPROJ, "w") as f:
        f.writelines(lines)

    print("\nDone fixing group assignments!")


if __name__ == "__main__":
    main()
