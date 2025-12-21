#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/hectorgarcia/LYO Da ONE /Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

puts "Removing test files from main target..."

test_files = [
  'LyoAITests.swift',
  'RepositoryTests.swift'
]

target.source_build_phase.files.each do |build_file|
  file_ref = build_file.file_ref
  next unless file_ref
  
  if test_files.include?(file_ref.name) || (file_ref.path && test_files.any? { |tf| file_ref.path.end_with?(tf) })
    puts "Removing #{file_ref.name} from main target build phase"
    target.source_build_phase.remove_build_file(build_file)
  end
end

project.save
puts "✅ Test files removed from main target!"
