# Phase 2: AI Services Implementation Plan - v1.1.0

## Overview
Add AI-powered enhancements to recipe import and management without disrupting the existing 3-tier parsing system.

---

## Architecture Design

### Service Structure
```
Heirloom/Core/Services/AI/
├── AIServiceProtocol.swift              # Protocol definition
├── AnthropicAIService.swift             # Claude API client
├── RecipeEnhancementService.swift       # High-level recipe AI
├── AIIngredientParser.swift             # AI-powered ingredient parsing
├── AICategoryDetector.swift             # Smart category detection
└── AIConfiguration.swift                # API keys & settings
```

### Design Principles
1. **Non-Blocking**: AI enhancement is optional, never blocks recipe import
2. **Graceful Degradation**: Falls back to existing parsers if AI fails
3. **Transparent**: Users see AI-enhancement status via ToastManager
4. **Cost-Aware**: Track token usage, implement caching
5. **Privacy-First**: All data processing via Anthropic (no training on user data)

---

## Implementation Phases

### Phase 2.1: Foundation (Week 1)
**Goal**: Setup AI infrastructure & API client

**Tasks**:
1. Create `Core/Services/AI/` directory structure
2. Implement `AIServiceProtocol` with standard methods
3. Build `AnthropicAIService` with Claude API client
4. Add secure API key storage (Keychain or build config)
5. Create error handling & retry logic
6. Add analytics tracking for AI events

**Files to Create**:
- `AIServiceProtocol.swift` (100 lines)
- `AnthropicAIService.swift` (300 lines)
- `AIConfiguration.swift` (50 lines)

**Budget**: ~$50/month for Claude API (Haiku for parsing, Sonnet for complex tasks)

---

### Phase 2.2: Smart Ingredient Parsing (Week 1-2)
**Goal**: AI-enhanced ingredient extraction from scraped recipes

**Current Problem**:
- Ingredient text varies wildly across sites
- Current parser struggles with complex formats: "2 (15-oz) cans black beans, drained"
- No understanding of ingredient relationships (e.g., "for topping", "divided")

**AI Solution**:
```swift
@MainActor
class AIIngredientParser {
    static let shared = AIIngredientParser()

    func parseIngredients(_ text: [String]) async throws -> [IngredientData] {
        // Batch parse all ingredients in one API call (more efficient)
        let prompt = buildIngredientParsingPrompt(text)
        let response = try await AnthropicAIService.shared.complete(prompt)
        return parseResponse(response)
    }
}
```

**Prompt Strategy**:
```
Parse these recipe ingredients into structured data:

Ingredients:
- 2 (15-oz) cans black beans, drained and rinsed
- 1/4 cup olive oil, divided
- 3 medium tomatoes (for topping)

Return JSON array:
[
  {
    "quantity": 2,
    "unit": "cans",
    "size": "15-oz",
    "name": "black beans",
    "preparation": "drained and rinsed",
    "optional": false,
    "note": null
  },
  ...
]
```

**Integration Point**: `RecipeImportView.saveRecipe()` line 340
```swift
// EXISTING CODE:
for (index, text) in imported.ingredients.enumerated() {
    let parsedData = IngredientParser.parse(text)
    // ...
}

// ENHANCED WITH AI (fallback to existing):
for (index, text) in imported.ingredients.enumerated() {
    var parsedData = IngredientParser.parse(text)  // Always run existing parser

    if AIConfiguration.shared.isEnabled {
        do {
            let aiParsed = try await AIIngredientParser.shared.parse(text)
            parsedData = aiParsed  // Use AI if successful
            AnalyticsService.shared.track(.aiIngredientParseSuccess)
        } catch {
            // Fall back to original parsed data
            AnalyticsService.shared.track(.aiIngredientParseFailed)
        }
    }
    // Continue with parsedData...
}
```

**Testing Strategy**:
- Add tests for complex ingredient formats
- Compare AI parsing accuracy vs existing parser
- Measure token usage and latency

**Expected Improvement**:
- 95%+ parsing accuracy (up from ~85%)
- Handles edge cases: ranges, alternatives, notes, "divided" modifiers

---

