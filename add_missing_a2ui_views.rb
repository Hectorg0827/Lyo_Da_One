#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target_name = 'Lyo'
target = project.targets.find { |t| t.name == target_name }

if target.nil?
  puts "Error: Target #{target_name} not found"
  exit 1
end

def add_file_to_project(project, target, file_path, group_path)
  # Navigate to the group
  current_group = project.main_group
  group_path.each do |name|
    next_group = current_group[name]
    if next_group.nil?
      puts "  Creating group: #{name}"
      next_group = current_group.new_group(name, name)
    end
    current_group = next_group
  end
  
  # Check if file already exists in group
  file_name = File.basename(file_path)
  existing_ref = current_group.files.find { |f| f.path == file_name }
  
  if existing_ref
    puts "  [SKIP] #{file_name} already in project"
    return
  end
  
  # Add file
  file_ref = current_group.new_file(file_path)
  target.source_build_phase.add_file_reference(file_ref)
  puts "  [ADDED] #{file_name}"
end

puts "Adding missing view files to Xcode project..."

# Files in Sources/Views/Components
components_files = [
  ['Sources/Views/Components/MagicalBackgroundView.swift', ['Sources', 'Views', 'Components']],
  ['Sources/Views/Components/MagicEffectView.swift', ['Sources', 'Views', 'Components']],
]

# Files in Sources/Views/Classroom
classroom_files = [
  ['Sources/Views/Classroom/BlockRendererView.swift', ['Sources', 'Views', 'Classroom']],
]

all_files = components_files + classroom_files

all_files.each do |file_info|
  file_path = file_info[0]
  group_path = file_info[1]
  
  # Check file exists on disk
  unless File.exist?(file_path)
    puts "  [MISSING] #{file_path} does not exist on disk!"
    next
  end
  
  add_file_to_project(project, target, file_path, group_path)
end

project.save
puts "Done! Project saved."
