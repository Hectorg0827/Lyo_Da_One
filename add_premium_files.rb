#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.find { |t| t.name == 'Lyo' }
raise "Could not find Lyo target" unless target

# Find or create the Premium group under Components
sources_group = project.main_group.find_subpath('Sources', true)
components_group = sources_group.find_subpath('Components', true) || sources_group.new_group('Components')
premium_group = components_group.find_subpath('Premium', true) || components_group.new_group('Premium')

# Files to add
files_to_add = [
  'Sources/Components/Premium/GlassCard.swift',
  'Sources/Components/Premium/AnimatedGradient.swift',
  'Sources/Components/Premium/AnimatedLioOrb.swift',
  'Sources/Components/Premium/PremiumButton.swift',
  'Sources/Components/Premium/ShimmerEffect.swift'
]

files_to_add.each do |file_path|
  file_name = File.basename(file_path)
  
  # Check if file already exists in project
  existing = premium_group.files.find { |f| f.path == file_name }
  if existing
    puts "File already in project: #{file_name}"
    next
  end
  
  # Add file reference
  file_ref = premium_group.new_file(File.join('..', '..', file_path))
  
  # Add to target's sources build phase
  target.source_build_phase.add_file_reference(file_ref)
  
  puts "Added: #{file_name}"
end

project.save
puts "Done! Project saved."
