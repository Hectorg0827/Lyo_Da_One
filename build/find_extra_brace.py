#!/usr/bin/env python3
"""Find the extra closing brace in project.pbxproj"""
import re

text = open("Lyo.xcodeproj/project.pbxproj", "r").read()
lines = text.split("\n")

# Track brace depth
depth = 0
for i, line in enumerate(lines, 1):
    old_depth = depth
    for ch in line:
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1

    stripped = line.strip()

    # The root dict opens at depth 1. objects = { is at depth 2.
    # Inside objects, each section entry is at depth 3.
    # A "};" at depth 1 closing objects should only happen once.
    if stripped == "};" and old_depth == 2 and depth == 1:
        print(f"  objects-level close at line {i}")

    if stripped == "}" and depth == 0 and old_depth == 1:
        print(f"  ROOT close at line {i}")

    if depth < 0:
        print(f"  NEGATIVE DEPTH at line {i}: {stripped[:80]}")
        break

print(f"Final depth: {depth}")

# Also check section Begin/End matching
begins = []
ends = []
for i, line in enumerate(lines, 1):
    m = re.search(r"/\* Begin (\w+) section \*/", line)
    if m:
        begins.append((i, m.group(1)))
    m = re.search(r"/\* End (\w+) section \*/", line)
    if m:
        ends.append((i, m.group(1)))

begin_names = [b[1] for b in begins]
end_names = [e[1] for e in ends]
for name in begin_names:
    if name not in end_names:
        print(f"  MISSING END section: {name}")
for name in end_names:
    if name not in begin_names:
        print(f"  MISSING BEGIN section: {name}")
if set(begin_names) == set(end_names):
    print("All Begin/End sections matched")

# Now check if the HEAD version is balanced
import subprocess
result = subprocess.run(["git", "show", "HEAD:Lyo.xcodeproj/project.pbxproj"],
                       capture_output=True, text=True)
if result.returncode == 0:
    head_text = result.stdout
    head_opens = head_text.count("{")
    head_closes = head_text.count("}")
    print(f"\nHEAD version: {{ = {head_opens}, }} = {head_closes}")
