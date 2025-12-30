# Phase 2 Manual Testing Guide

Complete manual testing checklist for all Phase 2 features before Prompt 12 integration.

---

## Prerequisites

### Automated Tests (Run First)

**✅ XCTest Suite (53 tests)**
```bash
# In Xcode, press ⌘+U to run all tests
# Expected: 53 passing (AIRecipeExtractor + IngredientParser)
# Note: SwiftData tests have infrastructure issues - use in-app harness instead
```

**✅ In-App Test Harness (7 tests)**
1. Build and run Heirloom in DEBUG mode
2. Add DebugTestView to your app (see AUTOMATED_TESTING_GUIDE.md)
3. Navigate to Debug Tests view
4. Tap "Run All Tests"
5. Verify all 7 tests pass:
   - ✅ Migration creates base version
   - ✅ Migration copies all recipe data
   - ✅ Migration is idempotent
   - ✅ Migration stats are accurate
   - ✅ Recipe computed properties
   - ✅ Recipe-Version relationships
   - ✅ Multi-recipe import flow

**Expected Results:**
- XCTest: 53/53 passing
- In-App Harness: 7/7 passing
- **Total: 60 automated tests**

See `AUTOMATED_TESTING_GUIDE.md` for detailed setup instructions.

### What's Automated (No Manual Testing Needed)
- ✅ Recipe ingredient parsing (28 tests)
- ✅ OCR text extraction logic (25 tests)
- ✅ Recipe migration service (4 tests)
- ✅ Recipe model computed properties (2 tests)
- ✅ Multi-recipe import flow (1 test)

### Test Devices Setup
- **Device A (Primary)**: Your main development iPhone/Simulator
- **Device B (Secondary)**: Physical device or different simulator
- Both devices signed in to same iCloud account
- Both devices have Heirloom installed

---

## Phase 2A: Social Infrastructure (Provenance Tracking)

### Test 1: Recipe Creation Provenance
**Goal:** Verify all new recipes get provenance metadata

1. Create a new recipe manually
   - Open Heirloom
   - Tap "+" > "New Recipe"
   - Fill in title: "Test Recipe - Manual"
   - Add 2-3 ingredients
   - Save

2. Verify provenance
   - Recipe should show "Original" badge
   - No generation number
   - Check recipe detail view for attribution

**Expected:** Recipe marked as generation 0, sourceType: .userCreated

---

## Phase 2B: OCR Enhancement

### Test 2: OCR Recipe Scanning
**Goal:** Test Vision framework OCR with physical recipe cards

**Materials Needed:**
- 3-5 printed recipe cards (clear text)
- 2 handwritten recipe cards
- 1 recipe card with poor lighting photo

**Test Steps:**

1. **Printed Recipe Card (High Quality)**
   - Tap "+" > "Scan Cookbook"
   - Point camera at printed recipe card
   - Capture image
   - Review OCR results in OCRReviewView
   - **Expected:**
     - OCR Quality: "Excellent" or "Good"
     - Parse Confidence: >0.8
     - Title extracted correctly
     - 90%+ ingredients detected
     - Instructions numbered correctly

2. **Handwritten Recipe Card**
   - Scan handwritten recipe
   - Review OCR results
   - **Expected:**
     - OCR Quality: "Fair" or "Good"
     - Parse Confidence: 0.6-0.8
     - Some manual corrections needed
     - Can edit in OCRReviewView

3. **Poor Quality Image**
   - Take photo with shadows/glare
   - **Expected:**
     - OCR Quality: "Poor" warning
     - Suggestion to retake photo
     - Quality indicators show issues

4. **Edit and Save**
   - Correct any OCR mistakes in review screen
   - Add missing ingredients
   - Fix instruction text
   - Save recipe
   - **Expected:**
     - Recipe saved with sourceType: .scan
     - Shows "doc.viewfinder" icon
     - Analytics event .recipeScanned tracked

**Success Criteria:**
- Printed recipes: 95% accuracy
- Handwritten recipes: 85% accuracy
- Can edit and save all scanned recipes

---

## Phase 2C: Social Features

### Test 3: Privacy Consent Dialog
**Goal:** Test first-launch privacy consent flow

1. **Fresh Install Simulation**
   - Delete app and reinstall OR
   - Clear UserDefaults: Settings > Reset Consent
   - Launch app

