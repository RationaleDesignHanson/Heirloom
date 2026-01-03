# CRDT Multi-Device Testing Checklist
**Version 2.0 - Conflict-Free Recipe Sync**

This document outlines comprehensive testing scenarios for the CRDT-based recipe sync system. Test these scenarios across multiple devices (iPhone, iPad, Mac) to ensure conflict-free merging works correctly.

---

## Prerequisites

- [ ] At least 2 test devices (iPhone + iPad, or iPhone + Mac)
- [ ] Same Firebase account signed in on all devices
- [ ] Test recipe created and synced to Firebase
- [ ] Network connectivity on all devices

---

## Test Scenario 1: Sequential Edits (No Conflicts)
**Expected Result**: Auto-merge with no conflict UI

### Steps:
1. **Device A (iPhone)**:
   - [ ] Open test recipe
   - [ ] Edit title: "Lasagna" → "Grandma's Lasagna"
   - [ ] Save and sync
   - [ ] Wait 5 seconds for sync to complete

2. **Device B (iPad)**:
   - [ ] Open same recipe
   - [ ] Verify title shows "Grandma's Lasagna"
   - [ ] Edit servings: "4 servings" → "6 servings"
   - [ ] Save and sync

3. **Device A (iPhone)**:
   - [ ] Pull to refresh recipes list
   - [ ] Open recipe
   - [ ] **Verify**: Title = "Grandma's Lasagna", Servings = "6 servings"
   - [ ] **Verify**: No conflict badge appears
   - [ ] **Verify**: No conflict UI shown

**Result**: ✅ PASS / ❌ FAIL
**Notes**:

---

## Test Scenario 2: Concurrent Edits on Different Fields (Auto-Merge)
**Expected Result**: Auto-merge with no conflict UI

### Steps:
1. **Setup**:
   - [ ] Both devices have recipe open
   - [ ] Turn on Airplane Mode on both devices

2. **Device A (iPhone) - Offline**:
   - [ ] Edit title: "Lasagna" → "Mom's Lasagna"
   - [ ] Edit servings: "4 servings" → "6 servings"
   - [ ] Save (stays local only)

3. **Device B (iPad) - Offline**:
   - [ ] Edit cook time: "30 min" → "45 min"
   - [ ] Edit notes: Add "Family favorite recipe"
   - [ ] Save (stays local only)

4. **Bring Both Online**:
   - [ ] Turn off Airplane Mode on Device A
   - [ ] Wait 10 seconds for sync
   - [ ] Turn off Airplane Mode on Device B
   - [ ] Wait 10 seconds for sync

5. **Verification** (on both devices):
   - [ ] **Verify**: Title = "Mom's Lasagna" (from Device A)
   - [ ] **Verify**: Servings = "6 servings" (from Device A)
   - [ ] **Verify**: Cook Time = "45 min" (from Device B)
   - [ ] **Verify**: Notes = "Family favorite recipe" (from Device B)
   - [ ] **Verify**: No conflict badge
   - [ ] **Verify**: No conflict UI shown

**Result**: ✅ PASS / ❌ FAIL
**Notes**:

---

## Test Scenario 3: Concurrent Edits on Same Field (Conflict)
**Expected Result**: Conflict UI appears, user must resolve

### Steps:
1. **Setup**:
   - [ ] Both devices have recipe open
   - [ ] Turn on Airplane Mode on both devices

2. **Device A (iPhone) - Offline**:
   - [ ] Edit servings: "4 servings" → "2 servings"
   - [ ] Save

3. **Device B (iPad) - Offline**:
   - [ ] Edit servings: "4 servings" → "6 servings"
   - [ ] Save

4. **Bring Both Online**:
   - [ ] Turn off Airplane Mode on Device A
   - [ ] Wait for sync
   - [ ] Turn off Airplane Mode on Device B
   - [ ] Wait for sync

5. **Verification** (on Device A):
   - [ ] **Verify**: Red conflict badge appears on recipe card
   - [ ] **Verify**: Tap recipe opens conflict resolution UI
   - [ ] **Verify**: Header shows "Merge Recipe Changes"
   - [ ] **Verify**: Conflict card shows servings conflict
   - [ ] **Verify**: Left card shows "Your Version: 2 servings"
   - [ ] **Verify**: Right card shows "iPad's Version: 6 servings"

