#!/usr/bin/env python3
"""
Theme Collection Cover Image Generator using Replicate FLUX API
Generates hero/cover images for each of the 10 theme collections.
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
OUTPUT_DIR = Path(__file__).parent / "theme-covers"
FLUX_MODEL = "black-forest-labs/flux-dev"

# Theme cover prompts - representative imagery for each collection
THEME_COVER_PROMPTS = {
    'theme-01-automat-classics': {
        'title': 'Automat Classics',
        'prompt': 'A nostalgic 1920s-1950s New York automat cafeteria scene, art deco chrome and glass coin-operated food dispensers, elegant display of classic American comfort food behind small glass windows, warm golden lighting, vintage aesthetic, urban dining romance, architectural photography style showing the iconic automat wall of food compartments',
        'era': '1920s-1950s'
    },
    'theme-02-railroad-dining': {
        'title': 'Golden Age of Rail',
        'prompt': 'An elegant 1940s luxury train dining car interior, white tablecloths and fine china set for service, polished wood paneling and brass fixtures, American landscape passing by large windows, warm ambient lighting, sophisticated mid-century travel elegance, golden age of rail romance',
        'era': '1920s-1950s'
    },
    'theme-03-victory-kitchen': {
        'title': 'Victory Kitchen',
        'prompt': 'A WWII 1940s American home front kitchen, patriotic red white and blue accents, ration books and victory garden produce on a wooden table, practical cooking tools, vintage war-era propaganda posters visible, warm homey lighting, resilient American spirit, wartime resourcefulness aesthetic',
        'era': '1940s'
    },
    'theme-04-navy-mess': {
        'title': 'Navy Mess Hall',
        'prompt': 'A traditional naval mess hall table setting, stainless steel trays with compartments, hearty portions of classic navy cuisine, maritime heritage aesthetic, practical naval service environment, nautical blue and white color scheme, military dining tradition, honest substantial food presentation',
        'era': 'Timeless Naval Tradition'
    },
    'theme-05-boston-cooking': {
        'title': 'Boston Cooking School',
        'prompt': 'A Victorian-era Boston Cooking School kitchen scene, antique cookbook open on wooden table, refined traditional American ingredients arranged elegantly, colonial New England aesthetic, brass and copper cookware, historical culinary education atmosphere, warm library-like lighting, Fannie Farmer era authenticity',
        'era': '1890s-1920s'
    },
    'theme-06-southern-roots': {
        'title': 'Southern Roots',
        'prompt': 'A warm Southern family gathering table, traditional comfort food spread on rustic wooden surface, Mason jars and cast iron skillets, magnolia blooms in background, golden hour warm lighting, Southern hospitality aesthetic, family recipe tradition, home-cooked soul food presentation',
        'era': 'Traditional Southern'
    },
    'theme-07-scandinavian': {
        'title': 'Scandinavian Heritage',
        'prompt': 'A clean Nordic kitchen scene with wholesome Scandinavian ingredients, simple wooden table with pale wood tones, fresh seasonal produce, minimalist aesthetic, natural daylight streaming through windows, traditional Nordic cookware, hygge atmosphere, Scandinavian design principles, honest wholesome food',
        'era': 'Nordic Heritage'
    },
    'theme-08-german-american': {
        'title': 'German-American Heritage',
        'prompt': 'A traditional German-American gathering table, robust hearty dishes arranged on dark wood, steins and old-world serving platters, community feast aesthetic, warm tavern-like lighting, immigrant culinary heritage, European craftsmanship meets American abundance, celebratory meal presentation',
        'era': 'Old World Heritage'
    },
    'theme-09-quick-weeknight': {
        'title': 'Quick Weeknight Meals',
        'prompt': 'A cheerful 1950s-1960s suburban American kitchen, practical family-friendly meal on Formica countertop, vintage appliances in pastel colors, modern convenience cooking aesthetic, mid-century home economics style, warm domestic lighting, post-war American optimism, practical weeknight dinner scene',
        'era': '1950s-1960s'
    },
    'theme-10-sunday-suppers': {
        'title': 'Sunday Suppers',
        'title_short': 'Sunday Suppers',
        'prompt': 'A traditional Sunday family supper table, multiple generations gathering around abundant home-cooked meal, heirloom serving dishes and tablecloth, warm leisurely afternoon lighting, multi-generational family tradition, special occasion presentation without formality, Sunday best comfort food aesthetic',
        'era': 'Timeless Family Tradition'
    },
    'presidential-pantry': {
        'title': 'Presidential Pantry',
        'prompt': 'Elegant White House state dining room with presidential china and formal place settings on a grand dining table, patriotic red white and blue color accents, historical Americana aesthetic, formal yet warm atmosphere, classical architectural details, dignified presentation, heritage illustration style',
        'era': '1700s-1900s'
    },
    'literary-kitchen': {
        'title': 'Literary Kitchen',
        'prompt': 'Cozy library reading nook with vintage leather-bound cookbooks stacked on wooden table, literary-inspired dishes arranged elegantly, warm candlelight creating intimate atmosphere, classic literature aesthetic, Victorian-Edwardian era charm, storybook illustration style, warm sepia tones',
        'era': 'Victorian-Edwardian'
    },
    'ancient-table': {
        'title': 'Ancient Table',
        'prompt': 'Ancient Roman or Greek dining room with terracotta amphoras and olive branches, classical Greco-Roman architectural columns visible, archaeological illustration style, earth tones and natural materials, historical authenticity, museum-quality presentation, classical antiquity aesthetic',
        'era': 'Ancient Greece & Rome'
    },
    'american-foundation': {
        'title': 'American Foundation',
        'prompt': 'Colonial American hearth kitchen with copper pots hanging on wall and wooden utensils on rustic table, candlelit warmth creating cozy atmosphere, cast iron cookware, rough-hewn wood surfaces, Americana folk art style, founding era simplicity, early American heritage aesthetic, honest craftsmanship',
        'era': '1700s-1800s'
    }
}

# Base style for all covers
BASE_STYLE = (
    "professional photography, warm nostalgic atmosphere, heritage aesthetic, "
    "soft natural lighting, authentic historical accuracy, high detail, "
    "cinematic composition, no text overlays, no people visible, no modern elements"
)

# Negative prompt
NEGATIVE_PROMPT = (
    "modern plating, restaurant styling, molecular gastronomy, neon colors, "
    "harsh lighting, people, faces, hands, text, watermarks, logos, "
    "smartphones, contemporary design, plastic, processed food packaging"
)


def generate_seed(theme_id):
    """Generate consistent seed from theme ID"""
    return int(hashlib.md5(theme_id.encode()).hexdigest()[:8], 16)


def generate_cover_image(theme_id, theme_data, output_path, aspect_ratio="16:9", preview_only=False):
    """Generate theme cover image using Replicate FLUX API"""
    full_prompt = f"{theme_data['prompt']}, {BASE_STYLE}"
    seed = generate_seed(theme_id)

    if preview_only:
        print(f"\n{'='*80}")
        print(f"Theme: {theme_data['title']}")
        print(f"ID: {theme_id}")
        print(f"Era: {theme_data['era']}")
        print(f"Aspect Ratio: {aspect_ratio}")
        print(f"Seed: {seed}")
        print(f"\nPrompt:\n{full_prompt}")
        print(f"\nNegative Prompt:\n{NEGATIVE_PROMPT}")
        print(f"{'='*80}\n")
        return True

    try:
        print(f"Generating cover for: {theme_data['title']}...")

        output = replicate.run(
            FLUX_MODEL,
            input={
                "prompt": full_prompt,
                "aspect_ratio": aspect_ratio,
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
        print(f"  ✗ Error generating {theme_id}: {str(e)}")
        return False


def save_manifest(covers_generated):
    """Save manifest of generated theme covers"""
    manifest_path = OUTPUT_DIR / "theme_covers_manifest.json"

    manifest = {
        'total_themes': len(THEME_COVER_PROMPTS),
        'covers_generated': len(covers_generated),
        'covers': covers_generated
    }

    with open(manifest_path, 'w') as f:
        json.dump(manifest, f, indent=2)

    print(f"\n✓ Manifest saved to {manifest_path}")


def main():
    parser = argparse.ArgumentParser(description='Generate theme collection cover images with Replicate FLUX')
    parser.add_argument('--preview-only', action='store_true', help='Show prompts without generating images')
    parser.add_argument('--delay', type=float, default=7.0, help='Delay between API calls (seconds)')
    parser.add_argument('--aspect-ratio', default='16:9', choices=['16:9', '4:3', '3:2', '1:1'],
                        help='Aspect ratio for cover images (default: 16:9 for collection covers)')
    parser.add_argument('--theme', help='Generate only for specific theme (e.g., theme-01-automat-classics)')

    args = parser.parse_args()

    # Check API token
    if not args.preview_only and not os.getenv('REPLICATE_API_TOKEN'):
        print("Error: REPLICATE_API_TOKEN environment variable not set")
        print("Set it with: export REPLICATE_API_TOKEN='r8_your_key_here'")
        sys.exit(1)

    # Create output directory
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Theme Collection Cover Generator")
    print(f"Aspect Ratio: {args.aspect_ratio}")
    print(f"Total themes: {len(THEME_COVER_PROMPTS)}\n")

    # Filter themes if specified
    themes_to_process = THEME_COVER_PROMPTS.items()
    if args.theme:
        if args.theme not in THEME_COVER_PROMPTS:
            print(f"Error: Theme '{args.theme}' not found")
            sys.exit(1)
        themes_to_process = [(args.theme, THEME_COVER_PROMPTS[args.theme])]

    # Generate covers
    success_count = 0
    skip_count = 0
    fail_count = 0
    covers_generated = []

    for i, (theme_id, theme_data) in enumerate(themes_to_process, 1):
        output_path = OUTPUT_DIR / f"{theme_id}-cover.webp"

        # Skip if already exists
        if not args.preview_only and output_path.exists():
            print(f"[{i}/{len(themes_to_process)}] Skipping {theme_id} (already exists)")
            skip_count += 1
            covers_generated.append({
                'theme_id': theme_id,
                'title': theme_data['title'],
                'filename': f"{theme_id}-cover.webp",
                'era': theme_data['era']
            })
            continue

        print(f"[{i}/{len(themes_to_process)}] ", end='')

        if generate_cover_image(theme_id, theme_data, output_path, args.aspect_ratio, args.preview_only):
            success_count += 1
            if not args.preview_only:
                covers_generated.append({
                    'theme_id': theme_id,
                    'title': theme_data['title'],
                    'filename': f"{theme_id}-cover.webp",
                    'era': theme_data['era']
                })
        else:
            fail_count += 1

        # Rate limiting delay
        if not args.preview_only and i < len(list(themes_to_process)):
            time.sleep(args.delay)

    # Save manifest
    if not args.preview_only and covers_generated:
        save_manifest(covers_generated)

    # Summary
    print(f"\n{'='*80}")
    print("Summary:")
    print(f"  Total themes: {len(THEME_COVER_PROMPTS)}")
    print(f"  Processed: {len(list(themes_to_process))}")
    if not args.preview_only:
        print(f"  Success: {success_count}")
        print(f"  Skipped: {skip_count}")
        print(f"  Failed: {fail_count}")
        print(f"  Cost estimate: ${success_count * 0.003:.2f}")
    print(f"{'='*80}\n")


if __name__ == '__main__':
    main()
