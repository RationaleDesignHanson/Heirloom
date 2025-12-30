# Phase 2 Testing Guide - Build 1.1.3 (21)

**Goal:** Enable CloudKit sync with comprehensive file-based logging to diagnose sync issues

**Status:** CloudKit ENABLED with full DeviceLogger logging

---

## What Changed in Phase 2

### CloudKit Re-Enabled:
- Uncommented CloudKitSyncService initialization
- Added error handling with try/catch
- Enabled automatic sync on startup

### Comprehensive Logging Added:
Every CloudKit operation now logs to file:
- ✅ CloudKit initialization (success/failure)
- ✅ Automatic sync startup
- ✅ Initial sync on app launch
- ✅ Periodic sync (every 5 minutes)
- ✅ Foreground sync (when app opens)
- ✅ Recipe upload attempts (with recordID)
- ✅ Upload success/failure (with error codes)
- ✅ Full sync operations
- ✅ Remote change fetching
- ✅ Conflict resolution

---

## Testing Build 1.1.3 (21)

### Step 1: Install and Launch

**On iPhone:**
1. Install build **1.1.3 (21)** from TestFlight
2. Launch Heirloom
3. Go to **Settings → Developer Testing → View Debug Log**

### Step 2: Verify CloudKit Initialization

**Expected logs (in order):**
```
🚀 [Heirloom] HeirloomApp.init() called - starting initialization
🔧 [Heirloom] Configuring SwiftData schema...
✅ [Heirloom] SwiftData initialized (Local storage, manual CloudKit sync)
🔄 [Heirloom] Configuring CloudKit sync...
✅ [Heirloom] CloudKit sync initialized successfully
🔄 [Heirloom] Starting automatic sync...
✅ [Heirloom] Automatic sync enabled
🔄 [Heirloom] Performing initial sync on startup...
🔄 [Heirloom] Starting full sync...
```

**✅ PASS if:** All logs appear in sequence
**❌ FAIL if:** See error message: `❌ CloudKit sync initialization failed: <error>`

### Step 3: Test Recipe Creation & Sync

**Create a test recipe:**
1. Tap **Add** tab (+)
2. Create recipe: "CloudKit Sync Test"
3. Add 2-3 ingredients
4. Add 2-3 instructions
5. Save recipe
6. **Immediately** go to Settings → Debug Log → **Refresh**

**Expected logs:**
```
📤 [Heirloom] Uploading 1 local changes
📤 [Heirloom] Uploading recipe: CloudKit Sync Test
✅ [Heirloom] Uploaded: CloudKit Sync Test (recordID: XXXXXXXX-XXXX-...)
✅ [Heirloom] Sync complete
```

**✅ PASS if:** Recipe uploaded successfully with recordID
**❌ FAIL if:** See upload error

### Step 4: Verify in CloudKit Dashboard

**Check CloudKit:**
1. Go to: https://icloud.developer.apple.com/dashboard
2. Select: Heirloom → Development Environment
3. Navigate to: Data → Private Database
4. Look for: Recipe records

**✅ PASS if:** Recipe appears in CloudKit with matching title
**❌ FAIL if:** 0 records in CloudKit

---

## Expected Log Patterns

### Successful Sync:
```
🔄 [Heirloom] Starting full sync...
📤 [Heirloom] Uploading 1 local changes
📤 [Heirloom] Uploading recipe: <name>
✅ [Heirloom] Uploaded: <name> (recordID: XXXXX)
ℹ️ [Heirloom] No remote changes to download
✅ [Heirloom] Sync complete
```

### No Changes to Sync:
```
🔄 [Heirloom] Starting full sync...
ℹ️ [Heirloom] No local changes to upload
📥 [Heirloom] Fetching remote changes since: <date>
ℹ️ [Heirloom] No remote changes to download
✅ [Heirloom] Sync complete
```

### CloudKit Errors (if they occur):
```
❌ [Heirloom] Upload failed: <recipe> - Error: <description> (code: <number>)
❌ [Heirloom] Sync failed: <error description>
```

---

