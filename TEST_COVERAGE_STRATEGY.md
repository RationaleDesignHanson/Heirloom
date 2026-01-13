# Test Coverage Strategy: Maximum Coverage, Maximum Signal

## Philosophy

**Not all lines of code are equal.** Strategic testing focuses on:
1. **High-risk code** (revenue, data integrity, user-facing flows)
2. **Complex logic** (conditionals, state machines, algorithms)
3. **Integration points** (network, database, external APIs)
4. **User-critical paths** (onboarding, core features, payments)

**Avoid testing**:
- Trivial getters/setters
- SwiftData auto-generated code
- SwiftUI view hierarchies (use UI tests sparingly)
- Third-party library internals
- Simple pass-through functions

## Current Coverage Gaps (Prioritized)

Based on current coverage, here's where to focus:

### High Priority (High Risk, Low Coverage)

| Feature | Current | Target | Gap | Risk | Effort |
|---------|---------|--------|-----|------|--------|
| **cloudSync** | 65% | 85% | +20% | HIGH | High |
| **shoppingLists** | 55% | 70% | +15% | MEDIUM | Low |
| **debugMenu** | 60% | 70% | +10% | LOW | Low |

### Medium Priority (Released but Below 80%)

| Feature | Current | Target | Gap | Risk | Effort |
|---------|---------|--------|-----|------|--------|
| **tags** | 75% | 80% | +5% | MEDIUM | Low |
| **scaling** | 70% | 80% | +10% | MEDIUM | Low |
| **heritageProvenance** | 70% | 80% | +10% | MEDIUM | Medium |

### Low Priority (Alpha/Development, Not User-Facing)

| Feature | Current | Target | Gap | Notes |
|---------|---------|--------|-----|-------|
| **discovery** | 30% | 40% | +10% | Alpha - OK for now |
| **cookbookScan** | 0% | 0% | 0% | Not implemented |
| **dinnerParty** | 0% | 0% | 0% | Not implemented |
| **stats** | 0% | 0% | 0% | Not implemented |

## Strategic Testing Patterns

### 1. Test Critical Paths, Not All Paths

**Bad** (low signal):
```swift
func test_recipe_titleGetter() {
    let recipe = Recipe(title: "Cookies")
    XCTAssertEqual(recipe.title, "Cookies") // Trivial
}

func test_recipe_titleSetter() {
    let recipe = Recipe(title: "Cookies")
    recipe.title = "Brownies"
    XCTAssertEqual(recipe.title, "Brownies") // Low value
}
```

**Good** (high signal):
```swift
func test_recipe_syncConflict_lastWriteWins() {
    // Given: Recipe edited locally and remotely
    let local = Recipe(title: "Cookies", modifiedAt: Date())
    let remote = Recipe(title: "Brownies", modifiedAt: Date().addingTimeInterval(100))

    // When: Sync conflict resolved
    let resolved = syncManager.resolveConflict(local: local, remote: remote)

    // Then: Remote wins (last write)
    XCTAssertEqual(resolved.title, "Brownies")
}
```

### 2. Focus on Edge Cases and Boundaries

**Bad** (obvious happy path):
```swift
func test_scaling_doubleRecipe() {
    // Given: Recipe with 2 cups flour
    let recipe = Recipe(...)
    recipe.ingredients = [Ingredient(name: "flour", quantity: 2.0, unit: "cups")]

    // When: Scale to 2x
    recipe.scale(factor: 2.0)

    // Then: Should have 4 cups
    XCTAssertEqual(recipe.ingredients[0].quantity, 4.0)
}
```

**Good** (edge cases that catch bugs):
```swift
func test_scaling_zeroFactor_preventsInvalidState() {
    // Edge case: Scale by 0
    let recipe = Recipe(...)
    recipe.scale(factor: 0.0)
    XCTAssertGreaterThan(recipe.ingredients[0].quantity, 0, "Should prevent zero quantities")
}

func test_scaling_negativeFactor_preventsInvalidState() {
    // Edge case: Negative scaling
    let recipe = Recipe(...)
    recipe.scale(factor: -1.0)
    XCTAssertGreaterThan(recipe.ingredients[0].quantity, 0, "Should prevent negative quantities")
}

func test_scaling_fractionalIngredients_roundsAppropriately() {
    // Boundary: 1/3 cup * 1.5 = 0.5 cups (should round to 1/2 cup)
    let recipe = Recipe(...)
    recipe.ingredients = [Ingredient(name: "sugar", quantity: 0.333, unit: "cups")]
    recipe.scale(factor: 1.5)
    XCTAssertEqual(recipe.ingredients[0].quantity, 0.5, accuracy: 0.01)
}
```