6. **Resolve Conflict**:
   - [ ] Tap on "Your Version" (2 servings)
   - [ ] **Verify**: Checkmark appears
   - [ ] **Verify**: Progress bar updates to 1/1
   - [ ] Tap "Preview Merged Recipe"
   - [ ] **Verify**: Preview shows servings = "2 servings"
   - [ ] Tap "Save Merged Recipe"
   - [ ] **Verify**: Success animation plays
   - [ ] **Verify**: Returns to recipe detail
   - [ ] **Verify**: Conflict badge disappears

7. **Verification** (on Device B):
   - [ ] Pull to refresh
   - [ ] **Verify**: Servings now shows "2 servings"
   - [ ] **Verify**: No conflict badge

**Result**: ✅ PASS / ❌ FAIL
**Notes**:

---

## Test Scenario 4: Multiple Conflicts on Different Fields
**Expected Result**: Conflict UI shows all conflicts, user resolves each

### Steps:
1. **Setup**:
   - [ ] Both devices have recipe open
   - [ ] Turn on Airplane Mode on both devices

2. **Device A (iPhone) - Offline**:
   - [ ] Edit servings: "4 servings" → "2 servings"
   - [ ] Edit cook time: "30 min" → "45 min"
   - [ ] Edit prep time: "15 min" → "20 min"
   - [ ] Save

3. **Device B (iPad) - Offline**:
   - [ ] Edit servings: "4 servings" → "6 servings"
   - [ ] Edit cook time: "30 min" → "60 min"
   - [ ] Edit prep time: "15 min" → "25 min"
   - [ ] Save

4. **Bring Both Online**:
   - [ ] Turn off Airplane Mode on both devices
   - [ ] Wait for sync

5. **Verification**:
   - [ ] **Verify**: Conflict badge appears
   - [ ] Open conflict UI
   - [ ] **Verify**: Header shows "3 Conflicting Fields"
   - [ ] **Verify**: Three FieldComparisonCards appear (servings, cook time, prep time)
   - [ ] **Verify**: Progress shows "0 of 3"

6. **Resolve All Conflicts**:
   - [ ] Resolve servings (choose iPhone)
   - [ ] **Verify**: Progress updates to "1 of 3"
   - [ ] Resolve cook time (choose iPad)
   - [ ] **Verify**: Progress updates to "2 of 3"
   - [ ] Resolve prep time (choose iPhone)
   - [ ] **Verify**: Progress updates to "3 of 3"
   - [ ] **Verify**: Preview button becomes enabled
   - [ ] Preview and save

7. **Verification** (both devices):
   - [ ] **Verify**: Servings = "2 servings" (iPhone)
   - [ ] **Verify**: Cook Time = "60 min" (iPad)
   - [ ] **Verify**: Prep Time = "20 min" (iPhone)

**Result**: ✅ PASS / ❌ FAIL
**Notes**:

---

## Test Scenario 5: Three-Device Merge
**Expected Result**: All three devices converge to same state

### Steps:
1. **Setup**:
   - [ ] All three devices (iPhone, iPad, Mac) have recipe open
   - [ ] Turn on Airplane Mode on all devices

2. **Device A (iPhone) - Offline**:
   - [ ] Edit title: "Lasagna" → "iPhone's Lasagna"
   - [ ] Save

3. **Device B (iPad) - Offline**:
   - [ ] Edit servings: "4 servings" → "6 servings"
   - [ ] Save

4. **Device C (Mac) - Offline**:
   - [ ] Edit cook time: "30 min" → "45 min"
   - [ ] Save

5. **Bring All Online**:
   - [ ] Turn off Airplane Mode on iPhone
   - [ ] Wait 10 seconds
   - [ ] Turn off Airplane Mode on iPad
   - [ ] Wait 10 seconds
   - [ ] Turn off Airplane Mode on Mac
   - [ ] Wait 10 seconds

6. **Verification** (on all three devices):
   - [ ] Pull to refresh
   - [ ] **Verify**: Title = "iPhone's Lasagna"
   - [ ] **Verify**: Servings = "6 servings"
   - [ ] **Verify**: Cook Time = "45 min"
   - [ ] **Verify**: No conflicts
   - [ ] **Verify**: All three devices show identical data

**Result**: ✅ PASS / ❌ FAIL
**Notes**:

