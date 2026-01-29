# Comprehensive Testing Checklist - Unified Collection Cards

**Branch:** `feature/standard-card-refactor`
**Date:** 2026-01-28
**Phases Tested:** 1-7 (Complete)

---

## Pre-Test Setup

- [+] Build succeeded
- [+] App launches without crashes
- [+] Navigate to Collections tab

---

## Test 1: Visual Consistency ✓

**Goal:** Verify all collection cards use unified vertical layout

We are missing a recipe for homemade beef stroganoff skillet. Please analyze the recipe and give me a prompt to generate the missing image with the right filename

### Test Steps:
1. Navigate to Collections tab
2. Observe "Your Discoveries" section (themed collections)
3. Observe "My Collections" section (standard collections)

### Expected Results:
- [+] All cards have same vertical layout (60/40 image split)
- [+] All cards have same height (~220pt including info bar)
- [+] All cards have same rounded corners (16pt image, 20pt card)
- [+] All cards have same shadow style
- [+] Theme collections show "Day X" or "Complete" badge in top-right
- [+] Standard collections show recipe count badge in bottom-right

### Pass Criteria:
Visual parity between themed and standard collections ✓


---

## Test 2: Empty Collection + Affordance (Large Slot)

**Goal:** Verify empty collections show prominent + affordance

### Test Steps:
1. Create a new empty user collection:
   - Tap "+" in Collections tab
   - Name it "Test Empty Collection"
   - Don't add any recipes
2. Observe the collection card in "My Collections"
3. Tap the large + affordance

Added empty collection but it did not appear in my collections

### Expected Results:
- [-] Large + icon (48pt) appears in hero image slot (60%)
- [-] Text reads "Add Your First Recipe"
- [-] Subtitle says "Tap to add a recipe"
- [-] Tapping opens add recipe menu
- [-] Small slots (40%) show placeholders

### Pass Criteria:
Empty collections are immediately actionable ✓

---

## Test 3: Single Recipe + Affordance (Small Slot)

**Goal:** Verify single-recipe collections show + affordance in small slot

### Test Steps:
1. Add ONE recipe to "Test Empty Collection"
2. Return to Collections tab
3. Observe the collection card

### Expected Results:
- [n/a] Recipe image appears in large slot (60%) OR AI background if generated
- [n/a] First small slot shows recipe thumbnail
- [n/a] Second small slot shows + affordance with "Add" text
- [n/a] Tapping + affordance opens add recipe menu
- [n/a] After adding 2nd recipe, + affordance disappears

### Pass Criteria:
+ affordance appears and functions correctly ✓

---

## Test 4: Type-Specific + Affordance Routing

**Goal:** Verify + affordance routes to correct import flow based on collection type

### Test Steps for Each Collection Type:

#### 4a. Web Imports Collection
1. Create empty web import (import 1 web recipe, then delete it)
2. Observe + affordance subtitle
3. Tap + affordance

Web import took a while to load the imagery in my collections.


**Expected:**
- [+] Subtitle: "Tap to import from a website" (works but text says 'add')
- [+] Opens RecipeImportView (web link import)

#### 4b. Video Imports Collection
1. Create empty video import collection (I can not do this because the section is auto added when I import a video)
2. Tap + affordance (works, I imported a video it created a video imports section, and then the add button room me to the right place)

**Expected:**
- [+] Subtitle: "Tap to import from a video"
- [+] Opens UnifiedVideoImportView

#### 4c. Cookbook Pages Collection
1. Create empty cookbook collection
2. Tap + affordance
Fails - still puts cookbook in 'shared recipes' collection instead of collection named after cookbook. We built a feature for this a while ago which scans the cookbook for its name and uses it to create a collection but for some reason this issue has persisted.

**Expected:**
- [x] Subtitle: "Tap to scan a cookbook page"
- [x] Opens CookbookScannerView

#### 4d. Photo Imports Collection
1. Create empty photo imports collection
2. Tap + affordance

Does not work. Recipe gets processed but collection is not created. Do we have a my collections limit or something?

**Expected:**
- [ ] Subtitle: "Tap to import from photos"
- [ ] Opens BulkImportView (photo import)
Sending multiple images from camera roll to heirloom does not process all images. Using this method still doesnt create an images collection
### Pass Criteria:
Each collection type routes to its specific import flow ✓

---

## Test 5: AI Background Generation

**Goal:** Verify AI generation works with type-specific prompts

### Test Steps:
1. Navigate to a collection with recipes (e.g., "Web Imports")
2. Long-press collection card
3. Tap "Generate with AI" from context menu
4. Wait for generation
5. Observe the result

### Expected Results:
- [ ] Loading indicator appears
- [ ] Toast shows "Generating background..."
- [ ] Background appears in large slot (60%)
- [ ] Recipe thumbnails remain in small slots (40%)
- [ ] Image matches collection type aesthetic:
  - **Web Imports**: Modern kitchen with tablet
  - **Video Imports**: Content creator filming
  - **Cookbook**: Vintage cookbook with notes
  - **Photo Imports**: Overhead flat lay

