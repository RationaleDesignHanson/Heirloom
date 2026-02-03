# Pending Tests

## Auto-Fix Recipe Scaling (2026-02-02)

### Unit Tests

#### IngredientTests.swift

```swift
// MARK: - Flexible Quantity Detection

func testFlexibleQuantity_ToTaste() {
    // Ingredient: "Salt to taste"
    let ingredient = Ingredient(originalText: "Salt to taste", name: "Salt", quantity: nil)
    XCTAssertTrue(ingredient.isFlexibleQuantity, "Should recognize 'to taste' pattern")
}

func testFlexibleQuantity_Pinch() {
    // Ingredient: "1 pinch black pepper"
    let ingredient = Ingredient(originalText: "1 pinch black pepper", name: "black pepper", quantity: nil)
    XCTAssertTrue(ingredient.isFlexibleQuantity, "Should recognize 'pinch' pattern")
}

func testFlexibleQuantity_SpiceCategory() {
    // Ingredient with nil quantity in spices category
    let ingredient = Ingredient(originalText: "black pepper", name: "black pepper", quantity: nil, category: .spices)
    XCTAssertTrue(ingredient.isFlexibleQuantity, "Should recognize spices category")
}

func testFlexibleQuantity_SaltByName() {
    // Ingredient named "salt" with nil quantity
    let ingredient = Ingredient(originalText: "salt", name: "salt", quantity: nil)
    XCTAssertTrue(ingredient.isFlexibleQuantity, "Should recognize salt by name")
}

func testFlexibleQuantity_RegularIngredient() {
    // Ingredient: "flour" (missing quantity, but not flexible)
    let ingredient = Ingredient(originalText: "flour", name: "flour", quantity: nil, category: .pantry)
    XCTAssertFalse(ingredient.isFlexibleQuantity, "Regular ingredient with missing quantity should not be flexible")
}

func testFlexibleQuantity_WithQuantity() {
    // Ingredient: "2 cups flour" (has quantity)
    let ingredient = Ingredient(originalText: "2 cups flour", name: "flour", quantity: 2.0, unit: "cup", category: .pantry)
    XCTAssertFalse(ingredient.isFlexibleQuantity, "Ingredient with quantity should not be flexible")
}
```

#### ServingsParserTests.swift

```swift
// MARK: - Confidence Scoring

func testConfidence_KeywordMatch() {
    let result = ServingsParser.parseWithConfidence("Serves 6")
    if case .confident(let count) = result {
        XCTAssertEqual(count, 6)
    } else {
        XCTFail("Should be confident parse")
    }
}

func testConfidence_MakesKeyword() {
    let result = ServingsParser.parseWithConfidence("Makes 12 cookies")
    if case .confident(let count) = result {
        XCTAssertEqual(count, 12)
    } else {
        XCTFail("Should be confident parse")
    }
}

func testConfidence_YieldsKeyword() {
    let result = ServingsParser.parseWithConfidence("Yields 4-6 servings")
    if case .confident(let count) = result {
        XCTAssertEqual(count, 4)
    } else {
        XCTFail("Should be confident parse")
    }
}

func testConfidence_NumberOnly() {
    let result = ServingsParser.parseWithConfidence("4")
    if case .uncertain(let count) = result {
        XCTAssertEqual(count, 4)
    } else {
        XCTFail("Should be uncertain parse")
    }
}

func testConfidence_NumberWithPeople() {
    let result = ServingsParser.parseWithConfidence("6 people")
    // Note: "people" is a keyword, so this should be confident
    if case .confident(let count) = result {
        XCTAssertEqual(count, 6)
    } else {
        XCTFail("Should be confident parse")
    }
}

func testConfidence_Unparseable_Nil() {
    let result = ServingsParser.parseWithConfidence(nil)
    if case .unparseable = result {
        // Success
    } else {
        XCTFail("Should be unparseable")
    }
}

func testConfidence_Unparseable_EmptyString() {
    let result = ServingsParser.parseWithConfidence("")
    if case .unparseable = result {
        // Success
    } else {
        XCTFail("Should be unparseable")
    }
}

func testConfidence_Unparseable_NonNumeric() {
    let result = ServingsParser.parseWithConfidence("some")
    if case .unparseable = result {
        // Success
    } else {
        XCTFail("Should be unparseable")
    }
}

func testConfidence_FourServings() {
    // CRITICAL: "4 servings" should be confident(4), not uncertain(4)
    let result = ServingsParser.parseWithConfidence("4 servings")
    if case .confident(let count) = result {
        XCTAssertEqual(count, 4)
    } else {
        XCTFail("'4 servings' should be confident parse, got \(result)")
    }
}

func testConfidence_DozenKeyword() {
    let result = ServingsParser.parseWithConfidence("Makes 2 dozen")
    if case .confident(let count) = result {
        XCTAssertEqual(count, 24)
    } else {
        XCTFail("Should be confident parse for dozen keyword")
    }
}
```

