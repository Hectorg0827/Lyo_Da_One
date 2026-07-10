#!/usr/bin/env ruby
# Add missing Swift files to the Xcode project using the xcodeproj gem.
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'Lyo' }
unless target
  puts "ERROR: Could not find 'Lyo' target"
  exit 1
end

# Missing files to add (path relative to project root)
missing_files = [
  "Sources/Core/A2UI/Views/A2UIHomeworkRenderers.swift",
  "Sources/Core/A2UI/Views/A2UIMiscRenderers.swift",
  "Sources/Core/A2UI/Views/A2UIMistakeRenderers.swift",
  "Sources/Core/A2UI/Views/A2UIStudyPlanRenderers.swift",
  "Sources/Core/ClientCapabilities.swift",
  "Sources/Core/LyoLogger.swift",
  "Sources/Views/Community/CommentsView.swift",
  "Sources/Views/Community/CommunityFeedView.swift",
  "Sources/ViewModels/CommunityFeedViewModel.swift",
  "Sources/Models/Community/CommunityPostModels.swift",
  "Sources/Services/CommunityService.swift",
  "Sources/Views/CourseRuntimeView.swift",
  "Sources/Services/DemoCourseLoader.swift",
  "Sources/Services/LessonBlockParser.swift",
  "Sources/Services/Lyo2ChatService.swift",
  "Sources/Models/Lyo2Models.swift",
  "Sources/Tests/LyoAdapterTests.swift",
  "Sources/Tests/LyoCinematicIntegrationTests.swift",
  "Sources/Models/LyoCourseProtocol.swift",
  "Sources/Services/LyoCourseRuntime.swift",
  "Sources/Models/LyoRuntimeModels.swift",
  "Sources/Views/Chat/NotesView.swift",
  "Sources/Components/Learning/PremiumQuizView.swift",
]

# Also remove references to files that don't exist on disk
files_to_remove = [
  "LioChatService.swift",
  "AdvancedA2UIRenderer.swift",
]

# Remove stale references
files_to_remove.each do |filename|
  project.files.select { |f| f.name == filename || f.path == filename }.each do |file_ref|
    puts "Removing stale reference: #{filename}"
    # Remove from build phases
    target.source_build_phase.files.select { |bf| bf.file_ref == file_ref }.each(&:remove_from_project)
    file_ref.remove_from_project
  end
end

# Helper: find or create group for a given path
def find_or_create_group(project, path_components)
  group = project.main_group
  path_components.each do |component|
    child = group.children.find { |c| c.respond_to?(:path) && c.path == component }
    if child
      group = child
    else
      group = group.new_group(component, component)
      puts "  Created group: #{component}"
    end
  end
  group
end

added = 0
skipped = 0

missing_files.each do |file_path|
  # Check if file exists on disk
  unless File.exist?(file_path)
    puts "SKIP (not on disk): #{file_path}"
    skipped += 1
    next
  end

  filename = File.basename(file_path)
  
  # Check if already in project
  existing = project.files.find { |f| f.real_path.to_s.end_with?(file_path) rescue false }
  if existing
    puts "SKIP (already in project): #{file_path}"
    skipped += 1
    next
  end

  # Find or create the parent group
  dir_parts = File.dirname(file_path).split('/')
  group = find_or_create_group(project, dir_parts)

  # Add file reference
  file_ref = group.new_file(filename)
  
  # Add to target's compile sources
  target.source_build_phase.add_file_reference(file_ref)
  
  puts "ADDED: #{file_path}"
  added += 1
end

# Save
project.save
puts "\nDone! Added #{added} files, skipped #{skipped}."
