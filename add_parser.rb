require 'xcodeproj'
project_path = '/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Lyo' }

# Find or create group
sources = project.main_group['Sources'] || project.main_group.new_group('Sources')
utils = sources['Utils'] || sources.new_group('Utils')

file_path = 'A2UIParser.swift' # Path relative to group
file_ref = utils.files.find { |f| f.path == file_path } || utils.new_file(file_path)

# Add to build phase if not already there
unless target.source_build_phase.files.any? { |f| f.file_ref == file_ref }
  target.add_file_references([file_ref])
  puts "Added A2UIParser.swift to target Lyo"
else
  puts "A2UIParser.swift already in target Lyo"
end

project.save
puts "Project saved"
