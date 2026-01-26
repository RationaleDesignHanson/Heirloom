# Theme Recipe Image Generation - Setup Complete ✓

## What Was Created

All files have been successfully created in `/Users/matthanson/Heirloom/scripts/theme-image-gen/`:

- ✓ `generate_recipe_images.py` - Main FLUX image generator
- ✓ `run_image_gen.sh` - Convenience wrapper script
- ✓ `upload_theme_images_to_firebase.py` - Firebase upload script
- ✓ `requirements.txt` - Python dependencies
- ✓ `README.md` - Full documentation
- ✓ `images/` - Output directory (empty, ready for generated images)

## Next Steps

### 1. Install Dependencies (Required)

```bash
cd /Users/matthanson/Heirloom/scripts/theme-image-gen
pip3 install -r requirements.txt
```

This installs:
- `replicate` - Replicate FLUX API client
- `requests` - HTTP library for image downloads
- `Pillow` - Image processing (if needed)
- `firebase-admin` - Firebase upload functionality

### 2. Set Your Replicate API Key

```bash
export REPLICATE_API_TOKEN="r8_your_key_here"
```

**Important:** Replace `r8_your_key_here` with your actual Replicate API token.

To get your token:
1. Go to https://replicate.com
2. Sign up or log in
3. Navigate to Account Settings → API Tokens
4. Create a new token or copy your existing one

### 3. Preview Prompts (Recommended First Step)

Before generating any images, preview the prompts to ensure they look good:

```bash
./run_image_gen.sh preview
```

This shows all 130 recipe prompts without making any API calls (no cost).

### 4. Generate Test Images

Generate 3 test images to validate quality and cost:

```bash
./run_image_gen.sh test
```

Cost: ~$0.01 (3 images × $0.003)
Time: ~30 seconds

Check the `images/` directory to review the generated images.

### 5. Generate All Images

Once you're happy with the test results:

```bash
./run_image_gen.sh generate
```

Cost: ~$0.39 (130 images × $0.003)
Time: ~15 minutes

The script will:
- Skip any already-generated images (resume capability)
- Rate limit requests (2 second delay between images)
- Show progress for each image
- Generate a manifest file mapping recipe IDs to images

### 6. Upload to Firebase

After all images are generated:

```bash
python3 upload_theme_images_to_firebase.py
```

This will:
- Upload all 130 images to Firebase Storage at `theme-recipes/{recipe-id}.webp`
- Generate public URLs for each image
- Create `firebase_urls.json` with the URL mapping
- Update `image_manifest.json` with Firebase URLs

## Verification

### Check Status Anytime

```bash
./run_image_gen.sh status
```

Shows:
- Images generated / total
- Images remaining
- Cost so far
- Estimated remaining cost

### View Generated Images

```bash
open images/
```

This opens the images directory in Finder.

## Recipe Breakdown

Total: **186 recipes across 14 themes**

**Original Themes (10):**
- Theme 01: Automat Classics (14 recipes)
- Theme 02: Golden Age of Rail (12 recipes)
- Theme 03: Victory Kitchen (14 recipes)
- Theme 04: Navy Mess Hall (14 recipes)
- Theme 05: Boston Cooking School (14 recipes)
- Theme 06: Southern Roots (14 recipes)
- Theme 07: Scandinavian Heritage (12 recipes)
- Theme 08: German-American (14 recipes)
- Theme 09: Quick Weeknight (14 recipes)
- Theme 10: Sunday Suppers (12 recipes)

**Heritage Collections (4):**
- Theme 11: Presidential Pantry (14 recipes)
- Theme 12: Literary Kitchen (14 recipes)
- Theme 13: Ancient Table (12 recipes)
- Theme 14: American Foundation (12 recipes)

## Cost Breakdown

| Stage | Images | Cost |
|-------|--------|------|
| Test | 3 | $0.01 |
| Recipe images | 186 | $0.56 |
| Theme covers | 14 | $0.04 |
| **Total** | **200** | **$0.60** |

**vs. DALL-E 3:** $8.00 (13× more expensive)

## Troubleshooting

### "REPLICATE_API_TOKEN environment variable not set"

Run:
```bash
export REPLICATE_API_TOKEN="your_token_here"
```

To make it permanent, add to your `~/.zshrc` or `~/.bash_profile`:
```bash
echo 'export REPLICATE_API_TOKEN="your_token_here"' >> ~/.zshrc
source ~/.zshrc
```

### "No module named 'replicate'"

Install dependencies:
```bash
pip3 install -r requirements.txt
```

### "No theme files found"

Verify theme files exist:
```bash
ls -l ../../themerecipes/theme-*.json
```

Should show 10 theme files.

## Help

For full documentation, see `README.md` in this directory.

For usage help:
```bash
./run_image_gen.sh
```

## Ready to Go!

You're all set. Start with:

```bash
# 1. Install dependencies
pip3 install -r requirements.txt

# 2. Set API key
export REPLICATE_API_TOKEN="r8_your_key_here"

# 3. Preview prompts
./run_image_gen.sh preview

# 4. Generate test images
./run_image_gen.sh test

# 5. Generate all images
./run_image_gen.sh generate
```
