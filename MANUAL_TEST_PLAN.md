# Heirloom Manual Test Plan
## Multi-Recipe Import & Duplicate Detection

**Date:** 2026-02-01
**Version:** 1.0
**Features Tested:**
- Multi-recipe detection from single images
- Duplicate detection and prevention
- Collection consolidation
- Import flow reliability
- Share extension → main app handoff

---

## Prerequisites

### Test Data Required
1. **Single Recipe Images** (3 files)
   - Orange Fritters recipe (complete, >3 ingredients)
   - Any cookbook page with 1 recipe
   - Any cookbook page with 1 recipe

2. **Multi-Recipe Images** (2 files)
   - Cookbook page with 2 recipes (e.g., Pumpkin Pie + Cheese Souffle)
   - Cookbook page with 3+ recipes

3. **Duplicate Test Images** (2 files)
   - Same recipe scanned twice (exact duplicate)
   - Similar recipe with minor variations (fuzzy duplicate)

### Initial Setup
1. **Clean install** (delete app, reinstall from Xcode)
2. **Verify logged in** to Firebase account
3. **Delete existing recipes** in Kitchen Table to start fresh
4. **Clear "Cookbook Pages" collections** if any exist

---

## Test Suite 1: Single Recipe Import

### Test 1.1: Camera Roll → Single Recipe Import

**Steps:**
1. Open Heirloom app
2. Tap "+" button to add recipe
3. Select "Scan Cookbook"
4. Tap photo icon to open camera roll
5. Select single recipe image (Orange Fritters)
6. **VERIFY:** Extraction starts automatically (no "Extract Recipe" button needed)
7. Wait for extraction to complete

**Expected Results:**
- ✅ Recipe extraction starts immediately after photo selection
- ✅ 1 recipe detected
- ✅ Recipe appears in Kitchen Table
- ✅ Recipe has image thumbnail
- ✅ Recipe has ≥3 ingredients
- ✅ Recipe has ≥2 instructions
- ✅ Recipe appears in "Cookbook Pages" collection
- ✅ No duplicate "Cookbook Pages" collections created

**Log Checkpoints:**
```
🔍 Starting image import processing
📸 Image loaded successfully (width: X, height: Y)
✅ Recipe detection completed (detected_count: 1)
📝 Extraction completed (detected: 1, extracted: 1, failed: 0)
✅ Source-specific processing completed (recipe_count: 1)
Saved recipe image from bulk import (source: photoLibrary)
```

**Failure Criteria:**
- ❌ Extraction requires manual "Extract Recipe" button tap
- ❌ Recipe rejected for too few ingredients (<3)
- ❌ Recipe rejected for too few instructions (<2)
- ❌ Multiple "Cookbook Pages" collections created
- ❌ Recipe missing from collection

---

### Test 1.2: Camera Capture → Single Recipe Import

**Steps:**
1. Tap "+" → "Scan Cookbook"
2. Tap camera icon
3. Grant camera permission if needed
4. Take photo of single recipe page
5. Tap "Use Photo"
6. Tap "Extract Recipe" button
7. Wait for extraction

**Expected Results:**
- ✅ Camera capture shows "Extract Recipe" button (manual trigger)
- ✅ Recipe extraction completes
- ✅ Recipe added to same "Cookbook Pages" collection as Test 1.1
- ✅ Total of 2 recipes in "Cookbook Pages" collection

**Log Checkpoints:**
```
📸 Processing camera/photo import (source: camera)
✅ Source-specific processing completed (recipe_count: 1)
```

---

## Test Suite 2: Multi-Recipe Detection

### Test 2.1: Dual Recipe Import (2 recipes on 1 page)

**Steps:**
1. Tap "+" → "Scan Cookbook" → Camera Roll
2. Select multi-recipe image (Pumpkin Pie + Cheese Souffle)
3. Wait for extraction

**Expected Results:**
- ✅ 2 recipes detected
- ✅ 2 recipes extracted successfully
- ✅ Both recipes appear in Kitchen Table
- ✅ Both recipes have unique IDs
- ✅ Both recipes appear in "Cookbook Pages" collection
- ✅ Total of 4 recipes in "Cookbook Pages" collection (2 from previous tests + 2 new)
- ✅ No duplicate recipes in collection
- ✅ Both recipes share same source image

**Log Checkpoints:**
```
✅ Recipe detection completed (detected_count: 2)
📝 Extraction completed (detected: 2, extracted: 2, failed: 0)
✨ Multiple recipes extracted from single image (count: 2, titles: "Pumpkin Pie | Cheese Souffle")
✅ Source-specific processing completed (recipe_count: 2)
Checkpointed recipe(s) (recipe_count: 2, recipe_ids: "UUID1, UUID2")
```

**Failure Criteria:**
- ❌ Only 1 recipe appears in Kitchen Table
- ❌ Only 1 recipe appears in collection
- ❌ Recipes appear in separate collections
- ❌ Recipes have duplicate entries (4 cards instead of 2)

