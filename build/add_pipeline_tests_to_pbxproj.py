#!/usr/bin/env python3
"""Add A2UIPipelineTests.swift to the Xcode project pbxproj."""
import hashlib
from pathlib import Path

pbxproj = Path('/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj/project.pbxproj')
text = pbxproj.read_text()

filename = 'A2UIPipelineTests.swift'

if filename in text:
    print('Already present – nothing to do')
    exit(0)

def det_uuid(seed):
    h = hashlib.sha1(seed.encode()).hexdigest()[:24].upper()
    return h

file_ref_uuid   = det_uuid('A2UIPipelineTests_fileref')
build_file_uuid = det_uuid('A2UIPipelineTests_buildfile')

# ── 1. PBXBuildFile section ──────────────────────────────────────────────────
T2 = '\t\t'
T4 = '\t\t\t\t'

OLD_BF = (T2 + 'D466269A1DA9C13EAA3A8239 /* MentorModeTests.swift in Sources */'
          ' = {isa = PBXBuildFile; fileRef = 277EBE51110A2BA1195E6FA6 /* MentorModeTests.swift */; };')
NEW_BF = (OLD_BF + '\n'
          + T2 + f'{build_file_uuid} /* {filename} in Sources */'
          f' = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* {filename} */; }};')
assert OLD_BF in text, f'BF anchor not found'
text = text.replace(OLD_BF, NEW_BF, 1)

# ── 2. PBXFileReference section ──────────────────────────────────────────────
OLD_FR = (T2 + '277EBE51110A2BA1195E6FA6 /* MentorModeTests.swift */'
          ' = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift;'
          ' path = MentorModeTests.swift; sourceTree = "<group>"; };')
NEW_FR = (OLD_FR + '\n'
          + T2 + f'{file_ref_uuid} /* {filename} */'
          f' = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift;'
          f' path = {filename}; sourceTree = "<group>"; }};')
assert OLD_FR in text, f'FR anchor not found'
text = text.replace(OLD_FR, NEW_FR, 1)

# ── 3. Group children list ───────────────────────────────────────────────────
OLD_CHILD = T4 + '277EBE51110A2BA1195E6FA6 /* MentorModeTests.swift */,'
NEW_CHILD = OLD_CHILD + '\n' + T4 + f'{file_ref_uuid} /* {filename} */,'
assert OLD_CHILD in text, 'Child anchor not found'
text = text.replace(OLD_CHILD, NEW_CHILD, 1)

# ── 4. Sources build phase ───────────────────────────────────────────────────
OLD_SRC = T4 + 'D466269A1DA9C13EAA3A8239 /* MentorModeTests.swift in Sources */,'
NEW_SRC = OLD_SRC + '\n' + T4 + f'{build_file_uuid} /* {filename} in Sources */,'
assert OLD_SRC in text, 'Src anchor not found'
text = text.replace(OLD_SRC, NEW_SRC, 1)

pbxproj.write_text(text)
print(f'Added {filename}  fileRef={file_ref_uuid}  buildFile={build_file_uuid}')
