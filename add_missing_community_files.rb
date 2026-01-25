#!/usr/bin/env ruby
require "xcodeproj"

project_path = "/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj"
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == "Lyo" }

# Find Views/Community group
views_group = nil
community_group = nil

project.main_group.recursive_children.each do |child|
  next unless child.is_a?(Xcodeproj::Project::Object::PBXGroup)
  
  if child.display_name == "Views" && child.parent&.display_name == "Sources"
    views_group = child
  end
end

if views_group
  community_group = views_group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.display_name == "Community" }
  
  if community_group.nil?
    puts "Community group not found!"
    exit 1
  end
else
  puts "Views group not found"
  exit 1
end

# Files to add
files_to_add = [
  "MyActivitiesView.swift",
  "PrivateLessonDetailView.swift",
  "EducationalCenterDetailView.swift",
  "BookingCalendarView.swift",
  "ReviewInputView.swift",
  "ReviewListView.swift"
]

files_to_add.each do |file_name|
  # Check if already in project
  existing = community_group.files.find { |f| f.display_name == file_name }
  if existing.nil?
    # Ensure full path is used relative to the group
    # Since the group structure mirrors the file system, we assume naming matches
    file_ref = community_group.new_reference(file_name)
    target.source_build_phase.add_file_reference(file_ref)
    puts "Added #{file_name}"
  else
    puts "#{file_name} already exists"
  end
end

project.save
puts "Project saved"
