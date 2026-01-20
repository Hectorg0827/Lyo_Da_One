require "xcodeproj"

project = Xcodeproj::Project.open("Lyo.xcodeproj")
app_target = project.targets.find { |t| t.name == "Lyo" }

# Remove any bad file references from the build phase
to_remove = []
app_target.source_build_phase.files.each do |bf|
  if bf.file_ref && bf.file_ref.path
    path = bf.file_ref.path
    # Remove doubled paths or bad ClipModels refs
    if path.include?("Sources/Models/Sources/") || path == "Sources/Models/ClipModels.swift"
      puts "Will remove from build phase: #{path}"
      to_remove << bf
    end
  end
end
to_remove.each { |bf| bf.remove_from_project }

# Find Models group
models_group = project.main_group.find_subpath("Sources/Models", true)

# Remove bad file refs from group
models_group.files.to_a.each do |f|
  if f.path && f.path.include?("Sources/")
    puts "Removing from group: #{f.path}"
    f.remove_from_project
  end
end

# Create correct file reference
# The path should be just the filename since the group already has the correct location
file_ref = project.new_file("Sources/Models/ClipModels.swift")
app_target.source_build_phase.add_file_reference(file_ref)
puts "Added ClipModels.swift with correct path"

project.save
puts "Project saved successfully"
