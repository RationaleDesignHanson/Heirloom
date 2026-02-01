# Public Recipe Discovery - Manual Testing Plan

## Testing Session Information

**Feature:** Public Recipe Discovery (Phases 1-11)
**Tester:** _______________
**Date:** _______________
**Build:** _______________
**Device:** _______________
**iOS Version:** _______________

**Progress Tracker:** `test_progress.json` (auto-updated via `./mark_test.sh`)

---

## Testing Instructions

### How to Use This Plan

1. **Start from the top** (Critical Path Tests - P0)
2. **Complete each test in order**
3. **Mark results using:** `./mark_test.sh <test-id> <pass|fail|skip> "[optional notes]"`
4. **If a test fails:**
   - Document the issue in notes
   - Take screenshots if possible
   - Continue with remaining tests
   - Circle back to failed tests after fixes
5. **Progress auto-saves** to `test_progress.json`

### Test Result Commands

```bash
# Mark test as passed
./mark_test.sh P0-01 pass

# Mark test as failed with notes
./mark_test.sh P0-02 fail "Recipe doesn't appear in discovery after 5 minutes"

# Mark test as skipped (e.g., depends on failed test)
./mark_test.sh P0-03 skip "Blocked by P0-02 failure"

# View current progress
./mark_test.sh status
```

---

## Priority Levels

- **P0 (Critical Path):** Must pass before any release - ~30 minutes
- **P1 (Core Functionality):** Should pass before beta - ~45 minutes
- **P2 (Polish & Edge Cases):** Should pass before full launch - ~30 minutes
- **P3 (Nice to Have):** Can be addressed post-launch

**Total Estimated Time:** ~2 hours

---

## P0: Critical Path Tests (MUST PASS) - ~30 minutes

These tests cover the essential user journeys. If any P0 test fails, the feature is not ready for release.

### P0-01: App Launch & Discovery Entry Point

**Prerequisites:** Fresh app install or clean state
**Estimated Time:** 2 minutes

**Steps:**
1. Launch app
2. Sign in (if not already signed in)
3. Navigate to Collections tab (recipe list)
4. Scroll to top of recipe list

**Expected Result:**
- [ ] App launches without crashing
- [ ] Recipe list loads successfully
- [ ] DiscoveryEntryBanner visible above recipe grid
- [ ] Banner shows "Discover Recipes" text
- [ ] Banner shows globe icon
- [ ] Banner shows "Browse trending recipes from the community" subtext
- [ ] Banner has proper styling (card with shadow)

**Pass Criteria:** All checkboxes checked, no crashes

**Mark result:** `./mark_test.sh P0-01 pass|fail "[notes]"`

---

### P0-02: Open Discovery Feed

**Prerequisites:** P0-01 passed
**Estimated Time:** 2 minutes

**Steps:**
1. From recipe list, tap DiscoveryEntryBanner
2. Observe transition

**Expected Result:**
- [ ] Discovery feed opens as full-screen modal
- [ ] Feed loads within 2 seconds
- [ ] See 3 tabs: Trending 🔥, New ✨, Popular ⭐
- [ ] Trending tab selected by default
- [ ] See recipe cards in 2-column grid
- [ ] Each card shows: image, title, creator name, view count, save count
- [ ] Cards have proper spacing and shadows
- [ ] Pull-to-refresh control visible

**Pass Criteria:** All checkboxes checked, loads within 2 seconds

**Mark result:** `./mark_test.sh P0-02 pass|fail "[notes]"`

---

### P0-03: Browse Discovery Tabs

**Prerequisites:** P0-02 passed
**Estimated Time:** 3 minutes

**Steps:**
1. Tap "New ✨" tab
2. Observe recipes load
3. Tap "Popular ⭐" tab
4. Observe recipes load
5. Tap "Trending 🔥" tab to return

**Expected Result:**
- [ ] New tab loads successfully
- [ ] New tab shows recently published recipes
- [ ] Popular tab loads successfully
- [ ] Popular tab shows most-saved recipes
- [ ] Returning to Trending works
- [ ] Each tab maintains scroll position when switching back
- [ ] Tab transitions are smooth (no lag)

