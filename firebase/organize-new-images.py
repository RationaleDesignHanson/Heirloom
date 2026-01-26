#!/usr/bin/env python3

"""
Organize New Recipe Images
Organizes recipe images with new naming convention into theme subdirectories
Naming convention: {theme-id}-{prefix}-{number}.webp or {theme-id}-{recipe-slug}.webp
"""

import os
import shutil
from pathlib import Path

# Source and destination directories
IMAGES_SRC = "/Users/matthanson/Heirloom/scripts/theme-image-gen/images"
IMAGES_DEST = "/Users/matthanson/Heirloom/recipe-images"

# Theme IDs (in order)
THEME_IDS = [
    'automat-classics',
    'railroad-dining',
    'victory-kitchen',
    'navy-mess',
    'boston-cooking-school',
    'southern-roots',
    'scandinavian-heritage',
    'german-american',
    'quick-weeknight',
    'sunday-suppers',
    'presidential-pantry',
    'literary-kitchen',
    'ancient-table',
    'american-foundation'
]

def main():
    print("🗂️  Organizing recipe images with new naming convention...\n")

    # Clean destination directory
    if Path(IMAGES_DEST).exists():
        print(f"🧹 Cleaning existing directory: {IMAGES_DEST}")
        shutil.rmtree(IMAGES_DEST)

    Path(IMAGES_DEST).mkdir(parents=True, exist_ok=True)

    total_copied = 0
    total_missing = 0

    for theme_id in THEME_IDS:
        print(f"\n📂 Processing {theme_id}...")

        # Create theme directory
        theme_dir = Path(IMAGES_DEST) / theme_id
        theme_dir.mkdir(exist_ok=True)

        count = 0

        # Find all images that start with this theme ID
        for file in Path(IMAGES_SRC).glob(f"{theme_id}-*.webp"):
            # Skip cover images
            if 'cover' in file.name:
                continue

            dest_file = theme_dir / file.name
            shutil.copy2(file, dest_file)
            print(f"  ✓ {file.name}")
            count += 1
            total_copied += 1

        if count == 0:
            print(f"  ⚠️  No images found for {theme_id}")
            total_missing += 1
        else:
            print(f"  → {count} images copied")

    print(f"\n📊 Summary:")
    print(f"   Themes processed: {len(THEME_IDS)}")
    print(f"   Images organized: {total_copied}")
    print(f"   Themes with no images: {total_missing}")

    if total_missing > 0:
        print(f"\n⚠️  {total_missing} theme(s) have no images")
    else:
        print(f"\n✅ All recipe images organized successfully!")

    print(f"\n📍 Recipe images organized in:")
    print(f"   {IMAGES_DEST}")

    # List counts per theme
    print(f"\n📋 Images per theme:")
    for theme_id in THEME_IDS:
        theme_dir = Path(IMAGES_DEST) / theme_id
        if theme_dir.exists():
            image_count = len(list(theme_dir.glob("*.webp")))
            print(f"   {theme_id}: {image_count} images")

if __name__ == "__main__":
    main()
