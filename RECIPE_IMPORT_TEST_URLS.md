# Recipe Import Test URLs

Test these URLs to validate the recipe import feature works across different sites and markup formats.

## ✅ Easy Imports (JSON-LD, Well-Structured)

### 1. AllRecipes - Classic Chocolate Chip Cookies
```
https://www.allrecipes.com/recipe/10813/best-chocolate-chip-cookies/
```
**Expected:** Title, ingredients, numbered steps, image, prep/cook time, servings
**Markup:** Schema.org JSON-LD (gold standard)

### 2. Serious Eats - Perfect Pan Pizza
```
https://www.seriouseats.com/foolproof-pan-pizza-recipe
```
**Expected:** Detailed instructions, multiple images, precise measurements
**Markup:** JSON-LD with rich metadata

### 3. King Arthur Baking - Rustic Sourdough Bread
```
https://www.kingarthurbaking.com/recipes/rustic-sourdough-bread-recipe
```
**Expected:** Baker's percentages, detailed timing, sourdough starter instructions
**Markup:** JSON-LD with baking-specific data

**Alternative King Arthur URLs to test:**
- https://www.kingarthurbaking.com/recipes/supersized-super-soft-chocolate-chip-cookies-recipe
- https://www.kingarthurbaking.com/recipes/easy-everyday-sourdough-bread-recipe
- https://www.kingarthurbaking.com/recipes/no-knead-sourdough-bread-recipe

## 🧪 Moderate Complexity (JSON-LD but Complex Structure)

### 4. NYT Cooking - Banana Bread
```
https://cooking.nytimes.com/recipes/1018045-banana-bread
```
**Expected:** Recipe behind paywall considerations, author info
**Markup:** JSON-LD (may require free account)
**Note:** Might fail if paywalled - that's expected behavior

### 5. Food Network - Chicken Stir-Fry
```
https://www.foodnetwork.com/recipes/food-network-kitchen/chicken-stir-fry-recipe-2103187
```
**Expected:** Video embeds, chef info, complex ingredient grouping
**Markup:** JSON-LD with @graph array

### 6. Bon Appétit - Caesar Salad
```
https://www.bonappetit.com/recipe/classic-caesar-salad
```
**Expected:** Editorial notes, ingredient variations
**Markup:** JSON-LD with nested structures

## 🔧 Edge Cases (Microdata Fallback, Older Sites)

### 7. Budget Bytes - Beef Tacos
```
https://www.budgetbytes.com/easy-beef-tacos/
```
**Expected:** Cost breakdowns, simpler format
**Markup:** May use older microdata or simplified JSON-LD

### 8. The Pioneer Woman - Lasagna
```
https://www.thepioneerwoman.com/food-cooking/recipes/a11659/meat-lovers-lasagna/
```
**Expected:** Personal story before recipe, lots of photos
**Markup:** JSON-LD with blog content

### 9. Simply Recipes - Pancakes
```
https://www.simplyrecipes.com/recipes/pancakes/
```
**Expected:** Ingredient substitutions, reader comments
**Markup:** Clean JSON-LD implementation

## 🌎 International Sites

### 10. BBC Good Food - Spaghetti Carbonara (UK)
```
https://www.bbcgoodfood.com/recipes/ultimate-spaghetti-carbonara-recipe
```
**Expected:** Metric measurements, UK terminology
**Markup:** JSON-LD with grams/ml

## 🚫 Expected Failures (Learning Opportunities)

### 11. Instagram Recipe Post
```
(Any Instagram recipe post URL)
```
**Expected:** FAIL - No structured data
**Why:** Good test of error handling

### 12. YouTube Recipe Video
```
(Any YouTube recipe video URL)
```
**Expected:** FAIL - No recipe markup in video pages
**Why:** Tests "no recipe found" error message

### 13. Personal Blog (No Markup)
```
(Small blog without Schema.org)
```
**Expected:** FAIL - No structured data
**Why:** Validates we need proper markup

---

## Testing Checklist

For each successful import, verify:
- [ ] Title imported correctly
- [ ] All ingredients captured (check count)
- [ ] Instructions in correct order
- [ ] Image downloads and displays
- [ ] Prep/cook time formatted correctly (e.g., "30m" not "PT30M")
- [ ] Servings captured
- [ ] Source URL saved
- [ ] Toast confirmation appears
- [ ] Recipe appears in list view

## Quick Test Script

1. **Test 3 Easy Sites** - Validate basic functionality
   - AllRecipes
   - Serious Eats
   - King Arthur

2. **Test 2 Complex Sites** - Validate advanced parsing
   - Food Network
   - Bon Appétit

3. **Test 1 Failure Case** - Validate error handling
   - Random blog without markup

4. **Spot Check Features:**
   - Import recipe
   - Navigate to detail view
   - Add to shopping list
   - Verify quantities aggregate correctly
   - Export to Reminders

---

## Known Limitations

Our parser currently handles:
✅ Schema.org JSON-LD (90% of modern recipe sites)
✅ Microdata fallback (older sites)
✅ Image downloading
✅ ISO duration parsing (PT30M → 30m)
✅ Multiple instruction formats (string, array, HowToStep)

We do NOT handle:
❌ Sites without structured data
❌ Paywalled content (NYT, WSJ)
❌ Video-only recipes
❌ PDF recipe cards
❌ Instagram/Pinterest posts

These are all acceptable limitations - the vast majority of recipe sites use Schema.org markup.

---

## If Import Fails

1. Copy the error message
2. Check if site requires login/paywall
3. View page source → Search for "application/ld+json" or "Recipe"
4. If no markup exists, site is not supported (expected)
5. If markup exists but parse fails, may need custom handling

## Success Criteria

✅ **7+ out of 10 test URLs import successfully**
✅ **Error messages are clear and actionable**
✅ **Imported recipes display correctly in app**
✅ **No crashes on invalid URLs**

---

**Next Step:** Test 3-5 URLs manually in the app, then we'll continue with Search & Filters feature.
