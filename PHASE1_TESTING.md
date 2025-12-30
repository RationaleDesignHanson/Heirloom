# Phase 1 Testing Guide - Build 1.1.3 (19)

**Goal:** Verify app works locally WITHOUT CloudKit and that Logger output is visible on device

---

## Setup (One-time)

### On Mac:
1. Connect iPhone "Moviefone" via USB
2. Open **Console.app** (Applications > Utilities > Console.app)
3. In left sidebar, select your device "Moviefone"
4. In search bar at top, enter: `subsystem:com.matthanson.heirloom`
5. Click **Start** button to begin streaming logs

### On iPhone:
1. Open TestFlight
2. Find **Heirloom** app
3. Install build **1.1.3 (19)**
4. Wait for "Ready to Test"

---

## Test Sequence

### Test 1: App Launch & Initialization

**Steps:**
1. With Console.app streaming, launch Heirloom on iPhone
2. **Watch Console.app** for log messages

**Expected Logs (in order):**
```
🚀 [Heirloom] HeirloomApp.init() called - starting initialization
🔧 [Heirloom] Configuring SwiftData schema...
✅ [Heirloom] SwiftData initialized (Local storage, manual CloudKit sync)
⏸️  [Heirloom] CloudKit sync DISABLED for Phase 1 testing
```

**✅ PASS if:**
- All 4 log messages appear in Console.app
- App launches without crashing
- UI loads normally (tab bar visible)

**❌ FAIL if:**
- No logs appear in Console.app
- App crashes on launch
- Different error messages appear

---

### Test 2: Recipe Creation

**Steps:**
1. Tap **Add** tab (+ button)
2. Create a test recipe:
   - Title: "Phase 1 Test Recipe"
   - Add 2-3 ingredients
   - Add 2-3 instructions
3. Tap **Save**

**Expected:**
- Recipe saves successfully
- Appears in Recipes list
- No error messages in Console.app

**✅ PASS if:**
- Recipe appears in list
- Can open and view recipe
- No crashes or errors

**❌ FAIL if:**
- Save fails
- App crashes
- Error logs appear

---

### Test 3: Recipe Editing

**Steps:**
1. Open the test recipe created above
2. Edit the title to "Phase 1 Test Recipe - Edited"
3. Save changes

**Expected:**
- Changes save successfully
- Updated title visible in list

**✅ PASS if:**
- Edits persist
- No errors

**❌ FAIL if:**
- Edits don't save
- App crashes

---

### Test 4: Recipe Deletion

**Steps:**
1. Swipe left on test recipe
2. Tap **Delete**
3. Confirm deletion

**Expected:**
- Recipe deleted from list
- No errors

**✅ PASS if:**
- Recipe removed
- No crashes

**❌ FAIL if:**
- Delete fails
- App crashes

---

## Success Criteria for Phase 1

**ALL of these must pass:**
- ✅ Logger messages visible in Console.app
- ✅ App initializes successfully (all 4 init logs appear)
- ✅ Can create recipes locally
- ✅ Can edit recipes
- ✅ Can delete recipes
- ✅ No crashes
- ✅ No unexpected errors in logs

---

## If Phase 1 Passes

**Next:** Proceed to Phase 2
- Uncomment CloudKit sync code
- Add comprehensive CloudKit logging
- Test sync to CloudKit

---

## If Phase 1 Fails

### No Logs Visible:
- Check Console.app filter: `subsystem:com.matthanson.heirloom`
- Verify device connected via USB
- Try restarting Console.app

### App Crashes:
- Capture crash log from Console.app
- Save to `/Users/matthanson/Desktop/errrrrr.txt`
- Report crash details

### Features Don't Work:
- Note specific feature that fails
- Copy error logs from Console.app
- Report issue with logs

---

## Reporting Results

**After testing, report:**
1. ✅ or ❌ for each test
2. Screenshot of Console.app showing logs
3. Any unexpected behavior
4. Ready to proceed to Phase 2? (Yes/No)

---

**Build:** 1.1.3 (19)
**Phase:** 1 of 3 (Local-only testing)
**Date:** 2025-12-28
**Status:** Ready for device testing
