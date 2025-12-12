# Heirloom Sticker Library Specifications

**Version:** 1.0
**Last Updated:** December 8, 2024
**Total Stickers:** 60 (organized in 8 categories)

## Overview

The sticker library enables users to personalize recipe cards with warm, nostalgic illustrations that feel hand-drawn and authentic. Stickers should feel like they could have been doodled in the margins of a grandmother's cookbook.

### Design Principles

**Visual Style:**
- **Hand-Drawn Aesthetic:** Slightly imperfect lines, organic shapes
- **Warm Color Palette:** Cream, Tomato Red, Amber, Sage Green, Burnt Sienna
- **Nostalgic Feel:** Mid-century illustration style, vintage cookbook vibes
- **Transparent Backgrounds:** PNG with alpha channel for layering
- **Scalable:** Vector-based (SVG) for clean rendering at any size
- **Readable:** Clear silhouettes that work at small sizes (24px minimum)

**Technical Specifications:**
- **Format:** SVG (source) + PNG @1x, @2x, @3x (rendered assets)
- **Artboard Size:** 512×512px (square) for most, up to 1024×512 for wide stickers
- **Line Weight:** 3-4px stroke for primary shapes
- **Colors:** Maximum 4 colors per sticker (prioritize readability)
- **Drop Shadow:** Optional subtle shadow for depth (8px blur, 20% opacity)
- **Naming Convention:** `sticker_[category]_[name]_[variant].svg`
  - Example: `sticker_food_tomato_red.svg`, `sticker_badge_homemade_blue.svg`

---

## Category 1: Food & Ingredients (15 Stickers)

Illustrated ingredients and dishes that celebrate cooking.

### Vegetables & Fruits
1. **Tomato** - Bright red heirloom tomato with green stem
2. **Garlic Bulb** - Whole garlic with a few cloves separated
3. **Lemon Slice** - Cross-section showing segments
4. **Carrot** - Orange carrot with leafy greens
5. **Mushroom** - Classic button mushroom, side view

### Proteins & Dairy
6. **Egg** - Cracked egg with yolk visible
7. **Butter** - Stick of butter with wrapper partially peeled
8. **Cheese Wedge** - Triangle of Swiss or cheddar with holes

### Baking Essentials
9. **Flour Sack** - Vintage flour sack with "FLOUR" label
10. **Sugar Bowl** - Ceramic bowl with spoon
11. **Chocolate Bar** - Partially unwrapped chocolate bar with squares

### Prepared Foods
12. **Pie Slice** - Lattice-top pie slice with steam
13. **Bread Loaf** - Artisan loaf with score marks
14. **Cookie** - Chocolate chip cookie with bite taken
15. **Herb Sprig** - Rosemary or thyme sprig tied with twine

---

## Category 2: Kitchen Tools (10 Stickers)

Essential utensils and appliances with vintage charm.

1. **Wooden Spoon** - Well-worn wooden spoon with grain texture
2. **Whisk** - Wire whisk, slightly bent from use
3. **Rolling Pin** - Classic wooden rolling pin with handles
4. **Chef's Knife** - Professional knife with bolster and rivets
5. **Mixing Bowl** - Ceramic mixing bowl, side view
6. **Measuring Cups** - Set of 4 nested cups
7. **Cast Iron Skillet** - Black cast iron pan with handle
8. **Dutch Oven** - Enameled pot with lid
9. **Stand Mixer** - Vintage stand mixer (think KitchenAid mid-century)
10. **Apron** - Folded apron with pocket and ties

---

## Category 3: Badges & Labels (12 Stickers)

Stamp-style badges for highlighting recipe attributes.

### Recipe Type
1. **"Family Recipe"** - Circular badge with serif font
2. **"Grandma's Secret"** - Banner with script font
3. **"Tested & Approved"** - Checkmark seal
4. **"Sunday Dinner"** - Oval badge with fork & knife icons

### Dietary & Occasion
5. **"Vegetarian"** - Green badge with leaf icon
6. **"Gluten-Free"** - Wheat icon with slash-through
7. **"Holiday Favorite"** - Red/green festive badge
8. **"Quick & Easy"** - Clock icon badge

### Achievement
9. **"⭐⭐⭐⭐⭐ Five Stars"** - 5-star rating stamp
10. **"Award Winner"** - Blue ribbon rosette
11. **"Made With Love"** - Heart-shaped badge
12. **"Homemade"** - Handwritten-style text badge

---

## Category 4: Seasonal & Holiday (8 Stickers)

Celebrate cooking throughout the year.

### Spring & Summer
1. **Cherry Blossoms** - Small branch with pink flowers
2. **Strawberry** - Red strawberry with seeds and leaves
3. **Sunflower** - Bright yellow sunflower head

### Fall & Winter
4. **Pumpkin** - Orange pumpkin with stem and vines
5. **Autumn Leaves** - 3 colorful fall leaves (red, orange, yellow)
6. **Snowflake** - Delicate 6-point snowflake
7. **Holly Sprig** - Green leaves with red berries
8. **Pinecone** - Detailed pinecone with scales

