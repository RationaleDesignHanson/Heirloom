# Getting Started with Sticker Generation

Step-by-step guide to creating all 60 stickers for Heirloom.

## Phase 1: Essential Stickers (20 items - Launch MVP)

Start with these 20 most important stickers:

### Food (6)
1. Tomato (whole)
2. Garlic bulb
3. Onion
4. Herb sprig (basil/parsley)
5. Lemon (whole)
6. Olive oil bottle

### Tools (4)
1. Whisk
2. Wooden spoon
3. Knife
4. Rolling pin

### Badges (4)
1. "Family Favorite" ribbon
2. "Quick & Easy" badge
3. "Tried & True" star
4. "Grandma's Recipe" heart

### Annotations (4)
1. Star burst
2. Arrow (pointing right)
3. Checkmark
4. Heart

### Seasonal (2)
1. Heart (Valentine's)
2. Flower

---

## Recommended Approach: AI Generation

### Why AI?
- ✅ Fastest (generate 60 stickers in 1-2 days)
- ✅ Most affordable ($50-200)
- ✅ Easy to iterate and refine
- ✅ Consistent style across all stickers

### Best Tools

**1. Midjourney** (Recommended)
- Best for illustration style
- $30/month Pro plan
- Generate in batches
- High quality SVG-ready outputs

**2. DALL-E 3** (via ChatGPT Plus)
- $20/month ChatGPT Plus
- Good for quick iterations
- Built into ChatGPT interface

**3. Ideogram** (Free tier available)
- Good alternative
- Free tier: 100 images/day
- Good for text in badges

---

## Step-by-Step: Midjourney Method

### 1. Subscribe to Midjourney
1. Go to [midjourney.com](https://midjourney.com)
2. Subscribe to Basic plan ($10/mo) or Standard ($30/mo)
3. Join their Discord server

### 2. Generate Food Stickers (Example)

In Midjourney Discord, use this prompt format:

```
/imagine prompt: hand-drawn illustration of a whole red tomato,
simple line art style, warm colors, whimsical and playful,
isolated on white background, sticker design, flat colors,
no shadows, vector-style, --ar 1:1 --v 6
```

**Generate all 6 Phase 1 food items:**

```
Tomato: /imagine hand-drawn red tomato, simple line art,
whimsical sticker design, isolated white background, warm colors,
flat illustration --ar 1:1 --v 6

Garlic: /imagine hand-drawn garlic bulb with cloves, simple line art,
whimsical sticker, white background, warm cream and purple tones,
flat colors --ar 1:1 --v 6

Onion: /imagine hand-drawn yellow onion, simple line art,
cute illustration, sticker design, white background,
flat colors --ar 1:1 --v 6

Herbs: /imagine hand-drawn basil sprig with leaves, simple line art,
botanical illustration style, sticker, white background,
sage green colors --ar 1:1 --v 6

Lemon: /imagine hand-drawn whole yellow lemon, simple line art,
cheerful illustration, sticker design, white background,
bright yellow --ar 1:1 --v 6

Olive Oil: /imagine hand-drawn olive oil bottle with label,
simple line art, whimsical sticker, white background,
amber and green tones --ar 1:1 --v 6
```

### 3. Generate Kitchen Tools

```
Whisk: /imagine hand-drawn wire whisk kitchen tool,
simple line art, cute illustration, sticker design,
white background, gray metal --ar 1:1 --v 6

Wooden Spoon: /imagine hand-drawn wooden cooking spoon,
simple line art, warm brown tones, whimsical sticker,
white background --ar 1:1 --v 6

Knife: /imagine hand-drawn chef's knife, simple line art,
clean illustration, sticker design, white background,
steel blade wooden handle --ar 1:1 --v 6

Rolling Pin: /imagine hand-drawn wooden rolling pin with handles,
simple line art, vintage style, sticker, white background,
warm wood tones --ar 1:1 --v 6
```

### 4. Generate Badges (With Text)

```
Family Favorite: /imagine hand-drawn ribbon badge with text
"FAMILY FAVORITE", vintage style, warm red and cream colors,
simple line art, sticker design, white background --ar 1:1 --v 6

Quick & Easy: /imagine hand-drawn circular badge with text
"QUICK & EASY", retro kitchen style, amber and sage colors,
simple sticker design, white background --ar 1:1 --v 6

Tried & True: /imagine hand-drawn star burst badge with text
"TRIED & TRUE", classic cookbook style, tomato red and cream,
sticker design, white background --ar 1:1 --v 6

Grandma's Recipe: /imagine hand-drawn heart badge with text
"GRANDMA'S RECIPE", vintage handwritten style, warm colors,
simple sticker, white background --ar 1:1 --v 6
```

### 5. Download and Process

1. In Discord, click each generated image
2. Click **"U1"**, **"U2"**, **"U3"**, or **"U4"** to upscale your favorite
3. Right-click the upscaled image → **Save Image**
4. Save to: `/Users/matthanson/Heirloom/stickergenerator/raw/`
5. Name files: `food-tomato.png`, `tool-whisk.png`, etc.

---

## Step-by-Step: Processing & Export

### 1. Organize Raw Files

```bash
cd /Users/matthanson/Heirloom/stickergenerator
mkdir -p raw processed exports

# Place downloaded Midjourney PNGs in raw/
```

### 2. Convert to SVG (if needed)

If you want vector SVGs from PNG:

```bash
# Option A: Use vectorizer.ai (online tool)
# Upload PNGs at https://vectorizer.ai
# Download SVGs

# Option B: Use Inkscape (command line)
brew install inkscape
for file in raw/*.png; do
  inkscape "$file" --export-type=svg --export-filename="processed/$(basename ${file%.png}).svg"
done
```

### 3. Optimize SVGs

```bash
# Install SVGO
npm install -g svgo

# Optimize all SVGs
svgo -f processed/ -o processed/ --multipass
```

### 4. Generate PNG Exports (@1x/2x/3x)

We'll create a script for this in the next step.

---

## Alternative: Commission a Designer

If you prefer human-created stickers:

### Where to Hire

**Fiverr** (Cheapest)
- Search: "hand-drawn sticker pack"
- Price: $50-200 for 20 stickers
- Timeline: 3-7 days

**Upwork** (Mid-range)
- Search: "illustration sticker design"
- Price: $300-800 for 60 stickers
- Timeline: 1-2 weeks

**Dribbble** (Premium)
- Find illustrators with similar style
- Price: $1,500-3,000 for custom set
- Timeline: 2-4 weeks

### Design Brief

Use the file `design-brief.md` in this folder to send to designers.

---

## Next Steps

1. **Choose your method** (AI/Designer/DIY)
2. **Generate Phase 1** (20 stickers)
3. **Process files** (optimize, convert)
4. **Export PNGs** (1x/2x/3x)
5. **Import to Xcode** (Asset catalog)
6. **Test in app**

Then repeat for Phase 2 (20 more) and Phase 3 (final 20).

---

## Need Help?

- Stuck on Midjourney prompts? See `ai-prompts/` folder
- Need processing scripts? Run `setup-scripts.sh`
- Questions about style? Review `style-guide.md`
