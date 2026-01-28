# Phase 5: UnifiedCollectionCard - Manual Integration Required

## Status
✅ UnifiedCollectionCard component created and ready
⚠️  Requires manual Xcode integration to complete

## What Was Done
- Created `UnifiedCollectionCard.swift` in `/Heirloom/Features/Collections/Components/`
- Component handles both `.standard` and `.themed` variants
- All shared layout logic extracted
- Backward compatible with existing functionality

## File Location
`/Users/matthanson/Heirloom/Heirloom/Features/Collections/Components/UnifiedCollectionCard.swift`

## Manual Steps Required

### Step 1: Add File to Xcode Project
1. Open `Heirloom.xcodeproj` in Xcode
2. In Project Navigator, navigate to: `Heirloom` → `Features` → `Collections` → `Components`
3. Right-click on the `Components` folder
4. Select "Add Files to Heirloom..."
5. Navigate to and select `UnifiedCollectionCard.swift`
6. Ensure "Copy items if needed" is **unchecked** (file is already in correct location)
7. Ensure "Heirloom" target is **checked**
8. Click "Add"

### Step 2: Update CollectionsListView
Once the file is added to Xcode, update `/Heirloom/Features/Collections/CollectionsListView.swift`:

**Replace ThemeCollectionCard usage (around line 465):**
```swift
// OLD:
ThemeCollectionCard(
    collection: collection,
    currentDay: themeUnlockTracker.currentTrialDay,
    unlockTracker: themeUnlockTracker,
    allRecipes: allRecipes,
    allThemes: allThemes
)

// NEW:
UnifiedCollectionCard(
    collection: collection,
    variant: .themed(
        currentDay: themeUnlockTracker.currentTrialDay,
        unlockTracker: themeUnlockTracker,
        allRecipes: allRecipes,
        allThemes: allThemes
    )
)
```

**Replace StandardCollectionCard usage (around line 506):**
```swift
// OLD:
StandardCollectionCard(
    collection: collection,
    onAddRecipeTap: (collection.recipes?.count ?? 0) == 1
        ? { handleAddRecipeToCollection(collection) }
        : nil
)

// NEW:
UnifiedCollectionCard(
    collection: collection,
    variant: .standard(
        onAddRecipeTap: (collection.recipes?.count ?? 0) == 1
            ? { handleAddRecipeToCollection(collection) }
            : nil
    )
)
```

### Step 3: Build and Test
1. Build the project (`Cmd+B`) - should succeed
2. Run on simulator
3. Navigate to Collections tab
4. Verify both themed and standard collections render correctly
5. Test + affordance, AI generation, context menus

### Step 4: Optional Cleanup
After verifying everything works, you can optionally:
- Mark `StandardCollectionCard.swift` as deprecated
- Mark `ThemeCollectionCard.swift` as deprecated
- Or delete both files (they're now redundant)

## Benefits of UnifiedCollectionCard
- **Code Reduction**: ~450 lines reduced to ~350 lines (single source of truth)
- **Maintainability**: Changes to layout only need to be made once
- **Consistency**: Guaranteed visual consistency between card types
- **Type Safety**: Variants ensure correct data for each card type

## Troubleshooting
- **"Cannot find UnifiedCollectionCard"**: File not added to Xcode target - follow Step 1
- **"Cannot infer .standard/.themed"**: Import issue - clean build folder (`Cmd+Shift+K`)
- **Build errors after adding**: Check that `CircularProgressView` isn't defined elsewhere

## Next Steps (Phase 6 & 7)
Once Phase 5 is complete, the plan includes:
- Phase 6: Smart + affordance in empty collections (large hero slot)
- Phase 7: Background customization UI (photo picker, remove background)
