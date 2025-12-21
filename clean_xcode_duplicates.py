#!/usr/bin/env python3
"""
Clean duplicate entries from Xcode project.pbxproj file.
Removes duplicate source file entries from PBXBuildFile and PBXSourcesBuildPhase sections.
"""

import re
import sys
from pathlib import Path

def clean_pbxproj(filepath: str) -> None:
    """Remove duplicate source entries from pbxproj file."""
    
    pbxproj = Path(filepath)
    if not pbxproj.exists():
        print(f"Error: File not found: {filepath}")
        sys.exit(1)
    
    content = pbxproj.read_text()
    
    # Extract PBXSourcesBuildPhase files section
    sources_pattern = r'(/\* Begin PBXSourcesBuildPhase section \*/.*?files = \()([^)]+)(\);.*?/\* End PBXSourcesBuildPhase section \*/)'
    
    match = re.search(sources_pattern, content, re.DOTALL)
    if not match:
        print("Could not find PBXSourcesBuildPhase section")
        sys.exit(1)
    
    # Parse file entries
    files_content = match.group(2)
    entries = [line.strip() for line in files_content.strip().split('\n') if line.strip()]
    
    # Track seen file names (basename) to remove duplicates
    seen_files = {}
    unique_entries = []
    duplicates_removed = 0
    
    for entry in entries:
        # Extract file name from entry like: "ABC123 /* FileName.swift in Sources */,"
        file_match = re.search(r'/\* ([^/]+) in Sources \*/', entry)
        if file_match:
            filename = file_match.group(1)
            if filename not in seen_files:
                seen_files[filename] = entry
                unique_entries.append(entry)
            else:
                duplicates_removed += 1
                print(f"  Removing duplicate: {filename}")
        else:
            unique_entries.append(entry)
    
    if duplicates_removed == 0:
        print("No duplicates found in PBXSourcesBuildPhase")
        return
    
    # Reconstruct files section
    new_files_content = '\n\t\t\t\t' + ',\n\t\t\t\t'.join(unique_entries)
    
    # Replace in content
    new_content = content[:match.start(2)] + new_files_content + '\n\t\t\t' + content[match.end(2):]
    
    # Backup original
    backup_path = pbxproj.with_suffix('.pbxproj.cleanup_backup')
    pbxproj.rename(backup_path)
    print(f"Backed up to: {backup_path}")
    
    # Write cleaned content
    pbxproj.write_text(new_content)
    
    print(f"\n✅ Removed {duplicates_removed} duplicate entries")
    print(f"Unique source files: {len(unique_entries)}")


if __name__ == "__main__":
    pbxproj_path = "/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj/project.pbxproj"
    print(f"Cleaning: {pbxproj_path}\n")
    clean_pbxproj(pbxproj_path)
