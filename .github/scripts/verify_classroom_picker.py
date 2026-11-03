#!/usr/bin/env python3
"""Emulator acceptance test for the Samsung three-button Start lesson regression.

Checks the *actual* Compose hit target and performs an adb tap, not just
compilation or a source-level layout assertion.
"""
import pathlib
import re
import subprocess
import time
import xml.etree.ElementTree as ET


def adb(*args):
    return subprocess.check_output(["adb", *args], text=True)


def capture_tree(remote, local):
    adb("shell", "uiautomator", "dump", remote)
    adb("pull", remote, local)
    return ET.parse(local).getroot()


def nodes_containing(root, search):
    return [
        node
        for node in root.iter("node")
        if search in (node.get("content-desc", "") + " " + node.get("text", ""))
    ]


root = capture_tree("/sdcard/classroom-picker.xml", "picker-before.xml")
buttons = nodes_containing(root, "Start lesson")
assert buttons, "Accessible Start lesson button was not found in classroom picker"
bounds = buttons[-1].get("bounds", "")
coords = [int(x) for x in re.findall("[0-9]+", bounds)]
assert len(coords) == 4, f"Unexpected button bounds: {bounds}"
x1, y1, x2, y2 = coords
physical = adb("shell", "wm", "size")
height = int(re.findall("[0-9]+", physical)[-1])
assert y2 > y1 and x2 > x1, f"Invalid button bounds: {bounds}"

# 120 px ensures a meaningful touch margin even for three-button navigation.
clearance = height - y2
print(f"Start lesson bounds={bounds}; display height={height}; bottom clearance={clearance}px")
assert clearance >= 120, (
    f"Start lesson overlaps navigation: bottom={y2} display={height} clearance={clearance}"
)

center_x = (x1 + x2) // 2
center_y = (y1 + y2) // 2
adb("shell", "input", "tap", str(center_x), str(center_y))
time.sleep(3)
after = capture_tree("/sdcard/classroom-after.xml", "picker-after.xml")
if not nodes_containing(after, "START_TAPPED"):
    # Preserve diagnostic screenshot and a useful tree excerpt on failures.
    with open("picker-after.png", "wb") as output:
        output.write(subprocess.check_output(["adb", "exec-out", "screencap", "-p"]))
    raise AssertionError("Start lesson tap did not activate the onChoose callback")
print(f"PASS: tap at ({center_x},{center_y}) activated Start lesson")
