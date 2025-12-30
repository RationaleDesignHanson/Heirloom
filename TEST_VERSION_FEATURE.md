h# Testing Multi-Version Recipe Feature

## Test Plan - Phase 1 & 2 Features + Multi-Recipe Selection

### Prerequisites
- ✅ Build succeeded
- ✅ DebugVersionTestView.swift added to Xcode project
- ✅ RecipeSelectionView.swift added to Xcode project
- App installed on simulator

---

## 🚀 Quick Start (Easiest Way to Test)

### Using the Debug Menu Button

1. **Open the app in simulator**
2. **Tap "Version Tests" button** at the bottom of the recipe list
3. **Tap "Create Multi-Version Recipe"**
   - Creates "Grandma's Lasagna" with 3 versions automatically
4. **Navigate back to recipe list**
5. **Open "Grandma's Lasagna"** and test version features

This creates the perfect test recipe with:
- **Grandma Kay (1987)** - Base version with ground beef
- **Mom (2015)** - Changed to ground turkey, has 5 cooks
- **You (2025)** - Changed title + added garlic to instructions

Now you can test **Test 3** (Cooking Mode) and **Test 4** (Detail View) immediately!

---

## Test 0: Multi-Recipe Selection from Images

**Goal:** Verify AI can detect and extract multiple recipes from vintage recipe cards

### Prerequisites:
- Save the vintage recipe card images to your Photos app on the simulator
- Images should contain multiple recipes (like the vintage cookbook pages you have)

### Steps:

1. **Open Recipe List** and tap the **"+"** menu
2. **Select "Scan Cookbook"**
3. In the scanner, tap **"Choose Photo"** button (top right, photo icon)
4. **Select a vintage recipe card image** with multiple recipes
5. **Tap "Process"** button
6. **Wait for AI extraction** (may take 5-10 seconds)

### Expected Results by Recipe Count:

#### Scenario A: Image with 2+ Recipes (e.g., Cheese Straws + Peanut Butter Bread page)
- ✅ **RecipeSelectionView appears** with grid/list of detected recipes
- ✅ **Each recipe card shows:**
  - Recipe title (e.g., "Cheese Straws", "Peanut Butter Bread")
  - Ingredient count (e.g., "8 ingredients")
  - Instruction count (e.g., "5 steps")
  - **Confidence badge**: High (green) / Medium (yellow) / Low (red)
- ✅ **All recipes selected by default** (checkboxes checked)
- ✅ **Tap a recipe card** to expand/collapse preview
- ✅ **"Select All / Deselect All"** button works
- ✅ **Bottom shows count**: "X Selected"
- ✅ **Tap "Import Selected"** → Recipes import successfully
- ✅ **Success toast** appears: "Successfully imported X recipes"
- ✅ **View dismisses** and recipes appear in list

#### Scenario B: Image with 1 Recipe
- ✅ **OCRReviewView appears** (traditional single-recipe flow)
- ✅ **No regression** - works exactly as before
- ✅ Can edit title, ingredients, instructions
- ✅ Save works normally

#### Scenario C: Image with 0 Recipes (non-recipe photo)
- ✅ **Error alert appears**: "No recipes detected in the image. Please try again with a clearer photo."
- ✅ **Can tap "OK"** to dismiss
- ✅ **Can tap "Retake"** to try different photo

### Visual Checks:

#### RecipeSelectionView UI:
- [ ] Header banner shows "Found X Recipes"
- [ ] "Select which ones to import" subtitle visible
- [ ] Select All / Deselect All button in header
- [ ] Recipe cards have clear hierarchy (title largest)
- [ ] Confidence badges color-coded correctly:
  - **High (0.9-1.0)**: Green badge with "High" text
  - **Medium (0.7-0.9)**: Yellow/amber badge with "Medium" text
  - **Low (<0.7)**: Red badge with "Low" text
- [ ] Selected recipes have colored border (tomato red)
- [ ] Unselected recipes have no border
- [ ] Expansion chevron (up/down) animates
- [ ] Expanded view shows ingredient/instruction previews
- [ ] Bottom toolbar shows selection count
- [ ] "Import Selected" button disabled when 0 selected

### Test with Different Image Types:

1. **Vintage cookbook page** (2-4 recipes) - Expected: Multi-select view
2. **Single recipe card** - Expected: OCRReviewView (no change)
3. **Modern cookbook page** (1-2 recipes) - Expected: Multi-select or review view
4. **Handwritten recipe** - Expected: Lower confidence scores
5. **Non-recipe photo** - Expected: Error message

### Console Output to Check:

