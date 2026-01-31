# Servings Scaling Fix - Testing Guide

**Date:** 2026-01-30
**Purpose:** Verify servings scaling works correctly across all import types

---

## What Was Fixed

### Primary Issues:
1. **Missing ingredient quantities** - Web imports returned strings without parsed quantities
2. **Unparseable servings strings** - Regex failed on varied formats like "Makes 2 dozen"
3. **No error reporting** - Silent failures with no user feedback

### Solutions Implemented:
1. **Enhanced ServingsParser** - Multi-strategy parsing with keyword extraction, dozen handling, temperature filtering
2. **Immediate ingredient parsing** - Parse quantities during import, not in background
3. **Validation & diagnostics** - Track scaling issues with structured logging
4. **User feedback** - Warning banner + repair tool for broken recipes
5. **Graceful degradation** - Show ⚠️ for unparseable ingredients, allow others to scale

---

## Quick Verification Checklist

Before detailed testing, verify the build:

```bash
# Build the app
cd /Users/matthanson/Heirloom
xcodebuild -scheme Heirloom -configuration Debug build

# Run unit tests
xcodebuild test -scheme HeirloomTestsV2 \
  -only-testing:HeirloomTestsV2/ServingsParserTests \
  -only-testing:HeirloomTestsV2/ScalingIntegrationTests
```

Expected: All tests pass with no errors.

---

## Test Matrix

Test each import type × servings format combination:

| Import Type | Test Recipe | Expected Servings | Test Scaling | Status |
|-------------|-------------|-------------------|--------------|--------|
| **Web URL** | NYT "Chocolate Chip Cookies" | 48 cookies → 48 | 48 → 96 (double) | ⬜ |
| **Web URL** | AllRecipes "Lasagna" | Serves 8 → 8 | 8 → 4 (half) | ⬜ |
| **Web URL** | Food Network "Banana Bread" | Makes 1 loaf → 1 | 1 → 2 (double) | ⬜ |
| **Manual** | User enters "Makes 12 muffins" | 12 | 12 → 24 (double) | ⬜ |
| **Manual** | User enters "4-6 servings" | 4 | 4 → 8 (double) | ⬜ |
| **Video** | ASMR video "for 6 people" | 6 | 6 → 3 (half) | ⬜ |
| **Photo/OCR** | Handwritten "Serves 4-6" | 4 | 4 → 8 (double) | ⬜ |
| **PDF** | Cookbook "Yield: 2 dozen" | 24 | 24 → 12 (half) | ⬜ |
| **Shared** | Inherited from friend | Match source | Match source | ⬜ |

---

## Detailed Test Procedures

### Test 1: Web Import (NYT Cooking)

**URL:** https://cooking.nytimes.com/recipes/1015819-chocolate-chip-cookies

**Steps:**
1. Open Heirloom app
2. Tap "+" → "Import from URL"
3. Paste NYT cookie recipe URL
4. Tap "Import"
5. Wait for import to complete
6. Verify recipe detail view opens

**Verify:**
- ✅ `parsedServingCount` shows correct number (e.g., 48)
- ✅ No warning banner appears (recipe is fully scalable)
- ✅ All ingredients show quantities (e.g., "2 cups flour")
- ✅ No ⚠️ icons next to ingredients

**Test Scaling:**
1. Tap servings stepper to change from 48 → 96
2. Verify all ingredient quantities **double**:
   - "2 cups flour" → "4 cups flour"
   - "1 cup sugar" → "2 cups sugar"
   - etc.
3. Change back to 48 → verify quantities return to original
4. Change to 24 (half) → verify quantities halve

**Expected:** ✅ All quantities scale correctly, no warnings

---

### Test 2: Web Import with Malformed Servings

**URL:** Find a recipe site with unusual servings format (e.g., "Yield: about 2 dozen")

**Steps:**
1. Import recipe with unusual servings string
2. Check recipe detail view

