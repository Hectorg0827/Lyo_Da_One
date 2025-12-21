#!/usr/bin/env ruby
require 'xcodeproj'

project_path = File.join(Dir.pwd, 'Lyo.xcodeproj')
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Get the Sources group
sources_group = project.main_group['Sources']

# Files to add
files_to_add = [
  'Sources/Models/TutorModels.swift',
  'Sources/Services/TutorService.swift',
  'Sources/Views/Main/Classroom/TutorModeView.swift'
]

def find_or_create_group(parent, path_components)
  return parent if path_components.empty?
  
  name = path_components.first
  group = parent[name] || parent.new_group(name)
  find_or_create_group(group, path_components[1..-1])
end

files_to_add.each do |file_path|
  full_path = File.join(Dir.pwd, file_path)
  
  next unless File.exist?(full_path)
  
  # Parse path to get group structure
  components = file_path.split('/')[1..-2] # Skip 'Sources' prefix and filename
  filename = File.basename(file_path)
  
  # Find/create the appropriate group
  group = find_or_create_group(sources_group, components)
  
  # Check if file already exists in the group
  existing = group.files.find { |f| f.path == filename }
  
  unless existing
    file_ref = group.new_reference(full_path)
    file_ref.path = filename
    file_ref.source_tree = '<group>'
    target.add_file_references([file_ref])
    puts "Added: #{file_path}"
  else
    puts "Already exists: #{file_path}"
  end
end

project.save

puts "\n✅ Successfully added tutor files to Xcode project!"
