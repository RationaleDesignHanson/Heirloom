# Heirloom TestFlight Testing Guide
## Phase 2A: CloudKit Sharing - End-to-End Testing

**Build:** 1.1.1 (16) - Hybrid Architecture Implementation
**Test Date:** 2025-12-28
**Tester:** Matt Hanson
**Devices:** 2 physical iOS devices

**🚨 IMPORTANT:** This build implements the **Hybrid Architecture** fix for Bug #7 (No CloudKit Integration). Before testing sharing, we MUST verify CloudKit sync is working.

---

## Pre-Test Setup

### ✅ Checklist Before Starting:
- [ ] Both devices have TestFlight app installed
- [ ] Both devices logged into TestFlight with same Apple ID
- [ ] Heirloom build **1.1.1 (16)** installed from TestFlight on both devices
- [ ] Both devices signed into iCloud (Settings > Apple ID)
- [ ] Both devices have internet connection
- [ ] Open CloudKit Dashboard: https://icloud.developer.apple.com/dashboard
  - Select "Heirloom" app
  - Select **"Development"** environment (for TestFlight internal testing)
  - Keep this tab open for monitoring
- [ ] Have Mac connected to Device A via USB (for console log monitoring)

### Device Setup:
- **Device A (Sender):** iPhone with TestFlight build 1.1.1 (16)
- **Device B (Receiver):** iPhone with TestFlight build 1.1.1 (16)

### Console Log Monitoring Setup:
```bash
# On Mac, in Terminal:
# Find your device ID:
xcrun devicectl list devices

# Option 1: Watch Heirloom logs (RECOMMENDED):
log stream --predicate 'processImagePath CONTAINS "Heirloom"' --style compact | grep -E '(CloudKit|Sync|✅|❌|📤|📥|🔄)'

# Option 2: If device connected via USB, use devicectl:
xcrun devicectl device info logs stream --device [DEVICE_ID] | grep -E '(CloudKit|Sync|✅|❌|📤|📥|🔄)'

# Option 3: Simple process filter:
log stream --level debug --predicate 'process == "Heirloom"' | grep -E '(CloudKit|Sync|✅|❌|📤|📥|🔄)'
```

**Use Option 1 for easiest setup**

---

## 🔴 TEST CASE 0: CloudKit Sync Verification (CRITICAL - DO THIS FIRST)

**⚠️ This test MUST pass before attempting any sharing tests. This verifies Bug #7 fix.**

### Steps:

#### 0.1: Launch and Check Console Logs
1. **Connect Device A to Mac via USB**
   - [ ] Device connected and visible in Finder
   - [ ] Start console log streaming (see above)

2. **Launch Heirloom on Device A**
   - [ ] App launches successfully
   - [ ] Watch console logs for these messages:
     ```
     ✅ SwiftData initialized (Local storage, manual CloudKit sync)
     ✅ CloudKit sync initialized
     🔄 Starting automatic sync...
     ```
   - [ ] If you see these, sync service is starting correctly ✅

#### 0.2: Create Test Recipe
3. **Create a new recipe**
   - [ ] Tap "+" tab to create recipe
   - [ ] Enter title: "CloudKit Sync Test Recipe"
   - [ ] Add at least 2 ingredients:
     - "1 cup flour"
     - "2 eggs"
   - [ ] Add at least 1 instruction: "Mix ingredients"
   - [ ] Save recipe

4. **Watch for sync logs**
   - [ ] Console should show within 5-10 seconds:
     ```
     📤 Uploading 1 local changes
     📤 Uploading recipe: CloudKit Sync Test Recipe
     ✅ Uploaded: CloudKit Sync Test Recipe
     ✅ Sync complete
     ```
   - [ ] If you see these, recipe synced to CloudKit ✅

#### 0.3: Verify in CloudKit Dashboard
5. **Check CloudKit Dashboard**
   - [ ] Go to CloudKit Dashboard > Data tab
   - [ ] Select "Private Database"
   - [ ] Look for "Recipe" record type
   - [ ] Click "Query Records"
   - [ ] **CRITICAL:** Should see at least 1 Recipe record
   - [ ] Open the Recipe record
   - [ ] Verify fields:
     - `title`: "CloudKit Sync Test Recipe"
     - `modifiedAt`: Recent timestamp
     - `createdAt`: Recent timestamp
     - `lastSyncedAt`: Recent timestamp

