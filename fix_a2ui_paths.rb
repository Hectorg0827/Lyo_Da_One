#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Lyo' }

# Find and remove old broken references (those with doubled paths)
broken_refs = target.source_build_phase.files_references.select { |f| 
  f.path && f.path.include?('Sources/Core/A2UI') 
}
puts "Found #{broken_refs.count} A2UI references to remove"

broken_refs.each do |ref|
  puts "  Removing: #{ref.path}"
  # Remove from build phase
  target.source_build_phase.files.select { |bf| bf.file_ref == ref }.each(&:remove_from_project)
end

# Remove file references from groups
project.groups.flatten.each do |group|
  group.files.select { |f| f.path && f.path.include?('A2UI') }.each do |file|
    puts "  Removing group file: #{file.path}"
    file.remove_from_project
  end
end

# Find A2UI groups and remove them
def find_and_remove_a2ui_groups(group)
  to_remove = []
 #!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
p    to_remove << g
   
project_path = 'Lnd_project = Xcodeproj::Project.
 
target = project.targets.find { |t| t.name ==rou
# Find and remove old broken references (those withmaibroken_refs = target.source_build_phase.files_references.select {ct  f.path && f.path.include?('Sources/Core/As"
