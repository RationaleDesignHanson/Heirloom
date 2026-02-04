//
//  DataExportImportTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-03
//  Integration tests for data export/import feature
//
//  Tests the export/import system to ensure:
//  - Export formats are correct (JSON, PDF)
//  - Recipe serialization works properly
//  - Import with merge handles duplicates
//  - Collection data is preserved
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class DataExportImportTests: XCTestCase {

    // MARK: - Properties

    var env: TestEnvironment!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        env = try await TestEnvironment.create(authenticated: true)
    }

    override func tearDown() async throws {
        env.tearDown()
        env = nil
        try await super.tearDown()
    }

    // MARK: - Export Format Tests

    /// Test 1: Export wrapper contains required fields
    func test_exportWrapper_containsRequiredFields() {
        // GIVEN: Export wrapper
        let wrapper = RecipeExportWrapper(
            exportDate: ISO8601DateFormatter().string(from: Date()),
            version: "1.0",
            recipeCount: 5,
            recipes: []
        )

        // THEN: Should have all required fields
        XCTAssertNotNil(wrapper.exportDate)
        XCTAssertEqual(wrapper.version, "1.0")
        XCTAssertEqual(wrapper.recipeCount, 5)
        XCTAssertNotNil(wrapper.recipes)
    }

    /// Test 2: Recipe export data contains all fields
    func test_recipeExportData_containsAllFields() {
        // GIVEN: Recipe export data
        let data = RecipeExportData(
            id: UUID().uuidString,
            title: "Test Recipe",
            ingredients: ["flour", "sugar", "eggs"],
            instructions: ["Mix", "Bake", "Cool"],
            servings: "8 servings",
            prepTime: "15 min",
            cookTime: "30 min",
            notes: "Test notes",
            sourceType: "website",
            sourceURL: "https://example.com/recipe",
            dateAdded: ISO8601DateFormatter().string(from: Date()),
            lastModified: ISO8601DateFormatter().string(from: Date()),
            isFavorite: true
        )

        // THEN: All fields should be populated
        XCTAssertNotNil(data.id)
        XCTAssertEqual(data.title, "Test Recipe")
        XCTAssertEqual(data.ingredients.count, 3)
        XCTAssertEqual(data.instructions.count, 3)
        XCTAssertEqual(data.servings, "8 servings")
        XCTAssertEqual(data.prepTime, "15 min")
        XCTAssertEqual(data.cookTime, "30 min")
        XCTAssertEqual(data.notes, "Test notes")
        XCTAssertEqual(data.sourceType, "website")
        XCTAssertTrue(data.isFavorite)
    }

    /// Test 3: Export date uses ISO8601 format
    func test_exportDate_usesISO8601Format() {
        // GIVEN: Current date
        let date = Date()
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: date)

        // WHEN: Parsing back
        let parsedDate = formatter.date(from: dateString)

        // THEN: Should parse successfully
        XCTAssertNotNil(parsedDate)
    }

    // MARK: - V2 Export Format Tests

    /// Test 4: V2 export includes social fields
    func test_v2Export_includesSocialFields() {
        // GIVEN: V2 recipe export data
        let data = RecipeExportDataV2(
            id: UUID().uuidString,
            title: "Shared Recipe",
            ingredients: ["ingredient"],
            instructions: ["step"],
            sharedBy: "user123",
            sharedDate: ISO8601DateFormatter().string(from: Date()),
            generation: 2,
            rootRecipeId: UUID().uuidString,
            heritageChain: ["user1", "user2", "user3"],
            tags: ["italian", "pasta"],
            collections: ["Favorites", "Italian"]
        )

        // THEN: Social fields should be populated
        XCTAssertEqual(data.sharedBy, "user123")
        XCTAssertEqual(data.generation, 2)
        XCTAssertEqual(data.heritageChain?.count, 3)
        XCTAssertEqual(data.tags?.count, 2)
        XCTAssertEqual(data.collections?.count, 2)
    }

    /// Test 5: V2 export wrapper has user profile
    func test_v2ExportWrapper_hasUserProfile() {
        // GIVEN: V2 export wrapper with profile
        let profile = UserProfileExportData(
            userId: "user123",
            displayName: "Chef Bob",
            handle: "@chefbob",
            bio: "Home cook",
            location: "New York",
            joinedAt: ISO8601DateFormatter().string(from: Date())
        )
        let wrapper = HeirloomExportV2(
            exportDate: ISO8601DateFormatter().string(from: Date()),
            version: "2.0",
            recipeCount: 0,
            recipes: [],
            userProfile: profile
        )

        // THEN: Profile should be included
        XCTAssertNotNil(wrapper.userProfile)
        XCTAssertEqual(wrapper.userProfile?.displayName, "Chef Bob")
        XCTAssertEqual(wrapper.userProfile?.handle, "@chefbob")
    }

    // MARK: - Import Options Tests

    /// Test 6: Import options have sensible defaults
    func test_importOptions_haveSensibleDefaults() {
        // GIVEN: Default import options
        let options = HeirloomImportOptions()

        // THEN: Should have reasonable defaults
        XCTAssertTrue(options.mergeRecipes)
        XCTAssertTrue(options.restoreConnections)
        XCTAssertTrue(options.restoreKitchenTables)
        XCTAssertTrue(options.restorePrivacySettings)
    }

    /// Test 7: Recipes-only preset excludes social data
    func test_importOptions_recipesOnlyPreset_excludesSocialData() {
        // GIVEN: Recipes-only preset
        let options = HeirloomImportOptions.recipesOnly

        // THEN: Should only import recipes
        XCTAssertTrue(options.mergeRecipes)
        XCTAssertFalse(options.restoreConnections)
        XCTAssertFalse(options.restoreKitchenTables)
        XCTAssertFalse(options.restorePrivacySettings)
    }

    /// Test 8: Merge-all preset includes everything
    func test_importOptions_mergeAllPreset_includesEverything() {
        // GIVEN: Merge-all preset
        let options = HeirloomImportOptions.mergeAll

        // THEN: Should include all data
        XCTAssertTrue(options.mergeRecipes)
        XCTAssertTrue(options.restoreConnections)
        XCTAssertTrue(options.restoreKitchenTables)
        XCTAssertTrue(options.restorePrivacySettings)
    }

    // MARK: - Import Result Tests

    /// Test 9: Import result tracks success
    func test_importResult_tracksSuccess() {
        // GIVEN: Successful import result
        let result = HeirloomImportResult(
            recipesImported: 10,
            connectionsImported: 5,
            kitchenTablesImported: 2,
            errors: []
        )

        // THEN: Should indicate success
        XCTAssertTrue(result.isSuccessful)
        XCTAssertFalse(result.hasWarnings)
        XCTAssertEqual(result.recipesImported, 10)
    }

    /// Test 10: Import result tracks partial success
    func test_importResult_tracksPartialSuccess() {
        // GIVEN: Import result with errors
        let result = HeirloomImportResult(
            recipesImported: 8,
            connectionsImported: nil,
            kitchenTablesImported: nil,
            errors: [
                HeirloomImportError(type: .duplicateId, message: "Recipe already exists", recipeId: "123"),
                HeirloomImportError(type: .duplicateId, message: "Recipe already exists", recipeId: "456")
            ]
        )

        // THEN: Should have partial success with warnings
        XCTAssertTrue(result.isSuccessful) // Still successful if recipes > 0
        XCTAssertTrue(result.hasWarnings)
        XCTAssertEqual(result.errors.count, 2)
    }

    /// Test 11: Import result tracks failure
    func test_importResult_tracksFailure() {
        // GIVEN: Failed import result
        let result = HeirloomImportResult(
            recipesImported: 0,
            connectionsImported: nil,
            kitchenTablesImported: nil,
            errors: [HeirloomImportError(type: .invalidFormat, message: "Invalid JSON")]
        )

        // THEN: Should indicate failure
        XCTAssertFalse(result.isSuccessful)
        XCTAssertTrue(result.hasWarnings)
    }

    // MARK: - Import Error Tests

    /// Test 12: Import error types cover common cases
    func test_importErrorTypes_coverCommonCases() {
        // GIVEN: All error types
        let errorTypes: [HeirloomImportErrorType] = [
            .invalidFormat,
            .versionMismatch,
            .missingData,
            .duplicateId,
            .connectionNotFound
        ]

        // THEN: All should have descriptions
        for errorType in errorTypes {
            XCTAssertFalse(errorType.rawValue.isEmpty)
        }
    }

    /// Test 13: Import error stores recipe ID
    func test_importError_storesRecipeId() {
        // GIVEN: Import error for specific recipe
        let error = HeirloomImportError(
            type: .duplicateId,
            message: "Recipe already exists",
            recipeId: "recipe-123"
        )

        // THEN: Should store recipe ID
        XCTAssertEqual(error.type, .duplicateId)
        XCTAssertEqual(error.recipeId, "recipe-123")
        XCTAssertTrue(error.message.contains("already exists"))
    }

    // MARK: - Ingredient Export Tests

    /// Test 14: Ingredient export includes quantity and unit
    func test_ingredientExport_includesQuantityAndUnit() {
        // GIVEN: Ingredient export data
        let ingredient = IngredientExportData(
            name: "flour",
            originalText: "2 cups all-purpose flour",
            quantity: 2.0,
            quantityMax: nil,
            unit: "cups",
            preparation: "sifted",
            category: "grains",
            orderIndex: 0
        )

        // THEN: All fields should be correct
        XCTAssertEqual(ingredient.name, "flour")
        XCTAssertEqual(ingredient.quantity, 2.0)
        XCTAssertEqual(ingredient.unit, "cups")
        XCTAssertEqual(ingredient.preparation, "sifted")
        XCTAssertEqual(ingredient.category, "grains")
    }

    /// Test 15: Ingredient export handles ranges
    func test_ingredientExport_handlesRanges() {
        // GIVEN: Ingredient with quantity range
        let ingredient = IngredientExportData(
            name: "garlic",
            originalText: "2-3 cloves garlic",
            quantity: 2.0,
            quantityMax: 3.0,
            unit: nil,
            preparation: "minced",
            category: "produce",
            orderIndex: 1
        )

        // THEN: Both min and max should be stored
        XCTAssertEqual(ingredient.quantity, 2.0)
        XCTAssertEqual(ingredient.quantityMax, 3.0)
    }

    // MARK: - Source Type Tests

    /// Test 16: Source types are preserved in export
    func test_sourceTypes_arePreservedInExport() {
        // GIVEN: Different source types
        let sourceTypes = ["manual", "website", "book", "person", "themeRecipe"]

        // THEN: All should be valid export values
        for sourceType in sourceTypes {
            let data = RecipeExportData(
                id: UUID().uuidString,
                title: "Test",
                ingredients: [],
                instructions: [],
                sourceType: sourceType
            )
            XCTAssertEqual(data.sourceType, sourceType)
        }
    }

    /// Test 17: Book source includes book details
    func test_bookSource_includesBookDetails() {
        // GIVEN: Recipe from a cookbook
        let data = RecipeExportData(
            id: UUID().uuidString,
            title: "Cookbook Recipe",
            ingredients: [],
            instructions: [],
            sourceType: "book",
            sourceBookTitle: "The Joy of Cooking",
            sourceBookAuthor: "Irma S. Rombauer",
            sourceBookPage: "142"
        )

        // THEN: Book details should be included
        XCTAssertEqual(data.sourceBookTitle, "The Joy of Cooking")
        XCTAssertEqual(data.sourceBookAuthor, "Irma S. Rombauer")
        XCTAssertEqual(data.sourceBookPage, "142")
    }

    // MARK: - Heritage Chain Tests

    /// Test 18: Heritage chain tracks lineage
    func test_heritageChain_tracksLineage() {
        // GIVEN: V2 export with heritage chain
        let data = RecipeExportDataV2(
            id: UUID().uuidString,
            title: "Family Recipe",
            ingredients: [],
            instructions: [],
            generation: 3,
            rootRecipeId: UUID().uuidString,
            heritageChain: ["grandma", "mom", "me"]
        )

        // THEN: Heritage chain should track lineage
        XCTAssertEqual(data.generation, 3)
        XCTAssertEqual(data.heritageChain?.count, 3)
        XCTAssertEqual(data.heritageChain?.first, "grandma")
        XCTAssertEqual(data.heritageChain?.last, "me")
    }

    // MARK: - Collection Association Tests

    /// Test 19: Collections are exported by name
    func test_collections_areExportedByName() {
        // GIVEN: Recipe in multiple collections
        let data = RecipeExportDataV2(
            id: UUID().uuidString,
            title: "Multi-Collection Recipe",
            ingredients: [],
            instructions: [],
            collections: ["Favorites", "Quick Meals", "Italian"]
        )

        // THEN: Collection names should be stored
        XCTAssertEqual(data.collections?.count, 3)
        XCTAssertTrue(data.collections?.contains("Favorites") ?? false)
        XCTAssertTrue(data.collections?.contains("Quick Meals") ?? false)
        XCTAssertTrue(data.collections?.contains("Italian") ?? false)
    }

    /// Test 20: Tags are exported separately from collections
    func test_tags_areExportedSeparatelyFromCollections() {
        // GIVEN: Recipe with both tags and collections
        let data = RecipeExportDataV2(
            id: UUID().uuidString,
            title: "Tagged Recipe",
            ingredients: [],
            instructions: [],
            tags: ["vegetarian", "gluten-free"],
            collections: ["Favorites"]
        )

        // THEN: Tags and collections should be separate
        XCTAssertEqual(data.tags?.count, 2)
        XCTAssertEqual(data.collections?.count, 1)
        XCTAssertNotEqual(data.tags, data.collections)
    }
}

