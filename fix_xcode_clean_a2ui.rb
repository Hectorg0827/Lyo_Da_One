#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🧹 Cleaning up broken A2UI references..."

target = project.targets.find { |t| t.name == 'Lyo' }
raise "Target 'Lyo' not found" unless target

# Remove all A2UI-related file references
def remove_a2ui_refs(group)
  to_remove = []
  group.files.each do |file|
    if file.path && (file.path.include?('A2UI') || file.path.include?('Sources/Core/Sources'))
      puts "  Removing file ref: #{file.path}"
      to_remove << file
    end
  end
  to_remove.each(&:remove_from_project)

  # Remove from build phase
  target.source_build_phase.files.select { |bf|
    bf.file_ref && bf.file_ref.path && (bf.file_ref.path.include?('A2UI') || bf.file_ref.path.include?('Sources/Core/Sources'))
  }.each do |build_file|
    puts "  Removing from build: #{build_file.file_ref.path}"
    build_file.remove_from_project
  end

  group.groups.each { |g| remove_a2ui_refs(g) }
end

# Remove A2UI groups
def remove_a2ui_groups(group)
  to_remove = []
  group.groups.each do |g|
    if g.name == 'A2UI'
      puts "  Removing group: #{g.name}"
      to_remove << g
    else
      remove_a2ui_groups(g)
    end
  end
  to_remove.each(&:remove_from_project)
end

remove_a2ui_refs(project.main_group)
remove_a2ui_groups(project.main_group)

puts "✅ Cleaned up broken references"

# Now add files properly
sources = project.main_group.find_subpath('Sources') || project.main_group.new_group('Sources')
core = sources.find_subpath('Core') || sources.new_group('Core')
a2ui_group = core.new_group('A2UI')

# A2UI root files
a2ui_files = [
  'A2UIElementType.swift',
  'A2UIProps.swift',
  'A2UIComponent.swift',
  'A2UICapabilityNegotiator.swift',
  'A2UIRenderer.swift'
]

# A2UI Views files
views_group = a2ui_group.new_group('Views')
view_files = [
  'A2UIRendererViews.swift',
  'A2UIQuizViews.swift',
  'A2UIStudyPlanViews.swift',
  'A2UIMistakeViews.swift',
  'A2UIHomeworkViews.swift',
  'A2UILayoutViews.swift',
  'A2UIMiscViews.swift'
]

# Add root files
a2ui_files.each do |filename|
  file_path = "Sources/Core/A2UI/#{filename}"
  next unless File.exist?(file_path)

  file_ref = a2ui_group.new_reference(file_path)
  target.source_build_phase.add_file_reference(file_ref)
  puts "✅ Added: #{file_path}"
end

# Add view files
view_files.each do |filename|
  file_path = "Sources/Core/A2UI/Views/#{filename}"
  next unless File.exist?(file_path)

  file_ref = views_group.new_reference(file_path)
  target.source_build_phase.add_file_reference(file_ref)
  puts "✅ Added: #{file_path}"
end

project.save
puts "🎉 Done! A2UI files properly added to Xcode project"