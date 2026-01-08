# TestFlight Manual Testing Checklist
## Date: 2025-12-29

## Pre-Flight Checklist
- [ ] Xcode project opens without errors
- [ ] SwiftSoup package dependency resolved
- [ ] Build succeeds (Cmd+B)
- [ ] Archive created successfully
- [ ] Uploaded to TestFlight

---

## Recipe Sharing Testing

### Test 1: Share Recipe via CloudKit (Basic Share)
**Prerequisites:**
- Device A: Your primary test device (logged into iCloud)
- Device B: Secondary test device or simulator (different iCloud account)

**Steps:**
1. **On Device A:**
   - [ ] Open Heirloom app
   - [ ] Navigate to a recipe (note recipe name: _________________)
   - [ ] Tap share button
   - [ ] Select "Share via CloudKit" or similar option
   - [ ] Choose recipient method (Messages, Email, Copy Link)
   - [ ] **Log:** Note the share URL format: _________________
   - [ ] Send to Device B

2. **On Device B:**
   - [ ] Receive the share link
   - [ ] Tap the link
   - [ ] **Expected:** Heirloom app opens
   - [ ] **Expected:** Recipe import/accept sheet appears
   - [ ] Tap "Accept" or "Import Recipe"
   - [ ] **Expected:** Recipe appears in Device B's library
   - [ ] **Log:** Check if all recipe data imported correctly:
     - [ ] Recipe name
     - [ ] Ingredients list
     - [ ] Instructions
     - [ ] Images
     - [ ] Tags/collections

3. **Verify Recipe Sync:**
   - [ ] **On Device A:** Edit the shared recipe (change title or add ingredient)
   - [ ] **On Device B:** Pull to refresh or wait for sync
   - [ ] **Expected:** Changes appear on Device B
   - [ ] **Log:** Sync time: ________ seconds

**Issue Log:**
```
Issue #:
Severity: [Critical/High/Medium/Low]
Description:
Steps to reproduce:
Expected behavior:
Actual behavior:
Screenshots/Logs:
```

---

### Test 2: Share Multiple Recipes
**Steps:**
1. **On Device A:**
   - [ ] Select multiple recipes (3-5 recipes)
   - [ ] Tap share button
   - [ ] Share to Device B

2. **On Device B:**
   - [ ] Accept the share
   - [ ] **Expected:** All recipes import successfully
   - [ ] Verify each recipe's data integrity

**Issue Log:**
```
Issue #:
Severity:
Description:
```

---

### Test 3: Share Recipe Collection (Heirloom Sharing)
**Prerequisites:** Create a collection with 3+ recipes

**Steps:**
1. **On Device A:**
   - [ ] Go to Collections view
   - [ ] Select a collection (name: _________________)
   - [ ] Tap share button on collection
   - [ ] Share to Device B

2. **On Device B:**
   - [ ] Receive and tap share link
   - [ ] **Expected:** Collection import sheet appears
   - [ ] **Expected:** Shows collection name and recipe count
   - [ ] Accept the collection share
   - [ ] **Expected:** New collection created with all recipes
   - [ ] Verify all recipes imported correctly

**Issue Log:**
```
Issue #:
Severity:
Description:
```

---

### Test 4: Permissions & Access Control
**Steps:**
1. **Test Read-Only Access:**
   - [ ] Share a recipe with "View Only" permission
   - [ ] **On Device B:** Verify cannot edit the recipe
   - [ ] **Expected:** Edit button disabled or shows permission error

2. **Test Edit Access:**
   - [ ] Share a recipe with "Can Edit" permission
   - [ ] **On Device B:** Make edits to the recipe
   - [ ] **On Device A:** Verify changes sync back
   - [ ] **Expected:** Changes appear on both devices

**Issue Log:**
```
Issue #:
Severity:
Description:
```

---

### Test 5: Share Link Edge Cases
**Steps:**
1. **Test Expired/Invalid Links:**
   - [ ] Try opening an old share link (if available)
   - [ ] **Expected:** Error message: "Link expired" or "Recipe not found"

2. **Test Without iCloud:**
   - [ ] Sign out of iCloud on Device B
   - [ ] Try to accept a share
   - [ ] **Expected:** Error prompting to sign in to iCloud

3. **Test Offline Mode:**
   - [ ] Turn off WiFi and cellular on Device B
   - [ ] Try to accept a share
   - [ ] **Expected:** Shows offline error or queues for later
   - [ ] Turn network back on
   - [ ] **Expected:** Automatically retries and imports

**Issue Log:**
```
Issue #:
Severity:
Description:
```

---

### Test 6: Deep Link Handling
**Steps:**
1. **Test Deep Link from Messages:**
   - [ ] Share recipe via Messages
   - [ ] Tap link from Messages app
   - [ ] **Expected:** Heirloom opens to share acceptance sheet

2. **Test Deep Link from Email:**
   - [ ] Share recipe via Email
   - [ ] Tap link from Mail app
   - [ ] **Expected:** Heirloom opens to share acceptance sheet

3. **Test Deep Link from Safari:**
   - [ ] Copy share link
   - [ ] Paste into Safari and navigate
   - [ ] **Expected:** Redirects to Heirloom app

**Issue Log:**
```
Issue #:
Severity:
Description:
```

---

### Test 7: Share Sheet UI/UX
**Steps:**
1. **Test Share Sheet Presentation:**
   - [ ] Open share sheet
   - [ ] **Verify:** All share options visible (Messages, Email, Copy Link, etc.)
   - [ ] **Verify:** Preview card shows recipe image and name
   - [ ] **Verify:** Permission options displayed clearly

2. **Test Share Sheet Cancellation:**
   - [ ] Open share sheet
   - [ ] Tap Cancel or swipe down
   - [ ] **Expected:** Returns to recipe without sharing

**Issue Log:**
```
Issue #:
Severity:
Description:
```

---

### Test 8: Performance & Reliability
**Steps:**
1. **Test Large Recipe Sharing:**
   - [ ] Share a recipe with many ingredients (20+)
   - [ ] Share a recipe with multiple high-res images
   - [ ] **Log:** Share creation time: ________ seconds
   - [ ] **Log:** Import time on Device B: ________ seconds

2. **Test Rapid Sharing:**
   - [ ] Share 5 recipes in quick succession
   - [ ] **Expected:** All shares process successfully
   - [ ] **Expected:** No crashes or UI freezes

**Issue Log:**
```
Issue #:
Severity:
Description:
```

---

## Critical Issues Found
**List all critical issues that block release:**

1.
2.
3.

---

## High Priority Issues
**Issues that should be fixed before release:**

1.
2.
3.

---

## Medium/Low Issues
**Issues that can be addressed in future updates:**

1.
2.
3.

---

## Overall Testing Summary
- **Total Tests Planned:** 8
- **Tests Completed:** ___/8
- **Tests Passed:** ___/8
- **Tests Failed:** ___/8
- **Critical Issues:** ___
- **High Priority Issues:** ___
- **Medium/Low Issues:** ___

**Ready for Release?** [ ] Yes [ ] No

**Notes:**
