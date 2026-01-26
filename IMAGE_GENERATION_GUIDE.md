# Image Generation Guide for 14 Themes

## Overview
You now have **14 themes** with **186 total recipes** that need images generated.

### Current Status
- ✅ 10 original themes: 134 recipe images generated and uploaded
- ❌ 4 heritage themes: 52 recipe images needed
- ❌ All 14 themes: Theme cover images needed

---

## Theme Cover Images Needed (14 total)

### Original Themes (1-10)
1. **Automat Classics** (`automat-classics.webp`)
   - Prompt: Warm art deco cafeteria interior with chrome coffee dispensers and glass pie cases, soft lighting, 1950s nostalgia, watercolor illustration style

2. **Golden Age of Rail** (`railroad-dining.webp`)
   - Prompt: Elegant vintage train dining car with white tablecloths and art deco details, golden hour light through windows, watercolor illustration

3. **Victory Kitchen** (`victory-kitchen.webp`)
   - Prompt: 1940s kitchen with victory garden vegetables and ration books, warm homey atmosphere, vintage advertisement style

4. **Navy Mess Hall** (`navy-mess.webp`)
   - Prompt: Navy ship galley with gleaming steel surfaces and hearty meal preparations, nautical color palette, vintage poster style

5. **Boston Cooking School** (`boston-cooking-school.webp`)
   - Prompt: Victorian-era kitchen classroom with measuring cups and vintage cookbook, soft sepia tones, historical illustration style

6. **Southern Roots** (`southern-roots.webp`)
   - Prompt: Southern farmhouse kitchen with fresh vegetables and cast iron cookware, warm golden light, folk art illustration style

7. **Scandinavian Heritage** (`scandinavian-heritage.webp`)
   - Prompt: Cozy Nordic kitchen with traditional baked goods and winter landscape through window, cool color palette, Scandinavian design aesthetic

8. **German-American Kitchen** (`german-american.webp`)
   - Prompt: Pennsylvania Dutch farmhouse kitchen with traditional hearth and baked goods, warm rustic atmosphere, folk art style

9. **Quick Weeknight Classics** (`quick-weeknight.webp`)
   - Prompt: Modern efficient kitchen with fresh ingredients and quick prep setup, bright clean aesthetic, contemporary illustration

10. **Sunday Suppers** (`sunday-suppers.webp`)
    - Prompt: Cozy Sunday dinner table with slow-cooked roast and family gathering, warm inviting light, Norman Rockwell style

### Heritage Themes (11-14)
11. **Presidential Pantry** (`presidential-pantry.webp`)
    - Prompt: Elegant White House state dining room with presidential china and formal place settings, patriotic color accents, historical illustration style

12. **Literary Kitchen** (`literary-kitchen.webp`)
    - Prompt: Cozy library reading nook with vintage cookbooks and literary-inspired dishes, warm candlelight, storybook illustration style

13. **Ancient Table** (`ancient-table.webp`)
    - Prompt: Ancient Roman or Greek dining room with amphoras and olive branches, classical architecture, archaeological illustration style

14. **American Foundation** (`american-foundation.webp`)
    - Prompt: Colonial American hearth kitchen with copper pots and wooden utensils, candlelit warmth, Americana folk art style

**Output Directory:** `/Users/matthanson/Heirloom/theme-images/`

---

## Recipe Images Needed (52 total for heritage themes)

### Presidential Pantry (14 recipes)
Prefix: `presidential-` or use exact recipe IDs from JSON

1. martha-washington-great-cake.webp
2. thomas-jefferson-ice-cream.webp
3. abraham-lincoln-gingerbread.webp
4. eleanor-roosevelt-scrambled-eggs.webp
5. dolley-madison-oyster-soup.webp
6. jacqueline-kennedy-chicken-casserole.webp
7. fdr-favorite-grilled-cheese.webp
8. harry-truman-ozark-pudding.webp
9. lbj-pedernales-river-chili.webp
10. george-washington-hoecakes.webp
11. john-adams-indian-pudding.webp
12. reagan-california-cobb-salad.webp
13. calvin-coolidge-chicken-pie.webp
14. james-monroe-spoon-bread.webp

### Literary Kitchen (14 recipes)
Prefix: `literary-` or use exact recipe IDs from JSON

1. mrs-beeton-beefsteak-kidney-pudding.webp
2. moby-dick-chowder.webp
3. great-gatsby-champagne-cocktails.webp
4. alice-tea-cakes.webp
5. little-women-apple-slump.webp
6. pride-prejudice-white-soup.webp
7. christmas-carol-roast-goose.webp
8. hemingway-death-afternoon.webp
9. to-kill-mockingbird-lane-cake.webp
10. laura-ingalls-vanity-cakes.webp
11. sherlock-holmes-seed-cake.webp
12. anne-green-gables-raspberry-cordial.webp
13. wuthering-heights-oatcakes.webp
14. winnie-pooh-honey-buns.webp

