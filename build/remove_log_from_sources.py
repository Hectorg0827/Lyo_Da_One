#!/usr/bin/env python3
"""Remove Log.swift from Sources build phase"""

pbx = 'Lyo.xcodeproj/project.pbxproj'

with open(pbx, 'r') as f:
    lines = f.readlines()

removed = 0
new_lines = []
for line in lines:
    if 'BB1234567890ABCDEF123456' in line and 'Log.swift in Sources' in line:
        removed += 1
        print(f'Removed line: {line.rstrip()}')
    else:
        new_lines.append(line)

with open(pbx, 'w') as f:
    f.writelines(new_lines)

print(f'Removed {removed} line(s).')