## Common CloudKit Error Codes

| Code | Meaning | Next Steps |
|------|---------|------------|
| 1 | Internal Error | Check CloudKit schema |
| 2 | Partial Failure | Some records failed, check batch |
| 3 | Network Unavailable | Normal - will retry |
| 4 | Network Failure | Normal - will retry |
| 6 | Service Unavailable | CloudKit down, wait |
| 9 | Not Authenticated | Sign into iCloud in Settings |
| 11 | Record Not Found | Normal for first upload |
| 14 | Bad Container | Check container ID |
| 26 | Zone Not Found | Run Phase 3 schema fix |

**Most Common Issue:** Code 26 (Zone Not Found) or Code 1 with "recordName not queryable"

---

## Diagnostic Scenarios

### Scenario A: CloudKit Initialization Fails

**Log shows:**
```
❌ [Heirloom] CloudKit sync initialization failed: <error>
```

**Diagnosis:**
- CloudKitSyncService.configure() or startAutomaticSync() threw error
- Check error message for specifics
- May need to fix schema (Phase 3)

### Scenario B: Upload Fails

**Log shows:**
```
📤 [Heirloom] Uploading recipe: Test
❌ [Heirloom] Upload failed: Test - Error: <description> (code: X)
```

**Diagnosis:**
- CloudKit record save failed
- Check error code in table above
- If code 26 or "recordName not queryable" → Phase 3 fix needed

### Scenario C: No Sync Attempts

**Log shows initialization but never "Starting full sync":**

**Diagnosis:**
- Automatic sync not triggering
- Check if sync service properly initialized
- May be caught in error path

### Scenario D: Sync Completes But No CloudKit Records

**Log shows:**
```
✅ [Heirloom] Uploaded: Test (recordID: XXXXX)
✅ [Heirloom] Sync complete
```

**But CloudKit Dashboard shows 0 records:**

**Diagnosis:**
- Upload appeared successful but CloudKit rejected silently
- Check Development vs Production environment
- Verify container configuration

---

## Success Criteria for Phase 2

**Phase 2 PASSES if:**
- ✅ CloudKit initializes without errors
- ✅ Automatic sync starts
- ✅ Recipe creation triggers upload
- ✅ Upload succeeds with recordID
- ✅ Recipe appears in CloudKit Dashboard
- ✅ All operations logged to debug log

**Phase 2 FAILS if:**
- ❌ CloudKit initialization error
- ❌ Upload fails with error
- ❌ No records in CloudKit Dashboard
- ❌ Specific error code requires Phase 3 fix

---

## If Phase 2 Fails

### Capture Full Diagnostic Log:

1. Open Settings → Developer Testing → View Debug Log
2. Tap **Share** button
3. AirDrop to Mac or save to Files
4. Save as: `/Users/matthanson/Desktop/phase2_log.txt`
5. Report:
   - Specific error messages
   - Error codes
   - Where sync failed (init, upload, fetch)

### Expected Issues:

**Most likely failure:** CloudKit schema not configured properly
- Error: "recordName is not marked queryable"
- Solution: Phase 3 schema fix

**Second likely failure:** Zone not found
- Error code 26
- Solution: Phase 3 schema setup

---

## Phase 3 Preview

If Phase 2 shows schema errors, Phase 3 will:
1. Fix CloudKit schema (add recordName as queryable)
2. Configure custom zones if needed
3. Test end-to-end sync after schema fix

---

## Testing Timeline

**Phase 2 Testing (~15 minutes):**
- Install build (2 min)
- Check initialization logs (1 min)
- Create test recipe (2 min)
- Verify upload logs (2 min)
- Check CloudKit Dashboard (3 min)
- Export debug log (2 min)
- Report results (3 min)

**After Testing:**
- If successful → Phase 3 (schema polish + testing)
- If errors → Fix issues based on logs, rebuild

---

**Build:** 1.1.3 (21)
**Phase:** 2 of 3 (CloudKit enabled with logging)
**Date:** 2025-12-28
**Status:** Ready for archive and TestFlight upload