2. **Consent Dialog Display**
   - **Expected:**
     - ConsentDialogView appears immediately
     - Cannot dismiss without choice
     - Shows two toggle options:
       - "Enable Recipe Sharing"
       - "Enable Analytics"
     - Clear explanations for each
     - Privacy policy link visible

3. **Grant Sharing Only**
   - Toggle ON: Recipe Sharing
   - Toggle OFF: Analytics
   - Tap "Continue"
   - **Expected:**
     - Dialog dismisses
     - Sharing features enabled
     - Analytics features disabled
     - Can share recipes
     - No trending data synced

4. **Grant Both Consents**
   - Go to Settings > Privacy
   - Toggle ON: Analytics
   - **Expected:**
     - Both features enabled
     - Engagement tracking starts
     - Can see trending recipes

### Test 4: QR Code Generation
**Goal:** Generate and scan QR codes for recipe sharing

**On Device A:**

1. **Generate QR Code**
   - Open any recipe
   - Tap share button
   - Select "QR Code"
   - **Expected:**
     - QRCodeShareSheet displays
     - Shows branded QR code with recipe title
     - "Scan to import recipe" text visible
     - QR code is 600x680 pixels (with branding)

2. **Save to Photos**
   - Tap "Save to Photos"
   - **Expected:**
     - Permission requested (first time)
     - QR code saved to Photos library
     - Success toast appears
     - Can find in Photos app

3. **Share QR Image**
   - Tap "Share QR Code"
   - **Expected:**
     - iOS share sheet appears
     - Can send via Messages, AirDrop, etc.

**On Device B:**

4. **Scan QR Code**
   - Display QR code on Device A screen OR
   - Use saved QR code image
   - On Device B: Tap "+" > "Scan QR Code"
   - Point camera at QR code
   - **Expected:**
     - Scanner reticle overlay visible
     - Corner brackets animate
     - Haptic feedback on successful scan
     - Imports recipe automatically
     - Recipe shows up with provenance

5. **Verify Import**
   - Check imported recipe details
   - **Expected:**
     - Recipe title matches original
     - All ingredients imported
     - Instructions intact
     - Provenance shows generation 1
     - Attribution to Device A user

**Success Criteria:**
- QR generates in < 200ms
- Scan detects QR in < 2 seconds
- Recipe imports successfully
- All data preserved

### Test 5: Comment Sharing
**Goal:** Test comment scope and lineage

**On Device A (Original Recipe):**

1. **Add Private Comment**
   - Open recipe
   - Go to Comments tab
   - Add comment: "My private notes"
   - Set scope: Private
   - Save
   - **Expected:**
     - Comment visible only on Device A
     - Not synced to CloudKit

2. **Add Family Comment**
   - Add comment: "This is great for family gatherings"
   - Set scope: Family (Lineage)
   - Save
   - **Expected:**
     - Comment synced to CloudKit
     - Will appear on forked copies
     - Shows author attribution

3. **Add Public Comment**
   - Add comment: "Best recipe ever!"
   - Set scope: Public
   - Save
   - **Expected:**
     - Comment synced to CloudKit
     - Visible to all who import recipe

**On Device B (Import Recipe):**

4. **Share Recipe to Device B**
   - Use QR code or share link
   - Import on Device B

5. **View Comments**
   - Open imported recipe
   - Go to Comments tab
   - **Expected:**
     - See Family and Public comments from Device A
     - NOT seeing Private comments
     - Attribution shows "via [Device A user]"
     - Can endorse comments (thumbs up)

6. **Add Own Comment**
   - Add comment on Device B
   - Set scope: Family
   - **Expected:**
     - Comment synced back
     - Visible across lineage

**Success Criteria:**
- Private comments stay private
- Family comments visible to lineage
- Public comments visible to all
- Attribution works correctly
- Endorsements sync

### Test 6: Privacy Settings Management
**Goal:** Test privacy controls and data export

1. **View Privacy Dashboard**
   - Go to Settings > Privacy
   - **Expected:**
     - Shows current consent status
     - Last updated timestamps
     - Clear toggle switches

2. **Revoke Sharing Consent**
   - Toggle OFF: Recipe Sharing
   - **Expected:**
     - Share buttons disabled
     - Toast: "Sharing features disabled"
     - Existing shares remain accessible

