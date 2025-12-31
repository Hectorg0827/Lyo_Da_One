#!/usr/bin/env ruby
# Fix stale file references in Xcode project
# Removes file references that point to non-existent paths

require 'fileutils'

project_file = '/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj/project.pbxproj'

# List of files that Xcode expects at root level but are actually elsewhere
stale_paths = [
  'CameraPreview.swift',
  'CampusItemDetailSheet.swift',
  'CampusView.swift',
  'ChallengesHomeView.swift',
  'ChatBubbleView.swift',
  'ChatHistoryView.swift',
  'ChatOverlayView.swift',
  'ClassroomView.swift',
  'CourseDrawerView.swift',
  'CreateEventView.swift',
  'CreationSheet.swift',
  'DiscoverReelView.swift',
  'DiscoverView.swift',
  'EnhancedLyoHomeView.swift',
  'FloatingOrbView.swift',
  'FocusView.swift',
  'GlobalSearchView.swift',
  'HeroSectionView.swift',
  'HolisticProfileView.swift',
  'HybridLyoHomeView.swift',
  'LioChatSheet.swift',
  'LiveClassroomView.swift',
  'LyoAvatarView.swift',
  'LyoHomeView.swift',
  'LyoOverlayView.swift',
  'MasteryProfileView.swift',
  'NotificationsView.swift',
  'PostEditorView.swift',
  'PremiumHomeView.swift',
  'ProactiveHintBanner.swift',
  'ProfileHomeView.swift',
  'QuizOverlayView.swift',
  'ReelActionStrip.swift',
  'ReelHeaderView.swift',
  'ReelInfoOverlay.swift',
  'SimpleVideoContextSheet.swift',
  'SmartMemoryService.swift',
  'SocialFeedSection.swift',
  'SoftSkillsService.swift',
  'StackDrawerView.swift',
  'StackPanelView.swift',
  'TopHeaderView.swift',
  'TranscriptSheet.swift',
  'TutorModeView.swift',
  'VideoContextSheet.swift',
  'VideoRecorderView.swift',
]

# Bad path patterns (references with wrong paths)
bad_path_patterns = [
  'Sources/Views/Profile/Views/Profile/HolisticProfileView.swift',
  'Sources/Views/Components/Views/Components/ProactiveHintBanner.swift',
  'Sources/Services/Services/SmartMemoryService.swift',
  'Sources/Services/Services/SoftSkillsService.swift',
]

# Read the project file
puts "Reading project file..."
content = File.read(project_file)
original_content = content.dup

# Create backup
backup_path = "#{project_file}.backup_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
FileUtils.cp(project_file, backup_path)
puts "Created backup at: #{backup_path}"

# Track removed references
removed_refs = []
removed_build_files = []

# Find and collect file reference IDs to remove
file_ref_ids_to_remove = []

# Pattern to match file references with stale paths
stale_paths.each do |filename|
  # Look for file references that point to root level (without Sources/ prefix)
  # These patterns match entries like:
  # ABCD1234 /* CameraPreview.swift */ = {isa = PBXFileReference; ... path = CameraPreview.swift; ...};
  
  # Match direct root-level references (path = "filename" without directory)
  pattern = /\s*([A-F0-9]{24})\s*\/\*\s*#{Regexp.escape(filename)}\s*\*\/\s*=\s*\{[^}]*path\s*=\s*"?#{Regexp.escape(filename)}"?\s*;[^}]*\};\n?/m
  
  content.scan(pattern) do |match|
    ref_id = match[0]
    file_ref_ids_to_remove << ref_id
    puts "Found stale reference: #{ref_id} -> #{filename}"
  end
end

# Handle bad nested path patterns
bad_path_patterns.each do |bad_path|
  filename = File.basename(bad_path)
  pattern = /\s*([A-F0-9]{24})\s*\/\*\s*#{Regexp.escape(filename)}\s*\*\/\s*=\s*\{[^}]*path\s*=\s*"?#{Regexp.escape(bad_path)}"?\s*;[^}]*\};\n?/m
  
  content.scan(pattern) do |match|
    ref_id = match[0]
    file_ref_ids_to_remove << ref_id
    puts "Found bad path reference: #{ref_id} -> #{bad_path}"
  end
end

puts "\nFound #{file_ref_ids_to_remove.length} stale file references"

# Remove the file references and associated build file entries
file_ref_ids_to_remove.uniq.each do |ref_id|
  # Remove PBXFileReference entry
  content.gsub!(/^\s*#{ref_id}\s*\/\*.*?\*\/\s*=\s*\{[^}]*\};\s*\n?/m, '')
  
  # Remove PBXBuildFile entries that reference this file
  content.gsub!(/^\s*[A-F0-9]{24}\s*\/\*.*?#{ref_id}.*?\*\/\s*=\s*\{[^}]*\};\s*\n?/m, '')
  
  # Remove from PBXGroup children arrays
  content.gsub!(/^\s*#{ref_id}\s*\/\*.*?\*\/,?\s*\n?/m, '')
  
  # Remove from PBXSourcesBuildPhase files arrays
  content.gsub!(/^\s*[A-F0-9]{24}\s*\/\*.*?in Sources.*?\*\/,?\s*\n?/, '')
  
  removed_refs << ref_id
end

# Also look for any remaining references to files at root level
stale_paths.each do |filename|
  # Remove any buildFile references pointing to just the filename (not in Sources/)
  pattern_build = /^\s*([A-F0-9]{24})\s*\/\*\s*#{Regexp.escape(filename)} in Sources\s*\*\/\s*=\s*\{[^}]*fileRef\s*=\s*([A-F0-9]{24})[^}]*\};\s*\n?/m
  
  content.scan(pattern_build) do |match|
    build_file_id = match[0]
    file_ref_id = match[1]
    
    # Check if this file ref points to root level (we need to verify in PBXFileReference)
    ref_pattern = /#{file_ref_id}\s*\/\*[^*]*\*\/\s*=\s*\{[^}]*path\s*=\s*"?#{Regexp.escape(filename)}"?\s*;/
    
    if content =~ ref_pattern
      # This appears to be a root-level reference - check if Sources/ version exists
      source_pattern = /[A-F0-9]{24}\s*\/\*\s*#{Regexp.escape(filename)}\s*\*\/\s*=\s*\{[^}]*path\s*=\s*"?Sources\/[^"]*#{Regexp.escape(filename)}"?\s*;/
      
      if content !~ source_pattern
        puts "Removing orphaned build file: #{build_file_id} for #{filename}"
        content.gsub!(/^\s*#{build_file_id}\s*\/\*.*?\*\/\s*=\s*\{[^}]*\};\s*\n?/m, '')
        removed_build_files << build_file_id
      end
    end
  end
end

# Clean up any dangling commas in arrays
content.gsub!(/,(\s*\);)/, '\1')
content.gsub!(/\(\s*,/, '(')

# Write the modified content
if content != original_content
  File.write(project_file, content)
  puts "\n✓ Updated project.pbxproj"
  puts "  Removed #{removed_refs.length} stale file references"
  puts "  Removed #{removed_build_files.length} orphaned build file entries"
else
  puts "\nNo stale references found matching stale root-level paths."
  puts "The issue may be with bad path patterns in the project file."
end

puts "\nBackup saved at: #{backup_path}"
puts "\nIf the build still fails, try:"
puts "  1. Open Xcode"
puts "  2. Select the project in the navigator"
puts "  3. Look for red (missing) files"
puts "  4. Delete those references manually"
puts "  5. Then re-add the files from their correct locations in Sources/"
