#!/usr/bin/env ruby
# Remove test files from main target's compile sources.
require 'xcodeproj'

project = Xcodeproj::Project.open('Lyo.xcodeproj')
target = project.targets.find { |t| t.name == 'Lyo' }

files_to_remove = ['LyoAdapterTests.swift', 'LyoCinematicIntegrationTests.swift']

target.source_build_phase.files.each do |build_file|
  if build_file.file_ref && files_to_remove.include?(build_file.file_ref.path)
    puts "Removing from compile sources: #{build_file.file_ref.path}"
    build_file.remove_from_project
  end
end

project.save
puts "Done!"