3. **Revoke Analytics Consent**
   - Toggle OFF: Analytics
   - **Expected:**
     - Engagement tracking stops
     - No more CloudKit sync for trending
     - Discovery feed may show less data

4. **Export Data (GDPR)**
   - Tap "Export My Data"
   - **Expected:**
     - JSON file generated with:
       - All recipes
       - All comments
       - Privacy consent history
     - ShareLink appears
     - Can save or share file

5. **View Shared Recipes**
   - Tap "View Shared Recipes"
   - **Expected:**
     - List of all recipes you've shared
     - Share counts
     - Can unshare

**Success Criteria:**
- Consent changes take effect immediately
- Data export completes
- Export JSON is valid and complete

---

## Phase 2D: Lineage & Analytics

### Test 7: Recipe Lineage Visualization
**Goal:** Test interactive family tree display

**Setup: Create Test Lineage**

1. **On Device A: Create Root Recipe**
   - Create recipe: "Original Chocolate Chip Cookies"
   - Add ingredients and instructions
   - Share via QR code

2. **On Device B: Fork Recipe**
   - Scan QR code
   - Import recipe (now generation 1)
   - Edit recipe: Change title to "Mom's Chocolate Chip Cookies"
   - Modify 1-2 ingredients
   - Save (creates fork)
   - Share this version

