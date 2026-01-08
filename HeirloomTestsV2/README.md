# HeirloomTestsV2 - Modern Testing Infrastructure

**Status**: ✅ Ready to Use
**Created**: January 6, 2026

---

## Quick Start

### Run Example Test

```bash
# In Xcode: ⌘U (test entire suite)
# Or select ExampleTest.swift and click the diamond icon

# Via command line:
xcodebuild test \
  -scheme Heirloom \
  -destination 'platform=iOS Simulator,id=AC23B9C2-AC19-4BFD-AAA7-FAF284C29232' \
  -only-testing:HeirloomTestsV2/ExampleTest
```

### Write Your First Test

```swift
import XCTest
@testable import Heirloom

final class MyFeatureTests: XCTestCase {
    var env: TestEnvironment!

    override func setUp() {
        super.setUp()
        env = createTestEnvironment(authenticated: true, language: "en")
    }

    override func tearDown() {
        env.reset()
        super.tearDown()
    }

    func testMyFeature_Scenario_ExpectedResult() async throws {
        // GIVEN
        let recipe = RecipeFactory.createEnglish()

        // WHEN
        // ... test your feature

        // THEN
        XCTAssertEqual(recipe.sourceLanguage, "en")
    }
}
```

---

## Infrastructure Overview

### Mocks (Fully Functional)

```swift
// Firebase Auth
env.mockAuth.signIn()
env.mockAuth.signOut()
env.mockAuth.isAuthenticated
env.mockAuth.wasCalled("signIn")

// Firestore
env.mockFirestore.setDocument(collection: "recipes", id: "1", data: [:])
env.mockFirestore.getDocument(collection: "recipes", id: "1")
env.mockFirestore.documentExists(collection: "recipes", id: "1")
env.mockFirestore.seed(collection: "recipes", documents: [:])

// Claude API
env.mockClaudeAPI.configureFrenchDetection()
env.mockClaudeAPI.detectLanguage(text: "...", url: nil, domain: nil)
env.mockClaudeAPI.translateText("text", from: "fr", to: "en")
```

### Factories (7 Languages Supported)

```swift
// English
let recipe = RecipeFactory.createEnglish(title: "Cookies")
let ingredient = IngredientFactory.createEnglish(name: "flour", quantity: 2, unit: "cup")

// French
let recipe = RecipeFactory.createFrench()
let ingredient = IngredientFactory.createFrench(name: "farine", quantity: 2, unit: "tasse")

// Japanese (with 200ml cup conversion)
let recipe = RecipeFactory.createJapanese()
let ingredient = IngredientFactory.createJapanese(name: "小麦粉", quantity: 2, unit: "カップ")

// Korean (with traditional units 근/돈)
let recipe = RecipeFactory.createKorean()
let ingredient = IngredientFactory.createKorean(name: "쇠고기", quantity: 1, unit: "근")

// Spanish, German, Chinese also supported
```

### Async Helpers

```swift
// Wait for condition
try await AsyncTestHelpers.waitFor { condition() }

// Wait for value
let value = try await AsyncTestHelpers.waitForValue { getValue() }

// Measure performance
let (result, duration) = try await AsyncTestHelpers.measure { operation() }

// Run concurrently
let results = try await AsyncTestHelpers.runConcurrently([op1, op2, op3])

// Assert eventually
await XCTAssertEventually { condition() }
```

---

## Directory Structure

```
HeirloomTestsV2/
├── TestInfrastructure/
│   ├── Mocks/              # All mock implementations
│   ├── Fixtures/           # Test data factories
│   ├── Helpers/            # Test utilities
│   └── Extensions/         # Test extensions
│
├── Unit/                   # Unit tests (isolated)
│   └── ExampleTest.swift   # Example showing all features
│
├── Integration/            # Integration tests
├── Regression/             # Regression tests
├── Performance/            # Performance tests
└── README.md              # This file
```

---

## Common Patterns

### Pattern 1: Testing with Authentication

```swift
func testFeatureRequiringAuth() async throws {
    // Setup authenticated environment
    env = createTestEnvironment(authenticated: true)
    try await env.signIn()

    // Your test here
    XCTAssertTrue(env.mockAuth.isAuthenticated)
}
```

### Pattern 2: Testing Multilingual Import

