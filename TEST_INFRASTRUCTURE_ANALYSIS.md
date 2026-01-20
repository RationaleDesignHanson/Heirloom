# Test Infrastructure Analysis: HeirloomTests vs HeirloomTestsV2

## Executive Summary

**Recommendation**: Migrate new Share Extension tests to **HeirloomTestsV2** structure. It's significantly better organized and more maintainable.

---

## Comparison Matrix

| Aspect | HeirloomTests (Old) | HeirloomTestsV2 (New) | Winner |
|--------|---------------------|----------------------|--------|
| **Organization** | Flat structure, mixed concerns | Clear Unit/Integration/Regression separation | ✅ V2 |
| **Test Quality** | Basic assertions | Given/When/Then + Adversarial patterns | ✅ V2 |
| **Mocks/Fixtures** | Scattered in Mocks/ folder | Organized TestInfrastructure/ with categories | ✅ V2 |
| **Setup Helpers** | Ad-hoc per test | Centralized factories (TestRecipeFactory, etc.) | ✅ V2 |
| **Coverage** | Basic happy path | Happy path + Adversarial + Integration | ✅ V2 |
| **Naming** | `testSomething()` | Descriptive `test_condition_expectation()` | ✅ V2 |
| **Documentation** | Minimal comments | Clear inline documentation | ✅ V2 |
| **Feature Organization** | Mixed | Features/VideoImport, Features/Sharing, etc. | ✅ V2 |

---

## HeirloomTests (Old Structure)

### Pros:
- ✅ Simple flat structure, easy to find tests
- ✅ Quick to add new tests

### Cons:
- ❌ No clear separation between unit/integration tests
- ❌ Mocks scattered, hard to reuse
- ❌ No adversarial testing pattern
- ❌ Basic test quality (simple assertions)
- ❌ Hard to navigate as test count grows

### Example Structure:
```
HeirloomTests/
├── Mocks/
│   └── Firebase/
│       ├── MockFirestore.swift
│       └── MockAuth.swift
├── Models/
│   ├── RecipeTests.swift
│   └── CRDT/
├── RecipeKeywordsTests.swift
├── PlatformDetectorTests.swift
└── AudioAnalyzerModeSelectionTests.swift
```

### Example Test (Simple):
```swift
final class RecipeKeywordsTests: XCTestCase {
    func testHighRelevanceTranscript() {
        let transcript = "Add two cups of flour..."
        let score = RecipeKeywords.relevanceScore(for: transcript)
        XCTAssertGreaterThan(score, 0.5)
    }
}
```

---

## HeirloomTestsV2 (New Structure)

### Pros:
- ✅ **Clear organization**: Unit/Integration/Regression/Performance
- ✅ **Feature-based**: Tests grouped by feature (VideoImport, Sharing, etc.)
- ✅ **Baseline + Adversarial pattern**: Happy path + edge cases/errors
- ✅ **Centralized test infrastructure**: Mocks, Fixtures, Helpers
- ✅ **Better naming**: `test_condition_expectation()`
- ✅ **Given/When/Then comments**: Self-documenting
- ✅ **Reusable factories**: TestRecipeFactory, IngredientFactory
- ✅ **Mock service container**: Easier dependency injection
- ✅ **Async test helpers**: Better async/await testing

### Cons:
- ❌ More structure to learn upfront (but worth it)

### Example Structure:
```
HeirloomTestsV2/
├── Unit/
│   ├── Features/
│   │   ├── VideoImport/
│   │   │   ├── VideoImportBaselineTests.swift
│   │   │   ├── VideoImportAdversarialTests.swift
│   │   │   └── ASMRProcessingTests.swift
│   │   ├── Sharing/
│   │   │   ├── DeepLinkingTests.swift
│   │   │   ├── FirebaseShareServiceTests.swift
│   │   │   └── SharingAdversarialTests.swift
│   │   └── Subscription/
│   ├── Models/
│   └── Services/
├── Integration/
│   ├── AI/
│   │   ├── ClaudeRecipeStructuringTests.swift
│   │   └── VideoImportEndToEndTests.swift
│   └── ASMRVideoProcessorTests.swift
├── Regression/
├── Performance/
└── TestInfrastructure/
    ├── Mocks/
    │   ├── AI/
    │   ├── Firebase/
    │   ├── Network/
    │   └── Store/
    ├── Fixtures/
    │   ├── RecipeFactory.swift
    │   └── IngredientFactory.swift
    └── Helpers/
        ├── TestRecipeFactory.swift
        ├── MockServiceContainer.swift
        └── AsyncTestHelpers.swift
```

