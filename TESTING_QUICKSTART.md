# TestFlight Quick Start Guide

## 🚀 Fast Track Testing (15 minutes)

**Build:** 1.1.1 (16) - Hybrid Architecture
**🚨 MUST test CloudKit sync FIRST before testing sharing**

### Pre-Flight:
- [ ] 2 iPhones with TestFlight
- [ ] Both logged into iCloud
- [ ] Heirloom **build 1.1.1 (16)** installed from TestFlight
- [ ] CloudKit Dashboard open: https://icloud.developer.apple.com/dashboard
- [ ] Mac connected to Device A via USB (for console logs)

---

## 🔴 STEP 0: CloudKit Sync Test (DO THIS FIRST!)

**⚠️ This verifies Bug #7 fix. If this fails, STOP and report.**

### Device A:
```
1. In Terminal on Mac, start log monitoring:
   log stream --predicate 'processImagePath CONTAINS "Heirloom"' --style compact | grep -E '(CloudKit|Sync|✅|❌|📤|📥|🔄)'

2. Launch Heirloom on device

3. Watch for logs:
   ✅ SwiftData initialized (Local storage, manual CloudKit sync)
   ✅ CloudKit sync initialized
   🔄 Starting automatic sync...

4. Create test recipe: "Sync Test Recipe"

5. Watch for logs:
   📤 Uploading recipe: Sync Test Recipe
   ✅ Uploaded: Sync Test Recipe

6. Check CloudKit Dashboard > Data > Private Database > Recipe records

7. VERIFY: Recipe appears in CloudKit within 10 seconds
```

**✅ If sync works → Proceed to sharing tests**
**❌ If no recipes in CloudKit → STOP, Bug #7 NOT FIXED**

---

## Test Flow (After Step 0 Passes):

### Device A (Sender):
```
1. Open recipe (that synced successfully)
2. Tap Share button
3. Fill: message="Test", name="Matt"
4. Tap "Create Share Link"
5. Send via Messages to Device B
```

### Device B (Receiver):
```
1. Open message
2. Tap CloudKit URL
3. Review preview
4. Tap "Add to My Recipes"
5. Verify recipe appears in list
6. Open recipe, check content
```

### CloudKit Dashboard:
```
1. Go to Data > Private Database
2. Find Recipe records (should already exist from Step 0)
3. Find cloudkit.share record
4. Verify participants listed
5. Verify Recipe record synced BEFORE CKShare created
```

---

## ✅ Success = All These Work:
- ✅ **Step 0:** Recipes sync to CloudKit automatically (Bug #7 fixed)
- ✅ Recipe records appear in CloudKit Dashboard
- ✅ Share creates without error
- ✅ URL sends via Messages
- ✅ Preview shows on Device B
- ✅ Recipe imports correctly
- ✅ All content preserved
- ✅ Provenance shows "Shared by Matt"

---

## 🚨 Report IMMEDIATELY If:
- ❌ **Step 0 fails:** No recipes in CloudKit (Bug #7 NOT fixed)
- ❌ App crashes
- ❌ Share creation fails
- ❌ Recipe missing content
- ❌ Can't accept share
- ❌ Sync takes > 10 seconds

---

## 📝 Log Bugs To:
`/Users/matthanson/Heirloom/TESTFLIGHT_BUGS.md`

**Quick Bug Format:**
```
Bug #1: [Title]
Reproduce: 1) 2) 3)
Expected:
Actual:
```

---

## Full Guide:
See: `TESTFLIGHT_TESTING_GUIDE.md` for detailed test cases

---

## 📋 What's New in Build 1.1.1 (16):

**Hybrid Architecture Implementation (Bug #7 Fix):**
- Disabled SwiftData automatic CloudKit sync
- Implemented manual CloudKit sync service
- Automatic sync triggers:
  - On app launch
  - When app enters foreground
  - Every 5 minutes
  - Before sharing
- Full sync metadata tracking on Recipe model
- Comprehensive error handling and logging

**See:** `CLOUDKIT_HYBRID_ARCHITECTURE.md` for technical details

---

## Need Help?
Open new terminal → Run `claude` → Paste bug details
