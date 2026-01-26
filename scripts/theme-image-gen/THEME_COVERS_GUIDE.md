# Theme Collection Cover Images Guide

## Overview

In addition to the 130 individual recipe images, you can generate 14 theme collection cover images. These are hero/banner images for each theme collection (10 theme collections + 4 heritage collections).

## Quick Start

### 1. Preview Cover Prompts

See what the cover images will look like:

```bash
./run_image_gen.sh preview-covers
```

This shows all 10 theme cover prompts without making API calls (no cost).

### 2. Generate All Covers

```bash
./run_image_gen.sh generate-covers
```

- **Cost:** $0.04 (14 covers × $0.003)
- **Time:** ~2 minutes with 7-second delay
- **Output:** `theme-covers/` directory

### 3. Check Status

```bash
./run_image_gen.sh status-covers
```

## Theme Covers

14 collection cover images are generated:

**Theme Collections (10):**
1. **theme-01-automat-classics-cover.webp** - 1920s-50s NYC automat cafeteria scene
2. **theme-02-railroad-dining-cover.webp** - Luxury train dining car interior
3. **theme-03-victory-kitchen-cover.webp** - WWII home front kitchen
4. **theme-04-navy-mess-cover.webp** - Naval mess hall table setting
5. **theme-05-boston-cooking-cover.webp** - Victorian Boston Cooking School
6. **theme-06-southern-roots-cover.webp** - Southern family gathering table
7. **theme-07-scandinavian-cover.webp** - Nordic kitchen scene
8. **theme-08-german-american-cover.webp** - German-American gathering table
9. **theme-09-quick-weeknight-cover.webp** - 1950s suburban kitchen
10. **theme-10-sunday-suppers-cover.webp** - Sunday family supper table

**Heritage Collections (4):**
11. **presidential-pantry-cover.webp** - White House state dining room with presidential china
12. **literary-kitchen-cover.webp** - Cozy library with vintage cookbooks
13. **ancient-table-cover.webp** - Ancient Roman/Greek dining room
14. **american-foundation-cover.webp** - Colonial American hearth kitchen

## Specifications

- **Format:** WebP
- **Aspect Ratio:** 16:9 (1600×900) - perfect for collection covers
- **Quality:** 90
- **Style:** Heritage aesthetic matching each theme's era
- **No text, people, or modern elements**

## Custom Aspect Ratio

If you need different aspect ratios:

```bash
# 4:3 landscape (same as recipes)
python3 generate_theme_covers.py --aspect-ratio 4:3

# 3:2 format
python3 generate_theme_covers.py --aspect-ratio 3:2

# Square
python3 generate_theme_covers.py --aspect-ratio 1:1
```

## Generate Single Theme

```bash
python3 generate_theme_covers.py --theme theme-01-automat-classics
```

## Upload to Firebase

After generating covers, upload them:

```bash
python3 upload_theme_images_to_firebase.py
```

This uploads both recipe images AND theme covers to Firebase Storage.

## Output Files

After generation:

- **Images:** `theme-covers/*.webp` (10 files)
- **Manifest:** `theme-covers/theme_covers_manifest.json`
- **Firebase URLs:** `firebase_urls.json` (includes both recipes and covers)

## Complete Workflow

Generate everything (recipes + covers):

```bash
# 1. Preview all prompts
./run_image_gen.sh preview
./run_image_gen.sh preview-covers

# 2. Generate test recipe images
./run_image_gen.sh test

# 3. Generate all recipe images (130)
./run_image_gen.sh generate

# 4. Generate theme cover images (10)
./run_image_gen.sh generate-covers

# 5. Check status
./run_image_gen.sh status
./run_image_gen.sh status-covers

# 6. Upload everything to Firebase
python3 upload_theme_images_to_firebase.py
```

## Total Cost

- Recipe images: 130 × $0.003 = $0.39
- Theme covers: 14 × $0.003 = $0.04
- **Total: $0.43**

## Filename Format Updates

### Recipe Images (with theme prefix)
- Old: `recipe-id.webp`
- **New: `theme-01-recipe-id.webp`**

Examples:
- `theme-01-automat-classics-automat-chicken-pot-pie.webp`
- `theme-02-railroad-dining-oysters-rockefeller.webp`
- `theme-03-victory-kitchen-victory-meatloaf.webp`

### Theme Covers
- Format: `theme-XX-theme-name-cover.webp`

Examples:
- `theme-01-automat-classics-cover.webp`
- `theme-02-railroad-dining-cover.webp`

This naming makes it easy to organize and identify images by collection.
