# Theme Recipe Image Generator

Generate beautiful heritage-style images for all 186 theme recipes + 14 theme collection covers using Replicate FLUX API.

## Quick Start

### 1. Install Dependencies
```bash
cd /Users/matthanson/Heirloom/scripts/theme-image-gen
pip3 install -r requirements.txt
```

### 2. Set Your API Key
```bash
export REPLICATE_API_TOKEN="r8_your_key_here"
```

Get your API key from: https://replicate.com/account/api-tokens

### 3. Generate Images

```bash
# Preview prompts first (no cost, no API calls)
./run_image_gen.sh preview

# Generate 3 test images ($0.01)
./run_image_gen.sh test

# Check what's been generated
./run_image_gen.sh status

# Generate all 186 recipe images (~$0.56, ~22 minutes)
./run_image_gen.sh generate

# Generate 14 theme cover images (~$0.04, ~2 minutes)
./run_image_gen.sh generate-covers
```

### 4. Upload to Firebase

```bash
# Upload all images to Firebase Storage
python3 upload_theme_images_to_firebase.py
```

## Cost Breakdown

| Item | Count | Cost/Image | Total | Time |
|------|-------|------------|-------|------|
| Recipe Images | 186 | $0.003 | $0.56 | ~22 min |
| Theme Covers | 14 | $0.003 | $0.04 | ~2 min |
| **Total** | **200** | - | **$0.60** | **~24 min** |

**vs. DALL-E 3 Standard:** $8.00 (13× more expensive)
**vs. DALL-E 3 HD:** $16.00 (27× more expensive)

**Recommendation:** Replicate FLUX offers excellent quality at a fraction of the cost.

## Theme Collections

The generator handles all 14 theme collections:

**Original Themes (10):**
1. **Automat Classics** (14 recipes) - 1920s-1950s New York diner culture
2. **Golden Age of Rail** (12 recipes) - Luxury train dining cars
3. **Victory Kitchen** (14 recipes) - WWII home front cooking
4. **Navy Mess Hall** (14 recipes) - Naval tradition dining
5. **Boston Cooking School** (14 recipes) - Colonial and Victorian era
6. **Southern Roots** (14 recipes) - American South traditions
7. **Scandinavian Heritage** (12 recipes) - Nordic heritage cuisine
8. **German-American** (14 recipes) - Immigrant culinary heritage
9. **Quick Weeknight** (14 recipes) - Mid-century convenience
10. **Sunday Suppers** (12 recipes) - Family gathering traditions

**Heritage Collections (4):**
11. **Presidential Pantry** (14 recipes) - White House dining from Washington to Reagan
12. **Literary Kitchen** (14 recipes) - Victorian cookbook tradition
13. **Ancient Table** (12 recipes) - Classical Greco-Roman cuisine
14. **American Foundation** (12 recipes) - Colonial hearth cooking

**Total: 186 recipes across 14 themes**

## Image Specifications

All images are generated with:
- **Format:** WebP
- **Aspect Ratio:** 4:3 landscape (1200×900)
- **Quality:** 90
- **File Size:** 100-300 KB
- **Style:** Warm golden hour lighting, rustic wooden tables, home-cooked heritage aesthetic
- **Angle:** Slightly overhead (30-45°)
- **Colors:** Cream (#FDF6E3) and amber (#8A6B4B) palette

## File Structure

```
theme-image-gen/
├── generate_recipe_images.py    # Main generator script
├── run_image_gen.sh              # Convenience wrapper
├── upload_theme_images_to_firebase.py  # Firebase upload
├── requirements.txt              # Python dependencies
├── image_manifest.json           # Recipe-to-image mapping (generated)
├── firebase_urls.json            # Firebase URLs (generated)
├── images/                       # Generated images
│   ├── automat-classics-automat-mac-cheese.webp
│   ├── railroad-dining-oysters-rockefeller.webp
│   └── ... (186 total)
└── README.md                     # This file
```

## Advanced Usage

### Generate Specific Theme Only
```bash
python3 generate_recipe_images.py --theme theme-01-automat-classics
```

### Custom Rate Limiting
```bash
python3 generate_recipe_images.py --delay 3.0
```

### Resume After Interruption
The script automatically skips existing images:
```bash
./run_image_gen.sh generate  # Will resume where it left off
```

### Start from Specific Recipe
```bash
python3 generate_recipe_images.py --start-from 50 --limit 10
```

## Prompt Architecture

Each image uses a three-layer prompt:

### Layer 1: Base Heritage Style
- Recipe title
- Warm golden hour lighting
- Rustic wooden table
- 4:3 aspect ratio
- 30-45° overhead angle
- Home-cooked aesthetic
- Cream/amber palette

### Layer 2: Era-Specific Context
- Theme-specific styling (automat, railroad, victory kitchen, etc.)
- Historical source attribution
- Period-appropriate details

### Layer 3: Recipe Details
- Key ingredients (first 5)
- Visual context from recipe story
- Authentic presentation

### Consistency Mechanisms
- **Seed generation:** Consistent hash of recipe ID
- **Negative prompt:** Excludes modern elements, text, people
- **Fixed guidance:** 3.5 guidance scale
- **Inference steps:** 28 steps for quality

## Troubleshooting

### "Rate limited"
Increase delay between requests:
```bash
python3 generate_recipe_images.py --delay 3.0
```

### "API key invalid"
Check your environment variable:
```bash
echo $REPLICATE_API_TOKEN
```
Should start with `r8_`

### "No theme files found"
Ensure you're running from the correct directory and theme files exist at:
```
/Users/matthanson/Heirloom/themerecipes/theme-*.json
```

### "Firebase service account not found"
Ensure service account exists at:
```
/Users/matthanson/Heirloom/backend/firebase-service-account.json
```

### Images too dark/light
Adjust guidance scale in `generate_recipe_images.py`:
```python
"guidance_scale": 4.0  # Increase for more adherence to prompt
```

### Inconsistent style across themes
Verify ERA_STYLES dictionary includes all themes and base style is applied to all prompts.

## Firebase Integration

After uploading, images are available at:
```
https://firebasestorage.googleapis.com/v0/b/heirloom-ios-prod.appspot.com/o/theme-recipes%2F{recipe-id}.webp?alt=media
```

The `firebase_urls.json` file contains the mapping of all recipe IDs to their Firebase URLs.

### iOS Integration
Update your theme recipe JSON files or Firestore documents with the Firebase URLs from `firebase_urls.json`.

## Cost Tracking

Check current cost:
```bash
./run_image_gen.sh status
```

This shows:
- Images generated
- Images remaining
- Cost so far
- Estimated remaining cost

## Support

For issues or questions:
1. Check this README's troubleshooting section
2. Review the generated prompts with `./run_image_gen.sh preview`
3. Test with 3 images first: `./run_image_gen.sh test`
4. Check the Replicate dashboard for API usage

## License

Part of the Heirloom iOS app project.