### Phase 2.3: Smart Category Detection (Week 2)
**Goal**: Replace rule-based `CategoryDetectionService` with AI

**Current Problem**:
- `CategoryDetectionService.swift` uses keyword matching
- Misses nuanced recipes (e.g., "Chocolate Chip Cookie Cake" → cookies, but should be cake)
- Can't detect specialized categories (laminated dough, emulsions, etc.)

**AI Solution**:
```swift
@MainActor
class AICategoryDetector {
    static let shared = AICategoryDetector()

    func detectCategory(
        title: String,
        ingredients: [String],
        instructions: [String]
    ) async throws -> RecipeCategory {
        let prompt = buildCategoryPrompt(title, ingredients, instructions)
        let response = try await AnthropicAIService.shared.complete(prompt)
        return parseCategory(response)
    }
}
```

**Prompt Strategy**:
```
Analyze this recipe and determine the best category:

Title: "Laminated Croissant Dough"
Ingredients: flour, butter, yeast, milk, sugar, salt
Instructions: [abbreviated]

Categories:
- Cookies: Drop cookies, bar cookies, rolled cookies
- Cakes: Layer cakes, sheet cakes, bundts, cheesecakes
- Breads: Yeast breads, quick breads
- Pastries: Laminated dough (croissants, puff pastry)
- Sauces: Emulsions (mayo, hollandaise), reductions
- ...

Return JSON:
{
  "category": "pastries_laminated",
  "confidence": 0.95,
  "reasoning": "Recipe involves folding butter into dough multiple times, classic laminated dough technique",
  "scalingConstraints": {
    "minServings": 8,
    "maxServings": 24,
    "allowScaling": true,
    "warnings": ["Laminated dough requires precise ratios"]
  }
}
```

**Integration Point**: `RecipeImportView.saveRecipe()` line 360
```swift
// EXISTING CODE:
CategoryDetectionService.detectAndApply(to: recipe, ingredients: ingredients)

// ENHANCED WITH AI:
if AIConfiguration.shared.isEnabled {
    do {
        let aiCategory = try await AICategoryDetector.shared.detect(
            title: recipe.title,
            ingredients: recipe.ingredients.map(\.originalText),
            instructions: recipe.instructions.map(\.text)
        )
        recipe.category = aiCategory.swiftDataCategory
        recipe.scalingMin = aiCategory.scalingConstraints.minServings
        recipe.scalingMax = aiCategory.scalingConstraints.maxServings
        AnalyticsService.shared.track(.aiCategoryDetectionSuccess)
    } catch {
        // Fall back to existing CategoryDetectionService
        CategoryDetectionService.detectAndApply(to: recipe, ingredients: ingredients)
        AnalyticsService.shared.track(.aiCategoryDetectionFailed)
    }
} else {
    CategoryDetectionService.detectAndApply(to: recipe, ingredients: ingredients)
}
```

**Expected Improvement**:
- 98%+ category accuracy (up from ~75%)
- Automatic detection of scaling constraints
- Better understanding of technique-based categories

---

### Phase 2.4: Recipe Enhancement Service (Week 3)
**Goal**: Comprehensive post-import AI enhancement

**Features**:
1. **Missing Field Detection**
   - Detect missing prep/cook times
   - Infer servings if not specified
   - Suggest category if uncategorized

2. **Quality Improvements**
   - Standardize ingredient formats
   - Fix typos in instructions
   - Add helpful cooking tips

3. **Metadata Enrichment**
   - Detect dietary restrictions (vegan, gluten-free, dairy-free)
   - Identify cuisine type (Italian, Mexican, Thai, etc.)
   - Suggest tags (quick, make-ahead, comfort food, etc.)

**Implementation**:
```swift
@MainActor
class RecipeEnhancementService {
    static let shared = RecipeEnhancementService()

    func enhanceRecipe(_ recipe: Recipe) async throws -> RecipeEnhancements {
        let prompt = buildEnhancementPrompt(recipe)
        let response = try await AnthropicAIService.shared.complete(prompt)
        return parseEnhancements(response)
    }
}

struct RecipeEnhancements {
    var prepTime: String?
    var cookTime: String?
    var servings: Int?
    var dietaryRestrictions: [String]
    var cuisineType: String?
    var suggestedTags: [String]
    var cookingTips: [String]
}
```

