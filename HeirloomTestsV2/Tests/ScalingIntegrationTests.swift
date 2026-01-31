//
//  ScalingIntegrationTests.swift
//  HeirloomTestsV2
//
//  Created by Claude on 2026-01-30.
//

import XCTest
import SwiftData
@testable import Heirloom

/// Integration tests for end-to-end scaling functionality
final class ScalingIntegrationTests: XCTestCase {
    var modelContext: ModelContext!

    override func setUp() async throws {
        // Create in-memory model context for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Recipe.self, Ingredient.self, configurations: config)
        modelContext = ModelContext(container)
    }

    override func tearDown() {
        modelContext = nil
    }

    // MARK: - Scaling Validation Tests

    func testScalingValidation_WithValidRecipe() {
        // Create recipe with valid servings and quantities
        let recipe = Recipe(
            title: "Test Recipe",
            sourceType: .manual,
            instructions: [],
            servings: "4 servings"
        )

        let ingredient = Ingredient(
            originalText: "2 cups flour",
            name: "flour",
            quantity: 2.0,
            unit: "cup",
            category: .other,
            orderIndex: 0
        )
        ingredient.recipe = recipe
        recipe.ingredients = [ingredient]

        modelContext.insert(recipe)
        modelContext.insert(ingredient)

        // Validate scaling capability
        let validation = recipe.scalingValidation
        XCTAssertTrue(validation.isFullyScalable, "Recipe with valid servings and quantities should be fully scalable")
        XCTAssertTrue(validation.issues.isEmpty, "Should have no issues")
    }

    func testScalingValidation_WithMissingQuantities() {
        // Create recipe with ingredients missing quantities
        let recipe = Recipe(
            title: "Test Recipe",
            sourceType: .manual,
            instructions: [],
            servings: "6 servings"
        )

        let ingredient1 = Ingredient(
            originalText: "flour",
            name: "flour",
            quantity: nil, // Missing!
            unit: nil,
            category: .other,
            orderIndex: 0
        )
        ingredient1.recipe = recipe

        let ingredient2 = Ingredient(
            originalText: "salt",
            name: "salt",
            quantity: nil, // Missing!
            unit: nil,
            category: .other,
            orderIndex: 1
        )
        ingredient2.recipe = recipe

        recipe.ingredients = [ingredient1, ingredient2]
        modelContext.insert(recipe)

        // Validate scaling capability
        let validation = recipe.scalingValidation
        XCTAssertFalse(validation.isFullyScalable, "Recipe with missing quantities should not be fully scalable")
        XCTAssertEqual(validation.issues.count, 1, "Should have one issue type")

        // Check for missing quantities issue
        let hasMissingQuantitiesIssue = validation.issues.contains { issue in
            if case .missingQuantities(let count, let total) = issue {
                return count == 2 && total == 2
            }
            return false
        }
        XCTAssertTrue(hasMissingQuantitiesIssue, "Should identify missing quantities issue")
    }

    func testScalingValidation_WithUnparseableServings() {
        // Create recipe with unparseable servings
        let recipe = Recipe(
            title: "Test Recipe",
            sourceType: .manual,
            instructions: [],
            servings: "some servings" // No number!
        )

        let ingredient = Ingredient(
            originalText: "2 cups flour",
            name: "flour",
            quantity: 2.0,
            unit: "cup",
            category: .other,
            orderIndex: 0
        )
        ingredient.recipe = recipe
        recipe.ingredients = [ingredient]

        modelContext.insert(recipe)

        // Validate scaling capability
        let validation = recipe.scalingValidation
        XCTAssertFalse(validation.isFullyScalable, "Recipe with unparseable servings should not be fully scalable")

        // Check for unparseable servings issue
        let hasUnparseableServingsIssue = validation.issues.contains { issue in
            if case .servingsUnparseable = issue {
                return true
            }
            return false
        }
        XCTAssertTrue(hasUnparseableServingsIssue, "Should identify unparseable servings issue")
    }

    // MARK: - Parsed Serving Count Tests

    func testParsedServingCount_WithValidServings() {
        let recipe = Recipe(title: "Test", sourceType: .manual)

        recipe.servings = "6 servings"
        XCTAssertEqual(recipe.parsedServingCount, 6)

        recipe.servings = "Makes 12 cookies"
        XCTAssertEqual(recipe.parsedServingCount, 12)

        recipe.servings = "Serves 4-6"
        XCTAssertEqual(recipe.parsedServingCount, 4)
    }

    func testParsedServingCount_WithInvalidServings() {
        let recipe = Recipe(title: "Test", sourceType: .manual)

        recipe.servings = nil
        XCTAssertEqual(recipe.parsedServingCount, 4, "Should default to 4")

        recipe.servings = "No numbers"
        XCTAssertEqual(recipe.parsedServingCount, 4, "Should default to 4")
    }

    // MARK: - Scale Factor Tests