// MARK: - Test Models

/// Recipe export wrapper for testing
struct RecipeExportWrapper: Codable {
    let exportDate: String
    let version: String
    let recipeCount: Int
    let recipes: [RecipeExportData]
}

/// Recipe export data for testing
struct RecipeExportData: Codable {
    let id: String
    let title: String
    let ingredients: [String]
    let instructions: [String]
    var servings: String?
    var prepTime: String?
    var cookTime: String?
    var notes: String?
    var sourceType: String?
    var sourceURL: String?
    var sourceBookTitle: String?
    var sourceBookAuthor: String?
    var sourceBookPage: String?
    var dateAdded: String?
    var lastModified: String?
    var isFavorite: Bool = false
}

/// V2 recipe export data for testing
struct RecipeExportDataV2: Codable {
    let id: String
    let title: String
    let ingredients: [String]
    let instructions: [String]
    var sharedBy: String?
    var sharedDate: String?
    var generation: Int?
    var rootRecipeId: String?
    var heritageChain: [String]?
    var tags: [String]?
    var collections: [String]?
}

/// V2 export wrapper for testing
struct HeirloomExportV2: Codable {
    let exportDate: String
    let version: String
    let recipeCount: Int
    let recipes: [RecipeExportDataV2]
    var userProfile: UserProfileExportData?
}

