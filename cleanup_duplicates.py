import re

project_path = 'Lyo.xcodeproj/project.pbxproj'

with open(project_path, 'r') as f:
    content = f.read()

# IDs to remove
files_to_remove = [
    '9B5FFAF7AD7B9BB02FDFA0BA', # AdaptiveHomeView.swift (Duplicate)
    '24DF143EAF4E7F34753ABB6B', # UserContextService.swift (Duplicate)
]

build_files_to_remove = [
    '97C9AFE26AACA7DE3700FA68', # AdaptiveHomeView.swift in Sources (Duplicate)
    '7C03F2A9DA0A0A592DF0FFD5', # UserContextService.swift in Sources (Duplicate)
]

groups_to_remove = [
    '5DB74B244F9274E22CF8F25D', # Main group (Duplicate/Empty)
]

# Remove PBXBuildFile entries
for bf_id in build_files_to_remove:
    # Regex to remove the whole line containing the ID
    content = re.sub(r'\s+' + bf_id + r' .*?;\n', '\n', content)
    # Also remove from PBXSourcesBuildPhase
    content = re.sub(r'\s+' + bf_id + r' .*?,\n', '\n', content)

# Remove PBXFileReference entries
for f_id in files_to_remove:
    content = re.sub(r'\s+' + f_id + r' .*?;\n', '\n', content)
    # Also remove from PBXGroup children
    content = re.sub(r'\s+' + f_id + r' .*?,\n', '\n', content)

# Remove PBXGroup entries
for g_id in groups_to_remove:
    # Remove the group definition block
    # This is harder with regex, let's just remove the line in children list first
    content = re.sub(r'\s+' + g_id + r' .*?,\n', '\n', content)
    
    # Now remove the group definition itself. It looks like:
    # g_id /* Name */ = {
    #    isa = PBXGroup;
    #    ...
    # };
    pattern = r'\s+' + g_id + r' /\* .*? \*/ = \{[^}]*\};'
    content = re.sub(pattern, '', content, flags=re.DOTALL)

with open(project_path, 'w') as f:
    f.write(content)

print("Cleaned up duplicate references.")