---

## Test Scenario 6: Additive Changes (Ingredients)
**Expected Result**: Auto-merge both sets of ingredients

### Steps:
1. **Setup**:
   - [ ] Both devices have recipe open
   - [ ] Recipe has 3 ingredients initially
   - [ ] Turn on Airplane Mode on both devices

2. **Device A (iPhone) - Offline**:
   - [ ] Add ingredient: "Garlic (2 cloves)"
   - [ ] Add ingredient: "Basil (1 tbsp)"
   - [ ] Save

3. **Device B (iPad) - Offline**:
   - [ ] Add ingredient: "Parmesan cheese (1 cup)"
   - [ ] Add ingredient: "Red pepper flakes (1 tsp)"
   - [ ] Save

4. **Bring Both Online**:
   - [ ] Turn off Airplane Mode on both devices
   - [ ] Wait for sync

5. **Verification** (both devices):
   - [ ] **Verify**: Recipe has 7 ingredients total (3 original + 4 new)
   - [ ] **Verify**: All 4 new ingredients appear
   - [ ] **Verify**: No duplicates
   - [ ] **Verify**: No conflict UI shown

**Result**: ✅ PASS / ❌ FAIL
**Notes**:

---

## Test Scenario 7: Recipe Sharing with Immutable IDs
**Expected Result**: Shared recipe maintains same ID across devices

### Steps:
1. **Device A (iPhone)**:
   - [ ] Create new recipe "Test Share Recipe"
   - [ ] Note the recipe ID (check debug logs or Firebase console)
   - [ ] Share recipe via Heirloom share link
   - [ ] Copy share link

2. **Device B (iPad)**:
   - [ ] Open share link
   - [ ] Accept shared recipe
   - [ ] **Verify**: Recipe appears in recipe list
   - [ ] **Verify**: Recipe ID matches original (check Firebase console)

3. **Device B (iPad)**:
   - [ ] Edit shared recipe: Change title to "Modified Title"
   - [ ] Save and sync

4. **Device A (iPhone)**:
   - [ ] Pull to refresh
   - [ ] **Verify**: Original recipe shows "Modified Title"
   - [ ] **Verify**: No duplicate recipe created
   - [ ] **Verify**: Recipe ID unchanged

**Result**: ✅ PASS / ❌ FAIL
**Notes**:

---

## Test Scenario 8: Transactional Save (Race Condition Prevention)
**Expected Result**: No false conflicts from race conditions

### Steps:
1. **Device A (iPhone)**:
   - [ ] Open recipe
   - [ ] Edit title
   - [ ] Tap Save
   - [ ] **Immediately** (within 1 second): Edit servings
   - [ ] Tap Save again

2. **Device B (iPad)**:
   - [ ] Wait 5 seconds
   - [ ] Pull to refresh
   - [ ] **Verify**: Both edits appear (title and servings)
   - [ ] **Verify**: No conflict detected
   - [ ] **Verify**: No false conflict badge

**Result**: ✅ PASS / ❌ FAIL
**Notes**:

---

## Test Scenario 9: Conflict Resolution UI Usability
**Expected Result**: UI is intuitive and non-technical

### Steps:
1. **Setup**: Create conflict (see Scenario 3)

2. **Conflict UI Inspection**:
   - [ ] **Verify**: No technical terms ("vector clock", "CRDT", "merge commit")
   - [ ] **Verify**: Device names shown ("Your iPhone", "Mom's iPad")
   - [ ] **Verify**: Timestamps shown in human-readable format
   - [ ] **Verify**: Preview shows exactly what will be saved

3. **Swipe Gesture Test**:
   - [ ] Swipe left on conflict card
   - [ ] **Verify**: Left card scales up, right card fades
   - [ ] **Verify**: Checkmark appears on left card
   - [ ] Swipe right
   - [ ] **Verify**: Right card scales up, left card fades
   - [ ] **Verify**: Checkmark moves to right card

4. **Animation Test**:
   - [ ] **Verify**: Entrance animations smooth
   - [ ] **Verify**: Cards animate in with stagger
   - [ ] **Verify**: Progress bar animates smoothly
   - [ ] Tap "Preview Merged Recipe"
   - [ ] **Verify**: Slide transition smooth
   - [ ] Tap "Save Merged Recipe"
   - [ ] **Verify**: Success animation plays (checkmark with scale)

