#!/usr/bin/env python3
"""Analyze group hierarchy for stale file references."""
import re

with open('Lyo.xcodeproj/project.pbxproj') as f:
    lines = f.readlines()

groups = {}
i = 0
while i < len(lines):
    m = re.match(r'\s*([A-F0-9]{24})\s*/\*\s*(.*?)\s*\*/\s*=\s*\{', lines[i].strip())
    if m and i+1 < len(lines) and 'PBXGroup' in lines[i+1]:
        gid = m.group(1)
        gname = m.group(2)
        children = []
        path = None
        j = i + 1
        while j < len(lines) and lines[j].strip() != '};':
            pm = re.match(r'\s*path\s*=\s*"?([^";\s]+)"?\s*;', lines[j].strip())
            if pm:
                path = pm.group(1)
            cm = re.match(r'\s*([A-F0-9]{24})\s*/\*', lines[j].strip())
            if cm:
                children.append(cm.group(1))
            j += 1
        groups[gid] = {'name': gname, 'path': path, 'children': children, 'line': i+1}
    i += 1

parent_map = {}
for gid, g in groups.items():
    for c in g['children']:
        if c not in parent_map:
            parent_map[c] = []
        parent_map[c].append(gid)

def full_path(gid, visited=None):
    if visited is None:
        visited = set()
    if gid in visited:
        return '(cycle)'
    visited.add(gid)
    g = groups.get(gid)
    if not g:
        return '?'
    parents = parent_map.get(gid, [])
    name = g.get('path') or g['name']
    if not parents:
        return name
    return full_path(parents[0], visited) + '/' + name

target_groups = [
    '3C0BD0E8EE25D74F14A9428C',  # Views (A2UI)
    '40B4CA1358F34A7EC4F744CB',  # Views (main)
    '24D57E778DAA441404ADB176',  # Community
    '7DC7802AD4F2D27D6C70E13E',  # Community
    'AD0E7701686E65AE6063F9CB',  # Learning
    'E33E9FE7CDF7BF4991E3C131',  # Learning
]

print("=== Group hierarchy ===")
for gid in target_groups:
    g = groups.get(gid)
    if g:
        fp = full_path(gid)
        print(f'{gid} [{g["name"]}] line {g["line"]}: {fp}')
        parents = parent_map.get(gid, [])
        for p in parents:
            pg = groups.get(p)
            if pg:
                print(f'  parent: {p} [{pg["name"]}] path={pg.get("path")}')
        print()

# Also find the correct A2UI/Views group
print("=== Looking for correct A2UI/Views group ===")
for gid, g in groups.items():
    if g['name'] == 'Views':
        fp = full_path(gid)
        if 'A2UI' in fp:
            print(f'{gid} [{g["name"]}] line {g["line"]}: {fp}')
            print(f'  children: {len(g["children"])}')
            print()

# Find correct Community group under Models
print("=== Looking for Community group under Models ===")
for gid, g in groups.items():
    if g['name'] == 'Community':
        fp = full_path(gid)
        if 'Models' in fp:
            print(f'{gid} [{g["name"]}] line {g["line"]}: {fp}')
            print(f'  children: {len(g["children"])}')
            print()

# Find correct Learning group under Components
print("=== Looking for Learning group under Components ===")
for gid, g in groups.items():
    if g['name'] == 'Learning':
        fp = full_path(gid)
        if 'Components' in fp:
            print(f'{gid} [{g["name"]}] line {g["line"]}: {fp}')
            print(f'  children: {len(g["children"])}')
            print()
