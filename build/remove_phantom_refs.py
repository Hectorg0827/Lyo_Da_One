#!/usr/bin/env python3
"""Remove phantom file references from pbxproj for files that don't exist on disk."""

import os

MISSING_FILES = [
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
    "LyoResponse.swift",
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
    "A2UIRecursive.swift",
    "AIResponseParser.swift",
    "CourseOrchestrator.swift",
    "A2UIParser.swift",
    "A2UIContentViews.swift",
    "A2UIRecursiveRenderer.swift",
    "CourseArtifactView.swift",
    "A2UITestView.swift",
]

def main():
    pbx_path = os.path.join(os.path.dirname(__file__), "..", "Lyo.xcodeproj", "project.pbxproj")
    pbx_path = os.path.abspath(pbx_path)
    
    with open(pbx_path, "r") as f:
        lines = f.readlines()
    
    print(f"Original lines: {len(lines)}")
    
    removed = 0
    kept = []
    for line in lines:
        should_remove = False
        for fname in MISSING_FILES:
            if fname in line:
                should_remove = True
                break
        if should_remove:
            removed += 1
        else:
            kept.append(line)
    
    print(f"Lines removed: {removed}")
    print(f"Remaining lines: {len(kept)}")
    
    with open(pbx_path, "w") as f:
        f.writelines(kept)
    
    print("Done - pbxproj updated")

if __name__ == "__main__":
    main()