**Result**: ✅ PASS / ❌ FAIL
**Notes**:

---

## Test Scenario 10: Edge Cases

### 10a. Same Value, Different Timestamps
**Expected Result**: Auto-merge with no conflict

- [ ] Device A sets servings to "6 servings" at 2:00 PM
- [ ] Device B sets servings to "6 servings" at 2:05 PM (concurrent)
- [ ] **Verify**: Auto-merge, no conflict UI

### 10b. Delete vs Update
**Expected Result**: Auto-merge (delete wins)

- [ ] Device A deletes notes field
- [ ] Device B updates notes to "New notes" (concurrent)
- [ ] **Verify**: Auto-merge, notes deleted
- [ ] **Verify**: No conflict UI

### 10c. Very Long Operation Log
**Expected Result**: Merge performance acceptable

- [ ] Make 50+ edits on Device A while offline
- [ ] Make 50+ edits on Device B while offline
- [ ] Bring both online
- [ ] **Verify**: Merge completes within 5 seconds
- [ ] **Verify**: UI remains responsive

### 10d. Conflict Dismissal
**Expected Result**: Conflict persists until resolved

- [ ] Create conflict
- [ ] Open conflict UI
- [ ] Tap "Later" to dismiss
- [ ] **Verify**: Conflict badge remains
- [ ] **Verify**: Next app launch shows conflict badge
- [ ] **Verify**: Recipe can still be edited

**Result**: ✅ PASS / ❌ FAIL
**Notes**:

---

## Testing Checklist Summary

| Scenario | Status | Notes |
|----------|--------|-------|
| 1. Sequential Edits | ⬜ | |
| 2. Concurrent Different Fields | ⬜ | |
| 3. Concurrent Same Field | ⬜ | |
| 4. Multiple Conflicts | ⬜ | |
| 5. Three-Device Merge | ⬜ | |
| 6. Additive Changes | ⬜ | |
| 7. Immutable Recipe IDs | ⬜ | |
| 8. Transactional Save | ⬜ | |
| 9. UI Usability | ⬜ | |
| 10. Edge Cases | ⬜ | |

---

## Known Limitations & Future Work

1. **Ingredient Reordering**: Currently treats as delete + add (may conflict)
2. **Image Conflicts**: Last-write-wins for images (CRDT only covers text fields)
3. **Comment Conflicts**: Not yet CRDT-aware (planned for future)
4. **Performance**: Large operation logs (1000+ ops) may slow merge
5. **Offline Duration**: Very long offline periods (weeks) may require full resync

---

## Debugging Tips

### View CRDT Data in Firebase Console:
1. Navigate to Firestore
2. Find `users/{userId}/recipes/{recipeId}`
3. Check `usesCRDT: true`
4. View `operations` subcollection
5. Verify vector clocks incrementing

### Enable CRDT Debug Logs:
Search for `[CRDT]` in Xcode console to see:
- `📤 [CRDT] Uploading recipe with operation log`
- `📥 [CRDT] Downloading and merging recipe`
- `🔀 [CRDT] Merging with existing local recipe`
- `✅ [CRDT] Uploaded recipe with X operations`
- `⚠️ [CRDT] Conflict detected for: {recipe title}`

### Common Issues:
- **Conflict badge stuck**: Check Firebase rules allow read/write to operations subcollection
- **False conflicts**: Ensure transactional save is used in RecipeEditorView.swift
- **Duplicate recipes**: Verify immutable IDs in FirebaseShareService.swift
- **Merge not happening**: Check FirebaseSyncService is calling `syncChangesWithCRDT()`

---

---

## Test Scenario 11: OCR - Basic Recipe Card Scanning
**Expected Result**: Recipe card scanned, extracted, and saved with accurate data

### Steps:
1. **Scan Recipe Card**:
   - [ ] Open Heirloom app
   - [ ] Tap "+" button → "Scan Recipe"
   - [ ] Point camera at recipe card (use RecipeCard_01.jpg from test images)
   - [ ] Tap capture button
   - [ ] **Verify**: Camera captures image

2. **OCR Processing**:
   - [ ] **Verify**: Loading indicator appears ("Extracting recipe...")
   - [ ] Wait for OCR processing (5-10 seconds)
   - [ ] **Verify**: Recipe preview appears with extracted data