3. **On Device A: Import Fork**
   - Scan Device B's QR code
   - Import the fork (generation 2 from B's perspective)

**Test Graph View:**

4. **Open Lineage View**
   - Open "Original Chocolate Chip Cookies"
   - Tap "View Lineage" button
   - **Expected:**
     - LineageContainerView opens
     - Graph/Timeline toggle visible
     - Default to Graph view

5. **Graph Interaction**
   - **Expected nodes:**
     - Root node (red, "Original")
     - Child nodes (blue, "1st Gen")
     - Edges connecting them
   - **Test interactions:**
     - Pinch to zoom (0.5x to 3x)
     - Drag to pan
     - Tap node to see stats
   - **Verify:**
     - Stats card shows:
       - Total nodes
       - Total generations
       - Total cooks across lineage
     - Selected node highlighted
     - Generation colors correct

6. **Switch to Timeline View**
   - Tap timeline toggle
   - **Expected:**
     - Chronological list
     - Generation dots on left
     - Timeline lines connecting nodes
     - Recipe cards with stats
     - Sort options: Date/Generation/Popularity

7. **Test Layout Algorithms**
   - Open controls menu (slider icon)
   - Switch layouts:
     - Tree View (hierarchical)
     - Timeline (chronological)
   - **Expected:**
     - Smooth animation between layouts
     - Nodes reposition correctly
     - All nodes remain visible

**Success Criteria:**
- Graph renders all nodes
- Gestures work smoothly (60fps)
- Generation colors correct
- Stats accurate
- Can navigate lineage

### Test 8: Generation Badges on Recipe Cards
**Goal:** Verify generation badges display

1. **View Recipe List**
   - Go to main recipe list
   - **Expected for original recipes:**
     - No badge shown
   - **Expected for imported recipes:**
     - Badge shows "1st Gen", "2nd Gen", etc.
     - Badge color matches generation
     - Badge positioned bottom-right of card

2. **Test Multiple Generations**
   - Create lineage with 3+ generations
   - **Expected:**
     - Original: No badge
     - 1st Gen: Blue badge
     - 2nd Gen: Green badge
     - 3rd Gen: Orange badge
     - 4th+: Gray badge

**Success Criteria:**
- Badges only on forked recipes
- Colors match generation
- Text reads correctly ("1st Gen" not "1th Gen")

### Test 9: Trending Algorithm & Discovery Feed
**Goal:** Test trending calculation and feed display

**Setup: Generate Engagement Data**

1. **Create Engagement on Multiple Recipes**
   - Recipe A: View 10 times, cook 3 times
   - Recipe B: View 5 times, cook 1 time, share once
   - Recipe C: View 20 times, save 5 times, cook 8 times
   - Recipe D: View 2 times (old engagement, 7+ days ago)

2. **Open Discovery Feed**
   - Tap "Discover" tab (if integrated) OR
   - Open DiscoveryView from menu
   - **Expected:**
     - Three tabs: Trending, New, Popular
     - Default to Trending tab

**Test Trending Tab:**

3. **Verify Trending Recipes**
   - **Expected order (Recipe C should be #1):**
     - Recipe C: Highest engagement, badge "🔥 Hot"
     - Recipe B: Rising engagement, badge "📈 Rising"
     - Recipe A: Moderate engagement
     - Recipe D: Should rank low (old engagement)

4. **Check Trending Card UI**
   - **Each card shows:**
     - Recipe image
     - Title
     - Trending badge (🔥/📈/⭐)
     - Engagement stats: 👁️ views, 🔥 cooks, ↗️ shares
     - Trending score bar (0-100)
     - Score number

5. **Pull to Refresh**
   - Pull down on feed
   - **Expected:**
     - Loading indicator
     - Cache cleared
     - Scores recalculated
     - Feed updates

**Test New Tab:**

6. **Switch to New Tab**
   - **Expected:**
     - Recently shared recipes
     - Sorted by date descending
     - "NEW" badge with sparkles
     - Relative time ("2 hours ago")

**Test Popular Tab:**

7. **Switch to Popular Tab**
   - **Expected:**
     - All-time most engaged recipes
     - No time decay applied
     - Star icon badges
     - Sorted by total engagement

**Verify Trending Algorithm:**

8. **Check Score Accuracy**
   - Recipe with recent engagement should score higher
   - Recipe with old engagement should score lower
   - Weights applied correctly:
     - Shares worth 8x views
     - Cooks worth 5x views
     - Saves worth 3x views

9. **Verify Velocity Badges**
   - Recipe with increasing engagement: "🔥 Hot" (velocity > 50%)
   - Recipe with moderate growth: "📈 Rising" (velocity 20-50%)
   - Recipe with high score but low velocity: "⭐ Popular"

**Success Criteria:**
- Trending scores accurate (check math)
- Time decay working (old engagement scores lower)
- Velocity calculated correctly
- Badges match criteria
- Feed loads in < 2 seconds
- Cache works (instant on second load)

### Test 10: Personal Stats Dashboard
**Goal:** Test personal cooking statistics

1. **Open Personal Stats**
   - Go to Settings > Your Stats OR
   - Open PersonalStatsView from profile
   - **Expected:**
     - Overview cards with totals:
       - 📖 Total Recipes
       - 🔥 Total Cooks
       - ↗️ Total Shares
       - ❤️ Favorites Count

2. **Most Cooked Recipes**
   - **Expected:**
     - Top 5 recipes ranked
     - Rank badges (1, 2, 3, 4, 5)
     - Cook count for each
     - Flame icon

3. **Most Shared Recipes**
   - **Expected:**
     - Top 5 shared recipes
     - Share counts
     - Share icon

4. **Cooking Timeline**
   - **Expected:**
     - Bar chart showing last 30 days
     - Weekly aggregation
     - Bars show cook count per week
     - X-axis: Week numbers
     - Y-axis: Cook count

5. **Achievements**
   - **Expected achievements (if qualified):**
     - 📖 Recipe Collector (10+ recipes)
     - 📚 Recipe Library (50+ recipes)
     - 🔥 Home Chef (25+ cooks)
     - ⭐ Master Chef (100+ cooks)
     - ↗️ Recipe Sharer (10+ shares)
     - ❤️ Favorites Curator (10+ favorites)
   - **Display:**
     - Unlocked: Full color, checkmark
     - Locked: Grayscale, progress hint

6. **Pull to Refresh**
   - Pull down on stats
   - **Expected:**
     - Recalculates all stats
     - Updates in real-time

**Success Criteria:**
- All numbers accurate
- Chart renders correctly
- Achievements unlock at thresholds
- Stats update when data changes

---

## Integration Testing

### Test 11: Device A + Device B Full Flow
**Goal:** Complete end-to-end sharing and lineage test

**Device A (Creator):**

1. Create original recipe
2. Add comment (Family scope)
3. Generate QR code
4. Display QR code

**Device B (Recipient):**

5. Scan QR code
6. Verify recipe imported with provenance
7. Check comment appears
8. Endorse comment
9. Cook recipe (mark as cooked)
10. Fork recipe (modify and save)
11. Generate new QR code of fork

**Device A (Full Circle):**

12. Scan Device B's fork
13. Verify lineage tree now has 3 generations
14. Check trending score updates
15. Verify engagement tracking

**Success Criteria:**
- Complete cycle works end-to-end
- All data preserved through sharing
- Lineage tree accurate
- Comments follow recipes
- Engagement tracked correctly

---

## CloudKit Testing

### Test 12: CloudKit Public Database Sync
**Goal:** Verify all CloudKit operations

1. **Share Recipe (Upload)**
   - Share a recipe
   - **Expected:**
     - Recipe uploaded to public database
     - Provenance hash set
     - Share ID generated

2. **Import Recipe (Download)**
   - Import on second device
   - **Expected:**
     - Recipe downloaded from CloudKit
     - All fields intact
     - Images downloaded

3. **Comment Sync**
   - Add comment with Family scope
   - **Expected:**
     - Comment uploaded to CloudKit
     - Appears on other devices with same lineage

4. **Engagement Sync (if Analytics enabled)**
   - Cook a recipe
   - **Expected:**
     - Engagement record synced to CloudKit
     - Trending score updates globally

5. **Network Scenarios**
   - Test with WiFi off
   - **Expected:**
     - Graceful error handling
     - Retry logic kicks in
     - Queue for later sync

**Success Criteria:**
- All sync operations complete
- No data loss
- Errors handled gracefully
- Works across multiple devices

---

## Performance Testing

### Test 13: Performance Benchmarks

1. **QR Code Generation**
   - Generate 10 QR codes
   - **Expected:** < 200ms each

2. **OCR Processing**
   - Scan 5 recipe cards
   - **Expected:** < 5 seconds each

3. **Graph Rendering**
   - Lineage with 10+ nodes
   - **Expected:** 60fps, smooth gestures

4. **Trending Calculation**
   - 100+ recipes
   - **Expected:** < 2 seconds

5. **Feed Load Time**
   - Discovery feed with 20 items
   - **Expected:** < 1.5 seconds (first load)
   - **Expected:** < 0.3 seconds (cached)

---

## Bug Reporting Template

If you find issues, document with:

```markdown
## Bug Report

**Feature:** [e.g., QR Code Scanner]
**Device:** [e.g., iPhone 15 Pro, iOS 18.1]
**Steps to Reproduce:**
1.
2.
3.

**Expected Behavior:**

**Actual Behavior:**

**Screenshots:** [if applicable]

**Console Logs:** [if available]

**Severity:** [Critical/High/Medium/Low]
```

---

## Test Completion Checklist

### Phase 2A: Social Infrastructure
- [ ] Recipe provenance tracking works
- [ ] Generation counting correct

### Phase 2B: OCR Enhancement
- [ ] Printed recipe OCR: 95% accuracy
- [ ] Handwritten recipe OCR: 85% accuracy
- [ ] Can edit and save scanned recipes
- [ ] RecipeSourceType.scan works

### Phase 2C: Social Features
- [ ] Privacy consent dialog appears on first launch
- [ ] Can grant/revoke consents independently
- [ ] QR code generation works (< 200ms)
- [ ] QR code scanning works (< 2s)
- [ ] Comment sharing with 3 scopes works
- [ ] Privacy settings functional
- [ ] Data export (GDPR) works

### Phase 2D: Lineage & Analytics
- [ ] Lineage graph renders all nodes
- [ ] Graph gestures work (pan, zoom, tap)
- [ ] Timeline view sorts correctly
- [ ] Generation badges on recipe cards
- [ ] Trending algorithm calculates correctly
- [ ] Discovery feed loads (Trending, New, Popular)
- [ ] Personal stats accurate
- [ ] Achievements unlock correctly

### Integration
- [ ] Device A + Device B full cycle works
- [ ] CloudKit sync works
- [ ] All engagement tracking functional

### Performance
- [ ] All operations meet performance targets
- [ ] No crashes or memory leaks
- [ ] Smooth 60fps UI

---

## Next Steps After Testing

1. **Document all bugs found**
2. **Run automated tests: ⌘+U in Xcode**
3. **Fix critical issues**
4. **Retest failed scenarios**
5. **Ready for Prompt 12: Integration Phase**

---

**Testing Timeline Estimate:**
- Phase 2A: 15 minutes
- Phase 2B: 45 minutes (includes physical recipe cards)
- Phase 2C: 60 minutes
- Phase 2D: 45 minutes
- Integration: 30 minutes
- **Total: ~3 hours**

Good luck testing! 🧪