**Pass Criteria:** All checkboxes checked

**Mark result:** `./mark_test.sh P0-03 pass|fail "[notes]"`

---

### P0-04: View Public Recipe Detail

**Prerequisites:** P0-03 passed
**Estimated Time:** 3 minutes

**Steps:**
1. From any discovery tab, tap any recipe card
2. PublicRecipeDetailView opens
3. Scroll through entire recipe

**Expected Result:**
- [ ] Detail view opens without crash
- [ ] Hero image displays (or placeholder if no image)
- [ ] Recipe title displays clearly
- [ ] Creator name and photo display
- [ ] View count and save count display
- [ ] Description displays (if present)
- [ ] Servings, prep time, cook time display
- [ ] Ingredients list displays correctly
- [ ] Instructions display in order
- [ ] Tags display (if present)
- [ ] "Save to My Recipes" button visible at bottom
- [ ] Ellipsis menu (•••) visible in toolbar

**Pass Criteria:** All checkboxes checked

**Mark result:** `./mark_test.sh P0-04 pass|fail "[notes]"`

---

### P0-05: Save Recipe From Discovery

**Prerequisites:** P0-04 passed
**Estimated Time:** 3 minutes

**Steps:**
1. From PublicRecipeDetailView, scroll to bottom
2. Tap "Save to My Recipes" button
3. Wait for save to complete
4. Observe success alert
5. Tap "View Recipe" in alert
6. Verify recipe in your collection

**Expected Result:**
- [ ] Button shows loading spinner while saving
- [ ] Success alert appears within 2 seconds
- [ ] Alert says "Recipe Saved!" with message
- [ ] Alert has "View Recipe" and "OK" buttons
- [ ] Tapping "View Recipe" navigates to saved recipe
- [ ] Saved recipe appears in Collections tab
- [ ] Saved recipe has all content (title, ingredients, instructions)
- [ ] Saved recipe shows "Based on recipe by [Creator]" attribution section
- [ ] Saved recipe has "View Original" button

**Pass Criteria:** All checkboxes checked, save completes within 2 seconds

**Mark result:** `./mark_test.sh P0-05 pass|fail "[notes]"`

---

### P0-06: Publish Recipe Flow

**Prerequisites:** Have a complete recipe ready (ingredients + instructions)
**Estimated Time:** 5 minutes

**Steps:**
1. Open any recipe you created
2. Tap share button (•••) in toolbar
3. Tap "Share Publicly"
4. PublishRecipeSheet opens
5. Review preview
6. Tap "Publish" button
7. Wait for publish to complete

**Expected Result:**
- [ ] PublishRecipeSheet opens with preview
- [ ] Preview shows what will be shared (title, image, ingredients, instructions)
- [ ] Privacy note visible ("You can unpublish anytime")
- [ ] "Publish" button enabled
- [ ] Button shows loading spinner during publish
- [ ] Success message appears within 3 seconds
- [ ] Sheet dismisses automatically
- [ ] Globe badge appears on recipe card in list
- [ ] Badge shows "0" views initially
- [ ] Recipe appears in discovery feed within 1 minute

**Pass Criteria:** All checkboxes checked, publishes within 3 seconds

**Mark result:** `./mark_test.sh P0-06 pass|fail "[notes]"`

---

### P0-07: Verify Published Recipe in Discovery

**Prerequisites:** P0-06 passed
**Estimated Time:** 3 minutes

**Steps:**
1. Navigate to discovery feed
2. Switch to "New ✨" tab
3. Pull to refresh
4. Scroll through recipes
5. Find your published recipe

**Expected Result:**
- [ ] Your recipe appears in "New" tab
- [ ] Recipe card shows your display name as creator
- [ ] Recipe card shows correct image (or placeholder)
- [ ] Recipe card shows correct title
- [ ] View count shows "0" or "1"
- [ ] Save count shows "0"
- [ ] Tapping card opens your published recipe
- [ ] Detail view shows all content correctly

**Pass Criteria:** Recipe found in discovery within 1 minute

**Mark result:** `./mark_test.sh P0-07 pass|fail "[notes]"`

---

### P0-08: Unpublish Recipe Flow

