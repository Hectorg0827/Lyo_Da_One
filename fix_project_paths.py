#!/usr/bin/env python3
import os

PROJECT_PATH = 'Lyo.xcodeproj/project.pbxproj'

# Map filename to correct relative path from Sources
PATH_CORRECTIONS = {
    'CreateHubView.swift': 'Views/Main/Creation/CreateHubView.swift',
    'HolisticProfileView.swift': 'Views/Profile/HolisticProfileView.swift',
    'ProactiveHintBanner.swift': 'Views/Components/ProactiveHintBanner.swift',
    'AdaptiveHomeView.swift': 'Views/Main/AdaptiveHomeView.swift',
    'SoftSkillsService.swift': 'Services/SoftSkillsService.swift',
    'SmartMemoryService.swift': 'Services/SmartMemoryService.swift',
    'UserContextService.swift': 'Services/UserContextService.swift'
}

def fix_paths():
    if not os.path.exists(PROJECT_PATH):
        print(f"Error: {PROJECT_PATH} not found")
        return

    print(f"Reading {PROJECT_PATH}...")
    with open(PROJECT_PATH, 'r') as f:
        content = f.read()

    new_content = content
    count = 0

    for filename, correct_path in PATH_CORRECTIONS.items():
        # Look for: path = Filename.swift;
        # Replace with: path = Correct/Path/Filename.swift;
        
        # We need to be careful not to replace if it's already correct or if it matches something else.
        # The pattern in the file is usually: path = Filename.swift;
        
        old_str = f'path = {filename};'
        new_str = f'path = {correct_path};'
        
        if old_str in new_content:
            new_content = new_content.replace(old_str, new_str)
            print(f"Fixed path for {filename}")
            count += 1
        else:
            print(f"Could not find entry for {filename} (might be already fixed)")

    if count > 0:
        print(f"Writing {count} corrections to {PROJECT_PATH}...")
        with open(PROJECT_PATH, 'w') as f:
            f.write(new_content)
        print("Done.")
    else:
        print("No changes made.")

if __name__ == '__main__':
    fix_paths()
