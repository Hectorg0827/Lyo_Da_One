import uuid, re

pbx = 'Lyo.xcodeproj/project.pbxproj'
text = open(pbx).read()

file_ref = uuid.uuid4().hex[:24].upper()
build_ref = uuid.uuid4().hex[:24].upper()
fname = 'StudyPlanView.swift'

# 1. PBXBuildFile
marker = '/* Begin PBXBuildFile section */'
entry = f'\n\t\t{build_ref} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref} /* {fname} */; }};'
text = text.replace(marker, marker + entry)

# 2. PBXFileReference
marker2 = '/* Begin PBXFileReference section */'
entry2 = f'\n\t\t{file_ref} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {fname}; sourceTree = "<group>"; }};'
text = text.replace(marker2, marker2 + entry2)

# 3. Sources build phase
src_phase = re.search(r'/\* Sources \*/ = \{.*?files = \((.*?)\);', text, re.DOTALL)
if src_phase:
    pos = src_phase.start(1)
    text = text[:pos] + f'\n\t\t\t\t{build_ref} /* {fname} in Sources */,' + text[pos:]
    print("Added to Sources build phase")

# 4. Components group
comp_group = re.search(r'path = Components;.*?children = \((.*?)\);', text, re.DOTALL)
if comp_group:
    pos = comp_group.start(1)
    text = text[:pos] + f'\n\t\t\t\t{file_ref} /* {fname} */,' + text[pos:]
    print("Added to Components group")

open(pbx, 'w').write(text)
print(f"Done: fileRef={file_ref}, buildRef={build_ref}")
