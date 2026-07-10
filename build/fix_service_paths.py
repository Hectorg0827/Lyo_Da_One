#!/usr/bin/env python3
"""Fix service file paths to use SOURCE_ROOT"""

pbx = 'Lyo.xcodeproj/project.pbxproj'

with open(pbx, 'r') as f:
    text = f.read()

fixes = [
    ('path = ContentStorageService.swift; sourceTree = "<group>"',
     'path = Sources/Services/ContentStorageService.swift; sourceTree = SOURCE_ROOT'),
    ('path = EnhancedCameraManager.swift; sourceTree = "<group>"',
     'path = Sources/Services/EnhancedCameraManager.swift; sourceTree = SOURCE_ROOT'),
    ('path = GamificationService.swift; sourceTree = "<group>"',
     'path = Sources/Services/GamificationService.swift; sourceTree = SOURCE_ROOT'),
    ('path = CalendarService.swift; sourceTree = "<group>"',
     'path = Sources/Services/CalendarService.swift; sourceTree = SOURCE_ROOT'),
    # Also fix StudyPlanCard path - it's in AITutor group which resolves to Views/Main/AITutor
    ('path = StudyPlanCard.swift; sourceTree = "<group>"',
     'path = Sources/Views/Main/AITutor/StudyPlanCard.swift; sourceTree = SOURCE_ROOT'),
    # Fix Log.swift path - in Utilities group which resolves to Core/Utilities
    ('path = Log.swift; sourceTree = "<group>"',
     'path = Sources/Core/Utilities/Log.swift; sourceTree = SOURCE_ROOT'),
]

count = 0
for old, new in fixes:
    if old in text:
        text = text.replace(old, new, 1)
        count += 1
        print('Fixed:', old[:50])
    else:
        print('MISS:', old[:50])

with open(pbx, 'w') as f:
    f.write(text)

print(f'\nFixed {count}/{len(fixes)} paths.')
