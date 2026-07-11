import os
import shutil
import json
from PIL import Image

workspace_dir = "/Users/hectorgarcia/LYO_Da_ONE"
backup_dir = os.path.join(workspace_dir, "backup_assets")
target_dir = os.path.join(workspace_dir, "Sources/Resources/Assets.xcassets")

print("🚀 Starting asset compression and restoration...")

if not os.path.exists(backup_dir):
    print(f"❌ Error: Backup directory {backup_dir} does not exist!")
    exit(1)

# Ensure target directory exists
os.makedirs(target_dir, exist_ok=True)

# Walk backup directory
for item in os.listdir(backup_dir):
    item_path = os.path.join(backup_dir, item)
    if not os.path.isdir(item_path):
        continue
    
    # 1. Permanently exclude lyo_reading_1.imageset which lacks Contents.json
    if item == "lyo_reading_1.imageset":
        print(f"🗑️ Skipping and permanently excluding corrupt empty imageset: {item}")
        continue
    
    print(f"📦 Processing imageset: {item}")
    
    # Create target imageset directory
    dest_item_path = os.path.join(target_dir, item)
    os.makedirs(dest_item_path, exist_ok=True)
    
    # Copy files and compress PNGs
    for subitem in os.listdir(item_path):
        subitem_path = os.path.join(item_path, subitem)
        dest_subitem_path = os.path.join(dest_item_path, subitem)
        
        if subitem.lower().endswith(".png"):
            # Check file size
            original_size = os.path.getsize(subitem_path)
            if original_size > 100 * 1024:  # > 100KB
                try:
                    with Image.open(subitem_path) as img:
                        # Resize if dimensions are extremely large
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
                            print(f"  ⚡ Resized {subitem} from {w}x{h} to {new_w}x{new_h}")
                        
                        # Save compressed
                        img.save(dest_subitem_path, "PNG", optimize=True)
                        new_size = os.path.getsize(dest_subitem_path)
                        reduction = (original_size - new_size) / original_size * 100
                        print(f"  ✓ Compressed {subitem}: {original_size/1024:.1f}KB -> {new_size/1024:.1f}KB ({reduction:.1f}% reduction)")
                except Exception as e:
                    print(f"  ⚠️ Warning: Failed to compress {subitem} using Pillow: {e}. Copying original instead.")
                    shutil.copy2(subitem_path, dest_subitem_path)
            else:
                shutil.copy2(subitem_path, dest_subitem_path)
        else:
            # Just copy json and other files
            if os.path.isfile(subitem_path):
                shutil.copy2(subitem_path, dest_subitem_path)

print("🎉 Asset optimization and restoration completed successfully!")