---

## Category 5: Handwritten Annotations (6 Stickers)

Pre-made handwritten notes that feel personal.

1. **"Mom's Original"** - Casual script in dark blue ink
2. **"Add More Garlic!"** - Playful note with arrow
3. **"Best Ever"** - Underlined emphatic text
4. **"Try This!"** - Handwritten with exclamation
5. **"Double the Recipe"** - Practical note in red
6. **"From Italy 1952"** - Historical provenance note

**Note:** These should feel like actual pen-on-paper annotations with slight ink bleed and character variation.

---

## Category 6: Decorative Elements (5 Stickers)

Ornamental flourishes for visual interest.

1. **Corner Flourish** - Vintage scroll design for card corners
2. **Divider Line** - Decorative separator with small icon in center
3. **Banner Ribbon** - Blank ribbon for custom text
4. **Recipe Box Border** - Ornate rectangular frame
5. **Laurel Wreath** - Simple laurel branch arc

---

## Category 7: Emotions & Memories (6 Stickers)

Capture the feelings associated with recipes.

1. **Heart** - Hand-drawn heart outline, slightly asymmetrical
2. **Star** - Five-point star with slight wobble
3. **Smiling Face** - Simple emoji-style happy face
4. **Coffee Stain Ring** - Circular stain mark (realistic texture)
5. **Fingerprint** - Smudged fingerprint (as if from floury hands)
6. **Lipstick Kiss** - Red lipstick mark (playful, Grandma's kiss)

**Note:** Coffee stain, fingerprint, and kiss marks should look realistic but not dirty—celebrating the "love marks" of cooking.

---

## Category 8: Numbers & Time (8 Stickers)

Functional stickers for annotations.

### Time Indicators
1. **Clock Face (15 min)** - Simple clock showing 15 minutes
2. **Clock Face (30 min)** - Clock showing 30 minutes
3. **Clock Face (1 hour)** - Clock showing 1 hour
4. **Timer Icon** - Hourglass or kitchen timer illustration

### Servings & Portions
5. **"Serves 4"** - Circular badge with 4 people icons
6. **"Serves 8"** - Badge with 8 people icons
7. **"Feeds a Crowd"** - Badge with 12+ people icons
8. **Portion Sizes** - Plate illustration with sizing indicators

---

## Implementation Plan

### Phase 1: Core Set (20 Stickers)
**Priority:** Launch essentials
**Timeline:** Weeks 5-7 (during Phase 2 development)

**Included:**
- Category 1: Tomato, Garlic, Lemon, Egg, Pie Slice, Cookie
- Category 2: Wooden Spoon, Whisk, Rolling Pin, Chef's Knife
- Category 3: "Family Recipe", "Tested & Approved", "Made With Love", "⭐⭐⭐⭐⭐"
- Category 6: Heart, Star, Coffee Stain, Fingerprint
- Category 7: Corner Flourish, Banner Ribbon

### Phase 2: Expanded Set (+20 Stickers)
**Priority:** Add variety for premium users
**Timeline:** Weeks 8-10

**Included:**
- Category 1: All remaining food items
- Category 2: All remaining kitchen tools
- Category 4: All seasonal items

### Phase 3: Complete Set (+20 Stickers)
**Priority:** Full library for power users
**Timeline:** Weeks 11-13

**Included:**
- Category 5: All handwritten annotations
- Category 7: All decorative elements
- Category 8: All numbers & time stickers

---

## Design Deliverables

### For Illustrator/Designer

**Package 1: Style Guide**
- Color palette swatches (Tomato, Amber, Sage, Cream, Burnt Sienna)
- Typography specimens (for badge text)
- Line weight and stroke examples
- Shadow and texture guidelines
- 3 completed example stickers showing style

**Package 2: Asset List**
- Spreadsheet with all 60 stickers
- Columns: Category, Name, Description, Priority (P0/P1/P2), Dimensions
- Reference images for each sticker concept

**Package 3: Technical Specs**
- Artboard templates (512×512px, 1024×512px)
- Export settings for SVG and PNG
- Naming conventions document
- Folder structure for delivery

### Delivery Format

```
heirloom-stickers/
├── svg/
│   ├── food/
│   │   ├── sticker_food_tomato.svg
│   │   ├── sticker_food_garlic.svg
│   │   └── ...
│   ├── tools/
│   │   ├── sticker_tools_woodenspoon.svg
│   │   └── ...
│   ├── badges/
│   ├── seasonal/
│   ├── annotations/
│   ├── decorative/
│   ├── emotions/
│   └── numbers/
├── png/
│   ├── 1x/ (512px)
│   ├── 2x/ (1024px)
│   └── 3x/ (1536px)
└── preview/
    └── sticker_catalog.pdf (visual reference)
```

---

## Usage in App

### Sticker Picker UI
- **Grid Layout:** 4 columns on iPhone, 6 on iPad
- **Category Tabs:** Horizontal scrolling tabs at top
- **Search:** Filter by name or category
- **Favorites:** Users can star frequently used stickers
- **Size Adjustment:** Pinch to resize after placement
- **Rotation:** Two-finger rotate gesture
- **Delete:** Drag to trash icon or long-press → delete

### Placement Behavior
- **Drag & Drop:** From picker to recipe card
- **Snap to Grid:** Optional 8px grid for alignment
- **Layer Order:** Most recent on top, can reorder
- **Bounds Checking:** Prevent placing outside card area
- **Undo/Redo:** Full history for sticker operations

### Export Behavior
- **Rasterization:** Stickers rendered at card resolution (2400×3200px for sharing)
- **Preserve Layers:** SVG stickers rendered as high-quality PNGs
- **Shared Cards:** Recipients see exactly the same stickers

---

## Cost Estimation

### Professional Illustration Services

**Option A: Freelance Illustrator (Mid-Level)**
- Rate: $50-75/hour
- Time per sticker: 2-3 hours (design, revisions, export)
- Cost per sticker: $100-225
- **Total for 60 stickers:** $6,000 - $13,500
- **Phase 1 only (20 stickers):** $2,000 - $4,500

**Option B: Design Agency**
- Flat rate package: $8,000 - $15,000 for complete set
- Includes: Style guide, revisions, format exports
- Higher quality and consistency
- **Phase 1 only:** $3,000 - $6,000

**Option C: Stock Illustration + Customization**
- Purchase existing illustrations: $10-30 each
- Hire designer to unify style: $1,500
- **Total:** $2,100 - $3,300
- **Trade-off:** Less unique, may not match perfectly

### Recommended Approach

**For Bootstrap Launch:**
- Start with **Option C** for Phase 1 (20 stickers)
- Budget: $1,000 for stock + $500 for style unification
- Launch with "good enough" stickers
- Gauge user demand before investing in custom set

**For Funded Launch:**
- **Option B** for complete set (60 stickers)
- Budget: $10,000 for agency package
- Professional, cohesive library from day one
- Strong differentiation vs. competitors

---

## Alternative: AI-Generated + Manual Touch-Up

**Hybrid Approach:**
1. Generate base illustrations with Midjourney/DALL-E
2. Hire designer to refine, ensure consistency
3. Manual vector tracing for clean SVGs

**Cost:**
- AI generation: $100/month subscription
- Designer touch-up: $30/hour × 60 hours = $1,800
- **Total:** $1,900 for 60 stickers

**Pros:**
- Fast iteration
- Low cost
- Good enough quality

**Cons:**
- Less unique
- Requires skilled designer for refinement
- Some inconsistency across stickers

---

## Quality Standards

### Acceptance Criteria
- ✓ Matches brand color palette (95% color accuracy)
- ✓ Hand-drawn aesthetic (no perfect geometric shapes)
- ✓ Readable at 24px minimum size
- ✓ Transparent background (alpha channel)
- ✓ Optimized file size (<50KB per SVG, <200KB per PNG @3x)
- ✓ Consistent line weight across category
- ✓ No copyright issues (original or properly licensed)

### Revisions Process
1. Initial concepts (3 stickers per category)
2. Feedback round (within 48 hours)
3. Full set production
4. Final review and export
5. Delivery with source files

---

## Future Expansion Ideas

**Seasonal Packs (DLC or Free Updates):**
- Thanksgiving Pack (10 stickers): Turkey, pumpkin pie, cornucopia, pilgrim hat
- Christmas Pack (10 stickers): Gingerbread man, candy cane, ornament, wreath
- Easter Pack (8 stickers): Egg, bunny, basket, spring flowers
- Summer BBQ Pack (8 stickers): Grill, hot dog, watermelon, corn

**Regional/Cultural Packs:**
- Italian Pack: Pasta shapes, wine bottle, olive branch, Tuscan landscape
- Asian Pack: Wok, chopsticks, rice bowl, dumplings, tea pot
- Mexican Pack: Chili pepper, avocado, lime, tortilla, cactus

**Premium Animated Stickers (Phase 3+):**
- Slight motion on stickers (steam rising, sparkles)
- Export as live photos or animated GIFs
- Extra delight for premium users

---

## Rights and Licensing

**Intellectual Property:**
- All stickers are proprietary to Heirloom
- Designer assigns full copyright upon payment
- Users receive license to use stickers within the app only
- Users cannot extract and resell stickers

**Designer Contract Terms:**
- Work-for-hire agreement
- All source files transferred
- No portfolio use without approval
- 2 revision rounds included

---

**Document Version:** 1.0
**Status:** Ready for designer outreach
**Budget Range:** $1,900 - $10,000 depending on approach
**Timeline:** 4-8 weeks for full set, 2-3 weeks for Phase 1