---

### Test 2.2: Triple Recipe Import (3+ recipes on 1 page)

**Steps:**
1. Tap "+" → "Scan Cookbook" → Camera Roll
2. Select multi-recipe image with 3+ recipes
3. Wait for extraction

**Expected Results:**
- ✅ 3+ recipes detected
- ✅ All recipes extracted (or partial success logged)
- ✅ All successful recipes appear in Kitchen Table
- ✅ All recipes added to same "Cookbook Pages" collection
- ✅ If partial failure: error message shows "X/Y recipes extracted (Z failed)"

**Log Checkpoints (Full Success):**
```
✅ Recipe detection completed (detected_count: 3)
✨ Multiple recipes extracted from single image (count: 3, titles: "Recipe1 | Recipe2 | Recipe3")
```

**Log Checkpoints (Partial Failure):**
```
⚠️ Partial extraction failure (successful: 2, failed: 1, failed_titles: "Recipe3")
⚠️ Partial import success (successful: 2, failed: 1, successful_titles: "Recipe1 | Recipe2")
```

---

## Test Suite 3: Duplicate Detection

### Test 3.1: Exact Duplicate Prevention

**Steps:**
1. Note the title of first recipe from Test 1.1 (e.g., "Orange Fritters")
2. Import the SAME image again (from camera roll)
3. Wait for extraction

**Expected Results:**
- ✅ Recipe detected and extracted
- ✅ Duplicate detection triggered
- ✅ Recipe NOT inserted into database (skipped)
- ✅ Recipe count in Kitchen Table unchanged
- ✅ Recipe count in "Cookbook Pages" collection unchanged

**Log Checkpoints:**
```
⚠️ Skipping exact duplicate recipe (title: "Orange Fritters", content_hash: "abc123...", duplicate_id: "UUID", duplicate_title: "Orange Fritters")
📋 Skipped duplicate recipes (count: 1, skipped_titles: "Orange Fritters", original_count: 1, inserted_count: 0)
```

**Verification:**
1. Open Kitchen Table
2. Count recipes with title "Orange Fritters"
3. **MUST BE EXACTLY 1** (not 2)

---

### Test 3.2: Fuzzy Duplicate Detection (Similar Recipe)

**Steps:**
1. Import recipe image with minor variations (e.g., "Chocolate Chip Cookies" with different measurements)
2. Wait for extraction

**Expected Results:**
- ✅ Recipe detected
- ✅ Similarity detected but NOT exact match
- ✅ Recipe inserted into database (threshold not met for exact duplicate)
- ✅ Warning logged about similarity

**Log Checkpoints:**
```
ℹ️ Recipe similar to existing recipe (inserting anyway) (title: "Chocolate Chip Cookies", similarity_score: 0.75, match_type: "titleMatch", similar_to: "Chocolate Chip Cookies")
```

**Note:** Recipe is inserted because similarity < 0.85 threshold for exact duplicates.

---

## Test Suite 4: Collection Consolidation

### Test 4.1: Verify Single "Cookbook Pages" Collection

**Steps:**
1. After completing Tests 1-3, navigate to Collections tab
2. Count "Cookbook Pages" collections

**Expected Results:**
- ✅ Exactly 1 "Cookbook Pages" collection exists
- ✅ Collection contains all imported recipes (excluding exact duplicates)
- ✅ Collection shows correct recipe count badge
- ✅ Collection icon is cookbook/pages icon

**Failure Criteria:**
- ❌ Multiple "Cookbook Pages" collections
- ❌ Recipes split across different collections
- ❌ Missing recipes in collection

---

### Test 4.2: Collection Persistence Across Sessions

**Steps:**
1. Note current recipe count in "Cookbook Pages"
2. Force quit Heirloom app (swipe up from app switcher)
3. Relaunch app
4. Navigate to Collections tab

**Expected Results:**
- ✅ "Cookbook Pages" collection still exists
- ✅ Recipe count unchanged
- ✅ All recipes accessible

---

## Test Suite 5: Share Extension → Main App Handoff

### Test 5.1: Share from Safari → Heirloom Import

**Steps:**
1. Open Safari
2. Navigate to recipe website (e.g., AllRecipes, NYT Cooking)
3. Tap Share button
4. Select "Heirloom" share extension
5. Wait for recipe preview
6. Tap "Import" in share extension
7. **IMMEDIATELY** return to home screen
8. Open Heirloom app

**Expected Results:**
- ✅ Recipe appears in Kitchen Table within 5 seconds
- ✅ Recipe has title, ingredients, instructions
- ✅ Recipe has source URL metadata
- ✅ No error message about "stale import"

**Log Checkpoints:**
```
🔗 Deep link received: heirloom://import?id=UUID
📥 Found pending import (source: share_extension, age_seconds: X)
✅ Recipe imported from share extension (title: "Recipe Title")
```