```swift
func testImportFrenchRecipe() async throws {
    // Configure French language
    env = createTestEnvironment(language: "fr")
    let recipe = RecipeFactory.createFrench()

    // Language auto-detected
    let detection = try await env.mockClaudeAPI.detectLanguage(
        text: recipe.title,
        domain: "marmiton.org"
    )

    XCTAssertEqual(detection.language, "fr")
}
```

### Pattern 3: Testing Database Operations

```swift
func testSaveRecipe() async throws {
    // Seed test data
    env.seedRecipes([RecipeFactory.createEnglish()])

    // Verify
    XCTAssertEqual(env.mockFirestore.documentCount(in: "recipes"), 1)
}
```

### Pattern 4: Testing Error Scenarios

```swift
func testNetworkError() async throws {
    // Configure mock to fail
    env.mockFirestore.simulateOffline = true

    // Assert error thrown
    await XCTAssertThrowsErrorAsync(
        try await env.mockFirestore.getDocument(collection: "recipes", id: "1")
    ) { error in
        XCTAssertEqual(error as? FirestoreError, .offline)
    }
}
```

### Pattern 5: Testing Regional Unit Conversions

```swift
func testJapaneseCupConversion() {
    // Create ingredient with Japanese cup
    let ingredient = IngredientFactory.createJapanese(
        name: "flour",
        quantity: 2.0,
        unit: "カップ"  // Japanese cup (200ml)
    )

    // Verify conversion (200ml → 237ml US = 0.844x)
    XCTAssertTrue(ingredient.wasConverted)
    XCTAssertEqual(ingredient.convertedQuantity!, 1.688, accuracy: 0.001)
    XCTAssertNotNil(ingredient.conversionNote)
}
```

---

## Testing Checklist

Before committing a new test:

- [ ] Test name follows convention: `test[Feature]_[Scenario]_[Expected]`
- [ ] Test has GIVEN/WHEN/THEN structure
- [ ] Test is isolated (uses `setUp()`/`tearDown()`)
- [ ] Test uses mocks for external dependencies
- [ ] Test includes meaningful assertions
- [ ] Test cleans up in `tearDown()`
- [ ] Test passes consistently (not flaky)
- [ ] Test is fast (< 1 second)

---

## Language Support

| Language | Factory | Ingredient Factory | Unit Conversion |
|----------|---------|-------------------|-----------------|
| 🇬🇧 English | ✅ | ✅ | N/A |
| 🇫🇷 French | ✅ | ✅ | ✅ Metric cup (250ml→237ml) |
| 🇪🇸 Spanish | ✅ | ✅ | ✅ Metric |
| 🇩🇪 German | ✅ | ✅ | ✅ Metric |
| 🇯🇵 Japanese | ✅ | ✅ | ✅ 200ml cups, traditional units |
| 🇨🇳 Chinese | ✅ | ✅ | ✅ Metric |
| 🇰🇷 Korean | ✅ | ✅ | ✅ 200ml cups, 근/돈 |

---

## Example Test Coverage

The `ExampleTest.swift` file demonstrates:

- ✅ Mock Firebase Auth operations
- ✅ Mock Firestore CRUD operations
- ✅ Mock Claude API language detection
- ✅ Recipe factories (English, French, Japanese)
- ✅ Ingredient factories with conversions
- ✅ Async helpers (waitFor, measure)
- ✅ Integration testing
- ✅ Error injection testing

**Run it to validate your setup!**

---

## Resources

- **Testing Standards**: `/Users/matthanson/Heirloom/TESTING_STANDARDS.md`
- **Test Audit**: `/Users/matthanson/Heirloom/TEST_SUITE_AUDIT_WEEK1.md`
- **Progress**: `/Users/matthanson/Heirloom/PROGRESS_SUMMARY.md`
- **Example Test**: `ExampleTest.swift` (this directory)

---

## Next Steps

1. ✅ Run `ExampleTest` to validate setup
2. 📝 Write tests for your feature
3. 📝 Integrate 90 multilingual tests (Week 4)
4. 📝 Build comprehensive coverage (Weeks 5-12)

---

**Status**: 🟢 Ready for Production Testing
**Infrastructure Complete**: 8 files, 5,500+ lines
**Test Coverage Target**: 70%+ across critical paths

Happy testing! 🧪
