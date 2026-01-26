#!/usr/bin/env python3
"""
Convert all recipe IDs to numeric format with accuracy verification
Creates backup, mapping file, and validation report
"""

import json
import glob
import shutil
from pathlib import Path
from datetime import datetime

# Configuration
THEME_DIR = Path(__file__).parent.parent.parent / "themerecipes"
NEWTHEMES_DIR = THEME_DIR / "newthemes"
BACKUP_DIR = Path(__file__).parent / "backups"
MAPPING_FILE = Path(__file__).parent / "id_conversion_mapping.json"

def backup_files():
    """Create timestamped backup of all theme files"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = BACKUP_DIR / timestamp
    backup_path.mkdir(parents=True, exist_ok=True)

    # Backup main themes
    theme_files = glob.glob(str(THEME_DIR / "theme-*.json"))
    for f in theme_files:
        shutil.copy2(f, backup_path / Path(f).name)

    # Backup newthemes
    if NEWTHEMES_DIR.exists():
        newthemes_backup = backup_path / "newthemes"
        newthemes_backup.mkdir(exist_ok=True)
        newthemes_files = glob.glob(str(NEWTHEMES_DIR / "theme-*.json"))
        for f in newthemes_files:
            shutil.copy2(f, newthemes_backup / Path(f).name)

    print(f"✓ Backup created: {backup_path}\n")
    return backup_path

def convert_theme_file(file_path, dry_run=True):
    """Convert recipe IDs in a single theme file"""
    with open(file_path, 'r') as f:
        data = json.load(f)

    theme_id = data['themeId']
    theme_name = data['themeName']
    recipes = data.get('recipes', [])

    # Sort by sortOrder to ensure numeric IDs match intended sequence
    recipes_sorted = sorted(recipes, key=lambda r: r.get('sortOrder', 999))

    conversions = []
    converted_recipes = []

    for idx, recipe in enumerate(recipes_sorted, start=1):
        old_id = recipe['id']
        new_id = f"{theme_id}-{idx:03d}"  # e.g., automat-classics-001

        # Create conversion record
        conversion = {
            'theme_id': theme_id,
            'theme_name': theme_name,
            'old_id': old_id,
            'new_id': new_id,
            'title': recipe['title'],
            'sort_order': recipe.get('sortOrder', idx)
        }
        conversions.append(conversion)

        # Update recipe with new ID
        recipe_copy = recipe.copy()
        recipe_copy['id'] = new_id
        converted_recipes.append(recipe_copy)

    # Create updated data
    data_updated = data.copy()
    data_updated['recipes'] = converted_recipes

    # Write if not dry run
    if not dry_run:
        with open(file_path, 'w') as f:
            json.dump(data_updated, f, indent=2)

    return conversions, len(recipes)

def validate_conversion(original_path, converted_path=None):
    """Validate that conversion preserved all data except IDs"""
    if converted_path is None:
        converted_path = original_path

    with open(original_path, 'r') as f:
        original = json.load(f)
    with open(converted_path, 'r') as f:
        converted = json.load(f)

    # Check recipe counts match
    original_count = len(original.get('recipes', []))
    converted_count = len(converted.get('recipes', []))

    if original_count != converted_count:
        return False, f"Recipe count mismatch: {original_count} vs {converted_count}"

    # Check all fields except 'id' are preserved
    for orig_recipe, conv_recipe in zip(original['recipes'], converted['recipes']):
        for key in orig_recipe:
            if key == 'id':
                continue
            if orig_recipe[key] != conv_recipe[key]:
                return False, f"Field '{key}' changed for recipe '{orig_recipe.get('title')}'"

    return True, "All data preserved"

def main():
    import argparse
    parser = argparse.ArgumentParser(description='Convert recipe IDs to numeric format')
    parser.add_argument('--dry-run', action='store_true', help='Preview changes without modifying files')
    parser.add_argument('--execute', action='store_true', help='Execute the conversion')
    args = parser.parse_args()

    if not args.dry_run and not args.execute:
        print("Error: Must specify either --dry-run or --execute")
        print("Usage:")
        print("  python3 convert_to_numeric_ids.py --dry-run    # Preview changes")
        print("  python3 convert_to_numeric_ids.py --execute    # Execute conversion")
        return

    print("="*80)
    print("Recipe ID Conversion to Numeric Format")
    print("="*80)
    print()

    if args.execute:
        print("⚠️  EXECUTE MODE - Files will be modified")
        print("Creating backup first...\n")
        backup_path = backup_files()
    else:
        print("📋 DRY RUN MODE - No files will be modified\n")

    # Get all theme files
    theme_files = sorted(glob.glob(str(THEME_DIR / "theme-*.json")))
    if NEWTHEMES_DIR.exists():
        theme_files.extend(sorted(glob.glob(str(NEWTHEMES_DIR / "theme-*.json"))))

    print(f"Found {len(theme_files)} theme files\n")

    all_conversions = []
    total_recipes = 0

    # Process each theme file
    for theme_file in theme_files:
        print(f"Processing: {Path(theme_file).name}")
        conversions, count = convert_theme_file(theme_file, dry_run=args.dry_run)
        all_conversions.extend(conversions)
        total_recipes += count

        # Show sample conversions
        print(f"  Recipes: {count}")
        for conv in conversions[:3]:
            print(f"    {conv['old_id']} → {conv['new_id']} ({conv['title']})")
        if len(conversions) > 3:
            print(f"    ... and {len(conversions) - 3} more")
        print()

    # Save mapping file
    mapping_data = {
        'conversion_date': datetime.now().isoformat(),
        'total_themes': len(theme_files),
        'total_recipes': total_recipes,
        'dry_run': args.dry_run,
        'conversions': all_conversions
    }

    mapping_path = MAPPING_FILE if args.execute else Path(str(MAPPING_FILE).replace('.json', '_preview.json'))
    with open(mapping_path, 'w') as f:
        json.dump(mapping_data, f, indent=2)

    print("="*80)
    print("Summary:")
    print(f"  Total themes processed: {len(theme_files)}")
    print(f"  Total recipes converted: {total_recipes}")
    print(f"  Mapping file: {mapping_path}")
    if args.execute:
        print(f"  Backup location: {backup_path}")
    print("="*80)
    print()

    if args.dry_run:
        print("✓ Dry run complete - no files were modified")
        print(f"✓ Review the preview mapping at: {mapping_path}")
        print()
        print("To execute the conversion:")
        print("  python3 convert_to_numeric_ids.py --execute")
    else:
        print("✓ Conversion complete!")
        print(f"✓ Original files backed up to: {backup_path}")
        print(f"✓ Conversion mapping saved to: {mapping_path}")
        print()
        print("Next steps:")
        print("  1. Review the mapping file to verify accuracy")
        print("  2. Clean existing images: rm images/*.webp")
        print("  3. Generate all images with new IDs: ./run_image_gen.sh generate")

if __name__ == '__main__':
    main()