### Test for Multiple Collection Types:
- [ ] Web Imports AI generation
- [ ] Video Imports AI generation
- [ ] Cookbook AI generation
- [ ] User-created collection AI generation

### Pass Criteria:
AI backgrounds display correctly with type-specific styling ✓

---

## Test 6: Collection Settings - Background Customization

**Goal:** Verify background customization UI works

### Test Steps:
1. Navigate to any collection
2. Tap gear icon (top-right) OR ellipses menu → "Collection Settings"
3. Observe "Background" section

Created ai image, but did not replace for your discoveries collections. Worked for 'my collections'/

### Test 6a: Toggle Custom Background
- [+] Toggle "Use Custom Background" ON
- [+] Photo picker and AI generation options appear
- [+] Toggle OFF
- [n/a] Custom background is cleared
- [n/a] Card reverts to recipe collage

Was able to see this option, but choosing image did not work. When in collections, the eclipses menu did not do anything when clicked

### Test 6b: Choose Photo
1. Toggle "Use Custom Background" ON
2. Tap "Choose Photo"
3. Select a photo from library
4. Observe result (result not visible)

**Expected:**
- [+] Photo picker opens
- [+] Selected photo appears as preview
- [+] Collection card shows custom photo in large slot
- [+] "Remove Background" button appears

### Test 6c: Generate with AI
1. Toggle "Use Custom Background" ON
2. Tap "Generate with AI"
3. Wait for generation

**Expected:**
- [+] Loading indicator appears
- [+] Toast notification on completion
- [+] Generated image appears as preview
- [+] Collection card shows AI image in large slot (does not work with theme collections) 

### Test 6d: Remove Background
1. With custom or AI background active
2. Tap "Remove Background"

Long pressing collection card does not give example to remove ai image)

**Expected:**
- [n/a] Background is removed
- [n/a] Toggle switches OFF
- [n/a] Card reverts to recipe collage

### Pass Criteria:
All background customization options work correctly ✓

---

## Test 7: Collection Naming & Editability

**Goal:** Verify system collections use displayName and can't be renamed

### Test Steps:
1. Navigate to Collection Settings for each system collection type
2. Observe the name field

### Expected Results:

**System Collections (read-only):**
- [+] "Web Imports" - Name field disabled, displays as "Web Imports"
- [+] "Video Imports" - Name field disabled, displays as "Video Imports"
- [na] "Cookbook Pages" - Name field disabled, displays as "Cookbook Pages"
- [na] "Photo Imports" - Name field disabled, displays as "Photo Imports"
- [na] "From Friends" - Name field disabled, displays as "From Friends"
- [+] Warning text: "System collection names cannot be changed"

**User Collections (editable):**
- [+] User-created collections - Name field enabled
- [+] Theme collections - Name field enabled
- [+] No warning text

### Pass Criteria:
System collections show correct displayName and prevent editing ✓

---

## Test 8: Empty Collection Visibility

**Goal:** Verify empty auto-generated collections are hidden

### Test Steps:
1. Navigate to Collections tab
2. Observe "My Collections" section
3. Check which collections are visible

### Expected Results:
**Hidden (if empty):**
- [+] Web Imports (if no web recipes imported)
- [+] Video Imports (if no video recipes imported)
- [+] Cookbook Pages (if no cookbook pages scanned)
- [+] Photo Imports (if no photos imported)
- [+] From Friends (if no shared recipes received)

**Always Visible (even if empty):**
- [n/a] User-created collections (not appearing)
- [+] Theme collections

### Pass Criteria:
Empty auto-generated collections are automatically hidden ✓

---

## Test 9: Web Import Performance

**Goal:** Verify web imports dismiss immediately with background processing

### Test Steps:
1. Tap "+" → "Import from Web"
2. Paste a recipe URL (e.g., from AllRecipes)
3. Tap "Import Recipe"
4. Wait for preview
5. Tap "Save"
6. Observe timing

### Expected Results:
- [+] "Recipe imported!" toast appears immediately (<1s)
- [+] Sheet dismisses immediately (<1s)
- [+] Recipe appears in list with placeholder ingredients
- [+] Recipe image loads progressively in background
- [+] Parsed ingredients appear progressively in background
- [+] No blocking spinner states

### Pass Criteria:
Sheet dismisses in <1 second, background processing completes without blocking UI ✓
Works but the image takes more time to load than the recipe card resulting in a placeholder image for a few seconds.
---

## Test 10: Context Menu Integration

**Goal:** Verify context menus work on both card types

### Test Steps:
1. Long-press on themed collection card
2. Long-press on standard collection card

### Expected Results:
Both card types show:
- [+] "Generate with AI" option
- [+] "Collection Settings" option
- [+] Options are functional
- [+] Loading states appear during AI generation

### Pass Criteria:
Context menus work identically on both card types ✓

---

## Test 11: Ellipses Menu → Settings

**Goal:** Verify gear button in collection detail opens settings

### Test Steps:
1. Navigate into any collection
2. Tap gear icon (toolbar, top-right) no gear icon, only ellipses, and when pressed nothing happens but the button ui responds to press

