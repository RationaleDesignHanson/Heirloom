# Heirloom iOS App - Comprehensive Testing Guide
**Build**: 1.1.3 (33+)
**Date**: 2025-12-29
**Status**: Pre-Deployment Testing

---

## Overview

This guide provides step-by-step testing procedures for all critical features before TestFlight deployment. Execute these tests in order and log any issues in the Bugs section at the bottom.

**Testing Devices Required:**
- Device A: iPhone with latest iOS (primary tester)
- Device B: Second iPhone with latest iOS (for sharing tests)
- Mac with Xcode (for console log monitoring)

---

## Pre-Test Setup

### 1. Prepare Testing Environment

```bash
# Terminal Window 1: Build and install to Device A
cd /Users/matthanson/Heirloom

# Clean build
xcodebuild clean -project Heirloom.xcodeproj -scheme Heirloom

# Build for device
xcodebuild -project Heirloom.xcodeproj \
  -scheme Heirloom \
  -configuration Release \
  -destination 'platform=iOS,id=YOUR_DEVICE_UDID' \
  build

# Install to device
# (Use Xcode UI: Product > Run on connected device)
```

### 2. Check Build Info

```bash
# Verify build number
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
  Heirloom/Resources/Info.plist

/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" \
  Heirloom/Resources/Info.plist
```

**Expected Output:**
- Version: 1.1.3
- Build: 33 (or higher)

### 3. Monitor Console Logs

```bash
# Terminal Window 2: Monitor device logs
# Replace DEVICE_UDID with your device ID

# Get device UDID
xcrun xctrace list devices

# Monitor logs (filter for Heirloom)
xcrun devicectl device info logs --device DEVICE_UDID | \
  grep -E "(Heirloom|CloudKit|Sync|✅|❌|📤|📥|🔄)"
```

### 4. CloudKit Dashboard Access

Open: https://icloud.developer.apple.com/dashboard
- Select: Heirloom app
- Environment: Development (for testing)
- Navigate to: Data > Query Records

---

## Test Suite 1: App Launch & Initialization (5 min)

### Test 1.1: First Launch
**Device:** Device A (fresh install)

**Steps:**
1. Delete app if previously installed
2. Install fresh build from Xcode
3. Launch app
4. Observe launch screen and initialization

**Console Log Check:**
```bash
# Look for initialization logs
grep "🚀 \[Heirloom\] HeirloomApp.init()" logs.txt
grep "✅ \[Heirloom\] SwiftData initialized" logs.txt
grep "✅ \[Heirloom\] CloudKit sync initialized" logs.txt
```

**Expected Results:**
- [ ] App launches without crash
- [ ] Launch screen displays (< 2 seconds)
- [ ] Main recipe list appears (empty state)
- [ ] Console shows: "SwiftData initialized (Local storage, manual CloudKit sync)"
- [ ] Console shows: "CloudKit sync initialized successfully"
- [ ] Console shows: "Automatic sync enabled"

**Log Bugs:**
```
Bug #:
Priority: P0/P1/P2/P3
Component: App Launch
Description:
Steps to Reproduce:
```

---

### Test 1.2: Empty State Display
**Device:** Device A (no recipes)

**Steps:**
1. Observe empty state on main screen
2. Check icon, title, message, action button
3. Tap "Add Recipe" button

**Expected Results:**
- [ ] Empty state displays with book icon
- [ ] Title: "No Recipes Yet"
- [ ] Message describes how to add recipes
- [ ] "Add Recipe" button is visible and tappable (min 44×44pt)
- [ ] Tapping button shows add menu

**Log Bugs:**
```
Bug #:
Priority:
Component: Empty States
Description:
```

---

## Test Suite 2: CloudKit Sync Infrastructure (15 min)

### Test 2.1: Initial Sync on Launch
**Device:** Device A

**Steps:**
1. Launch app (fresh or existing)
2. Wait 10 seconds
3. Check console logs for sync activity

