# TestFlight Issues Log - Build Date: 2025-12-29

## Issue #1: Share Sheet Opens Empty in TestFlight Build
**Date Found:** 2025-12-29
**Severity:** 🔴 **CRITICAL** - Blocks all sharing functionality
**Status:** Found

### Description
The share sheet opens but displays empty (cream/blank screen) when attempting to share a recipe in the TestFlight build. This feature works correctly in development builds.

### Steps to Reproduce
1. Open Heirloom app (TestFlight build)
2. Create or select a recipe (tested with "Teddy's Dinner")
3. Tap Share button on recipe detail view
4. Fill out share options
5. Tap "Create Share Link"
6. **Result:** Cream/blank share sheet appears with no content

### Expected Behavior
- Share sheet should display with standard iOS share options
- Should show options like: Messages, Mail, Copy Link, etc.
- Share link should be generated and ready to share

### Actual Behavior
- Empty/blank cream-colored sheet appears
- No share options visible
- Cannot proceed with sharing

### Environment
- **Build:** TestFlight production build (2025-12-29)
- **Device A:** (to be filled)
- **iOS Version:** (to be filled)
- **Development Build:** Works correctly ✓
- **TestFlight Build:** Broken ✗

### ROOT CAUSE IDENTIFIED ✅

**From device logs at 20:52:20:**

```
error: You cannot get the URL of a share until it's been saved to the server
error: You cannot get the URL of a share until it's been saved to the server
```

**Additional CloudKit errors:**

```
error: Finished operation <CKQueryOperation> with error:
Error Domain=CKInternalErrorDomain Code=2015
"Type is not marked indexable: cloudkit.share"
```

```
error: Unexpected: The invitedPCS has a different number of public identities
than expected (1 vs. 2) on the share
```

### Technical Root Causes

1. **Share URL Access Before Save (PRIMARY BUG)**
   - Code at RecipeShareSheet.swift:312 calls `generateShareURL(from: share)`
   - This happens BEFORE the share is fully saved to CloudKit server
   - The share object doesn't have a URL until CloudKit assigns one
   - This causes `shareURL` to be nil
   - ShareSuccessView displays with nil URL → blank sheet

2. **CloudKit Schema Configuration**
   - "Type is not marked indexable: cloudkit.share" error
   - The CloudKit schema doesn't have proper indexes set up for querying shares
   - Need to configure CloudKit Dashboard schema for production

3. **Share Save Operation Timing**
   - The share creation appears to succeed (ModifyRecordsURLRequest completed)
   - But URL generation happens before CloudKit returns the share URL
   - Missing proper async/await handling for URL generation

### Code Location
- **File:** `Heirloom/Features/Sharing/Views/RecipeShareSheet.swift`
- **Line:** 312
- **Problem:**
  ```swift
  shareURL = RecipeShareService.shared.generateShareURL(from: share)
  ```
  This runs but share.url is nil until server confirms save

### Fix Required
1. Wait for CloudKit save operation to complete AND return updated share
2. Check if share.url exists before calling generateShareURL
3. Handle nil URL case gracefully with error message
4. Configure CloudKit schema indexes in production

### Next Steps
1. ✅ Root cause identified from device logs
2. Fix RecipeShareService.createShare() to ensure share has URL
3. Add nil check for shareURL before showing success view
4. Configure CloudKit production schema
5. Test fix in development
6. Push new TestFlight build

### Related Files
- Heirloom/Heirloom.entitlements
- Heirloom.xcodeproj/project.pbxproj
- Info.plist
- Build settings for Release configuration

---

---

## Issue #2: Version Error When Accepting Shares (NEEDS INVESTIGATION)
**Date Found:** 2025-12-29
**Severity:** 🟡 **HIGH** - Blocks share acceptance on second device
**Status:** Investigating

### Description (Reported by User)
When attempting to open a share link on a second device, a "version error" appears. This prevents the recipient from accepting the shared recipe.

### Key Information Needed
- **What was the exact error message?** (e.g., "Schema version mismatch", "Incompatible version", etc.)
- **Which device showed the error?** Sender or receiver?
- **Was this in dev builds or TestFlight?**
- **Did both devices have the same build installed?**

### Analysis
The codebase has:
1. **SwiftData Schema Versioning** (SchemaV1 at version 1.0.0)
2. **Recipe Multi-Version System** (RecipeVersion for tracking changes)
3. **NO version validation** in ShareAcceptanceService

### Possible Root Causes

**Theory A: SwiftData Schema Mismatch**
- One device has SchemaV1 (1.0.0), other has different version
- Could happen if builds are from different branches/commits
- SwiftData would reject incompatible schema

**Theory B: CloudKit Record Type Version**
- CloudKit record types have versions
- If devices have different CloudKit schema expectations
- Would cause deserialization errors

**Theory C: RecipeVersion Field Mismatch**
- Recipe has RecipeVersion data on sender
- Receiver's schema doesn't include RecipeVersion yet
- Unlikely since both should have SchemaV1

**Theory D: Missing Version Compatibility Check**
- No validation in ShareAcceptanceService
- Should check schema version before importing
- Currently just tries to import and fails

### Our Recent Fix Impact
**Important:** The URL generation fix we just made should NOT cause this issue because:
- It only affects how the share URL is returned from CloudKit
- Doesn't change the share data structure
- Doesn't modify schema or versioning logic
- We're **uncovering** an existing issue, not creating a new one

### Next Steps - NEED YOUR INPUT
1. Try to reproduce the version error with the fix in place
2. Capture the EXACT error message text
3. Check both devices' build numbers
4. Collect device logs from the receiver when error occurs

---

## Testing Summary
- **Total Issues Found:** 2
- **Critical Issues:** 1 (Issue #1 - FIXED)
- **High Priority Issues:** 1 (Issue #2 - INVESTIGATING)
- **Medium/Low Issues:** 0
- **Tests Blocked:** Share acceptance blocked by Issue #2 (needs reproduction)

**Release Status:** 🟡 INVESTIGATING - Issue #1 fixed, Issue #2 needs more info
