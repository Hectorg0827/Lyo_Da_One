#!/bin/bash

# Generate unique IDs
FILE_REF=$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-' | cut -c1-24 | tr '[:lower:]' '[:upper:]')
BUILD_FILE=$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-' | cut -c1-24 | tr '[:upper:]' '[:upper:]')

# Backup the project file
cp "Lyo.xcodeproj/project.pbxproj" "Lyo.xcodeproj/project.pbxproj.backup"

# Add the file reference in PBXFileReference section
sed -i '' "/\/\* Begin PBXFileReference section \*\//a\\
$FILE_REF /* EnhancedLyoHomeView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = EnhancedLyoHomeView.swift; sourceTree = \"<group>\"; };
" "Lyo.xcodeproj/project.pbxproj"

# Add the build file in PBXBuildFile section
sed -i '' "/\/\* Begin PBXBuildFile section \*\//a\\
$BUILD_FILE /* EnhancedLyoHomeView.swift in Sources */ = {isa = PBXBuildFile; fileRef = $FILE_REF /* EnhancedLyoHomeView.swift */; };
" "Lyo.xcodeproj/project.pbxproj"

# Find the AITutor group and add the file there
awk -v file_ref="$FILE_REF" '
/6A7D94D2885CAB9768DC0D58 \/\* LyoHomeView.swift \*\// {
    print $0
    print "\t\t\t\t" file_ref " /* EnhancedLyoHomeView.swift */,"
    next
}
{print}
' "Lyo.xcodeproj/project.pbxproj" > "Lyo.xcodeproj/project.pbxproj.tmp" && mv "Lyo.xcodeproj/project.pbxproj.tmp" "Lyo.xcodeproj/project.pbxproj"

# Add to Sources build phase
awk -v build_file="$BUILD_FILE" '
/6A00D4DB215BB65065B18C64 \/\* LyoHomeView.swift in Sources \*\// {
    print $0
    print "\t\t\t\t" build_file " /* EnhancedLyoHomeView.swift in Sources */,"
    next
}
{print}
' "Lyo.xcodeproj/project.pbxproj" > "Lyo.xcodeproj/project.pbxproj.tmp" && mv "Lyo.xcodeproj/project.pbxproj.tmp" "Lyo.xcodeproj/project.pbxproj"

echo "File added successfully!"