### Example Test (Well-Structured):
```swift
@MainActor
final class VideoImportBaselineTests: XCTestCase {
    var modelContext: ModelContext!
    var mockLogger: MockLoggingService!
    var analytics: AnalyticsService!

    override func setUp() async throws {
        try await super.setUp()
        modelContext = try TestRecipeFactory.createTestModelContext()
        mockLogger = MockLoggingService()
        analytics = AnalyticsService()
    }

    func test_validYouTubeURL_acceptedForProcessing() {
        // Given: Valid YouTube URL
        let validURLs = [
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://youtu.be/dQw4w9WgXcQ",
            "https://m.youtube.com/watch?v=dQw4w9WgXcQ"
        ]

        // When/Then: Each URL should be valid
        for url in validURLs {
            let isValid = VideoURLValidator.isValidYouTubeURL(url)
            XCTAssertTrue(isValid, "URL should be valid: \(url)")
        }
    }
}
```

### Example Adversarial Test:
```swift
@MainActor
final class VideoImportAdversarialTests: XCTestCase {
    func test_malformedURL_failsGracefully() {
        // Given: Malformed URLs
        let malformedURLs = [
            "not a url at all",
            "htp://youtube.com",
            "https://",
            "www.youtube.com" // Missing protocol
        ]

        // When/Then: Each should be invalid
        for url in malformedURLs {
            let isValid = VideoURLValidator.isValidYouTubeURL(url)
            XCTAssertFalse(isValid, "Malformed URL should be invalid: \(url)")
        }
    }
}
```

---

## Recommended Test Patterns (from V2)

### 1. Baseline + Adversarial Split
- **Baseline**: Happy path, expected behavior
- **Adversarial**: Edge cases, errors, boundaries, malformed input

### 2. Given/When/Then Comments
```swift
func test_action_expectedResult() {
    // Given: Setup and preconditions
    let input = "test"

    // When: Perform action
    let result = processInput(input)

    // Then: Verify expectations
    XCTAssertEqual(result, "expected")
}
```

### 3. Descriptive Test Names
- ❌ Bad: `testURL()`
- ✅ Good: `test_validYouTubeURL_acceptedForProcessing()`
- ✅ Good: `test_malformedURL_failsGracefully()`

### 4. Centralized Factories
```swift
// TestRecipeFactory.createHeritageRecipe()
// IngredientFactory.create()
// MockServiceContainer.shared
```

### 5. Feature-Based Organization
```
Unit/Features/VideoImport/
Unit/Features/Sharing/
Unit/Features/Subscription/
```

---

## Migration Plan for Share Extension Tests

### Current Tests (in HeirloomTests):
```
HeirloomTests/
├── PlatformDetectorTests.swift
├── RecipeKeywordsTests.swift
└── AudioAnalyzerModeSelectionTests.swift
```

### Recommended Structure (in HeirloomTestsV2):
```
HeirloomTestsV2/
├── Unit/
│   └── Features/
│       └── ShareExtension/
│           ├── PlatformDetectorBaselineTests.swift
│           ├── PlatformDetectorAdversarialTests.swift
│           ├── RecipeKeywordsTests.swift
│           ├── AudioAnalyzerTests.swift
│           ├── OnScreenTextDetectorTests.swift
│           ├── WatermarkDetectorTests.swift
│           └── AttributionResolverTests.swift
├── Integration/
│   └── ShareExtension/
│       ├── ShareExtensionE2ETests.swift
│       ├── ThreeTierCascadeTests.swift
│       └── DeepLinkHandoffTests.swift
└── TestInfrastructure/
    ├── Mocks/
    │   └── ShareExtension/
    │       ├── MockPendingImportManager.swift
    │       └── MockVideoProcessor.swift
    └── Fixtures/
        └── VideoImportFixtures.swift
```

---

## Specific Improvements for Our Tests

### PlatformDetectorTests

**Current** (Basic):
```swift
func testTikTokFullURL() {
    let url = URL(string: "https://www.tiktok.com/@chef/video/1234567890")!
    let result = PlatformDetector.detect(from: url)
    XCTAssertEqual(result?.platform, .tiktok)
}
```

**Improved** (Baseline + Adversarial):
```swift
// PlatformDetectorBaselineTests.swift
func test_validTikTokURL_detectedCorrectly() {
    // Given: Valid TikTok URLs in various formats
    let validURLs = [
        "https://www.tiktok.com/@chef/video/1234567890",
        "https://vm.tiktok.com/ABC123",
        "https://tiktok.com/@user/video/9876543210"
    ]

    // When/Then: Each should detect TikTok platform
    for url in validURLs {
        guard let url = URL(string: url) else {
            XCTFail("Invalid URL string: \(url)")
            continue
        }
        let result = PlatformDetector.detect(from: url)
        XCTAssertEqual(result?.platform, .tiktok, "Should detect TikTok for: \(url)")
    }
}

// PlatformDetectorAdversarialTests.swift
func test_malformedTikTokURL_returnsNil() {
    // Given: Malformed TikTok URLs
    let malformedURLs = [
        "tiktok.com/@user", // Missing protocol
        "https://tiktok.com", // Missing video path
        "https://www.tiktok.com/@user/video/", // Missing video ID
        "https://tiktok.com/video/123" // Missing username
    ]

    // When/Then: Each should return nil or unknown
    for urlString in malformedURLs {
        let result = PlatformDetector.detect(from: urlString)
        XCTAssertTrue(
            result == nil || result?.platform == .unknown,
            "Malformed URL should not detect TikTok: \(urlString)"
        )
    }
}
```

