#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Lyo' }
unless target
  puts "Error: Target 'Lyo' not found"
  exit 1
end

# Remove build files with bad paths (doubled paths)
compile_sources_phase = target.source_build_phase
files_to_remove = []

compile_sources_phase.files.each do |build_file|
  file_ref = build_file.file_ref
  next unless file_ref
  
  # Get the full resolved path
  full_path = file_ref.real_path.to_s rescue nil
  next unless full_path
  
  # Check for doubled paths like Sources/Core/Sources/Core
  if full_path.include?('Sources/Core/Sources/') ||
     full_path.include?('Sources/Services/Sources/') ||
     full_path.include?('Sources/Components/Sources/') ||
     full_path.include?('Sources/Views/Sources/') ||
     full_path.include?('AITutor/Sources/')
    puts "Bad path found: #{full_path}"
    files_to_remove << build_file
  end
end

# Also find bad file references in the project
bad_file_refs = []
project.files.each do |file_ref|
  path = file_ref.path.to_s
  full_path = file_ref.real_path.to_s rescue nil
  
  if full_path && (full_path.include?('Sources/Core/Sources/') ||
     full_path.include?('Sources/Services/Sources/') ||
     full_path.include?('Sources/Components/Sources/') ||
     full_path.include?('Sources/Views/Sources/') ||
     full_path.include?('AITutor/Sources/'))
    puts "Bad file ref: #{full_path}"
    bad_file_refs << file_ref
  end
end

if files_to_remove.empty? && bad_file_refs.empty?
  puts "No bad paths found."
else
  puts "\nRemoving #{files_to_remove.count} bad build files..."
  files_to_remove.each do |file|
    compile_sources_phase.remove_build_file(file)
  end
  
  puts "Removing #{bad_file_refs.count} bad file references..."
  bad_file_refs.each do |ref|
    ref.remove_from_project
  end
  
  project.save
  puts "Project saved."
end
