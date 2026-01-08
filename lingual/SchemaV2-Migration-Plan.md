# SchemaV2 Migration Plan: Multilingual Recipe Import

## Status: DESIGN PHASE
**Created:** 2026-01-06
**Purpose:** Add optional language fields to Recipe and Ingredient models without breaking existing data

---

## Overview

### Goal
Extend SwiftData schema from V1 → V2 to support multilingual recipe imports while maintaining **100% backward compatibility** with existing recipes.

### Key Principles
1. **All new fields are optional** (nullable) - existing recipes work unchanged
2. **Default values preserve current behavior** - English recipes default to `sourceLanguage = "en"`, `confidence = 1.0`
3. **No data loss** - migration transforms V1 → V2 losslessly
4. **Type-safe fields** - Use proper SwiftData types, NOT JSON blobs
5. **Queryable** - Can filter by `sourceLanguage`, index for performance

---

## Recipe Model Extensions

### New Fields (SchemaV2)

```swift
// MARK: - Multilingual Support (SchemaV2)
/// ISO 639-1 language code of the source recipe ("en", "ja", "ko", "es", "fr", "de", "zh")
var sourceLanguage: String? = "en"

/// Confidence score of language detection (0.0-1.0)
var sourceLanguageConfidence: Double? = 1.0

/// Original title in source language (preserved for display)
var originalTitle: String?

/// Original instructions in source language (preserved for Artifact View)
var originalInstructions: [String]?

/// Translated title (if recipe was translated from foreign language)
var translatedTitle: String?

/// Translated instructions (if recipe was translated)
var translatedInstructions: [String]?

/// Original measurement system detected ("metric" or "imperial")
/// Based on ingredient units (e.g., "grams" → metric, "cups" → imperial)
var detectedUnitSystem: String?

/// User preference: should we show original or translated version?
var preferOriginalLanguage: Bool = false

/// Translation quality indicator ("excellent", "good", "needs_review")
var translationQuality: String?

/// When was this recipe translated (for cache invalidation)
var translatedAt: Date?
```

### Migration Logic: Recipe

**For existing recipes (V1 → V2):**
```swift
// SchemaV2 migration
VersionedSchema(version: Schema.Version(2, 0, 0)) {
    // ... existing models ...

    // Migration plan
    MigrationPlan {
        Stage("Add multilingual fields") {
            // All existing recipes default to English
            .transformModel(from: RecipeV1.self, to: RecipeV2.self) { old in
                var new = old

                // Default: existing recipes are English with high confidence
                new.sourceLanguage = "en"
                new.sourceLanguageConfidence = 1.0

                // No original text (recipe is already in English)
                new.originalTitle = nil
                new.originalInstructions = nil

                // No translation (already English)
                new.translatedTitle = nil
                new.translatedInstructions = nil

                // Detect unit system from ingredients
                new.detectedUnitSystem = detectUnitSystem(old.ingredients)

                // Default: show current language (English)
                new.preferOriginalLanguage = false

                return new
            }
        }
    }
}

/// Helper: detect if recipe uses metric or imperial units
private func detectUnitSystem(_ ingredients: [Ingredient]?) -> String {
    guard let ingredients = ingredients else { return "imperial" }

    let metricUnits = ["gram", "g", "kg", "kilogram", "ml", "milliliter", "l", "liter"]
    let imperialUnits = ["cup", "tablespoon", "teaspoon", "oz", "ounce", "pound", "lb"]

    var metricCount = 0
    var imperialCount = 0

    for ingredient in ingredients {
        let unit = ingredient.unit?.lowercased() ?? ""
        if metricUnits.contains(where: { unit.contains($0) }) {
            metricCount += 1
        }
        if imperialUnits.contains(where: { unit.contains($0) }) {
            imperialCount += 1
        }
    }

    // If >70% metric, mark as metric
    let total = metricCount + imperialCount
    if total > 0 && Double(metricCount) / Double(total) > 0.7 {
        return "metric"
    }

    return "imperial"  // Default for US recipes
}
```

---

## Ingredient Model Extensions

### New Fields (SchemaV2)

```swift
// MARK: - Multilingual Support (SchemaV2)
/// Original ingredient name in source language
var originalLanguageName: String?

/// Translated ingredient name (if translated)
var translatedName: String?

/// Original unit before conversion (e.g., "カップ" for Japanese cup)
var originalLanguageUnit: String?

/// Quantity after unit conversion (e.g., Japanese 200ml cup → 0.83 US cups)
var convertedQuantity: Double?

/// Unit after conversion (e.g., "cup" after converting from Japanese "カップ")
var convertedUnit: String?

/// Human-readable explanation of conversion
/// Example: "Japanese cup (200ml) converted to US cup (240ml)"
var conversionNote: String?

/// Whether this ingredient required regional unit conversion
var wasConverted: Bool = false
```

### Migration Logic: Ingredient