**Verify:**
- ✅ Servings parsed correctly (e.g., "2 dozen" → 24)
- ✅ No warning banner (if quantities parsed)
- ✅ Scaling works correctly

**Fallback Test:**
If servings can't be parsed:
- ✅ Warning banner appears: "Could not determine serving count from 'X'"
- ✅ Tap "Fix" button opens repair sheet
- ✅ Scaling still works with default (4)

---

### Test 3: Web Import with Missing Quantities (Worst Case)

**Scenario:** Recipe where AI parsing fails

**Steps:**
1. Import recipe from less common site
2. If quantities are missing, observe behavior

**Verify:**
- ✅ Warning banner appears: "X of Y ingredients missing quantities"
- ✅ Ingredients without quantities show ⚠️ icon
- ✅ Ingredients WITH quantities still scale correctly
- ✅ Tap "Fix" → repair sheet attempts to parse missing quantities
- ✅ After repair, warning disappears if successful

---

### Test 4: Manual Recipe Entry

**Steps:**
1. Tap "+" → "Create Recipe"
2. Enter title: "Test Muffins"
3. Enter servings: "Makes 12 muffins"
4. Add ingredients:
   - "2 cups flour"
   - "1 cup sugar"
   - "2 eggs"
5. Save recipe

**Verify:**
- ✅ `parsedServingCount` = 12
- ✅ Change to 24 → all quantities double
- ✅ Change to 6 → all quantities halve

**Edge Case Test:**
1. Create recipe with servings "some amount" (no number)
2. Verify warning appears: "Could not determine serving count"
3. Servings defaults to 4

---

### Test 5: Video Import

**Steps:**
1. Select video from camera roll with recipe
2. Wait for processing
3. Check parsed servings from transcription

**Verify:**
- ✅ If servings mentioned in video (e.g., "for 6 people"), `parsedServingCount` = 6
- ✅ If not mentioned, defaults to 4 with no warning
- ✅ Scaling works if quantities were extracted from video

---

### Test 6: Photo/OCR Import

**Steps:**
1. Take photo of printed recipe
2. Wait for OCR processing
3. Review extracted recipe

**Verify:**
- ✅ Servings extracted from image (e.g., "Serves 4-6" → 4)
- ✅ Ingredient quantities extracted
- ✅ Scaling works on extracted data

**Handwritten Test:**
1. Photo of handwritten recipe
2. Verify Claude Vision extracted quantities
3. Test scaling

---

### Test 7: PDF Import

**Steps:**
1. Select PDF with recipe (e.g., cookbook page)
2. Wait for processing
3. Check extracted data

**Verify:**
- ✅ "Yield: 2 dozen" parsed as 24
- ✅ "Makes 1 9-inch pie" parsed as 1 (not 9)
- ✅ Scaling works on extracted quantities

---

### Test 8: Shared Recipe

**Steps:**
1. Accept shared recipe from friend
2. Verify inherited servings and quantities

**Verify:**
- ✅ Servings match source recipe
- ✅ Quantities inherited correctly
- ✅ Scaling works immediately (no parsing needed)

---

## Diagnostic Verification

### Check Console Logs

Open **Console.app** and filter by "scaling":

**Look for:**
```
✅ "Scaling successful" - when servings changed
✅ "Ingredients parsed successfully" - after import
⚠️ "Failed to parse servings" - if unparseable
⚠️ "Recipe has ingredients without quantities" - if missing data
```

**Verify:**
- No silent failures (all issues logged)
- Success rate metrics visible
- Useful metadata (recipeId, sourceType, counts)

---

## Regression Checks

Ensure no existing functionality broke:

### ScalingEngine Still Works
1. Open recipe with advanced scaling (laminated dough, candy)
2. Verify lock icon shows with "fixed" label
3. Verify ScalingExplanationSheet explains why locked

### Shopping Cart Integration
1. Scale recipe to custom servings
2. Add to shopping cart
3. Verify shopping cart shows scaled quantities
4. Verify grocery list totals are correct

