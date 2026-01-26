#!/usr/bin/env python3

import os
import json
import shutil
from pathlib import Path

# Source and destination directories
RECIPES_JSON_DIR = "/Users/matthanson/Desktop/themerecipes"
IMAGES_SRC = "/Users/matthanson/Heirloom/scripts/theme-image-gen/images"
IMAGES_DEST = "/Users/matthanson/Heirloom/recipe-images"

# Theme file to Firebase ID mapping
THEME_FILE_MAP = {
    'theme-01-automat-classics.json': 'automat-classics',
    'theme-02-railroad-dining.json': 'railroad-dining',
    'theme-03-victory-kitchen.json': 'victory-kitchen',
    'theme-04-navy-mess.json': 'navy-mess',
    'theme-05-boston-cooking.json': 'boston-cooking-school',
    'theme-06-southern-roots.json': 'southern-roots',
    'theme-07-scandinavian.json': 'scandinavian-heritage',
    'theme-08-german-american.json': 'german-american',
    'theme-09-quick-weeknight.json': 'quick-weeknight',
    'theme-10-sunday-suppers.json': 'sunday-suppers',
    'theme-11-presidential-pantry.json': 'presidential-pantry',
    'theme-12-literary-kitchen.json': 'literary-kitchen',
    'theme-13-ancient-table.json': 'ancient-table',
    'theme-14-american-foundation.json': 'american-foundation'
}

def main():
    print("🗂️  Organizing recipe images by reading JSON files...\n")

    # Clean destination directory
    if Path(IMAGES_DEST).exists():
        print(f"🧹 Cleaning existing directory: {IMAGES_DEST}")
        shutil.rmtree(IMAGES_DEST)

    Path(IMAGES_DEST).mkdir(parents=True, exist_ok=True)

    total_recipes = 0
    total_matched = 0
    total_missing = 0

    # Process each theme JSON file
    for json_file, theme_id in THEME_FILE_MAP.items():
        json_path = Path(RECIPES_JSON_DIR) / json_file

        if not json_path.exists():
            print(f"⚠️  JSON file not found: {json_file}")
            continue

        print(f"\n📂 Processing {theme_id}...")

        # Read theme JSON
        with open(json_path, 'r') as f:
            theme_data = json.load(f)

        recipes = theme_data.get('recipes', [])
        print(f"   Found {len(recipes)} recipes in JSON")

        # Create theme directory
        theme_dir = Path(IMAGES_DEST) / theme_id
        theme_dir.mkdir(exist_ok=True)

        matched = 0
        missing = []

        # For each recipe, find matching image
        for recipe in recipes:
            recipe_id = recipe.get('id')
            if not recipe_id:
                continue

            total_recipes += 1

            # Look for image file
            image_file = Path(IMAGES_SRC) / f"{recipe_id}.webp"

            if image_file.exists():
                dest_file = theme_dir / image_file.name
                shutil.copy2(image_file, dest_file)
                print(f"  ✓ {image_file.name}")
                matched += 1
                total_matched += 1
            else:
                missing.append(recipe_id)
                total_missing += 1

        if missing:
            print(f"\n  ⚠️  Missing images for {len(missing)} recipes:")
            for recipe_id in missing:
                print(f"     - {recipe_id}.webp")

        print(f"  → {matched}/{len(recipes)} images copied")

    print(f"\n📊 Summary:")
    print(f"   Total recipes: {total_recipes}")
    print(f"   Images matched: {total_matched}")
    print(f"   Images missing: {total_missing}")

    if total_missing > 0:
        print(f"\n⚠️  {total_missing} recipe images are missing - you may need to generate them")
    else:
        print(f"\n✅ All recipe images organized successfully!")

    print(f"\n📍 Recipe images organized in:")
    print(f"   {IMAGES_DEST}")

if __name__ == "__main__":
    main()
