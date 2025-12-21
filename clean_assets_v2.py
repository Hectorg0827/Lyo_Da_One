import json
import os

def clean_assets(path):
    contents_path = os.path.join(path, 'Contents.json')
    if not os.path.exists(contents_path):
        print(f"No Contents.json found at {path}")
        return

    with open(contents_path, 'r') as f:
        data = json.load(f)

    images = data.get('images', [])
    new_images = []
    removed_count = 0

    for img in images:
        # Remove if explicitly unassigned
        if img.get('unassigned') is True:
            removed_count += 1
            continue
        
        # Remove if filename looks like a duplicate/conflict (heuristic based on error logs)
        # The error mentioned "20x20 1.png" and "REading Avatar 1.png"
        # But usually "unassigned": true is the source of truth for these warnings.
        
        new_images.append(img)

    if removed_count > 0:
        data['images'] = new_images
        with open(contents_path, 'w') as f:
            json.dump(data, f, indent=2)
        print(f"Cleaned {path}: Removed {removed_count} unassigned images.")
    else:
        print(f"No unassigned images found in {path}.")

base_path = "/Users/hectorgarcia/LYO_Da_ONE/Sources/Resources/Assets.xcassets"
clean_assets(os.path.join(base_path, "AppIcon.appiconset"))
clean_assets(os.path.join(base_path, "avatar_reading.imageset"))
