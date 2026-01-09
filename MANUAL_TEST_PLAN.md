# Manual Test Plan - Collection Deletion & UI Improvements

**Date**: 2026-01-08
**Features**: Collection deletion, compact recipe cards, improved onboarding
**Tester**: Matt

---

## Test 1: Compact Recipe Cards

**Location**: Recipes tab, Collections tab (within collections)

### Steps:
1. Navigate to Recipes tab
2. Observe recipe cards

### Expected Results:
- [ ] Source, times cooked (🔥), and generation badge are on ONE line
- [ ] Bullet separator (•) appears between source and times cooked (if times cooked > 0)
- [ ] Cards are noticeably shorter than before
- [ ] All information is still readable
- [ ] Generation badge stays on the right side

### Visual Check:
```
┌─────────────────────┐
│ Recipe Image        │
├─────────────────────┤
│ Recipe Title        │
│ Recipe Title Line 2 │
│                     │
│ Source • 🔥3  [1st Gen]│  ← All on one line
└─────────────────────┘
```

---

## Test 2: Delete Heritage Collection (Long Press)

**Location**: Collections tab → Heritage Collections section

### Steps:
1. Go to Collections tab
2. Long-press on a heritage collection (Presidential Pantry, Literary Kitchen, etc.)
3. Tap "Delete Collection"
4. Select "Delete Collection Only"

### Expected Results:
- [ ] Context menu appears with "Delete Collection" option
- [ ] Confirmation dialog shows TWO options:
  - "Delete Collection Only"
  - "Delete Collection & Recipes"
  - "Cancel"
- [ ] Clear message explains consequences
- [ ] After selecting "Delete Collection Only":
  - Collection disappears from list
  - Green toast: "Collection deleted - Recipes remain in your library"
  - Warning haptic on delete, success haptic after
  - Recipes still exist in Recipes tab

### Test Again With:
5. Long-press another heritage collection
6. Select "Delete Collection & Recipes"

### Expected Results:
- [ ] Collection disappears
- [ ] Toast shows: "Collection and X recipes deleted"
- [ ] Recipes no longer in Recipes tab
- [ ] Both collection and recipes synced to Firebase (check logs)

---

## Test 3: Delete User Collection (Long Press)

**Location**: Collections tab → My Collections section

### Steps:
1. Create a new user collection
2. Add 2-3 recipes to it
3. Long-press the collection
4. Tap "Delete Collection"
5. Test both options

### Expected Results:
- [ ] Same behavior as heritage collections
- [ ] Both delete modes work correctly
- [ ] Toast messages are clear

---

## Test 4: Delete Collection (Trash Icon in Detail View)

**Location**: Inside any collection detail view

### Steps:
1. Open a user collection (tap to open)
2. Look at top-right toolbar
3. Verify trash icon appears
4. Tap trash icon
5. Test both delete options

### Expected Results:
- [ ] Trash icon visible in toolbar (next to + button)
- [ ] Confirmation dialog appears (same as long-press)
- [ ] After deletion, automatically navigate back to Collections list
- [ ] Collection removed from list

### Test System Collections:
6. Open Favorites collection
7. Check toolbar

### Expected Results:
- [ ] NO trash icon appears
- [ ] Only + button visible

---

## Test 5: System Collection Protection

**Location**: Collections tab → Smart Collections section

### Steps:
1. Try to long-press "Favorites" collection
2. Try to long-press "Quick Meals" collection
3. Try to long-press "Meal Prep" collection

### Expected Results:
- [ ] Context menu DOES appear with "Delete Collection"
- [ ] Selecting delete shows confirmation
- [ ] After selecting either option, see error toast:
  - "Cannot delete - System collections cannot be deleted"
  - Red error toast
  - Error haptic feedback
- [ ] Collection remains intact

---

## Test 6: Onboarding Flow

**Location**: Settings → Reset to trigger onboarding (or fresh install)

### Steps:
1. Trigger onboarding (Settings → scroll to bottom → "Reset Onboarding")
2. Complete Screen 1
3. On Screen 2, observe the 4 heritage collections
4. Tap one of the collections

