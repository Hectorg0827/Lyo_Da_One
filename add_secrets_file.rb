#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.first
group = project.main_group['Sources']['Core']['Configuration']

file_path = 'Sources/Core/Configuration/Secrets.swift'

# Check if file exists in group
file_ref = group.files.find { |f| f.path == 'Secrets.swift' }

if file_ref
  puts "File already exists in project"
else
  file_ref = group.new_file('Secrets.swift')
  target.add_file_references([file_ref])
  puts "Added Secrets.swift to project"
end

project.save
