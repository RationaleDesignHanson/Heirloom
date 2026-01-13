# Feature Development Guide

How to add new features to Heirloom using the feature management infrastructure.

## Philosophy: Test-First, Flag-Controlled, Gradual Rollout

1. **Define** feature metadata
2. **Write tests** first (TDD)
3. **Implement** with feature flag
4. **Validate** with CI/CD gates
5. **Deploy** gradually (10% → 50% → 100%)
6. **Monitor** and rollback if needed

---

## Step-by-Step: Adding a New Feature

### Example: Adding "Recipe Import from URL"

Let's walk through adding a feature that imports recipes from any cooking website URL (not just YouTube).

---

### Step 1: Define Feature Metadata (5 minutes)

**Add to `Feature.swift`:**
```swift
enum Feature: String, CaseIterable, Codable {
    // ... existing features
    case webRecipeImport = "web_recipe_import"
}

extension Feature {
    var displayName: String {
        switch self {
        // ... existing cases
        case .webRecipeImport: return "Web Recipe Import"
        }
    }

    var description: String {
        switch self {
        // ... existing cases
        case .webRecipeImport:
            return "Import recipes from any cooking website URL"
        }
    }

    var requiresPremium: Bool {
        switch self {
        // ... existing cases
        case .webRecipeImport: return true // Premium feature
        }
    }

    var category: FeatureCategory {
        switch self {
        // ... existing cases
        case .webRecipeImport: return .premium
        }
    }
}
```

**Add to `FeatureRegistryData.swift`:**
```swift
.webRecipeImport: FeatureMetadata(
    feature: .webRecipeImport,
    displayName: "Web Recipe Import",
    description: "Import recipes from any cooking website using AI extraction",
    state: .development, // Start in development
    dependencies: [.recipeManagement, .premiumSubscription],
    requiredServices: ["WebScraperService", "ClaudeRecipeStructurer", "ModelContext"],
    testCoverage: 0.0, // No tests yet
    owner: "Import Team",
    introducedVersion: "2.1.0",
    deprecatedVersion: nil,
    removalVersion: nil,
    documentation: """
        Extracts recipes from cooking websites using web scraping + AI.
        Supports major recipe sites: AllRecipes, FoodNetwork, NYT Cooking, etc.
        Premium feature requiring active subscription.
        """
)
```

**Add to CI scripts** (list-features.swift, check-feature-gates.swift, validate-features.swift):
```swift
Feature(name: "webRecipeImport", displayName: "Web Recipe Import",
        category: .premium, state: .development, testCoverage: 0.0, requiresPremium: true)
```

---

### Step 2: Write Tests First (TDD) (8-12 hours)

**Create test structure:**
```
HeirloomTestsV2/Unit/Features/WebRecipeImport/
├── WebScraperTests.swift (baseline)
├── WebScraperAdversarialTests.swift (edge cases)
└── WebRecipeImportIntegrationTests.swift (end-to-end)
```

**Baseline Tests** (WebScraperTests.swift):
```swift
@MainActor
final class WebScraperTests: XCTestCase {
    var scraper: WebScraperService!

    func test_scraper_extractsRecipeFromAllRecipes() async throws {
        // Given: AllRecipes URL
        let url = "https://www.allrecipes.com/recipe/10813/best-chocolate-chip-cookies/"

        // When: Scrape recipe
        let html = try await scraper.fetchHTML(url: url)
        let recipe = try await scraper.extractRecipe(from: html)

        // Then: Should extract recipe data
        XCTAssertFalse(recipe.title.isEmpty)
        XCTAssertGreaterThan(recipe.ingredients?.count ?? 0, 0)
        XCTAssertGreaterThan(recipe.instructions.count, 0)
    }

    func test_scraper_extractsRecipeFromFoodNetwork() async throws {
        // Test with Food Network URL
        // ...
    }

    func test_scraper_extractsRecipeFromNYTCooking() async throws {
        // Test with NYT Cooking URL
        // ...
    }

    func test_scraper_handlesRecipeSchema() async throws {
        // Given: HTML with schema.org Recipe markup
        let html = """
        <script type="application/ld+json">
        {
          "@type": "Recipe",
          "name": "Chocolate Chip Cookies",
          "recipeIngredient": ["2 cups flour", "1 cup sugar"],
          "recipeInstructions": ["Mix", "Bake"]
        }
        </script>
        """

        // When: Extract schema
        let recipe = try scraper.extractSchemaRecipe(from: html)

        // Then: Should parse schema
        XCTAssertEqual(recipe.title, "Chocolate Chip Cookies")
        XCTAssertEqual(recipe.ingredients?.count, 2)
    }
}
```

