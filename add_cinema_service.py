#!/usr/bin/env python3
"""
Add InteractiveCinemaService.swift to Xcode project
"""

import subprocess
import sys

# Path to the file that needs to be added
file_path = "Sources/Services/InteractiveCinemaService.swift"

# Try using xcode-select to add the file
print(f"Adding {file_path} to Xcode target...")

# Use pbxproj command-line tool if available, otherwise use Ruby script
ruby_script = """
require 'xcodeproj'

project_path = 'Lyo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Get or create the Services group
services_group = project.main_group.find_subpath('Sources/Services', true)

# Add the file
file_ref = services_group.new_reference('InteractiveCinemaService.swift')
file_ref.last_known_file_type = 'sourcecode.swift'
file_ref.path = 'InteractiveCinemaService.swift'

# Add to build phase
target.source_build_phase.add_file_reference(file_ref)

project.save
puts "✅ Added InteractiveCinemaService.swift to Xcode project"
"""

# Write Ruby script to temp file
with open('/tmp/add_cinema_service.rb', 'w') as f:
    f.write(ruby_script)

# Try to run Ruby script
try:
    # First check if xcodeproj gem is installed
    check_gem = subprocess.run(['gem', 'list', 'xcodeproj'], capture_output=True, text=True)
    
    if 'xcodeproj' not in check_gem.stdout:
        print("Installing xcodeproj gem...")
        subprocess.run(['gem', 'install', 'xcodeproj', '--user-install'], check=False)
    
    # Run the Ruby script
    result = subprocess.run(['ruby', '/tmp/add_cinema_service.rb'], 
                          capture_output=True, text=True, cwd='/Users/hectorgarcia/LYO_Da_ONE')
    
    if result.returncode == 0:
        print(result.stdout)
        print("✅ File added successfully!")
        sys.exit(0)
    else:
        print(f"⚠️ Ruby script failed: {result.stderr}")
        print("Trying manual approach...")
        
except Exception as e:
    print(f"⚠️ Ruby approach failed: {e}")
    print("Trying alternative...")

# Alternative: Just rebuild derived data
print("\nCleaning derived data and rebuilding...")
subprocess.run([
    'rm', '-rf', 
    '/Users/hectorgarcia/Library/Developer/Xcode/DerivedData/Lyo-*'
], shell=True, check=False)

print("\n✅ Cleaned build cache. Please:")
print("1. Open Xcode")
print("2. Right-click on 'Sources/Services' folder")
print("3. Click 'Add Files to Lyo...'")
print("4. Select 'InteractiveCinemaService.swift'")
print("5. Make sure 'Add to targets: Lyo' is checked")
print("6. Click 'Add'")
