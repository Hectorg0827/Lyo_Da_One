#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/hectorgarcia/LYO Da ONE /Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

puts "Deep cleaning Utils..."

# Iterate through all build files in the Sources build phase
target.source_build_phase.files.each do |build_file|
  file_ref = build_file.file_ref
  next unless file_ref

  # Check if the file reference points to 'Utils'
  if file_ref.path == 'Utils' || file_ref.name == 'Utils'
    puts "Checking build file: #{file_ref.path} (#{file_ref.isa})"
    
    if file_ref.isa == 'PBXGroup'
       puts "Removing GROUP from build phase: #{file_ref.path}"
       target.source_build_phase.remove_build_file(build_file)
    elsif file_ref.isa == 'PBXFileReference'
       # Check if it is actually a directory on disk
       begin
         full_path = file_ref.real_path
         if File.directory?(full_path)
           puts "Removing folder reference from build phase: #{full_path}"
           target.source_build_phase.remove_build_file(build_file)
           file_ref.remove_from_project
         end
       rescue => e
         puts "Error checking path: #{e.message}"
       end
    end
  end
end

project.save
puts "✅ Deep clean finished!"
