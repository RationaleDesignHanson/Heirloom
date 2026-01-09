# Test Roadmap - Collection Deletion & UI Improvements

**Created**: 2026-01-08
**Status**: In Progress
**Current Phase**: Manual Testing + Test Suite Fixes

---

## Option B: Fix Test Build Errors

### Overview
Old test suite (HeirloomTests) has ~35 build errors due to `quantity` property changing from `Double` to `Double?`. Need to unwrap optionals in test assertions.

### Files to Fix

#### 1. MultilingualRecipeImportTests.swift
**Location**: `/Users/matthanson/Heirloom/HeirloomTests/Integration/MultilingualRecipeImportTests.swift`
**Status**: ✅ FIXED
**Errors Fixed**: 3
**Pattern**: Changed `ingredient.quantity` to `ingredient.quantity ?? 0` in XCTAssertEqual

#### 2. MultilingualIngredientParsingTests.swift
**Location**: `/Users/matthanson/Heirloom/HeirloomTests/Services/MultilingualIngredientParsingTests.swift`
**Status**: ❌ TODO
**Estimated Errors**: ~35
**Pattern**: Same as above - unwrap optional quantities

**Fix Strategy**:
```swift
// BEFORE (fails)
XCTAssertEqual(qty, 2.0, accuracy: 0.01)

// AFTER (works)
XCTAssertEqual(qty ?? 0, 2.0, accuracy: 0.01)
```

**Search/Replace**:
1. Find: `XCTAssertEqual(qty,`
   Replace: `XCTAssertEqual(qty ?? 0,`

2. Find: `XCTAssertEqual(quantity,`
   Replace: `XCTAssertEqual(quantity ?? 0,`

3. Find: `XCTAssertEqual(ingredient.quantity,`
   Replace: `XCTAssertEqual(ingredient.quantity ?? 0,`

**Estimated Time**: 5-10 minutes

### Verification Steps
1. Fix all Double? errors in MultilingualIngredientParsingTests.swift
2. Run: `xcodebuild test -scheme Heirloom -destination 'platform=iOS Simulator,id=AC23B9C2-AC19-4BFD-AAA7-FAF284C29232' -only-testing:HeirloomTests`
3. Verify 0 build errors
4. Check test results (should pass)

---

## Option C: Write More Automated Tests

### Test Suite 1: CollectionDeletionTests.swift
**Location**: `/Users/matthanson/Heirloom/HeirloomTestsV2/Tests/CollectionDeletionTests.swift`
**Status**: ✅ COMPLETE
**Tests**: 12 tests written

**Coverage**:
- ✅ Delete collection only (keep recipes)
- ✅ Delete collection and recipes
- ✅ System collection protection
- ✅ Heritage collection allowed
- ✅ Multi-collection recipe handling
- ✅ Empty collection deletion
- ✅ Relationship integrity

**To Run**:
```bash
xcodebuild test -scheme Heirloom \
  -destination 'platform=iOS Simulator,id=AC23B9C2-AC19-4BFD-AAA7-FAF284C29232' \
  -only-testing:HeirloomTestsV2/CollectionDeletionTests
```

---

### Test Suite 2: SampleRecipeGenerationTests.swift
**Location**: `/Users/matthanson/Heirloom/HeirloomTestsV2/Tests/SampleRecipeGenerationTests.swift`
**Status**: ❌ TODO
**Estimated Time**: 30-45 minutes

#### Tests to Write:

1. **testSampleRecipe_HeritageGeneration_LoadsFromJSON**
   - Verify loads from `heritage-recipes.json`
   - Verify pool size = 100 recipes
   - Verify structure matches HeritageRecipeJSON model

2. **testSampleRecipe_HeritageGeneration_SelectsRandomly**
   - Generate 10 recipes
   - Verify variety (not always same recipe)
   - Verify all from heritage pool

3. **testSampleRecipe_NormalGeneration_LoadsFromLibrary**
   - Verify loads from `SampleRecipeLibrary.all`
   - Verify pool size = 12 recipes
   - Verify randomElement() behavior

4. **testSampleRecipe_DuplicateTitle_AutoNumbering**
   - Create recipe "Test Recipe"
   - Generate duplicate with same title
   - Verify creates "Test Recipe (2)"
   - Generate another duplicate
   - Verify creates "Test Recipe (3)"

5. **testSampleRecipe_AddedToCollection_RelationshipCreated**
   - Generate sample recipe for collection
   - Verify recipe.collections contains the collection
   - Verify collection.recipes contains the recipe
   - Verify bidirectional relationship