### 3. Integration Tests Over Unit Tests for Complex Flows

**Bad** (over-mocking):
```swift
func test_cloudSync_uploadRecipe() {
    let mockNetwork = MockNetworkService()
    let mockDatabase = MockDatabaseService()
    let mockAuth = MockAuthService()
    let sut = CloudSyncService(network: mockNetwork, database: mockDatabase, auth: mockAuth)

    // Test becomes a mock verification exercise
    sut.uploadRecipe(recipe)
    XCTAssertTrue(mockNetwork.uploadCalled)
    XCTAssertTrue(mockDatabase.saveCalled)
}
```

**Good** (integration test with real dependencies):
```swift
func test_cloudSync_uploadAndDownload_dataIntegrity() async throws {
    // Given: Real CloudKit container (test environment)
    let syncService = CloudSyncService(container: testContainer)
    let originalRecipe = Recipe(title: "Test Recipe", ingredients: [...])

    // When: Upload and download
    try await syncService.upload(originalRecipe)
    let downloadedRecipe = try await syncService.download(recipeId: originalRecipe.id)

    // Then: Data integrity maintained
    XCTAssertEqual(downloadedRecipe.title, originalRecipe.title)
    XCTAssertEqual(downloadedRecipe.ingredients.count, originalRecipe.ingredients.count)
    XCTAssertEqual(downloadedRecipe.instructions, originalRecipe.instructions)
}
```

### 4. State Machine Testing (Exhaustive)

For complex state machines (like PaywallManager), test **all state transitions**:

```swift
// State machine: none → dismissed1 → dismissed2 → dismissed3 → hardWall
func test_paywallStateMachine_allTransitions() {
    // State 0: none
    XCTAssertEqual(sut.dismissCount, 0)
    XCTAssertFalse(sut.isHardWallEnabled)

    // State 1: dismissed1
    sut.dismiss()
    XCTAssertEqual(sut.dismissCount, 1)
    XCTAssertFalse(sut.isHardWallEnabled)

    // State 2: dismissed2
    sut.dismiss()
    XCTAssertEqual(sut.dismissCount, 2)
    XCTAssertFalse(sut.isHardWallEnabled)

    // State 3: dismissed3 (threshold reached)
    sut.dismiss()
    XCTAssertEqual(sut.dismissCount, 3)
    XCTAssertTrue(sut.isHardWallEnabled, "Hard wall should enable after 3 dismissals")

    // Verify hard wall persists
    sut.dismiss()
    XCTAssertTrue(sut.isHardWallEnabled, "Hard wall should stay enabled")
}
```

### 5. Property-Based Testing for Algorithms

For complex algorithms (like recipe scaling, ingredient parsing), use property-based testing:

```swift
func test_scaling_identityProperty() {
    // Property: scale(x, 1.0) = x (identity)
    let recipe = Recipe(...)
    let original = recipe.ingredients[0].quantity

    recipe.scale(factor: 1.0)

    XCTAssertEqual(recipe.ingredients[0].quantity, original, accuracy: 0.01)
}

func test_scaling_compositionProperty() {
    // Property: scale(scale(x, a), b) = scale(x, a*b)
    let recipe1 = Recipe(...)
    let recipe2 = Recipe(...)

    recipe1.scale(factor: 2.0)
    recipe1.scale(factor: 3.0)

    recipe2.scale(factor: 6.0)

    XCTAssertEqual(recipe1.ingredients[0].quantity, recipe2.ingredients[0].quantity, accuracy: 0.01)
}
```

## Coverage Improvement Plan (High Signal)

### Phase A: CloudSync (65% → 85%)

**Focus Areas**:
1. **Conflict resolution** (high risk, complex logic)
2. **Network failure recovery** (retry logic, exponential backoff)
3. **Data integrity** (upload/download round-trip)
4. **Concurrent syncs** (race conditions)

**Tests to Add** (15-20 tests):
```swift
// Conflict Resolution
test_sync_conflictResolution_localWins()
test_sync_conflictResolution_remoteWins()
test_sync_conflictResolution_lastWriteWins()
test_sync_conflictResolution_mergeStrategy()

// Network Failures
test_sync_networkTimeout_retriesWithExponentialBackoff()
test_sync_networkError_queuesForRetry()
test_sync_partialUpload_rollsBackTransaction()
test_sync_connectionLost_resumesOnReconnect()

// Data Integrity
test_sync_uploadDownloadRoundTrip_preservesAllFields()
test_sync_largeRecipe_chunkedUpload()
test_sync_specialCharacters_encodedCorrectly()
test_sync_recipeWithImages_uploadsAllAssets()

// Concurrency
test_sync_simultaneousUploads_noDuplicates()
test_sync_uploadDuringDownload_queuesCorrectly()
test_sync_deleteWhileSyncing_handledGracefully()
```

