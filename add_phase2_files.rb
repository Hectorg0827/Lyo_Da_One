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

# Files to add
files_to_add = [
  { path: 'Sources/Core/AppUIState.swift', group: 'Sources/Core' },
  { path: 'Sources/Components/AITutor/LioOrbView.swift', group: 'Sources/Components/AITutor' },
  { path: 'Sources/Services/LioChatService.swift', group: 'Sources/Services' },
  { path: 'Sources/Views/Main/AITutor/LioChatSheet.swift', group: 'Sources/Views/Main/AITutor' }
]

def find_or_create_group(project, path)
  parts = path.split('/')
  current_group = project.main_group
  
  parts.each do |part|
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
  file_path = file_info[:path]
  group_path = file_info[:group]
  
  # Check if file already exists in project
  existing = project.files.find { |f| f.real_path.to_s.end_with?(file_path) }
  if existing
    puts "Skipping (already in project): #{file_path}"
    next
  end
  
  # Find or create the group
  group = find_or_create_group(project, group_path)
  
  # Add file reference
  file_basename = File.basename(file_path)
  file_ref = group.new_file(file_path)
  
  # Add to target's compile sources
  main_target.source_build_phase.add_file_reference(file_ref)
  
  puts "Added: #{file_path}"
end

project.save
puts "\nProject saved successfully!"
