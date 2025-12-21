#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "Project Analysis:"
project.targets.each do |t|
  puts "Target: #{t.name}"
  puts "  Product Type: #{t.product_type}"
  
  t.build_configurations.each do |config|
    puts "  Configuration: #{config.name}"
    settings = config.build_settings
    puts "    IPHONEOS_DEPLOYMENT_TARGET: #{settings['IPHONEOS_DEPLOYMENT_TARGET']}"
    puts "    CODE_SIGN_IDENTITY: #{settings['CODE_SIGN_IDENTITY']}"
    puts "    DEVELOPMENT_TEAM: #{settings['DEVELOPMENT_TEAM']}"
    puts "    PROVISIONING_PROFILE_SPECIFIER: #{settings['PROVISIONING_PROFILE_SPECIFIER']}"
    puts "    SKIP_INSTALL: #{settings['SKIP_INSTALL']}"
  end
end
