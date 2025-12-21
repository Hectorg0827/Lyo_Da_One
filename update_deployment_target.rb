#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "Updating Deployment Target to 16.0..."
project.targets.each do |t|
  t.build_configurations.each do |config|
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
  end
end

project.save
puts "Project saved with new deployment target."