    func testScaleFactor_Doubling() {
        let recipe = Recipe(
            title: "Test Recipe",
            sourceType: .manual,
            instructions: [],
            servings: "4 servings"
        )
        XCTAssertEqual(recipe.parsedServingCount, 4)

        let targetServings = 8
        let scaleFactor = Double(targetServings) / Double(recipe.parsedServingCount)
        XCTAssertEqual(scaleFactor, 2.0, accuracy: 0.001)
    }

    func testScaleFactor_Halving() {
        let recipe = Recipe(
            title: "Test Recipe",
            sourceType: .manual,
            instructions: [],
            servings: "8 servings"
        )
        XCTAssertEqual(recipe.parsedServingCount, 8)

        let targetServings = 4
        let scaleFactor = Double(targetServings) / Double(recipe.parsedServingCount)
        XCTAssertEqual(scaleFactor, 0.5, accuracy: 0.001)
    }

    // MARK: - Import Type Tests

    func testValidation_URLImport() {
        let recipe = Recipe(
            title: "Imported Recipe",
            sourceType: .url,
            instructions: [],
            servings: "6 servings"
        )
        recipe.sourceURL = "https://example.com/recipe"

        // URL imports should be validated
        XCTAssertEqual(recipe.parsedServingCount, 6)
        XCTAssertEqual(recipe.sourceType, .url)
    }

    func testValidation_ManualEntry() {
        let recipe = Recipe(
            title: "Manual Recipe",
            sourceType: .manual,
            instructions: [],
            servings: "4 servings"
        )

        XCTAssertEqual(recipe.parsedServingCount, 4)
        XCTAssertEqual(recipe.sourceType, .manual)
    }

    func testValidation_VideoImport() {
        let recipe = Recipe(
            title: "Video Recipe",
            sourceType: .video,
            instructions: [],
            servings: "8 servings"
        )

        XCTAssertEqual(recipe.parsedServingCount, 8)
        XCTAssertEqual(recipe.sourceType, .video)
    }

    // MARK: - Real-World Scenario Tests

    func testCompleteImportFlow_WithGoodData() {
        // Simulate a successful import with all data
        let recipe = Recipe(
            title: "Chocolate Chip Cookies",
            sourceType: .url,
            instructions: ["Mix ingredients", "Bake at 350°F"],
            servings: "Makes 24 cookies"
        )

        let ingredients = [
            Ingredient(originalText: "2 cups flour", name: "flour", quantity: 2.0, unit: "cup", category: .other, orderIndex: 0),
            Ingredient(originalText: "1 cup sugar", name: "sugar", quantity: 1.0, unit: "cup", category: .other, orderIndex: 1),
            Ingredient(originalText: "0.5 tsp salt", name: "salt", quantity: 0.5, unit: "tsp", category: .other, orderIndex: 2)
        ]

        for ingredient in ingredients {
            ingredient.recipe = recipe
            modelContext.insert(ingredient)
        }
        recipe.ingredients = ingredients
        modelContext.insert(recipe)

        // Verify full scalability
        let validation = recipe.scalingValidation
        XCTAssertTrue(validation.isFullyScalable)
        XCTAssertEqual(recipe.parsedServingCount, 24)

        // Test scaling to 48 cookies (double)
        let targetServings = 48
        let scaleFactor = Double(targetServings) / Double(recipe.parsedServingCount)
        XCTAssertEqual(scaleFactor, 2.0)

        // Verify ingredients would scale correctly
        if let flour = ingredients.first(where: { $0.name == "flour" }) {
            let scaledQuantity = (flour.quantity ?? 0) * scaleFactor
            XCTAssertEqual(scaledQuantity, 4.0, accuracy: 0.001) // 2 cups * 2 = 4 cups
        }
    }

    func testCompleteImportFlow_WithMissingData() {
        // Simulate an import with missing quantities (common with web imports)
        let recipe = Recipe(
            title: "Imported Recipe",
            sourceType: .url,
            instructions: ["Mix", "Bake"],
            servings: "6 servings"
        )

        let ingredients = [
            Ingredient(originalText: "flour", name: "flour", quantity: nil, unit: nil, category: .other, orderIndex: 0),
            Ingredient(originalText: "sugar", name: "sugar", quantity: nil, unit: nil, category: .other, orderIndex: 1)
        ]

        for ingredient in ingredients {
            ingredient.recipe = recipe
            modelContext.insert(ingredient)
        }
        recipe.ingredients = ingredients
        modelContext.insert(recipe)

        // Verify scaling limitations detected
        let validation = recipe.scalingValidation
        XCTAssertFalse(validation.isFullyScalable)

        // Check that issues are reported
        XCTAssertFalse(validation.issues.isEmpty)
        let hasQuantityIssue = validation.issues.contains { issue in
            if case .missingQuantities = issue { return true }
            return false
        }
        XCTAssertTrue(hasQuantityIssue)
    }
}
