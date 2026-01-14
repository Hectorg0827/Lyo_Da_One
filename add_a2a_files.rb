#!/usr/bin/env ruby
require 'xcodeproj'

project_path = File.join(Dir.pwd, 'Lyo.xcodeproj')
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Get the Sources group
sources_group = project.main_group['Sources']

# A2A files to add
files_to_add = [
  'Sources/Models/AI/A2AModels.swift',
  'Sources/Views/AI/A2AGenerationProgressView.swift',
  'Sources/Services/A2ACourseService.swift',
  'Sources/Services/A2UI/AIResponseParser.swift',
  'Sources/Services/A2UI/CourseOrchestrator.swift',
]

def find_or_create_group(parent_group, path_components)
  return parent_group if path_components.empty?

  group_name = path_components.first
  group = parent_group[group_name] || parent_group.new_group(group_name, group_name)

  find_or_create_group(group, path_components[1..-1])
end

files_to_add.each do |file_path|
  full_path = File.join(Dir.pwd, file_path)

  unless File.exist?(full_path)
    puts "WARNING: File does not exist: #{full_path}"
    next
  end

  # Parse path to find the right group
  if file_path.start_with?('Sources/')
    path_parts = file_path.split('/')[1..-1]  # Remove 'Sources' prefix
    group_to_use = sources_group
  else
    path_parts = file_path.split('/')
    group_to_use = project.main_group
  end
  file_name = path_parts.pop

  # Find or create the appropriate group
  group = find_or_create_group(group_to_use, path_parts)

  # Check if file is already in the group to avoid duplicates
  existing_file = group.files.find { |f| f.path == full_path || f.name == file_name }
  
  if existing_file
    puts "Skipping existing file: #{file_path}"
  else
    # Add the file reference
    file_ref = group.new_file(full_path)

    # Add to build phase if it's a Swift file
    if file_name.end_with?('.swift')
      target.add_file_references([file_ref])
    end
    puts "Added: #{file_path}"
  end
end

# Save the project
project.save

puts "\n✅ Successfully added A2A files to Xcode project!"