**Prerequisites:** P0-06 passed (have published recipe)
**Estimated Time:** 3 minutes

**Steps:**
1. Open your published recipe
2. Tap share button (•••) in toolbar
3. Tap "Unpublish" (replaces "Share Publicly")
4. UnpublishConfirmationSheet opens
5. Review information
6. Tap "Unpublish" button
7. Confirm in alert if needed

**Expected Result:**
- [ ] UnpublishConfirmationSheet opens
- [ ] Shows current stats (views, saves)
- [ ] Shows "What happens" bullet list
- [ ] Warning icon visible
- [ ] "Unpublish" button has destructive styling (red)
- [ ] Button shows loading spinner during unpublish
- [ ] Success occurs within 2 seconds
- [ ] Sheet dismisses
- [ ] Globe badge removed from recipe card
- [ ] Recipe no longer appears in discovery (verify in P0-09)

**Pass Criteria:** All checkboxes checked, unpublishes within 2 seconds

**Mark result:** `./mark_test.sh P0-08 pass|fail "[notes]"`

---

### P0-09: Search for Recipe

**Prerequisites:** Discovery feed has recipes
**Estimated Time:** 3 minutes

**Steps:**
1. Open discovery feed
2. Tap search bar at top
3. Type a common keyword (e.g., "chicken", "pasta", "chocolate")
4. Wait for results
5. Clear search
6. Type nonsense query (e.g., "xyzabc123")

**Expected Result:**
- [ ] Search bar activates on tap
- [ ] Keyboard appears
- [ ] Results appear within 1 second of typing
- [ ] Results match search query
- [ ] Matching recipes highlighted or filtered
- [ ] Nonsense query shows empty state
- [ ] Empty state says "No results found"
- [ ] Clear button (X) clears search
- [ ] Clearing search returns to full feed

**Pass Criteria:** Search works, returns results within 1 second

**Mark result:** `./mark_test.sh P0-09 pass|fail "[notes]"`

---

### P0-10: Report Recipe (Basic Flow)

**Prerequisites:** Discovery feed has recipes
**Estimated Time:** 3 minutes

**Steps:**
1. Open any public recipe detail view
2. Tap ellipsis menu (•••) in toolbar
3. Tap "Report Recipe"
4. ReportConfirmationSheet opens
5. Select any reason (e.g., "Spam or misleading")
6. Optionally add details
7. Tap "Submit Report"

**Expected Result:**
- [ ] Menu shows "Report Recipe" option with destructive styling
- [ ] ReportConfirmationSheet opens
- [ ] Shows 6 report reasons with icons
- [ ] Reason selection highlights with blue border
- [ ] Additional details field optional
- [ ] "Submit Report" button enabled when reason selected
- [ ] Button shows loading spinner during submit
- [ ] Success alert appears within 2 seconds
- [ ] Alert says "Report Submitted" with thank you message
- [ ] Sheet dismisses on OK
- [ ] Trying to report same recipe again shows "already reported" error

**Pass Criteria:** Report submits successfully, duplicate blocked

**Mark result:** `./mark_test.sh P0-10 pass|fail "[notes]"`

---

### P0-11: Deep Link - Custom Scheme

**Prerequisites:** Have a published recipe ID
**Estimated Time:** 2 minutes

**Steps:**
1. Get a public recipe ID (from Firestore or logs)
2. Quit app completely
3. Open Safari on device
4. Enter URL: `heirloom://recipe/{publicRecipeId}`
5. Tap Go

**Expected Result:**
- [ ] iOS prompts to open in Heirloom
- [ ] Tapping "Open" launches app
- [ ] App navigates to PublicRecipeDetailView
- [ ] Correct recipe displays
- [ ] All content loads correctly
- [ ] Invalid recipe ID shows "Recipe not found" error

**Pass Criteria:** Deep link works, opens correct recipe

**Mark result:** `./mark_test.sh P0-11 pass|fail "[notes]"`

---

### P0-12: Deep Link - Universal Link

**Prerequisites:** Have a published recipe ID
**Estimated Time:** 2 minutes

**Steps:**
1. Get a public recipe ID
2. Quit app completely
3. Open Safari on device
4. Enter URL: `https://heirloom.app/recipe/{publicRecipeId}`
5. Tap Go

