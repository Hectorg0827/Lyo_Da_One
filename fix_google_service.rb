#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Lyo' }
if target.nil?
  puts "Error: Target 'Lyo' not found"
  exit 1
end

# Find or create Resources group
resources_group = project.main_group['Sources']['Resources']
if resources_group.nil?
  puts "Creating Resources group..."
  sources_group = project.main_group['Sources']
  resources_group = sources_group.new_group('Resources', 'Resources')
end

file_path = 'Sources/Resources/GoogleService-Info.plist'
file_ref = resources_group.files.find { |f| f.path == 'GoogleService-Info.plist' }

if file_ref.nil?
  puts "Adding GoogleService-Info.plist to project..."
  file_ref = resources_group.new_file('GoogleService-Info.plist')
else
  puts "GoogleService-Info.plist already in project structure."
end

# Add to Copy Bundle Resources phase
resources_phase = target.resources_build_phase
build_file = resources_phase.files.find { |f| f.file_ref == file_ref }

if build_file.nil?
  puts "Adding GoogleService-Info.plist to Copy Bundle Resources phase..."
  resources_phase.add_file_reference(file_ref)
  project.save
  puts "Project saved."
else
  puts "GoogleService-Info.plist already in Copy Bundle Resources phase."
end
