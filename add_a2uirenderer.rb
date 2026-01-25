require "xcodeproj"

project_path = "Lyo.xcodeproj"
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Helper to find or create group
def find_or_create_group(parent, name)
  parent[name] || parent.new_group(name)
end

# Find the Sources group
sources_group = project.main_group["Sources"]
views_group = find_or_create_group(sources_group, "Views")
main_group = find_or_create_group(views_group, "Main")
hybrid_group = find_or_create_group(main_group, "Hybrid")
components_group = find_or_create_group(hybrid_group, "Components")

file_path = "Sources/Views/Main/Hybrid/Components/A2UIRenderer.swift"
filename = "A2UIRenderer.swift"

if File.exist?(file_path)
  # Check if already added
  existing_ref = components_group.files.find { |f| f.path == filename }
  
  if existing_ref
    puts "File already exists in project"
  else
    # Correctly add the file reference with the relative path from the group
    # If the group uses a path, we just need the filename.
    # But often groups don't have paths set or set to something else.
    # To be safe, we can add it to the group.
    
    file_ref = components_group.new_file(filename)
    target.source_build_phase.add_file_reference(file_ref)
    project.save
    puts "Added #{filename} to project"
  end
else
  puts "File not found at #{file_path}"
end