**Estimated Effort**: 8-10 hours
**Impact**: +20% coverage, catches sync bugs (high value)

### Phase B: ShoppingLists (55% → 70%)

**Focus Areas**:
1. **Ingredient aggregation** (combining quantities)
2. **Unit conversion** (cups to tablespoons, etc.)
3. **Duplicate detection** (same ingredient, different recipes)

**Tests to Add** (10-12 tests):
```swift
// Aggregation
test_shoppingList_aggregatesSameIngredient()
test_shoppingList_preservesDifferentUnits()
test_shoppingList_combinesMultipleRecipes()

// Unit Conversion
test_shoppingList_convertsCupsToTablespoons()
test_shoppingList_convertsGramsToOunces()
test_shoppingList_preservesUnconvertibleUnits()

// Deduplication
test_shoppingList_deduplicatesExactMatches()
test_shoppingList_detectsSimilarIngredients()
test_shoppingList_handlesPluralization()
```

**Estimated Effort**: 4-5 hours
**Impact**: +15% coverage, improves shopping list reliability

### Phase C: Tags, Scaling, Provenance (70-75% → 80%)

**Focus Areas**:
1. **Tags**: Tag filtering, hierarchical tags, tag suggestions
2. **Scaling**: Fractional ingredients, unit conversions, rounding
3. **Provenance**: Lineage tracking, generation counting, attribution

**Tests to Add** (15-18 tests):
```swift
// Tags
test_tags_filterByMultipleTags_AND()
test_tags_filterByMultipleTags_OR()
test_tags_hierarchicalTags_inheritParent()
test_tags_suggestTags_basedOnIngredients()

// Scaling
test_scaling_fractionalCup_roundsToNearestCommonFraction()
test_scaling_convertsBetweenUnits_whenAppropriate()
test_scaling_preservesRatios()

// Provenance
test_provenance_tracksMultipleGenerations()
test_provenance_preservesAttribution()
test_provenance_detectsCircularLineage()
```

**Estimated Effort**: 6-8 hours
**Impact**: +5-10% coverage each, solidifies core features

## Tools for Finding Untested Code

### 1. Xcode Coverage Report

```bash
# Run tests with coverage
xcodebuild test -scheme Heirloom -enableCodeCoverage YES -resultBundlePath TestResults

# View coverage
xcrun xccov view --report --json TestResults.xcresult > coverage.json

# Open in Xcode
open TestResults.xcresult
```

In Xcode:
1. Open TestResults.xcresult
2. Go to Coverage tab
3. Sort by "Coverage" (ascending) to see lowest coverage files
4. Click file to see **red highlights** on untested lines

### 2. Coverage-Guided Testing

Use `llvm-cov` to find untested branches:

```bash
# Generate detailed coverage
xcrun llvm-cov show ./build/Heirloom.app/Heirloom \
  -instr-profile=./build/Coverage.profdata \
  -format=html \
  -output-dir=coverage-html

# Open in browser
open coverage-html/index.html
```

Look for:
- **Red lines**: Never executed
- **Yellow lines**: Partially covered (some branches not tested)
- **Branch coverage**: if/else, switch, guard

### 3. Mutation Testing (Advanced)

Use mutation testing to verify tests catch bugs:

```bash
# Install Muter
brew install muter

# Run mutation testing
muter run
```

Muter changes your code (mutations) and runs tests. If tests still pass, the test isn't catching bugs.

**Example**:
```swift
// Original code
if count > 0 { return true }

// Mutation: Change > to >=
if count >= 0 { return true }

// If tests still pass, you need a test for count=0
```

## What NOT to Test (Avoid Coverage Inflation)

### 1. SwiftData Models (Auto-Generated)

**Don't test**:
```swift
@Model
class Recipe {
    var title: String
    var instructions: [String]
}

// ❌ Don't write this test
func test_recipe_titleProperty() {
    let recipe = Recipe(title: "Cookies")
    XCTAssertEqual(recipe.title, "Cookies")
}
```

### 2. SwiftUI View Hierarchies

**Don't test**:
```swift
// ❌ Don't unit test SwiftUI views
func test_recipeView_hasTitle() {
    let view = RecipeView(recipe: testRecipe)
    // Testing view structure is brittle and low value
}
```

**Do test** (ViewModels):
```swift
// ✅ Test view logic in ViewModels
func test_recipeViewModel_loadsRecipe() async {
    let viewModel = RecipeViewModel(recipeId: "123")
    await viewModel.load()
    XCTAssertEqual(viewModel.recipe.title, "Expected Title")
}
```