**Expected Result:**
- [ ] Page loads (or redirects)
- [ ] iOS Smart Banner or prompt to open app appears
- [ ] Tapping "Open" launches app
- [ ] App navigates to PublicRecipeDetailView
- [ ] Correct recipe displays

**Pass Criteria:** Universal link works, opens correct recipe

**Mark result:** `./mark_test.sh P0-12 pass|fail "[notes]"`

---

## P0 Summary

**Total P0 Tests:** 12
**Estimated Time:** ~30 minutes
**Must Pass:** 100% (12/12)

**Check Progress:** `./mark_test.sh status`

If all P0 tests pass ✅, proceed to P1 tests.
If any P0 test fails ❌, address issues before continuing.

---

## P1: Core Functionality Tests (SHOULD PASS FOR BETA) - ~45 minutes

These tests cover important functionality that should work for beta release.

### P1-01: Publish Validation - No Ingredients

**Prerequisites:** Create recipe with instructions but NO ingredients
**Estimated Time:** 2 minutes

**Steps:**
1. Create recipe with only instructions (no ingredients)
2. Try to publish via "Share Publicly"

**Expected Result:**
- [ ] PublishRecipeSheet opens
- [ ] Error message displays: "Recipe must have at least one ingredient"
- [ ] Publish button disabled or shows error
- [ ] User cannot proceed with publish

**Pass Criteria:** Publishing blocked with clear error

**Mark result:** `./mark_test.sh P1-01 pass|fail "[notes]"`

---

### P1-02: Publish Validation - No Instructions

**Prerequisites:** Create recipe with ingredients but NO instructions
**Estimated Time:** 2 minutes

**Steps:**
1. Create recipe with only ingredients (no instructions)
2. Try to publish via "Share Publicly"

**Expected Result:**
- [ ] Error message: "Recipe must have at least one instruction"
- [ ] Publish blocked

**Pass Criteria:** Publishing blocked with clear error

**Mark result:** `./mark_test.sh P1-02 pass|fail "[notes]"`

---

### P1-03: Theme Recipe Cannot Be Published

**Prerequisites:** Have access to a Heritage (theme) recipe
**Estimated Time:** 1 minute

**Steps:**
1. Open any Heritage recipe (isThemeRecipe = true)
2. Check toolbar for share button

**Expected Result:**
- [ ] "Share Publicly" button NOT visible in menu
- [ ] Or button disabled with explanation
- [ ] Heritage recipes cannot be published

**Pass Criteria:** Theme recipes blocked from publishing

**Mark result:** `./mark_test.sh P1-03 pass|fail "[notes]"`

---

### P1-04: Sample Recipe Cannot Be Published

**Prerequisites:** Have a sample recipe
**Estimated Time:** 1 minute

**Steps:**
1. Open any sample recipe (isSampleRecipe = true)
2. Check for publish option

**Expected Result:**
- [ ] "Share Publicly" button NOT visible
- [ ] Sample recipes cannot be published

**Pass Criteria:** Sample recipes blocked from publishing

**Mark result:** `./mark_test.sh P1-04 pass|fail "[notes]"`

---

### P1-05: Discovery Pagination

**Prerequisites:** Discovery feed has 20+ recipes
**Estimated Time:** 3 minutes

**Steps:**
1. Open discovery feed
2. Scroll to bottom of list
3. Observe next page load
4. Continue scrolling

**Expected Result:**
- [ ] Initial load shows 20 recipes
- [ ] Scrolling to bottom triggers next page
- [ ] Loading indicator appears
- [ ] Next 20 recipes load
- [ ] No duplicate recipes appear
- [ ] Smooth scrolling (no lag)

**Pass Criteria:** Pagination works without duplicates

**Mark result:** `./mark_test.sh P1-05 pass|fail "[notes]"`

---

### P1-06: Pull to Refresh

**Prerequisites:** Discovery feed open
**Estimated Time:** 2 minutes

**Steps:**
1. On any discovery tab, pull down to refresh
2. Observe refresh indicator
3. Wait for completion

