# Phase 5 Week 12: AI Services Migration to Dependency Injection

**Date**: 2026-01-03
**Status**: In Progress
**Goal**: Migrate 10 AI services from singleton pattern to DI

---

## Progress Summary

### ✅ Phase 5 Week 11 - COMPLETED
- **Firebase Services**: All 11 services migrated to DI
- **Views Updated**: 15+ views converted to use `@Environment`
- **Build Status**: ✅ Succeeded
- **Singletons Removed**: 11 of 52 (21% complete)

### 🚧 Phase 5 Week 12 - IN PROGRESS
- **AI Services**: 0 of 10 migrated
- **Build Status**: ⚠️ 5 failures (protocol conformance)
- **Singletons Removed**: 11 of 52 (21% complete)

---

## AI Services Inventory

### Priority 1: Core AI Services (Days 1-2)

#### 1. AnthropicAIService ✅
- **Protocol**: `AIServiceProtocol` (already conforms)
- **Status**: Has protocol, needs DI migration
- **Dependencies**: AIConfiguration
- **Consumers**: All AI features
- **Complexity**: Medium

#### 2. AIConfiguration ✅
- **Protocol**: `AIConfigurationProtocol` (already conforms)
- **Status**: Has protocol, needs DI migration
- **Dependencies**: Keychain
- **Consumers**: All AI services
- **Complexity**: Low

#### 3. AIRecipeExtractor ⚠️
- **Protocol**: `AIRecipeExtractorProtocol` (declared, needs implementation)
- **Status**: Protocol mismatch - needs wrapper methods
- **Current API**:
  - `extractRecipe(from ocrText: String) -> ExtractedRecipe`
  - `extractRecipeFromImage(...) -> ExtractedRecipe`
  - `extractMultipleRecipes(...)`
- **Protocol API**:
  - `extract(from text: String) async throws -> Recipe`
  - `extract(from image: UIImage) async throws -> Recipe`
- **Dependencies**: AnthropicAIService, AIConfiguration
- **Consumers**: CookbookScannerView, OCRReviewView, RecipeImportView
- **Complexity**: High (complex API, multiple methods)

#### 4. AIIngredientParser ⚠️
- **Protocol**: `AIIngredientParserProtocol` (declared, needs implementation)
- **Status**: Protocol mismatch - needs wrapper methods
- **Current API**:
  - `parseIngredient(_ text: String) async throws -> ParsedIngredient`
  - `parseIngredients(_ texts: [String]) async throws -> [ParsedIngredient]`
- **Protocol API**:
  - `parse(_ text: String) async throws -> Ingredient`
  - `parseBatch(_ texts: [String]) async throws -> [Ingredient]`
- **Dependencies**: AnthropicAIService
- **Consumers**: RecipeEditorView, IngredientInputView
- **Complexity**: Medium

### Priority 2: Analysis Services (Days 3-4)

#### 5. CommentAnalysisService
- **Protocol**: None (needs creation)
- **Status**: No protocol yet
- **Current API**:
  - `analyzeSentiment(for text: String) async throws -> Sentiment`
  - `suggestTags(for comment: String) async throws -> [String]`
- **Dependencies**: AnthropicAIService
- **Consumers**: CommentInputView, CommentListView
- **Complexity**: Low

#### 6. DinnerPartySummaryService
- **Protocol**: None (needs creation)
- **Status**: No protocol yet
- **Current API**:
  - `generateSummary(for party: DinnerParty) async throws -> String`
- **Dependencies**: AnthropicAIService
- **Consumers**: DinnerPartyDetailView
- **Complexity**: Low

#### 7. ShoppingListSummaryService
- **Protocol**: None (needs creation)
- **Status**: No protocol yet
- **Current API**:
  - `summarizeList(_ items: [ShoppingItem]) async throws -> String`
- **Dependencies**: AnthropicAIService
- **Consumers**: ShoppingListView
- **Complexity**: Low

### Priority 3: Utility Services (Days 5-6)