#### Recipe+ScalingTests.swift

```swift
// MARK: - Validation with Flexible Quantities

func testValidation_IgnoresToTaste() {
    // Recipe with only "to taste" ingredients
    let recipe = Recipe(title: "Test Recipe")
    let ingredient1 = Ingredient(originalText: "salt to taste", name: "salt", quantity: nil)
    let ingredient2 = Ingredient(originalText: "pepper to taste", name: "pepper", quantity: nil)
    recipe.ingredients = [ingredient1, ingredient2]
    recipe.servings = "4 servings"

    let validation = recipe.scalingValidation
    XCTAssertTrue(validation.isFullyScalable, "Recipe with only 'to taste' ingredients should be fully scalable")
    XCTAssertTrue(validation.issues.isEmpty, "Should have no issues")
}

func testValidation_FlagsTruelyMissing() {
    // Recipe with truly missing quantity
    let recipe = Recipe(title: "Test Recipe")
    let ingredient1 = Ingredient(originalText: "flour", name: "flour", quantity: nil, category: .pantry)
    let ingredient2 = Ingredient(originalText: "salt to taste", name: "salt", quantity: nil)
    recipe.ingredients = [ingredient1, ingredient2]
    recipe.servings = "4 servings"

    let validation = recipe.scalingValidation
    XCTAssertFalse(validation.isFullyScalable, "Recipe with missing flour quantity should not be scalable")
    XCTAssertEqual(validation.issues.count, 1, "Should have 1 issue")

    if case .missingQuantities(let count, let total) = validation.issues.first {
        XCTAssertEqual(count, 1, "Should report 1 missing quantity (flour)")
        XCTAssertEqual(total, 2, "Should have 2 total ingredients")
    } else {
        XCTFail("Should have missingQuantities issue")
    }
}

func testValidation_AllowsConfidentFour() {
    // Recipe with "4 servings" (confident parse)
    let recipe = Recipe(title: "Test Recipe")
    recipe.servings = "4 servings"
    let ingredient = Ingredient(originalText: "2 cups flour", name: "flour", quantity: 2.0, unit: "cup")
    recipe.ingredients = [ingredient]

    let validation = recipe.scalingValidation
    XCTAssertTrue(validation.isFullyScalable, "Recipe with '4 servings' should be fully scalable")
}

func testValidation_AllowsUncertainFour() {
    // Recipe with just "4" (uncertain parse, but still allowed)
    let recipe = Recipe(title: "Test Recipe")
    recipe.servings = "4"
    let ingredient = Ingredient(originalText: "2 cups flour", name: "flour", quantity: 2.0, unit: "cup")
    recipe.ingredients = [ingredient]

    let validation = recipe.scalingValidation
    XCTAssertTrue(validation.isFullyScalable, "Recipe with uncertain '4' should still be scalable")
}

func testValidation_FlagsUnparseable() {
    // Recipe with unparseable servings
    let recipe = Recipe(title: "Test Recipe")
    recipe.servings = "some"
    let ingredient = Ingredient(originalText: "2 cups flour", name: "flour", quantity: 2.0, unit: "cup")
    recipe.ingredients = [ingredient]

    let validation = recipe.scalingValidation
    XCTAssertFalse(validation.isFullyScalable, "Recipe with unparseable servings should not be scalable")
    XCTAssertEqual(validation.issues.count, 1, "Should have 1 issue")

    if case .servingsUnparseable = validation.issues.first {
        // Success
    } else {
        XCTFail("Should have servingsUnparseable issue")
    }
}

func testValidation_ErrorMessageExcludesSeasonings() {
    // Verify error message says "excluding seasonings"
    let recipe = Recipe(title: "Test Recipe")
    let ingredient1 = Ingredient(originalText: "flour", name: "flour", quantity: nil, category: .pantry)
    let ingredient2 = Ingredient(originalText: "salt to taste", name: "salt", quantity: nil)
    recipe.ingredients = [ingredient1, ingredient2]
    recipe.servings = "4 servings"

    let validation = recipe.scalingValidation
    let message = validation.issues.first?.userMessage ?? ""
    XCTAssertTrue(message.contains("excluding seasonings"), "Error message should clarify 'excluding seasonings'")
}

// MARK: - Inferred Serving Count

func testInferredServingCount_ParsedServings() {
    let recipe = Recipe(title: "Test Recipe")
    recipe.servings = "6 servings"
    XCTAssertEqual(recipe.inferredServingCount, 6)
}

func testInferredServingCount_CategoryDefault() {
    let recipe = Recipe(title: "Test Recipe")
    recipe.servings = nil
    recipe.category = .cookies
    XCTAssertEqual(recipe.inferredServingCount, 12, "Cookies should default to 12")
}

func testInferredServingCount_FallbackDefault() {
    let recipe = Recipe(title: "Test Recipe")
    recipe.servings = nil
    recipe.category = nil
    XCTAssertEqual(recipe.inferredServingCount, 4, "Should fallback to 4")
}
```

