#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Lyo' }
unless target
  puts "Error: Target 'Lyo' not found"
  exit 1
end

# Files to add with correct paths
files_to_add = [
  'Sources/Models/UIStackModels.swift',
  'Sources/Services/UIStackStore.swift',
  'Sources/Components/Common/StackCardView.swift',
  'Sources/Views/Main/Stack/StackPanelView.swift'
]

def find_group(project, path_parts)
  current_group = project.main_group
  path_parts.each do |part|
    found = current_group.children.find { |g| g.display_name == part && g.is_a?(Xcodeproj::Project::Object::PBXGroup) }
    if found
      current_group = found
    else
      # Create the group if it doesn't exist
      new_group = current_group.new_group(part, part)
      current_group = new_group
      puts "  Created group: #{part}"
    end
  end
  current_group
end

files_to_add.each do |file_path|
  # Check if file already exists in project correctly
  full_path = File.expand_path(file_path, Dir.pwd)
  existing = project.files.find { |f| (f.real_path.to_s rescue nil) == full_path }
  
  if existing
    puts "Already exists correctly: #{file_path}"
    next
  end
  
  # Split path and get group path (all but the filename)
  parts = file_path.split('/')
  filename = parts.pop
  group = find_group(project, parts)
  
  # Add file reference - just use the filename since the group has the path
  file_ref = group.new_file(filename)
  
  # Add to compile sources
  target.source_build_phase.add_file_reference(file_ref)
  
  puts "Added: #{file_path}"
end

project.save
puts "\nProject saved!"