### Expected Results:
- [-] CollectionSettingsView opens
- [-] All settings sections visible
- [-] Changes save correctly

### Pass Criteria:
Settings accessible from collection detail view ✓

---

## Test 12: Edge Cases & Error Handling

**Goal:** Test unusual scenarios

### Test 12a: Collection with No Images
1. Create collection with recipes that have no images
2. Observe card

Not showing up

**Expected:**
- [-] Large slot shows placeholder with collection icon
- [-] Small slots show placeholders
- [-] No crashes

### Test 12b: AI Generation Failure
1. Attempt AI generation with no network
2. Observe error handling

**Expected:**
- [havent encountered] Error toast appears
- [havent encountered] Card doesn't break
- [havent encountered] Can retry

### Test 12c: Very Long Collection Names
1. Create collection with 50+ character name
2. Observe card

**Expected:**
- [+] Name truncates with ellipsis
- [+] Card layout doesn't break
- [+] No text overflow

### Test 12d: Rapid Collection Creation
1. Create 5 collections quickly
2. Observe list

Cant create collections and have them appear yet

**Expected:**
- [n/a] All collections appear
- [n/a] No duplicates
- [n/a] No crashes

### Pass Criteria:
App handles edge cases gracefully ✓

---

## Test 13: Theme Collections (Backward Compatibility)

**Goal:** Verify themed collections still work correctly

### Test Steps:
1. Navigate to "Your Discoveries" section
2. Observe themed collections
3. Tap into a themed collection

### Expected Results:
- [+] Theme cover image in large slot (60%)
- [+] Recipe thumbnails in small slots (40%)
- [+] "Day X" badge visible in top-right
- [+] Progress indicator in info bar (it looks like there is a tappable > affordance but there is no ux here, we should get rid of the > or have it go somewhere useful)
- [+] Unlock mechanics work as before
- [+] No visual regressions

### Pass Criteria:
Theme collections function identically to before refactor ✓

Cant tell if daily unlocks work, we will have to use the terminal to change the simulator date and check 

---

## Test 14: Memory & Performance

**Goal:** Verify no memory leaks or performance degradation

### Test Steps:
1. Scroll through Collections tab rapidly
2. Open/close multiple collections
3. Generate 3-4 AI backgrounds
4. Monitor performance

### Expected Results:
- [+] Smooth scrolling (60fps)
- [+] No stuttering when loading images
- [+] No memory warnings
- [+] AI generation completes in reasonable time (~10-15s)

### Pass Criteria:
No performance regressions ✓

---

## Test 15: Recipe Sharing & "From Friends" Collection

**Goal:** Verify sharing functionality works with unified cards

### Test Steps:

#### 15a: Share Recipe from Collection
1. Navigate into any collection with recipes
2. Long-press a recipe card
3. Tap "Share Recipe" from context menu
4. Share to another device/user

**Expected:**
- [ ] Share sheet opens
- [ ] Recipe data includes all details
- [ ] Recipient receives recipe correctly

#### 15b: Receive Shared Recipe
1. Have another user share a recipe to you
2. Accept the shared recipe
3. Navigate to Collections tab
4. Observe "From Friends" collection

**Expected:**
- [ ] "From Friends" collection appears (if it has recipes)
- [ ] Collection uses UnifiedCollectionCard
- [ ] Shared recipe appears in collection
- [ ] Card shows recipe thumbnails correctly
- [ ] Collection name displays as "From Friends"

#### 15c: Share Collection
1. Navigate to Collection Settings
2. If share option exists, tap "Share Collection"
3. Share to another user

**Expected:**
- [ ] Share functionality works
- [ ] Recipient can view collection
- [ ] Unified card styling preserved

### Pass Criteria:
Sharing works correctly with unified collection cards ✓

---

## Summary Checklist

- [ ] Test 1: Visual Consistency
- [ ] Test 2: Empty Collection + Affordance (Large)
- [ ] Test 3: Single Recipe + Affordance (Small)
- [ ] Test 4: Type-Specific Routing
- [ ] Test 5: AI Background Generation
- [ ] Test 6: Collection Settings UI
- [ ] Test 7: Collection Naming
- [ ] Test 8: Empty Collection Visibility
- [ ] Test 9: Web Import Performance
- [ ] Test 10: Context Menu Integration
- [ ] Test 11: Ellipses Menu → Settings
- [ ] Test 12: Edge Cases
- [ ] Test 13: Theme Collections
- [ ] Test 14: Memory & Performance
- [ ] Test 15: Recipe Sharing & "From Friends" Collection

---

## Issues Found

**Document any issues discovered during testing:**

### Issue 1:
- **Test:**
- **Expected:**
- **Actual:**
- **Severity:**

### Issue 2:
- **Test:**
- **Expected:**
- **Actual:**
- **Severity:**

---

## Final Sign-Off

- [ ] All tests passed
- [ ] No critical issues found
- [ ] Minor issues documented
- [ ] Ready for merge to main

**Tested By:** _______________
**Date:** _______________
**Build:** _______________
