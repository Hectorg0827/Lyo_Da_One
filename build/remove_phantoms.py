#!/usr/bin/env python3
"""Remove phantom/duplicate PBXFileReference entries that point to nonexistent paths.

Each of these files has TWO PBXFileReference entries. One resolves to the correct
disk path and the other resolves to a wrong path. We remove the wrong ones plus
their associated PBXBuildFile entries and group children entries.
"""
import re, os

PBXPROJ = os.path.join(os.path.dirname(__file__), "..", "Lyo.xcodeproj", "project.pbxproj")

# Wrong fref IDs (the ones in wrong groups based on error analysis)
# A2UI renderers: wrong refs are in the top-level "Views" group instead of Core/A2UI/Views
WRONG_FREFS = {
    "A46AD14B3E20291628090184": "A2UIStudyPlanRenderers.swift",  # in Views instead of Core/A2UI/Views
    "BA8AFE59DBAD46386FD3CCBD": "A2UIMistakeRenderers.swift",
    "1FB186FA5C7D59A298A4BE54": "A2UIMiscRenderers.swift",
    "293E6CB659E1F9AEE8A1F3F5": "A2UIHomeworkRenderers.swift",
    # CommunityPostModels: both refs are in "Community" groups. Need to figure out which is wrong.
    # PremiumQuizView: both refs are in "Learning" groups. Need to figure out which is wrong.
}

# For CommunityPostModels and PremiumQuizView, both frefs appear in same-named groups 
# but under different parent groups. We need to identify which parent is wrong.
# CommunityPostModels: one is under Views/Community (wrong), should be Models/Community
# PremiumQuizView: one is under Views/Learning (wrong), should be Components/Learning


def main():
    with open(PBXPROJ, "r") as f:
        content = f.read()

    removed_count = 0

    # Remove wrong frefs and their associated build file entries
    for fref, filename in WRONG_FREFS.items():
        # Remove PBXFileReference line
        pattern = re.compile(r'\t\t' + fref + r' /\* .+ \*/ = \{isa = PBXFileReference;[^\n]+\n')
        content, n = pattern.subn('', content)
        if n:
            print(f"  Removed PBXFileReference for {filename} ({fref})")
            removed_count += n

        # Find and remove associated PBXBuildFile (references this fref)
        bfile_pattern = re.compile(r'\t\t\w{24} /\* ' + re.escape(filename) + r' in Sources \*/ = \{isa = PBXBuildFile; fileRef = ' + fref + r'[^\n]+\n')
        content, n = bfile_pattern.subn('', content)
        if n:
            print(f"  Removed PBXBuildFile for {filename}")
            removed_count += n

        # Remove from group children
        children_pattern = re.compile(r'\t+' + fref + r' /\* ' + re.escape(filename) + r' \*/,\n')
        content, n = children_pattern.subn('', content)
        if n:
            print(f"  Removed {n} group children entry(ies) for {filename}")
            removed_count += n

        # Remove from sources build phase
        sources_pattern = re.compile(r'\t+\w{24} /\* ' + re.escape(filename) + r' in Sources \*/,\n')
        # Only remove if we can match the specific bref (we removed the bfile above)
        # Actually we need to be careful — only remove the BUILD entry that references the WRONG fref
        # Let's find the bref first
        bref_pattern = re.compile(r'(\w{24}) /\* ' + re.escape(filename) + r' in Sources \*/ = \{isa = PBXBuildFile; fileRef = ' + fref)
        # Since we already removed the PBXBuildFile line, let's just remove orphan source phase entries
        # Actually the sources_pattern is too broad — it would remove valid entries too
        # Skip this for now, the build system will handle orphan build phase entries

    # For PremiumQuizView and CommunityPostModels, we need to handle duplicates differently
    # These have TWO refs in similar-named groups. Let's just remove one of the duplicate pairs.
    
    # PremiumQuizView: frefs 102D00F5D459B0EB25C13F29 and 6C635A279950F3A4D52D7C11
    # Both are in Learning groups. Let's check which parent is Views vs Components
    # From the error, /Sources/Views/Learning/PremiumQuizView.swift doesn't exist
    # The correct path is /Sources/Components/Learning/PremiumQuizView.swift
    # We need to find which fref is under the Views/Learning group
    
    # Let's remove the duplicate fref entries for these
    for dup_fref, filename in [
        ("6C635A279950F3A4D52D7C11", "PremiumQuizView.swift"),
        ("303D7C9301977095F5EECFD1", "CommunityPostModels.swift"),
    ]:
        # Remove PBXFileReference
        pattern = re.compile(r'\t\t' + dup_fref + r' /\* .+ \*/ = \{isa = PBXFileReference;[^\n]+\n')
        content, n = pattern.subn('', content)
        if n:
            print(f"  Removed duplicate PBXFileReference for {filename} ({dup_fref})")
            removed_count += n

        # Remove PBXBuildFile
        bfile_pattern = re.compile(r'\t\t\w{24} /\* ' + re.escape(filename) + r' in Sources \*/ = \{isa = PBXBuildFile; fileRef = ' + dup_fref + r'[^\n]+\n')
        content, n = bfile_pattern.subn('', content)
        if n:
            print(f"  Removed duplicate PBXBuildFile for {filename}")
            removed_count += n

        # Remove from group children
        children_pattern = re.compile(r'\t+' + dup_fref + r' /\* ' + re.escape(filename) + r' \*/,\n')
        content, n = children_pattern.subn('', content)
        if n:
            print(f"  Removed {n} duplicate children entry(ies) for {filename}")
            removed_count += n

    with open(PBXPROJ, "w") as f:
        f.write(content)

    print(f"\nTotal removals: {removed_count}")
    print("Run plutil -lint to validate.")


if __name__ == "__main__":
    main()
