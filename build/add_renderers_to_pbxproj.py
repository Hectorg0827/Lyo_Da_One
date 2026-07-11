#!/usr/bin/env python3
"""Add new A2UI renderer files to the Xcode project."""
import hashlib
import re

pbxproj_path = "Lyo.xcodeproj/project.pbxproj"
with open(pbxproj_path, 'r') as f:
    content = f.read()

new_files = [
    "A2UIHomeworkRenderers.swift",
    "A2UIMistakeRenderers.swift",
    "A2UIStudyPlanRenderers.swift",
    "A2UIMiscRenderers.swift",
]

def gen_id(seed):
    h = hashlib.md5(seed.encode()).hexdigest()
    return h[:24].upper()

for fname in new_files:
    file_ref_id = gen_id("fileref_" + fname + "_v3")
    build_file_id = gen_id("buildfile_" + fname + "_v3")

    if fname in content:
        print("SKIP " + fname + " (already in pbxproj)")
        continue

    print("ADD " + fname + " ref=" + file_ref_id + " build=" + build_file_id)

    # 1. PBXBuildFile
    anchor = "DCB9DE00FEEB19D22AB7084A /* A2UIHomeworkViews.swift in Sources */ = {isa = PBXBuildFile;"
    new_build = "\t\t\t" + build_file_id + " /* " + fname + " in Sources */ = {isa = PBXBuildFile; fileRef = " + file_ref_id + " /* " + fname + " */; };\n"
    idx = content.find(anchor)
    if idx >= 0:
        line_end = content.index("\n", idx) + 1
        content = content[:line_end] + new_build + content[line_end:]

    # 2. PBXFileReference
    anchor2 = "3E2E90DD8063B5DE1743D1EB /* A2UIHomeworkViews.swift */ = {isa = PBXFileReference;"
    new_ref = "\t\t\t" + file_ref_id + " /* " + fname + " */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = " + fname + '; sourceTree = "<group>"; };\n'
    idx2 = content.find(anchor2)
    if idx2 >= 0:
        line_end2 = content.index("\n", idx2) + 1
        content = content[:line_end2] + new_ref + content[line_end2:]

    # 3. Group children (after A2UIHomeworkViews in the group listing)
    anchor3 = "3E2E90DD8063B5DE1743D1EB /* A2UIHomeworkViews.swift */,"
    new_group = "\t\t\t\t\t\t" + file_ref_id + " /* " + fname + " */,\n"
    idx3 = content.find(anchor3)
    if idx3 >= 0:
        line_end3 = content.index("\n", idx3) + 1
        content = content[:line_end3] + new_group + content[line_end3:]

    # 4. Sources build phase
    anchor4 = "DCB9DE00FEEB19D22AB7084A /* A2UIHomeworkViews.swift in Sources */,"
    new_source = "\t\t\t\t\t\t" + build_file_id + " /* " + fname + " in Sources */,\n"
    idx4 = content.find(anchor4)
    if idx4 >= 0:
        line_end4 = content.index("\n", idx4) + 1
        content = content[:line_end4] + new_source + content[line_end4:]

with open(pbxproj_path, 'w') as f:
    f.write(content)

print("DONE")
