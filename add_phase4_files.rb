#!/usr/bin/env ruby
require 'xcodeproj'

project_path = File.join(Dir.pwd, 'Lyo.xcodeproj')
project = Xcodeproj::Project.open(project_path)

target = project.targets.first
sources_group = project.main_group['Sources']

phase4_files = [
  'Sources/Models/LiveLessonModels.swift',
  'Sources/ViewModels/LiveClassroomViewModel.swift',
  'Sources/Views/Main/Classroom/LiveClassroomView.swift',
  'Sources/Views/Main/Classroom/TranscriptSheet.swift'
]

def find_or_create_group(project, sources_group, path)
  parts = path.split('/')
  parts.shift # Remove 'Sources'
  
  current_group = sources_group
  parts[0...-1].each do |part|
    child = current_group.children.find { |c| c.display_name == part }
    if child.nil?
      child = current_group.new_group(part)
    end
    current_group = child
  end
  current_group
end

phase4_files.each do |file_path|
  full_path = File.join(Dir.pwd, file_path)
  next unless File.exist?(full_path)
  
  # Check if already in project
  already_added = false
  target.source_build_phase.files.each do |build_file|
    if build_file.file_ref && build_file.file_ref.real_path.to_s == full_path
      already_added = true
      break
    end
  end
  
  if already_added
    puts "Already exists: #{file_path}"
    next
  end
  
  group = find_or_create_group(project, sources_group, file_path)
  file_ref = group.new_file(full_path)
  target.source_build_phase.add_file_reference(file_ref)
  puts "Added: #{file_path}"
end

project.save
puts "\n✅ Successfully added Phase 4 files to Xcode project!"
