#!/usr/bin/env python3
"""Remove phantom file references from project.pbxproj.

These files are referenced in the project but the references point to wrong paths.
The files exist at correct paths and are already referenced correctly elsewhere.
We only remove the DUPLICATE wrong-path references.
"""
import re, os

PBXPROJ = os.path.join(os.path.dirname(__file__), "..", "Lyo.xcodeproj", "project.pbxproj")

# Files that are referenced from wrong group paths.
# We need to find which PBXFileReference IDs point to wrong locations and remove them.
# The error says:
#   Sources/Views/A2UIStudyPlanRenderers.swift  -> actual: Sources/Core/A2UI/Views/
#   Sources/Views/A2UIMistakeRenderers.swift    -> actual: Sources/Core/A2UI/Views/
#   Sources/Views/A2UIMiscRenderers.swift       -> actual: Sources/Core/A2UI/Views/
#   Sources/Views/A2UIHomeworkRenderers.swift    -> actual: Sources/Core/A2UI/Views/
#   Sources/Views/Community/CommunityPostModels.swift -> actual: Sources/Models/Community/
#   Sources/Views/Learning/PremiumQuizView.swift      -> actual: Sources/Components/Learning/

# Strategy: Find file refs for these names that are in wrong groups, 
# and remove their PBXBuildFile, PBXFileReference, group children, and source phase entries.

PHANTOM_FILES = [
    "A2UIStudyPlanRenderers.swift",
    "A2UIMistakeRenderers.swift", 
    "A2UIMiscRenderers.swift",
    "A2UIHomeworkRenderers.swift",
    "CommunityPostModels.swift",
    "PremiumQuizView.swift",
]


def main():
    with open(PBXPROJ, "r") as f:
        content = f.read()
    
    lines = content.split("\n")
    
    # For each phantom file, find ALL file reference IDs
    # Then determine which ones are in wrong groups and remove them
    for filename in PHANTOM_FILES:
        # Find all PBXFileReference IDs for this filename
        fref_pattern = re.compile(r'\s+(\w{24}) /\* ' + re.escape(filename) + r' \*/ = \{isa = PBXFileReference')
        frefs = []
        for i, line in enumerate(lines):
            m = fref_pattern.search(line)
            if m:
                frefs.append((m.group(1), i))
        
        if len(frefs) <= 1:
            # Only one reference exists, it's probably the correct one
            # or it's the only one and we shouldn't remove it
            print(f"  {filename}: {len(frefs)} ref(s), skipping")
            continue
        
        # We have duplicates. The "wrong" ones are those in groups that resolve to wrong paths.
        # For now, identify which frefs are actually used in the compile phase and which resolve correctly.
        # The safe approach: keep ALL frefs but make sure they're in correct groups.
        # Actually, the simplest fix: just find which fref IDs appear in the error path and remove those.
        print(f"  {filename}: {len(frefs)} refs found: {[f[0] for f in frefs]}")
    
    print("\nAnalysis complete. Use information above to decide what to remove.")
    
    # Actually, the simplest approach: find which groups contain these files  
    # and show the group paths for analysis
    for filename in PHANTOM_FILES:
        pattern = re.compile(r'(\w{24}) /\* ' + re.escape(filename) + r' \*/,')
        for i, line in enumerate(lines):
            m = pattern.search(line)
            if m:
                fref = m.group(1)
                # Look for nearby group info
                for j in range(i+1, min(i+15, len(lines))):
                    if "path = " in lines[j] and "sourceTree" not in lines[j]:
                        group_path = lines[j].strip()
                        print(f"  {filename} (fref {fref}) in group with {group_path} (line {i+1})")
                        break


if __name__ == "__main__":
    main()
