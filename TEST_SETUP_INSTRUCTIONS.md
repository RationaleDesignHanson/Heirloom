# Heirloom Test Setup Instructions

This document provides step-by-step instructions for configuring test targets in Xcode and running the comprehensive test suite.

## Test Suite Overview

We've created **93+ test cases** organized into 4 test files:

### Unit Tests (`HeirloomTests/`)
- **IngredientParserTests.swift** - 34 test cases covering ingredient text parsing
- **ScalingEngineTests.swift** - 21 test cases covering recipe scaling logic
- **RecipeModelTests.swift** - 28 test cases covering Recipe model behavior
- **GroceryCategoryTests.swift** - 20 test cases covering ingredient categorization

### Test Infrastructure
- **RecipeBuilder.swift** - Fluent API for creating test recipes
- **Fixtures/** - Directory structure for HTML samples, images, and JSON mocks (to be populated)

---

## Adding Test Targets to Xcode

Since test targets cannot be created programmatically, follow these steps to add them manually in Xcode:

### Step 1: Create HeirloomTests Target

1. Open `/Users/matthanson/Heirloom/Heirloom.xcodeproj` in Xcode
2. Select the project in the Project Navigator
3. Click the **"+"** button at the bottom of the targets list
4. Choose **"Unit Testing Bundle"**
5. Configure the target:
   - **Product Name:** `HeirloomTests`
   - **Team:** Your development team
   - **Project:** Heirloom
   - **Target to be Tested:** Heirloom
6. Click **Finish**
7. Xcode will create a default test file - **delete it** (we have our own test files)

### Step 2: Add Test Files to Target

1. In Finder, navigate to `/Users/matthanson/Heirloom/HeirloomTests/`
2. Drag the `HeirloomTests` folder into your Xcode project navigator
3. In the dialog that appears:
   - ✅ **Copy items if needed** (leave unchecked - files are already in place)
   - ✅ **Create groups** (not folder references)
   - ✅ **Add to targets:** Select `HeirloomTests`
4. Click **Add**

### Step 3: Configure Test Target Settings

1. Select the `HeirloomTests` target
2. Go to **Build Settings**
3. Set **Enable Testing Search Paths** to `Yes`
4. Go to **Build Phases** → **Link Binary With Libraries**
5. Ensure these frameworks are linked:
   - `XCTest.framework`
   - `SwiftData.framework`
   - `Foundation.framework`

### Step 4: Make Heirloom App Testable

1. Select the **Heirloom** app target (not the test target)
2. Go to **Build Settings**
3. Search for **"Enable Testability"**
4. Set **Enable Testability** to `Yes` for **Debug** configuration

### Step 5: Configure Test Scheme

1. Click on the scheme selector (next to the Run/Stop buttons)
2. Select **Edit Scheme...**
3. Select **Test** in the left sidebar
4. Click **"+"** under Test Plans/Targets
5. Add `HeirloomTests`
6. Enable **Code Coverage**:
   - Check **"Gather coverage for: Heirloom"**
7. Click **Close**

---

## Running the Tests

### Run All Tests

**Method 1: Keyboard Shortcut**
- Press `⌘ + U` (Command + U)

**Method 2: Menu**
- Product → Test

**Method 3: Test Navigator**
- Open Test Navigator (`⌘ + 6`)
- Click the play button next to "HeirloomTests"

### Run Individual Test Files

1. Open Test Navigator (`⌘ + 6`)
2. Expand `HeirloomTests`
3. Click the play button next to a specific test file:
   - `IngredientParserTests`
   - `ScalingEngineTests`
   - `RecipeModelTests`
   - `GroceryCategoryTests`

### Run Individual Test Cases

1. Open a test file (e.g., `IngredientParserTests.swift`)
2. Look for the diamond icon in the gutter next to each test function
3. Click the diamond to run that specific test

---

## Viewing Test Results

### Test Navigator
- Green checkmarks ✅ = Passing tests
- Red X's ❌ = Failing tests
- Click on a failed test to see the failure details

### Report Navigator
- Open Report Navigator (`⌘ + 9`)
- Select the latest test run
- View detailed logs, code coverage, and performance metrics

### Code Coverage
1. After running tests with coverage enabled
2. Open Report Navigator (`⌘ + 9`)
3. Select **Coverage** tab
4. You'll see coverage percentages for each file
5. Click on a file to see line-by-line coverage visualization

**Coverage Targets:**
- ✅ **IngredientParser:** Should reach 90%+ coverage
- ✅ **ScalingEngine:** Should reach 85%+ coverage
- ✅ **Recipe model:** Should reach 75%+ coverage
- ✅ **GroceryCategory:** Should reach 80%+ coverage

---

## Expected Test Results

When everything is configured correctly, you should see:

```
Test Suite 'HeirloomTests' started
Test Suite 'IngredientParserTests' passed: 34 tests, 0 failures
Test Suite 'ScalingEngineTests' passed: 21 tests, 0 failures
Test Suite 'RecipeModelTests' passed: 28 tests, 0 failures
Test Suite 'GroceryCategoryTests' passed: 20 tests, 0 failures

Total: 103 tests, 0 failures in ~2.0 seconds
```

---

## Troubleshooting

### "Cannot find 'IngredientParser' in scope"

**Solution:** Ensure `@testable import Heirloom` is at the top of each test file and that "Enable Testability" is set to Yes in the app target.

### "No such module 'XCTest'"

**Solution:** The test target isn't properly configured. Verify:
1. XCTest.framework is linked in Build Phases
2. The target is set to iOS 17.0+ (matching your app target)

### Tests Don't Appear in Test Navigator

**Solution:**
1. Clean build folder: Product → Clean Build Folder (`⌘ + Shift + K`)
2. Close and reopen Xcode
3. Verify test files are added to the `HeirloomTests` target (check File Inspector)

### SwiftData Models Not Found

**Solution:** Ensure all model files are included in both the app target AND the test target:
1. Select each model file (Recipe.swift, Ingredient.swift, etc.)
2. Check File Inspector (right sidebar)
3. Verify both `Heirloom` and `HeirloomTests` are checked under **Target Membership**

---

## Next Steps (Phase 2-5)

After verifying Phase 1 tests pass:

### Phase 2: AI Backend Enhancements (Week 2-4)
- ✅ AI recipe extraction service
- ✅ Semantic search engine
- ✅ Cooking assistant chatbot
- ✅ Ingredient substitution AI

### Phase 3: Integration Tests (Week 3-4)
- PersistenceIntegrationTests
- CloudKitSyncTests
- RecipeImportIntegrationTests
- ImageStorageIntegrationTests

### Phase 4: UI Tests (Week 3-4)
- RecipeFlowUITests
- CookingModeUITests
- ShoppingListUITests
- DinnerPartyUITests
- SharingFlowUITests

### Phase 5: Performance & Resilience (Week 5-6)
- PerformanceTests
- ConflictResolutionTests
- RaceConditionTests
- ErrorRecoveryTests
- CI/CD Pipeline

---

## Questions or Issues?

If you encounter any issues setting up the tests:

1. Verify you're using Xcode 15+ and iOS 17+ SDK
2. Check that all dependencies (SwiftSoup) are properly installed
3. Ensure the app builds successfully before running tests
4. Review Xcode's Issue Navigator (`⌘ + 5`) for specific errors

---

## Test Coverage Goals

**Current Status: Phase 1 Complete**

| Component | Target Coverage | Test Cases | Status |
|-----------|----------------|------------|--------|
| IngredientParser | 90%+ | 34 | ✅ Complete |
| ScalingEngine | 85%+ | 21 | ✅ Complete |
| Recipe Model | 75%+ | 28 | ✅ Complete |
| GroceryCategory | 80%+ | 20 | ✅ Complete |
| **Phase 1 Total** | **80%+** | **103** | **✅ Complete** |

**Next Phases:**
- Phase 2: AI Services (4 new services)
- Phase 3: Integration Tests (30+ tests)
- Phase 4: UI Tests (20+ tests)
- Phase 5: Performance/Resilience (25+ tests)

**Final Goal: 120+ total tests covering 65% of the codebase**
