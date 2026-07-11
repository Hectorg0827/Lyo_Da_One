require 'xcodeproj'

project_path = '/Users/hectorgarcia/LYO_Da_ONE/LYO_Da_ONE.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target_name = 'LYO_Da_ONE'
target = project.targets.find { |t| t.name == target_name }

def remove_reference_if_exists(group, path)
  ref = group[path]
  if ref
    ref.remove_from_project
    puts "Removed reference to #{path}"
  end
end

puts "Finding new files to add..."
new_files = [
  '/Users/hectorgarcia/LYO_Da_ONE/Sources/Models/LessonBlock.swift',
  '/Users/hectorgarcia/LYO_Da_ONE/Sources/Services/SmartBlockParser.swift'
]

new_files.each do |file_path|
  file_ref = project.main_group.find_file_by_path(file_path)
  if file_ref
    puts "#{file_path} is already in the project."
  else
    file_ref = project.main_group.new_reference(file_path)
    target.add_file_references([file_ref])
    puts "Added #{file_path} to the target."
  end
end

puts "Removing archived files from the target..."
# Remove any references that contain 'A2UI_Archive' from the build phases
target.source_build_phase.files.each do |build_file|
  if build_file.file_ref && build_file.file_ref.real_path.to_s.include?('A2UI_Archive')
    target.source_build_phase.remove_build_file(build_file)
    puts "Removed archived file from build phase: #{build_file.file_ref.real_path}"
  end
end

project.save
puts "Project updated successfully."
