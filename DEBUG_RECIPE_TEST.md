# Debug Recipe & Scrolling Issues

## Test Plan

### Issue 1: Ingredients Not Showing

**Steps to test:**
1. Open the app
2. **DELETE the existing "Grandma's Chocolate Chip Cookies"** (swipe left or use detail view delete)
3. Tap "Add Sample Recipe" button
4. Watch console for: `✅ Sample recipe saved with 9 ingredients`
5. Tap the new recipe card
6. Check if ingredients appear OR if you see red debug text

**What the debug text tells us:**
- "Recipe.ingredients is nil" → Recipe was created without ingredients relationship
- "Recipe.ingredients is empty array" → Array exists but has no items

### Issue 2: Scrolling/Jumping Cards

**What's happening:**
The cards are jumping/sliding because AsyncRecipeImage is changing size as it loads.

**Fixed in latest build:**
1. All card dimensions are now fixed
2. Image container uses ZStack (more stable)
3. ForEach uses explicit IDs
4. Cards have fixed heights for all elements

**Test the fix:**
1. Delete all recipes
2. Add 3-4 sample recipes (tap button multiple times)
3. Scroll up and down
4. **Expected:** Cards should NOT jump or slide
5. **If still jumping:** The skeleton/placeholder has different size than loaded image

## Quick Fixes if Still Broken

### If Ingredients Still Don't Show:

The recipe needs to be created WITH ingredients in the modelContext. Try this in RecipeListView:

```swift
private func addSampleRecipe() {
    // Create recipe
    let recipe = Recipe.example
    modelContext.insert(recipe)

    // IMMEDIATELY create ingredients BEFORE saving
    let texts = [
        "2 1/4 cups flour",
        "1 tsp baking soda",
        "1 tsp salt",
        "1 cup butter",
        "3/4 cup sugar",
        "3/4 cup brown sugar",
        "2 eggs",
        "2 tsp vanilla",
        "2 cups chocolate chips"
    ]

    for (i, text) in texts.enumerated() {
        let ing = Ingredient(originalText: text, orderIndex: i)
        ing.recipe = recipe
        modelContext.insert(ing)
    }

    // Force save
    try? modelContext.save()

    print("✅ Created recipe with ID: \(recipe.id)")
}
```

### If Cards Still Jump:

The AsyncRecipeImage needs a FIXED frame. In RecipeCardView:

```swift
AsyncRecipeImage(...)
    .frame(width: UIScreen.main.bounds.width / 2 - 32, height: 150)
    .clipped()
    .cornerRadius(12)
```

## Current Status

**From Console Log:**
- ✅ App launches
- ✅ Analytics working
- ✅ Recipe viewed successfully
- ✅ Shopping list toggle works
- ⚠️ CloudKit warnings (expected - no iCloud in simulator)
- ⚠️ Array warnings (benign - SwiftData internal)
- ❓ No "Sample recipe saved" message → You're viewing an OLD recipe

**Action:** DELETE OLD RECIPE and add a new one to test the fix!
