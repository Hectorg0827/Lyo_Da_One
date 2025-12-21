#!/usr/bin/env ruby
require 'xcodeproj'

project_path = File.join(Dir.pwd, 'Lyo.xcodeproj')
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'Lyo' } || project.targets.first

# Files to add
files_to_add = [
  'Sources/Models/PersonalizationModels.swift',
  'Sources/Services/PersonalizationService.swift',
  'Sources/Views/Main/Profile/MasteryProfileView.swift'
]

files_to_add.each do |file_path|
  # Split path into components
  components = file_path.split('/')
  filename = components.pop
  
  # Navigate/create groups
  current_group = project.main_group
  components.each do |group_name|
    current_group = current_group[group_name] || current_group.new_group(group_name)
  end
  
  # Check if file already exists in group
  file_ref = current_group.files.find { |f| f.path == filename }
  if file_ref.nil?
    file_ref = current_group.new_file(filename)
    target.add_file_references([file_ref])
    puts "Added #{file_path} to project and target."
  else
    # Ensure it's in the target
    unless target.source_build_phase.files.any? { |f| f.file_ref == file_ref }
      target.add_file_references([file_ref])
      puts "Added existing file reference #{file_path} to target."
    else
      puts "#{file_path} already exists in project and target."
    end
  end
end

project.save
puts "Project saved."
