
#!/usr/bin/env ruby
require 'xcodeproj'

project_path = File.join(Dir.pwd, 'Lyo.xcodeproj')
project = Xcodeproj::Project.open(project_path)

files_removed = 0

# Helper to inspect groups recursively
def clean_group(group)
  # Duplicate the list to avoid modification during iteration issues
  files = group.files.dup
  
  files.each do |file_ref|
    # Resolve the real path
    begin
      real_path = file_ref.real_path
      unless File.exist?(real_path)
        puts "Removing missing file reference: #{file_ref.path}"
        file_ref.remove_from_project
        files_removed += 1
      end
    rescue => e
      # Sometimes real_path fails if the path is malformed
      puts "Warning: Could not check path for #{file_ref.path}: #{e}"
    end
  end

  # Recurse into subgroups
  group.groups.each do |subgroup|
    clean_group(subgroup)
  end
end

puts "Checking for missing files in project..."
project.files.each do |file_ref|
    begin
        real_path = file_ref.real_path
        unless File.exist?(real_path)
          puts "Removing missing file reference: #{file_ref.path}"
          file_ref.remove_from_project
          files_removed += 1
        end
    rescue => e
        # Ignore errors for special file types that might not map to disk directly
    end
end

if files_removed > 0
  project.save
  puts "\n✅ Removed #{files_removed} missing file references."
else
  puts "\n✅ No missing files found."
end