### Integration Tests

#### ScalingRepairSheetTests.swift

```swift
// MARK: - Servings Repair

func testServingsRepair_CategoryDefault() {
    // Recipe with nil servings + cookie category
    let recipe = Recipe(title: "Chocolate Chip Cookies")
    recipe.servings = nil
    recipe.category = .cookies

    let sheet = ScalingRepairSheet(recipe: recipe)
    let repaired = sheet.attemptServingsRepair()

    XCTAssertTrue(repaired, "Should successfully repair")
    XCTAssertEqual(recipe.servings, "12 servings", "Should set to cookie default")
}

func testServingsRepair_TitleInference_Dozen() {
    // Recipe with "dozen" in title
    let recipe = Recipe(title: "Grandma's Dozen Cookies")
    recipe.servings = nil

    let sheet = ScalingRepairSheet(recipe: recipe)
    let repaired = sheet.attemptServingsRepair()

    XCTAssertTrue(repaired)
    XCTAssertEqual(recipe.servings, "12 servings")
}

func testServingsRepair_TitleInference_DoubleBatch() {
    // Recipe titled "Double Batch Cookies"
    let recipe = Recipe(title: "Double Batch Cookies")
    recipe.servings = nil

    let sheet = ScalingRepairSheet(recipe: recipe)
    let repaired = sheet.attemptServingsRepair()

    XCTAssertTrue(repaired)
    XCTAssertEqual(recipe.servings, "24 servings")
}

func testServingsRepair_AlreadyConfident() {
    // Recipe with confident parse (no repair needed)
    let recipe = Recipe(title: "Test Recipe")
    recipe.servings = "Serves 6"

    let sheet = ScalingRepairSheet(recipe: recipe)
    let repaired = sheet.attemptServingsRepair()

    XCTAssertTrue(repaired, "Should return true (already good)")
    XCTAssertEqual(recipe.servings, "Serves 6", "Should not modify")
}

// MARK: - Full Repair Flow

func testFullRepair_OnlyToTasteIngredients() {
    // Import recipe with "salt to taste"
    let recipe = Recipe(title: "Test Recipe")
    recipe.servings = "4 servings"
    let ingredient = Ingredient(originalText: "salt to taste", name: "salt", quantity: nil)
    recipe.ingredients = [ingredient]

    // Before repair
    let validationBefore = recipe.scalingValidation
    XCTAssertTrue(validationBefore.isFullyScalable, "Should already be scalable")

    // After repair (should not need repair)
    // Verify salt shows "Adjust to taste" in UI (manual UI test)
}
```

### Edge Cases

