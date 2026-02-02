import re
import os

PROJECT_PATH = "Lyo.xcodeproj/project.pbxproj"
BACKUP_PATH = "Lyo.xcodeproj/project.pbxproj.backup"
TEAM_ID = "5QZDMJGN7B"

# Expected Target IDs (from previous finding)
TARGET_LYO = "4BB5C257A9D8AD9C970FB775"
TARGET_TESTS = "8CC9FA11D78C39F34BE56D1D"

def fix_project():
    if not os.path.exists(PROJECT_PATH):
        print(f"Error: {PROJECT_PATH} not found")
        return

    # Backup
    with open(PROJECT_PATH, 'r') as f:
        content = f.read()
    with open(BACKUP_PATH, 'w') as f:
        f.write(content)
    
    print("Backed up project file.")

    # Find PBXProject section
    project_section_match = re.search(r'/\* Begin PBXProject section \*/(.*?)/* End PBXProject section \*/', content, re.DOTALL)
    if not project_section_match:
        print("Error: PBXProject section not found")
        return

    section_content = project_section_match.group(1)
    
    # Locate attributes block
    # We look for "attributes = {" inside the project object
    # Pattern: attributes = { ... };
    
    attributes_match = re.search(r'attributes = \{([^}]*)\};', section_content)
    
    if not attributes_match:
        print("Error: Attributes block not found")
        return
        
    attributes_block = attributes_match.group(1)
    
    # Check if TargetAttributes exists
    if "TargetAttributes" in attributes_block:
        print("TargetAttributes already exists. Checking content...")
        # Inspecting manual for now, complex to parse nested braces with regex. 
        # But if it exists, maybe we just leave it unless it's wrong?
        # Actually, let's assume if it exists, we might need to PATCH it.
        # But simpler: replace the whole TargetAttributes block if possible? 
        # Or just append if missing.
        pass
    else:
        print("TargetAttributes missing. Injecting...")
        
        new_attributes = f"""
                                TargetAttributes = {{
                                        {TARGET_LYO} = {{
                                                CreatedOnToolsVersion = 14.0;
                                                DevelopmentTeam = {TEAM_ID};
                                                ProvisioningStyle = Automatic;
                                        }};
                                        {TARGET_TESTS} = {{
                                                CreatedOnToolsVersion = 14.0;
                                                DevelopmentTeam = {TEAM_ID};
                                                ProvisioningStyle = Automatic;
                                        }};
                                }};"""
        
        # Insert before the closing brace of attributes
        # We replace the attributes block content
        
        # Construct new Attributes Block
        # Append to existing attributes
        updated_attributes_block = attributes_block + new_attributes
        
        # Replace in section
        new_section_content = section_content.replace(attributes_block, updated_attributes_block)
        
        # Replace in full content
        new_content = content.replace(section_content, new_section_content)
        
        with open(PROJECT_PATH, 'w') as f:
            f.write(new_content)
            
        print("✅ Successfully injected TargetAttributes for Automatic Signing!")

if __name__ == "__main__":
    fix_project()
