#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Lyo' }
raise "Target 'Lyo' not found" unless target

# Find the A2UI Views group
sources = project.main_group.find_subpath('Sources')
core = sources.find_subpath('Core')
a2ui_group = core.find_subpath('A2UI')
views_group = a2ui_group.find_subpath('Views')

# New files to add
new_files = [
  'A2UIQuizRenderers.swift',
  'A2UILayoutRenderers.swift'
]

new_files.each do |filename|
  file_path = "Sources/Core/A2UI/Views/#{filename}"
  next unless File.exist?(file_path)

  # Check if already exists
  next if views_group.files.any? { |f| f.path && f.path.include?(filename) }

  file_ref = views_group.new_reference(file_path)
  target.source_build_phase.add_file_reference(file_ref)
  puts "✅ Added: #{file_path}"
end

project.save
puts "✅ Done adding new A2UI files"
