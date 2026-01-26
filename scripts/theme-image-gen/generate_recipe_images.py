#!/usr/bin/env python3
"""
Theme Recipe Image Generator using Replicate FLUX API
Generates images for all 130 theme recipes with consistent heritage aesthetic.
"""

import json
import os
import sys
import glob
import hashlib
import time
import argparse
from pathlib import Path
import replicate
import requests

# Configuration
THEME_DIR = Path(__file__).parent.parent.parent / "themerecipes"
NEWTHEMES_DIR = Path(__file__).parent.parent.parent / "themerecipes" / "newthemes"
OUTPUT_DIR = Path(__file__).parent / "images"
MANIFEST_PATH = Path(__file__).parent / "image_manifest.json"
FLUX_MODEL = "black-forest-labs/flux-dev"

# Era styling for each theme (using themeId from JSON files, not filename)
ERA_STYLES = {
    'automat-classics': '1920s-1950s New York automat culture, art deco details, chrome and glass, efficient urban dining, nostalgic Americana',
    'railroad-dining': '1920s-1950s luxury train dining car, elegant table service, cross-country journey romance, upscale mid-century styling',
    'victory-kitchen': 'WWII 1940s home front, patriotic colors, practical rationing-inspired, resilient American spirit, wartime resourcefulness',
    'navy-mess': 'Naval tradition dining, hearty practical portions, stainless steel trays, maritime heritage, military service aesthetic',
    'boston-cooking-school': 'Early American colonial and Victorian Boston, refined traditional styling, Boston cookbook heritage, historic New England',
    'southern-roots': 'American South culinary traditions, warm family gatherings, comfort food aesthetic, Southern hospitality feel',
    'scandinavian-heritage': 'Nordic heritage cuisine, clean simple lines, wholesome seasonal ingredients, Scandinavian design principles',
    'german-american': 'German immigrant culinary heritage, robust hearty portions, community gathering aesthetic, old-world craftsmanship',
    'quick-weeknight': 'Mid-century modern convenience cooking, practical family-friendly, 1950s-1960s suburban American home',
    'sunday-suppers': 'Multi-generational family gathering, warm leisurely dining, Sunday best presentation, traditional family recipes',
    'presidential-pantry': 'Colonial American formal entertaining, 18th-century Mount Vernon style, elegant but not ostentatious, presidential dining aesthetic, pewter and silver, White House state dinner tradition',
    'literary-kitchen': 'Victorian era formality, Mrs. Beeton cookbook aesthetic, ornate china, Edwardian dining, Dickensian literary feast feel, sepia undertones, classic literature inspiration',
    'ancient-table': 'Classical antiquity, archaeological recreation photography, earth tones, ancient Roman/Greek styling, museum-quality presentation, historical accuracy, terracotta and olive branches',
    'american-foundation': 'Colonial hearth cooking, cast iron skillets, rough-hewn tables, rustic Americana, founding era simplicity, honest farm-to-table, early American heritage'
}

# Base heritage style (always applied)
BASE_STYLE = (
    "warm golden hour lighting, rustic wooden table, "
    "4:3 landscape aspect ratio, slightly overhead angle 30-45 degrees, "
    "home-cooked heritage aesthetic not restaurant, cream and amber color palette, "
    "soft natural shadows, nostalgic feel, professional food photography"
)

# Negative prompt for consistency
NEGATIVE_PROMPT = (
    "modern plating, restaurant styling, garnishes, microgreens, foam, "
    "molecular gastronomy, neon colors, harsh lighting, people, hands, "
    "text, watermarks, logos, smartphones, modern appliances"
)


def generate_seed(recipe_id):
    """Generate consistent seed from recipe ID for reproducibility"""
    return int(hashlib.md5(recipe_id.encode()).hexdigest()[:8], 16)


