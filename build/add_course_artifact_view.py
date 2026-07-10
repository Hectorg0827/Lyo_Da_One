#!/usr/bin/env python3
"""Add CourseArtifactView.swift to Lyo.xcodeproj/project.pbxproj"""
import hashlib, pathlib, sys

pbxproj = pathlib.Path("Lyo.xcodeproj/project.pbxproj")
text = pbxproj.read_text()

filename = "CourseArtifactView.swift"

if filename in text:
    print("Already in pbxproj, nothing to do.")
    sys.exit(0)

def make_uuid(seed):
    h = hashlib.md5(seed.encode()).hexdigest().upper()
    return h[:24]

file_ref_uuid   = make_uuid("CourseArtifactView_fileref")
build_file_uuid = make_uuid("CourseArtifactView_buildfile")

print(f"file_ref_uuid   = {file_ref_uuid}")
print(f"build_file_uuid = {build_file_uuid}")

file_ref_line   = (
    f'\t\t{file_ref_uuid} /* {filename} */ = '
    f'{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; '
    f'path = {filename}; sourceTree = "<group>"; }};'
)
build_file_line = (
    f'\t\t{build_file_uuid} /* {filename} in Sources */ = '
    f'{{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* {filename} */; }};'
)

# ── 1 PBXFileReference ───────────────────────────────────────────────────────
anchor_fref = '40FBB2F129DCBD4CEE5A506E /* ProactiveHintBanner.swift */ = {isa = PBXFileReference;'
if anchor_fref not in text:
    print("ERROR: PBXFileReference anchor not found"); sys.exit(1)
text = text.replace(anchor_fref, file_ref_line + "\n\t\t" + anchor_fref, 1)
print("PBXFileReference inserted")

# ── 2 PBXBuildFile ────────────────────────────────────────────────────────────
anchor_bfile = '1BBF0134881EC569EDD6C279 /* ProactiveHintBanner.swift in Sources */ = {isa = PBXBuildFile;'
if anchor_bfile not in text:
    print("ERROR: PBXBuildFile anchor not found"); sys.exit(1)
text = text.replace(anchor_bfile, build_file_line + "\n\t\t" + anchor_bfile, 1)
print("PBXBuildFile inserted")

# ── 3 Group membership ────────────────────────────────────────────────────────
anchor_group = '40FBB2F129DCBD4CEE5A506E /* ProactiveHintBanner.swift */,'
group_entry  = f'{file_ref_uuid} /* {filename} */,'
if anchor_group not in text:
    print("ERROR: group anchor not found"); sys.exit(1)
text = text.replace(anchor_group, anchor_group + "\n\t\t\t\t\t" + group_entry, 1)
print("Group membership added")

# ── 4 Sources build phase ─────────────────────────────────────────────────────
anchor_src  = '1BBF0134881EC569EDD6C279 /* ProactiveHintBanner.swift in Sources */,'
sources_entry = f'{build_file_uuid} /* {filename} in Sources */,'
if anchor_src not in text:
    print("ERROR: Sources phase anchor not found"); sys.exit(1)
text = text.replace(anchor_src, anchor_src + "\n\t\t\t\t\t" + sources_entry, 1)
print("Sources build phase updated")

pbxproj.write_text(text)
print("pbxproj written successfully")
