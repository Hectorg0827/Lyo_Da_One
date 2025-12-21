#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'Lyo' }
if target.nil?
  puts "Error: Target 'Lyo' not found"
  exit 1
end

# Get the Sources group
sources_group = project.main_group['Sources']

# Files to add (Stories components)
files_to_add = [
  'Sources/Views/Components/Stories/StoriesRailView.swift',
  'Sources/Views/Components/Stories/StoryCircleView.swift',
  'Sources/Views/Components/Stories/StoryViewer.swift',
  'Sources/Services/StoryService.swift'
]

added_count = 0

files_to_add.each do |file_path|
  # Check if file exists
  unless File.exist?(file_path)
    puts "⚠️ File not found: #{file_path}"
    next
  end
  
  # Find or create appropriate group
  path_parts = file_path.split('/')
  current_group = sources_group
  
  # Navigate/create group path (skip 'Sources')
  path_parts[1...-1].each do |part|
    found_group = current_group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.name == part }
    if found_group
      current_group = found_group
    else
      current_group = current_group.new_group(part)
    end
  end
  
  # Check if file already exists in project
  file_name = File.basename(file_path)
  existing_file = current_group.files.find { |f| f.name == file_name || f.path == file_name }
  
  if existing_file
    puts "⏭️ Already exists: #{file_path}"
  else
    # Add file reference
    file_ref = current_group.new_file(File.absolute_path(file_path))
    target.source_build_phase.add_file_reference(file_ref)
    puts "✅ Added: #{file_path}"
    added_count += 1
  end
end

project.save
puts "\n🎉 Added #{added_count} new files to Xcode project!"