**Expected Result:**
- [ ] Pull gesture triggers refresh
- [ ] Loading indicator appears
- [ ] Feed refreshes within 2 seconds
- [ ] New recipes may appear (if published recently)
- [ ] Indicator disappears on completion

**Pass Criteria:** Pull-to-refresh works, completes within 2 seconds

**Mark result:** `./mark_test.sh P1-06 pass|fail "[notes]"`

---

### P1-07: Empty Discovery Feed

**Prerequisites:** Fresh Firebase instance with NO public recipes (or use feature flag to simulate)
**Estimated Time:** 2 minutes

**Steps:**
1. Open discovery feed when no recipes exist
2. Check each tab

**Expected Result:**
- [ ] Empty state displays
- [ ] Message says "No recipes yet" or similar
- [ ] Icon visible (empty state illustration)
- [ ] Helpful text: "Be the first to share!" or similar
- [ ] No crash or loading spinner stuck

**Pass Criteria:** Empty state displays correctly

**Mark result:** `./mark_test.sh P1-07 pass|fail "[notes]"`

---

### P1-08: Search Empty Results

**Prerequisites:** Discovery feed open
**Estimated Time:** 1 minute

**Steps:**
1. Search for nonsense query (e.g., "zzzxxx999")

**Expected Result:**
- [ ] Empty state displays
- [ ] Message: "No results found"
- [ ] Suggestion to try different keywords
- [ ] Clear button allows return to full feed

**Pass Criteria:** Empty search state handled gracefully

**Mark result:** `./mark_test.sh P1-08 pass|fail "[notes]"`

---

### P1-09: Recipe Detail - No Image

**Prerequisites:** Find or create public recipe without image
**Estimated Time:** 2 minutes

**Steps:**
1. View public recipe that has no image
2. Observe placeholder

**Expected Result:**
- [ ] Placeholder image displays (fork/knife icon on cream background)
- [ ] No broken image icon
- [ ] Layout still correct
- [ ] Recipe otherwise displays normally

**Pass Criteria:** Placeholder displays correctly

**Mark result:** `./mark_test.sh P1-09 pass|fail "[notes]"`

---

### P1-10: Saved Recipe Attribution

**Prerequisites:** P0-05 passed (saved recipe from discovery)
**Estimated Time:** 3 minutes

**Steps:**
1. Open recipe saved from discovery
2. Scroll to attribution section
3. Tap "View Original" button

**Expected Result:**
- [ ] Attribution section visible: "Based on recipe by [Creator]"
- [ ] Creator name displays
- [ ] "View Original" button present
- [ ] Last checked timestamp visible
- [ ] Tapping "View Original" opens PublicRecipeDetailView
- [ ] Original recipe loads correctly

**Pass Criteria:** Attribution works, links to original

**Mark result:** `./mark_test.sh P1-10 pass|fail "[notes]"`

---

### P1-11: Publish Recipe With Image

**Prerequisites:** Recipe with photo attached
**Estimated Time:** 4 minutes

**Steps:**
1. Create or open recipe with image
2. Publish recipe
3. Wait for upload
4. Verify in discovery

**Expected Result:**
- [ ] Image uploads during publish
- [ ] Loading indicator shows progress
- [ ] Publish completes within 5 seconds
- [ ] Recipe appears in discovery with image
- [ ] Image quality acceptable (not too compressed)

**Pass Criteria:** Image publishes successfully

**Mark result:** `./mark_test.sh P1-11 pass|fail "[notes]"`

---

### P1-12: Unpublish Preserves Stats

**Prerequisites:** Published recipe with views/saves
**Estimated Time:** 3 minutes

**Steps:**
1. Publish recipe
2. View it in discovery (increment view count)
3. Note view count
4. Unpublish recipe
5. Check local recipe stats

**Expected Result:**
- [ ] Recipe unpublishes successfully
- [ ] Local recipe retains publicViewCount
- [ ] Local recipe retains publicSaveCount
- [ ] Stats visible in recipe detail (for re-publishing)
- [ ] Globe badge removed from card

**Pass Criteria:** Stats preserved after unpublish

**Mark result:** `./mark_test.sh P1-12 pass|fail "[notes]"`

---

### P1-13: Category Filters

