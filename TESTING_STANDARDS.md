# Heirloom Testing Standards & Best Practices
**Version**: 1.0
**Created**: January 6, 2026
**Status**: Living Document

---

## Purpose

This document establishes testing standards, conventions, and best practices for the Heirloom iOS app test suite. All test code must follow these guidelines to ensure consistency, maintainability, and reliability.

---

## Table of Contents

1. [Test Naming Conventions](#test-naming-conventions)
2. [Test Organization](#test-organization)
3. [Test Structure](#test-structure)
4. [Mocking Strategy](#mocking-strategy)
5. [Async Testing](#async-testing)
6. [Assertions](#assertions)
7. [Test Data & Fixtures](#test-data--fixtures)
8. [Performance Testing](#performance-testing)
9. [Code Style](#code-style)
10. [Common Patterns](#common-patterns)

---

## Test Naming Conventions

### Test Class Names
Format: `[FeatureName][Type]Tests`

```swift
// Unit tests
class RecipeScalingEngineTests: XCTestCase { }
class IngredientParserTests: XCTestCase { }
class UnitConversionServiceTests: XCTestCase { }

// Integration tests
class RecipeImportFlowTests: XCTestCase { }
class RecipeSharingFlowTests: XCTestCase { }

// UI tests
class RecipeListUITests: XCTestCase { }
class RecipeEditorUITests: XCTestCase { }

// Performance tests
class RecipeImportPerformanceTests: XCTestCase { }
```

### Test Method Names
Format: `test[FeatureName]_[Scenario]_[ExpectedResult]`

Use descriptive, readable names that explain:
1. What feature is being tested
2. What scenario or condition
3. What the expected outcome is

```swift
// ✅ GOOD: Clear, descriptive, follows pattern
func testRecipeImport_ValidURL_ReturnsRecipe() { }
func testRecipeImport_InvalidURL_ThrowsError() { }
func testLanguageDetection_FrenchRecipe_DetectsFrench() { }
func testUnitConversion_JapaneseCup_ConvertsToUSCup() { }
func testRecipeScaling_Double_ScalesAllIngredients() { }
func testRecipeScaling_Halve_RoundsToCommonFractions() { }

// ❌ BAD: Too vague, unclear expected behavior
func testImport() { }
func testConversion() { }
func testScaling() { }
```

### Test Groups (MARK Comments)
Use `// MARK:` to organize related tests:

```swift
class RecipeScalingEngineTests: XCTestCase {
    // MARK: - Basic Scaling
    func testBasicScaling_Double_AllIngredientsDoubled() { }
    func testBasicScaling_Halve_AllIngredientsHalved() { }

    // MARK: - Non-Linear Scaling
    func testNonLinearScaling_Spices_LogarithmicScaling() { }
    func testNonLinearScaling_Leavening_SquareRootScaling() { }

    // MARK: - Edge Cases
    func testEdgeCase_ZeroServings_ThrowsError() { }
    func testEdgeCase_ExtremeScaling_HandledGracefully() { }
}
```

---

## Test Organization

### Directory Structure

```
HeirloomTestsV2/
├── TestInfrastructure/
│   ├── Mocks/                     # Mock implementations
│   │   ├── Firebase/
│   │   │   ├── MockFirebaseAuth.swift
│   │   │   ├── MockFirestore.swift
│   │   │   └── MockStorage.swift
│   │   ├── AI/
│   │   │   └── MockClaudeAPI.swift
│   │   └── Network/
│   │       └── MockURLSession.swift
│   │
│   ├── Fixtures/                  # Test data
│   │   ├── RecipeFixtures.swift
│   │   ├── IngredientFixtures.swift
│   │   └── ImportResponseFixtures.swift
│   │
│   ├── Helpers/                   # Test utilities
│   │   ├── TestEnvironment.swift
│   │   ├── AsyncTestHelpers.swift
│   │   └── AssertionHelpers.swift
│   │
│   └── Extensions/                # Test extensions
│       └── XCTestCase+Extensions.swift
│
├── Unit/                          # Unit tests (isolated)
│   ├── Services/
│   ├── Models/
│   └── Utils/
│
├── Integration/                   # Integration tests
│   ├── RecipeImportFlowTests.swift
│   ├── RecipeSharingFlowTests.swift
│   └── MultiDeviceSyncTests.swift
│
├── Regression/                    # Regression tests
│   ├── EnglishImportRegressionTests.swift
│   └── RecipeScalingRegressionTests.swift
│
└── Performance/                   # Performance tests
    └── RecipeImportPerformanceTests.swift
```

### File Organization Rules

1. **One test class per file**: Each file should contain exactly one test class
2. **Related tests together**: Group tests for the same feature in the same directory
3. **Shared utilities**: Common test utilities go in `TestInfrastructure/`
4. **No production code**: Test targets should never import production code files directly (use module imports)

---

## Test Structure

### Standard Test Structure

Every test should follow this structure:

```swift
func testFeatureName_Scenario_ExpectedResult() {
    // GIVEN: Setup - Arrange test data and dependencies
    let mockService = MockClaudeAPI()
    mockService.mockLanguageResponse = .french
    let importService = CloudRecipeImportService(claude: mockService)

    // WHEN: Action - Execute the code being tested
    let result = try await importService.detectLanguage("Tarte aux pommes")

    // THEN: Assertion - Verify expected behavior
    XCTAssertEqual(result.language, "fr")
    XCTAssertGreaterThan(result.confidence, 0.9)
}
```

### Test Lifecycle Methods

```swift
class RecipeScalingEngineTests: XCTestCase {
    // MARK: - Properties
    var sut: ScalingEngine!  // System Under Test
    var mockService: MockService!

    // MARK: - Setup & Teardown

    /// Runs once before all tests in this class
    override class func setUp() {
        super.setUp()
        // Class-level setup (rare)
    }

    /// Runs before EACH test
    override func setUp() {
        super.setUp()
        // Create fresh instances for each test
        mockService = MockService()
        sut = ScalingEngine(service: mockService)
    }

    /// Runs after EACH test
    override func tearDown() {
        // Clean up resources
        sut = nil
        mockService = nil
        super.tearDown()
    }

    /// Runs once after all tests in this class
    override class func tearDown() {
        // Class-level cleanup (rare)
        super.tearDown()
    }
}
```

### Test Isolation

**CRITICAL**: Each test must be independent and isolated.

```swift
// ✅ GOOD: Test creates its own data
func testRecipeCreation_ValidData_Success() {
    let recipe = RecipeFactory.create(title: "Test Recipe")
    XCTAssertEqual(recipe.title, "Test Recipe")
}

// ❌ BAD: Test depends on shared state
class RecipeTests: XCTestCase {
    var sharedRecipe: Recipe!  // ❌ Shared mutable state

    func testUpdateTitle() {
        sharedRecipe.title = "New Title"  // ❌ Affects other tests
    }
}
```

---

## Mocking Strategy

### Mock Protocols

All mocks must implement tracking and behavior configuration:

```swift
/// Base protocol for all mocks
protocol MockTracking {
    var callLog: [String] { get set }
    func recordCall(_ functionName: String)
}

extension MockTracking {
    func recordCall(_ functionName: String) {
        callLog.append(functionName)
    }
}
```

### Mock Implementation Pattern

```swift
class MockClaudeAPI: ClaudeAPIProtocol, MockTracking {
    // MARK: - MockTracking
    var callLog: [String] = []

    // MARK: - Configurable Responses
    var mockLanguageResponse: LanguageDetectionResponse?
    var mockTranslationResponse: String?

    // MARK: - Error Injection
    var shouldFailDetection = false
    var shouldFailTranslation = false
    var detectionError: Error?

    // MARK: - ClaudeAPIProtocol

    func detectLanguage(_ text: String, url: String?, domain: String?) async throws -> LanguageDetectionResponse {
        recordCall("detectLanguage")

        if shouldFailDetection {
            throw detectionError ?? ClaudeAPIError.detectionFailed
        }

        return mockLanguageResponse ?? LanguageDetectionResponse(
            language: "en",
            confidence: 1.0,
            languageName: "English",
            detectedUnitSystem: "imperial",
            needsTranslation: false
        )
    }

    func translateText(_ text: String, from: String, to: String) async throws -> String {
        recordCall("translateText")

        if shouldFailTranslation {
            throw ClaudeAPIError.translationFailed
        }

        return mockTranslationResponse ?? text
    }
}
```

### Using Mocks in Tests

```swift
func testLanguageDetection_French_Success() async throws {
    // GIVEN: Mock configured for French response
    let mockClaude = MockClaudeAPI()
    mockClaude.mockLanguageResponse = LanguageDetectionResponse(
        language: "fr",
        confidence: 0.95,
        languageName: "French",
        detectedUnitSystem: "metric",
        needsTranslation: true
    )

    let service = LanguageDetectionService(claude: mockClaude)

    // WHEN: Detect language
    let result = try await service.detectLanguage(text: "Tarte aux pommes", url: nil, domain: "marmiton.org")

    // THEN: Assert French detected
    XCTAssertEqual(result.language, "fr")
    XCTAssertEqual(result.confidence, 0.95)
    XCTAssertTrue(result.needsTranslation)

    // THEN: Assert mock was called correctly
    XCTAssertTrue(mockClaude.callLog.contains("detectLanguage"))
    XCTAssertEqual(mockClaude.callLog.count, 1, "Should call detectLanguage exactly once")
}
```

---

## Async Testing

### Async/Await Pattern

Use Swift's native async/await for all async tests:

```swift
// ✅ GOOD: Native async/await
func testRecipeImport_ValidURL_Success() async throws {
    let recipe = try await importService.importRecipe(from: url)
    XCTAssertEqual(recipe.title, "Expected Title")
}

// ❌ BAD: Completion handlers (outdated)
func testRecipeImport_ValidURL_Success() {
    let expectation = XCTestExpectation(description: "Import completes")
    importService.importRecipe(from: url) { result in
        XCTAssertEqual(result.title, "Expected Title")
        expectation.fulfill()
    }
    wait(for: [expectation], timeout: 5.0)
}
```

### Testing Async Sequences

```swift
func testSync_MultipleUpdates_ReceivesAll() async throws {
    let updates = syncService.updates

    var receivedUpdates: [Update] = []

    Task {
        for try await update in updates {
            receivedUpdates.append(update)
            if receivedUpdates.count == 3 { break }
        }
    }

    // Trigger updates
    try await syncService.syncRecipe(recipe1)
    try await syncService.syncRecipe(recipe2)
    try await syncService.syncRecipe(recipe3)

    // Wait for updates
    try await Task.sleep(nanoseconds: 100_000_000)  // 0.1s

    XCTAssertEqual(receivedUpdates.count, 3)
}
```

### Testing Concurrent Operations

```swift
func testConcurrentImports_NoDataRaces() async throws {
    // Start multiple imports concurrently
    async let recipe1 = importService.importRecipe(from: url1)
    async let recipe2 = importService.importRecipe(from: url2)
    async let recipe3 = importService.importRecipe(from: url3)

    // Wait for all to complete
    let recipes = try await [recipe1, recipe2, recipe3]

    XCTAssertEqual(recipes.count, 3)
    XCTAssertEqual(Set(recipes.map(\.id)).count, 3, "All recipes should have unique IDs")
}
```

---

## Assertions

### Standard Assertions

```swift
// Equality
XCTAssertEqual(actual, expected, "Optional failure message")
XCTAssertNotEqual(actual, unexpected)

// Boolean
XCTAssertTrue(condition)
XCTAssertFalse(condition)

// Nil checks
XCTAssertNil(optionalValue)
XCTAssertNotNil(optionalValue)

// Numeric comparisons
XCTAssertGreaterThan(value, 0)
XCTAssertLessThan(value, 100)
XCTAssertGreaterThanOrEqual(value, 0)

// Floating point (with accuracy)
XCTAssertEqual(actual, expected, accuracy: 0.001)
```

### Error Assertions

```swift
// Assert throws
XCTAssertThrowsError(try throwingFunction()) { error in
    XCTAssertTrue(error is ImportError)
    XCTAssertEqual((error as? ImportError)?.code, .invalidURL)
}

// Assert no throw
XCTAssertNoThrow(try validFunction())

// Async throws
await XCTAssertThrowsError(try await asyncThrowingFunction())
```

### Custom Assertions

Create custom assertions for complex validations:

```swift
// In AssertionHelpers.swift
func XCTAssertRecipeEqual(
    _ actual: Recipe,
    _ expected: Recipe,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual(actual.id, expected.id, "Recipe IDs don't match", file: file, line: line)
    XCTAssertEqual(actual.title, expected.title, "Recipe titles don't match", file: file, line: line)
    XCTAssertEqual(actual.ingredients.count, expected.ingredients.count, "Ingredient counts don't match", file: file, line: line)
}

// Usage
XCTAssertRecipeEqual(actualRecipe, expectedRecipe)
```

---

## Test Data & Fixtures

### Factory Functions

Use factory functions to create test data:

```swift
// In RecipeFixtures.swift
enum RecipeFactory {
    static func create(
        id: UUID = UUID(),
        title: String = "Test Recipe",
        servings: Int = 4,
        ingredients: [Ingredient] = [],
        sourceLanguage: String? = nil
    ) -> Recipe {
        return Recipe(
            id: id,
            title: title,
            servings: "\(servings)",
            ingredients: ingredients.isEmpty ? [IngredientFactory.create()] : ingredients,
            instructions: ["Step 1", "Step 2"],
            dateAdded: Date(),
            lastModified: Date(),
            sourceLanguage: sourceLanguage
        )
    }

    static func createFrench(title: String = "Tarte aux pommes") -> Recipe {
        return create(
            title: title,
            sourceLanguage: "fr",
            ingredients: [
                IngredientFactory.createFrench(name: "pommes", quantity: 4),
                IngredientFactory.createFrench(name: "sucre", quantity: 100, unit: "g")
            ]
        )
    }
}
```

### Fixture Constants

Define reusable fixture data:

```swift
// In IngredientFixtures.swift
enum IngredientFixtures {
    static let commonEnglish: [String] = [
        "2 cups flour",
        "1 tbsp butter",
        "3 tsp salt",
        "500 g sugar",
        "2 lbs beef"
    ]

    static let commonFrench: [String] = [
        "2 tasses de farine",
        "1 cuillère à soupe de beurre",
        "3 cuillères à café de sel",
        "500 g de sucre"
    ]

    static let commonJapanese: [String] = [
        "2カップの小麦粉",
        "大さじ1のバター",
        "小さじ3の塩",
        "500gの砂糖"
    ]
}
```

### Using Fixtures

```swift
func testIngredientParsing_EnglishRecipes_ParsesCorrectly() {
    for ingredientText in IngredientFixtures.commonEnglish {
        let result = IngredientParser.parse(ingredientText, language: "en")
        XCTAssertNotNil(result.quantity, "Failed to parse: \(ingredientText)")
        XCTAssertNotNil(result.unit, "Failed to parse unit: \(ingredientText)")
        XCTAssertNotNil(result.name, "Failed to parse name: \(ingredientText)")
    }
}
```

---

## Performance Testing

### Measure Performance

```swift
func testRecipeImport_Performance() throws {
    let url = URL(string: "https://example.com/recipe")!

    measure {
        // This block will be executed 10 times
        _ = try? importService.importRecipe(from: url)
    }
}
```

### Performance Metrics

```swift
let metrics: [XCTMetric] = [
    XCTClockMetric(),           // Time
    XCTMemoryMetric(),          // Memory usage
    XCTCPUMetric(),             // CPU usage
    XCTStorageMetric()          // Disk I/O
]

let options = XCTMeasureOptions()
options.iterationCount = 10

measure(metrics: metrics, options: options) {
    // Code to measure
}
```

### Performance Assertions

```swift
func testIngredientParsing_30Ingredients_Under100ms() throws {
    let ingredients = (0..<30).map { _ in IngredientFactory.create() }

    let start = Date()
    for ingredient in ingredients {
        _ = IngredientParser.parse(ingredient.description)
    }
    let elapsed = Date().timeIntervalSince(start)

    XCTAssertLessThan(elapsed, 0.1, "Parsing 30 ingredients should take less than 100ms")
}
```

---

## Code Style

### Swift Style

Follow Swift API Design Guidelines:

```swift
// ✅ GOOD: Clear, descriptive, Swift-style naming
func testRecipeScaling_DoubleServings_AllIngredientsDoubled() async throws {
    let recipe = RecipeFactory.create(servings: 4)
    let scaled = try await scalingEngine.scale(recipe, to: 8)
    XCTAssertEqual(scaled.ingredients.count, recipe.ingredients.count)
}

// ❌ BAD: Abbreviated, unclear
func testScale() {
    let r = mkRecipe()
    let s = scale(r, 8)
    XCTAssert(s.ing.count == r.ing.count)
}
```

### Comments

```swift
// Use comments to explain WHY, not WHAT

// ✅ GOOD: Explains reasoning
// Korean cups are 200ml, US cups are 237ml
// so 1 Korean cup = 0.844 US cups
XCTAssertEqual(converted, 0.844, accuracy: 0.001)

// ❌ BAD: States the obvious
// Assert that converted equals 0.844
XCTAssertEqual(converted, 0.844, accuracy: 0.001)
```

### Test Categories (Tags)

Use test categories for filtering (Xcode 16+):

```swift
@Tag("unit")
@Tag("multilingual")
final class UnitConversionServiceTests: XCTestCase { }

@Tag("integration")
@Tag("firebase")
final class RecipeSharingFlowTests: XCTestCase { }

@Tag("performance")
final class RecipeImportPerformanceTests: XCTestCase { }
```

---

## Common Patterns

### Testing Throws

```swift
func testImport_InvalidURL_ThrowsError() async throws {
    let invalidURL = URL(string: "not-a-url")!

    await XCTAssertThrowsError(try await importService.importRecipe(from: invalidURL)) { error in
        XCTAssertTrue(error is ImportError)
        XCTAssertEqual((error as? ImportError)?.code, .invalidURL)
    }
}
```

### Testing Optional Values

```swift
func testRecipeFetch_ValidID_ReturnsRecipe() throws {
    let recipe = try recipeService.fetchRecipe(id: validID)

    XCTAssertNotNil(recipe)
    let unwrapped = try XCTUnwrap(recipe)
    XCTAssertEqual(unwrapped.id, validID)
}
```

### Testing Collections

```swift
func testIngredientParsing_MultipleLanguages_AllParsed() {
    let ingredients = [
        "2 cups flour",        // English
        "2 tasses de farine",  // French
        "2カップの小麦粉"        // Japanese
    ]

    for (index, text) in ingredients.enumerated() {
        let parsed = IngredientParser.parse(text)
        XCTAssertNotNil(parsed.quantity, "Failed at index \(index): \(text)")
        XCTAssertEqual(parsed.quantity, 2.0, accuracy: 0.001)
        XCTAssertEqual(parsed.unit, "cup")
    }
}
```

### Testing State Changes

```swift
func testRecipeUpdate_Title_UpdatesLastModified() async throws {
    // GIVEN: Recipe with known last modified date
    let originalDate = Date().addingTimeInterval(-3600)  // 1 hour ago
    let recipe = RecipeFactory.create(lastModified: originalDate)

    // WHEN: Update title
    recipe.title = "Updated Title"
    try await recipeService.save(recipe)

    // THEN: Last modified should be recent
    XCTAssertGreaterThan(recipe.lastModified, originalDate)
    XCTAssertLessThan(Date().timeIntervalSince(recipe.lastModified), 5.0)
}
```

### Testing Side Effects

```swift
func testRecipeShare_SendsNotification() async throws {
    // GIVEN: Mock notification service
    let mockNotifications = MockNotificationService()
    let shareService = ShareService(notifications: mockNotifications)

    // WHEN: Share recipe
    try await shareService.share(recipe, to: recipientID)

    // THEN: Notification was sent
    XCTAssertTrue(mockNotifications.callLog.contains("sendNotification"))
    XCTAssertEqual(mockNotifications.sentNotifications.count, 1)
    XCTAssertEqual(mockNotifications.sentNotifications.first?.recipientID, recipientID)
}
```

---

## Anti-Patterns to Avoid

### ❌ Don't Use Sleep for Synchronization

```swift
// ❌ BAD: Race conditions, flaky tests
func testAsync_BadExample() async {
    startAsyncOperation()
    try? await Task.sleep(nanoseconds: 1_000_000_000)  // Hope it finishes in 1s
    XCTAssertTrue(operationCompleted)
}

// ✅ GOOD: Proper async/await
func testAsync_GoodExample() async throws {
    let result = try await performAsyncOperation()
    XCTAssertEqual(result, expected)
}
```

### ❌ Don't Test Implementation Details

```swift
// ❌ BAD: Tests internal implementation
func testRecipeScaling_UsesLinearAlgorithm() {
    XCTAssertTrue(scalingEngine.usesLinearScaling)  // Internal detail
}

// ✅ GOOD: Tests behavior
func testRecipeScaling_Double_IngredientsDoubled() {
    let scaled = scalingEngine.scale(recipe, to: 8)
    XCTAssertEqual(scaled.ingredients[0].quantity, recipe.ingredients[0].quantity * 2)
}
```

### ❌ Don't Share Mutable State

```swift
// ❌ BAD: Shared mutable state
class BadTests: XCTestCase {
    var sharedRecipe: Recipe!  // Shared across tests

    func testOne() {
        sharedRecipe.title = "Test 1"
    }

    func testTwo() {
        // Depends on test order!
        XCTAssertEqual(sharedRecipe.title, "Test 1")
    }
}

// ✅ GOOD: Each test creates its own data
class GoodTests: XCTestCase {
    func testOne() {
        let recipe = RecipeFactory.create(title: "Test 1")
        XCTAssertEqual(recipe.title, "Test 1")
    }

    func testTwo() {
        let recipe = RecipeFactory.create(title: "Test 2")
        XCTAssertEqual(recipe.title, "Test 2")
    }
}
```

---

## Checklist for New Tests

Before committing new tests, verify:

- [ ] Test name follows convention: `test[Feature]_[Scenario]_[Expected]`
- [ ] Test is isolated (no shared mutable state)
- [ ] Test uses mocks for external dependencies
- [ ] Test uses async/await (not completion handlers)
- [ ] Test has clear GIVEN/WHEN/THEN structure
- [ ] Test includes meaningful assertions with failure messages
- [ ] Test is fast (< 1 second for unit tests)
- [ ] Test is deterministic (no race conditions)
- [ ] Test cleans up resources in tearDown
- [ ] Test is documented (if complex logic)

---

## Quick Reference

### Test Template

```swift
import XCTest
@testable import Heirloom

@Tag("unit")
final class FeatureNameTests: XCTestCase {
    // MARK: - Properties
    var sut: ServiceUnderTest!
    var mockDependency: MockDependency!

    // MARK: - Setup & Teardown
    override func setUp() {
        super.setUp()
        mockDependency = MockDependency()
        sut = ServiceUnderTest(dependency: mockDependency)
    }

    override func tearDown() {
        sut = nil
        mockDependency = nil
        super.tearDown()
    }

    // MARK: - Tests
    func testFeature_Scenario_ExpectedResult() async throws {
        // GIVEN
        let input = FixtureFactory.create()

        // WHEN
        let result = try await sut.performAction(input)

        // THEN
        XCTAssertEqual(result, expected)
    }
}
```

---

## Resources

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Swift Testing Best Practices](https://swift.org/documentation/testing/)
- [Test-Driven Development](https://martinfowler.com/bliki/TestDrivenDevelopment.html)

---

**Document Version**: 1.0
**Last Updated**: January 6, 2026
**Maintained By**: Test Infrastructure Team