```swift
// MARK: - Edge Cases

func testEdgeCase_MixedIngredients() {
    // Recipe with both "salt to taste" AND missing flour quantity
    let recipe = Recipe(title: "Test Recipe")
    recipe.servings = "4 servings"
    let ingredient1 = Ingredient(originalText: "flour", name: "flour", quantity: nil, category: .pantry)
    let ingredient2 = Ingredient(originalText: "salt to taste", name: "salt", quantity: nil)
    recipe.ingredients = [ingredient1, ingredient2]

    let validation = recipe.scalingValidation
    XCTAssertFalse(validation.isFullyScalable)
    XCTAssertEqual(validation.issues.count, 1)

    if case .missingQuantities(let count, let total) = validation.issues.first {
        XCTAssertEqual(count, 1, "Should show '1 of 2 ingredients missing quantities (excluding seasonings)'")
        XCTAssertEqual(total, 2)
    }
}

func testEdgeCase_AllSpices() {
    // Recipe with all spices (all nil quantities)
    let recipe = Recipe(title: "Spice Blend")
    recipe.servings = "1 cup"
    let ingredient1 = Ingredient(originalText: "cumin", name: "cumin", quantity: nil, category: .spices)
    let ingredient2 = Ingredient(originalText: "paprika", name: "paprika", quantity: nil, category: .spices)
    recipe.ingredients = [ingredient1, ingredient2]

    let validation = recipe.scalingValidation
    XCTAssertTrue(validation.isFullyScalable, "Spice blend with all flexible quantities should be scalable")
}

func testEdgeCase_OptionalIngredient() {
    // Ingredient marked as optional with nil quantity
    let ingredient = Ingredient(originalText: "fresh herbs (optional)", name: "fresh herbs", quantity: nil)
    ingredient.isOptional = true

    XCTAssertTrue(ingredient.isFlexibleQuantity, "Optional ingredients should be flexible")
}
```

### Manual UI Tests

1. **Import flow with "to taste":**
   - Import recipe with "salt to taste"
   - Verify validation shows no issues
   - Verify scaling UI doesn't show warning banner
   - Scale recipe to 2x
   - Verify salt shows "Adjust to taste" in scaled view

2. **Repair flow:**
   - Create recipe with nil servings + cookie category
   - Tap "Fix" button
   - Verify servings auto-filled to "12 servings"
   - Verify no more warnings shown

3. **Mixed ingredients:**
   - Recipe with "flour" (missing qty) + "salt to taste"
   - Verify shows: "1 of 2 ingredients missing quantities (excluding seasonings)"
   - Tap "Fix"
   - After AI re-parsing fixes flour, verify fully scalable

## Seasoning Suggestions Tests (2026-02-02)

### SeasoningDefaultsTests.swift

```swift
// MARK: - Base Defaults

func testSeasoningDefaults_Salt() {
    let result = SeasoningDefaults.suggestedAmount(
        for: "salt",
        servingCount: 4,
        category: nil
    )

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.unit, "tsp")
    XCTAssertEqual(result?.typical, 1.0, accuracy: 0.1)
}

func testSeasoningDefaults_BlackPepper() {
    let result = SeasoningDefaults.suggestedAmount(
        for: "black pepper",
        servingCount: 4,
        category: nil
    )

    XCTAssertNotNil(result)
    XCTAssertEqual(result?.typical, 0.5, accuracy: 0.1)
}

func testSeasoningDefaults_CategoryAdjustment() {
    let soupSalt = SeasoningDefaults.suggestedAmount(
        for: "salt",
        servingCount: 4,
        category: .soupStew
    )

    let regularSalt = SeasoningDefaults.suggestedAmount(
        for: "salt",
        servingCount: 4,
        category: nil
    )

    XCTAssertNotNil(soupSalt)
    XCTAssertNotNil(regularSalt)
    XCTAssertGreaterThan(soupSalt!.typical, regularSalt!.typical)
}

func testSeasoningDefaults_FuzzyMatch() {
    let result = SeasoningDefaults.suggestedAmount(
        for: "sea salt",
        servingCount: 4,
        category: nil
    )

    XCTAssertNotNil(result, "Should fuzzy match 'sea salt' to 'salt'")
}
```

### ScalingEngineTests.swift

```swift
func testScalingEngine_SaltSuggestion() {
    let recipe = Recipe(title: "Test Recipe")
    recipe.servings = "4 servings"

    let ingredient = Ingredient(
        originalText: "salt to taste",
        name: "salt",
        quantity: nil
    )
    recipe.ingredients = [ingredient]

    let engine = ScalingEngine()
    let scaled = engine.scaleRecipe(recipe, toServings: 8)

    XCTAssertNotNil(scaled)
    let scaledIngredient = scaled?.scaledIngredients.first
    XCTAssertNotNil(scaledIngredient?.scaledQuantity)
    XCTAssertTrue(scaledIngredient?.notes?.contains("Suggested") ?? false)
    XCTAssertTrue(scaledIngredient?.notes?.contains("adjust to taste") ?? false)
}
```

## Test Execution Notes

- Add these tests to the appropriate test files in the test suite
- Run tests after implementation to verify functionality
- Update test-suite-status.md when tests are added and passing
- Monitor user feedback on seasoning suggestions for future calibration
