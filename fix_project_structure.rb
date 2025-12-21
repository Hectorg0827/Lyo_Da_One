#!/usr/bin/env ruby
require 'xcodeproj'
require 'pathname'

project_path = '/Users/hectorgarcia/LYO Da ONE /Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first
sources_group = project.main_group['Sources']

root_dir = '/Users/hectorgarcia/LYO Da ONE '

puts "Scanning project..."

# 1. Fix Sources/Utils if it's added as a file reference
# We look for a child named 'Utils' in Sources group
utils_ref = sources_group.children.find { |c| (c.name == 'Utils' || c.path == 'Utils') }

if utils_ref && utils_ref.isa == 'PBXFileReference'
  puts "Found incorrect file reference for 'Utils' folder. Removing it..."
  # Remove from build phases first
  target.source_build_phase.remove_file_reference(utils_ref)
  utils_ref.remove_from_project
end

# Helper to find or create group
def find_or_create_group(parent_group, path_components)
  return parent_group if path_components.empty?
  group_name = path_components.first
  
  # Check if child exists and is a group
  child = parent_group.children.find { |c| (c.name == group_name || c.path == group_name) && c.isa == 'PBXGroup' }
  
  if child
    group = child
  else
    # puts "Creating group: #{group_name}"
    group = parent_group.new_group(group_name, group_name)
  end
  find_or_create_group(group, path_components[1..-1])
end

# 2. Scan all swift files in Sources
Dir.chdir(root_dir) do
  Dir.glob('Sources/**/*.swift').each do |file_path|
    full_path = File.join(root_dir, file_path)
    
    # Navigate to the group
    path_parts = file_path.split('/')
    path_parts.shift # Remove 'Sources'
    file_name = path_parts.pop
    
    group = find_or_create_group(sources_group, path_parts)
    
    # Check if file exists in group
    existing_file = group.files.find { |f| f.path == file_name || f.name == file_name }
    
    if existing_file
      # Ensure it is in the compile sources build phase
      unless target.source_build_phase.files_references.include?(existing_file)
        puts "Adding missing build phase for: #{file_path}"
        target.add_file_references([existing_file])
      end
    else
      puts "Adding missing file: #{file_path}"
      file_ref = group.new_file(full_path)
      target.add_file_references([file_ref])
    end
  end
end

project.save
puts "✅ Project structure fixed!"