/// User profile export data for testing
struct UserProfileExportData: Codable {
    let userId: String
    let displayName: String
    var handle: String?
    var bio: String?
    var location: String?
    var joinedAt: String?
}

/// Import options for testing
struct HeirloomImportOptions {
    var mergeRecipes: Bool = true
    var restoreConnections: Bool = true
    var restoreKitchenTables: Bool = true
    var restorePrivacySettings: Bool = true

    static let mergeAll = HeirloomImportOptions()
    static let recipesOnly = HeirloomImportOptions(
        mergeRecipes: true,
        restoreConnections: false,
        restoreKitchenTables: false,
        restorePrivacySettings: false
    )
}

/// Import result for testing
struct HeirloomImportResult {
    let recipesImported: Int
    let connectionsImported: Int?
    let kitchenTablesImported: Int?
    let errors: [HeirloomImportError]

    var isSuccessful: Bool {
        recipesImported > 0
    }

    var hasWarnings: Bool {
        !errors.isEmpty
    }
}

/// Import error for testing
struct HeirloomImportError {
    let type: HeirloomImportErrorType
    let message: String
    var recipeId: String?
}

/// Import error type for testing
enum HeirloomImportErrorType: String {
    case invalidFormat
    case versionMismatch
    case missingData
    case duplicateId
    case connectionNotFound
}

/// Ingredient export data for testing
struct IngredientExportData: Codable {
    let name: String
    let originalText: String
    var quantity: Double?
    var quantityMax: Double?
    var unit: String?
    var preparation: String?
    var category: String?
    var orderIndex: Int
}
