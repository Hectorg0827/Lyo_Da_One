#!/usr/bin/env python3
"""Find Swift files in Sources/ that are missing from project.pbxproj."""
import os
import re

pbxproj = "Lyo.xcodeproj/project.pbxproj"
with open(pbxproj) as f:
    content = f.read()

# Get all .swift filenames referenced in the pbxproj
referenced = set(re.findall(r'/\* (\S+\.swift) \*/', content))

# Get all .swift files on disk under Sources/
on_disk = set()
for root, dirs, files in os.walk("Sources"):
    for fn in files:
        if fn.endswith(".swift"):
            on_disk.add(fn)

missing = sorted(on_disk - referenced)
extra = sorted(referenced - on_disk)

print(f"Files on disk: {len(on_disk)}")
print(f"Files in pbxproj: {len(referenced)}")
print(f"\nMissing from pbxproj ({len(missing)}):")
for f in missing:
    # Find full path
    for root, dirs, files in os.walk("Sources"):
        if f in files:
            print(f"  {os.path.join(root, f)}")
            break

print(f"\nIn pbxproj but not on disk ({len(extra)}):")
for f in extra:
    print(f"  {f}")