### Cooking Mode
1. Scale recipe
2. Start cooking mode
3. Verify instructions show scaled quantities
4. Verify timer still works

---

## Error Cases to Test

### Import Failures
1. **Invalid URL** → verify error message
2. **Paywall site** → verify fallback or error
3. **No internet** → verify offline handling

### Parsing Failures
1. **All quantities fail to parse** → verify warning banner with "Fix" button
2. **Repair tool fails** → verify error message in repair sheet
3. **AI service down** → verify fallback to basic parsing

---

## Performance Verification

### Import Speed
- **Before fix:** Background parsing delayed (user saw nil quantities)
- **After fix:** Immediate parsing (user sees quantities on import)

**Test:**
1. Import recipe from URL
2. Measure time from "Import" tap to recipe detail view
3. Verify quantities visible **immediately** (not after delay)

**Expected:** < 5 seconds for typical recipe import

### No Duplicate Work
**Verify:**
1. Import recipe
2. Check logs for "Skipping background parsing - ingredients already parsed"
3. Confirm no duplicate AI calls

---

## Acceptance Criteria

All tests must pass before marking as complete:

- ✅ All 7 import types scale correctly
- ✅ Enhanced ServingsParser handles edge cases (dozens, ranges, temperatures)
- ✅ No silent failures (all issues logged with diagnostics)
- ✅ User sees clear feedback for broken recipes (warning banner)
- ✅ Repair tool successfully fixes at least 80% of issues
- ✅ No performance regression (import speed maintained)
- ✅ No crashes or data loss
- ✅ Graceful degradation (partial scaling works)
- ✅ Unit tests pass (ServingsParserTests)
- ✅ Integration tests pass (ScalingIntegrationTests)

---

## Known Limitations

### Expected Behavior:
1. **Recipes without servings** → Default to 4, show warning
2. **Ingredients without units** → Can't scale (e.g., "Salt to taste")
3. **Complex preparations** → May not scale perfectly (e.g., "1 9-inch pan")
4. **Rare units** → May not convert well

### Not Bugs:
- Locked recipes (laminated dough, candy) intentionally don't scale
- "Adjust to taste" ingredients show ⚠️ (correct behavior)
- Some handwritten text may not OCR perfectly (limitation of Vision)

---

## Reporting Issues

If any test fails, report with:

1. **Import type** (URL, manual, video, etc.)
2. **Recipe source** (exact URL if web import)
3. **Servings string** (what was written/extracted)
4. **Expected servings** vs **actual parsedServingCount**
5. **Screenshots** of warning banner (if shown)
6. **Console logs** (filter by "scaling")
7. **Steps to reproduce**

**Example:**
```
❌ Web import from AllRecipes failed

Source: https://allrecipes.com/recipe/12345/
Servings string: "Yield: 1 dozen cookies"
Expected: 12
Actual: 4 (defaulted)

Logs showed: "Failed to parse servings - defaulting to 4"
Warning banner appeared correctly

Issue: ServingsParser not recognizing "dozen" with "Yield:" keyword
```

---

## Success Metrics

After deployment, monitor:

### Analytics (Mixpanel/Firebase)
- `scaling_attempt` event count
- `scaling_success_rate` (via diagnostics)
- `scaling_repair_used` (how often users tap "Fix")
- `scaling_repair_success_rate`

### User Feedback
- Support tickets about scaling issues (should decrease)
- App Store reviews mentioning scaling (sentiment improvement)

### Technical Metrics
- `parsedServingCount` accuracy (% not defaulting to 4)
- Ingredient quantity parsing success rate (% with non-nil quantities)
- Time to parse ingredients (should be < 5s median)

---

**Version:** 1.0
**Last Updated:** 2026-01-30
**Tested By:** _____________
**Date Tested:** _____________
**Result:** ⬜ PASS  ⬜ FAIL  ⬜ NEEDS FIXES