#### 0.4: Test Automatic Foreground Sync
6. **Background and foreground test**
   - [ ] On Device A, press Home button (background app)
   - [ ] Wait 5 seconds
   - [ ] Re-open Heirloom
   - [ ] Console should show:
     ```
     🔄 Starting full sync...
     📥 Fetching remote changes...
     ✅ Sync complete
     ```

**✅ PASS CRITERIA:**
- ✅ Console logs show sync initialization
- ✅ Recipe uploads to CloudKit within 10 seconds of creation
- ✅ Recipe appears in CloudKit Dashboard
- ✅ All recipe fields populated correctly
- ✅ Foreground sync triggers automatically

**❌ FAIL CRITERIA (STOP TESTING - Bug #7 NOT FIXED):**
- ❌ No sync logs appear in console
- ❌ Recipe does NOT appear in CloudKit Dashboard
- ❌ Any "❌ CloudKit error" messages in console
- ❌ Sync times out or never completes

**If Test Case 0 FAILS, STOP HERE and report:**
```
BUG: CloudKit Sync Still Not Working (Bug #7 not fixed)
Build: 1.1.1 (16)
Console logs: [paste logs]
CloudKit Dashboard: [screenshot showing no records]
```

**If Test Case 0 PASSES, proceed to Test Case 1 (Share Creation) ✅**

---

## Test Case 1: Create and Share Recipe (Device A - Sender)

### Steps:
1. **Launch Heirloom on Device A**
   - [ ] App launches successfully
   - [ ] No crashes or errors on launch
   - [ ] Can see recipes tab

2. **Navigate to a recipe**
   - [ ] Tap on an existing recipe (or create a new one)
   - [ ] Recipe detail view opens correctly
   - [ ] Can see all recipe content (title, ingredients, instructions)

3. **Open share sheet**
   - [ ] Tap the Share button (top right)
   - [ ] RecipeShareSheet appears
   - [ ] Sheet shows proper UI with all options

4. **Fill out share options**
   - [ ] Enter personal message: "Testing CloudKit sharing!"
   - [ ] Enter sharer name: "Matt"
   - [ ] Set permission: Read-Only
   - [ ] Enable "Include Card Back": ON
   - [ ] Enable "Include Rating": ON
   - [ ] Enable "Allow Re-sharing": ON
   - [ ] Set expiration: 7 days

5. **Create share**
   - [ ] Tap "Create Share Link" button
   - [ ] Loading indicator appears
   - [ ] Success - iOS share sheet appears with CloudKit URL
   - [ ] Share URL looks like: `https://www.icloud.com/share/...`

6. **Send via Messages**
   - [ ] Select "Messages" from iOS share sheet
   - [ ] Choose recipient or your own number
   - [ ] Message sends successfully
   - [ ] URL preview appears in Messages

**✅ Success Criteria:**
- No crashes during share creation
- CloudKit share URL generated
- Message sent successfully

**❌ Bugs Found:**
```
[ ] Bug #1:
Description:
Steps to reproduce:
Expected:
Actual:

[ ] Bug #2:
Description:
Steps to reproduce:
Expected:
Actual:
```

---

## Test Case 2: Receive and Accept Share (Device B - Receiver)

### Steps:
1. **Receive message on Device B**
   - [ ] Open Messages app
   - [ ] See message with CloudKit share URL
   - [ ] URL preview loads correctly

2. **Tap share URL**
   - [ ] Tap on the CloudKit share URL
   - [ ] iOS prompts to open in Heirloom app
   - [ ] Tap "Open"

3. **Review share preview**
   - [ ] RecipeReceiveSheet appears
   - [ ] See sharer name: "Matt"
   - [ ] See personal message: "Testing CloudKit sharing!"
   - [ ] See recipe title
   - [ ] See recipe metadata (servings, prep time, cook time)
   - [ ] See ingredient count
   - [ ] See instruction/step count
   - [ ] See generation badge: "Generation 1"
   - [ ] Attribution card looks correct

4. **Accept the share**
   - [ ] Tap "Add to My Recipes" button
   - [ ] Loading indicator appears
   - [ ] Success toast: "Recipe Added - '[Recipe Title]' added to your collection"
   - [ ] Sheet dismisses
   - [ ] Haptic feedback occurs

5. **Verify recipe imported**
   - [ ] Navigate to Recipes tab
   - [ ] See newly imported recipe in list
   - [ ] Recipe has same title as shared recipe
   - [ ] Tap on recipe to open detail view

6. **Verify recipe content**
   - [ ] Title matches original
   - [ ] All ingredients present
   - [ ] All instructions present
   - [ ] Servings/times match
   - [ ] Photos/images present (if applicable)

7. **Verify provenance metadata**
   - [ ] Look for attribution/provenance badge
   - [ ] Should show: "Shared by Matt"
   - [ ] Should show personal message somewhere
   - [ ] Generation count visible

**✅ Success Criteria:**
- Share preview displays correctly
- Recipe imports successfully
- All content preserved
- Provenance metadata attached

**❌ Bugs Found:**
```
[ ] Bug #3:
Description:
Steps to reproduce:
Expected:
Actual:

[ ] Bug #4:
Description:
Steps to reproduce:
Expected:
Actual:
```

---

## Test Case 3: CloudKit Dashboard Verification (Hybrid Architecture)

### Steps:
1. **Open CloudKit Dashboard**
   - [ ] Go to: https://icloud.developer.apple.com/dashboard
   - [ ] Select "Heirloom" app
   - [ ] Select "Development" environment

2. **Check Recipe records (Manual Sync)**
   - [ ] Navigate to "Data" tab
   - [ ] Select "Private Database"
   - [ ] Look for `Recipe` record type
   - [ ] Should see ALL recipes from Device A synced here
   - [ ] Open a Recipe record
   - [ ] Verify sync metadata fields:
     - `title`: Recipe title
     - `instructions`: JSON array of instruction strings
     - `ingredientIDs`: Array of ingredient UUIDs
     - `modifiedAt`: Recent timestamp
     - `createdAt`: Timestamp
     - `lastSyncedAt`: Recent timestamp (within last 5 min)
     - `provenanceJSON`: JSON string (if provenance exists)

3. **Check CKShare records**
   - [ ] Look for `cloudkit.share` record type (or CKShare)
   - [ ] Should see at least 1 CKShare record created
   - [ ] Note: CKShare only appears AFTER Test Case 1 completes

4. **Verify CKShare fields**
   - [ ] Open the CKShare record
   - [ ] Verify fields present:
     - `title`: Recipe title
     - `personalMessage`: "Testing CloudKit sharing!"
     - `sharerName`: "Matt"
     - `generation`: 0 (original)
     - `includeCardBack`: 1
     - `includeRating`: 1
     - `allowReSharing`: 1
     - `expiresAt`: Date 7 days from now

5. **Verify CKShare → Recipe link**
   - [ ] CKShare should reference a Recipe record
   - [ ] Recipe recordID should match one from step 2
   - [ ] Recipe record was synced BEFORE CKShare creation (hybrid architecture)

6. **Verify participants**
   - [ ] CKShare should list participants
   - [ ] Owner (Device A user) visible
   - [ ] Participant (Device B user) visible after acceptance

**✅ Success Criteria:**
- Recipe records exist and are syncing (Bug #7 fix verified)
- CKShare record exists
- All custom fields populated correctly
- Recipe synced before CKShare created
- Participants list correct

**❌ CloudKit Issues:**
```
[ ] Issue #1:
Description:
What's missing/wrong in CloudKit:

[ ] Issue #2:
Description:
What's missing/wrong in CloudKit:
```

---

## Test Case 4: Decline Share (Optional)

### Steps:
1. **Send another share from Device A**
   - [ ] Create another share link
   - [ ] Send to Device B

2. **Decline on Device B**
   - [ ] Open share link
   - [ ] RecipeReceiveSheet appears
   - [ ] Tap "Decline" button
   - [ ] Sheet dismisses
   - [ ] No recipe added to collection

**✅ Success Criteria:**
- Decline works without crashes
- No recipe imported
- Sheet closes cleanly

---

## Test Case 5: Error Handling

### 5A: Offline Share Creation (Device A)
- [ ] Turn on Airplane Mode
- [ ] Try to create a share
- [ ] Should see error: "No internet connection" or similar
- [ ] Error message is clear and helpful

### 5B: Offline Share Acceptance (Device B)
- [ ] Receive share URL
- [ ] Turn on Airplane Mode
- [ ] Try to accept share
- [ ] Should see error about connectivity
- [ ] Can retry after connection restored

### 5C: Invalid/Expired Share
- [ ] Create a share with 1-minute expiration
- [ ] Wait 2 minutes
- [ ] Try to accept expired share
- [ ] Should see "Share expired" error

**❌ Error Handling Issues:**
```
[ ] Issue #1:
Description:
Error scenario:
Expected error:
Actual result:
```

---

## Test Case 6: Re-sharing (Generation Tracking)

### Steps:
1. **Device B: Re-share received recipe**
   - [ ] Open the imported recipe on Device B
   - [ ] Tap Share button
   - [ ] Fill out share form
   - [ ] Note: Generation should be 2 (or incremented)
   - [ ] Create share link
   - [ ] Send to a third device or back to Device A

2. **Verify generation increment**
   - [ ] Accept on receiving device
   - [ ] Check generation badge
   - [ ] Should show "Generation 2" (or higher)
   - [ ] Provenance lineage preserved

**✅ Success Criteria:**
- Re-sharing works
- Generation increments correctly
- Lineage tracked properly

---

## Performance & Polish

### General App Performance:
- [ ] App feels responsive
- [ ] No noticeable lag when opening sheets
- [ ] Animations smooth
- [ ] No UI glitches or visual bugs

### Share Creation Performance:
- [ ] Share creation completes in < 5 seconds
- [ ] Loading indicators appear immediately
- [ ] No frozen UI during creation

### Share Acceptance Performance:
- [ ] Share preview loads quickly (< 3 seconds)
- [ ] Recipe import completes in < 5 seconds
- [ ] Smooth transition back to recipe list

**⚠️ Performance Issues:**
```
[ ] Issue #1:
Action:
Time taken:
Expected:
Notes:
```

---

## UI/UX Feedback

### RecipeShareSheet:
- [ ] Layout looks good
- [ ] All fields easy to understand
- [ ] Labels clear
- [ ] Typography readable
- [ ] Colors on-brand

### RecipeReceiveSheet:
- [ ] Preview information clear
- [ ] Attribution prominent
- [ ] Personal message visible
- [ ] Buttons easy to tap (44pt minimum)
- [ ] Generation badge understandable

**💡 UX Improvements:**
```
[ ] Suggestion #1:
Screen:
Current behavior:
Suggested improvement:

[ ] Suggestion #2:
Screen:
Current behavior:
Suggested improvement:
```

---

## Critical Bugs (Stop Testing)

**🚨 If you encounter any of these, stop testing and report immediately:**
- [ ] App crashes on launch
- [ ] Data loss (recipes disappear)
- [ ] Unable to create shares at all
- [ ] Unable to accept shares at all
- [ ] CloudKit errors preventing core functionality

---

## Post-Test Summary

### Test Results:
- **Total Test Cases:** 7 (including critical Test Case 0)
- **Passed:** ___
- **Failed:** ___
- **Blocked:** ___

### Critical Test Case 0 Result:
- [ ] ✅ PASSED - CloudKit sync working (Bug #7 FIXED)
- [ ] ❌ FAILED - CloudKit sync NOT working (Bug #7 NOT FIXED - STOP TESTING)

### Bug Summary:
- **Critical (P0):** ___ (App crashes, data loss, core features broken)
- **High (P1):** ___ (Major features not working as expected)
- **Medium (P2):** ___ (Minor bugs, edge cases)
- **Low (P3):** ___ (Polish, UX improvements)

### Overall Assessment:
```
[ ] ✅ Ready for production - No critical bugs, minor issues acceptable
[ ] ⚠️ Needs fixes - Some bugs need addressing before release
[ ] ❌ Blocked - Critical issues prevent release
```

### Next Steps:
```
1.
2.
3.
```

---

## Bug Report Template

When you find a bug, copy this template and fill it out:

```markdown
## Bug #X: [Short Title]

**Severity:** [ ] P0-Critical  [ ] P1-High  [ ] P2-Medium  [ ] P3-Low

**Environment:**
- Device: [e.g., iPhone 15 Pro]
- iOS Version: [e.g., 18.2]
- Build: [TestFlight build number]

**Steps to Reproduce:**
1.
2.
3.

**Expected Result:**


**Actual Result:**


**Screenshots/Video:**
[Attach if available]

**Console Logs:**
[Copy any relevant error logs if visible]

**Frequency:**
[ ] Always  [ ] Sometimes  [ ] Once

**Workaround:**
[If you found a way around it]

**Notes:**

```

---

## Useful Commands for Debugging

If you need to inspect logs or state:

```bash
# View device logs (connect device via USB)
xcrun devicectl device info logs --device <DEVICE_ID> --stream

# View CloudKit container info
# (Run in separate Claude Code terminal window)
```

---

## Contact

If you encounter issues during testing:
- Open a **new terminal window**
- Run `claude` in the Heirloom project directory
- Paste bug reports from above
- I'll help diagnose and create fix tasks

**Happy Testing! 🧪**
