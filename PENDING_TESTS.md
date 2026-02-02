# Pending Tests - Social Features

## Date: 2026-02-02

### Tests to Run After Gym

#### 1. Profile Header Share Counts
- [ ] User A shares a recipe to User B
- [ ] Verify User A's Table header shows "1 to friends"
- [ ] User A publishes a recipe publicly
- [ ] Verify User A's Table header shows "1 public"
- [ ] If both exist, should show "X to friends · Y public"

#### 2. Real-time Connection Requests
- [ ] User A sends connection request to User B
- [ ] Verify User B sees request immediately (NO force quit needed)
- [ ] User B accepts request
- [ ] Verify both users see connection instantly

#### 3. Connection Profile Sheet
- [ ] Go to Table tab → tap on a connection
- [ ] Verify profile loads immediately (not blank)
- [ ] Should show stats: "X You Shared · Y They Shared"
- [ ] Dismiss and reopen → should still work

#### 4. Total Recipe Count in Connection List
- [ ] Connection row should show total recipes shared between both users
- [ ] Formula: recipesSharedCount + recipesReceivedCount
- [ ] Example: If you shared 2 and received 3, shows "5 recipes shared"

#### 5. Remove Connection
- [ ] Tap connection → scroll to bottom → "Remove Connection"
- [ ] Confirm removal
- [ ] Verify connection removed from both users' lists

#### 6. Connection Counts Update
- [ ] After sharing/accepting recipes, verify counts increment correctly
- [ ] Recipient's "They Shared" count should increment
- [ ] Sender's "You Shared" count should increment

---

## Recent Fixes Applied
- ✅ Added real-time Firestore listener for connections
- ✅ Fixed profile sheet blank on first tap (.id modifier)
- ✅ Changed connection row to show total shared recipes
- ✅ Updated profile header to show "X to friends · Y public"
- ✅ Fixed connection removal (reciprocal delete)
- ✅ Added recipesReceivedCount tracking on share acceptance
- ✅ Fixed Firebase rules to allow connection deletion

## Known Issues
- None currently logged

---

## Ingredient Preparation Extraction & Shopping List Consolidation

### Tests to Run

#### 1. Preparation Details Preserved in Import
- [ ] Import web recipe with preparation details (e.g., "2 cloves garlic, thinly sliced")
- [ ] Verify recipe detail shows: "2 cloves garlic (thinly sliced)"
- [ ] Import OCR recipe with preparation (e.g., "1 onion, diced")
- [ ] Verify shows: "1 onion (diced)"
- [ ] Test common preparations: minced, diced, chopped, sliced, grated, shredded, melted, sifted

#### 2. Shopping List - Single Recipe
- [ ] Add 1 recipe to shopping list with prepared ingredients
- [ ] Verify ingredient shows with preparation: "2 cloves garlic (minced)"
- [ ] Helpful reminder when shopping what you'll need to do with it

#### 3. Shopping List - Consolidated Ingredients (Different Preparations)
- [ ] Add 4 recipes to shopping list:
  - Recipe A: 2 cloves garlic, minced
  - Recipe B: 4 cloves garlic, thinly sliced
  - Recipe C: 6 cloves garlic, sliced
  - Recipe D: 2 cloves garlic, chopped
- [ ] **Expected:** Single line showing "14 cloves garlic" (NO preparation shown)
- [ ] **NOT:** Multiple lines for garlic with different preparations
- [ ] Tap ingredient → should show all 4 recipes that use it
- [ ] Can see individual preparations in each recipe detail

#### 4. Shopping List - Same Preparation
- [ ] Add 2 recipes with identical preparation (e.g., both "minced")
- [ ] Should still consolidate: "6 cloves garlic" (no prep shown when consolidated)

#### 5. Edit Tracking Shows Preparation Changes
- [ ] Import recipe with "2 cloves garlic, minced"
- [ ] Edit to "2 cloves garlic, thinly sliced"
- [ ] Tap "Show original" → verify diff shows preparation change
- [ ] Original: "2 cloves garlic, minced"
- [ ] Current: "2 cloves garlic, thinly sliced"

#### 6. Recipe Detail Display
- [ ] Recipe detail should show: "2 cloves garlic (thinly sliced)"
- [ ] Cooking mode should show same format
- [ ] Card view should show same format

---

**Next Session:** Run all tests above and document results