**For existing ingredients (V1 → V2):**
```swift
.transformModel(from: IngredientV1.self, to: IngredientV2.self) { old in
    var new = old

    // Existing ingredients have no original language text
    new.originalLanguageName = nil
    new.translatedName = nil
    new.originalLanguageUnit = nil

    // No conversion needed for existing English ingredients
    new.convertedQuantity = nil
    new.convertedUnit = nil
    new.conversionNote = nil
    new.wasConverted = false

    return new
}
```

---

## Schema File Structure

### Current: SchemaV1.swift
```swift
// Heirloom/Core/Models/SchemaV1.swift
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Recipe.self,
            Ingredient.self,
            // ... 14 other models ...
        ]
    }
}
```

### New: SchemaV2.swift (to create)
```swift
// Heirloom/Core/Models/SchemaV2.swift
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Recipe.self,
            Ingredient.self,
            // ... 14 other models (unchanged) ...
        ]
    }

    // Migration plan from V1 → V2
    static var migrationPlan: MigrationPlan {
        MigrationPlan([.transformRecipes, .transformIngredients])
    }
}
```

### Migration Stages

```swift
extension MigrationStage {
    static var transformRecipes: Self {
        .custom(
            fromVersion: SchemaV1.self,
            toVersion: SchemaV2.self,
            willMigrate: { context in
                Log.info("Starting Recipe migration V1 → V2", category: .database)
            },
            didMigrate: { context in
                Log.info("Completed Recipe migration V1 → V2", category: .database)
            }
        )
    }

    static var transformIngredients: Self {
        .custom(
            fromVersion: SchemaV1.self,
            toVersion: SchemaV2.self,
            willMigrate: { context in
                Log.info("Starting Ingredient migration V1 → V2", category: .database)
            },
            didMigrate: { context in
                Log.info("Completed Ingredient migration V1 → V2", category: .database)
            }
        )
    }
}
```

---

## Testing Strategy

### Unit Tests: Migration Validation

**File:** `/HeirloomTests/Migration/SchemaV2MigrationTests.swift`

```swift
@MainActor
final class SchemaV2MigrationTests: XCTestCase {

    func testMigration_ExistingEnglishRecipe_DefaultsToEnglish() throws {
        // Given: V1 recipe
        let v1Recipe = createV1Recipe(title: "Chocolate Chip Cookies")

        // When: Migrate to V2
        let v2Recipe = migrateToV2(v1Recipe)

        // Then: Defaults applied correctly
        XCTAssertEqual(v2Recipe.sourceLanguage, "en")
        XCTAssertEqual(v2Recipe.sourceLanguageConfidence, 1.0)
        XCTAssertNil(v2Recipe.originalTitle)
        XCTAssertNil(v2Recipe.translatedTitle)
    }

    func testMigration_ExistingIngredient_NoConversionNeeded() throws {
        // Given: V1 ingredient
        let v1Ingredient = createV1Ingredient("1 cup flour")

        // When: Migrate to V2
        let v2Ingredient = migrateToV2(v1Ingredient)

        // Then: No conversion fields populated
        XCTAssertNil(v2Ingredient.convertedQuantity)
        XCTAssertNil(v2Ingredient.convertedUnit)
        XCTAssertFalse(v2Ingredient.wasConverted)
    }

    func testMigration_MetricRecipe_DetectsMetricSystem() throws {
        // Given: Recipe with metric ingredients
        let recipe = createRecipeWithIngredients([
            "250 grams flour",
            "500 ml water",
            "2 kg sugar"
        ])

        // When: Migration detects unit system
        let migrated = migrateToV2(recipe)

        // Then: System detected as metric
        XCTAssertEqual(migrated.detectedUnitSystem, "metric")
    }

    func testMigration_AllExistingRecipes_Preserved() throws {
        // Given: Database with 100 V1 recipes
        let v1Recipes = createTestRecipes(count: 100)

        // When: Migrate all to V2
        let v2Recipes = migrateAll(v1Recipes)

        // Then: All data preserved
        XCTAssertEqual(v2Recipes.count, 100)
        for (v1, v2) in zip(v1Recipes, v2Recipes) {
            XCTAssertEqual(v1.title, v2.title)
            XCTAssertEqual(v1.instructions, v2.instructions)
            XCTAssertEqual(v1.ingredients?.count, v2.ingredients?.count)
        }
    }
}
```

### Integration Tests: Real Database Migration

**File:** `/HeirloomTests/Integration/RealDatabaseMigrationTests.swift`