#### 8. RecipeTimelineCalculator
- **Protocol**: None (needs creation)
- **Status**: No protocol yet
- **Current API**:
  - `calculateTimeline(for recipe: Recipe) -> Timeline`
- **Dependencies**: None (pure logic)
- **Consumers**: CookingModeView
- **Complexity**: Low

#### 9. AIUsageTracker
- **Protocol**: None (needs creation)
- **Status**: No protocol yet
- **Current API**:
  - `trackRequest(tokens: Int, cost: Decimal)`
  - `getUsageStats() -> UsageStats`
- **Dependencies**: None
- **Consumers**: All AI services
- **Complexity**: Low

#### 10. AIIngredientSpellChecker
- **Protocol**: None (needs creation)
- **Status**: No protocol yet
- **Current API**:
  - `checkSpelling(_ text: String) async throws -> SpellCheckResult`
- **Dependencies**: AnthropicAIService
- **Consumers**: IngredientInputView
- **Complexity**: Low

---

## Implementation Plan

### Step 1: Fix Protocol Conformance (Days 1-2)

**AIRecipeExtractor** - Add wrapper methods:
```swift
// MARK: - Protocol Conformance

func extract(from text: String) async throws -> Recipe {
    let extracted = try await extractRecipe(from: text)
    return convertToRecipe(extracted)
}

func extract(from image: UIImage) async throws -> Recipe {
    let extracted = try await extractRecipeFromImage(image)
    return convertToRecipe(extracted)
}

private func convertToRecipe(_ extracted: ExtractedRecipe) -> Recipe {
    // Convert ExtractedRecipe to Recipe
}
```

**AIIngredientParser** - Add wrapper methods:
```swift
// MARK: - Protocol Conformance

func parse(_ text: String) async throws -> Ingredient {
    let parsed = try await parseIngredient(text)
    return convertToIngredient(parsed)
}

func parseBatch(_ texts: [String]) async throws -> [Ingredient] {
    let parsed = try await parseIngredients(texts)
    return parsed.map { convertToIngredient($0) }
}

private func convertToIngredient(_ parsed: ParsedIngredient) -> Ingredient {
    // Convert ParsedIngredient to Ingredient
}
```

### Step 2: Create Missing Protocols (Day 3)

Add to `ServiceProtocols.swift`:
```swift
protocol CommentAnalysisServiceProtocol {
    func analyzeSentiment(for text: String) async throws -> Sentiment
    func suggestTags(for comment: String) async throws -> [String]
}

protocol DinnerPartySummaryServiceProtocol {
    func generateSummary(for party: DinnerParty) async throws -> String
}

protocol ShoppingListSummaryServiceProtocol {
    func summarizeList(_ items: [ShoppingItem]) async throws -> String
}

protocol RecipeTimelineCalculatorProtocol {
    func calculateTimeline(for recipe: Recipe) -> Timeline
}

protocol AIUsageTrackerProtocol {
    func trackRequest(tokens: Int, cost: Decimal)
    func getUsageStats() -> UsageStats
}

protocol AIIngredientSpellCheckerProtocol {
    func checkSpelling(_ text: String) async throws -> SpellCheckResult
}
```

### Step 3: Add Protocol Conformance (Day 3)

Add conformance declarations to each service:
```swift
class CommentAnalysisService: CommentAnalysisServiceProtocol { ... }
class DinnerPartySummaryService: DinnerPartySummaryServiceProtocol { ... }
// etc.
```

### Step 4: Remove .shared Singletons (Day 4)

For each service, remove:
```swift
// REMOVE:
static let shared = ServiceName()
private init() {}

// Services will be instantiated by ServiceContainer
```

### Step 5: Update ServiceRegistration (Day 4)

