# New Heritage Themes Added (4 Collections, 52 Recipes)

## Overview

Added 4 heritage collections with 52 new recipes from `/Users/matthanson/Heirloom/themerecipes/newthemes/`

## New Collections

### 11. Presidential Pantry (14 recipes)
- **Theme ID:** `presidential-pantry`
- **Era:** 1700s-1900s
- **Description:** Recipes from the White House kitchens spanning American presidents from Washington to Reagan
- **Style:** Colonial American formal entertaining, 18th-century Mount Vernon style, presidential dining aesthetic

**Sample Recipes:**
- Martha Washington's Great Cake
- Thomas Jefferson's Ice Cream
- Presidential state dinner dishes

### 12. Literary Kitchen (14 recipes)
- **Theme ID:** `literary-kitchen`
- **Era:** Victorian-Edwardian
- **Description:** Victorian cookbook tradition and literary-inspired dishes
- **Style:** Mrs. Beeton cookbook aesthetic, ornate china, Edwardian dining, classic literature inspiration

**Sample Recipes:**
- Victorian tea cakes
- Dickensian-era dishes
- Classic cookbook recipes

### 13. Ancient Table (12 recipes)
- **Theme ID:** `ancient-table`
- **Era:** Ancient Greece & Rome
- **Description:** Classical Greco-Roman cuisine with archaeological authenticity
- **Style:** Classical antiquity, terracotta amphoras, olive branches, museum-quality presentation

**Sample Recipes:**
- Ancient Roman dishes
- Greek classical cuisine
- Archaeological recipe recreations

### 14. American Foundation (12 recipes)
- **Theme ID:** `american-foundation`
- **Era:** 1700s-1800s
- **Description:** Colonial hearth cooking and founding-era American cuisine
- **Style:** Cast iron skillets, rough-hewn tables, rustic Americana, honest farm-to-table

**Sample Recipes:**
- Colonial hearth dishes
- Founding fathers' era cuisine
- Early American heritage recipes

## Updated Totals

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Themes | 10 | 14 | +4 |
| Recipes | 134 | 186 | +52 |
| Recipe Image Cost | $0.40 | $0.56 | +$0.16 |
| Total Cost (with covers) | $0.44 | $0.60 | +$0.16 |

## File Naming Convention

New recipe images use the theme ID prefix:

```
presidential-pantry-{recipe-id}.webp
literary-kitchen-{recipe-id}.webp
ancient-table-{recipe-id}.webp
american-foundation-{recipe-id}.webp
```

Examples:
- `presidential-pantry-presidential-001.webp` (Martha Washington's Great Cake)
- `literary-kitchen-literary-001.webp` (Victorian tea cake)
- `ancient-table-ancient-001.webp` (Roman dish)
- `american-foundation-foundation-001.webp` (Colonial hearth dish)

## Theme Cover Images

Each new collection also has a cover image:

- `presidential-pantry-cover.webp` - White House state dining room
- `literary-kitchen-cover.webp` - Cozy library with vintage cookbooks
- `ancient-table-cover.webp` - Classical Greco-Roman dining room
- `american-foundation-cover.webp` - Colonial hearth kitchen

## Generation Status

To generate images for all themes (including new ones):

```bash
cd /Users/matthanson/Heirloom/scripts/theme-image-gen

# Check current status
./run_image_gen.sh status

# Generate all recipe images (186 total)
./run_image_gen.sh generate

# Generate all cover images (14 total)
./run_image_gen.sh generate-covers
```

## Integration Notes

The generation script automatically detects and processes recipes from both:
- `/Users/matthanson/Heirloom/themerecipes/theme-*.json` (original 10 themes)
- `/Users/matthanson/Heirloom/themerecipes/newthemes/theme-*.json` (new 4 themes)

No manual configuration needed - just run the generation commands as usual.

## Firebase Upload

The upload script handles all 186 recipe images + 14 cover images:

```bash
python3 upload_theme_images_to_firebase.py
```

All images will be uploaded to:
- `gs://heirloom-ios-prod.appspot.com/theme-recipes/{theme-id}-{recipe-id}.webp`

## Summary

✓ 4 new heritage collections added
✓ 52 new recipes ready for image generation
✓ Era-appropriate styling configured
✓ Cover images defined for each collection
✓ Total: 186 recipes + 14 covers = 200 images for $0.60