def generate_prompt(recipe, era_style):
    """
    Generate three-layer prompt:
    1. Base: Recipe title + base heritage style
    2. Era: Theme-specific context + historical source
    3. Details: Key ingredients for visual context
    """
    # Layer 1: Base with recipe title
    base = f"A beautifully styled photograph of {recipe['title']}"

    # Layer 2: Era context
    era = f", {era_style}"
    if recipe.get('source'):
        era += f", authentic to historical source"

    # Layer 3: Ingredient details
    ingredients = recipe.get('ingredients', [])[:5]
    if ingredients:
        ingredient_names = ', '.join(ingredients)
        era += f", featuring {ingredient_names}"

    # Combine all layers with base style
    full_prompt = f"{base}{era}, {BASE_STYLE}"

    return full_prompt


def load_all_recipes():
    """Load all recipes from theme files in both directories"""
    # Load from main themes directory
    theme_files = sorted(glob.glob(str(THEME_DIR / "theme-*.json")))

    # Load from newthemes directory
    if NEWTHEMES_DIR.exists():
        theme_files.extend(sorted(glob.glob(str(NEWTHEMES_DIR / "theme-*.json"))))

    if not theme_files:
        print(f"Error: No theme files found in {THEME_DIR} or {NEWTHEMES_DIR}")
        sys.exit(1)

    all_recipes = []
    theme_summary = {}

    for theme_file in theme_files:
        with open(theme_file, 'r') as f:
            theme_data = json.load(f)
            theme_id = theme_data['themeId']
            theme_name = theme_data['themeName']
            recipes = theme_data.get('recipes', [])

            theme_summary[theme_id] = {
                'name': theme_name,
                'count': len(recipes)
            }

            for recipe in recipes:
                # Extract ingredient names only
                ingredient_names = [
                    ing['name'] if isinstance(ing, dict) else ing
                    for ing in recipe.get('ingredients', [])
                ]

                all_recipes.append({
                    'id': recipe['id'],
                    'title': recipe['title'],
                    'ingredients': ingredient_names,
                    'story': recipe.get('story', ''),
                    'source': recipe.get('source', ''),
                    'theme_id': theme_id,
                    'theme_name': theme_name,
                    'unlock_day': recipe.get('unlockDay'),
                    'sort_order': recipe.get('sortOrder', 0)
                })

    return all_recipes, theme_summary


def generate_image(recipe, era_style, output_path, preview_only=False):
    """Generate image using Replicate FLUX API"""
    prompt = generate_prompt(recipe, era_style)
    seed = generate_seed(recipe['id'])

    if preview_only:
        print(f"\n{'='*80}")
        print(f"Recipe: {recipe['title']}")
        print(f"Theme: {recipe['theme_name']}")
        print(f"ID: {recipe['id']}")
        print(f"Seed: {seed}")
        print(f"\nPrompt:\n{prompt}")
        print(f"\nNegative Prompt:\n{NEGATIVE_PROMPT}")
        print(f"{'='*80}\n")
        return True

    try:
        print(f"Generating: {recipe['title']} ({recipe['theme_name']})...")

        output = replicate.run(
            FLUX_MODEL,
            input={
                "prompt": prompt,
                "aspect_ratio": "4:3",
                "output_format": "webp",
                "output_quality": 90,
                "seed": seed,
                "num_inference_steps": 28,
                "guidance_scale": 3.5,
                "negative_prompt": NEGATIVE_PROMPT
            }
        )

        # Download image
        image_url = output[0] if isinstance(output, list) else output
        response = requests.get(image_url, timeout=30)
        response.raise_for_status()

        # Save as WebP
        with open(output_path, 'wb') as f:
            f.write(response.content)

        file_size = os.path.getsize(output_path) / 1024  # KB
        print(f"  ✓ Saved to {output_path.name} ({file_size:.1f} KB)")
        return True

    except Exception as e:
        print(f"  ✗ Error generating {recipe['id']}: {str(e)}")
        return False