3. **Validate Extraction**:
   - [ ] **Verify**: Title is non-empty and meaningful (not "Untitled Recipe")
   - [ ] **Verify**: At least 3 ingredients extracted
   - [ ] **Verify**: At least 2 instruction steps extracted
   - [ ] **Verify**: Servings extracted (if present on card)
   - [ ] **Verify**: Prep/cook time extracted (if present on card)

4. **Ingredient Parsing**:
   - [ ] Check ingredient list
   - [ ] **Verify**: At least 60% have quantities parsed (e.g., "1", "2", "1/2")
   - [ ] **Verify**: At least 50% have units parsed (e.g., "cup", "tsp", "lb")
   - [ ] **Verify**: Ingredient names are clean (no stray numbers/units in name)

5. **Grocery Categories**:
   - [ ] Check ingredient categories
   - [ ] **Verify**: At least 30% auto-categorized (not "Other")
   - [ ] **Verify**: Categories make sense (flour → Pantry, eggs → Dairy, etc.)

6. **Save Recipe**:
   - [ ] Review extracted data
   - [ ] Make any necessary edits
   - [ ] Tap "Save"
   - [ ] **Verify**: Recipe appears in recipe list
   - [ ] Open saved recipe
   - [ ] **Verify**: All data persisted correctly

**Result**: ✅ PASS / ❌ FAIL
**Notes**:

---

## Test Scenario 12: OCR - Cookbook Page Scanning
**Expected Result**: Cookbook page with multiple recipes handled correctly

### Steps:
1. **Scan Cookbook Page**:
   - [ ] Open app → "Scan Recipe"
   - [ ] Point camera at cookbook page (use Cookbook_01.jpeg)
   - [ ] Capture image
   - [ ] **Verify**: Image captured successfully

2. **Multiple Recipe Detection**:
   - [ ] **If multiple recipes on page**: App should prompt to select which recipe
   - [ ] **If single recipe**: Proceed with extraction
   - [ ] **Verify**: Correct recipe extracted (if multiple present)

3. **Handle Complex Layouts**:
   - [ ] **Verify**: OCR handles two-column layouts
   - [ ] **Verify**: Instructions maintain correct order
   - [ ] **Verify**: Ingredient list not mixed with instructions
   - [ ] **Verify**: Page numbers/headers excluded from extraction

4. **Validate Quality**:
   - [ ] **Verify**: Title extracted correctly
   - [ ] **Verify**: All ingredients captured (compare to original)
   - [ ] **Verify**: All instruction steps captured
   - [ ] **Verify**: No duplicate lines

**Result**: ✅ PASS / ❌ FAIL
**Notes**:

---

## Test Scenario 13: OCR - Poor Quality Image Handling
**Expected Result**: App handles low-quality images gracefully

### Steps:
1. **Test Blurry Image**:
   - [ ] Take photo with intentional motion blur
   - [ ] **Verify**: OCR attempts extraction
   - [ ] **Verify**: If extraction quality is poor, app shows warning/retry option
   - [ ] **Verify**: User can retake photo

2. **Test Low Light**:
   - [ ] Take photo in dim lighting
   - [ ] **Verify**: Camera shows low light warning (if applicable)
   - [ ] **Verify**: OCR still attempts extraction
   - [ ] **Verify**: User can adjust and retry

3. **Test Angled/Skewed Image**:
   - [ ] Take photo at 45-degree angle
   - [ ] **Verify**: OCR handles perspective distortion
   - [ ] **Verify**: Text still readable in extraction

4. **Test Handwritten Recipe**:
   - [ ] Scan handwritten recipe card
   - [ ] **Verify**: OCR attempts extraction
   - [ ] **Verify**: If handwriting is illegible, user can manually edit all fields

**Result**: ✅ PASS / ❌ FAIL
**Notes**:

---

## Test Scenario 14: OCR - Parity with Manual Entry
**Expected Result**: OCR recipes match quality of manually-entered recipes

### Steps:
1. **Create Two Versions of Same Recipe**:
   - [ ] Scan recipe card with OCR → Save as "Recipe A"
   - [ ] Manually enter same recipe → Save as "Recipe B"