### 3. Third-Party Library Internals

**Don't test**:
```swift
// ❌ Don't test Firebase behavior
func test_firestore_savesDocument() {
    Firestore.firestore().collection("recipes").document().setData([...])
    // Firebase's responsibility
}
```

**Do test** (Your integration):
```swift
// ✅ Test your service that uses Firebase
func test_recipeService_savesToFirebase() async throws {
    let service = FirebaseRecipeService()
    try await service.save(recipe)
    let fetched = try await service.fetch(recipeId: recipe.id)
    XCTAssertEqual(fetched.title, recipe.title)
}
```

### 4. Simple Pass-Through Functions

**Don't test**:
```swift
// ❌ Pass-through with no logic
func saveRecipe(_ recipe: Recipe) {
    repository.save(recipe) // No logic to test
}
```

**Do test** (If it adds logic):
```swift
// ✅ Has validation logic worth testing
func saveRecipe(_ recipe: Recipe) throws {
    guard !recipe.title.isEmpty else {
        throw ValidationError.emptyTitle
    }
    repository.save(recipe)
}

func test_saveRecipe_rejectsEmptyTitle() {
    XCTAssertThrowsError(try sut.saveRecipe(emptyRecipe))
}
```

## Test Quality Metrics

Beyond line coverage, track:

### 1. Mutation Score

Percentage of mutations caught by tests.
- **Target**: 70%+ for critical code
- **Tool**: Muter

### 2. Test Execution Time

Fast tests = run frequently = catch bugs early.
- **Target**: < 10 seconds for unit tests
- **Target**: < 2 minutes for full suite

### 3. Flakiness Rate

Percentage of tests that fail intermittently.
- **Target**: < 1% flakiness
- **Action**: Fix or disable flaky tests immediately

### 4. Code Coverage Per Feature

Track coverage by feature, not just overall:
```bash
./scripts/feature-tool.sh coverage
```

## Prioritization Framework

When deciding what to test next:

```
Priority = (Risk × Complexity × Usage) / Test Effort

Risk: 1-10 (10 = revenue/data loss)
Complexity: 1-10 (10 = state machine/async)
Usage: 1-10 (10 = every user, every session)
Test Effort: 1-10 (10 = requires extensive mocking)
```

**Examples**:

| Code | Risk | Complexity | Usage | Effort | Priority | Test? |
|------|------|------------|-------|--------|----------|-------|
| Subscription trial logic | 10 | 8 | 10 | 3 | 267 | ✅ YES |
| CloudSync conflict resolution | 9 | 9 | 8 | 5 | 130 | ✅ YES |
| Recipe title getter | 1 | 1 | 10 | 1 | 10 | ❌ NO |
| Debug menu toggle | 1 | 2 | 1 | 2 | 1 | ❌ NO |

## Action Plan Summary

### Immediate (Next 20 hours)

1. **CloudSync**: +20% coverage (8-10 hours)
   - Focus: Conflict resolution, network failures, data integrity
   - High risk, high value

2. **ShoppingLists**: +15% coverage (4-5 hours)
   - Focus: Aggregation, unit conversion, deduplication
   - Medium risk, medium value

3. **Tags/Scaling/Provenance**: +10% coverage each (6-8 hours)
   - Focus: Edge cases, boundary conditions
   - Medium risk, medium value

**Total Effort**: 18-23 hours
**Coverage Gain**: 35-45 percentage points (specific files)
**Overall Coverage**: 68% → ~75%

### Long-Term (Next 3 months)

1. **Enable Mutation Testing**: Validate test quality
2. **Add Performance Tests**: Track regression
3. **Integration Test Suite**: End-to-end user flows
4. **UI Test Automation**: Critical user paths only (5-10 tests)

## Success Metrics

You've achieved high-signal coverage when:

- ✅ All critical paths have 100% coverage
- ✅ Integration tests cover major user flows
- ✅ Mutation score > 70% on critical code
- ✅ Zero flaky tests
- ✅ Test suite runs in < 2 minutes
- ✅ Every test catches a real bug (not just exercising code)

## Conclusion

**Maximum coverage ≠ Maximum lines covered**

Maximum coverage = **Maximum bug detection per test effort**

Focus on:
1. Critical paths (revenue, data, user-facing)
2. Complex logic (state machines, algorithms)
3. Integration points (network, database, external APIs)
4. Edge cases and boundaries

Avoid:
1. Trivial getters/setters
2. Auto-generated code
3. View hierarchies (use UI tests sparingly)
4. Third-party internals
5. Pass-through functions

By following this strategy, you'll achieve 75-80% overall coverage with **every test pulling its weight**.