### RecipeKeywordsTests

**Current** (Basic):
```swift
func testHighRelevanceTranscript() {
    let transcript = "Add two cups of flour..."
    let score = RecipeKeywords.relevanceScore(for: transcript)
    XCTAssertGreaterThan(score, 0.5)
}
```

**Improved**:
```swift
func test_recipeTranscript_highRelevanceScore() {
    // Given: Transcript with many recipe keywords
    let transcript = """
    Add two cups of flour and one teaspoon of salt.
    Mix in the eggs and butter. Preheat the oven to 350 degrees.
    Bake for 30 minutes until golden brown.
    """

    // When: Calculate relevance score
    let score = RecipeKeywords.relevanceScore(for: transcript)

    // Then: Should be high relevance (>50%)
    XCTAssertGreaterThan(score, 0.5, "Recipe transcript should have high relevance")
}

func test_emptyString_zeroRelevance() {
    // Given: Empty string
    let empty = ""

    // When: Calculate relevance
    let score = RecipeKeywords.relevanceScore(for: empty)

    // Then: Should be zero
    XCTAssertEqual(score, 0, "Empty string should have zero relevance")
}

func test_unicodeText_handledGracefully() {
    // Given: Text with emoji and unicode
    let transcript = "🍕 Add 2️⃣ cups of 小麦粉 (flour)"

    // When: Calculate relevance
    let score = RecipeKeywords.relevanceScore(for: transcript)

    // Then: Should not crash and should detect "flour"
    XCTAssertGreaterThan(score, 0, "Should handle unicode text")
}
```

---

## Action Items

### 1. Migrate Current Tests to HeirloomTestsV2
- [ ] Create `Unit/Features/ShareExtension/` directory
- [ ] Split PlatformDetectorTests into Baseline + Adversarial
- [ ] Improve RecipeKeywordsTests with better test cases
- [ ] Improve AudioAnalyzerModeSelectionTests with mocks

### 2. Add Integration Tests
- [ ] ShareExtensionE2ETests (full flow from share to recipe)
- [ ] ThreeTierCascadeTests (test mode selection logic)
- [ ] DeepLinkHandoffTests (shared container → main app)

### 3. Create Test Infrastructure
- [ ] MockPendingImportManager
- [ ] MockVideoProcessor (for faster tests)
- [ ] VideoImportFixtures (sample videos, transcripts)
- [ ] ShareExtensionTestHelpers

### 4. Document Testing Standards
- [ ] Add TEST_GUIDELINES.md with V2 patterns
- [ ] Update contribution guidelines
- [ ] Add test templates

---

## Example: Complete Share Extension Test Suite

```
HeirloomTestsV2/
├── Unit/Features/ShareExtension/
│   ├── PlatformDetectorBaselineTests.swift
│   │   ├── test_validTikTokURL_detectedCorrectly()
│   │   ├── test_validInstagramReel_detectedCorrectly()
│   │   ├── test_validYouTubeShorts_detectedCorrectly()
│   │   └── test_extractUsername_fromTikTokURL()
│   │
│   ├── PlatformDetectorAdversarialTests.swift
│   │   ├── test_malformedURL_returnsNil()
│   │   ├── test_nonVideoURL_returnsNil()
│   │   ├── test_emptyString_handledGracefully()
│   │   └── test_extremelyLongURL_handledGracefully()
│   │
│   ├── RecipeKeywordsTests.swift
│   │   ├── test_recipeTranscript_highRelevance()
│   │   ├── test_nonRecipeText_lowRelevance()
│   │   ├── test_emptyString_zeroRelevance()
│   │   └── test_unicodeText_handledGracefully()
│   │
│   ├── AudioAnalyzerBaselineTests.swift
│   │   ├── test_clearSpeech_audioMode()
│   │   ├── test_lowWordCount_ocrMode()
│   │   └── test_backgroundMusic_ocrMode()
│   │
│   └── ThreeTierCascadeLogicTests.swift
│       ├── test_goodAudio_skipOCR()
│       ├── test_poorAudio_tryOCR()
│       └── test_bothFail_requirePremium()
│
└── Integration/ShareExtension/
    ├── ShareExtensionE2ETests.swift
    │   ├── test_shareVideo_createsRecipe()
    │   ├── test_shareURL_fetchesMetadata()
    │   └── test_shareToMain_deepLinkWorks()
    │
    └── ThreeTierCascadeIntegrationTests.swift
        ├── test_realVideo_selectsCorrectMode()
        └── test_paywallTriggered_forVisualMode()
```

---

## Conclusion

**HeirloomTestsV2** is clearly superior for:
- Maintainability
- Readability
- Coverage
- Organization

**Recommendation**:
1. Use HeirloomTestsV2 for all new tests
2. Gradually migrate HeirloomTests to V2 structure
3. Adopt Baseline + Adversarial pattern
4. Use centralized test infrastructure
