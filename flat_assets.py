import os
import shutil
import json
from PIL import Image

workspace_dir = "/Users/hectorgarcia/LYO_Da_ONE"
backup_dir = os.path.join(workspace_dir, "backup_assets")
xcassets_dir = os.path.join(workspace_dir, "Sources/Resources/Assets.xcassets")
resources_dir = os.path.join(workspace_dir, "Sources/Resources")

print("🚀 Starting flat asset bundler...")

if not os.path.exists(backup_dir):
    print(f"❌ Error: Backup directory {backup_dir} does not exist!")
    exit(1)

# Ensure resources directory exists
os.makedirs(resources_dir, exist_ok=True)

# 1. Clean xcassets of all imageset directories (keep colorsets and AppIcon)
print("🧼 Cleaning imageset directories from Assets.xcassets...")
for item in os.listdir(xcassets_dir):
    item_path = os.path.join(xcassets_dir, item)
    if os.path.isdir(item_path) and item.endswith(".imageset"):
        print(f"  🗑️ Removing from Assets.xcassets: {item}")
        shutil.rmtree(item_path)

# 2. Process all folders in backup_assets
for item in os.listdir(backup_dir):
    item_path = os.path.join(backup_dir, item)
    if not os.path.isdir(item_path):
        continue
    
    # Skip corrupt imageset
    if item == "lyo_reading_1.imageset":
        continue
        
    # If it is a colorset, copy it to Assets.xcassets
    if item.endswith(".colorset"):
        dest_colorset = os.path.join(xcassets_dir, item)
        if not os.path.exists(dest_colorset):
            print(f"🎨 Restoring colorset: {item}")
            shutil.copytree(item_path, dest_colorset)
        continue
        
    # If it is an appiconset, keep/restore it in xcassets
    if item.endswith(".appiconset"):
        dest_appicon = os.path.join(xcassets_dir, item)
        if not os.path.exists(dest_appicon):
            print(f"📱 Restoring AppIcon set: {item}")
            shutil.copytree(item_path, dest_appicon)
        continue
        
    # If it is an imageset, convert it to a flat resource PNG
    if item.endswith(".imageset"):
        imageset_name = item[:-len(".imageset")]
        print(f"🖼️ Processing imageset: {item} -> {imageset_name}.png")
        
        # Read Contents.json to find the declared image file
        contents_json = os.path.join(item_path, "Contents.json")
        img_filename = None
        if os.path.exists(contents_json):
            try:
                with open(contents_json, 'r') as f:
                    data = json.load(f)
                images = data.get('images', [])
                # Prefer 1x or 2x, fallback to any available filename
                for img in images:
                    filename = img.get('filename')
                    if filename:
                        img_filename = filename
                        break
            except Exception as e:
                print(f"  ⚠️ Warning parsing Contents.json for {item}: {e}")
                
        # Fallback to finding the largest PNG in the directory if not found in json
        if not img_filename:
            png_files = [f for f in os.listdir(item_path) if f.lower().endswith(".png")]
            if png_files:
                # Sort by size descending
                png_files.sort(key=lambda f: os.path.getsize(os.path.join(item_path, f)), reverse=True)
                img_filename = png_files[0]
                
        if not img_filename:
            print(f"  ⚠️ No image file found in {item}! Skipping.")
            continue
            
        src_image_path = os.path.join(item_path, img_filename)
        dest_image_path = os.path.join(resources_dir, f"{imageset_name}.png")
        
        # Optimize and compress the PNG using Pillow
        try:
            original_size = os.path.getsize(src_image_path)
            with Image.open(src_image_path) as img:
                # Resize to max 512px dimension for optimal app size
                max_dimension = 512
                w, h = img.size
                if w > max_dimension or h > max_dimension:
                    if w > h:
                        new_w = max_dimension
                        new_h = int(h * (max_dimension / w))
                    else:
                        new_h = max_dimension
                        new_w = int(w * (max_dimension / h))
                    img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
                
                img.save(dest_image_path, "PNG", optimize=True)
                new_size = os.path.getsize(dest_image_path)
                print(f"  ✓ Compressed and moved: {original_size/1024:.1f}KB -> {new_size/1024:.1f}KB")
        except Exception as e:
            print(f"  ⚠️ Failed to optimize {img_filename}: {e}. Copying original instead.")
            shutil.copy2(src_image_path, dest_image_path)

print("🎉 Flat asset bundling completed successfully!")