### Ancient Table (12 recipes)
Prefix: `ancient-` or use exact recipe IDs from JSON

1. apicius-conditum-paradoxum.webp
2. roman-patina-de-piris.webp
3. greek-olive-honey-cakes.webp
4. roman-garum-sauce.webp
5. egyptian-flatbread.webp
6. mesopotamian-beer-bread.webp
7. greek-lentil-soup.webp
8. roman-moretum.webp
9. persian-rice-pilaf.webp
10. byzantine-honey-fritters.webp
11. greek-barley-cakes.webp
12. roman-stuffed-dormice.webp

### American Foundation (12 recipes)
Prefix: `american-` or use exact recipe IDs from JSON

1. colonial-brown-bread.webp
2. shaker-lemon-pie.webp
3. johnnycakes.webp
4. succotash.webp
5. pumpkin-butter.webp
6. apple-pandowdy.webp
7. hasty-pudding.webp
8. election-cake.webp
9. switchel.webp
10. syllabub.webp
11. mincemeat.webp
12. corn-dodgers.webp

**Note:** Check `/Users/matthanson/Heirloom/themerecipes/theme-11-presidential-pantry.json` (and other heritage theme files) for exact recipe IDs to ensure filenames match.

**Output Directory:** `/Users/matthanson/Heirloom/scripts/theme-image-gen/images/`

---

## Style Guidelines

### Consistency with Existing Images
Review the 134 existing recipe images in `/Users/matthanson/Heirloom/recipe-images/` to maintain:
- Color palette consistency
- Illustration style (appears to be food photography or realistic rendering)
- Composition (overhead shot, plated presentation, etc.)
- Lighting and mood

### Theme Cover Style
- Watercolor or illustrated aesthetic (not photography)
- Historical accuracy for period-specific themes
- Warm, inviting atmosphere
- Should evoke the era/source without being too literal
- Consistent aspect ratio (suggest 3:4 portrait or 16:9 landscape)

---

## Workflow

### Phase 1: Generate Heritage Recipe Images (52 images)
1. Review existing 134 recipe images for style reference
2. Generate 52 new images matching the style
3. Save to `/Users/matthanson/Heirloom/scripts/theme-image-gen/images/`
4. Ensure filenames match recipe IDs in theme JSON files

### Phase 2: Generate All Theme Cover Images (14 images)
1. Use prompts provided above
2. Ensure consistent style across all 14 covers
3. Save to `/Users/matthanson/Heirloom/theme-images/`
4. Filename format: `{theme-id}.webp`

### Phase 3: Upload to Firebase
```bash
cd /Users/matthanson/Heirloom/firebase

# 1. Organize heritage recipe images
node organize_images_from_json.py

# 2. Upload all images (recipes + covers)
npm run upload-images

# 3. Verify in Firebase Console
# Images will be at:
# - gs://heirloom-ios-prod.firebasestorage.app/themes/{theme-id}.webp
# - gs://heirloom-ios-prod.firebasestorage.app/recipes/{theme-id}/{recipe-id}.webp
```

---

## Firebase Upload Commands

After generating images:

```bash
cd /Users/matthanson/Heirloom/firebase

# Seed the 4 new heritage themes (if not done already)
npm run seed-themes

# Seed the 52 new heritage recipes
npm run seed-recipes

# Upload theme covers and recipe images
npm run upload-images

# Or upload separately:
npm run upload-images:themes   # Only theme covers
npm run upload-images:recipes  # Only recipe images
```

---

## Verification Checklist

After uploading:

- [ ] All 14 theme covers display in app theme selection
- [ ] All 186 recipe images display in collection details
- [ ] Image quality is consistent across all themes
- [ ] Images load quickly (check file sizes)
- [ ] Style is cohesive between original and heritage themes
- [ ] Firestore documents updated with imageURL fields

---

## Reference Files

- **Heritage Recipe Data:** `/Users/matthanson/Heirloom/heritage-recipes-export/`
- **Theme JSON Files:** `/Users/matthanson/Heirloom/themerecipes/`
- **Existing Recipe Images:** `/Users/matthanson/Heirloom/recipe-images/` (134 images)
- **Firebase Scripts:** `/Users/matthanson/Heirloom/firebase/`

---

## Total Image Count

- Theme covers: **14 images** (all needed)
- Original recipe images: **134 images** (✅ complete, uploaded)
- Heritage recipe images: **52 images** (❌ needed)
- **Grand Total: 200 images** (134 complete, 66 needed)
