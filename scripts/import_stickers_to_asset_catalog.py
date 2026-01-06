#!/usr/bin/env python3
"""
Import stickers from stickergenerator output into Xcode Asset Catalog.
Creates asset catalog structure and generates metadata JSON for StickerLibraryService.
"""

import json
import os
import shutil
from pathlib import Path

# Paths
STICKER_SOURCE_DIR = Path("/Users/matthanson/Heirloom/stickergenerator/heirloom_stickers_complete")
METADATA_FILE = STICKER_SOURCE_DIR / "metadata.json"
ASSET_CATALOG = Path("/Users/matthanson/Heirloom/Heirloom/Assets.xcassets/Stickers")
OUTPUT_JSON = Path("/Users/matthanson/Heirloom/Heirloom/Resources/sticker_library.json")

# Category mapping from generator to app categories
CATEGORY_MAP = {
    "food": "botanical",  # Food items map to botanical
    "tools": "utensils",   # Tools map to utensils
    "badges": "icons",     # Badges map to icons
    "seasonal": "seasonal",
    "annotations": "typography",
    "decorative": "decorative",
    "emotions": "icons",  # Emotions also map to icons
    "time": "icons"       # Time also maps to icons
}

def load_metadata():
    """Load sticker metadata from JSON"""
    with open(METADATA_FILE, 'r') as f:
        return json.load(f)

def create_asset_catalog():
    """Create Asset Catalog directory structure"""
    ASSET_CATALOG.mkdir(parents=True, exist_ok=True)

    # Create Contents.json for the stickers folder
    contents_json = {
        "info": {
            "author": "xcode",
            "version": 1
        },
        "properties": {
            "provides-namespace": True
        }
    }

    with open(ASSET_CATALOG / "Contents.json", 'w') as f:
        json.dump(contents_json, f, indent=2)

    print(f"✓ Created asset catalog at {ASSET_CATALOG}")

def import_sticker(sticker_data):
    """Import a single sticker into Asset Catalog"""
    name = sticker_data['name']
    # filepath in metadata includes the parent dir, extract just the filename
    filename = Path(sticker_data['filepath']).name
    category = sticker_data['category']
    filepath = STICKER_SOURCE_DIR / category / filename

    # Create asset name (e.g., "sticker_tomato")
    asset_name = f"sticker_{name.lower().replace(' ', '_').replace('-', '_')}"

    # Create imageset directory
    imageset_dir = ASSET_CATALOG / f"{asset_name}.imageset"
    imageset_dir.mkdir(parents=True, exist_ok=True)

    # Copy PNG file
    dest_file = imageset_dir / f"{asset_name}.png"
    shutil.copy2(filepath, dest_file)

    # Create Contents.json for the imageset
    contents = {
        "images": [
            {
                "filename": f"{asset_name}.png",
                "idiom": "universal",
                "scale": "1x"
            },
            {
                "idiom": "universal",
                "scale": "2x"
            },
            {
                "idiom": "universal",
                "scale": "3x"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        }
    }

    with open(imageset_dir / "Contents.json", 'w') as f:
        json.dump(contents, f, indent=2)

    return asset_name

def generate_library_json(metadata):
    """Generate JSON file for StickerLibraryService to load"""
    stickers = []

    for idx, sticker_data in enumerate(metadata['stickers']):
        name = sticker_data['name']
        category = sticker_data['category']
        mapped_category = CATEGORY_MAP.get(category, "icons")

        # Create asset name
        asset_name = f"sticker_{name.lower().replace(' ', '_').replace('-', '_')}"

        # Create sticker entry
        sticker = {
            "id": asset_name,
            "name": name,
            "category": mapped_category,
            "assetName": asset_name,
            "supportsTinting": True if mapped_category in ["decorative", "icons", "typography"] else False,
            "defaultSize": {
                "width": 0.15,
                "height": 0.15
            },
            "tags": extract_tags(name, category),
            "isPremium": False,
            "sortOrder": idx
        }

        stickers.append(sticker)

    return stickers

def extract_tags(name, category):
    """Extract searchable tags from name and category"""
    tags = [category.lower(), name.lower()]

    # Add common keywords
    keywords_map = {
        "tomato": ["vegetable", "red", "produce"],
        "garlic": ["vegetable", "seasoning", "bulb"],
        "lemon": ["citrus", "fruit", "yellow"],
        "heart": ["love", "emotion"],
        "star": ["rating", "favorite"],
        "clock": ["time", "timer"],
        "badge": ["label", "award"],
        # Add more as needed
    }

    for keyword, extra_tags in keywords_map.items():
        if keyword in name.lower():
            tags.extend(extra_tags)

    return list(set(tags))  # Remove duplicates

def main():
    print("🎨 Importing Stickers to Asset Catalog\n")

    # Load metadata
    print("📖 Loading metadata...")
    metadata = load_metadata()
    print(f"✓ Found {metadata['total_stickers']} stickers\n")

    # Create asset catalog
    print("📁 Creating asset catalog...")
    create_asset_catalog()
    print()

    # Import each sticker
    print("🖼️  Importing stickers...")
    imported = 0
    for sticker_data in metadata['stickers']:
        asset_name = import_sticker(sticker_data)
        imported += 1
        if imported % 10 == 0:
            print(f"   Imported {imported}/{metadata['total_stickers']} stickers...")

    print(f"✓ Imported all {imported} stickers\n")

    # Generate library JSON
    print("📝 Generating sticker library JSON...")
    stickers = generate_library_json(metadata)

    # Ensure output directory exists
    OUTPUT_JSON.parent.mkdir(parents=True, exist_ok=True)

    with open(OUTPUT_JSON, 'w') as f:
        json.dump({"stickers": stickers}, f, indent=2)

    print(f"✓ Generated {OUTPUT_JSON}\n")

    # Summary
    print("✨ Summary:")
    print(f"   Total stickers: {len(stickers)}")
    print(f"   Asset catalog: {ASSET_CATALOG}")
    print(f"   Library JSON: {OUTPUT_JSON}")
    print(f"\n✅ Import complete!")

if __name__ == "__main__":
    main()
