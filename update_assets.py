
import os
import shutil
import json

uploaded_files = [
    "/Users/hectorgarcia/.gemini/antigravity/brain/9adf41bf-b831-4d69-8774-ea5030461234/uploaded_image_0_1765275559321.png",
    "/Users/hectorgarcia/.gemini/antigravity/brain/9adf41bf-b831-4d69-8774-ea5030461234/uploaded_image_1_1765275559321.png",
    "/Users/hectorgarcia/.gemini/antigravity/brain/9adf41bf-b831-4d69-8774-ea5030461234/uploaded_image_2_1765275559321.png",
    "/Users/hectorgarcia/.gemini/antigravity/brain/9adf41bf-b831-4d69-8774-ea5030461234/uploaded_image_3_1765275559321.png",
    "/Users/hectorgarcia/.gemini/antigravity/brain/9adf41bf-b831-4d69-8774-ea5030461234/uploaded_image_4_1765275559321.png"
]

assets_dir = "/Users/hectorgarcia/LYO_Da_ONE/Sources/Resources/Assets.xcassets"

if not os.path.exists(assets_dir):
    print(f"Error: Assets directory not found at {assets_dir}")
    exit(1)

for i, src in enumerate(uploaded_files):
    if not os.path.exists(src):
        print(f"Warning: Source file not found: {src}")
        continue
        
    name = f"reading_{i}"
    imageset_dir = os.path.join(assets_dir, f"{name}.imageset")
    os.makedirs(imageset_dir, exist_ok=True)
    
    dest_path = os.path.join(imageset_dir, f"{name}.png")
    shutil.copy2(src, dest_path)
    print(f"Copied {src} to {dest_path}")
    
    contents = {
      "images" : [
        {
          "filename" : f"{name}.png",
          "idiom" : "universal",
          "scale" : "1x"
        },
        {
          "idiom" : "universal",
          "scale" : "2x"
        },
        {
          "idiom" : "universal",
          "scale" : "3x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    
    with open(os.path.join(imageset_dir, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print(f"Created Contents.json for {name}")

print("Done.")