**Console Log Check:**
```bash
# Look for sync initialization
grep "🔄 \[Heirloom\] Performing initial sync" logs.txt
grep "🔄 \[Heirloom\] Starting full sync" logs.txt
grep "✅ \[Heirloom\] Sync complete" logs.txt
```

**Expected Results:**
- [ ] Console shows: "Performing initial sync on startup"
- [ ] Console shows: "Starting full sync..."
- [ ] Console shows: "Sync complete" (within 5 seconds)
- [ ] No errors in console

**Log Bugs:**
```
Bug #:
Priority:
Component: CloudKit Sync
Description:
```

---

### Test 2.2: Recipe Upload to CloudKit
**Device:** Device A
**CloudKit Dashboard:** Open and ready

**Steps:**
1. Tap + button → "Add Sample Recipe"
2. Wait for recipe to appear in list
3. Wait 10 seconds for automatic sync
4. Check CloudKit Dashboard → Data → Query Records
5. Select "Recipe" record type
6. Click "Query Records"

**Console Log Check:**
```bash
grep "📤 \[Heirloom\] Uploading.*local changes" logs.txt
grep "✅ \[Heirloom\] Uploaded:" logs.txt
grep "cloudKitRecordID" logs.txt
```

**Expected Results:**
- [ ] Recipe appears in app immediately
- [ ] Console shows: "📤 [Heirloom] Uploading 1 local changes"
- [ ] Console shows: "✅ [Heirloom] Uploaded: [Recipe Name]"
- [ ] CloudKit Dashboard shows 1 Recipe record (within 10 seconds)
- [ ] Recipe record has populated fields (title, instructions, etc.)

**Log Bugs:**
```
Bug #:
Priority:
Component: CloudKit Upload
Description:
```

---

### Test 2.3: Ingredient Upload to CloudKit
**Device:** Device A
**CloudKit Dashboard:** Open

**Steps:**
1. From previous test, recipe should be uploaded
2. Click "Ingredient" record type in Dashboard
3. Click "Query Records"
4. Check for ingredients associated with the recipe

**Console Log Check:**
```bash
grep "📤 \[Heirloom\] Uploading.*ingredients" logs.txt
grep "Batch upload complete:" logs.txt
```

**Expected Results:**
- [ ] CloudKit Dashboard shows multiple Ingredient records
- [ ] Each ingredient has: originalText, name, quantity, unit, category
- [ ] Ingredients have recipeID matching the Recipe record
- [ ] Ingredients have correct orderIndex (0, 1, 2, ...)

**Log Bugs:**
```
Bug #:
Priority:
Component: CloudKit Ingredient Sync
Description:
```

---

### Test 2.4: Pull-to-Refresh Sync
**Device:** Device A

**Steps:**
1. On recipe list screen
2. Pull down to refresh
3. Observe sync status indicator
4. Wait for completion

**Console Log Check:**
```bash
grep "pull_to_refresh" logs.txt
grep "📥 \[Heirloom\] Fetching remote changes" logs.txt
```

**Expected Results:**
- [ ] Pull-to-refresh gesture works
- [ ] Spinner appears in toolbar (left of filter button)
- [ ] Light haptic feedback on pull
- [ ] Success haptic feedback on complete (0.3-0.5 seconds)
- [ ] Console shows: "pull_to_refresh" analytics event
- [ ] Spinner disappears after sync

**Log Bugs:**
```
Bug #:
Priority:
Component: Pull-to-Refresh
Description:
```

---

## Test Suite 3: Recipe Sharing (20 min)

### Test 3.1: Create Share Link
**Device:** Device A
**Prerequisite:** At least 1 recipe in app

**Steps:**
1. Open any recipe detail view
2. Tap "Share" button (top right)
3. Select "Via iCloud (Live Recipe)"
4. Fill out share form:
   - Enter your name in "Your Name" field
   - Add personal message (optional)
   - Leave other settings default
5. Tap "Create Share Link"
6. Wait for "Share Created!" success view

**Console Log Check:**
```bash
grep "📤 Creating share for recipe:" logs.txt
grep "✅ Share created successfully:" logs.txt
```

