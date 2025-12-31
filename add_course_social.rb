require "xcodeproj"

project_path = "Lyo.xcodeproj"
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == "Lyo" }

file_path = "Sources/Core/Services/CourseSocialService.swift"
file_ref = project.new_file(file_path)

target.source_build_phase.add_file_reference(file_ref)

project.save
puts "✅ Added CourseSocialService.swift to project"
