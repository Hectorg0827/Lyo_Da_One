#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "Targets in project:"
project.targets.each do |t|
  puts "- #{t.name} (Type: #{t.product_type})"
  
  # Check resources phase
  resources_phase = t.resources_build_phase
  if resources_phase
    has_plist = resources_phase.files.any? { |f| f.file_ref && f.file_ref.path == 'GoogleService-Info.plist' }
    puts "  Has GoogleService-Info.plist: #{has_plist}"
  else
    puts "  No resources phase"
  end
end
