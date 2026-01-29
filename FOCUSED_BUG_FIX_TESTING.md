# 🎯 Focused Bug Fix Testing Guide

**Date:** 2026-01-28
**Focus:** Test only the bug fixes, not features that already worked
**Expected Duration:** 15-20 minutes

---

## ⚡ Quick Test Plan

This guide tests **only the 8 bugs that were fixed**, not the features that already worked.

| # | Test | Priority | Expected Time |
|---|------|----------|---------------|
| 1 | Empty user collections appear | P0 | 2 min |
| 2 | Photo imports create collection | P0 | 3 min |
| 3 | Ellipses menu in detail view | P0 | 2 min |
| 4 | AI generation for themes | P1 | 3 min |
| 5 | Custom photos display | P1 | 2 min |
| 6 | Affordance text per type | P2 | 2 min |
| 7 | Cookbook routing 🔍 | P0 | 3 min + logs |
| 8 | Share deep links 🔍 | P1 | 3 min + logs |

🔍 = Requires console/log monitoring

---

## Test 1: Empty User Collections Now Appear ✅

**Bug Fixed:** #1 (P0) - Empty user-created collections were hidden

### Steps:
1. Tap "+" in Collections tab
2. Create new collection: "Test Empty Collection"
3. **Don't add any recipes**
4. Dismiss sheet

### ✅ Expected Result:
- "Test Empty Collection" appears in My Collections section
- Shows large + affordance in center with "Add Your First Recipe"

### ❌ Fail If:
- Collection doesn't appear at all
- Have to add a recipe before it shows

Created new collection, but does not have + affordance (see image)

---

## Test 2: Photo Imports Create Collection ✅

**Bug Fixed:** #3 (P0) - Photo imports didn't create "Photo Imports" collection

### Steps:
1. Navigate to Collections tab
2. Tap the photo imports collection card (or create import flow)
3. Select 3 photos from library
4. Tap "Import Selected"
5. Wait for processing to complete (~30 seconds)
6. Go back to Collections tab

### ✅ Expected Result:
- "Photo Imports" collection exists in My Collections
- Contains all 3 imported recipes
- Shows proper recipe thumbnails



### ❌ Fail If:
- No "Photo Imports" collection created
- Recipes went to different collection
- Only 1 photo processed instead of all 3

Only extracted one recipe when 3 were selected, importing the only recipe that was detected did not add it to any group. It's lost to time. 

---

## Test 3: Ellipses Menu in Detail View ✅

**Bug Fixed:** #4 (P0) - No ellipses menu existed in collection detail view

### Steps:
1. Open any collection detail view
2. Look at toolbar - should see ellipses icon (•••)
3. Tap ellipses icon
4. Verify menu items

Tapping elipses triggeres a 2nd eclipses menu, when I click that menu I get the options. We need to make it so the options appear when clicking the ellipses without so many steps. 

### ✅ Expected Result:
Menu shows:
- ⚙️ **Collection Settings**
- ✨ **Generate with AI** (not disabled)
- 🗑️ **Delete Collection** (only if non-system collection)

They are there but are 1 click too deep. 

### Sub-test A: Settings Navigation
1. Tap "Collection Settings"
2. Settings sheet opens with background options

This worked, but it is not the 'background' its the primary thumbnail in the collection card, lets use language implying that instead (like, collection card image)

### Sub-test B: AI Generation from Detail
1. Tap ellipses → "Generate with AI"
2. Toast shows "Generating Background..."
3. Wait ~20 seconds
4. Toast shows "Background Generated"
5. AI image appears in collection card

Works



### ❌ Fail If:
- No ellipses menu exists
- Menu items missing
- "Generate with AI" disabled when it shouldn't be
- Settings doesn't open
- AI generation doesn't work from menu

---

## Test 4: AI Generation for Theme Collections ✅

**Bug Fixed:** #5 (P1) - AI generation didn't display for theme collections

