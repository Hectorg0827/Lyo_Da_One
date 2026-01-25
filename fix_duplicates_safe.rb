require 'xcodeproj'
project_path = '/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Lyo' }

# 1. Deduplicate Sources build phase
sources_phase = target.source_build_phase
seen_paths = {}
to_remove = []

sources_phase.files.each do |build_file|
  next unless build_file.file_ref
  path = build_file.file_ref.full_path.to_s rescue build_file.file_ref.path
  if seen_paths[path]
    to_remove << build_file
  else
    seen_paths[path] = true
  end
end

if to_remove.any?
  puts "Removing #{to_remove.count} duplicate build files from sources phase..."
  to_remove.each { |f| sources_phase.remove_build_file(f) }
end

# 2. Specifically check for ClipModels.swift duplicates in groups
models_group = project.main_group.find_subpath('Sources/Models', false)
if models_group
  clip_files = models_group.files.select { |f| f.path == 'ClipModels.swift' }
  if clip_files.count > 1
    puts "Found #{clip_files.count} file references for ClipModels.swift in Sources/Models. Cleaning up..."
    clip_files[1..-1].each { |f| f.remove_from_project }
  end
end

project.save
puts "Project saved successfully"
