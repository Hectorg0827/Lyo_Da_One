#!/usr/bin/env python3
"""Add missing Swift files to pbxproj."""
import hashlib
import re
import sys

PBXPROJ = 'Lyo.xcodeproj/project.pbxproj'

# filename -> (group_search_term, group_path)
FILES = [
    ('CinematicHookView.swift', 'AITutor'),
    ('FlashcardSetView.swift', 'AITutor'),
    ('FlashcardView.swift', 'AITutor'),
    ('LessonImageView.swift', 'AITutor'),
    ('MasteryMapView.swift', 'AITutor'),
    ('ProgressBarView.swift', 'AITutor'),
    ('RichTextBubble.swift', 'AITutor'),
    ('SmartBlockContainerView.swift', 'AITutor'),
    ('SmartBlockQuizCard.swift', 'AITutor'),
    ('SmartBlockStudyPlanView.swift', 'AITutor'),
    ('SmartBlockSummaryCard.swift', 'AITutor'),
    ('TestPrepCardView.swift', 'AITutor'),
    ('LessonBlock.swift', 'Models'),
    ('SmartBlockParser.swift', 'Services'),
    ('AgentCardView.swift', 'Components'),
]

def make_id(seed):
    return hashlib.md5(seed.encode()).hexdigest()[:24].upper()

def main():
    with open(PBXPROJ, 'r') as f:
        text = f.read()

    # Check which are already present
    to_add = []
    for fname, group in FILES:
        if fname in text:
            print(f'SKIP (already in pbxproj): {fname}')
        else:
            to_add.append((fname, group))

    if not to_add:
        print('Nothing to add!')
        return

    for fname, group in to_add:
        ref_id = make_id(f'ref_{fname}')
        build_id = make_id(f'build_{fname}')
        
        # 1. Add PBXBuildFile entry (insert after first PBXBuildFile line)
        bf_line = f'\t\t{build_id} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref_id} /* {fname} */; }};\n'
        
        # Find PBXBuildFile section and insert
        marker = '/* Begin PBXBuildFile section */\n'
        idx = text.index(marker) + len(marker)
        text = text[:idx] + bf_line + text[idx:]
        
        # 2. Add PBXFileReference entry (insert after first PBXFileReference line)
        fr_line = f'\t\t{ref_id} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {fname}; sourceTree = "<group>"; }};\n'
        
        marker2 = '/* Begin PBXFileReference section */\n'
        idx2 = text.index(marker2) + len(marker2)
        text = text[:idx2] + fr_line + text[idx2:]
        
        # 3. Add to group children
        # Find the group with path = <group>;
        group_pattern = rf'(/\* {re.escape(group)} \*/ = \{{\s*isa = PBXGroup;\s*children = \()\n'
        match = re.search(group_pattern, text)
        if match:
            insert_pos = match.end()
            group_child = f'\t\t\t\t{ref_id} /* {fname} */,\n'
            text = text[:insert_pos] + group_child + text[insert_pos:]
            print(f'Added {fname} to {group} group')
        else:
            # Try path-based search
            path_pattern = rf'(children = \(\n(?:.*\n)*?)\t\t\t\);\n\t\t\tpath = {re.escape(group)};'
            match2 = re.search(path_pattern, text)
            if match2:
                insert_pos = match2.end(1)
                group_child = f'\t\t\t\t{ref_id} /* {fname} */,\n'
                text = text[:insert_pos] + group_child + text[insert_pos:]
                print(f'Added {fname} to {group} group (path match)')
            else:
                print(f'WARNING: Could not find group for {fname} ({group})')
        
        # 4. Add to Sources build phase
        sources_marker = '/* Begin PBXSourcesBuildPhase section */'
        sources_idx = text.index(sources_marker)
        # Find 'files = (' after this marker
        files_marker = 'files = ('
        files_idx = text.index(files_marker, sources_idx) + len(files_marker) + 1
        source_line = f'\t\t\t\t{build_id} /* {fname} in Sources */,\n'
        text = text[:files_idx] + source_line + text[files_idx:]
        
        print(f'Added {fname}: ref={ref_id}, build={build_id}')

    with open(PBXPROJ, 'w') as f:
        f.write(text)
    
    print(f'\nDone! Added {len(to_add)} files.')

if __name__ == '__main__':
    main()