def save_manifest(recipes, output_dir):
    """Save manifest mapping recipe IDs to image filenames"""
    manifest = {
        'total_recipes': len(recipes),
        'themes': {},
        'recipes': []
    }

    # Group by theme
    for recipe in recipes:
        theme_id = recipe['theme_id']
        if theme_id not in manifest['themes']:
            manifest['themes'][theme_id] = {
                'name': recipe['theme_name'],
                'recipes': []
            }

        recipe_entry = {
            'id': recipe['id'],
            'title': recipe['title'],
            'theme_id': theme_id,
            'theme_name': recipe['theme_name'],
            'image_filename': f"{theme_id}-{recipe['id']}.webp",
            'unlock_day': recipe.get('unlock_day')
        }

        manifest['recipes'].append(recipe_entry)
        manifest['themes'][theme_id]['recipes'].append(recipe['id'])

    with open(MANIFEST_PATH, 'w') as f:
        json.dump(manifest, f, indent=2)

    print(f"\n✓ Manifest saved to {MANIFEST_PATH}")


def main():
    parser = argparse.ArgumentParser(description='Generate theme recipe images with Replicate FLUX')
    parser.add_argument('--preview-only', action='store_true', help='Show prompts without generating images')
    parser.add_argument('--limit', type=int, help='Limit number of images to generate')
    parser.add_argument('--start-from', type=int, default=0, help='Start from recipe index N')
    parser.add_argument('--delay', type=float, default=7.0, help='Delay between API calls (seconds)')
    parser.add_argument('--theme', help='Generate only for specific theme (e.g., theme-01-automat-classics)')

    args = parser.parse_args()

    # Check API token
    if not args.preview_only and not os.getenv('REPLICATE_API_TOKEN'):
        print("Error: REPLICATE_API_TOKEN environment variable not set")
        print("Set it with: export REPLICATE_API_TOKEN='r8_your_key_here'")
        sys.exit(1)

    # Create output directory
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Load recipes
    print("Loading theme recipes...")
    all_recipes, theme_summary = load_all_recipes()

    print(f"\nFound {len(all_recipes)} recipes across {len(theme_summary)} themes:")
    for theme_id, info in sorted(theme_summary.items()):
        print(f"  {theme_id}: {info['name']} ({info['count']} recipes)")

    # Filter by theme if specified
    if args.theme:
        all_recipes = [r for r in all_recipes if r['theme_id'] == args.theme]
        if not all_recipes:
            print(f"\nError: No recipes found for theme '{args.theme}'")
            sys.exit(1)
        print(f"\nFiltered to {len(all_recipes)} recipes for theme: {args.theme}")

    # Apply start-from and limit
    recipes_to_process = all_recipes[args.start_from:]
    if args.limit:
        recipes_to_process = recipes_to_process[:args.limit]

    print(f"\nProcessing {len(recipes_to_process)} recipes...")

    # Generate images
    success_count = 0
    skip_count = 0
    fail_count = 0

    for i, recipe in enumerate(recipes_to_process, 1):
        # Include theme prefix in filename: theme-01-recipe-id.webp
        output_path = OUTPUT_DIR / f"{recipe['theme_id']}-{recipe['id']}.webp"
        era_style = ERA_STYLES.get(recipe['theme_id'], '')

        # Skip if already exists (resume capability)
        if not args.preview_only and output_path.exists():
            print(f"[{i}/{len(recipes_to_process)}] Skipping {recipe['id']} (already exists)")
            skip_count += 1
            continue

        print(f"[{i}/{len(recipes_to_process)}] ", end='')

        if generate_image(recipe, era_style, output_path, args.preview_only):
            success_count += 1
        else:
            fail_count += 1

        # Rate limiting delay
        if not args.preview_only and i < len(recipes_to_process):
            time.sleep(args.delay)

    # Save manifest
    if not args.preview_only:
        save_manifest(all_recipes, OUTPUT_DIR)

    # Summary
    print(f"\n{'='*80}")
    print("Summary:")
    print(f"  Total recipes: {len(all_recipes)}")
    print(f"  Processed: {len(recipes_to_process)}")
    if not args.preview_only:
        print(f"  Success: {success_count}")
        print(f"  Skipped: {skip_count}")
        print(f"  Failed: {fail_count}")
        print(f"  Cost estimate: ${success_count * 0.003:.2f}")
    print(f"{'='*80}\n")


if __name__ == '__main__':
    main()
