# Onboarding Flow Testing Guide

## Pre-Testing Setup

### 1. Add Placeholder Image (Required)
The onboarding flow requires `onboarding-grilled-cheese-soup.png` in the asset catalog.

**Quick Fix Option A: Use Existing Asset**
```swift
// In OnboardingConceptScreen.swift, line 21, temporarily change:
imageName: "onboarding-grilled-cheese-soup"
// To use an existing asset:
imageName: "ceramic-hero-book"
```

**Option B: Add Placeholder Image**
1. Open Xcode
2. Navigate to `Assets.xcassets`
3. Right-click → New Image Set → Name: `onboarding-grilled-cheese-soup`
4. Drag any placeholder image (can be any recipe photo or even the ceramic book)

### 2. Build the Project
```bash
cd /Users/matthanson/Heirloom
xcodebuild -project Heirloom.xcodeproj -scheme Heirloom -sdk iphonesimulator build
```

If you encounter provisioning errors, open in Xcode:
```bash
open Heirloom.xcodeproj
```
Then build via Xcode (Cmd+B).

### 3. Reset Onboarding State
To test the full onboarding flow from scratch:

**Option A: Delete the app** from simulator
- Long press app icon → Delete App

**Option B: Reset UserDefaults** (if testing repeatedly)
Add this temporary code to `HeirloomApp.swift` in the `init()`:
```swift
// Temporary: Reset onboarding for testing
UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
UserDefaults.standard.set(false, forKey: "hasSeenBlindBoxes")
UserDefaults.standard.set(false, forKey: "OnboardingRecipeSeeded")
```

## Testing Steps

### Test 1: Three-Screen Onboarding Flow

1. **Launch app** (should start onboarding if never completed)

2. **Screen 1: Welcome**
   - ✅ Should show ceramic book icon
   - ✅ Title: "Heirloom"
   - ✅ Tagline: "Your recipes, preserved forever"
   - ✅ 3 value propositions with icons
   - ✅ "Get Started" button (tomato color)
   - **Action:** Tap "Get Started"

3. **Screen 2: Concept Introduction**
   - ✅ Title: "Organize recipes you love"
   - ✅ Recipe card showing "Grilled Cheese and Tomato Soup"
   - ✅ 3 collection rows: Favorites (highlighted + pulsing), Quick Meals, Meal Prep
   - ✅ Elements are non-tappable (taps should do nothing)
   - ✅ Favorites row should have subtle pulse animation (2 cycles)
   - **Action:** Tap "Continue"

4. **Screen 3: Import Methods**
   - ✅ Shows 4 import method cards (Video, Image, Website, Manual)
   - ✅ Can tap cards to see preview overlay
   - **Action:** Tap "Continue"

5. **Post-Onboarding: Collections Tab**
   - ✅ Should land on **Collections tab** (not Recipes)
   - ✅ Should see 2 "Mystery Collection" blind boxes at top
   - ✅ Blind boxes should have:
     - Blurred gift icon
     - "Mystery Collection" text (slightly blurred)
     - "Tap to reveal" subtitle
     - Sparkles icon on right
     - Tomato border with shimmer effect

### Test 2: Blind Box Reveal

1. **Tap first blind box**
   - ✅ Should feel haptic feedback
   - ✅ Scale animation (1.0 → 1.05)
   - ✅ Blur reduces to 0 over 0.5s
   - ✅ Second haptic after animation completes
   - ✅ Toast notification appears: "Discovered: [Collection Name]"
   - ✅ Should reveal: **Literary Kitchen** collection

2. **Tap second blind box**
   - ✅ Same reveal animation
   - ✅ Should reveal one of: Presidential Pantry, Ancient Table, or American Foundation (random)

3. **After revealing both**
   - ✅ Blind boxes should be replaced by normal collection rows
   - ✅ Can tap collection rows to view recipes

### Test 3: Grilled Cheese Recipe

