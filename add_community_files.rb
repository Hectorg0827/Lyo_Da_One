#!/usr/bin/env ruby
require "xcodeproj"

project_path = "/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj"
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == "Lyo" }

# Find Views/Community group, creating it if needed
views_group = nil
community_group = nil
components_group = nil

project.main_group.recursive_children.each do |child|
  next unless child.is_a?(Xcodeproj::Project::Object::PBXGroup)
  
  if child.display_name == "Views" && child.parent&.display_name == "Sources"
    views_group = child
  end
end

if views_group
  # Look for Community group
  community_group = views_group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.display_name == "Community" }
  
  if community_group.nil?
    community_group = views_group.new_group("Community", "Community")
    puts "Created Community group"
  end
  
  components_group = community_group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.display_name == "Components" }
  
  if components_group.nil?
    components_group = community_group.new_group("Components", "Components")
    puts "Created Components group"
  end
else
  puts "Views group not found"
  exit 1
end

# Files to add
community_files = [
  { name: "CommunityView.swift", group: community_group },
  { name: "CommunityMapView.swift", group: community_group },
  { name: "CreateCommunityItemSheet.swift", group: community_group },
]

component_files = [
  { name: "CommunityCardView.swift", group: components_group },
  { name: "CommunityDockView.swift", group: components_group },
]

all_files = community_files + component_files

all_files.each do |file_info|
  file_name = file_info[:name]
  group = file_info[:group]
  
  # Check if already in project
  existing = group.files.find { |f| f.display_name == file_name }
  if existing.nil?
    file_ref = group.new_reference(file_name)
    target.source_build_phase.add_file_reference(file_ref)
    puts "Added #{file_name}"
  else
    puts "#{file_name} already exists"
  end
end

project.save
puts "Project saved"