When processing, look for:
```
🎨 Step 1: Preprocessing image...
🔍 Step 2: Performing OCR...
🤖 Step 3: Detecting and extracting recipes...
✅ Processing complete!
   OCR Confidence: XX%
   Detected X recipe(s)
✅ Multiple recipes detected:
   1. Cheese Straws (confidence: 0.95)
   2. Peanut Butter Bread (confidence: 0.92)
   3. Nut and Raisin Rolls (confidence: 0.88)
```

### Known Limitations:
- AI extraction requires configured Anthropic API key
- Without AI, falls back to basic extraction (single recipe only)
- Confidence scores may vary based on image quality and OCR accuracy

---

## Test 1: Migration Service

**Goal:** Verify existing recipes get base versions

### Steps (Using Debug Menu):
1. Launch app
2. Create a test recipe with title "Test Lasagna" (or use existing recipes)
3. **Tap "Version Tests" button** at bottom
4. **Tap "Check Migration Stats"** to see how many need migration
5. **Tap "Run Migration"** to migrate all recipes
6. **Expected:** Success message shows number of recipes migrated
7. Close debug menu and verify recipes now have base versions

### Expected Output:
```
✅ Migrated X recipes to version system
```

---

## Test 2: Create Multiple Versions (Manual)

**Goal:** Test RecipeVersionService

### Steps via Debug Console:
```swift
// 1. Get a recipe
let descriptor = FetchDescriptor<Recipe>()
let recipes = try modelContext.fetch(descriptor)
let recipe = recipes.first!

// 2. Prepare for heirloom sharing (creates base version if needed)
try RecipeVersionService.shared.prepareForHeirloomSharing(recipe, context: modelContext)

// 3. Create Mom's version
let momVersion = RecipeVersion(
    creatorUserID: "user-mom",
    creatorDisplayName: "Mom",
    creationYear: "2015"
)
momVersion.title = recipe.title
momVersion.ingredients = recipe.ingredients?.map { $0.originalText } ?? []
momVersion.instructions = recipe.instructions

// Record a change
momVersion.recordChange(field: "ingredient-1", from: "2 cups butter", to: "2 cups olive oil")

recipe.versions?.append(momVersion)

// 4. Create Your version
let yourVersion = RecipeVersion(
    creatorUserID: "user-you",
    creatorDisplayName: "You",
    creationYear: "2025"
)
yourVersion.title = recipe.title
yourVersion.ingredients = momVersion.ingredients
yourVersion.instructions = recipe.instructions

// Record changes
yourVersion.recordChange(field: "title", from: recipe.title, to: "My \(recipe.title)")

recipe.versions?.append(yourVersion)

try modelContext.save()

print("Recipe now has \(recipe.versions?.count ?? 0) versions")
print("Has multiple versions: \(recipe.hasMultipleVersions)")
```

---

## Test 3: Version Selector in Cooking Mode

**Goal:** Verify version selector appears and switches versions

### Steps:
1. Open recipe with multiple versions
2. Tap "Start Cooking"
3. **Expected:** See version selector at top
4. Tap version selector
5. **Expected:** See list of versions (Original, Mom '15, You '25)
6. Select "Mom '15"
7. **Expected:** Instructions update to Mom's version
8. Navigate through steps
9. Complete cooking
10. **Expected:** Mom's version timesCooked increments

### Visual Checks:
- [ ] Version selector shows current version (e.g., "Mom '15")
- [ ] Expandable list shows all versions
- [ ] Selected version has checkmark
- [ ] Change counts shown per version
- [ ] Instructions change when switching
- [ ] Step count updates if versions have different instruction counts

---

## Test 4: Version Indicator in Detail View

**Goal:** Verify compact version selector in RecipeDetailView

