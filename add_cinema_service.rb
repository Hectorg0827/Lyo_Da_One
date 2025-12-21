require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'Lyo' }

if target.nil?
  puts "❌ Could not find target 'Lyo'"
  exit 1
end

# Find the Sources/Services group
sources_group = project.main_group['Sources']
if sources_group.nil?
  puts "❌ Could not find Sources group"
  exit 1
end

services_group = sources_group['Services']
if services_group.nil?
  # Create Services group if it doesn't exist
  services_group = sources_group.new_group('Services', 'Sources/Services')
end

# Check if file already exists in project
existing_file = services_group.files.find { |f| f.path == 'InteractiveCinemaService.swift' }

if existing_file
  puts "⚠️  InteractiveCinemaService.swift already in project group"
else
  # Add the file reference
  file_ref = services_group.new_reference('InteractiveCinemaService.swift')
  
  # Add to build phase
  target.source_build_phase.add_file_reference(file_ref)
  
  puts "✅ Added InteractiveCinemaService.swift to project"
end

# Save the project
project.save

puts "✅ Project saved successfully"
puts ""
puts "Files in Services group:"
services_group.files.each do |file|
  puts "  - #{file.path}"
end