2. **Compare Recipe A (OCR) vs Recipe B (Manual)**:
   - [ ] **Verify**: Both have complete titles
   - [ ] **Verify**: Both have similar ingredient counts (±2)
   - [ ] **Verify**: Both have similar instruction counts (±1)
   - [ ] **Verify**: Ingredient quantities match (e.g., "1 cup" vs "1 cup")
   - [ ] **Verify**: Grocery categories similar (OCR should auto-categorize)

3. **Functional Parity**:
   - [ ] Test scaling on both recipes
   - [ ] **Verify**: Both scale correctly
   - [ ] Add both to shopping list
   - [ ] **Verify**: Ingredients format similarly
   - [ ] Share both recipes
   - [ ] **Verify**: Both sync correctly

**Result**: ✅ PASS / ❌ FAIL
**Notes**:

---

## Test Scenario 15: OCR - End-to-End User Flow
**Expected Result**: Complete user journey from scan to cook

### Steps:
1. **Discover Feature**:
   - [ ] As new user, find "Scan Recipe" option easily
   - [ ] **Verify**: Clear icon/label (camera icon?)
   - [ ] **Verify**: Help text or onboarding for first scan

2. **Scan Recipe**:
   - [ ] Choose physical recipe card to scan
   - [ ] Open scanner
   - [ ] Position recipe in frame
   - [ ] **Verify**: Camera viewfinder shows alignment guides (if applicable)
   - [ ] Capture image

3. **Review Extraction**:
   - [ ] **Verify**: Loading state is clear (not frozen)
   - [ ] Review extracted recipe
   - [ ] **Verify**: Can edit any field before saving
   - [ ] **Verify**: Can see original image (thumbnail/preview)
   - [ ] Make minor corrections if needed

4. **Save & Organize**:
   - [ ] Save recipe
   - [ ] **Verify**: Recipe tagged with sourceType = .scan
   - [ ] **Verify**: Original image attached to recipe (if feature exists)
   - [ ] Add to collection/folder

5. **Use Recipe**:
   - [ ] Open recipe
   - [ ] Scale to different servings
   - [ ] Add to shopping list
   - [ ] Start cooking mode (if exists)
   - [ ] **Verify**: All features work identically to manual recipes

**Result**: ✅ PASS / ❌ FAIL
**Notes**:

---

## Test Scenario 16: OCR - Edge Cases & Error Handling
**Expected Result**: Graceful error handling for unusual scenarios

### Steps:
1. **No Recipe in Image**:
   - [ ] Scan random text (newspaper, book page)
   - [ ] **Verify**: App detects no recipe structure
   - [ ] **Verify**: Clear error message shown
   - [ ] **Verify**: User can retry or cancel

2. **Empty/Blank Image**:
   - [ ] Point camera at blank wall
   - [ ] Capture
   - [ ] **Verify**: OCR returns empty/minimal text
   - [ ] **Verify**: App prompts to retry

3. **Very Long Recipe**:
   - [ ] Scan recipe with 20+ ingredients, 15+ steps
   - [ ] **Verify**: All ingredients extracted
   - [ ] **Verify**: All steps extracted
   - [ ] **Verify**: UI scrolls properly
   - [ ] **Verify**: No truncation or cutoff

4. **Special Characters**:
   - [ ] Scan recipe with fractions (½, ¼, ¾)
   - [ ] Scan recipe with special chars (°, ", ')
   - [ ] **Verify**: Fractions converted correctly
   - [ ] **Verify**: Degree symbols preserved (350°F)
   - [ ] **Verify**: Quotes handled properly

5. **Network Interruption**:
   - [ ] Start scanning
   - [ ] Turn on Airplane Mode during OCR processing
   - [ ] **Verify**: App shows offline error
   - [ ] **Verify**: Can retry when back online
   - [ ] **Verify**: Image cached locally for retry

**Result**: ✅ PASS / ❌ FAIL
**Notes**:

---

## Sign-Off

### CRDT Testing
**Tester Name**: ___________________
**Date**: ___________________
**Devices Used**: ___________________
**Overall Result**: ✅ PASS / ❌ FAIL
**Blocker Issues**: ___________________

### OCR Testing
**Tester Name**: ___________________
**Date**: ___________________
**Device Used**: ___________________
**Recipe Cards Tested**: ___________________
**Cookbook Pages Tested**: ___________________
**Overall Result**: ✅ PASS / ❌ FAIL
**Blocker Issues**: ___________________
