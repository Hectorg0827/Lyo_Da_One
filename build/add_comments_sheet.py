#!/usr/bin/env python3
"""Add CommentsSheet.swift to Xcode project pbxproj."""
import re
import uuid
from pathlib import Path

def make_uuid():
    return uuid.uuid4().hex[:24].upper()

pbxproj_path = Path("Lyo.xcodeproj/project.pbxproj")
text = pbxproj_path.read_text()

# Check if already added
if "CommentsSheet.swift" in text:
    print("CommentsSheet.swift already in pbxproj")
    exit(0)

# Find sibling ReelActionStrip.swift UUIDs
build_match = re.search(
    r'([A-F0-9]{24}) /\* ReelActionStrip\.swift in Sources \*/ = \{isa = PBXBuildFile; fileRef = ([A-F0-9]{24})',
    text
)
if not build_match:
    print("ERROR: Could not find ReelActionStrip.swift in pbxproj")
    exit(1)

sibling_build_uuid = build_match.group(1)
sibling_ref_uuid = build_match.group(2)
print(f"Sibling build UUID: {sibling_build_uuid}")
print(f"Sibling fileRef UUID: {sibling_ref_uuid}")

# Find the fileRef line for the sibling to see the format
ref_pattern = re.compile(
    rf'({sibling_ref_uuid} /\* ReelActionStrip\.swift \*/ = \{{[^}}]+\}})',
    re.DOTALL
)
ref_match = ref_pattern.search(text)
if not ref_match:
    print("ERROR: Could not find fileRef definition for ReelActionStrip.swift")
    exit(1)

sibling_ref_line = ref_match.group(1)
print(f"Sibling ref: {sibling_ref_line[:200]}")

# Generate new UUIDs for CommentsSheet.swift
new_build_uuid = make_uuid()
new_ref_uuid = make_uuid()

# 1. Add PBXBuildFile entry (insert after sibling's PBXBuildFile line)
new_build_line = f'\t\t{new_build_uuid} /* CommentsSheet.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {new_ref_uuid} /* CommentsSheet.swift */; }};\n'
sibling_build_line = f'\t\t{sibling_build_uuid} /* ReelActionStrip.swift in Sources */'
text = text.replace(
    sibling_build_line,
    new_build_line + '\t\t' + sibling_build_uuid + ' /* ReelActionStrip.swift in Sources */',
    1
)

# 2. Add PBXFileReference entry (insert after sibling's ref line)
# Extract lastKnownFileType and sourceTree from sibling
sibling_ref_str = sibling_ref_line
# Build the new ref line based on sibling
new_ref_line = sibling_ref_str.replace(sibling_ref_uuid, new_ref_uuid)
new_ref_line = new_ref_line.replace('ReelActionStrip.swift', 'CommentsSheet.swift')
text = text.replace(sibling_ref_str, new_ref_line + '\n\t\t' + sibling_ref_str, 1)

# 3. Add to PBXGroup (ReelComponents folder group) - find the group containing ReelActionStrip
group_pattern = re.compile(
    r'(/\* ReelComponents \*/ = \{[^}]+children = \()[^)]+(\);)',
    re.DOTALL
)
# Find the group with ReelActionStrip
group_full_pattern = re.compile(
    r'(/\* [^*]+ \*/ = \{\s*isa = PBXGroup;\s*children = \()([^)]+)(\);[^}]*path = ReelComponents;)',
    re.DOTALL
)
gm = group_full_pattern.search(text)
if gm:
    old_children = gm.group(2)
    # Append new ref to children
    new_children = old_children.rstrip() + f'\n\t\t\t\t{new_ref_uuid} /* CommentsSheet.swift */,\n\t\t\t'
    text = text.replace(gm.group(0), gm.group(1) + new_children + gm.group(3), 1)
    print("Added to ReelComponents PBXGroup")
else:
    # Fallback: find the group that contains sibling_ref_uuid
    group_with_sibling = re.compile(
        r'(/\* [^*]+ \*/ = \{\s*isa = PBXGroup;\s*children = \()([^)]*' + re.escape(sibling_ref_uuid) + r'[^)]+)(\);)',
        re.DOTALL
    )
    gm2 = group_with_sibling.search(text)
    if gm2:
        old_children = gm2.group(2)
        new_children = old_children.replace(
            f'{sibling_ref_uuid} /* ReelActionStrip.swift */,',
            f'{new_ref_uuid} /* CommentsSheet.swift */,\n\t\t\t\t{sibling_ref_uuid} /* ReelActionStrip.swift */,'
        )
        text = text.replace(gm2.group(0), gm2.group(1) + new_children + gm2.group(3), 1)
        print("Added to PBXGroup (fallback)")
    else:
        print("WARNING: Could not find PBXGroup containing ReelActionStrip; skipping group step")

# 4. Add to PBXSourcesBuildPhase (Sources build phase for Lyo target)
sources_pattern = re.compile(
    r'(isa = PBXSourcesBuildPhase;[^}]+files = \()([^)]*' + re.escape(sibling_build_uuid) + r' /\* ReelActionStrip\.swift in Sources \*/)([^)]+\);)',
    re.DOTALL
)
sm = sources_pattern.search(text)
if sm:
    text = text.replace(
        sm.group(2),
        f'{new_build_uuid} /* CommentsSheet.swift in Sources */,\n\t\t\t\t' + sm.group(2)
    )
    print("Added to PBXSourcesBuildPhase")
else:
    print("WARNING: Could not find CommentsSheet in Sources build phase; trying alternate approach")
    # Try to find the Sources build phase and add near sibling
    alt = re.compile(
        rf'({re.escape(sibling_build_uuid)} /\* ReelActionStrip\.swift in Sources \*/,)'
    )
    if alt.search(text):
        text = alt.sub(
            f'{new_build_uuid} /* CommentsSheet.swift in Sources */,\n\t\t\t\t\\1',
            text,
            count=1
        )
        print("Added to Sources phase (alt method)")
    else:
        print("ERROR: Could not add to Sources build phase")

pbxproj_path.write_text(text)
print("Done. CommentsSheet.swift added to pbxproj.")
print(f"  Build UUID: {new_build_uuid}")
print(f"  File UUID:  {new_ref_uuid}")
