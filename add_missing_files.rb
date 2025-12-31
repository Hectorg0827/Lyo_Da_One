#!/usr/bin/env ruby
# encoding: UTF-8
# Add missing Swift files to Xcode project

require 'fileutils'
require 'securerandom'

project_file = '/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj/project.pbxproj'

# Backup
backup_path = "#{project_file}.backup_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
FileUtils.cp(project_file, backup_path)
puts "Created backup: #{backup_path}"

content = File.read(project_file, encoding: 'UTF-8')

# Generate unique IDs (24 hex chars)
def generate_id
  SecureRandom.hex(12).upcase
end

# Files to add with their relative paths from Sources/
files_to_add = [
  { name: 'CreateViewModel.swift', path: 'Sources/ViewModels/CreateViewModel.swift' },
  { name: 'CreationSheet.swift', path: 'Sources/Views/Main/Creation/CreationSheet.swift' }
]

added_files = []

files_to_add.each do |file_info|
  name = file_info[:name]
  path = file_info[:path]
  
  # Check if file already exists in project (properly, not as stale reference)
  if content.include?("path = #{path}")
    puts "✓ #{name} already correctly referenced in project"
    next
  end
  
  # Generate IDs
  file_ref_id = generate_id
  build_file_id = generate_id
  
  puts "Adding #{name}..."
  puts "  File Ref ID: #{file_ref_id}"
  puts "  Build File ID: #{build_file_id}"
  
  # 1. Add PBXFileReference
  file_ref_entry = "\t\t#{file_ref_id} /* #{name} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = #{path}; sourceTree = \"<group>\"; };\n"
  
  # Find the end of PBXFileReference section and insert before it
  file_ref_pattern = /(\s*\/\* End PBXFileReference section \*\/)/
  if content =~ file_ref_pattern
    content.sub!(file_ref_pattern, "#{file_ref_entry}\\1")
    puts "  ✓ Added PBXFileReference"
  else
    puts "  ✗ Could not find PBXFileReference section end"
    next
  end
  
  # 2. Add PBXBuildFile
  build_file_entry = "\t\t#{build_file_id} /* #{name} in Sources */ = {isa = PBXBuildFile; fileRef = #{file_ref_id} /* #{name} */; };\n"
  
  build_file_pattern = /(\s*\/\* End PBXBuildFile section \*\/)/
  if content =~ build_file_pattern
    content.sub!(build_file_pattern, "#{build_file_entry}\\1")
    puts "  ✓ Added PBXBuildFile"
  else
    puts "  ✗ Could not find PBXBuildFile section end"
    next
  end
  
  # 3. Add to main group's children (find the Sources group)
  # Look for the Sources group and add to its children
  # First, find the Sources group ID
  sources_group_pattern = /([A-F0-9]{24})\s*\/\*\s*Sources\s*\*\/\s*=\s*\{[^}]*isa\s*=\s*PBXGroup[^}]*\}/m
  
  if content =~ sources_group_pattern
    sources_group_id = $1
    puts "  Found Sources group: #{sources_group_id}"
    
    # Now add under the Sources group's children
    # Find the Sources group definition and add to its children array
    sources_children_pattern = /(#{sources_group_id}\s*\/\*\s*Sources\s*\*\/\s*=\s*\{[^}]*children\s*=\s*\([^)]*)/m
    
    if content =~ sources_children_pattern
      # Add the file reference to children
      content.sub!(sources_children_pattern, "\\1\n\t\t\t\t#{file_ref_id} /* #{name} */,")
      puts "  ✓ Added to Sources group children"
    end
  else
    puts "  ⚠ Could not find Sources group, adding to main group"
    
    # Fallback: add to the main project group
    main_children_pattern = /(mainGroup\s*=\s*)([A-F0-9]{24})/
    if content =~ main_children_pattern
      main_group_id = $2
      main_group_children_pattern = /(#{main_group_id}\s*\/\*[^*]*\*\/\s*=\s*\{[^}]*children\s*=\s*\([^)]*)/m
      if content =~ main_group_children_pattern
        content.sub!(main_group_children_pattern, "\\1\n\t\t\t\t#{file_ref_id} /* #{name} */,")
        puts "  ✓ Added to main group children"
      end
    end
  end
  
  # 4. Add to PBXSourcesBuildPhase files array
  # Find the build phase for the Lyo target
  sources_build_phase_pattern = /(\/\*\s*Sources\s*\*\/\s*=\s*\{[^}]*isa\s*=\s*PBXSourcesBuildPhase[^}]*files\s*=\s*\([^)]*)/m
  
  if content =~ sources_build_phase_pattern
    content.sub!(sources_build_phase_pattern, "\\1\n\t\t\t\t#{build_file_id} /* #{name} in Sources */,")
    puts "  ✓ Added to PBXSourcesBuildPhase"
  else
    puts "  ✗ Could not find PBXSourcesBuildPhase"
  end
  
  added_files << name
end

# Write updated content
File.write(project_file, content, encoding: 'UTF-8')

puts ""
if added_files.empty?
  puts "No files needed to be added (all already present)"
else
  puts "✓ Added #{added_files.length} files to project:"
  added_files.each { |f| puts "  - #{f}" }
end
puts "Backup saved: #{backup_path}"