Add registrations for all AI services:
```swift
// Core AI Services
register(AIServiceProtocol.self, lifecycle: .singleton) { container in
    let config = container.resolve(AIConfiguration.self)
    return AnthropicAIService(configuration: config)
}

register(AIRecipeExtractorProtocol.self, lifecycle: .singleton) { container in
    let aiService = container.resolve(AIServiceProtocol.self)
    let config = container.resolve(AIConfiguration.self)
    return AIRecipeExtractor(aiService: aiService, configuration: config)
}

register(AIIngredientParserProtocol.self, lifecycle: .singleton) { container in
    let aiService = container.resolve(AIServiceProtocol.self)
    return AIIngredientParser(aiService: aiService)
}

// Analysis Services
register(CommentAnalysisServiceProtocol.self, lifecycle: .singleton) { container in
    let aiService = container.resolve(AIServiceProtocol.self)
    return CommentAnalysisService(aiService: aiService)
}

// Continue for all services...
```

### Step 6: Add Environment Keys (Day 5)

Add to `ServiceEnvironment.swift`:
```swift
// AI Services
private struct AIServiceKey: EnvironmentKey {
    static let defaultValue: AIServiceProtocol = MainActor.assumeIsolated {
        ServiceContainer.shared.resolve(AIServiceProtocol.self)
    }
}

private struct AIRecipeExtractorKey: EnvironmentKey {
    static let defaultValue: AIRecipeExtractorProtocol = MainActor.assumeIsolated {
        ServiceContainer.shared.resolve(AIRecipeExtractorProtocol.self)
    }
}

extension EnvironmentValues {
    var aiService: AIServiceProtocol {
        get { self[AIServiceKey.self] }
        set { self[AIServiceKey.self] = newValue }
    }

    var aiRecipeExtractor: AIRecipeExtractorProtocol {
        get { self[AIRecipeExtractorKey.self] }
        set { self[AIRecipeExtractorKey.self] = newValue }
    }

    // Continue for all services...
}
```

### Step 7: Update View Consumers (Days 5-6)

Update all views using AI services:

**Before:**
```swift
struct CookbookScannerView: View {
    func processImage() {
        let result = await AIRecipeExtractor.shared.extractRecipe(...)
    }
}
```

**After:**
```swift
struct CookbookScannerView: View {
    @Environment(\.aiRecipeExtractor) private var aiRecipeExtractor

    func processImage() {
        let result = await aiRecipeExtractor.extract(from: image)
    }
}
```

**Views to Update:**
- CookbookScannerView
- OCRReviewView
- RecipeImportView
- RecipeSelectionView
- RecipeEditorView
- IngredientInputView
- CommentInputView
- CommentListView
- DinnerPartyDetailView
- ShoppingListView
- CookingModeView

---

## Testing Strategy

### Unit Tests (After Migration)
```swift
class AIRecipeExtractorTests: XCTestCase {
    var sut: AIRecipeExtractor!
    var mockAIService: MockAIService!

    override func setUp() {
        mockAIService = MockAIService()
        sut = AIRecipeExtractor(aiService: mockAIService)
    }

    func testExtractFromText() async throws {
        // Test with mock
        mockAIService.stubResponse = mockRecipeJSON
        let recipe = try await sut.extract(from: "recipe text")
        XCTAssertEqual(recipe.title, "Expected Title")
    }
}
```

### Integration Tests
```swift
func testAIServicesIntegration() async throws {
    // Setup container with test configuration
    let container = ServiceContainer()
    container.register(AIServiceProtocol.self) { _ in
        MockAIService()
    }

    // Test service resolution
    let extractor = container.resolve(AIRecipeExtractorProtocol.self)
    let recipe = try await extractor.extract(from: "test")
    XCTAssertNotNil(recipe)
}
```

---

## Risk Mitigation

### High Risk Areas

1. **AIRecipeExtractor Protocol Mismatch**
   - **Risk**: Complex API with multiple extraction methods
   - **Mitigation**: Create comprehensive wrapper methods, maintain existing public API
   - **Rollback**: Keep existing methods, mark protocol methods as convenience

2. **AIIngredientParser Return Type Mismatch**
   - **Risk**: Returns `ParsedIngredient`, protocol expects `Ingredient`
   - **Mitigation**: Create conversion helper, test thoroughly
   - **Rollback**: Update protocol to use `ParsedIngredient`

3. **Service Initialization Order**
   - **Risk**: AIServices depend on each other and AIConfiguration
   - **Mitigation**: Careful ordering in ServiceRegistration
   - **Rollback**: Use lazy initialization

