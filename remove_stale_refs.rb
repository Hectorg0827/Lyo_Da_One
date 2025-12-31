#!/usr/bin/env ruby
# encoding: UTF-8
require 'fileutils'

project_file = '/Users/hectorgarcia/LYO_Da_ONE/Lyo.xcodeproj/project.pbxproj'

# Create backup
backup_path = "#{project_file}.backup_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
FileUtils.cp(project_file, backup_path)
puts "Created backup: #{backup_path}"

content = File.read(project_file, encoding: 'UTF-8')
original_size = content.length

# All stale file reference IDs to remove (from root-level paths)
stale_ids = %w[
  5072328A04C620F7E85CA07F
  AC511E206CE6BC76BAE1EADE
  AFCE4430BB6040AF31533C61
  DCE61F32A32DA120A31A6381
  0DA3DF9BA88DE65E82CC45DB
  7083C463CB880165A70D6626
  0AF87D127ED13977BA4D5D9E
  33832FDAA99B80AA76642070
  BB2DCE22F743DD0A8E680A96
  6745B24B297D44FCE9686076
  D179E7F3A152C6F43972E79F
  3773C4873A63BDF8DEA2722F
  F0AB5AC67748757944FFD28C
  40D19F543FE091E7D874DB29
  89A981C81186E1EDBDE1C235
  C748EEBD16A8CC0F24CB473E
  2867003D8F3B91E2CC5D0148
  FF9D03B4E7833F37BA7A4117
  448752348ABA6200849DDAF9
  2B9237D79C40F7D1A0BA5FE2
  F660E75765DF39F0AFE4CB38
  FB5E51091A7374AED915F37D
  6A7D94D2885CAB9768DC0D58
  E09994C205AE4575A85D1BE9
  3FF9B283C03897C14E696C8D
  5A4591D656604E631F42D285
  2BF6D9451EEA788672DB8D7A
  8983410096FBA6AFB9E2AFC4
  BF91DA74F74FB6560B4A35F3
  059E2FDA0D8255F29D49A1CA
  EEE52F566E6BA65E6CFD0FE0
  F7B0B0F6417620C1C0D74271
  2A4D89BEFCC1EAE5167A86BF
  5959A5110AEC59BEC94D8E6E
  0E9E5D53D0BC4FCB1C5252B7
  4146A8FFF79D99BC67BE9083
  AF3644210EF40C1E2C85BBF5
  D8E5D7E11CF17E721B42B881
  22C3E2493103E3F4088BEB92
  52031AAE8354B3F9D8DFBDCD
  AA01D30BA67AAB7312BA6468
  1402673D3A74F57124D303EE
]

# Additional stale IDs for files with relative paths like Views/Profile/xxx.swift
additional_stale_ids = %w[
  1C322DB1C46A466C8FA8EBD3
  40FBB2F129DCBD4CEE5A506E
  6093749A86AF324385D0BC3D
  660DF960996A466CB262B4D9
  C5C98B5B4523D1A9A5240C0C
  CF945245D5E74202BA7E6EE1
  CFA7034290FF470ABAACD838
  F2681D0146C1707EAB8B116C
]

all_stale_ids = stale_ids + additional_stale_ids
removed_count = 0

all_stale_ids.each do |ref_id|
  # Remove the PBXFileReference line
  if content.gsub!(/^\s*#{ref_id}\s*\/\*[^*]*\*\/\s*=\s*\{[^}]*\};\s*\n/, '')
    removed_count += 1
    puts "Removed file reference: #{ref_id}"
  end
  
  # Remove from children arrays (in PBXGroup sections)
  content.gsub!(/^\s*#{ref_id}\s*\/\*[^*]*\*\/,?\s*\n/, '')
end

# Now find and remove the associated PBXBuildFile entries that reference the stale file refs
build_files_removed = 0
all_stale_ids.each do |ref_id|
  # Pattern: ID /* name in Sources */ = {isa = PBXBuildFile; fileRef = STALE_ID; ...};
  build_pattern = /^\s*[A-F0-9]{24}\s*\/\*[^*]*in Sources[^*]*\*\/\s*=\s*\{[^}]*fileRef\s*=\s*#{ref_id}[^}]*\};\s*\n/
  
  if content.gsub!(build_pattern, '')
    build_files_removed += 1
    puts "Removed build file entry for: #{ref_id}"
  end
end

# Clean up dangling commas in arrays
content.gsub!(/,(\s*\);)/, '\1')

# Write updated content
File.write(project_file, content, encoding: 'UTF-8')

puts ""
puts "Removed #{removed_count} stale file references"
puts "Removed #{build_files_removed} build file entries"
puts "Project file size: #{original_size} -> #{content.length} bytes (#{original_size - content.length} bytes removed)"
puts "Backup saved: #{backup_path}"