### Steps:
1. Open "Your Discoveries" section
2. Find a theme collection (e.g., "30 Days of Fresh Italian")
3. Tap ellipses → "Generate with AI"
4. Wait for generation (~20 seconds)
5. Observe collection card

### ✅ Expected Result:
- AI generated image appears in **large hero slot (60% left side)**
- Small recipe thumbnails remain in **right stacked slots (40%)**
- AI image completely replaces theme cover image in large slot

### ❌ Fail If:
- AI image doesn't appear at all
- Still shows theme cover image instead
- AI image goes to small slots instead of large hero slot

Works

---

## Test 5: Custom Photos Display Correctly ✅

**Bug Fixed:** #6 (P1) - Custom photos didn't display after selection

### Steps:
1. Open any collection
2. Tap ellipses → "Collection Settings"
3. Toggle "Use Custom Background" ON
4. Tap "Choose Photo"
5. Select any photo from library
6. Observe preview area in settings

Works but poorly named

### ✅ Expected Result:
- Photo displays **immediately** in preview (150pt height)
- Toast shows "Background Updated"
- Tap "Done"
- Custom photo displays in collection card large slot

### ❌ Fail If:
- Preview stays empty after photo selection
- Toast doesn't show
- Photo doesn't appear in collection card after dismissing settings

---

## Test 6: Type-Specific Affordance Text ✅

**Bug Fixed:** #9 (P2) - All affordances showed generic "Add" text

### Steps:
Create 4 collections, each with exactly 1 recipe:

#### A. Web Imports
1. Import a recipe from web
2. Verify collection has 1 recipe
3. Check small + affordance shows **"Import"**

Worked, takes time to refresh the collection card, lets have a delay until the info loads before showing the collection card.

#### B. Video Imports
1. Import a recipe from video
2. Verify collection has 1 recipe
3. Check small + affordance shows **"Video"**

Works

#### C. Cookbook Pages
1. Scan a cookbook page
2. Verify collection has 1 recipe
3. Check small + affordance shows **"Scan"**

Shows up in cookbook pages section. there were 2 recipes but only one was imported. 

#### D. Photo Imports (if you have one with 1 recipe)
1. Check small + affordance shows **"Photos"**

### ✅ Expected Result:
Each collection type shows correct text in small + affordance (bottom-right quadrant)

### ❌ Fail If:
- All show generic "Add" text
- Text doesn't match collection type

---

## Test 7: Cookbook Routing 🔍 (WITH LOGGING)

**Bug Fixed:** #2 (P0) - Cookbooks routed to "Shared Recipes" collection

**⚠️ IMPORTANT:** Open Console.app or Xcode console BEFORE starting test

### Steps:
1. **Open Console.app** (or Xcode console if running in simulator)
2. Filter for: `subsystem:com.heirloom.app` OR search for `[Import]`
3. Open Heirloom → Cookbook Scanner
4. **CRITICAL:** Enter cookbook name: **"Jan 28 Test Cookbook"**
5. **Verify name field shows "Jan 28 Test Cookbook" before scanning**
6. Scan a recipe page
7. Wait for processing (~30 seconds)
8. **Watch console logs**

### ✅ Expected Result:

**Console logs should show:**
```
[Import] Creating cookbook import job
    collectionName: "Jan 28 Test Cookbook"
    userEnteredName: "Jan 28 Test Cookbook"
    isEmpty: false

[Import] Auto-creating collection for completed job
    jobId: <uuid>
    cookbookName: "Jan 28 Test Cookbook"
    collectionType: "cookbook"
    successfulRecipes: 1
```

**Collections tab should show:**
- "Jan 28 Test Cookbook" collection exists
- Contains the scanned recipe
- Recipe is **NOT** in "Shared Recipes" collection

### ❌ Fail If:
- Recipe goes to "Shared Recipes" instead
- No "Jan 28 Test Cookbook" collection created
- Console shows: `Skipping collection creation - cookbook name is empty`

**If test fails:** Share screenshot of console logs showing the full flow


I imported a large cookbook, it still imports to 'shared recipes' (image 2)

---

