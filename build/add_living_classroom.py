#!/usr/bin/env python3
"""Add LivingClassroomView.swift and LivingClassroomService.swift to project.pbxproj"""
import hashlib, random, re, sys

pbx_path = 'Lyo.xcodeproj/project.pbxproj'
text = open(pbx_path).read()
existing_uuids = set(re.findall(r'([0-9A-F]{24})', text))

def gen_uuid():
    while True:
        u = hashlib.md5(str(random.random()).encode()).hexdigest()[:24].upper()
        if u not in existing_uuids:
            existing_uuids.add(u)
            return u

# Check if already added
if 'LivingClassroomView.swift' in text:
    print('LivingClassroomView.swift already in project.pbxproj, skipping.')
    sys.exit(0)

vfr = gen_uuid(); vbf = gen_uuid(); sfr = gen_uuid(); sbf = gen_uuid()
print(f"View fileRef={vfr} buildFile={vbf}")
print(f"Service fileRef={sfr} buildFile={sbf}")

# 1. PBXBuildFile
m1 = '/* Begin PBXBuildFile section */'
ins1 = (
    f'\n\t\t{vbf} /* LivingClassroomView.swift in Sources */ = '
    f'{{isa = PBXBuildFile; fileRef = {vfr} /* LivingClassroomView.swift */; }};'
    f'\n\t\t{sbf} /* LivingClassroomService.swift in Sources */ = '
    f'{{isa = PBXBuildFile; fileRef = {sfr} /* LivingClassroomService.swift */; }};'
)
text = text.replace(m1, m1 + ins1, 1)

# 2. PBXFileReference
m2 = '/* Begin PBXFileReference section */'
ins2 = (
    f'\n\t\t{vfr} /* LivingClassroomView.swift */ = '
    f'{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LivingClassroomView.swift; sourceTree = "<group>"; }};'
    f'\n\t\t{sfr} /* LivingClassroomService.swift */ = '
    f'{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LivingClassroomService.swift; sourceTree = "<group>"; }};'
)
text = text.replace(m2, m2 + ins2, 1)

# 3. Add to Classroom group children
lines = text.split('\n')
done_view = False
for i, line in enumerate(lines):
    if '/* Classroom */' in line and i+1 < len(lines) and 'isa = PBXGroup' in lines[i+1]:
        for j in range(i, min(i+5, len(lines))):
            if 'children = (' in lines[j]:
                lines.insert(j+1, f'\t\t\t\t\t{vfr} /* LivingClassroomView.swift */,')
                done_view = True
                print('Added view to Classroom group')
                break
        break
if not done_view:
    print('WARNING: Classroom group not found!')

# 4. Add to Services group children
text2 = '\n'.join(lines)
lines = text2.split('\n')
done_svc = False
for i, line in enumerate(lines):
    if '/* Services */' in line and i+1 < len(lines) and 'isa = PBXGroup' in lines[i+1]:
        for j in range(i, min(i+5, len(lines))):
            if 'children = (' in lines[j]:
                lines.insert(j+1, f'\t\t\t\t\t{sfr} /* LivingClassroomService.swift */,')
                done_svc = True
                print('Added service to Services group')
                break
        break
if not done_svc:
    print('WARNING: Services group not found!')

# 5. Add to PBXSourcesBuildPhase
text3 = '\n'.join(lines)
lines = text3.split('\n')
done_build = False
for i, line in enumerate(lines):
    if '/* Sources */' in line and i+1 < len(lines) and 'isa = PBXSourcesBuildPhase' in lines[i+1]:
        for j in range(i, min(i+10, len(lines))):
            if 'files = (' in lines[j]:
                lines.insert(j+1, f'\t\t\t\t\t{vbf} /* LivingClassroomView.swift in Sources */,')
                lines.insert(j+2, f'\t\t\t\t\t{sbf} /* LivingClassroomService.swift in Sources */,')
                done_build = True
                print('Added both to PBXSourcesBuildPhase')
                break
        break
if not done_build:
    print('WARNING: PBXSourcesBuildPhase not found!')

open(pbx_path, 'w').write('\n'.join(lines))
print('Done!')
