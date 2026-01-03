# OCR Parity Test Setup Guide

## Overview

OCR Parity Tests validate that scanned analog recipes (from cards and cookbooks) achieve the same data quality as manually-entered or link-imported recipes.

**IMPORTANT: Tests use PRODUCTION services (no mocks!):**
- ✅ `EnhancedOCRService` - Production OCR (same as CookbookScannerView)
- ✅ `AIRecipeExtractor` - Production AI parsing (Anthropic Claude)
- ✅ `IngredientParser` - Production ingredient parsing
- ✅ `GroceryCategory.categorize()` - Production auto-categorization

**Test Files:**
- `OCRParityTests.swift` - Main test suite
- Test Images: `/Users/matthanson/Heirloom/AnalogRecipes/`

## Adding Test Images to Xcode

### Option 1: Drag and Drop (Recommended)

1. **Open Xcode project**
2. **Select HeirloomTests target** in Project Navigator
3. **Drag images** from Finder → Xcode
   - Source: `/Users/matthanson/Heirloom/AnalogRecipes/Cards/`
   - Source: `/Users/matthanson/Heirloom/AnalogRecipes/Cookbooks/`
4. **In the dialog that appears:**
   - ✅ Check "Copy items if needed"
   - ✅ Check "Add to targets: HeirloomTests" (NOT Heirloom main app)
   - ✅ Check "Create folder references" (keep folder structure)
5. **Click "Finish"**

### Option 2: Asset Catalog (Alternative)

1. Create `TestImages.xcassets` in HeirloomTests
2. Drag images into asset catalog
3. Update `loadTestImage()` to use Asset Catalog API

## Verifying Setup

Run this command to check if images are in test bundle:

```bash
# List all images in test bundle
find ~/Library/Developer/Xcode/DerivedData/Heirloom*/Build/Products/Debug*/HeirloomTests.xctest -name "*.jpg" -o -name "*.jpeg"
```

Or run a quick test:

```swift
func testSetup_ImagesAvailable() {
    let image = UIImage(named: "RecipeCard_01", in: Bundle(for: type(of: self)), compatibleWith: nil)
    XCTAssertNotNil(image, "RecipeCard_01 should be available in test bundle")
}
```

## Test Image Inventory

### Recipe Cards (12 total)
```
RecipeCard_01.jpg   - 53KB
RecipeCard_02.jpeg  - 104KB
RecipeCard_03.jpeg  - 823KB (high-res)
RecipeCard_04.jpeg  - 816KB (high-res)
RecipeCard_05.jpeg  - 171KB
RecipeCard_06.jpeg  - 98KB
RecipeCard_07.jpg   - 141KB
RecipeCard_08.jpg   - 121KB
RecipeCard_09.jpg   - 124KB
RecipeCard_10.jpg   - 131KB
RecipeCard_11.jpg   - 127KB
RecipeCard_12.jpg   - 155KB
```

### Cookbook Pages (11 total)
```
Cookbook_01.jpeg - 380KB
Cookbook_02.jpeg - 292KB
Cookbook_03.jpeg - 295KB
Cookbook_04.jpeg - 720KB (high-res)
Cookbook_05.jpeg - 208KB
Cookbook_06.jpeg - 292KB
Cookbook_07.jpg  - 629KB
Cookbook_08.jpg  - 827KB (high-res)
Cookbook_09.jpg  - 2MB (very high-res)
Cookbook_10.jpeg - 2.2MB (very high-res)
Cookbook_11.jpg  - 318KB
```

## Running Tests

### Run All OCR Tests
```bash
xcodebuild test -scheme Heirloom \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HeirloomTests/OCRParityTests
```

### Run Single Test
```bash
xcodebuild test -scheme Heirloom \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:HeirloomTests/OCRParityTests/testOCRParity_RecipeCard_01
```

### Run in Xcode
1. Open `OCRParityTests.swift`
2. Click diamond icon next to test method
3. View results in Test Navigator (Cmd+6)

## Expected Test Coverage

Each test validates:
- ✅ **OCR Extraction**: Can read text from image
- ✅ **AI Parsing**: ExtractedRecipe has title, ingredients, instructions
- ✅ **Recipe Model**: Complete Recipe object created
- ✅ **Ingredient Parsing**: Quantities, units, names extracted
- ✅ **Grocery Categories**: Auto-assigned based on ingredient names
- ✅ **Schema Completeness**: All required fields populated or defaulted

## Parity Metrics

**Minimum Quality Standards:**
- Title: Non-empty, meaningful (not "Untitled Recipe")
- Ingredients: ≥3 items
- Instructions: ≥2 steps
- Ingredient Parsing: ≥60% with quantities, ≥50% with units
- Categorization: ≥40% assigned specific categories (not "Other")

## Troubleshooting

### "Failed to load test image"
- Images not in test bundle → Re-add with "Copy items" checked
- Wrong target membership → Select image, check "Target Membership" in File Inspector

### "OCR should extract text from card" fails
- Vision framework not available on simulator → Use physical device
- Image quality too low → Use higher resolution source images

### AI API not configured
- Tests fall back to basic extraction (no AI)
- Set `AIConfiguration.shared.enableAIEnhancement = true` in setUp()
- Provide API key via environment variable

## Adding New Test Cases

```swift
func testOCRParity_RecipeCard_NewCard() async throws {
    // 1. Add image to test bundle (RecipeCard_13.jpg)
    // 2. Load image
    let image = try loadTestImage("RecipeCard_13")

    // 3. Extract
    let ocrText = try await performOCR(on: image)
    let extracted = try await extractor.extractRecipe(from: ocrText)
    let recipe = try createRecipe(from: extracted, withImage: image)

    // 4. Validate parity
    assertRecipeParity(recipe)
}
```

## Notes

- Tests use **in-memory SwiftData** (no persistence between tests)
- OCR uses **Vision framework** (iOS 13+)
- AI enhancement via **Anthropic API** (falls back to basic if unavailable)
- Tests are **async/await** (@MainActor)
- Each test is **independent** (fresh model context)

## Success Criteria

**Parity Achieved When:**
- All Recipe schema fields populated correctly
- Ingredient parsing matches manual entry quality (60%+ with quantities)
- Grocery categorization works (40%+ specific categories)
- No crashes or errors during full extraction pipeline
- Tests pass consistently (not flaky due to OCR variance)
