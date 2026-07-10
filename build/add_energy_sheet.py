import re, uuid

pbx = 'Lyo.xcodeproj/project.pbxproj'
text = open(pbx).read()

fname = 'EnergyPaymentSheet.swift'
file_ref = uuid.uuid4().hex[:24].upper()
build_ref = uuid.uuid4().hex[:24].upper()

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

# 4. Find Monetization group
monetization = re.search(r'path = Monetization;.*?children = \((.*?)\);', text, re.DOTALL)
if monetization:
    pos = monetization.start(1)
    text = text[:pos] + f'\n\t\t\t\t{file_ref} /* {fname} */,' + text[pos:]
    print("Added to Monetization group")
else:
    print("WARNING: No Monetization group found")

open(pbx, 'w').write(text)
print(f"Done: {fname}")
