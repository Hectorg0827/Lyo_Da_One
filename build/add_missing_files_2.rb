#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Lyo' }
unless target
  puts "ERROR: Could not find 'Lyo' target"
  exit 1
end

missing_files = [
  "Sources/Services/CalendarService.swift",
  "Sources/Services/ContentStorageService.swift",
  "Sources/Services/EnhancedCameraManager.swift",
  "Sources/Services/GamificationService.swift",
  "Sources/Core/Utilities/Log.swift"
]

def find_or_create_group(project, path_components)
  group = project.main_group
  path_components.each do |component|
    child = group.children.find { |c| c.respond_to?(:path) && c.path == component }
    if child
      group = child
    else
      group = group.new_group(component, component)
      puts "  Created group: #{component}"
    end
  end
  group
end

added = 0
skipped = 0

missing_files.each do |file_path|
  unless File.exist?(file_path)
    puts "SKIP (not on disk): #{file_path}"
    skipped += 1
    next
  end

  filename = File.basename(file_path)
  
  existing = project.files.find { |f| f.real_path.to_s.end_with?(file_path) rescue false }
  if existing
    puts "SKIP (already in project): #{file_path}"
    skipped += 1
    next
  end

  dir_parts = File.dirname(file_path).split('/')
  group = find_or_create_group(project, dir_parts)

  file_ref = group.new_file(filename)
  target.source_build_phase.add_file_reference(file_ref)
  
  puts "ADDED: #{file_path}"
  added += 1
end

project.save
puts "\nDone! Added #{added} files, skipped #{skipped}."
