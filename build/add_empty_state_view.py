#!/usr/bin/env python3
"""Add EmptyStateView.swift to the Xcode project."""
import re
import uuid

pbx_path = 'Lyo.xcodeproj/project.pbxproj'

with open(pbx_path, 'r') as f:
    text = f.read()

if 'EmptyStateView' in text:
    print('Already in pbxproj')
    exit(0)

def gen_id():
    return uuid.uuid4().hex[:24].upper()

file_ref_id = gen_id()
build_file_id = gen_id()

# 1. Add PBXBuildFile entry
bf_marker = '/* Begin PBXBuildFile section */'
bf_idx = text.index(bf_marker) + len(bf_marker)
build_file_entry = f'\n\t\t{build_file_id} /* EmptyStateView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* EmptyStateView.swift */; }};'
text = text[:bf_idx] + build_file_entry + text[bf_idx:]

# 2. Add PBXFileReference entry
fr_marker = '/* Begin PBXFileReference section */'
fr_idx = text.index(fr_marker) + len(fr_marker)
file_ref_entry = f'\n\t\t{file_ref_id} /* EmptyStateView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = EmptyStateView.swift; sourceTree = "<group>"; }};'
text = text[:fr_idx] + file_ref_entry + text[fr_idx:]

# 3. Add to Common group children
common_pat = re.compile(r'(/\* Common \*/ = \{[^}]*children = \(\s*)', re.DOTALL)
m = common_pat.search(text)
if m:
    insert_pos = m.end()
    child_entry = f'{file_ref_id} /* EmptyStateView.swift */,\n\t\t\t\t'
    text = text[:insert_pos] + child_entry + text[insert_pos:]
    print('Added to Common group')
else:
    print('ERROR: Common group not found')
    exit(1)

# 4. Add to PBXSourcesBuildPhase
sources_pat = re.compile(r'(/\* Sources \*/ = \{[^}]*files = \(\s*)', re.DOTALL)
m2 = sources_pat.search(text)
if m2:
    insert_pos2 = m2.end()
    source_entry = f'{build_file_id} /* EmptyStateView.swift in Sources */,\n\t\t\t\t'
    text = text[:insert_pos2] + source_entry + text[insert_pos2:]
    print('Added to Sources build phase')
else:
    print('ERROR: Sources build phase not found')
    exit(1)

with open(pbx_path, 'w') as f:
    f.write(text)

print(f'Done. FileRef={file_ref_id}, BuildFile={build_file_id}')
