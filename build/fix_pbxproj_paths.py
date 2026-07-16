#!/usr/bin/env python3
"""Fix PBXFileReference entries to use SOURCE_ROOT with correct paths."""
import os

PBXPROJ = 'Lyo.xcodeproj/project.pbxproj'

# Maps from filename -> correct relative path from source root
FILE_PATHS = {
    'CinematicHookView.swift': 'Sources/Components/AITutor/CinematicHookView.swift',
    'FlashcardSetView.swift': 'Sources/Components/AITutor/FlashcardSetView.swift',
    'FlashcardView.swift': 'Sources/Components/AITutor/FlashcardView.swift',
    'LessonImageView.swift': 'Sources/Components/AITutor/LessonImageView.swift',
    'MasteryMapView.swift': 'Sources/Components/AITutor/MasteryMapView.swift',
    'ProgressBarView.swift': 'Sources/Components/AITutor/ProgressBarView.swift',
    'RichTextBubble.swift': 'Sources/Components/AITutor/RichTextBubble.swift',
    'SmartBlockContainerView.swift': 'Sources/Components/AITutor/SmartBlockContainerView.swift',
    'SmartBlockQuizCard.swift': 'Sources/Components/AITutor/SmartBlockQuizCard.swift',
    'SmartBlockStudyPlanView.swift': 'Sources/Components/AITutor/SmartBlockStudyPlanView.swift',
    'SmartBlockSummaryCard.swift': 'Sources/Components/AITutor/SmartBlockSummaryCard.swift',
    'TestPrepCardView.swift': 'Sources/Components/AITutor/TestPrepCardView.swift',
    'LessonBlock.swift': 'Sources/Models/LessonBlock.swift',
    'SmartBlockParser.swift': 'Sources/Services/SmartBlockParser.swift',
    'AgentCardView.swift': 'Sources/Views/Components/AgentCardView.swift',
}

def main():
    with open(PBXPROJ, 'r') as f:
        text = f.read()

    for fname, full_path in FILE_PATHS.items():
        # Find the PBXFileReference line for this file and update it
        # Old: path = X.swift; sourceTree = "<group>";
        # New: name = X.swift; path = full/path/X.swift; sourceTree = SOURCE_ROOT;
        old_pattern = f'path = {fname}; sourceTree = "<group>";'
        new_pattern = f'name = {fname}; path = {full_path}; sourceTree = SOURCE_ROOT;'
        
        count = text.count(old_pattern)
        if count == 0:
            print(f'WARNING: Pattern not found for {fname}')
            continue
        
        # Only replace in the PBXFileReference that we added (the one with our generated ID)
        # Since there might be other references to the same filename, be careful
        # Our added refs are the ones with our generated IDs
        text = text.replace(old_pattern, new_pattern, 1)
        print(f'Fixed: {fname} -> {full_path}')

    # Also need to remove the duplicate children entries we added to wrong groups
    # and move them to correct groups. But since we're using SOURCE_ROOT now,
    # we don't need to move them.

    with open(PBXPROJ, 'w') as f:
        f.write(text)

    print('\nDone! Fixed PBXFileReference paths.')

if __name__ == '__main__':
    main()