1. **Navigate to Recipes tab**
   - Switch to Recipes tab (first tab)

2. **Check Favorites**
   - ✅ Should see "Grilled Cheese and Tomato Soup" recipe
   - ✅ Recipe should have:
     - Image (if asset added, else placeholder)
     - Title
     - In "Favorites" collection

3. **Open recipe**
   - ✅ Full recipe details should be present
   - ✅ 10 ingredients
   - ✅ 11 instruction steps
   - ✅ Servings: 2
   - ✅ Prep: 10 minutes
   - ✅ Cook: 25 minutes

4. **Check card back**
   - Flip recipe card
   - ✅ Should see welcome note: "This is your first recipe! Try tapping different parts of the app."

### Test 4: Persistence

1. **Close and reopen app**
   - ✅ Should NOT show onboarding again
   - ✅ Should land on last selected tab
   - ✅ Blind boxes should remain revealed
   - ✅ Grilled Cheese recipe should still be in Favorites

## Known Issues to Check

### Compilation Issues
- ❓ Check if project builds without errors in Xcode
- ❓ Verify all imports are present (SwiftUI, SwiftData, Foundation)

### Missing Asset
- ❗ **CRITICAL:** `onboarding-grilled-cheese-soup.png` is not added yet
- **Workaround:** Use temporary placeholder (see Pre-Testing Setup)

### Potential Edge Cases
- ❓ What happens if heritage recipes haven't seeded yet?
- ❓ What if Favorites collection doesn't exist?
- ❓ Does onboarding work if interrupted mid-flow?

## Debug Commands

### Check UserDefaults State
```swift
// In any view's .onAppear:
print("Onboarding completed:", UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
print("Blind boxes seen:", UserDefaults.standard.bool(forKey: "hasSeenBlindBoxes"))
print("Recipe seeded:", UserDefaults.standard.bool(forKey: "OnboardingRecipeSeeded"))
```

### Force Show Onboarding
```swift
// In ContentView.swift
.fullScreenCover(isPresented: .constant(true)) {
    OnboardingContainerView(selectedTab: $selectedTab)
}
```

### Check Blind Box State
```swift
// In CollectionsListView, add to .onAppear:
print("Blind boxes:", blindBoxCollections.map { $0.name })
print("Revealed heritage:", revealedHeritageCollections.map { $0.name })
```

## Testing Checklist Summary

- [ ] Project builds successfully in Xcode
- [ ] Placeholder image added for recipe card
- [ ] Welcome screen displays correctly
- [ ] Concept screen shows static demo
- [ ] Import methods screen functions
- [ ] Lands on Collections tab after onboarding
- [ ] Two blind boxes appear
- [ ] Blind boxes reveal with animation
- [ ] Grilled Cheese recipe in Favorites
- [ ] Onboarding doesn't repeat after completion
- [ ] All transitions are smooth (no crashes)

## Next Steps After Testing

Once basic flow is confirmed:
1. Add actual recipe image (600x450px, shows grilled cheese + soup)
2. Implement recipe filtering (hide unrevealed blind box recipes from Recipes tab)
3. Add pull-to-refresh sign-in prompt
4. Add entrance animation to Recipes tab

## Troubleshooting

### App crashes on onboarding
- Check Xcode console for error messages
- Verify all files are added to target
- Ensure SwiftData model changes are handled

### Blind boxes don't appear
- Check: `UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")` returns `true`
- Check: Heritage recipes were seeded (check heritage collections exist)
- Add debug logging to `seedBlindBoxesIfNeeded()`

### Recipe doesn't appear in Favorites
- Verify Favorites collection was created (system collections)
- Check `OnboardingRecipeSeeder` was called
- Add debug logging to seeder

### Image doesn't show
- Verify asset name matches exactly: `onboarding-grilled-cheese-soup`
- Check asset is in correct target membership
- Fallback: Use placeholder asset temporarily
