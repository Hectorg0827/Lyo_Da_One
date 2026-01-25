#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get or create A2UI group
sources = project.main_group.find_subpath('Sources', true) || project.main_group.new_group('Sources')
core = sources.find_subpath('Core', true) || sources.new_group('Core')
a2ui = core.find_subpath('A2UI', true) || core.new_group('A2UI')
views = a2ui.find_subpath('Views', true) || a2ui.new_group('Views')

target = project.targets.find { |t| t.name == 'Lyo' }
raise "Target 'Lyo' not found" unless target

# Files to add
a2ui_root_files = [
  'Sources/Core/A2UI/A2UIElementType.swift',
  'Sources/Core/A2UI/A2UIProps.swift',
  'Sources/Core/A2UI/A2UIComponent.swift',
  'Sources/Core/A2UI/A2UIRenderer.swift'
]

a2ui_view_files = [
  'Sources/Core/A2UI/Views/A2UIRendererViews.swift',
  'Sources/Core/A2UI/Views/A2UIQuizViews.swift',
  'Sources/Core/A2UI/Views/A2UIStudyPlanViews.swift',
  'Sources/Core/A2UI/Views/A2UIMistakeViews.swift',
  'Sources/Core/A2UI/Views/A2UIHomeworkViews.swift',
  'Sources/Core/A2UI/Views/A2UILayoutViews.swift',
  'Sources/Core/A2UI/Views/A2UIMiscViews.swift'
]

def add_file(group, file_path, target)
  return if group.files.any? { |f| f.path && f.path.include?(File.basename(file_path)) }
  
  file_ref = group.new_file(file_path)
  target.source_build_phase.add_file_reference(file_ref) unless target.source_build_phase.files_references.include?(file_ref)
  puts "✅ Added: #{file_path}"
end

a2ui_root_files.each { |f| add_file(a2ui, f, target) }
a2ui_view_files.each { |f| add_file(views, f, target) }

project.save
puts "🎉 Done! A2UI files added to Xcode project."
