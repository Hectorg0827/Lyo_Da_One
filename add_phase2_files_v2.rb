#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find main target
main_target = project.targets.find { |t| t.name == 'Lyo' }
unless main_target
  puts "Error: Could not find 'Lyo' target"
  exit 1
end

# Files to add (with relative path from project root)
files_to_add = [
  { file: 'Sources/Core/AppUIState.swift', group_path: ['Sources', 'Core'] },
  { file: 'Sources/Components/AITutor/LioOrbView.swift', group_path: ['Sources', 'Components', 'AITutor'] },
  { file: 'Sources/Services/LioChatService.swift', group_path: ['Sources', 'Services'] },
  { file: 'Sources/Views/Main/AITutor/LioChatSheet.swift', group_path: ['Sources', 'Views', 'Main', 'AITutor'] }
]

# First, remove any bad file references that have doubled paths
project.files.each do |file_ref|
  path_str = file_ref.path.to_s
  if path_str.include?('Sources/') && path_str.count('/') > 5
    puts "Removing bad reference: #{path_str}"
    file_ref.remove_from_project
  end
end

def find_or_create_group(project, path_parts)
  current_group = project.main_group
  
  path_parts.each do |part|
    found = current_group.children.find { |g| g.display_name == part && g.is_a?(Xcodeproj::Project::Object::PBXGroup) }
    if found
      current_group = found
    else
      new_group = current_group.new_group(part, part)
      current_group = new_group
      puts "  Created group: #{part}"
    end
  end
  
  current_group
end

files_to_add.each do |file_info|
  file_path = file_info[:file]
  group_path = file_info[:group_path]
  file_basename = File.basename(file_path)
  
  # Check if file already exists correctly in project
  existing = project.files.find { |f| f.real_path.to_s == File.expand_path(file_path) rescue false }
  if existing
    puts "Skipping (already in project): #{file_path}"
    next
  end
  
  # Find or create the group
  group = find_or_create_group(project, group_path)
  
  # Add file reference with just the filename (the group provides the path context)
  file_ref = group.new_file(file_basename)
  
  # Add to target's compile sources
  main_target.source_build_phase.add_file_reference(file_ref)
  
  puts "Added: #{file_path}"
end

project.save
puts "\nProject saved successfully!"
