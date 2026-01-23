# Add Onboarding Files to Xcode - Quick Checklist

**Xcode is now open.** Follow these steps to add the 7 new files:

## Step 1: Navigate to Onboarding Folder
1. In Xcode's **left sidebar** (Project Navigator), press **⌘1** to ensure it's visible
2. Expand: **Heirloom** → **Features** → **Onboarding**

## Step 2: Add New Screen Files (4 files)

1. **Right-click** on the **Onboarding** folder
2. Select **"Add Files to "Heirloom"..."**
3. Navigate to: `Heirloom/Features/Onboarding/`
4. **Select these 4 files** (hold ⌘ to select multiple):
   - [ ] `OnboardingVideoHeroScreen.swift`
   - [ ] `OnboardingShareExtensionScreen.swift`
   - [ ] `OnboardingFlexibilityScreen.swift`
   - [ ] `OnboardingOrganizationScreen.swift`

5. **Before clicking Add:**
   - ✅ Check: **"Copy items if needed"** (should be UNCHECKED - files are already in place)
   - ✅ Check: **"Create groups"** (should be SELECTED)
   - ✅ Check: **"Heirloom"** target is CHECKED in "Add to targets"

6. Click **"Add"**

## Step 3: Create Components Folder

1. **Right-click** on the **Onboarding** folder
2. Select **"New Group"**
3. Name it: **"Components"**

## Step 4: Add Component Files (3 files)

1. **Right-click** on the new **Components** folder you just created
2. Select **"Add Files to "Heirloom"..."**
3. Navigate to: `Heirloom/Features/Onboarding/Components/`
4. **Select these 3 files** (hold ⌘ to select multiple):
   - [ ] `PremiumBadge.swift`
   - [ ] `ThreeTierExtractionView.swift`
   - [ ] `FeaturePill.swift`

5. **Before clicking Add:**
   - ✅ Check: **"Copy items if needed"** (should be UNCHECKED)
   - ✅ Check: **"Create groups"** (should be SELECTED)
   - ✅ Check: **"Heirloom"** target is CHECKED

6. Click **"Add"**

## Step 5: Verify Files Were Added

In the Onboarding folder, you should now see:
- [ ] OnboardingVideoHeroScreen.swift (NEW - has blue icon)
- [ ] OnboardingShareExtensionScreen.swift (NEW - has blue icon)
- [ ] OnboardingFlexibilityScreen.swift (NEW - has blue icon)
- [ ] OnboardingOrganizationScreen.swift (NEW - has blue icon)
- [ ] Components/ (folder)
  - [ ] PremiumBadge.swift
  - [ ] ThreeTierExtractionView.swift
  - [ ] FeaturePill.swift

**Note:** OnboardingContainerView.swift and ImportMethodCard.swift should show "M" (modified) since we updated them.

## Step 6: Build

1. **Clean Build Folder**: Press **⇧⌘K** (Shift + Cmd + K)
2. **Build**: Press **⌘B** (Cmd + B)
3. **Check for errors** in the bottom panel

✅ If build succeeds → Continue to Step 7
❌ If build fails → Let me know the error

## Step 7: Reset Onboarding Flag (for testing)

In Xcode, find and open `HeirloomApp.swift`:
1. Press **⌘⇧O** (Cmd + Shift + O) - "Open Quickly"
2. Type: `HeirloomApp.swift` and press Enter
3. Find the `ContentView` struct (around line 1090)
4. **Temporarily add** this line at the top of the `.onAppear` block:
   ```swift
   .onAppear {
       UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding") // TEMPORARY - Remove after testing

       // ... rest of existing code
   }
   ```

## Step 8: Test New Onboarding

1. **Run the app**: Press **⌘R**
2. You should see the NEW onboarding:
   - [ ] **Screen 1**: "Recipes from your favorite creators" (video hero)
   - [ ] **Screen 2**: "Share from anywhere" (share extension tutorial)
   - [ ] **Screen 3**: "Import from any source" (flexibility + features)
   - [ ] **Screen 4**: "Beautiful recipes, beautifully organized" (organization)
3. Tap through all 4 screens
4. Verify "Start Cooking" button completes onboarding

## Step 9: Remove Temporary Code

After testing, **remove** the line you added in Step 7:
```swift
UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding") // DELETE THIS
```

## Step 10: Commit & Merge

Once everything works:

```bash
# Commit the Xcode project changes
git add Heirloom.xcodeproj/project.pbxproj
git commit -m "Add new onboarding files to Xcode project"

# Merge to main
git checkout main
git merge feature/onboarding-redesign-video-first
git push
```

---

## Troubleshooting

**If files don't appear:**
- Make sure you selected the correct folder path
- Check "Add to targets" has Heirloom checked

**If build fails with "Cannot find HeirloomColors":**
- Files weren't added to Heirloom target
- Select each new file → File Inspector (⌥⌘1) → Check "Heirloom" under Target Membership

**Need help?** Just let me know what error you're seeing!

---

**Files to add:** 7 total (4 screens + 3 components)
**Expected time:** 2-3 minutes
**Current branch:** `feature/onboarding-redesign-video-first`