---

### Test 5.2: Share Extension → Crash Recovery

**Steps:**
1. Repeat Test 5.1 steps 1-6
2. **FORCE QUIT** Heirloom app before opening it
3. Wait 5 seconds
4. Open Heirloom app
5. Wait 10 seconds

**Expected Results:**
- ✅ App launches successfully
- ✅ Recipe appears in Kitchen Table within 10 seconds (retry logic)
- ✅ No "stale import" error

**Log Checkpoints:**
```
⚠️ Pending import not found yet, retrying... (attempt: 1, delay: 0.5s)
⚠️ Pending import not found yet, retrying... (attempt: 2, delay: 1.0s)
📥 Found pending import (source: share_extension, age_seconds: X)
```

**Note:** Exponential backoff retry: 0.5s, 1s, 2s, 4s, 8s (max 5 attempts)

---

### Test 5.3: Share Extension → 24-Hour Staleness Window

**Steps:**
1. Repeat Test 5.1 steps 1-6
2. **Do NOT open Heirloom app**
3. Wait 30 seconds (simulate delay)
4. Open Heirloom app

**Expected Results:**
- ✅ Recipe imported successfully (within 24-hour window)
- ✅ No "stale import" warning

**Note:** Imports expire after 24 hours (was 5 minutes, extended in Task #1)

---

## Test Suite 6: Error Handling

### Test 6.1: Incomplete Recipe Rejection

**Steps:**
1. Create test image with recipe containing only 2 ingredients
2. Import via camera roll
3. Wait for extraction

**Expected Results:**
- ✅ Recipe detected
- ✅ Recipe extraction attempted
- ✅ Recipe REJECTED due to quality validation
- ✅ Error message: "Recipe has too few ingredients (2 found, need at least 3)"
- ✅ Recipe NOT added to Kitchen Table

**Log Checkpoints:**
```
❌ Recipe quality validation failed (title: "Incomplete Recipe", reason: "Recipe has too few ingredients (2 found, need at least 3)")
❌ All recipe extractions failed (attempted: 1, failures: "Incomplete Recipe: Recipe has too few ingredients...")
```

---

### Test 6.2: Partial Multi-Recipe Failure

**Steps:**
1. Import multi-recipe image where 1 recipe is incomplete
2. Wait for extraction

**Expected Results:**
- ✅ Multiple recipes detected (e.g., 3)
- ✅ Valid recipes extracted (e.g., 2)
- ✅ Invalid recipe rejected (e.g., 1)
- ✅ Partial success logged
- ✅ Valid recipes appear in Kitchen Table
- ✅ Error message shows "2/3 recipes extracted (1 failed)"

**Log Checkpoints:**
```
⚠️ Partial extraction failure (successful: 2, failed: 1, failed_titles: "Incomplete Recipe")
⚠️ Partial import success (successful: 2, failed: 1, successful_titles: "Recipe1 | Recipe2")
```

---

## Test Suite 7: Content Hash Generation

### Test 7.1: Verify Content Hash on New Recipe

**Steps:**
1. Import any single recipe
2. Open Xcode debugger or database viewer
3. Inspect Recipe model for imported recipe
4. Check `contentHash` field

**Expected Results:**
- ✅ `contentHash` field is populated
- ✅ Hash is 64-character hexadecimal string (SHA256)
- ✅ Hash format: `abc123def456...` (lowercase, no spaces)

**Example:** `contentHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"`

---

### Test 7.2: Content Hash Determinism

**Steps:**
1. Note content hash of recipe from Test 7.1
2. Import SAME recipe image again (will be skipped as duplicate)
3. Check logs for duplicate detection message
4. Verify content hashes match

**Expected Results:**
- ✅ New extraction generates identical content hash
- ✅ Duplicate detection triggers on exact hash match
- ✅ Recipe skipped with matching content_hash logged

---

## Test Suite 8: Theme Collection Images

### Test 8.1: Verify Theme Cover Images

**Steps:**
1. Navigate to Collections tab
2. Locate theme collections (e.g., "Italian Classics", "Holiday Favorites")
3. Verify cover images display

**Expected Results:**
- ✅ Theme collections show Firebase-hosted cover images
- ✅ Images load within 2 seconds
- ✅ No placeholder icons for theme collections
- ✅ Images are high quality and not pixelated

---

## Summary Checklist

After completing all tests, verify:

- [ ] Single recipe imports work from camera roll (auto-extract)
- [ ] Single recipe imports work from camera (manual extract)
- [ ] Multi-recipe detection works (2-3+ recipes per page)
- [ ] All recipes from multi-recipe import appear in collection
- [ ] Exact duplicate detection prevents re-importing same recipe
- [ ] Fuzzy duplicate detection logs warnings but allows insert
- [ ] Only ONE "Cookbook Pages" collection exists
- [ ] Collection persists across app restarts
- [ ] Share extension → main app handoff works reliably
- [ ] Share extension → crash recovery works (retry logic)
- [ ] Incomplete recipes rejected (<3 ingredients or <2 instructions)
- [ ] Partial multi-recipe failures handled gracefully
- [ ] Content hashes generated correctly (SHA256, 64-char hex)
- [ ] Theme collection images display correctly

---

## Troubleshooting

### Issue: Recipe not appearing in collection
1. Check Kitchen Table - is recipe there?
2. Check logs for "Checkpointed recipe(s)" message
3. Verify `recipeIDs` array populated on ImportItem
4. Check collection routing logic (should use `flatMap { $0.recipeIDs }`)

### Issue: Duplicate recipes appearing
1. Check logs for duplicate detection messages
2. Verify `contentHash` field populated on both recipes
3. Check similarity threshold (0.85 for exact match)
4. Verify duplicate detection service registered in ServiceContainer

### Issue: Share extension import fails
1. Check if pending import file exists: `/Users/matthanson/Library/Group Containers/group.com.heirloom/pending_imports/`
2. Check logs for deep link handler retry attempts
3. Verify 24-hour staleness window not exceeded
4. Check share extension wait times (1.5s before deep link, 1s after)

### Issue: Multi-recipe detection finds only 1 recipe
1. Check logs for "Recipe detection completed (detected_count: X)"
2. Verify AIRecipeDetector prompt includes multi-recipe instructions
3. Check if recipes have distinct bounding boxes
4. Verify extraction uses `extractRecipesFromImage` not single-recipe API

---

## Test Results Template

**Tester:** _________________
**Date:** _________________
**Build:** _________________

| Test ID | Test Name | Pass/Fail | Notes |
|---------|-----------|-----------|-------|
| 1.1 | Camera Roll Single Recipe | ☐ | |
| 1.2 | Camera Capture Single Recipe | ☐ | |
| 2.1 | Dual Recipe Import | ☐ | |
| 2.2 | Triple Recipe Import | ☐ | |
| 3.1 | Exact Duplicate Prevention | ☐ | |
| 3.2 | Fuzzy Duplicate Detection | ☐ | |
| 4.1 | Single Collection Verification | ☐ | |
| 4.2 | Collection Persistence | ☐ | |
| 5.1 | Share Extension Import | ☐ | |
| 5.2 | Share Extension Crash Recovery | ☐ | |
| 5.3 | Share Extension 24h Window | ☐ | |
| 6.1 | Incomplete Recipe Rejection | ☐ | |
| 6.2 | Partial Multi-Recipe Failure | ☐ | |
| 7.1 | Content Hash Generation | ☐ | |
| 7.2 | Content Hash Determinism | ☐ | |
| 8.1 | Theme Collection Images | ☐ | |

**Overall Result:** ☐ Pass ☐ Fail
**Critical Issues Found:** ___________________________________

---

## Test Suite 9: Unified Collection Routing (Task #3)

### Test 9.1: Cookbook Import via ImportJobManager Uses CollectionRouter

**Steps:**
1. Import cookbook page via camera roll
2. Check logs for "Adding recipes to collection via CollectionRouter" message
3. Verify recipes appear in collection

**Expected Results:**
- ✅ Log shows "Adding recipes to collection via CollectionRouter"
- ✅ Log shows "Successfully routed recipes to collection via CollectionRouter"
- ✅ Recipes appear in correct collection
- ✅ Collection consolidation works (multiple imports go to same "Cookbook Pages" collection)

**Log Checkpoints:**
```
Adding recipes to collection via CollectionRouter (items_processed: X, recipes_extracted: Y, avg_recipes_per_item: Z)
Routed Y recipes to cookbook collection (cookbook: "Cookbook Pages", count: "Y", collection_id: "UUID")
Successfully routed recipes to collection via CollectionRouter (cookbook: "Cookbook Pages", successful_recipes: Y)
```

---

### Test 9.2: Multi-Recipe Import with Job-Level Collection Tracking

**Steps:**
1. Import multi-recipe cookbook page (2-3 recipes)
2. Verify all recipes go to same collection
3. Import another page from same job
4. Verify uses same collection (job tracking)

**Expected Results:**
- ✅ All recipes from first page in same collection
- ✅ All recipes from second page in same collection
- ✅ Log shows "Reusing collection from job cache" for second page
- ✅ Only ONE collection created for entire job

**Log Checkpoints:**
```
Routed 2 recipes to cookbook collection (first page)
Reusing collection from job cache (job_id: "UUID", collection_id: "UUID")
Routed 3 recipes to cookbook collection (second page)
```

---

### Test 9.3: URL Import Multi-Recipe Support

**Steps:**
1. Import recipe URL that returns multiple recipes (if supported by scraper)
2. Verify all recipes appear in "From Web" collection

**Expected Results:**
- ✅ All recipes appear in "From Web" collection
- ✅ Log shows "Routed URL import(s) to From Web (recipe_count: X)"
- ✅ No duplicate collections created

**Note:** Currently most URL scrapers return single recipes, but infrastructure supports multi-recipe.

---

### Test 9.4: Video Import Multi-Recipe Support

**Steps:**
1. Import video with multiple recipes (if supported)
2. Verify all recipes appear in "From Videos" collection

**Expected Results:**
- ✅ All recipes appear in "From Videos" collection
- ✅ Log shows "Routed video import(s) to From Videos (recipe_count: X)"
- ✅ No duplicate collections created

**Note:** Infrastructure supports multi-recipe video imports.

---

### Test 9.5: Photo Import Multi-Recipe Support

**Steps:**
1. Import photo with multiple recipes via OCRReviewView
2. Verify all recipes appear in "From Photos" collection

**Expected Results:**
- ✅ All recipes appear in "From Photos" collection
- ✅ Log shows "Routed photo import(s) to From Photos (recipe_count: X)"
- ✅ No duplicate collections created

---

## Summary Checklist (Updated for Task #3)

After completing all tests, verify:

- [ ] Single recipe imports work from camera roll (auto-extract)
- [ ] Single recipe imports work from camera (manual extract)
- [ ] Multi-recipe detection works (2-3+ recipes per page)
- [ ] All recipes from multi-recipe import appear in collection
- [ ] Exact duplicate detection prevents re-importing same recipe
- [ ] Fuzzy duplicate detection logs warnings but allows insert
- [ ] Only ONE "Cookbook Pages" collection exists
- [ ] Collection persists across app restarts
- [ ] Share extension → main app handoff works reliably
- [ ] Share extension → crash recovery works (retry logic)
- [ ] Incomplete recipes rejected (<3 ingredients or <2 instructions)
- [ ] Partial multi-recipe failures handled gracefully
- [ ] Content hashes generated correctly (SHA256, 64-char hex)
- [ ] Theme collection images display correctly
- [ ] **ImportJobManager uses CollectionRouter** (Task #3)
- [ ] **Job-level collection tracking prevents duplicate collections** (Task #3)
- [ ] **All import paths support multi-recipe routing** (Task #3)
- [ ] **"Cookbook Pages" consolidation works globally** (Task #3)

---

## Test Results Template (Updated)

**Tester:** _________________
**Date:** _________________
**Build:** _________________

| Test ID | Test Name | Pass/Fail | Notes |
|---------|-----------|-----------|-------|
| 1.1 | Camera Roll Single Recipe | ☐ | |
| 1.2 | Camera Capture Single Recipe | ☐ | |
| 2.1 | Dual Recipe Import | ☐ | |
| 2.2 | Triple Recipe Import | ☐ | |
| 3.1 | Exact Duplicate Prevention | ☐ | |
| 3.2 | Fuzzy Duplicate Detection | ☐ | |
| 4.1 | Single Collection Verification | ☐ | |
| 4.2 | Collection Persistence | ☐ | |
| 5.1 | Share Extension Import | ☐ | |
| 5.2 | Share Extension Crash Recovery | ☐ | |
| 5.3 | Share Extension 24h Window | ☐ | |
| 6.1 | Incomplete Recipe Rejection | ☐ | |
| 6.2 | Partial Multi-Recipe Failure | ☐ | |
| 7.1 | Content Hash Generation | ☐ | |
| 7.2 | Content Hash Determinism | ☐ | |
| 8.1 | Theme Collection Images | ☐ | |
| **9.1** | **Cookbook Import Uses CollectionRouter** | ☐ | |
| **9.2** | **Multi-Recipe Job-Level Tracking** | ☐ | |
| **9.3** | **URL Import Multi-Recipe Support** | ☐ | |
| **9.4** | **Video Import Multi-Recipe Support** | ☐ | |
| **9.5** | **Photo Import Multi-Recipe Support** | ☐ | |

**Overall Result:** ☐ Pass ☐ Fail
**Critical Issues Found:** ___________________________________

---

## Test Suite 10: Bottom Sheet Dismissal (Task #13)

### Test 10.1: Scan Cookbook Sheet Dismisses After Import

**Steps:**
1. Open app and tap "+" button
2. Select "Scan Cookbook"
3. Tap camera icon to select photo from library
4. Select a recipe image
5. Wait for automatic extraction to start

**Expected Results:**
- ✅ CookbookScannerView sheet dismisses immediately after extraction starts
- ✅ User sees ImportProgressBottomBanner at bottom of screen
- ✅ NO stacked sheets (sheet on top of sheet)
- ✅ User can see Kitchen Table in background

**Log Checkpoints:**
```
Creating cookbook import job (collectionName: "Cookbook Pages")
Cookbook import job started successfully (jobId: "UUID")
```

**Failure Criteria:**
- ❌ CookbookScannerView sheet remains open
- ❌ ImportProgressView sheet appears on top of CookbookScannerView sheet
- ❌ User has to manually dismiss CookbookScannerView

---

### Test 10.2: Scan Cookbook Sheet Dismisses After Camera Capture

**Steps:**
1. Open app and tap "+" button
2. Select "Scan Cookbook"
3. Tap "Open Camera"
4. Take photo of recipe page
5. Tap "Use Photo"
6. Tap "Extract Recipe" button
7. Wait for extraction to start

**Expected Results:**
- ✅ CookbookScannerView sheet dismisses after tapping "Extract Recipe"
- ✅ ImportProgressBottomBanner appears
- ✅ Sheet properly dismissed (no stack)

---

### Test 10.3: Scan Cookbook Sheet Dismisses After Batch Import

**Steps:**
1. Open app and tap "+" button
2. Select "Scan Cookbook"
3. Tap "Choose Photos"
4. Select 3-5 recipe images
5. Wait for batch import to start

**Expected Results:**
- ✅ CookbookScannerView sheet dismisses immediately
- ✅ ImportProgressBottomBanner shows batch progress
- ✅ No lingering sheets

**Note:** This was already working correctly (line 638 had `dismiss()`)

---

### Test 10.4: Scan Cookbook Sheet Dismisses After PDF Import

**Steps:**
1. Open app and tap "+" button
2. Select "Scan Cookbook"
3. Tap "Import PDF"
4. Select a PDF file
5. Configure pages
6. Start import

**Expected Results:**
- ✅ CookbookScannerView sheet dismisses when PDF job created
- ✅ ImportProgressBottomBanner appears
- ✅ Sheet properly dismissed

**Note:** This was already working correctly (line 139 had `onJobCreated` callback)

---

## Summary Checklist (Updated for Task #13)

After completing all tests, verify:

- [ ] Single recipe imports work from camera roll (auto-extract)
- [ ] Single recipe imports work from camera (manual extract)
- [ ] Multi-recipe detection works (2-3+ recipes per page)
- [ ] All recipes from multi-recipe import appear in collection
- [ ] Exact duplicate detection prevents re-importing same recipe
- [ ] Fuzzy duplicate detection logs warnings but allows insert
- [ ] Only ONE "Cookbook Pages" collection exists
- [ ] Collection persists across app restarts
- [ ] Share extension → main app handoff works reliably
- [ ] Share extension → crash recovery works (retry logic)
- [ ] Incomplete recipes rejected (<3 ingredients or <2 instructions)
- [ ] Partial multi-recipe failures handled gracefully
- [ ] Content hashes generated correctly (SHA256, 64-char hex)
- [ ] Theme collection images display correctly
- [ ] ImportJobManager uses CollectionRouter (Task #3)
- [ ] Job-level collection tracking prevents duplicate collections (Task #3)
- [ ] All import paths support multi-recipe routing (Task #3)
- [ ] "Cookbook Pages" consolidation works globally (Task #3)
- [ ] **CookbookScannerView sheet dismisses after single photo import** (Task #13)
- [ ] **CookbookScannerView sheet dismisses after camera capture** (Task #13)
- [ ] **CookbookScannerView sheet dismisses after batch import** (Task #13)
- [ ] **CookbookScannerView sheet dismisses after PDF import** (Task #13)

---

## Test Results Template (Updated)

**Tester:** _________________
**Date:** _________________
**Build:** _________________

| Test ID | Test Name | Pass/Fail | Notes |
|---------|-----------|-----------|-------|
| 1.1 | Camera Roll Single Recipe | ☐ | |
| 1.2 | Camera Capture Single Recipe | ☐ | |
| 2.1 | Dual Recipe Import | ☐ | |
| 2.2 | Triple Recipe Import | ☐ | |
| 3.1 | Exact Duplicate Prevention | ☐ | |
| 3.2 | Fuzzy Duplicate Detection | ☐ | |
| 4.1 | Single Collection Verification | ☐ | |
| 4.2 | Collection Persistence | ☐ | |
| 5.1 | Share Extension Import | ☐ | |
| 5.2 | Share Extension Crash Recovery | ☐ | |
| 5.3 | Share Extension 24h Window | ☐ | |
| 6.1 | Incomplete Recipe Rejection | ☐ | |
| 6.2 | Partial Multi-Recipe Failure | ☐ | |
| 7.1 | Content Hash Generation | ☐ | |
| 7.2 | Content Hash Determinism | ☐ | |
| 8.1 | Theme Collection Images | ☐ | |
| 9.1 | Cookbook Import Uses CollectionRouter | ☐ | |
| 9.2 | Multi-Recipe Job-Level Tracking | ☐ | |
| 9.3 | URL Import Multi-Recipe Support | ☐ | |
| 9.4 | Video Import Multi-Recipe Support | ☐ | |
| 9.5 | Photo Import Multi-Recipe Support | ☐ | |
| **10.1** | **Single Photo Import Dismisses Sheet** | ☐ | |
| **10.2** | **Camera Capture Dismisses Sheet** | ☐ | |
| **10.3** | **Batch Import Dismisses Sheet** | ☐ | |
| **10.4** | **PDF Import Dismisses Sheet** | ☐ | |

**Overall Result:** ☐ Pass ☐ Fail
**Critical Issues Found:** ___________________________________

---

## Note on Task #11: Share Extension Deep Link Handoff

**Task #11 was completed as part of Task #1.**

All share extension deep link handoff issues were fixed in Task #1 with:
1. ✅ Extended staleness window from 5 minutes to 24 hours
2. ✅ Added retry logic with exponential backoff (0.5s, 1s, 2s, 4s, 8s - max 5 attempts)
3. ✅ Increased share extension wait times (1.5s before deep link, 1s after)

**Testing Coverage:**
- **Test 5.1**: Verifies immediate handoff works
- **Test 5.2**: Verifies crash recovery with retry logic
- **Test 5.3**: Verifies 24-hour staleness window

No additional work needed for Task #11 - it's covered by Task #1 implementation and Test Suite 5.

---

## Test Suite 11: Import Status Badges and Notifications

**Purpose:** Verify that import status is clearly visible to users through badges, notifications, and enhanced progress displays.

**Date:** 2026-02-01
**Task Reference:** #7 - Add import status badges and notifications

---

### Test 11.1: "New" Badge on Recently Imported Recipes

**Steps:**
1. Import a single recipe via camera roll
2. Wait for import to complete successfully
3. Navigate to Kitchen Table (main recipe list)
4. Locate the newly imported recipe

**Expected Results:**
- ✅ Recipe card shows "NEW" badge in red (top left, below favorite icon if present)
- ✅ Badge is visible and readable
- ✅ Badge disappears after 24 hours (can verify by changing device time)

**Visual Verification:**
```
┌─────────────────┐
│ ❤️ [Favorite]   │  ← Top left
│ NEW             │  ← "NEW" badge appears below favorite
│                 │
│   [Recipe Img]  │
│                 │
└─────────────────┘
```

**Overall Result:** ☐ Pass ☐ Fail

---

### Test 11.2: Recipe Count Badge in Progress Banner (Multi-Recipe)

**Steps:**
1. Import a cookbook page with 3+ recipes
2. While import is in progress, observe the bottom progress banner

**Expected Results:**
- ✅ Banner shows recipe count badge: "+3" (or actual count) next to progress title
- ✅ Badge is red with white text
- ✅ Badge only appears for multi-recipe imports (totalItems > 1)
- ✅ Badge disappears when import completes

**Visual Verification:**
```
┌──────────────────────────────────────┐
│ ━━━━━━━━━━━━━━━━━━ 45%              │  ← Progress bar
│ 📸 Extracting Recipes +3    45%     │  ← "+3" badge
│    2 of 3 recipes                    │  ← Subtitle
└──────────────────────────────────────┘
```

**Overall Result:** ☐ Pass ☐ Fail

---

### Test 11.3: Enhanced Progress Banner Subtitle (Phase Display)

**Steps:**
1. Import a cookbook page with 2 recipes
2. Observe subtitle text changes through import phases:
   - Analysis phase: "Analyzing images • 0 of 2"
   - Extraction phase: "Extracting recipes • 1 of 2"
   - Finalization: "Finalizing import • 2 of 2"

**Expected Results:**
- ✅ Subtitle shows current phase name (e.g., "Extracting recipes")
- ✅ Subtitle shows progress: "X of Y" for multi-recipe
- ✅ Subtitle shows collection name on completion: "Saved to [Collection Name]"

**Log Checkpoints:**
```
Phase: Analysis → "Analyzing images • 0 of 2"
Phase: Extraction → "Extracting recipes • 1 of 2"
Phase: Completed → "Saved to Cookbook Pages"
```

**Overall Result:** ☐ Pass ☐ Fail

---

### Test 11.4: Success Toast Notification (Single Recipe)

**Steps:**
1. Import a single recipe from camera roll
2. Wait for import to complete successfully
3. Observe toast notification

**Expected Results:**
- ✅ Green success toast appears after import completes
- ✅ Toast title: "1 Recipe Imported"
- ✅ Toast message: "Saved to [Collection Name]"
- ✅ Toast auto-dismisses after ~3 seconds

**Visual Verification:**
```
┌────────────────────────────────┐
│ ✅ 1 Recipe Imported           │
│    Saved to Cookbook Pages     │
└────────────────────────────────┘
```

**Overall Result:** ☐ Pass ☐ Fail

---

### Test 11.5: Success Toast Notification (Multi-Recipe)

**Steps:**
1. Import a cookbook page with 3 recipes
2. Wait for all recipes to import successfully
3. Observe toast notification

**Expected Results:**
- ✅ Green success toast appears
- ✅ Toast title: "3 Recipes Imported" (plural)
- ✅ Toast message: "Saved to [Collection Name]"

**Visual Verification:**
```
┌────────────────────────────────┐
│ ✅ 3 Recipes Imported          │
│    Saved to Italian Cookbook   │
└────────────────────────────────┘
```

**Overall Result:** ☐ Pass ☐ Fail

---

### Test 11.6: Partial Success Toast (Some Failures)

**Steps:**
1. Import a cookbook page with 3 recipes where 1 recipe has quality issues (will fail)
2. Wait for import to complete
3. Observe toast notification

**Expected Results:**
- ✅ Orange warning toast appears
- ✅ Toast title: "2 Recipes Imported" (successful count)
- ✅ Toast message: "1 failed • Saved to [Collection Name]"

**Visual Verification:**
```
┌────────────────────────────────┐
│ ⚠️ 2 Recipes Imported          │
│    1 failed • Saved to Italian │
└────────────────────────────────┘
```

**Overall Result:** ☐ Pass ☐ Fail

---

### Test 11.7: Error Toast Notification (All Failed)

**Steps:**
1. Import a low-quality image that will fail extraction
2. Wait for import to fail
3. Observe toast notification

**Expected Results:**
- ✅ Red error toast appears
- ✅ Toast title: "Import Failed"
- ✅ Toast message: "All X recipe(s) failed to import"

**Visual Verification:**
```
┌────────────────────────────────┐
│ ❌ Import Failed               │
│    All 1 recipe failed to      │
│    import                       │
└────────────────────────────────┘
```

**Overall Result:** ☐ Pass ☐ Fail

---

### Test 11.8: Failed Import Icon in Progress Banner

**Steps:**
1. Import a low-quality image that will fail
2. Wait for import to fail
3. Observe progress banner state

**Expected Results:**
- ✅ Progress banner shows red exclamation icon instead of percentage
- ✅ Banner remains visible after failure (allows retry)
- ✅ Subtitle shows: "Tap to retry from last checkpoint"

**Visual Verification:**
```
┌──────────────────────────────────────┐
│ ⚠️ Import Interrupted         ❌     │  ← Red error icon
│    Tap to retry from last            │
│    checkpoint                         │
└──────────────────────────────────────┘
```

**Overall Result:** ☐ Pass ☐ Fail

---

### Test 11.9: Collection Name Display in Toasts

**Steps:**
1. Import recipe with custom cookbook name: "My Italian Cookbook"
2. Observe success toast
3. Import recipe with default "Cookbook Pages"
4. Observe success toast

**Expected Results:**
- ✅ Custom collection: "Saved to My Italian Cookbook"
- ✅ Default collection: "Saved to Cookbook Pages"
- ✅ No collection name: "Saved to your library"

**Overall Result:** ☐ Pass ☐ Fail

---

### Test 11.10: Badge Visibility Across Different Recipe States

**Steps:**
1. Import 3 recipes at different times:
   - Recipe A: Just imported (< 1 hour ago)
   - Recipe B: Imported 12 hours ago
   - Recipe C: Imported 25 hours ago (use device time change)
2. Mark Recipe A as favorite
3. View all recipes in Kitchen Table

**Expected Results:**
- ✅ Recipe A: Shows both favorite ❤️ AND "NEW" badge (stacked vertically)
- ✅ Recipe B: Shows only "NEW" badge (< 24 hours)
- ✅ Recipe C: No "NEW" badge (> 24 hours)
- ✅ Badges don't overlap or obscure recipe image

**Visual Verification:**
```
Recipe A (< 1hr, favorite):
┌─────────────────┐
│ ❤️              │  ← Favorite
│ NEW             │  ← New badge
│   [Recipe Img]  │
└─────────────────┘

Recipe B (12hrs):
┌─────────────────┐
│ NEW             │  ← Only new badge
│   [Recipe Img]  │
└─────────────────┘

Recipe C (25hrs):
┌─────────────────┐
│   [Recipe Img]  │  ← No badge
└─────────────────┘
```

**Overall Result:** ☐ Pass ☐ Fail

---

## Summary: Import Status Badges and Notifications

**Test Coverage:**
- ✅ "NEW" badge on recently imported recipes (< 24 hours)
- ✅ Recipe count badge in progress banner (+X)
- ✅ Phase-specific progress messages
- ✅ Success toast notifications (single and multi-recipe)
- ✅ Partial success toast (some failures)
- ✅ Error toast (all failed)
- ✅ Failed import icon in banner
- ✅ Collection name display in toasts
- ✅ Badge visibility and stacking

**Overall Result:** ☐ Pass ☐ Fail
**Critical Issues Found:** ___________________________________

---