6. **testSampleRecipe_ImageDownload_SavesToStorage**
   - Mock URLSession
   - Generate sample recipe with image URL
   - Verify URLSession.data(from:) called
   - Verify imageFileName set on recipe
   - Verify ImageStorageService.saveImage called

7. **testSampleRecipe_HeritageProperties_SetCorrectly**
   - Generate heritage recipe
   - Verify sourceType = .heritage
   - Verify historicalContext set (if provided)
   - Verify sourceDate set (if provided)

8. **testSampleRecipe_Ingredients_ParsedAndInserted**
   - Generate sample recipe
   - Verify ingredients created
   - Verify IngredientParser.parse() called for each
   - Verify orderIndex set correctly
   - Verify recipe.ingredients relationship

9. **testSampleRecipe_EmptyPool_HandlesGracefully**
   - Mock empty JSON file
   - Attempt to generate heritage recipe
   - Verify doesn't crash
   - Verify returns early or shows error

10. **testSampleRecipe_NetworkError_ContinuesWithoutImage**
    - Mock URLSession to throw error
    - Generate sample recipe
    - Verify recipe still created
    - Verify imageFileName remains nil

**Code Structure**:
```swift
import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class SampleRecipeGenerationTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        // Setup in-memory container
    }

    override func tearDown() async throws {
        // Cleanup
    }

    // Tests here...
}
```

---

### Test Suite 3: RecipeCardLayoutTests.swift
**Location**: `/Users/matthanson/Heirloom/HeirloomTestsV2/Tests/RecipeCardLayoutTests.swift`
**Status**: ❌ TODO (Lower Priority)
**Estimated Time**: 20-30 minutes

#### Tests to Write:

1. **testRecipeCard_MetadataLine_ContainsSourceAndTimesCooked**
   - Create recipe with source and timesCooked > 0
   - Render card
   - Verify source text displayed
   - Verify flame icon and count displayed
   - Verify both on same line

2. **testRecipeCard_BulletSeparator_OnlyWhenTimesCooked**
   - Test 1: timesCooked = 0
     - Verify no bullet (•) displayed
   - Test 2: timesCooked > 0
     - Verify bullet appears between source and flame icon

3. **testRecipeCard_GenerationBadge_AlignedRight**
   - Create recipe with generation = 1
   - Verify badge appears
   - Verify positioned on right side
   - Verify on same line as source/times cooked

4. **testRecipeCard_HeightReduction_Measured**
   - Measure old layout height (before changes)
   - Measure new layout height (after changes)
   - Verify new height < old height
   - Verify reduction ~20-30 points

5. **testRecipeCard_AllElements_StillVisible**
   - Create recipe with all metadata
   - Render card
   - Verify title visible (2 lines max)
   - Verify source visible
   - Verify times cooked visible
   - Verify generation badge visible
   - Verify nothing clipped

**Note**: These are UI/snapshot tests and may require ViewInspector or snapshot testing framework.

---

### Test Suite 4: OnboardingFlowUITests.swift
**Location**: `/Users/matthanson/Heirloom/HeirloomUITests/OnboardingFlowUITests.swift`
**Status**: ❌ TODO (Lowest Priority)
**Type**: UI Tests (XCUITest)
**Estimated Time**: 45-60 minutes

#### Tests to Write:

1. **testOnboarding_Screen1_DisplaysCorrectly**
   - Launch app (fresh install state)
   - Verify Screen 1 appears
   - Verify hero image visible
   - Verify title text visible
   - Verify "Get Started" button visible

2. **testOnboarding_Screen1_GetStartedButton_NavigatesToScreen2**
   - Tap "Get Started"
   - Verify Screen 2 appears
   - Verify heritage collections visible

3. **testOnboarding_Screen2_ShowsHeritageCollections**
   - Navigate to Screen 2
   - Verify 4 heritage collections displayed
   - Verify 2x2 grid layout
   - Verify collection icons visible
   - Verify collection names visible

4. **testOnboarding_Screen2_TapCollection_NavigatesToDetail**
   - Navigate to Screen 2
   - Tap "Presidential Pantry" collection
   - Verify navigates to CollectionDetailView
   - Verify navigation title = "Presidential Pantry"
   - Verify recipes displayed (or empty state)

5. **testOnboarding_BackFromCollection_CompletesOnboarding**
   - Navigate to Screen 2
   - Tap collection to enter detail
   - Tap back button
   - Verify onboarding completes
   - Verify main app appears
   - Verify UserDefaults hasCompletedOnboarding = true

6. **testOnboarding_ExploreButton_CompletesOnboarding**
   - Navigate to Screen 2
   - Tap "Explore Collections" button
   - Verify onboarding completes
   - Verify main app appears