4. **Performance Impact**
   - **Risk**: DI container resolution overhead
   - **Mitigation**: Use singleton lifecycle, measure performance
   - **Rollback**: Keep services cached after first resolution

### Low Risk Areas

- CommentAnalysisService (simple API)
- DinnerPartySummaryService (single method)
- ShoppingListSummaryService (single method)
- RecipeTimelineCalculator (no dependencies)
- AIUsageTracker (stateless)

---

## Success Criteria

### Build Status
- ✅ Zero compilation errors
- ✅ Zero warnings related to AI services
- ✅ All 235 tests pass

### Code Quality
- ✅ All AI services conform to protocols
- ✅ No `.shared` singleton accessors remain
- ✅ All consumers use `@Environment` injection
- ✅ ServiceContainer properly configured

### Functionality
- ✅ Recipe extraction works (text and image)
- ✅ Ingredient parsing works
- ✅ Comment analysis works
- ✅ All AI features functional

### Progress Metrics
- **Before**: 11/52 services migrated (21%)
- **After**: 21/52 services migrated (40%)
- **Target**: 52/52 services migrated (100%)

---

## Timeline

| Day | Task | Status |
|-----|------|--------|
| Day 1 | Fix AIRecipeExtractor protocol conformance | 🚧 In Progress |
| Day 1 | Fix AIIngredientParser protocol conformance | ⏳ Pending |
| Day 2 | Migrate AnthropicAIService to DI | ⏳ Pending |
| Day 2 | Migrate AIConfiguration to DI | ⏳ Pending |
| Day 3 | Create protocols for analysis services | ⏳ Pending |
| Day 3 | Add protocol conformance to analysis services | ⏳ Pending |
| Day 4 | Remove .shared from all AI services | ⏳ Pending |
| Day 4 | Update ServiceRegistration | ⏳ Pending |
| Day 5 | Add environment keys | ⏳ Pending |
| Day 5 | Update views (Part 1: Extraction/Parsing) | ⏳ Pending |
| Day 6 | Update views (Part 2: Analysis/Utilities) | ⏳ Pending |
| Day 6 | Final build verification | ⏳ Pending |

---

## Next Steps After AI Services

### Phase 5 Week 13: Recipe Services (7 services)
- RecipeImportService ✅ (has protocol)
- RecipeVersionService ✅ (has protocol)
- RecipeLineageService
- RecipeStructureParser
- RecipeExportService
- RecipeMigrationService
- CategoryDetectionService

### Phase 5 Week 14: Storage Services (2 services)
- ImageStorageService ✅ (has protocol)
- ImageCache ✅ (has protocol)

### Phase 5 Week 15: Core Services (9 services)
- NetworkMonitor ✅ (has protocol)
- DeepLinkHandler
- EnhancedOCRService
- RemindersService
- CommentService ✅ (already uses DI)
- UndoService
- CRDTMergeEngine
- ScalingEngine
- ImagePreprocessor

### Phase 5 Week 16: UI/Utility Services (9 services)
- ToastManager
- HeirloomLogger ✅ (has protocol)
- DeviceLogger
- BackendConfig
- UnitsConfiguration
- ImportJobManager ✅ (already uses DI)
- GestureGuide
- HelpContent
- PrivacyConsentService

### Phase 5 Week 17: Analytics Services (3 services)
- AnalyticsService ✅ (has protocol)
- MixpanelService
- ConsoleAnalyticsService

---

## Completion Roadmap

**Current**: 11/52 services (21%)

**After Week 12 (AI)**: 21/52 services (40%)
**After Week 13 (Recipe)**: 28/52 services (54%)
**After Week 14 (Storage)**: 30/52 services (58%)
**After Week 15 (Core)**: 39/52 services (75%)
**After Week 16 (UI/Utilities)**: 48/52 services (92%)
**After Week 17 (Analytics)**: 51/52 services (98%)
**After Week 18 (Final cleanup)**: 52/52 services (100%) ✅

**Target Completion**: End of January 2026
