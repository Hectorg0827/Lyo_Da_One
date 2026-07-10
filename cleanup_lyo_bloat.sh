#!/bin/bash
#
# cleanup_lyo_bloat.sh
# Safely removes 40GB+ of build artifacts and caches from LYO_Da_ONE
#
# Safety: Uses rm -i for confirmations on directories
# Backup: Creates a manifest of what's being deleted
#

set -e

REPO_PATH="/Users/hectorgarcia/LYO_Da_ONE"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MANIFEST_FILE="$REPO_PATH/cleanup_manifest_${TIMESTAMP}.txt"

echo "🧹 LYO_Da_ONE Repository Cleanup"
echo "=================================="
echo "Repo: $REPO_PATH"
echo "Timestamp: $TIMESTAMP"
echo ""

# Safety check
if [ ! -d "$REPO_PATH" ]; then
    echo "❌ Error: $REPO_PATH not found"
    exit 1
fi

if [ ! -d "$REPO_PATH/.git" ]; then
    echo "❌ Error: Not a git repository"
    exit 1
fi

echo "📋 Creating deletion manifest in: $MANIFEST_FILE"
{
    echo "Cleanup Manifest - $TIMESTAMP"
    echo "=============================="
    echo ""
    echo "Directories to be deleted:"
} > "$MANIFEST_FILE"

# Track total size
TOTAL_SIZE=0

# Function to safely delete directory
delete_dir() {
    local dir="$1"
    local desc="$2"
    
    if [ -d "$dir" ]; then
        local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
        echo ""
        echo "🗑️  $desc: $size"
        echo "   Path: $dir"
        echo ""
        echo "   $desc: $size ($dir)" >> "$MANIFEST_FILE"
        
        read -p "   Delete? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$dir"
            echo "   ✅ Deleted"
        else
            echo "   ⏭️  Skipped"
        fi
    fi
}

# Function to safely delete files
delete_files() {
    local pattern="$1"
    local desc="$2"
    
    local count=$(find "$REPO_PATH" -maxdepth 1 -name "$pattern" 2>/dev/null | wc -l)
    
    if [ "$count" -gt 0 ]; then
        local size=$(find "$REPO_PATH" -maxdepth 1 -name "$pattern" -exec du -sh {} + 2>/dev/null | tail -1 | cut -f1)
        echo ""
        echo "🗑️  $desc: ~$size ($count files)"
        echo ""
        echo "   $desc: ~$size ($count files matching '$pattern')" >> "$MANIFEST_FILE"
        
        read -p "   Delete? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            find "$REPO_PATH" -maxdepth 1 -name "$pattern" -exec rm -f {} +
            echo "   ✅ Deleted"
        else
            echo "   ⏭️  Skipped"
        fi
    fi
}

# Show current size
echo "📊 Current repository size:"
du -sh "$REPO_PATH"
echo ""

# Start deletion prompts
echo "🔍 Ready to delete the following bloat:"
echo ""

# 1. Lyo_Da_One duplicate project (4.8GB)
delete_dir "$REPO_PATH/Lyo_Da_One" "Duplicate Lyo_Da_One directory"

# 2. Derived data caches
delete_dir "$REPO_PATH/.derived-data-build" "Derived data cache: .derived-data-build"
delete_dir "$REPO_PATH/.derived-data-build2" "Derived data cache: .derived-data-build2"
delete_dir "$REPO_PATH/.derived-data-sim" "Derived data cache: .derived-data-sim"
delete_dir "$REPO_PATH/.derived-data-verify" "Derived data cache: .derived-data-verify"
delete_dir "$REPO_PATH/.derived-data-sdk" "Derived data cache: .derived-data-sdk"
delete_dir "$REPO_PATH/.derived-data-postgen" "Derived data cache: .derived-data-postgen"
delete_dir "$REPO_PATH/.derived-data-ci" "Derived data cache: .derived-data-ci"

# 3. SPM caches
delete_dir "$REPO_PATH/.build" "SPM build cache: .build"
delete_dir "$REPO_PATH/SourcePackages" "SPM packages: SourcePackages"

# 4. Temporary builds
delete_dir "$REPO_PATH/build_temp" "Temporary build directory: build_temp"
delete_dir "$REPO_PATH/build_temp_3" "Temporary build directory: build_temp_3"

# 5. Old log files
delete_files "build*.log" "Build log files: build*.log"
delete_files "build*.txt" "Build text files: build*.txt"
delete_files "*.log" "Other log files: *.log"
delete_files "pkg_resolve*.log" "Package resolution logs: pkg_resolve*.log"
delete_files "settings_check.log" "Settings check logs: settings_check.log"

# 6. System files
echo ""
echo "🗑️  System files (.DS_Store)"
read -p "   Delete all .DS_Store files? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    find "$REPO_PATH" -name ".DS_Store" -type f -delete
    echo "   ✅ Deleted"
    echo "   System files: .DS_Store files" >> "$MANIFEST_FILE"
else
    echo "   ⏭️  Skipped"
fi

# Optional: build/ directory (keep scripts, delete artifacts)
echo ""
echo "⚠️  build/ directory (5.2GB) - Contains build scripts AND artifacts"
echo "   Recommend: Manual review or delete selectively"
read -p "   Review build/ contents? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "   Build directory contents:"
    ls -lh "$REPO_PATH/build/" | head -20
    echo ""
    read -p "   Delete entire build/ directory? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$REPO_PATH/build"
        echo "   ✅ Deleted"
        echo "   Entire build/ directory (5.2GB)" >> "$MANIFEST_FILE"
    fi
fi

# Show final size
echo ""
echo "=================================="
echo "✅ Cleanup complete!"
echo ""
echo "📊 New repository size:"
du -sh "$REPO_PATH"
echo ""
echo "📋 Manifest saved: $MANIFEST_FILE"
echo ""
echo "🚀 Next steps:"
echo "  1. Close Xcode completely: killall Xcode"
echo "  2. Clear Xcode caches: rm -rf ~/Library/Developer/Xcode/DerivedData/*"
echo "  3. Rebuild project in Xcode"
echo ""
echo "💡 To revert deleted files: git checkout <files> (if they were in git)"
echo ""
