#!/usr/bin/env python3
"""
Rename existing images to include theme prefix
Converts: recipe-id.webp -> theme-id-recipe-id.webp
"""

import json
import glob
import os
from pathlib import Path

# Configuration
THEME_DIR = Path(__file__).parent.parent.parent / "themerecipes"
IMAGES_DIR = Path(__file__).parent / "images"

def load_recipe_to_theme_mapping():
    """Build mapping of recipe ID to theme ID"""
    recipe_to_theme = {}
    all_theme_ids = set()

    # Load all theme files
    theme_files = sorted(glob.glob(str(THEME_DIR / "theme-*.json")))

    for theme_file in theme_files:
        with open(theme_file, 'r') as f:
            theme_data = json.load(f)
            theme_id = theme_data['themeId']
            all_theme_ids.add(theme_id)

            for recipe in theme_data.get('recipes', []):
                recipe_id = recipe['id']
                recipe_to_theme[recipe_id] = theme_id

    return recipe_to_theme, all_theme_ids

def main():
    print("Renaming existing images to include theme prefix...")
    print("="*80)

    # Load recipe-to-theme mapping
    recipe_to_theme, all_theme_ids = load_recipe_to_theme_mapping()
    print(f"Loaded {len(recipe_to_theme)} recipe mappings from theme files")
    print(f"Found {len(all_theme_ids)} theme IDs: {', '.join(sorted(all_theme_ids))}\n")

    # Find all existing images
    existing_images = list(IMAGES_DIR.glob("*.webp"))

    if not existing_images:
        print("No images found to rename")
        return

    print(f"Found {len(existing_images)} existing images\n")

    renamed_count = 0
    already_prefixed_count = 0
    not_found_count = 0

    for image_path in sorted(existing_images):
        filename = image_path.name
        name_without_ext = image_path.stem  # filename without extension

        # Check if already has theme prefix by seeing if it starts with a known theme ID
        has_theme_prefix = False
        for theme_id in all_theme_ids:
            if name_without_ext.startswith(f"{theme_id}-"):
                has_theme_prefix = True
                print(f"  ✓ Already prefixed: {filename}")
                already_prefixed_count += 1
                break

        if has_theme_prefix:
            continue

        # This is an old-format filename, find the recipe ID
        recipe_id = name_without_ext

        # Look up theme for this recipe
        if recipe_id not in recipe_to_theme:
            print(f"  ⚠ Recipe ID not found in themes: {recipe_id}")
            not_found_count += 1
            continue

        theme_id = recipe_to_theme[recipe_id]
        new_filename = f"{theme_id}-{filename}"
        new_path = IMAGES_DIR / new_filename

        # Rename the file
        try:
            image_path.rename(new_path)
            print(f"  ✓ Renamed: {filename} -> {new_filename}")
            renamed_count += 1
        except Exception as e:
            print(f"  ✗ Error renaming {filename}: {str(e)}")

    # Summary
    print(f"\n{'='*80}")
    print("Summary:")
    print(f"  Total images found: {len(existing_images)}")
    print(f"  Already prefixed: {already_prefixed_count}")
    print(f"  Successfully renamed: {renamed_count}")
    print(f"  Recipe ID not found: {not_found_count}")
    print(f"{'='*80}\n")

    if renamed_count > 0:
        print("✓ Rename complete! Images now match the new naming convention.")
        print("  Run './run_image_gen.sh generate' to generate only the missing images.")
    elif already_prefixed_count == len(existing_images):
        print("✓ All images already use the new naming convention.")
    else:
        print("⚠ No images were renamed. Check the output above for issues.")

if __name__ == '__main__':
    main()