**Integration Point**: Optional enhancement after successful import
```swift
// After recipe is saved to database
if AIConfiguration.shared.enableEnhancement {
    Task {
        do {
            let enhancements = try await RecipeEnhancementService.shared.enhance(recipe)
            applyEnhancements(enhancements, to: recipe)
            ToastManager.shared.info(
                title: "Recipe Enhanced",
                message: "AI added helpful details and tips"
            )
        } catch {
            // Silent failure - enhancement is nice-to-have
        }
    }
}
```

---

### Phase 2.5: Settings & Configuration (Week 3)
**Goal**: User control over AI features

**Settings Screen Updates**:
```swift
Section("AI Features") {
    Toggle("AI-Powered Ingredient Parsing", isOn: $config.enableAIParsing)
        .help("More accurate ingredient extraction (uses Claude API)")

    Toggle("Smart Category Detection", isOn: $config.enableAICategories)
        .help("Automatically categorize recipes based on content")

    Toggle("Recipe Enhancement", isOn: $config.enableEnhancement)
        .help("Add cooking tips and detect dietary info")

    if config.anyAIEnabled {
        HStack {
            Text("Monthly Usage")
            Spacer()
            Text("\(aiUsageTracker.estimatedCost, format: .currency(code: "USD"))")
                .foregroundStyle(.secondary)
        }

        Button("View AI Usage Details") {
            showAIUsageSheet = true
        }
    }
}
```

**API Key Management**:
```swift
// Store in Keychain (secure)
struct AIConfiguration {
    static let shared = AIConfiguration()

    var apiKey: String? {
        get { Keychain.shared.get("anthropic_api_key") }
        set { Keychain.shared.set("anthropic_api_key", value: newValue) }
    }

    var enableAIParsing: Bool {
        get { UserDefaults.standard.bool(forKey: "ai_parsing_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "ai_parsing_enabled") }
    }
}
```

---

## Analytics & Monitoring

### New Analytics Events
```swift
extension AnalyticsEvent {
    static let aiIngredientParseRequested = "AI Ingredient Parse Requested"
    static let aiIngredientParseSuccess = "AI Ingredient Parse Success"
    static let aiIngredientParseFailed = "AI Ingredient Parse Failed"

    static let aiCategoryDetectionRequested = "AI Category Detection Requested"
    static let aiCategoryDetectionSuccess = "AI Category Detection Success"
    static let aiCategoryDetectionFailed = "AI Category Detection Failed"

    static let aiRecipeEnhancementRequested = "AI Recipe Enhancement Requested"
    static let aiRecipeEnhancementSuccess = "AI Recipe Enhancement Success"
    static let aiRecipeEnhancementFailed = "AI Recipe Enhancement Failed"
}
```

### Token Usage Tracking
```swift
@MainActor
class AIUsageTracker: ObservableObject {
    @Published var totalTokensUsed: Int = 0
    @Published var totalCost: Decimal = 0
    @Published var requestCount: Int = 0

    func trackUsage(tokens: Int, model: String) {
        totalTokensUsed += tokens
        totalCost += calculateCost(tokens: tokens, model: model)
        requestCount += 1

        // Track in analytics
        AnalyticsService.shared.track(.aiTokensUsed, properties: [
            "tokens": tokens,
            "model": model,
            "cost": totalCost
        ])
    }
}
```

---

## Cost Projections

### Anthropic Claude Pricing (Jan 2025)
- **Claude Haiku**: $0.25 per 1M input tokens, $1.25 per 1M output tokens
- **Claude Sonnet**: $3 per 1M input tokens, $15 per 1M output tokens

### Estimated Usage (per recipe import)
- **Ingredient Parsing**: ~500 input + 200 output tokens = $0.0004 (Haiku)
- **Category Detection**: ~800 input + 300 output tokens = $0.0006 (Haiku)
- **Recipe Enhancement**: ~1500 input + 500 output tokens = $0.005 (Sonnet)

**Total per recipe**: ~$0.006 (less than 1 cent)