```swift
@MainActor
final class RealDatabaseMigrationTests: XCTestCase {

    func testRealMigration_WithUserData() throws {
        // Given: Actual V1 database with user's recipes
        let v1Container = createV1Container()
        let v1Context = ModelContext(v1Container)

        // Seed with realistic data
        seedTestData(v1Context)

        // When: Perform real migration
        let v2Container = createV2Container()
        // Migration happens automatically on first access
        let v2Context = ModelContext(v2Container)

        // Then: Verify migration succeeded
        let descriptor = FetchDescriptor<Recipe>()
        let migratedRecipes = try v2Context.fetch(descriptor)

        XCTAssertGreaterThan(migratedRecipes.count, 0)

        // Verify new fields present
        for recipe in migratedRecipes {
            XCTAssertNotNil(recipe.sourceLanguage)
            XCTAssertNotNil(recipe.sourceLanguageConfidence)
        }
    }

    func testRollback_IfMigrationFails() throws {
        // Given: V1 database
        let v1Container = createV1Container()

        // When: Migration encounters error
        // Then: Should rollback to V1
        // (SwiftData handles this automatically)
    }
}
```

---

## Backward Compatibility Guarantees

### What MUST NOT Break

1. **Existing queries work unchanged**
   ```swift
   // This query MUST still work
   let descriptor = FetchDescriptor<Recipe>()
   let recipes = try context.fetch(descriptor)
   ```

2. **Existing recipe display works unchanged**
   ```swift
   // title, instructions, ingredients all accessible as before
   Text(recipe.title)
   ForEach(recipe.instructions, id: \.self) { Text($0) }
   ```

3. **Existing tests pass 100%**
   ```bash
   xcodebuild test -only-testing:HeirloomTests/EnglishImportRegressionTests
   # ALL tests must pass
   ```

### What Changes (New Functionality Only)

1. **New queries possible**
   ```swift
   // Filter by language
   let japaneseRecipes = FetchDescriptor<Recipe>(
       predicate: #Predicate { $0.sourceLanguage == "ja" }
   )
   ```

2. **Translation toggle available**
   ```swift
   if let originalTitle = recipe.originalTitle {
       Toggle("Show Original", isOn: $recipe.preferOriginalLanguage)
   }
   ```

---

## Rollout Plan

### Phase 1: Create SchemaV2 (Current)
- [ ] Create `SchemaV2.swift` file
- [ ] Add migration logic
- [ ] Update `Recipe.swift` with new fields
- [ ] Update `Ingredient.swift` with new fields
- [ ] Write migration tests

### Phase 2: Test Migration
- [ ] Run migration tests
- [ ] Verify backward compatibility (regression tests)
- [ ] Test with realistic data (10,000+ recipes)
- [ ] Performance benchmarks (migration < 5 seconds)

### Phase 3: Deploy
- [ ] Update app's ModelContainer to use SchemaV2
- [ ] Add migration monitoring/logging
- [ ] Gradual rollout (1% → 10% → 50% → 100%)

---

## Performance Considerations

### Migration Speed
- **Goal:** < 5 seconds for 10,000 recipes
- **Strategy:** Batch transformations, minimal computation
- **Monitoring:** Log migration time, alert if > 10s

### Storage Impact
- **New fields:** ~200 bytes per recipe
- **10,000 recipes:** ~2 MB additional storage
- **Acceptable:** < 0.1% of typical device storage

### Query Performance
- **Index:** `sourceLanguage` field for fast filtering
- **Impact:** Negligible (optional field, rarely queried)

---

## Risk Mitigation

### Risk 1: Migration Fails
**Mitigation:** SwiftData auto-rollback on failure
**Test:** Simulate failures in test environment

### Risk 2: Data Corruption
**Mitigation:** Migration logic preserves all V1 fields
**Test:** Compare V1 vs V2 data checksums

### Risk 3: Performance Degradation
**Mitigation:** Performance tests before/after
**Test:** Benchmark query/save speed with 10K recipes

---

## Files to Create/Modify

### Create New
- `/Heirloom/Core/Models/SchemaV2.swift` - New schema definition
- `/HeirloomTests/Migration/SchemaV2MigrationTests.swift` - Migration tests
- `/HeirloomTests/Integration/RealDatabaseMigrationTests.swift` - Integration tests

### Modify Existing
- `/Heirloom/Core/Models/Recipe.swift` - Add multilingual fields
- `/Heirloom/Core/Models/Ingredient.swift` - Add conversion fields
- `/Heirloom/Core/Models/SchemaV1.swift` - Add migration plan reference
- `/Heirloom/HeirloomApp.swift` - Update ModelContainer to SchemaV2

---

## Next Steps

1. **Review this plan** with Systems Architect agent for validation
2. **Create SchemaV2.swift** with migration logic
3. **Extend Recipe.swift** with new fields (documented above)
4. **Extend Ingredient.swift** with new fields (documented above)
5. **Write migration tests** (30+ tests)
6. **Run regression suite** to verify zero breakage

---

**Status:** READY FOR IMPLEMENTATION
**Confidence:** HIGH (follows SwiftData best practices, all fields optional, backward compatible)
**Risk:** LOW (extensive testing plan, gradual rollout, auto-rollback on failure)
