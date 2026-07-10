#!/usr/bin/env python3
"""Add 8 missing files to PBXSourcesBuildPhase in project.pbxproj"""

pbx = 'Lyo.xcodeproj/project.pbxproj'

with open(pbx, 'r') as f:
    text = f.read()

changes = 0

# 1. After A2ATaskManager.swift in Sources in build phase
old1 = '\t\t\t\tFADF492A2F86952E46DEF44C /* A2ATaskManager.swift in Sources */,\n\t\t\t\t1005C6316A17A5C74AC9D893'
new1 = (
    '\t\t\t\tFADF492A2F86952E46DEF44C /* A2ATaskManager.swift in Sources */,\n'
    '\t\t\t\t012345678A1B2C3D4E5F6789 /* A2ATaskManagerTests.swift in Sources */,\n'
    '\t\t\t\tDD1234567890ABCDEF123456 /* ContentStorageService.swift in Sources */,\n'
    '\t\t\t\tFF1234567890ABCDEF123456 /* EnhancedCameraManager.swift in Sources */,\n'
    '\t\t\t\tB2C3D4E5F6789012345678A1 /* GamificationService.swift in Sources */,\n'
    '\t\t\t\tD4E5F6789012345678A1B2C3 /* CalendarService.swift in Sources */,\n'
    '\t\t\t\tF6789012345678A1B2C3D4E5 /* CreateStudioComponents.swift in Sources */,\n'
    '\t\t\t\t89012345678A1B2C3D4E5F67 /* StudyPlanCard.swift in Sources */,\n'
    '\t\t\t\t1005C6316A17A5C74AC9D893'
)
if old1 in text:
    text = text.replace(old1, new1, 1)
    changes += 1
    print('OK: Inserted 8 files after A2ATaskManager in Sources build phase')
else:
    print('MISS: A2ATaskManager anchor not found in build phase')

# 2. After LyoLogger.swift in Sources in build phase
old2 = '\t\t\t\tF8B123C11543E5BBC85EF253 /* LyoLogger.swift in Sources */,\n\t\t\t\t88378618CE7CF391D96D7714'
new2 = (
    '\t\t\t\tF8B123C11543E5BBC85EF253 /* LyoLogger.swift in Sources */,\n'
    '\t\t\t\tBB1234567890ABCDEF123456 /* Log.swift in Sources */,\n'
    '\t\t\t\t88378618CE7CF391D96D7714'
)
if old2 in text:
    text = text.replace(old2, new2, 1)
    changes += 1
    print('OK: Inserted Log.swift after LyoLogger in Sources build phase')
else:
    print('MISS: LyoLogger anchor not found in build phase')

with open(pbx, 'w') as f:
    f.write(text)

print(f'Done. {changes}/2 replacements made.')
