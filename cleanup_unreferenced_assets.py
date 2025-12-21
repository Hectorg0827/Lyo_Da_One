import json
import os

def remove_unreferenced_files(path):
    contents_path = os.path.join(path, 'Contents.json')
    if not os.path.exists(contents_path):
        print(f"No Contents.json found at {path}")
        return

    with open(contents_path, 'r') as f:
        data = json.load(f)

    referenced_files = set()
    for img in data.get('images', []):
        if 'filename' in img:
            referenced_files.add(img['filename'])
    
    referenced_files.add('Contents.json')

    # List all files in directory
    for filename in os.listdir(path):
        if filename not in referenced_files and filename != '.DS_Store':
            file_path = os.path.join(path, filename)
            if os.path.isfile(file_path):
                print(f"Removing unreferenced file: {file_path}")
                os.remove(file_path)

base_path = "/Users/hectorgarcia/LYO_Da_ONE/Sources/Resources/Assets.xcassets"
remove_unreferenced_files(os.path.join(base_path, "AppIcon.appiconset"))
remove_unreferenced_files(os.path.join(base_path, "avatar_reading.imageset"))