**Prerequisites:** Discovery feed has recipes with tags
**Estimated Time:** 3 minutes

**Steps:**
1. Open discovery feed
2. Tap a category chip (e.g., "Dessert", "Dinner")
3. Observe filtered results

**Expected Result:**
- [ ] Category chips visible below search bar
- [ ] Tapping chip filters results
- [ ] Only matching recipes show
- [ ] Chip highlights when selected
- [ ] Tapping again deselects filter
- [ ] Multiple filters work together (AND logic)

**Pass Criteria:** Filters work correctly

**Mark result:** `./mark_test.sh P1-13 pass|fail "[notes]"`

---

### P1-14: Search Debounce

**Prerequisites:** Discovery feed open
**Estimated Time:** 2 minutes

**Steps:**
1. Tap search bar
2. Type quickly: "c", "ch", "chi", "chic", "chick", "chicke", "chicken"
3. Observe when search executes

**Expected Result:**
- [ ] Search does NOT fire on every keystroke
- [ ] Search waits ~300ms after last keystroke
- [ ] Only 1-2 queries executed (not 7)
- [ ] Performance remains smooth

**Pass Criteria:** Debouncing works (not querying on every key)

**Mark result:** `./mark_test.sh P1-14 pass|fail "[notes]"`

---

### P1-15: Report Duplicate Prevention

**Prerequisites:** Already reported a recipe (P0-10)
**Estimated Time:** 2 minutes

**Steps:**
1. Open same recipe you reported in P0-10
2. Try to report again

**Expected Result:**
- [ ] Error alert appears
- [ ] Message: "You've already reported this recipe"
- [ ] Report not submitted again
- [ ] Sheet dismisses or shows error

**Pass Criteria:** Duplicate reports blocked

**Mark result:** `./mark_test.sh P1-15 pass|fail "[notes]"`

---

### P1-16: Trending Score Calculation

**Prerequisites:** Wait 24 hours after publishing recipes (or manually trigger Cloud Function)
**Estimated Time:** 3 minutes (+ 24 hour wait)

**Steps:**
1. Verify `calculateTrendingScores` Cloud Function ran (check logs)
2. Check Firestore for recipes with trendingScore field
3. Verify trending tab shows correct order

**Expected Result:**
- [ ] Cloud Function executed successfully
- [ ] All recipes have trendingScore field
- [ ] Trending tab sorts by trendingScore descending
- [ ] Recent recipes with engagement appear at top
- [ ] Old recipes with no engagement near bottom

**Pass Criteria:** Trending scores calculated and sorting works

**Mark result:** `./mark_test.sh P1-16 pass|fail "[notes]"`

---

### P1-17: View Count Increment

**Prerequisites:** Published recipe
**Estimated Time:** 2 minutes

**Steps:**
1. Note initial view count on your published recipe
2. View recipe detail in discovery (from different account or device if possible)
3. Refresh and check view count

**Expected Result:**
- [ ] View count increments by 1
- [ ] Increment happens within 5 seconds
- [ ] Cloud Function `incrementPublicRecipeView` executed successfully

**Pass Criteria:** View count increments

**Mark result:** `./mark_test.sh P1-17 pass|fail "[notes]"`

---

### P1-18: Save Count Increment

**Prerequisites:** Published recipe
**Estimated Time:** 2 minutes

**Steps:**
1. Note initial save count
2. Save recipe from discovery (different account if possible)
3. Check save count

**Expected Result:**
- [ ] Save count increments by 1
- [ ] Cloud Function `incrementPublicRecipeSave` executed successfully

**Pass Criteria:** Save count increments

**Mark result:** `./mark_test.sh P1-18 pass|fail "[notes]"`

---

## P1 Summary

**Total P1 Tests:** 18
**Estimated Time:** ~45 minutes
**Target:** 95%+ pass rate (17/18)

**Check Progress:** `./mark_test.sh status`

---

## P2: Polish & Edge Cases (SHOULD PASS FOR FULL LAUNCH) - ~30 minutes

### P2-01: Recipe With Long Title (100+ chars)

**Expected:** Title truncates or wraps gracefully