**Adversarial Tests** (WebScraperAdversarialTests.swift):
```swift
func test_scraper_invalidURL_throwsError()
func test_scraper_nonRecipePage_returnsNil()
func test_scraper_paywall_detectsAndNotifies()
func test_scraper_networkTimeout_retriesGracefully()
func test_scraper_malformedHTML_handlesGracefully()
func test_scraper_missingIngredients_fallsBackToAI()
```

**Integration Tests** (WebRecipeImportIntegrationTests.swift):
```swift
func test_webImport_endToEnd_allRecipes() async throws {
    // Given: Real AllRecipes URL
    let url = "https://www.allrecipes.com/recipe/10813/best-chocolate-chip-cookies/"

    // When: Import via processor
    let processor = WebRecipeProcessor(...)
    let recipe = try await processor.process(url: url, context: modelContext)

    // Then: Complete recipe saved to database
    XCTAssertNotNil(recipe)
    try modelContext.save()

    let fetchDescriptor = FetchDescriptor<Heirloom.Recipe>()
    let recipes = try modelContext.fetch(fetchDescriptor)
    XCTAssertEqual(recipes.count, 1)
}
```

**Run tests (they'll fail - that's expected):**
```bash
xcodebuild test -scheme Heirloom \
  -only-testing:HeirloomTestsV2/Unit/Features/WebRecipeImport
# All tests fail (no implementation yet) ✅ Expected
```

---

### Step 3: Implement Feature (15-20 hours)

**Create service:**
```swift
// Heirloom/Core/Services/WebImport/WebScraperService.swift
final class WebScraperService {
    func fetchHTML(url: String) async throws -> String {
        // Fetch HTML from URL
    }

    func extractRecipe(from html: String) async throws -> Recipe {
        // 1. Try schema.org Recipe markup
        if let schemaRecipe = extractSchemaRecipe(from: html) {
            return schemaRecipe
        }

        // 2. Try site-specific parsers
        if let siteRecipe = extractWithSiteParser(from: html) {
            return siteRecipe
        }

        // 3. Fallback to AI extraction
        return try await extractWithAI(from: html)
    }

    private func extractSchemaRecipe(from html: String) -> Recipe? {
        // Parse schema.org/Recipe JSON-LD
    }

    private func extractWithAI(from html: String) async throws -> Recipe {
        // Use Claude to extract recipe from HTML
        let structurer = ClaudeRecipeStructurer(...)
        return try await structurer.structureFromHTML(html: html, context: modelContext)
    }
}
```

**Create processor:**
```swift
// Heirloom/Core/Services/WebImport/WebRecipeProcessor.swift
final class WebRecipeProcessor {
    let scraper: WebScraperService
    let logger: LoggingService
    let analytics: AnalyticsService

    func process(url: String, context: ModelContext) async throws -> Recipe {
        // 1. Validate URL
        guard isValidURL(url) else {
            throw ValidationError.invalidURL
        }

        // 2. Fetch HTML
        let html = try await scraper.fetchHTML(url: url)

        // 3. Extract recipe
        let recipe = try await scraper.extractRecipe(from: html)

        // 4. Save metadata
        recipe.sourceType = .web
        recipe.sourceURL = url
        recipe.createdAt = Date()

        // 5. Save to database
        context.insert(recipe)
        try context.save()

        // 6. Track analytics
        analytics.track(event: .webRecipeImported, properties: [
            "url": url,
            "hasIngredients": recipe.ingredients?.count ?? 0 > 0
        ])

        return recipe
    }
}
```

**Add UI with feature flag:**
```swift
// Heirloom/Features/Import/WebRecipeImportView.swift
struct WebRecipeImportView: View {
    @State private var flagManager = FeatureFlagManager.shared
    @State private var url: String = ""

    var body: some View {
        if flagManager.isEnabled(.webRecipeImport) {
            VStack {
                TextField("Paste recipe URL", text: $url)
                Button("Import Recipe") {
                    Task {
                        await importRecipe()
                    }
                }
            }
        } else {
            FeatureDisabledView(feature: .webRecipeImport)
        }
    }

    func importRecipe() async {
        let processor = WebRecipeProcessor(...)
        let recipe = try? await processor.process(url: url, context: modelContext)
        // Handle result
    }
}
```

