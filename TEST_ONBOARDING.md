# Test New Onboarding Flow

## Quick Test Steps

### 1. Reset Onboarding Flag

**Option A - In Xcode (Temporary for testing):**
1. Open `HeirloomApp.swift` (Press ⌘⇧O, type "HeirloomApp")
2. Find the `ContentView` struct
3. In the `.onAppear` block, add at the very top:
   ```swift
   UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
   ```
4. Build & Run (⌘R)
5. **Remove this line after testing!**

**Option B - Via Simulator Menu (Cleaner):**
1. Run app in simulator (⌘R)
2. In **Simulator menu**: Device → Erase All Content and Settings
3. Run app again - onboarding will show

**Option C - Delete App from Simulator:**
1. Long-press Heirloom app icon in simulator
2. Tap the X to delete
3. Run app again (⌘R)

### 2. Walk Through New Onboarding

You should see these 4 NEW screens:

#### ✅ Screen 1: Video-to-Recipe Hero
- Title: **"Recipes from your favorite creators"**
- Subtitle: "AI extracts ingredients and steps from cooking videos"
- Mock video card with @gordonramsay badge
- 3-tier extraction showcase:
  - Listen (audio)
  - Read (OCR)
  - See (visual) **← Has Premium badge**
- Platform icons: TikTok, Instagram, YouTube, Safari
- Button: **"See How It Works"**

#### ✅ Screen 2: Share Extension Tutorial
- Title: **"Share from anywhere"**
- Subtitle: "One tap from the apps you already use"
- iOS share sheet mockup with Heirloom highlighted
- Platform flow visualization
- 3 steps:
  1. See recipe
  2. Tap Share → Heirloom
  3. Recipe saved automatically
- Button: **"Continue"**

#### ✅ Screen 3: Import Flexibility + Features
- Title: **"Import from any source"**
- Subtitle: "Plus powerful features to organize and share"
- 2x2 grid of import methods:
  - **Share Extension** (purple) ← **Has pulse animation**
  - Image Scan (blue)
  - Website URLs (green)
  - Manual (orange)
- 3 feature pills:
  - Recipe Lineage
  - Creator Attribution
  - Meal Planning
- Button: **"Continue"**

#### ✅ Screen 4: Organization & Sync
- Title: **"Beautiful recipes, beautifully organized"**
- Subtitle: "Collections, sync, and sharing built in"
- 2 recipe cards (Grilled Cheese, Tomato Soup)
- 3 collections with Favorites highlighted (pulses)
- **Sync indicator**: "Syncs across all your devices"
- Button: **"Start Cooking"**

### 3. Verify Completion

After tapping "Start Cooking":
- [ ] App should show main interface (Collections tab)
- [ ] Onboarding should NOT show on next launch
- [ ] 2 sample recipes should be created (Grilled Cheese, Tomato Soup)

### 4. Test Animations

Check these animations work smoothly:
- [ ] Screen transitions (slide left/right)
- [ ] Premium badge subtle pulse (Screen 1)
- [ ] Share extension card pulse (Screen 3)
- [ ] Collections Favorites pulse (Screen 4)

### 5. Test on Different Devices

Test in simulator on:
- [ ] iPhone SE (small screen) - Does text fit?
- [ ] iPhone 16 Pro (standard) - Everything looks good?
- [ ] iPad Air (large screen) - Layout adapts?

---

## If Everything Works ✅

```bash
# You're ready to merge!
git checkout main
git merge feature/onboarding-redesign-video-first
git push
```

## If Something's Wrong ❌

Let me know what's not working and I'll help fix it!

---

**Current Branch:** `feature/onboarding-redesign-video-first`
**Build Status:** ✅ SUCCESS
**Files Status:** ✅ All added to Xcode
**Next Step:** Test onboarding flow
