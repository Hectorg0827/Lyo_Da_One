#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Lyo' }
puts "Target: #{target.name}"

# Step 1: Remove ALL existing A2UI references (broken ones)
puts "\n--- Cleaning broken references ---"

# Remove from build phases
files_to_remove = []
target.source_build_phase.files.each do |build_file|
  next unless build_file.file_ref
  path = build_file.file_ref.real_path.to_s rescue nil
  if path && path.include?('A2UI')
    files_to_remove << build_file
    puts "  Will remove build file: #{path}"
  end
end
files_to_remove.each(&:remove_from_project)
puts "Removed #{files_to_remove.count} build files"

# Step 2: Clean up any A2UI groups
def remove_a2ui_groups(group, depth = 0)
  return unless group.respond_to?(:groups)
  
  groups_to_remove = []
  group.groups.each do |g|
    if g.name == 'A2UI'
      groups_to_remove << g
      puts "  Found A2UI group to remove at depth #{depth}"
    else
      remove_a2ui_groups(g, depth + 1)
    end
  end
  groups_to_remove.each(&:remove_from_project)
end

project.main_group.groups.each { |g| remove_a2ui_groups(g) }

project.save
puts "\n--- Phase 1 complete: Cleaned up ---"

# Step 3: Now add files correctly
puts "\n--- Adding A2UI files correctly ---"

# Find Sources group
sources_group = project.main_group.groups.find { |g| g.name == 'Sources' }
unless sources_group
  puts "ERROR: No Sources group found!"
  exit 1
end
puts "Found Sources group"

# Find Core group
core_group = sources_group.groups.find { |g| g.name == 'Core' }
unless core_group
  puts "ERROR: No Core group found!"
  exit 1
end
puts "Found Core group"

# Create A2UI group
a2ui_group = core_group.new_group('A2UI', 'A2UI')
puts "Created A2UI group"

# Create Views subgroup
views_group = a2ui_group.new_group('Views', 'Views')
puts "Created Views subgroup"

# Base path for files
base_path = File.expand_path('Sources/Core/A2UI', File.dirname(project_path))

# Core A2UI files
core_files = [
  'A2UIElementType.swift',
  'A2UIComponent.swift',
  'A2UIProps.swift',
  'A2UIRenderer.swift'
]

# View files
view_files = [
  'A2UIRendererViews.swift',
  'A2UIQuizViews.swift',
  'A2UIStudyPlanViews.swift',
  'A2UIMistakeViews.swift',
  'A2UIHomeworkViews.swift',
  'A2UILayoutViews.swift',
  'A2UIMiscViews.swift'
]

# Add core files
core_files.each do |filename|
  file_path = File.join(base_path, filename)
  if File.exist?(file_path)
    file_ref = a2ui_group.new_file(file_path)
    target.source_build_phase.add_file_reference(file_ref)
    puts "  Added: #{filename}"
  else
    puts "  WARNING: Missing #{file_path}"
  end
end

# Add view files
views_path = File.join(base_path, 'Views')
view_files.each do |filename|
  file_path = File.join(views_path, filename)
  if File.exist?(file_path)
    file_ref = views_group.new_file(file_path)
    target.source_build_phase.add_file_reference(file_ref)
    puts "  Added: Views/#{filename}"
  else
    puts "  WARNING: Missing #{file_path}"
  end
end

project.save
puts "\n🎉 Done! A2UI files properly added to Xcode project."
