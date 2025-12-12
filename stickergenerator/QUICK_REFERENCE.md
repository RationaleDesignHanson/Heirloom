# 🍳 Heirloom Sticker Generator - Quick Reference

## 🚀 Quick Start (3 commands)

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Set your API key
export OPENAI_API_KEY='sk-your-key-here'

# 3. Generate stickers
python3 generate_stickers.py
```

## 💰 Cost & Time

- **Cost:** $0.80 (20 stickers × $0.04 each)
- **Time:** 3-5 minutes
- **Output:** 1024×1024px PNG files

## 📋 What Gets Generated

| Category | Count | Examples |
|----------|-------|----------|
| Food & Ingredients | 6 | Tomato, Garlic, Lemon, Egg, Pie, Cookie |
| Kitchen Tools | 4 | Wooden Spoon, Whisk, Rolling Pin, Knife |
| Badges & Labels | 4 | Family Recipe, Tested & Approved, Made With Love, Five Stars |
| Emotions & Memories | 4 | Heart, Star, Coffee Stain, Fingerprint |
| Decorative Elements | 2 | Corner Flourish, Banner Ribbon |
| **TOTAL** | **20** | |

## 📁 Output Structure

```
heirloom_stickers/
├── food/           (6 stickers)
├── tools/          (4 stickers)
├── badges/         (4 stickers)
├── emotions/       (4 stickers)
├── decorative/     (2 stickers)
└── metadata.json
```

## 🔧 Troubleshooting

| Problem | Solution |
|---------|----------|
| **No API key** | Get one at https://platform.openai.com/api-keys |
| **Rate limit hit** | Wait 1 minute or increase delay in script |
| **White backgrounds** | Use remove.bg or Photoshop to remove |
| **Style inconsistent** | Regenerate specific stickers or use Midjourney instead |

## 🎨 Post-Processing Checklist

After generation:

- [ ] Remove white backgrounds (remove.bg)
- [ ] Vectorize in Illustrator (Image Trace → 3-6 colors)
- [ ] Correct colors to brand palette
- [ ] Export as SVG
- [ ] Export PNG at @1x, @2x, @3x sizes

## 🎯 Brand Colors

```
Tomato Red:    #E74C3C
Amber Gold:    #F39C12
Sage Green:    #8BA888
Burnt Sienna:  #8B4513
Cream:         #F5F5DC
```

## 📞 Support

- [OpenAI DALL-E Docs](https://platform.openai.com/docs/guides/images)
- [OpenAI Pricing](https://openai.com/pricing)
- [Get API Key](https://platform.openai.com/api-keys)

---

**Next:** Generate Phase 2 (20 more stickers) for $0.80 additional
