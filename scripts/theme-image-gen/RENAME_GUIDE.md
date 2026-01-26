# Renaming Existing Images Guide

## Problem

The naming convention was updated to include theme prefixes in filenames:

**Old format:** `recipe-id.webp`
**New format:** `theme-id-recipe-id.webp`

Examples:
- Old: `automat-mac-cheese.webp`
- New: `automat-classics-automat-mac-cheese.webp`

Your existing 134 images use the old format, so the script doesn't recognize them as already generated and will try to regenerate all 186 images.

## Solution

Run the rename script to convert existing images to the new naming convention:

```bash
cd /Users/matthanson/Heirloom/scripts/theme-image-gen

# Rename existing images
./run_image_gen.sh rename

# Or run the Python script directly
python3 rename_existing_images.py
```

## What It Does

The script will:
1. Load all theme files to build a recipe-to-theme mapping
2. Scan the `images/` directory for existing images
3. Check if each image already has a theme prefix (by matching against known theme IDs)
4. Rename images that don't have a prefix: `recipe-id.webp` → `theme-id-recipe-id.webp`
5. Skip images that already have the correct prefix
6. Report which images were renamed, skipped, or couldn't be found

## Expected Output

```
Renaming existing images to include theme prefix...
================================================================================
Loaded 186 recipe mappings from theme files
Found 14 theme IDs: american-foundation, ancient-table, automat-classics, ...

Found 134 existing images

  ✓ Renamed: automat-mac-cheese.webp -> automat-classics-automat-mac-cheese.webp
  ✓ Renamed: automat-baked-beans.webp -> automat-classics-automat-baked-beans.webp
  ...
  ✓ Already prefixed: automat-classics-some-recipe.webp
  ...

================================================================================
Summary:
  Total images found: 134
  Already prefixed: 0
  Successfully renamed: 134
  Recipe ID not found: 0
================================================================================

✓ Rename complete! Images now match the new naming convention.
  Run './run_image_gen.sh generate' to generate only the missing images.
```

## After Renaming

Once renamed, check the status:

```bash
./run_image_gen.sh status
```

Should show:
```
Generated: 134 / 186
Remaining: 52
```

Then generate only the missing 52 heritage collection images:

```bash
./run_image_gen.sh generate
```

This will:
- Skip the 134 renamed images (already exist with new naming)
- Generate only the 52 new heritage collection images
- Cost: 52 × $0.003 = $0.16
- Time: ~6 minutes

## Safety

The script is safe to run multiple times:
- Won't rename images that already have theme prefixes
- Won't overwrite existing files
- Reports what it's doing before making changes

## Troubleshooting

### "Recipe ID not found in themes"

If some recipe IDs can't be found, it means:
- The recipe was removed from the theme files
- The recipe ID changed
- The image file doesn't match any recipe

These images will be skipped and reported in the summary.

### Images Already Have Theme Prefix

If all images already have the theme prefix, the script will report:
```
✓ All images already use the new naming convention.
```

No changes needed - proceed with generating new images.

## Manual Verification

After renaming, you can verify the new naming:

```bash
ls images/ | head -20
```

Should see filenames like:
```
automat-classics-automat-apple-pie.webp
automat-classics-automat-baked-beans.webp
railroad-dining-oysters-rockefeller.webp
victory-kitchen-victory-meatloaf.webp
...
```

Each filename starts with the theme ID, followed by the recipe ID.