**Run tests again (should pass now):**
```bash
xcodebuild test -scheme Heirloom \
  -only-testing:HeirloomTestsV2/Unit/Features/WebRecipeImport
# Tests pass ✅
```

---

### Step 4: Update Test Coverage (1-2 hours)

**Update metadata:**
```swift
// FeatureRegistryData.swift
.webRecipeImport: FeatureMetadata(
    // ...
    testCoverage: 0.65, // 65% coverage achieved
    // ...
)
```

**Update CI scripts:**
```swift
// scripts/check-feature-gates.swift, list-features.swift
Feature(name: "webRecipeImport", state: .development, testCoverage: 0.65, ...)
```

**Verify gates:**
```bash
./scripts/feature-tool.sh gates
# webRecipeImport [Development] 65% (req: 0%) ✅ PASS
```

---

### Step 5: Move to Alpha (2-3 hours)

**Update state:**
```swift
// FeatureRegistryData.swift
state: .alpha, // Changed from .development
```

**Add more tests to reach 40%:**
```bash
./scripts/feature-tool.sh gates
# webRecipeImport [Alpha] 65% (req: 40%) ✅ PASS
```

**Enable for internal testing:**
```swift
// In debug menu, toggle on
flagManager.setLocalOverride(.webRecipeImport, enabled: true)
```

**Test manually:**
- Try various recipe websites
- Verify data extraction quality
- Test error handling
- Check premium gate works

---

### Step 6: Move to Beta (Add Tests) (4-6 hours)

**Update state:**
```swift
state: .beta, // Changed from .alpha
```

**Add tests to reach 60%:**
- Add more adversarial tests
- Add performance tests
- Add integration tests with various sites

**Verify gates:**
```bash
./scripts/feature-tool.sh gates
# webRecipeImport [Beta] 65% (req: 60%) ✅ PASS
```

**Enable for beta testers via Firebase:**
1. Go to Firebase Console → Remote Config
2. Add parameter: `web_recipe_import`
3. Create condition: `beta_testers` (10% of users)
4. Set value: `true` for beta testers, `false` for others
5. Publish changes

---

### Step 7: Release Preparation (Add Tests to 80%) (6-8 hours)

**Update state:**
```swift
state: .released, // Changed from .beta
```

**Add tests to reach 80%:**
- Comprehensive integration tests
- All major recipe sites covered
- All error paths tested
- Performance benchmarks

**Verify gates:**
```bash
./scripts/feature-tool.sh gates
# webRecipeImport [Released] 82% (req: 80%) ✅ PASS
```

**CI must pass:**
```bash
git add .
git commit -m "feat: Add web recipe import (80% coverage)"
git push
# CI runs, validates coverage gates ✅
```

---

### Step 8: Production Rollout (Follow PRODUCTION_ROLLOUT_GUIDE.md)

**Week 1: 10% Rollout**
- Firebase: Set to 10% of users
- Monitor for 48 hours
- Check: Crash rate < 1%, support tickets < 5%

**Week 2: 50% Rollout**
- Firebase: Increase to 50%
- Monitor for 72 hours
- Check: No new critical bugs

**Week 3: 100% Rollout**
- Firebase: Set default to `true`
- Monitor for 1 week
- Feature fully deployed! 🎉

---

## Quick Reference

### Feature Lifecycle States

| State | Coverage Required | Purpose |
|-------|------------------|---------|
| **Development** | 0% | Early implementation, rapid iteration |
| **Alpha** | 40% | Internal testing, basic validation |
| **Beta** | 60% | Public beta, validated logic |
| **Released** | 80% | Production, high confidence |
| **Deprecated** | 80% | Marked for removal, maintain quality |
| **Removed** | 0% | No longer in codebase |

### When to Use Each State

**Development** → **Alpha** (40% coverage):
- Feature works for happy path
- Basic error handling
- Ready for internal testing

**Alpha** → **Beta** (60% coverage):
- Edge cases covered
- Error paths tested
- Performance acceptable
- Ready for public beta

**Beta** → **Released** (80% coverage):
- Comprehensive test coverage
- All major sites/scenarios tested
- Integration tests pass
- CI gates pass
- Ready for production

### Coverage Targets by Priority