### Steps:
1. Open recipe with multiple versions
2. **Expected:** See compact version badge near title (e.g., "Mom '15")
3. Tap the version badge
4. **Expected:** Dropdown menu with all versions
5. Select different version
6. **Expected:** Badge updates
7. Scroll to ingredients/instructions
8. **Expected:** Content reflects selected version (though we haven't built attribution badges yet)

### Visual Checks:
- [ ] Compact badge visible on recipes with multiple versions
- [ ] Badge shows active version
- [ ] Badge invisible on single-version recipes
- [ ] Dropdown menu works
- [ ] Selection persists

---

## Test 5: Sample Data Creation

**Fastest way to test: Use the Debug Menu Button ✅**

### Steps:
1. **Tap "Version Tests" button** at bottom of recipe list
2. **Tap "Create Multi-Version Recipe"**
3. **Expected:** Success message: "✅ Created 'Grandma's Lasagna' with 3 versions"
4. Close debug menu
5. Find "Grandma's Lasagna" in recipe list

### What Gets Created:

**Base Version (Grandma Kay • 1987):**
- Title: "Grandma's Lasagna"
- Ingredients: ground beef, lasagna noodles, ricotta
- 4 instructions

**Mom's Version (Mom • 2015):**
- Changed: beef → turkey
- Added notes: "I use turkey instead — healthier!"
- Times cooked: 5

**Your Version (You • 2025):**
- Changed title: "My Amazing Lasagna"
- Changed instruction: added garlic
- Added notes: "Added garlic for extra flavor"

### Code Reference (in DebugVersionTestView.swift):
The debug button uses the exact sample data pattern recommended for testing. See `DebugVersionTestView.swift:55-121` for implementation details.

---

## Test 6: Analytics Tracking

**Goal:** Verify cooking completion tracks version

### Steps:
1. Cook a recipe with version "Mom '15" selected
2. Complete all steps
3. Check analytics output (console logs)
4. **Expected:** Event includes `"version_used": "Mom"`

---

## Known Limitations (Not Yet Implemented)

These are **expected** to not work yet:

- ❌ Inline attribution badges on changed fields (Phase 3)
- ❌ CloudKit heirloom sharing toggle (Phase 4)
- ❌ Version-specific notes on card back (Phase 5)
- ❌ Automatic version creation on share acceptance (Phase 4)
- ❌ Change history tooltips (Phase 3)

---

## Bug Checklist

Watch for these potential issues:

- [ ] Crash when switching versions in cooking mode
- [ ] selectedVersionID not persisting
- [ ] Version selector not appearing when hasMultipleVersions is true
- [ ] Instructions not updating when version changes
- [ ] timesCooked incrementing on wrong version
- [ ] Circular reference warnings in console
- [ ] CloudKit sync conflicts with versions

---

## Success Criteria

### Phase 1 & 2 (Multi-Version Support):

✅ Recipes can have multiple versions
✅ Each version has attribution (creator, year)
✅ Users can select which version to cook
✅ Instructions render from selected version
✅ Version selector UI appears in cooking mode
✅ Version indicator appears in detail view
✅ Cooking completion increments correct version's timesCooked
✅ App doesn't crash
✅ Build succeeds
✅ Unit tests pass (34 tests)

### Multi-Recipe Selection Feature:

✅ **AI Detection:**
  - Can detect 0, 1, or multiple recipes from single image
  - Returns confidence score per recipe
  - Handles OCR text with multiple recipe sections

✅ **Photo Library Access:**
  - "Choose Photo" button visible in scanner toolbar
  - Can import from Photos app (not just camera)
  - Selected photo displays in preview

✅ **Smart Routing:**
  - 0 recipes → Error message
  - 1 recipe → OCRReviewView (no regression)
  - 2+ recipes → RecipeSelectionView

✅ **Selection UI:**
  - Shows all detected recipes in list
  - Displays confidence badges (High/Medium/Low)
  - Checkboxes for multi-select (all selected by default)
  - Expandable preview per recipe
  - "Select All / Deselect All" functionality
  - Import button disabled when 0 selected

✅ **Batch Import:**
  - Can import multiple selected recipes at once
  - All recipes save to SwiftData successfully
  - Success toast shows count imported
  - View dismisses after import

✅ **No Regressions:**
  - Single-recipe flow unchanged
  - Existing OCRReviewView still works
  - Camera capture still functional

---

## Next Steps After Testing

If tests pass:
1. Commit Phase 1 & 2 code
2. Update progress tracker
3. Begin Phase 3 (Attribution Badges) or
4. Begin Phase 4 (Sharing Permissions)

If bugs found:
1. Document in GitHub issues
2. Fix critical bugs
3. Re-test
4. Then proceed

---

## Quick Test Commands

```bash
# Run unit tests
cd /Users/matthanson/Heirloom
xcodebuild test -project Heirloom.xcodeproj -scheme Heirloom -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(Test Suite|passed|failed)"

# Build and run
xcodebuild -project Heirloom.xcodeproj -scheme Heirloom -destination 'platform=iOS Simulator,name=iPhone 16' build

# Launch simulator
open -a Simulator
```

---

## 📱 How to Access Debug Menu

The debug menu is only visible in **DEBUG builds** (not production).

### Location:
**Recipe List Screen** → Bottom toolbar → **"Version Tests" button** (hammer icon)

### Available Actions:
1. **"Create Multi-Version Recipe"** - Instantly creates test data (Test 5)
2. **"Run Migration"** - Migrates all existing recipes (Test 1)
3. **"Check Migration Stats"** - Shows migration status (Test 1)

---

**Ready to test! Use the Debug Menu button for quickest validation.**
