import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class RecipeMigrationServiceTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var service: RecipeMigrationService!

    override func setUp() async throws {
        print("DEBUG setUp: Starting")
        try await super.setUp()
        print("DEBUG setUp: About to create container")

        do {
            modelContainer = try TestFixtures.createTestContainer()
            print("DEBUG setUp: Container created successfully")
        } catch {
            print("DEBUG setUp: ERROR creating container: \(error)")
            throw error
        }

        print("DEBUG setUp: Creating context")
        modelContext = ModelContext(modelContainer)
        print("DEBUG setUp: Getting service")
        service = RecipeMigrationService.shared
        print("DEBUG setUp: Complete - service=\(service as Any), context=\(modelContext as Any)")
    }

    override func tearDown() async throws {
        modelContext = nil
        modelContainer = nil
        service = nil
        try await super.tearDown()
    }

    // MARK: - Migration Stats Tests

    func testGetMigrationStats_NoRecipes() throws {
        // Given - empty database
        print("DEBUG: Test starting")
        print("DEBUG: service = \(service as Any)")
        print("DEBUG: modelContext = \(modelContext as Any)")

        // When
        print("DEBUG: About to call getMigrationStats")
        let stats = try service.getMigrationStats(context: modelContext)
        print("DEBUG: Got stats: \(stats)")

        // Then
        XCTAssertEqual(stats.totalRecipes, 0)
        XCTAssertEqual(stats.recipesNeedingMigration, 0)
        XCTAssertEqual(stats.recipesWithVersions, 0)
        print("DEBUG: Test completed successfully")
    }

    func testGetMigrationStats_AllNeedMigration() throws {
        // Given
        let recipes = TestFixtures.createTestRecipes(count: 3, context: modelContext)
        for recipe in recipes {
            recipe.versions = []  // No versions = needs migration
        }
        try modelContext.save()

        // When
        let stats = try service.getMigrationStats(context: modelContext)

        // Then
        XCTAssertEqual(stats.totalRecipes, 3)
        XCTAssertEqual(stats.recipesNeedingMigration, 3)
        XCTAssertEqual(stats.recipesWithVersions, 0)
    }

    func testGetMigrationStats_AllAlreadyMigrated() throws {
        // Given
        _ = TestFixtures.createTestRecipes(count: 2, context: modelContext)
        try modelContext.save()

        // Migrate all
        _ = try service.migrateRecipesToVersions(context: modelContext)

        // When
        let stats = try service.getMigrationStats(context: modelContext)

        // Then
        XCTAssertEqual(stats.totalRecipes, 2)
        XCTAssertEqual(stats.recipesNeedingMigration, 0)
        XCTAssertEqual(stats.recipesWithVersions, 2)
    }

    func testGetMigrationStats_Mixed() throws {
        // Given
        let recipes = TestFixtures.createTestRecipes(count: 4, context: modelContext)
        recipes[0].versions = []  // Needs migration
        recipes[1].versions = []  // Needs migration
        // recipes[2] and recipes[3] already have versions from TestFixtures
        try modelContext.save()

        // When
        let stats = try service.getMigrationStats(context: modelContext)

        // Then
        XCTAssertEqual(stats.totalRecipes, 4)
        XCTAssertGreaterThanOrEqual(stats.recipesNeedingMigration, 2)
        XCTAssertGreaterThanOrEqual(stats.recipesWithVersions, 0)
    }

    // MARK: - Migration Execution Tests

    func testMigrateAllRecipes_Success() throws {
        // Given
        let recipes = TestFixtures.createTestRecipes(count: 3, context: modelContext)
        for recipe in recipes {
            recipe.versions = []
        }
        try modelContext.save()

        // When
        let count = try service.migrateRecipesToVersions(context: modelContext)

        // Then
        XCTAssertEqual(count, 3, "Should migrate 3 recipes")

        // Verify each recipe has a base version
        for recipe in recipes {
            XCTAssertFalse(recipe.versions?.isEmpty ?? true, "Should have versions")
            XCTAssertNotNil(recipe.baseVersion, "Should have base version")
            XCTAssertNotNil(recipe.selectedVersionID, "Should have selected version")
        }
    }

    func testMigrateAllRecipes_NoRecipesToMigrate() throws {
        // Given - all recipes already migrated
        _ = TestFixtures.createTestRecipes(count: 2, context: modelContext)
        try modelContext.save()
        _ = try service.migrateRecipesToVersions(context: modelContext)

        // When - try to migrate again
        let count = try service.migrateRecipesToVersions(context: modelContext)

        // Then
        XCTAssertEqual(count, 0, "Should not migrate already-migrated recipes")
    }

    func testMigrateAllRecipes_EmptyDatabase() throws {
        // Given - no recipes

        // When
        let count = try service.migrateRecipesToVersions(context: modelContext)

        // Then
        XCTAssertEqual(count, 0, "Should return 0 for empty database")
    }

    func testMigrateAllRecipes_Idempotent() throws {
        // Given
        let recipes = TestFixtures.createTestRecipes(count: 2, context: modelContext)
        for recipe in recipes {
            recipe.versions = []
        }
        try modelContext.save()

        // When - migrate twice
        let firstCount = try service.migrateRecipesToVersions(context: modelContext)
        let secondCount = try service.migrateRecipesToVersions(context: modelContext)

        // Then
        XCTAssertEqual(firstCount, 2, "First migration should migrate 2")
        XCTAssertEqual(secondCount, 0, "Second migration should migrate 0")

        // Verify still only one version per recipe
        for recipe in recipes {
            XCTAssertEqual(recipe.versions?.count, 1, "Should still have only 1 version")
        }
    }

    // MARK: - Base Version Creation Tests

    func testMigration_CreatesBaseVersion() throws {
        // Given
        let recipe = TestFixtures.mockRecipe(title: "Test Recipe", context: modelContext)
        recipe.versions = []
        try modelContext.save()

        // When
        _ = try service.migrateRecipesToVersions(context: modelContext)

        // Then
        XCTAssertNotNil(recipe.baseVersion, "Should create base version")
        XCTAssertEqual(recipe.baseVersion?.title, recipe.title, "Should copy title")
        XCTAssertEqual(recipe.baseVersion?.instructions, recipe.instructions, "Should copy instructions")
    }

    func testMigration_CopiesIngredients() throws {
        // Given
        let recipe = TestFixtures.mockRecipe(context: modelContext)
        recipe.versions = []
        let originalIngredients = recipe.ingredients?.map { $0.originalText } ?? []
        try modelContext.save()

        // When
        _ = try service.migrateRecipesToVersions(context: modelContext)

        // Then
        let baseVersion = recipe.baseVersion
        XCTAssertNotNil(baseVersion)
        XCTAssertEqual(baseVersion?.ingredients?.count, originalIngredients.count, "Should copy all ingredients")
    }

    func testMigration_SetsSelectedVersion() throws {
        // Given
        let recipe = TestFixtures.mockRecipe(context: modelContext)
        recipe.versions = []
        XCTAssertNil(recipe.selectedVersionID, "Should start with no selected version")
        try modelContext.save()

        // When
        _ = try service.migrateRecipesToVersions(context: modelContext)

        // Then
        XCTAssertNotNil(recipe.selectedVersionID, "Should set selected version")
        XCTAssertEqual(recipe.selectedVersionID, recipe.baseVersion?.id, "Should select base version")
    }

    func testMigration_PreservesExistingVersions() throws {
        // Given
        let recipe = TestFixtures.mockRecipeWithVersions(context: modelContext)
        let originalVersionCount = recipe.versions?.count ?? 0
        XCTAssertGreaterThan(originalVersionCount, 0, "Should start with versions")
        try modelContext.save()

        // When - try to migrate (should skip)
        _ = try service.migrateRecipesToVersions(context: modelContext)

        // Then
        XCTAssertEqual(recipe.versions?.count, originalVersionCount, "Should not modify existing versions")
    }

    // MARK: - Edge Case Tests

    func testMigration_RecipeWithNoIngredients() throws {
        // Given
        let recipe = Recipe(title: "Empty Recipe", sourceType: .manual)
        recipe.versions = []
        modelContext.insert(recipe)
        try modelContext.save()

        // When
        _ = try service.migrateRecipesToVersions(context: modelContext)

        // Then
        XCTAssertNotNil(recipe.baseVersion, "Should create base version even with no ingredients")
        XCTAssertTrue(recipe.baseVersion?.ingredients?.isEmpty ?? true, "Should have empty ingredients array")
    }

    func testMigration_RecipeWithNoInstructions() throws {
        // Given
        let recipe = Recipe(title: "No Instructions", sourceType: .manual)
        recipe.versions = []
        recipe.instructions = []
        modelContext.insert(recipe)
        try modelContext.save()

        // When
        _ = try service.migrateRecipesToVersions(context: modelContext)

        // Then
        XCTAssertNotNil(recipe.baseVersion, "Should create base version even with no instructions")
        XCTAssertTrue(recipe.baseVersion?.instructions?.isEmpty ?? true, "Should have empty instructions array")
    }

    func testMigration_RecipeWithSpecialCharacters() throws {
        // Given
        let recipe = Recipe(title: "Recipe with émojis 🍰 & spëcial çhars", sourceType: .manual)
        recipe.versions = []
        modelContext.insert(recipe)
        try modelContext.save()

        // When
        _ = try service.migrateRecipesToVersions(context: modelContext)

        // Then
        XCTAssertNotNil(recipe.baseVersion)
        XCTAssertEqual(recipe.baseVersion?.title, recipe.title, "Should preserve special characters")
    }

    // MARK: - Performance Tests

    func testMigration_Performance() throws {
        // Given
        let recipes = TestFixtures.createTestRecipes(count: 10, context: modelContext)
        for recipe in recipes {
            recipe.versions = []
        }
        try modelContext.save()

        // When/Then
        measure {
            _ = try? service.migrateRecipesToVersions(context: modelContext)
        }
    }

    func testGetStats_Performance() throws {
        // Given
        _ = TestFixtures.createTestRecipes(count: 50, context: modelContext)
        try modelContext.save()

        // When/Then
        measure {
            _ = try? service.getMigrationStats(context: modelContext)
        }
    }
}
