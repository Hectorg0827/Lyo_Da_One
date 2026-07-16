#!/usr/bin/env python3
"""
Remove pbxproj entries for deleted A2UI files.
Keeps entries for files that still exist on disk.
"""

import re
from pathlib import Path

PROJ = Path("/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj/project.pbxproj")

# Files we DELETED (basenames). These entries must be removed from pbxproj.
DELETED_FILES = {
    # Core A2UI framework (Sources/Core/A2UI/)
    "A2IPayloadMapper.swift",
    "A2UICapabilityNegotiator.swift",
    "A2UIComponent.swift",
    "A2UIContentSynthesizer.swift",
    "A2UIElementType.swift",
    "A2UIPrimitive.swift",
    "A2UIProps.swift",
    "A2UIRenderer.swift",
    "A2UIStateObserver.swift",
    "A2UIStreamService.swift",
    "A2UIVoiceController.swift",
    # A2UI Views (Sources/Core/A2UI/Views/)
    "A2UICollectionRenderers.swift",
    "A2UIHomeworkRenderers.swift",
    "A2UIHomeworkViews.swift",
    "A2UIInputRenderers.swift",
    "A2UILayoutRenderers.swift",
    "A2UILayoutViews.swift",
    "A2UIMiscRenderers.swift",
    "A2UIMiscViews.swift",
    "A2UIMistakeRenderers.swift",
    "A2UIMistakeViews.swift",
    "A2UIQuizRenderers.swift",
    "A2UIQuizViews.swift",
    "A2UIRendererViews.swift",
    "A2UIStudyPlanRenderers.swift",
    "A2UIStudyPlanViews.swift",
    "LyoContentPrimitives.swift",
    "LyoEngagementPrimitives.swift",
    "LyoInputPrimitives.swift",
    "LyoLayoutPrimitives.swift",
    "LyoLearningPrimitives.swift",
    "LyoPrimitiveRenderer.swift",
    # Other deleted files
    "AIResponseParser.swift",
    "CourseArtifactView.swift",
    "A2UITestView.swift",
    "A2UIParser.swift",
    # Test files
    "A2IPayloadMapperTests.swift",
    "A2UIBugContractTests.swift",
    "A2UIDecodingTests.swift",
    "A2UIPipelineTests.swift",
    "A2UITests.swift",
}

text = PROJ.read_text()
lines = text.splitlines(keepends=True)

removed_count = 0
kept_lines = []

for line in lines:
    # Check if this line references any deleted file
    should_remove = False
    for fname in DELETED_FILES:
        if fname in line:
            should_remove = True
            break
    
    if should_remove:
        removed_count += 1
        # Don't add this line to output
    else:
        kept_lines.append(line)

new_text = "".join(kept_lines)

# Validate: check brace balance
open_braces = new_text.count("{")
close_braces = new_text.count("}")
print(f"Brace balance: {{ = {open_braces}, }} = {close_braces}")
if open_braces != close_braces:
    print("⚠️  WARNING: Brace mismatch! Not writing.")
else:
    PROJ.write_text(new_text)
    print(f"✅ Removed {removed_count} lines from pbxproj")
    print(f"   File size: {len(new_text)} bytes")

# Verify with plutil
import subprocess
result = subprocess.run(["plutil", "-lint", str(PROJ)], capture_output=True, text=True)
print(f"plutil lint: {result.stdout.strip()}")
if result.returncode != 0:
    print(f"  stderr: {result.stderr.strip()}")