```
Priority = (Risk × Complexity × Usage) / Test Effort

High Priority (Score > 100):
- Critical paths: 100% (payments, subscriptions)
- Released features: 80%
- Integration points: 80%

Medium Priority (Score 50-100):
- Beta features: 60%
- Complex algorithms: 70%

Low Priority (Score < 50):
- Alpha features: 40%
- Development features: 0%
- Trivial getters: 0% (don't test)
```

### CLI Tools

```bash
# List all features
./scripts/feature-tool.sh list

# Check if feature meets lifecycle gate
./scripts/feature-tool.sh gates

# Validate feature dependencies
./scripts/feature-tool.sh validate

# Check test coverage
./scripts/feature-tool.sh coverage
```

---

## Common Patterns

### Pattern 1: Premium Feature

```swift
// 1. Define feature
case myPremiumFeature = "my_premium_feature"

// 2. Mark as premium
var requiresPremium: Bool {
    case .myPremiumFeature: return true
}

// 3. Check in UI
if flagManager.isAvailable(.myPremiumFeature, subscriptionManager: subManager) {
    // Show feature (checks both flag AND premium status)
}
```

### Pattern 2: Feature with Dependencies

```swift
// In FeatureRegistryData.swift
dependencies: [.recipeManagement, .premiumSubscription]

// Validate before using
let registry = FeatureRegistry.shared
if let errors = registry.validateDependencies() {
    // Handle dependency errors
}
```

### Pattern 3: Gradual Rollout

```swift
// Firebase Remote Config conditions:
// 1. Create: my_feature_10_percent (10% of users)
// 2. Wait 48 hours, monitor
// 3. Update to 50%
// 4. Wait 72 hours, monitor
// 5. Set default to true (100%)
```

### Pattern 4: Emergency Rollback

```swift
// In Firebase Console:
// 1. Set my_feature = false
// 2. Publish changes
// 3. Feature disabled within 12 hours (cache TTL)

// For immediate effect:
// 1. Set fetch interval to 0 hours (temporary)
// 2. Publish
// 3. Restore to 12 hours after incident
```

---

## Testing Checklist

Before moving feature between states:

### Development → Alpha (40% coverage)
- [ ] Baseline tests pass (happy path)
- [ ] Basic error handling tested
- [ ] Integration with core services works
- [ ] Manual testing successful
- [ ] Feature flag works (on/off)

### Alpha → Beta (60% coverage)
- [ ] Adversarial tests added (edge cases)
- [ ] Error paths tested
- [ ] Performance acceptable (< 2 sec for user operations)
- [ ] Tested on multiple scenarios/inputs
- [ ] Beta users feedback positive

### Beta → Released (80% coverage)
- [ ] Comprehensive test coverage
- [ ] All integration tests pass
- [ ] CI gates pass (`./scripts/feature-tool.sh gates`)
- [ ] No known critical bugs
- [ ] Performance meets targets
- [ ] Documentation complete
- [ ] Analytics tracking verified
- [ ] Premium gate (if applicable) tested

---

## Anti-Patterns (What NOT to Do)

❌ **Don't skip tests**: "I'll add tests later" → never happens

❌ **Don't mock everything**: Integration tests need real dependencies

❌ **Don't test trivial code**: Getters/setters waste time

❌ **Don't deploy without flag**: Always wrap new features

❌ **Don't skip gradual rollout**: 0% → 100% is risky

❌ **Don't ignore CI failures**: Coverage gates exist for a reason

❌ **Don't ship without monitoring**: Set up analytics first

---

## Resources

- **Feature Management Summary**: `FEATURE_MANAGEMENT_SUMMARY.md`
- **Production Rollout Guide**: `PRODUCTION_ROLLOUT_GUIDE.md`
- **Test Coverage Strategy**: `TEST_COVERAGE_STRATEGY.md`
- **AI Pipeline Testing**: `AI_PIPELINE_TEST_GAPS.md`
- **Firebase Setup**: `FIREBASE_REMOTE_CONFIG_SETUP.md`
- **CI/CD Scripts**: `scripts/README.md`

---

## Next Steps

Ready to add your feature? Follow these steps:

1. **Read this guide** (you're here!)
2. **Define feature metadata** (Step 1)
3. **Write tests first** (Step 2) - TDD approach
4. **Implement with flag** (Step 3)
5. **Iterate through states** (Steps 4-7) - Development → Alpha → Beta → Released
6. **Deploy gradually** (Step 8) - 10% → 50% → 100%

Questions? Check the guides above or open an issue.

**Good luck! 🚀**