**Monthly Projection** (100 recipe imports):
- Ingredient Parsing: $0.04
- Category Detection: $0.06
- Recipe Enhancement: $0.50
- **Total**: ~$0.60/month

**At Scale** (1000 users, 10 recipes/month each):
- 10,000 recipe imports/month
- **Estimated Cost**: $60/month

---

## Testing Strategy

### Unit Tests
```swift
class AIIngredientParserTests: XCTestCase {
    func test_parseComplexIngredient_success() async throws {
        let text = "2 (15-oz) cans black beans, drained and rinsed"
        let parsed = try await AIIngredientParser.shared.parse(text)

        XCTAssertEqual(parsed.quantity, 2)
        XCTAssertEqual(parsed.unit, "cans")
        XCTAssertEqual(parsed.size, "15-oz")
        XCTAssertEqual(parsed.name, "black beans")
        XCTAssertEqual(parsed.preparation, "drained and rinsed")
    }

    func test_fallbackToExistingParser_onAIFailure() async throws {
        // Simulate AI failure
        AIConfiguration.shared.simulateFailure = true

        let text = "1/2 cup flour"
        let parsed = try await AIIngredientParser.shared.parse(text)

        // Should fall back to IngredientParser
        XCTAssertEqual(parsed.quantity, 0.5)
        XCTAssertEqual(parsed.unit, "cup")
        XCTAssertEqual(parsed.name, "flour")
    }
}
```

### Integration Tests
- Test full recipe import with AI enabled
- Verify graceful degradation on API failures
- Test token usage tracking
- Verify cost estimates

---

## Privacy & Security

### Data Handling
1. **No Data Retention**: Use Anthropic API with zero data retention policy
2. **User Consent**: Clear disclosure in settings about AI usage
3. **API Key Security**: Store in Keychain, never log or display
4. **Minimal Data Sent**: Only send necessary fields (title, ingredients, instructions)
5. **No PII**: Never send user data, device IDs, or location info

### API Key Storage
```swift
// Secure storage in Keychain
class Keychain {
    static let shared = Keychain()

    func set(_ key: String, value: String?) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: value?.data(using: .utf8) ?? Data()
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)

        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
```

---

## Rollout Plan

### Week 1: Foundation
- [ ] Create AI service directory structure
- [ ] Implement `AnthropicAIService` with API client
- [ ] Add secure API key storage
- [ ] Create error handling & retry logic
- [ ] Add analytics events for AI features

### Week 2: Core Features
- [ ] Implement `AIIngredientParser`
- [ ] Implement `AICategoryDetector`
- [ ] Add fallback logic to existing parsers
- [ ] Create unit tests for AI services
- [ ] Add token usage tracking

### Week 3: Enhancement & Polish
- [ ] Implement `RecipeEnhancementService`
- [ ] Add settings screen for AI features
- [ ] Create AI usage dashboard
- [ ] Write integration tests
- [ ] Performance optimization

### Week 4: Testing & Launch
- [ ] Beta testing with real API usage
- [ ] Monitor costs and performance
- [ ] Fix bugs and edge cases
- [ ] Update TestFlight with v1.1.0
- [ ] Gather user feedback

---

## Success Metrics

### Technical Metrics
- AI parsing accuracy: >95%
- Category detection accuracy: >98%
- Average token usage per recipe: <1000 tokens
- API latency: <2 seconds
- Fallback rate: <5%

### User Metrics
- AI feature adoption rate: >50% of users
- Recipe import success rate: >95%
- User satisfaction with AI enhancements: >4.5/5
- Cost per active user: <$1/month

### Business Metrics
- Total AI cost: <$100/month at launch
- Cost per recipe import: <$0.01
- User retention improvement: +10%
- Recipe import volume: +25%

---

## Next Steps

1. **Review Plan**: Approve architecture and scope
2. **Setup API Key**: Get Anthropic API key (free tier includes $5 credit)
3. **Create Foundation**: Build AI service infrastructure
4. **Implement Features**: Start with ingredient parsing
5. **Test & Iterate**: Beta test with real recipes
6. **Launch v1.1.0**: Ship to TestFlight

**Ready to start implementation?**
