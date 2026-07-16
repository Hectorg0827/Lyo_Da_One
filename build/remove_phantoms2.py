#!/usr/bin/env python3
"""Remove remaining phantom entries for A2UI renderers and CommunityPostModels.

These files exist at:
  Sources/Core/A2UI/Views/A2UI*Renderers.swift
  Sources/Models/Community/CommunityPostModels.swift
  
But have duplicate references in wrong Views groups resolving to:
  Sources/Views/A2UI*Renderers.swift
  Sources/Views/Community/CommunityPostModels.swift
  
We need to remove the SECOND occurrence of these frefs in group children 
(the ones at lines ~1089-1092 which are in a Views group),
and remove orphaned build file / source phase entries.
"""
import os

PBXPROJ = os.path.join(os.path.dirname(__file__), "..", "Lyo.xcodeproj", "project.pbxproj")

# These are the SECOND set of frefs that appear in wrong groups
# The frefs themselves are correct (they point to Core/A2UI/Views files)
# but they appear in BOTH the correct group AND a wrong Views group.
# We need to remove from the wrong Views group only.

# Wrong frefs for A2UI renderers (duplicate entries at lines ~1089-1092)
A2UI_WRONG_FREFS = [
    "7092070FB1572A32B69851AA",  # A2UIHomeworkRenderers.swift
    "E09D2C6CCC5884E56D1B8553",  # A2UIMiscRenderers.swift
    "E0B86941AC5B2233ADF004E7",  # A2UIMistakeRenderers.swift
    "6E94A6F5F9E7E46D1A098465",  # A2UIStudyPlanRenderers.swift
]

# CommunityPostModels fref that's in wrong Views/Community group
COMMUNITY_WRONG_FREF = "01F9AA72938357EAA357643A"


def main():
    with open(PBXPROJ, "r") as f:
        lines = f.readlines()

    # Strategy: For A2UI renderer frefs, remove only the SECOND occurrence
    # of each fref in group children (the first is in the correct Core/A2UI/Views group)
    
    # Track how many times we've seen each fref in group children
    seen_count = {}
    for fref in A2UI_WRONG_FREFS:
        seen_count[fref] = 0

    removals = 0
    new_lines = []
    for i, line in enumerate(lines):
        remove = False
        for fref in A2UI_WRONG_FREFS:
            if fref in line:
                stripped = line.strip()
                # Is this a group children entry? (format: <fref> /* filename */,)
                if stripped.startswith(fref) and stripped.endswith(","):
                    seen_count[fref] += 1
                    if seen_count[fref] > 1:
                        # This is the duplicate — remove it
                        remove = True
                        removals += 1
                        print(f"  Removed duplicate group entry at line {i+1}: {stripped[:60]}...")
                        break

        # For CommunityPostModels, remove the entry in the Views/Community group
        # It should be in Models/Community, not Views/Community
        # Look at context: the Views group is earlier in the file than Models group
        # Actually, we already removed one fref. The remaining one (01F9AA72...) 
        # appears in two groups. We need to remove from the Views/Community one.
        if not remove and COMMUNITY_WRONG_FREF in line:
            stripped = line.strip()
            if stripped.startswith(COMMUNITY_WRONG_FREF) and stripped.endswith(","):
                if "seen_community" not in dir():
                    seen_community = 0
                seen_community = getattr(main, '_community_count', 0) + 1
                main._community_count = seen_community
                if seen_community > 1:
                    remove = True
                    removals += 1
                    print(f"  Removed duplicate Community entry at line {i+1}")

        if not remove:
            new_lines.append(line)

    # Also remove duplicate Sources build phase entries
    # These show up as: <bref> /* filename in Sources */,
    # We need to keep only ONE per filename in the build phase
    
    final_lines = []
    seen_in_sources = {}
    in_sources_phase = False
    
    for line in new_lines:
        if "isa = PBXSourcesBuildPhase" in line:
            in_sources_phase = True
        if in_sources_phase and ");" in line.strip() and line.strip() == ");":
            in_sources_phase = False
        
        remove = False
        if in_sources_phase:
            for name in ["A2UIHomeworkRenderers.swift", "A2UIMiscRenderers.swift",
                         "A2UIMistakeRenderers.swift", "A2UIStudyPlanRenderers.swift",
                         "CommunityPostModels.swift"]:
                if name in line and "in Sources" in line:
                    if name not in seen_in_sources:
                        seen_in_sources[name] = True
                    else:
                        remove = True
                        removals += 1
                        print(f"  Removed duplicate source phase entry: {name}")
                        break
        
        if not remove:
            final_lines.append(line)

    with open(PBXPROJ, "w") as f:
        f.writelines(final_lines)

    print(f"\nTotal removals: {removals}")


main._community_count = 0

if __name__ == "__main__":
    main()
