
#!/usr/bin/env ruby
require 'xcodeproj'

project_path = File.join(Dir.pwd, 'Lyo.xcodeproj')
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Lyo' }
abort("Target 'Lyo' not found") unless target

compile_phase = target.source_build_phase
resources_phase = target.resources_build_phase

# Helper to deduplicate a phase
def deduplicate_phase(phase, phase_name)
  puts "Checking #{phase_name}..."
  seen = {}
  to_remove = []

  phase.files.each do |build_file|
    ref = build_file.file_ref
    next unless ref
    
    # Use full path as identity
    # Often duplicates happen because the same file is added twice
    # We want to keep the FIRST one.
    
    # Note: ref.path might be relative. We should check if they point to the same physical file.
    # But for PBXProj, even just matching the name/path in the proj definition is usually enough for duplicate build file warnings.
    
    # We will use the file name as a heuristic for aggressive dedupe 
    # (assuming we don't have different files with same name in different folders which is bad practice anyway in Swift usually, but possible).
    # Let's use the file reference UUID or just the path.
    
    key = ref.path || ref.name
    
    if seen[key]
      puts "  Duplicate found: #{key}"
      to_remove << build_file
    else
      seen[key] = true
    end
  end

  if to_remove.any?
    to_remove.each { |f| phase.remove_build_file(f) }
    puts "  Removed #{to_remove.count} duplicates from #{phase_name}."
    return true
  else
    puts "  No duplicates in #{phase_name}."
    return false
  end
end

changed_sources = deduplicate_phase(compile_phase, "Compile Sources")
changed_resources = deduplicate_phase(resources_phase, "Copy Bundle Resources")

if changed_sources || changed_resources
  project.save
  puts "✅ Project saved with aggressive deduplication."
else
  puts "✅ Project clean."
end
