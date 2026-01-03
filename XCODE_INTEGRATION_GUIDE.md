# Xcode Integration Guide - Phase 3 Components

## Step-by-Step Instructions

### Step 1: Add Files to Xcode Project (2 minutes)

1. **Open Xcode**
   ```
   open Heirloom.xcodeproj
   ```

2. **Navigate to RecipeDetail folder**
   - In Project Navigator (⌘1), expand:
     - Heirloom → Features → Recipes → RecipeDetail

3. **Add the component files**
   - Right-click on `RecipeDetail` folder
   - Select "Add Files to 'Heirloom'..."
   - Navigate to: `Heirloom/Features/Recipes/RecipeDetail/`
   - Select these 4 files (hold ⌘ to multi-select):
     - `RecipeDetailHeader.swift`
     - `RecipeMetadataSection.swift`
     - `RecipeIngredientsSection.swift`
     - `RecipeInstructionsSection.swift`
   - ✅ Ensure "Copy items if needed" is **unchecked** (files are already in place)
   - ✅ Ensure "Add to targets: Heirloom" is **checked**
   - Click "Add"

### Step 2: Update RecipeDetailView.swift (3 minutes)

Open `RecipeDetailView.swift` and make these replacements:

#### Replace Line 179: `headerSection` with:
```swift
RecipeDetailHeader(
    recipe: recipe,
    displayTitle: displayTitle,
    isInShoppingCart: isInShoppingCart,
    onToggleFavorite: toggleFavorite,
    onAddToShoppingList: addToShoppingList
)
```

#### Replace Line 187: `metadataSection` with:
```swift
RecipeMetadataSection(
    recipe: recipe,
    targetServings: $targetServings,
    showScalingExplanation: $showScalingExplanation
)
```

#### Replace Lines 195-211: `ingredientsSection(ingredients)` block with:
```swift
if let ingredients = recipe.ingredients, !ingredients.isEmpty {
    RecipeIngredientsSection(
        recipe: recipe,
        ingredients: ingredients,
        targetServings: targetServings
    )
}
```

#### Replace Lines 214-216: `instructionsSection` with:
```swift
if !recipe.instructions.isEmpty {
    RecipeInstructionsSection(instructions: displayInstructions)
}
```

### Step 3: Remove Old Section Code (Optional - After Testing)

Once verified working, you can delete these old private view properties:
- `private var headerSection` (lines 379-423)
- `private var metadataSection` (lines 524-651)
- `private func ingredientsSection(_ ingredients: [Ingredient])` (lines 676-825)
- `private var instructionsSection` (lines 826-871)

**Keep these helper methods** (they're used by components):
- `sectionHeader(title:icon:count:)` - Used by Ingredients/Instructions sections

### Step 4: Build & Verify

1. **Clean Build Folder** (⇧⌘K)
2. **Build** (⌘B)
3. **Run** (⌘R)

### Expected Results

✅ RecipeDetailView compiles successfully
✅ Recipe detail screen looks identical to before
✅ All interactions work (favorite, shopping list, serving selector)
✅ Ingredients scale correctly when changing servings
✅ SwiftUI previews work for each component

---

## Quick Verification Checklist

After integration, test these features:

- [ ] Recipe title displays correctly
- [ ] Favorite button toggles (heart icon)
- [ ] Shopping list button works
- [ ] Serving selector dropdown shows options
- [ ] Changing servings scales ingredient quantities
- [ ] Ingredients display with proper formatting
- [ ] Instructions display numbered steps
- [ ] Scrolling is smooth
- [ ] No console errors

---

## Troubleshooting

### Issue: "Cannot find 'RecipeDetailHeader' in scope"
**Solution**: Files not added to Xcode project. Repeat Step 1.

### Issue: Build errors about missing properties
**Solution**: Check that all 4 component files were added with "Add to targets: Heirloom" checked.

### Issue: Components don't display
**Solution**: Verify RecipeDetailView.swift has the exact code from Step 2.

### Issue: Scaling doesn't work
**Solution**: Ensure `targetServings` is passed as a direct value (not `$targetServings`) to RecipeIngredientsSection.

---

## File Locations

All component files are located in:
```
Heirloom/Features/Recipes/RecipeDetail/
├── RecipeDetailView.swift (main view - to be updated)
├── RecipeDetailHeader.swift (NEW)
├── RecipeMetadataSection.swift (NEW)
├── RecipeIngredientsSection.swift (NEW)
└── RecipeInstructionsSection.swift (NEW)
```

---

## Benefits After Integration

- **RecipeDetailView**: 1,544 → ~1,000 lines (35% reduction)
- **Component Reusability**: Use in RecipeCardView, widgets, previews
- **Better Previews**: Each component has its own SwiftUI preview
- **Faster Compilation**: Smaller files compile faster
- **Team Velocity**: Different devs can work on different components

---

## Next Steps After Integration

Once integrated and verified:

1. **Phase 3 Week 6**: Extract remaining sections
   - RecipeNotesAndSourceSection
   - RecipeCommentsSection (142 lines)

2. **Phase 4**: Code Quality & Cleanup
   - Remove 634 print statements
   - Replace with proper logging

3. **Phase 5**: Architecture Modernization
   - Convert 89 singletons to DI

---

**Need Help?** Check the VIEW_DECOMPOSITION_PLAN.md for full architectural details.
