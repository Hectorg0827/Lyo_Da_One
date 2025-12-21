require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Lyo' }
if target.nil?
  puts "Error: Target 'Lyo' not found"
  exit 1
end

compile_sources_phase = target.source_build_phase
files = compile_sources_phase.files

seen_files = Set.new
files_to_remove = []

files.each do |build_file|
  file_ref = build_file.file_ref
  if file_ref.nil?
    puts "Warning: Build file #{build_file} has no file reference"
    next
  end

  file_path = file_ref.path
  
  if seen_files.include?(file_path)
    puts "Duplicate found: #{file_path}"
    files_to_remove << build_file
  else
    seen_files.add(file_path)
  end
end

if files_to_remove.empty?
  puts "No duplicate build files found."
else
  puts "Removing #{files_to_remove.count} duplicate build files..."
  files_to_remove.each do |file|
    compile_sources_phase.remove_build_file(file)
  end
  project.save
  puts "Project saved."
end

# Deduplicate Resources Phase (Fixes GoogleService-Info.plist)
puts "\nChecking Resources Phase..."
resources_phase = target.resources_build_phase
resources_seen = Set.new
resources_to_remove = []

resources_phase.files.each do |build_file|
  next unless build_file.file_ref
  
  # Identify by name or path to catch duplicates
  id = build_file.file_ref.name || build_file.file_ref.path
  
  if resources_seen.include?(id)
    puts "Duplicate resource found: #{id}"
    resources_to_remove << build_file
  else
    resources_seen.add(id)
  end
end

if resources_to_remove.empty?
  puts "No duplicate resources found."
else
  puts "Removing #{resources_to_remove.count} duplicate resources..."
  resources_to_remove.each do |file|
    resources_phase.remove_build_file(file)
  end
  project.save
  puts "Project saved (Resources cleaned)."
end
