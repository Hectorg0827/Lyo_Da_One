require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.find { |t| t.name == 'Lyo' }
if target.nil?
  puts "Error: Target 'Lyo' not found"
  exit 1
end

# Find or create the group path Sources/Components/Common
sources_group = project.main_group['Sources']
components_group = sources_group['Components']
common_group = components_group['Common']

# File to add
file_name = 'FlowLayout.swift'
file_path = "Sources/Components/Common/#{file_name}"

# Check if file is already in the group
existing_file = common_group.files.find { |f| f.path == file_name }

if existing_file
  puts "#{file_name} already exists in project structure."
  # Ensure it's in the target
  unless target.source_build_phase.files_references.include?(existing_file)
    target.add_file_references([existing_file])
    puts "Added #{file_name} to target."
  end
else
  # Add file to group and target
  new_file = common_group.new_file(file_name)
  target.add_file_references([new_file])
  puts "Added #{file_name} to project and target."
end

project.save
puts "Project saved."
