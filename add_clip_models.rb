require "xcodeproj"
project = Xcodeproj::Project.open("Lyo.xcodeproj")
app_target = project.targets.find { |t| t.name == "Lyo" }

models_group = project.main_group.find_subpath("Sources/Models", true)
if models_group.nil?
  models_group = project.main_group["Sources"].new_group("Models")
end

file_path = "Sources/Models/ClipModels.swift"
unless models_group.files.any? { |f| f.path == "ClipModels.swift" }
  file_ref = models_group.new_file(file_path)
  app_target.source_build_phase.add_file_reference(file_ref)
  puts "Added ClipModels.swift"
else
  puts "ClipModels.swift already exists"
end

project.save
puts "Project saved"