**Mark result:** `./mark_test.sh P2-01 pass|fail "[notes]"`

---

### P2-02: Recipe With 50+ Tags

**Expected:** Tags display without breaking layout

**Mark result:** `./mark_test.sh P2-02 pass|fail "[notes]"`

---

### P2-03: Recipe With 100+ Ingredients

**Expected:** Ingredient list scrolls, no performance issues

**Mark result:** `./mark_test.sh P2-03 pass|fail "[notes]"`

---

### P2-04: Offline - View Discovery

**Expected:** Cached results show, or helpful offline message

**Mark result:** `./mark_test.sh P2-04 pass|fail "[notes]"`

---

### P2-05: Offline - Publish Recipe

**Expected:** Error message: "No internet connection. Try again when online."

**Mark result:** `./mark_test.sh P2-05 pass|fail "[notes]"`

---

### P2-06: Slow Network - Discovery Load

**Expected:** Loading indicator, timeout after 10s with retry option

**Mark result:** `./mark_test.sh P2-06 pass|fail "[notes]"`

---

### P2-07: Re-publish After Unpublish

**Expected:** Recipe publishes again, gets new publicRecipeId, stats reset

**Mark result:** `./mark_test.sh P2-07 pass|fail "[notes]"`

---

### P2-08: Publish Same Recipe Twice

**Expected:** Second publish updates existing or shows error

**Mark result:** `./mark_test.sh P2-08 pass|fail "[notes]"`

---

### P2-09: View Deleted Recipe (Deep Link)

**Expected:** Error: "Recipe not found" or "Recipe no longer available"

**Mark result:** `./mark_test.sh P2-09 pass|fail "[notes]"`

---

### P2-10: Memory Usage During Long Scroll

**Expected:** Memory stays < 200MB, no leaks

**Mark result:** `./mark_test.sh P2-10 pass|fail "[notes]"`

---

## P2 Summary

**Total P2 Tests:** 10
**Estimated Time:** ~30 minutes
**Target:** 80%+ pass rate (8/10)

---

## P3: Accessibility Tests (WCAG 2.1 AA) - ~20 minutes

### P3-01: VoiceOver - Discovery Navigation

**Expected:** All elements announced, navigation works without sight

**Mark result:** `./mark_test.sh P3-01 pass|fail "[notes]"`

---

### P3-02: VoiceOver - Publish Flow

**Expected:** Can publish recipe using VoiceOver only

**Mark result:** `./mark_test.sh P3-02 pass|fail "[notes]"`

---

### P3-03: Dynamic Type - Maximum Size

**Expected:** All text readable, buttons tappable at largest size

**Mark result:** `./mark_test.sh P3-03 pass|fail "[notes]"`

---

### P3-04: Color Contrast Check

**Expected:** All text meets WCAG AA contrast ratios (4.5:1)

**Mark result:** `./mark_test.sh P3-04 pass|fail "[notes]"`

---

### P3-05: Keyboard Navigation (iPad)

**Expected:** All interactive elements reachable via keyboard

**Mark result:** `./mark_test.sh P3-05 pass|fail "[notes]"`

---

## P3 Summary

**Total P3 Tests:** 5
**Estimated Time:** ~20 minutes
**Target:** 100% pass (accessibility is critical)

---

## Final Summary

**Total Tests:** 45
- **P0 (Critical):** 12 tests - ~30 min - MUST PASS 100%
- **P1 (Core):** 18 tests - ~45 min - TARGET 95%
- **P2 (Polish):** 10 tests - ~30 min - TARGET 80%
- **P3 (Accessibility):** 5 tests - ~20 min - TARGET 100%

**Total Estimated Time:** ~2 hours 5 minutes

**Check Overall Progress:** `./mark_test.sh status`

**View Detailed Results:** `cat test_progress.json | jq`

---

## Post-Testing

### If All P0 Tests Pass
✅ Feature is ready for internal beta testing

### If 95% of P0+P1 Tests Pass
✅ Feature is ready for external beta (TestFlight)

### If 90% of All Tests Pass
✅ Feature is ready for production launch

### If Critical Tests Fail
❌ Address issues, re-run failed tests, document blockers

---

**Happy Testing! 🧪**
