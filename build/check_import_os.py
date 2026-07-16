#!/usr/bin/env python3
"""Check which files are missing 'import os' and add it if needed."""
import os

files = [
    "Sources/Components/AITutor/AccessibleLyoAvatar.swift",
    "Sources/Components/Premium/PremiumButton.swift",
    "Sources/Components/Vision/ImagePickerView.swift",
    "Sources/Core/A2UI/A2UIStateObserver.swift",
    "Sources/Core/A2UI/A2UIStreamService.swift",
    "Sources/Core/A2UI/A2UIVoiceController.swift",
    "Sources/Models/AICommandResponse.swift",
    "Sources/Services/A2A/AgentCardService.swift",
    "Sources/Services/A2UI/AIResponseParser.swift",
    "Sources/Services/AICommandHandler.swift",
    "Sources/Services/AudioPlaybackService.swift",
    "Sources/Services/AuthService.swift",
    "Sources/Services/BackendAIService.swift",
    "Sources/Services/CameraManager.swift",
    "Sources/Views/AI/CourseCreationCoordinator.swift",
    "Sources/Views/AI/CourseGenerationSettingsView.swift",
    "Sources/Views/AI/GenerationProgressView.swift",
    "Sources/Views/Chat/SuggestionChipsView.swift",
    "Sources/Views/Gamification/AllAchievementsView.swift",
    "Sources/Views/Test/A2UITestView.swift",
]

missing = []
for f in files:
    with open(f) as fh:
        content = fh.read()
    if "import os" not in content:
        missing.append(f)
        print("MISSING: " + f)
    else:
        print("HAS:     " + f)

print("\n" + str(len(missing)) + " files missing import os")

if missing:
    print("\nAdding import os to missing files...")
    for f in missing:
        with open(f) as fh:
            content = fh.read()
        # Add import os after the last import line
        lines = content.split("\n")
        last_import_idx = -1
        for i, line in enumerate(lines):
            if line.startswith("import "):
                last_import_idx = i
        if last_import_idx >= 0:
            lines.insert(last_import_idx + 1, "import os")
        else:
            lines.insert(0, "import os")
        with open(f, "w") as fh:
            fh.write("\n".join(lines))
        print("  Fixed: " + f)
    print("Done!")
