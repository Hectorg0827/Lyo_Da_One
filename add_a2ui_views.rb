require "xcodeproj"

project_path = "Lyo.xcodeproj"
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Find any group with Swift files - use first one found
sources_group = nil
project.main_group.recursive_children.each do |child|
  if child.is_a?(Xcodeproj::Project::Object::PBXGroup)
    has_swift = child.files.any? { |f| f.path && f.path.end_with?(".swift") }
    if has_swift
      sources_group = child
      break
    end
  end
end

if sources_group.nil?
  sources_group = project.main_group
  puts "Using main_group as fallback"
else
  puts "Found group: #{sources_group.name || 'unnamed'}"
end

# Add A2UIContentViews.swift
file_path = "Sources/Views/Chat/A2UIContentViews.swift"
if File.exist?(file_path)
  file_ref = sources_group.new_file(file_path)
  target.source_build_phase.add_file_reference(file_ref)
  puts "Added A2UIContentViews.swift"
else
  puts "File not found: #{file_path}"
  exit 1
end

project.save
puts "Project saved successfully"