**Expected Results:**
- [ ] Share form loads with all sections visible
- [ ] "Your Name" text field is present and editable
- [ ] Preview card shows recipe with good color contrast
- [ ] Secondary text is readable (warmGray #6B6B6B)
- [ ] "Create Share Link" button is tappable
- [ ] Console shows: "Creating share for recipe: [Name]"
- [ ] Success screen appears with checkmark
- [ ] Share URL is displayed

**Log Bugs:**
```
Bug #:
Priority:
Component: Recipe Sharing
Description:
```

---

### Test 3.2: Share Link Distribution (Bug #4 Fix)
**Device:** Device A
**Success View:** From Test 3.1

**Steps:**
1. On "Share Created!" success view
2. Tap "Share Link" button (top blue button)
3. Observe iOS share sheet

**Expected Results:**
- [ ] iOS system share sheet opens
- [ ] Share sheet shows Messages, AirDrop, Copy, etc.
- [ ] No errors or "nothing happens"
- [ ] Can select Messages to share
- [ ] Share URL is included in message

**Log Bugs:**
```
Bug #:
Priority: P0 (Critical - blocks share flow)
Component: Share Distribution
Description:
```

---

### Test 3.3: Copy Link Function (Bug #6 Fix)
**Device:** Device A
**Success View:** From Test 3.1

**Steps:**
1. On "Share Created!" success view
2. Tap "Copy Link" button (second button)
3. Observe button state change
4. Open Notes app
5. Paste (long press → Paste)

**Expected Results:**
- [ ] Button changes to "Copied!" with checkmark icon
- [ ] Button changes back to "Copy Link" after 2 seconds
- [ ] Pasting in Notes shows CloudKit share URL
- [ ] URL starts with "https://www.icloud.com/share/"

**Log Bugs:**
```
Bug #:
Priority: P0 (Critical - blocks share flow)
Component: Copy to Clipboard
Description:
```

---

### Test 3.4: Retry Share Creation (Bug #5 Fix)
**Device:** Device A
**Prerequisite:** Share already created for a recipe

**Steps:**
1. Go back to same recipe detail view
2. Tap "Share" button again
3. Select "Via iCloud (Live Recipe)"
4. Tap "Create Share Link" again

**Console Log Check:**
```bash
grep "ℹ️ Reusing existing share for recipe" logs.txt
```

**Expected Results:**
- [ ] No error occurs
- [ ] Console shows: "ℹ️ Reusing existing share for recipe"
- [ ] Same share URL is returned
- [ ] Success view appears normally
- [ ] No "Record not found" error

**Log Bugs:**
```
Bug #:
Priority: P0 (Critical - blocks retry)
Component: Share Retry Logic
Description:
```

---

### Test 3.5: Accept Shared Recipe (Device B)
**Device:** Device B (recipient)
**Prerequisite:** Share URL from Test 3.2

**Steps:**
1. On Device B, open Messages app
2. Receive share URL from Device A
3. Tap the iCloud share link
4. Tap "Open" to launch Heirloom
5. Observe share acceptance flow
6. Tap "Accept" to add recipe

**Console Log Check (Device B):**
```bash
grep "🎁 \[Heirloom\] Accepting share:" logs.txt
grep "✅ \[Heirloom\] Share accepted" logs.txt
```

**Expected Results:**
- [ ] Link opens Heirloom app
- [ ] Share acceptance UI displays recipe preview
- [ ] "Accept" button is visible
- [ ] Tapping Accept adds recipe to Device B
- [ ] Recipe appears in Device B's recipe list
- [ ] Recipe includes all ingredients (not just IDs)
- [ ] Recipe provenance shows shared from Device A user

**Log Bugs:**
```
Bug #:
Priority: P0 (Critical - core sharing feature)
Component: Share Acceptance
Description:
```

---

## Test Suite 4: Camera & OCR (15 min)

### Test 4.1: Camera Viewport Fill
**Device:** Device A

**Steps:**
1. Tap + → "Scan Cookbook"
2. Allow camera permission if prompted
3. Observe camera preview
4. Rotate device to landscape
5. Rotate back to portrait

**Expected Results:**
- [ ] Camera preview fills entire screen (no black bars)
- [ ] Preview rotates smoothly with device orientation
- [ ] Guide overlay is visible
- [ ] Capture button is accessible (44×44pt minimum)
- [ ] Quality indicator shows in real-time

**Log Bugs:**
```
Bug #:
Priority:
Component: Camera Preview
Description:
```

---

### Test 4.2: OCR Processing with Progress
**Device:** Device A
**Material:** Printed recipe card or cookbook page

**Steps:**
1. In camera view, point at recipe
2. Tap capture button
3. Observe captured image preview
4. Tap "Process" button
5. Observe processing overlay

**Expected Results:**
- [ ] Capture shows medium haptic feedback
- [ ] Captured image displays clearly
- [ ] "Process" button is visible
- [ ] Processing overlay shows:
   - Spinner
   - "Analyzing recipe card..." message
   - "Using AI vision to detect and extract recipes" subtitle
- [ ] Processing completes within 10-15 seconds
- [ ] Success haptic on completion

**Log Bugs:**
```
Bug #:
Priority:
Component: OCR Processing
Description:
```

---

### Test 4.3: Multi-Recipe Detection
**Device:** Device A
**Material:** Page with 2+ recipes

**Steps:**
1. Scan page with multiple recipes
2. Process the image
3. Observe RecipeSelectionView
4. Select one recipe
5. Tap "Import Selected"

**Console Log Check:**
```bash
grep "Found.*recipe(s)" logs.txt
grep "Extracted.*recipe(s)" logs.txt
```

**Expected Results:**
- [ ] Console shows: "Found X recipe(s)"
- [ ] RecipeSelectionView displays all detected recipes
- [ ] Each recipe shows title, ingredient count, instruction count
- [ ] Can select individual recipes
- [ ] Import button adds selected recipes to library

**Log Bugs:**
```
Bug #:
Priority:
Component: Multi-Recipe OCR
Description:
```

---

## Test Suite 5: UX Polish & Interactions (10 min)

### Test 5.1: Swipe Gestures
**Device:** Device A
**Prerequisite:** 2+ recipes in list

**Steps:**
1. On recipe list, swipe recipe card left (trailing edge)
2. Observe delete button
3. Release (don't delete)
4. Swipe same recipe card right (leading edge)
5. Observe favorite button
6. Tap favorite button

**Expected Results:**
- [ ] Left swipe reveals red "Delete" button
- [ ] Full swipe deletes with confirmation dialog
- [ ] Right swipe reveals yellow "Favorite" button
- [ ] Tapping favorite adds to favorites
- [ ] Light haptic feedback on favorite
- [ ] Toast shows "Added to favorites"

**Log Bugs:**
```
Bug #:
Priority:
Component: Swipe Actions
Description:
```

---

### Test 5.2: Touch Target Sizes
**Device:** Device A

**Steps:**
1. Measure key interactive elements:
   - Add recipe button (+)
   - Filter button
   - Recipe card tap area
   - Swipe action buttons
   - Navigation bar buttons

**Measurement Tool:**
- Use Xcode View Debugger (Debug → View Debugging → Capture View Hierarchy)
- Or measure visually: 1 point ≈ 1/163 inch on iPhone

**Expected Results:**
- [ ] All buttons are minimum 44×44 points
- [ ] Recipe cards are easily tappable
- [ ] Swipe action buttons are minimum height
- [ ] No false taps from small targets

**Log Bugs:**
```
Bug #:
Priority: P1 (Accessibility issue)
Component: Touch Targets
Description:
Size: [actual size]
Minimum: 44×44pt
```

---

### Test 5.3: Haptic Feedback Consistency
**Device:** Device A

**Test all haptic locations:**
- [ ] Pull-to-refresh: Light impact
- [ ] Refresh complete: Success notification
- [ ] Delete recipe: Medium impact
- [ ] Toggle favorite: Light impact
- [ ] Add to shopping list: Medium impact
- [ ] Remove from shopping list: Light impact
- [ ] Recipe import success: Success notification
- [ ] Recipe import error: Error notification
- [ ] Camera capture: Medium impact
- [ ] OCR complete: Success notification

**Expected Results:**
- [ ] All haptics fire at appropriate moments
- [ ] Haptic styles match action severity
- [ ] No haptics on read-only actions

**Log Bugs:**
```
Bug #:
Priority: P2 (UX polish)
Component: Haptic Feedback
Location:
Expected: [type]
Actual: [behavior]
```

---

## Test Suite 6: Error Handling & Edge Cases (10 min)

### Test 6.1: Offline Mode
**Device:** Device A

**Steps:**
1. Enable Airplane Mode
2. Try to import recipe from URL
3. Try to share a recipe
4. Try to pull-to-refresh

**Expected Results:**
- [ ] Import shows network error message
- [ ] Share shows "Check connection" message
- [ ] Pull-to-refresh shows offline status
- [ ] App doesn't crash
- [ ] Clear error messages displayed

**Log Bugs:**
```
Bug #:
Priority:
Component: Offline Handling
Description:
```

---

### Test 6.2: CloudKit Sync Conflicts
**Device:** Device A & B

**Steps:**
1. On Device A: Edit recipe title
2. On Device B: Edit same recipe title (different text)
3. Wait for both to sync
4. Check final state on both devices

**Console Log Check:**
```bash
grep "⚠️ \[Heirloom\] Conflict detected" logs.txt
grep "Resolving conflict" logs.txt
```

**Expected Results:**
- [ ] Both edits sync without crash
- [ ] Last-write-wins conflict resolution applies
- [ ] No data loss
- [ ] Final state is consistent across devices

**Log Bugs:**
```
Bug #:
Priority: P1 (Data integrity)
Component: Sync Conflicts
Description:
```

---

### Test 6.3: Large Dataset Performance
**Device:** Device A

**Steps:**
1. Add 20+ sample recipes (use "Add Sample Recipe" repeatedly)
2. Scroll through recipe list
3. Search for a recipe
4. Filter recipes
5. Observe performance

**Expected Results:**
- [ ] Smooth scrolling (60 fps)
- [ ] Search is instant
- [ ] Filters apply quickly
- [ ] No lag or stuttering
- [ ] Memory usage is reasonable

**Log Bugs:**
```
Bug #:
Priority:
Component: Performance
Description:
```

---

## Test Suite 7: Accessibility (5 min)

### Test 7.1: VoiceOver Support
**Device:** Device A

**Steps:**
1. Enable VoiceOver (Settings → Accessibility → VoiceOver)
2. Navigate recipe list
3. Open recipe detail
4. Try to share a recipe
5. Disable VoiceOver

**Expected Results:**
- [ ] All UI elements have accessibility labels
- [ ] Navigation is logical
- [ ] Buttons announce purpose
- [ ] Images are hidden or have descriptions
- [ ] No "Button Button" or unlabeled elements

**Log Bugs:**
```
Bug #:
Priority: P1 (Accessibility requirement)
Component: VoiceOver
Element:
Issue:
```

---

### Test 7.2: Dynamic Type Support
**Device:** Device A

**Steps:**
1. Settings → Display & Brightness → Text Size
2. Increase text size to maximum
3. Return to Heirloom app
4. Observe layout

**Expected Results:**
- [ ] Text scales appropriately
- [ ] No text truncation
- [ ] Buttons remain tappable
- [ ] Layout adjusts dynamically
- [ ] No overlapping UI elements

**Log Bugs:**
```
Bug #:
Priority: P1 (Accessibility requirement)
Component: Dynamic Type
Screen:
Issue:
```

---

## Test Suite 8: Final Verification (5 min)

### Test 8.1: Build Metadata
```bash
# Check Info.plist values
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
  Heirloom/Resources/Info.plist

/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" \
  Heirloom/Resources/Info.plist

/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" \
  Heirloom/Resources/Info.plist
```

**Expected Output:**
- [ ] Version: 1.1.3
- [ ] Build: 33 or higher
- [ ] Display Name: Heirloom

---

### Test 8.2: App Store Assets Ready
**Check:**
- [ ] App icon (1024×1024)
- [ ] Screenshots (all required sizes)
- [ ] Privacy policy URL
- [ ] Support URL
- [ ] Marketing description
- [ ] What's New text

---

### Test 8.3: CloudKit Production Schema
**CloudKit Dashboard:**
1. Switch to Production environment
2. Navigate to Schema
3. Verify record types exist:
   - [ ] Recipe
   - [ ] Ingredient
   - [ ] cloudkit.share

**Recipe Record Type Fields:**
- [ ] title (String, queryable)
- [ ] instructions (String)
- [ ] servings (String)
- [ ] prepTime (String)
- [ ] cookTime (String)
- [ ] imageFileName (String)
- [ ] sourceType (String)
- [ ] sourceURL (String)
- [ ] notes (String)
- [ ] All metadata fields

**Ingredient Record Type Fields:**
- [ ] ingredientID (String)
- [ ] recipeID (String, queryable)
- [ ] originalText (String)
- [ ] name (String)
- [ ] quantity (Double)
- [ ] unit (String)
- [ ] category (String)
- [ ] orderIndex (Int64, queryable)
- [ ] All 14+ ingredient fields

---

## Bug Tracking

### Critical Bugs (P0) - MUST FIX BEFORE DEPLOYMENT

```
Bug #___: [Title]
Component:
Severity: P0
Frequency: Always/Sometimes/Once
Device: iPhone [model], iOS [version]

Reproduce:
1.
2.
3.

Expected:

Actual:

Logs:
```

Copy template for each bug found.

---

### High Priority Bugs (P1) - FIX BEFORE PUBLIC RELEASE

```
Bug #___: [Title]
Component:
Severity: P1
[Same template as above]
```

---

### Medium Priority Bugs (P2) - FIX IN PATCH UPDATE

```
Bug #___: [Title]
Component:
Severity: P2
[Same template as above]
```

---

### Low Priority Bugs (P3) - BACKLOG

```
Bug #___: [Title]
Component:
Severity: P3
[Same template as above]
```

---

## Test Summary Report

**Date**: _____________
**Build**: _____________
**Tester**: _____________

### Results
- Total Test Cases: 30
- Passed: ___
- Failed: ___
- Blocked: ___

### Critical Issues Found
- P0: ___ (blocking deployment)
- P1: ___ (fix before public release)
- P2: ___ (fix in patch)
- P3: ___ (backlog)

### Deployment Recommendation
- [ ] **PASS** - Ready for TestFlight
- [ ] **CONDITIONAL PASS** - Fix P0/P1 bugs first
- [ ] **FAIL** - Major issues, do not deploy

### Notes
```
[Add any general observations, patterns, or concerns]
```

---

## Appendix: Useful Commands

### View CloudKit Records
```bash
# Query recipes
# Use CloudKit Dashboard web interface

# Or use private API (requires entitlements):
# (Not recommended for testing)
```

### Export Test Logs
```bash
# Export filtered logs
xcrun devicectl device info logs --device DEVICE_UDID > heirloom_test_logs.txt

# Search for errors
grep "❌" heirloom_test_logs.txt
grep "ERROR" heirloom_test_logs.txt

# Search for sync events
grep -E "(📤|📥|🔄)" heirloom_test_logs.txt
```

### Reset App State
```bash
# Uninstall and reinstall
xcrun simctl uninstall booted com.matthanson.heirloom  # Simulator
# Or delete app from device manually

# Clear CloudKit Development data
# Use CloudKit Dashboard → Development → Reset Development Environment
```

---

**Testing Guide Version**: 1.0
**Last Updated**: 2025-12-29
