# Heirloom Sticker Generator - Phase 1

Python script to automatically generate all 20 Phase 1 stickers using DALL-E 3.

## Features

✅ Generates all 20 priority stickers automatically  
✅ Progress bar with real-time cost tracking  
✅ Organizes stickers by category  
✅ Creates metadata JSON file  
✅ Error handling and retry logic  
✅ Estimated cost: **$0.80** (20 stickers × $0.04)  

## Installation

### 1. Install Python dependencies

```bash
pip install openai tqdm requests
```

Or use the requirements file:

```bash
pip install -r requirements.txt
```

### 2. Get your OpenAI API key

1. Go to https://platform.openai.com/api-keys
2. Create a new API key
3. Copy it (starts with `sk-...`)

## Usage

### Quick Start

```bash
python generate_stickers.py
```

The script will prompt you for:
- Your OpenAI API key (or use environment variable)
- Output directory (defaults to `heirloom_stickers`)
- Confirmation before spending money

### Using Environment Variable

```bash
export OPENAI_API_KEY='sk-your-key-here'
python generate_stickers.py
```

### Sample Run

```
============================================================
🍳 HEIRLOOM STICKER GENERATOR - PHASE 1
============================================================

🔑 OpenAI API Key: [detected from environment]

Output directory [heirloom_stickers]: 

💰 Estimated cost: $0.80 (20 stickers × $0.04)

Proceed with generation? [Y/n]: y

🎨 Heirloom Sticker Generator
📁 Output directory: /path/to/heirloom_stickers
🖼️  Generating 20 stickers...

Generating Tomato: 100%|██████████| 20/20 [02:15<00:00, ✓: 20, ✗: 0, cost: $0.80]

============================================================
✅ Successfully generated: 20/20 stickers
💰 Total cost: $0.80
📁 Saved to: /path/to/heirloom_stickers
============================================================

📂 Directory structure:
   └── food/ (6 files)
   └── tools/ (4 files)
   └── badges/ (4 files)
   └── emotions/ (4 files)
   └── decorative/ (2 files)

📄 Metadata saved to: /path/to/heirloom_stickers/metadata.json

✨ All done! Your stickers are ready to use.
```

## Output Structure

```
heirloom_stickers/
├── food/
│   ├── sticker_food_tomato.png
│   ├── sticker_food_garlic.png
│   ├── sticker_food_lemon.png
│   ├── sticker_food_egg.png
│   ├── sticker_food_pie.png
│   └── sticker_food_cookie.png
├── tools/
│   ├── sticker_tools_woodenspoon.png
│   ├── sticker_tools_whisk.png
│   ├── sticker_tools_rollingpin.png
│   └── sticker_tools_knife.png
├── badges/
│   ├── sticker_badge_familyrecipe.png
│   ├── sticker_badge_tested.png
│   ├── sticker_badge_madewithlove.png
│   └── sticker_badge_fivestars.png
├── emotions/
│   ├── sticker_emotion_heart.png
│   ├── sticker_emotion_star.png
│   ├── sticker_emotion_coffeestain.png
│   └── sticker_emotion_fingerprint.png
├── decorative/
│   ├── sticker_decorative_flourish.png
│   └── sticker_decorative_banner.png
└── metadata.json
```

## What's Generated

### Phase 1 (20 Stickers)

**Food & Ingredients (6)**
- Tomato, Garlic, Lemon, Egg, Pie Slice, Cookie

**Kitchen Tools (4)**
- Wooden Spoon, Whisk, Rolling Pin, Chef's Knife

**Badges & Labels (4)**
- Family Recipe, Tested & Approved, Made With Love, Five Stars

**Emotions & Memories (4)**
- Heart, Star, Coffee Stain, Fingerprint

**Decorative Elements (2)**
- Corner Flourish, Banner Ribbon

## Post-Processing

After generation, you'll want to:

1. **Remove backgrounds** (if needed)
   - Use remove.bg, Photoshop, or Photopea
   - Export as PNG with alpha channel

2. **Vectorize for SVG**
   - Import PNG to Adobe Illustrator
   - Use Image Trace (3-6 colors)
   - Export as SVG

3. **Color correction**
   - Ensure colors match brand palette:
     - Tomato Red: #E74C3C
     - Amber Gold: #F39C12
     - Sage Green: #8BA888
     - Burnt Sienna: #8B4513

4. **Export multiple sizes**
   - 512px (1x), 1024px (2x), 1536px (3x)

## Troubleshooting

### Rate Limits
If you hit rate limits:
```python
generator.generate_all(PHASE_1_STICKERS, delay=2.0)  # Increase delay
```

### API Key Issues
Make sure your key:
- Starts with `sk-`
- Has billing enabled
- Has sufficient credits

### Background Not Transparent
DALL-E 3 generates on white backgrounds. You'll need to remove backgrounds in post-processing using:
- remove.bg (fastest)
- Photoshop Magic Wand
- Photopea (free Photoshop alternative)

### Inconsistent Style
If some stickers don't match the style:
- Regenerate individual stickers
- Adjust prompts in the script
- Use Midjourney for more consistent results

## Cost Breakdown

| Item | Cost |
|------|------|
| 20 stickers @ $0.04 each | $0.80 |
| **Total** | **$0.80** |

Plus post-processing (if outsourced):
- Background removal: ~$1-3/image
- Vectorization: ~$5-10/image

## Next Steps

### Phase 2 (Next 20 Stickers)
Run the Phase 2 script for the expanded set:
```bash
python generate_stickers_phase2.py
```

### Phase 3 (Final 20 Stickers)
Complete the full 60-sticker library:
```bash
python generate_stickers_phase3.py
```

## API Documentation

- [OpenAI DALL-E 3 Docs](https://platform.openai.com/docs/guides/images)
- [OpenAI API Keys](https://platform.openai.com/api-keys)
- [OpenAI Pricing](https://openai.com/pricing)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review OpenAI's documentation
3. Check your API key and billing status

## License

This script is part of the Heirloom recipe app project.