7. **testOnboarding_OnlyShownOnce**
   - Complete onboarding
   - Force quit app
   - Relaunch app
   - Verify onboarding does NOT show again
   - Verify main app appears immediately

8. **testOnboarding_ResetOnboarding_ShowsAgain**
   - Complete onboarding
   - Go to Settings
   - Scroll to "Reset Onboarding" button
   - Tap reset
   - Relaunch app
   - Verify onboarding shows again

**Code Structure**:
```swift
import XCTest

final class OnboardingFlowUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        // Reset to fresh state
        app.launchArguments = ["--uitesting", "--reset-onboarding"]
    }

    // Tests here...
}
```

---

## Test Execution Plan

### Phase 1: Fix Build Errors (5-10 min)
- [ ] Fix MultilingualIngredientParsingTests.swift
- [ ] Run HeirloomTests suite
- [ ] Verify all pass

### Phase 2: Run New Collection Tests (2-3 min)
- [ ] Run CollectionDeletionTests
- [ ] Verify all 12 tests pass
- [ ] Document any failures

### Phase 3: Write Sample Recipe Tests (30-45 min)
- [ ] Create SampleRecipeGenerationTests.swift
- [ ] Write all 10 tests
- [ ] Run and verify pass

### Phase 4: Manual Testing (15-20 min)
- [ ] Follow MANUAL_TEST_PLAN.md
- [ ] Test all 12 scenarios
- [ ] Document bugs found

### Phase 5: Write Layout Tests (Optional, 20-30 min)
- [ ] Create RecipeCardLayoutTests.swift
- [ ] Write 5 layout tests
- [ ] Run and verify pass

### Phase 6: Write UI Tests (Optional, 45-60 min)
- [ ] Create OnboardingFlowUITests.swift
- [ ] Write 8 UI tests
- [ ] Run on simulator

---

## Success Criteria

### Minimum (Ship-Ready):
- ✅ Manual test plan completed with 0 critical bugs
- ✅ CollectionDeletionTests all pass (12/12)
- ✅ Old test suite builds and runs (0 build errors)

### Ideal (Comprehensive):
- ✅ All above
- ✅ SampleRecipeGenerationTests all pass (10/10)
- ✅ RecipeCardLayoutTests all pass (5/5)

### Stretch (Full Coverage):
- ✅ All above
- ✅ OnboardingFlowUITests all pass (8/8)
- ✅ Test coverage >70% on new features

---

## Resources

- **Manual Test Plan**: `/Users/matthanson/Heirloom/MANUAL_TEST_PLAN.md`
- **Test Infrastructure**: `/Users/matthanson/Heirloom/HeirloomTestsV2/README.md`
- **New Tests**: `/Users/matthanson/Heirloom/HeirloomTestsV2/Tests/CollectionDeletionTests.swift`

---

## Quick Commands

### Run All Tests
```bash
xcodebuild test -scheme Heirloom \
  -destination 'platform=iOS Simulator,id=AC23B9C2-AC19-4BFD-AAA7-FAF284C29232'
```

### Run Only New Tests (HeirloomTestsV2)
```bash
xcodebuild test -scheme Heirloom \
  -destination 'platform=iOS Simulator,id=AC23B9C2-AC19-4BFD-AAA7-FAF284C29232' \
  -only-testing:HeirloomTestsV2
```

### Run Specific Test Class
```bash
xcodebuild test -scheme Heirloom \
  -destination 'platform=iOS Simulator,id=AC23B9C2-AC19-4BFD-AAA7-FAF284C29232' \
  -only-testing:HeirloomTestsV2/CollectionDeletionTests
```

### Run Single Test
```bash
xcodebuild test -scheme Heirloom \
  -destination 'platform=iOS Simulator,id=AC23B9C2-AC19-4BFD-AAA7-FAF284C29232' \
  -only-testing:HeirloomTestsV2/CollectionDeletionTests/testCollectionDeletion_OnlyCollection_KeepsRecipes
```

---

## Status Summary

| Task | Status | Priority | Time Est. |
|------|--------|----------|-----------|
| Fix MultilingualIngredientParsingTests | ❌ TODO | High | 5-10 min |
| Run CollectionDeletionTests | ✅ READY | High | 2 min |
| Manual Testing | ⏸️ WAITING | High | 15-20 min |
| Write SampleRecipeGenerationTests | ❌ TODO | Medium | 30-45 min |
| Write RecipeCardLayoutTests | ❌ TODO | Low | 20-30 min |
| Write OnboardingFlowUITests | ❌ TODO | Low | 45-60 min |

---

**Next Action**: Choose one:
1. Fix test build errors (unblock automated testing)
2. Start manual testing (validate features work)
3. Write sample recipe tests (test new feature)
