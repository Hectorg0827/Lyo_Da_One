#!/usr/bin/env ruby
require 'json'

assets_path = 'Sources/Resources/Assets.xcassets'

# Fix AppIcon
app_icon_path = File.join(assets_path, 'AppIcon.appiconset')
contents_json_path = File.join(app_icon_path, 'Contents.json')

if File.exist?(contents_json_path)
  json = JSON.parse(File.read(contents_json_path))
  
  # Remove unassigned images
  json['images'].reject! { |img| img['filename'] == '20x20 1.png' }
  
  File.write(contents_json_path, JSON.pretty_generate(json))
  puts "Fixed AppIcon.appiconset"
end

# Fix avatar_reading
avatar_path = File.join(assets_path, 'avatar_reading.imageset')
contents_json_path = File.join(avatar_path, 'Contents.json')

if File.exist?(contents_json_path)
  json = JSON.parse(File.read(contents_json_path))
  
  # Remove unassigned images
  json['images'].reject! { |img| img['filename'] == 'REading Avatar 1.png' }
  
  File.write(contents_json_path, JSON.pretty_generate(json))
  puts "Fixed avatar_reading.imageset"
end
