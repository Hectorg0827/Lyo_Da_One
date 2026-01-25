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

# Find the valid group path: Lyo/Sources/Core
group_path = ['Sources', 'Core']
current_group = project.main_group

group_path.each do |name|
  current_group = current_group[name]
  if current_group.nil?
    puts "Error: Group #{name} not found"
    exit 1
  end
end

puts "Found Core group: #{current_group.path}"

# Clean up existing A2UI group to avoid duplication/nesting errors
existing_a2ui = current_group['A2UI']
if existing_a2ui
  puts "Removing existing A2UI group to clean up..."
  existing_a2ui.remove_from_project
end

# Create new A2UI group
# We set the path relative to the parent group (Core) which is likely 'Sources/Core'
# So A2UI group path should be just 'A2UI'
a2ui_group = current_group.new_group('A2UI', 'A2UI') # Relative path

puts "Created A2UI group"

# Files to add
files = [
  'A2UIElementType.swift',
  'A2UIComponent.swift',
  'A2UIProps.swift',
  'A2UICapabilityNegotiator.swift',
  'A2UIRenderer.swift'
]

# Add core files
files.each do |file|
  file_path = "A2UI/#{file}" 
  # Since we are adding to a2ui_group which has path 'A2UI' relative to Core,
  # and Core has path 'Core' relative to Sources,
  # we just add the file by name to the group, and set its path.
  # Actually, Xcodeproj handles this if we just new_file(file_name) on the group
  
  file_ref = a2ui_group.new_file(file)
  target.add_file_references([file_ref])
  puts "Added #{file}"
end

# Handle Views View Controller
views_group = a2ui_group.new_group('Views', 'Views')

view_files = Dir.glob('Sources/Core/A2UI/Views/*.swift').map { |f| File.basename(f) }

view_files.each do |file|
  file_ref = views_group.new_file(file)
  target.add_file_references([file_ref])
  puts "Added Views/#{file}"
end

project.save
puts "Project saved successfully."