### Expected Results:
- [ ] Screen 1 shows hero imagery and description
- [ ] Screen 2 shows 4 heritage collections in 2x2 grid
- [ ] Tapping a collection navigates INTO that collection
- [ ] Can see recipes inside the collection
- [ ] Can tap back arrow to return to onboarding
- [ ] Backing out completes onboarding automatically
- [ ] "Explore Collections" button also completes onboarding

---

## Test 7: Sample Recipe Generation (Heritage)

**Location**: Inside any collection

### Steps:
1. Open any collection
2. Tap + button
3. Tap "Generate Sample Recipe"
4. Tap "Heritage Recipe"
5. Wait for recipe to generate
6. Repeat 5-10 times

### Expected Results:
- [ ] Each time generates DIFFERENT recipe (from 100-recipe pool)
- [ ] Recipes have heritage styling/imagery
- [ ] No duplicates until pool exhausted
- [ ] If duplicate, auto-numbered: "Recipe Title (2)", "Recipe Title (3)"
- [ ] Recipe appears in the collection
- [ ] Recipe has proper source type (heritage)

---

## Test 8: Sample Recipe Generation (Normal)

**Location**: Inside any collection

### Steps:
1. Open any collection
2. Tap + button
3. Tap "Generate Sample Recipe"
4. Tap "Normal Recipe"
5. Repeat 5-10 times

### Expected Results:
- [ ] Generates from 12-recipe pool randomly
- [ ] Variety of recipes (not always tomato soup)
- [ ] Duplicate handling with auto-numbering
- [ ] Recipe appears in collection immediately

---

## Test 9: Empty Menu Error (Fixed)

**Location**: Collections tab → Any collection

### Steps:
1. Open any collection
2. Check console/logs for errors

### Expected Results:
- [ ] NO "UIContextMenuInteraction updateVisibleMenuWithBlock" errors
- [ ] NO "menu is not visible" errors
- [ ] Only + button visible (no ellipsis)

---

## Test 10: Multi-Option Import Menu

**Location**: Inside any collection

### Steps:
1. Open any collection
2. Tap + button
3. Review menu options

### Expected Results:
- [ ] Menu shows ALL options:
  - New Recipe
  - Import from URL
  - Bulk Import
  - Scan Cookbook
  - Generate Sample Recipe (with submenu)
    - Normal Recipe
    - Heritage Recipe
- [ ] All options functional
- [ ] Submenu shows chevron indicator

---

## Test 11: Recipe Count Display

**Location**: Collection detail view header

### Steps:
1. Open a collection with recipes
2. Delete a recipe
3. Add a recipe
4. Observe recipe count

### Expected Results:
- [ ] Count updates in real-time
- [ ] Shows "X recipe" or "X recipes" (proper pluralization)
- [ ] Count matches actual recipes shown

---

## Test 12: Firebase Sync (if active)

**Location**: Any collection deletion

### Steps:
1. Enable Firebase backend
2. Delete a collection with "Delete Collection Only"
3. Check network logs
4. Delete another with "Delete Collection & Recipes"
5. Check network logs

### Expected Results:
- [ ] "Delete Collection Only": Only `deleteCollection` API called
- [ ] "Delete Collection & Recipes": Both `deleteRecipe` (for each) AND `deleteCollection` called
- [ ] Success toasts appear after sync completes
- [ ] No sync errors in logs

---

## Bug Tracking

### Issues Found:

1. **Issue**: _______________________________________________
   - **Severity**: Critical / High / Medium / Low
   - **Steps to Reproduce**: _________________________________
   - **Expected**: __________________________________________
   - **Actual**: ____________________________________________

2. **Issue**: _______________________________________________
   - **Severity**: Critical / High / Medium / Low
   - **Steps to Reproduce**: _________________________________
   - **Expected**: __________________________________________
   - **Actual**: ____________________________________________

---

## Sign-Off

- [ ] All critical tests passed
- [ ] All high priority tests passed
- [ ] Bugs filed for any failures
- [ ] Ready for automated test writing

**Tester Signature**: _________________ **Date**: _________

---

## Notes

- Haptic feedback should be felt on supported devices
- Toast notifications should auto-dismiss after ~3 seconds
- All navigation should feel smooth and natural
- No crashes or freezes during testing