## Test 8: Recipe Share Deep Links 🔍 (WITH LOGGING)

**Bug Fixed:** #7 (P1) - Share links didn't open from Messages

**⚠️ IMPORTANT:** Open Console.app or Xcode console BEFORE starting test

### Steps:
1. **Open Console.app** (or Xcode console)
2. Filter for: `[DeepLink]`
3. Open any recipe in Heirloom
4. Tap share icon → "Copy Link"
5. Open Messages app
6. Paste link and send to yourself (link looks like: `heirloom://share/UUID`)
7. **Force quit Heirloom app** (double-tap home, swipe up to close)
8. Tap the link in Messages
9. **Watch console logs**

### ✅ Expected Result:

**Console logs should show:**
```
📥 [DeepLink] DeepLinkHandler received URL: heirloom://share/<uuid>
⏳ [DeepLink] App not ready, queuing URL for later
  [DeepLink] Queue now has 1 URL(s)
✅ [DeepLink] App marked as ready for deep links
📱 [DeepLink] Processing 1 queued URL(s)
🔄 [DeepLink] Processing URL: heirloom://share/<uuid>
🔗 [DeepLink] Detected heirloom:// URL scheme
```

**App behavior:**
- App launches from cold start
- Recipe share sheet appears with recipe details

### ❌ Fail If:
- App launches but no share sheet appears
- Console shows: `⚠️ [DeepLink] Ignoring duplicate URL` (shouldn't happen after 5s window increase)
- Console shows URL was lost/never processed

**If test fails:** Share screenshot of console logs showing what happened to the URL

Share links did not work when I tried to open using the desktop messenger and opening in simulator. Link worked when sent from simulator to device. Here are the different messages I sent myself from each device trying to share a recipe. (Image 4) the heirloom://share/....worked on my mobile device when sent from mobile and opened on mobile.

---

## 📋 Quick Results Checklist

Mark each test as you complete it:

- [ ] **Test 1:** Empty collections appear ✅
- [ ] **Test 2:** Photo imports create collection ✅
- [ ] **Test 3:** Ellipses menu works ✅
  - [ ] Settings navigation
  - [ ] AI generation from menu
- [ ] **Test 4:** Theme AI generation displays ✅
- [ ] **Test 5:** Custom photos display ✅
- [ ] **Test 6:** Affordance text correct ✅
  - [ ] Web Imports → "Import"
  - [ ] Video Imports → "Video"
  - [ ] Cookbook → "Scan"
  - [ ] Photo Imports → "Photos"
- [ ] **Test 7:** Cookbook routing 🔍 (check logs)
- [ ] **Test 8:** Share deep links 🔍 (check logs)

---

## 🚀 Test Results Summary

### If All Tests Pass:
**Status: READY TO SHIP! 🎉**
- All P0 bugs fixed and verified
- All P1 bugs fixed and verified
- All P2 bugs fixed and verified

### If Test 7 or 8 Fail:
**Status: Need final diagnosis**
- Share console logs from failed test
- I'll implement final fix based on log evidence
- Should be quick fix (~30 min)

---

## 💡 Testing Tips

1. **Console Logs:** Use Console.app (not terminal) for easier filtering
   - Open Console.app
   - Select your device/simulator
   - Search bar: enter `[Import]` or `[DeepLink]`
   - Logs will auto-scroll as they appear

2. **Force Quit:** To test deep links properly:
   - Double-tap home button (or swipe up on newer iPhones)
   - Swipe Heirloom app preview upward
   - This ensures cold start

3. **Cookbook Names:** Always enter a unique name for cookbook tests:
   - Good: "Jan 28 Test", "My Cookbook 2026", "Grandma's Recipes"
   - Bad: Empty field, generic "Cookbook Pages"

4. **Take Screenshots:** If anything fails, screenshot:
   - The issue in the app
   - The console logs showing the problem
   - Both help diagnose quickly

---

**Total Testing Time:** ~15-20 minutes (or ~25 if Test 7/8 need investigation)

**Good luck! You're so close to shipping! 🚀**
