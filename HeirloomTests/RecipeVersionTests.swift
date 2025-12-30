import XCTest
import SwiftData
@testable import Heirloom

/// Unit tests for RecipeVersion model and RecipeVersionService
@MainActor
final class RecipeVersionTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var service: RecipeVersionService!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory model container for testing
        modelContainer = try TestFixtures.createTestContainer()
        modelContext = ModelContext(modelContainer)
        service = RecipeVersionService.shared
    }

    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        try await super.tearDown()
    }

    // MARK: - RecipeVersion Model Tests

    func testVersionCreation() throws {
        let version = RecipeVersion(
            creatorUserID: "user-test",
            creatorDisplayName: "Test User",
            creationYear: "2025"
        )

        XCTAssertNotNil(version.id)
        XCTAssertEqual(version.creatorUserID, "user-test")
        XCTAssertEqual(version.creatorDisplayName, "Test User")
        XCTAssertEqual(version.creationYear, "2025")
        XCTAssertFalse(version.isBaseVersion)
        XCTAssertTrue(version.isActive)
        XCTAssertEqual(version.timesCooked, 0)
    }

    func testVersionAttributionLabel() throws {
        let version = RecipeVersion(
            creatorUserID: "user-mom",
            creatorDisplayName: "Mom",
            creationYear: "2015"
        )

        XCTAssertEqual(version.attributionLabel, "Mom '15")
        XCTAssertEqual(version.fullAttribution, "Mom (2015)")
    }

    func testVersionIngredientsEncoding() throws {
        let version = RecipeVersion(
            creatorUserID: "user-test",
            creatorDisplayName: "Test User"
        )

        let ingredients = ["2 cups flour", "1 cup sugar", "3 eggs"]
        version.ingredients = ingredients

        XCTAssertNotNil(version.ingredientsData)
        XCTAssertEqual(version.ingredients, ingredients)
    }

    func testVersionInstructionsEncoding() throws {
        let version = RecipeVersion(
            creatorUserID: "user-test",
            creatorDisplayName: "Test User"
        )

        let instructions = ["Mix dry ingredients", "Add wet ingredients", "Bake at 350°F"]
        version.instructions = instructions

        XCTAssertNotNil(version.instructionsData)
        XCTAssertEqual(version.instructions, instructions)
    }

    func testVersionChangeTracking() throws {
        let version = RecipeVersion(
            creatorUserID: "user-test",
            creatorDisplayName: "Test User"
        )

        version.recordChange(field: "ingredient-0", from: "butter", to: "olive oil")

        XCTAssertNotNil(version.changeLog)
        XCTAssertEqual(version.changeCount, 1)
        XCTAssertTrue(version.hasChanges)

        let changes = version.getChanges(for: "ingredient-0")
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.from, "butter")
        XCTAssertEqual(changes.first?.to, "olive oil")
    }

    func testVersionMultipleChanges() throws {
        let version = RecipeVersion(
            creatorUserID: "user-test",
            creatorDisplayName: "Test User"
        )

        version.recordChange(field: "ingredient-0", from: "butter", to: "olive oil")
        version.recordChange(field: "ingredient-1", from: "sugar", to: "honey")
        version.recordChange(field: "title", from: "Old Title", to: "New Title")

        XCTAssertEqual(version.changeCount, 3)

        let ingredientChanges = version.getChanges(for: "ingredient-0")
        XCTAssertEqual(ingredientChanges.count, 1)

        let titleChanges = version.getChanges(for: "title")
        XCTAssertEqual(titleChanges.count, 1)
    }

    func testVersionClearChanges() throws {
        let version = RecipeVersion(
            creatorUserID: "user-test",
            creatorDisplayName: "Test User"
        )

        version.recordChange(field: "ingredient-0", from: "butter", to: "olive oil")
        XCTAssertTrue(version.hasChanges)

        version.clearChanges()
        XCTAssertFalse(version.hasChanges)
        XCTAssertEqual(version.changeCount, 0)
    }

    // MARK: - RecipeVersionService Tests

    func testCreateBaseVersion() throws {
        let recipe = Recipe(title: "Test Recipe")
        recipe.instructions = ["Step 1", "Step 2"]
        modelContext.insert(recipe)

        let baseVersion = try service.createBaseVersion(for: recipe, context: modelContext)

        XCTAssertNotNil(baseVersion)
        XCTAssertTrue(baseVersion.isBaseVersion)
        XCTAssertEqual(baseVersion.creatorDisplayName, "Original")
        XCTAssertEqual(baseVersion.title, "Test Recipe")
        XCTAssertEqual(baseVersion.instructions?.count, 2)
        XCTAssertEqual(recipe.versions?.count, 1)
    }

    func testCreateBaseVersionFailsIfAlreadyExists() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        _ = try service.createBaseVersion(for: recipe, context: modelContext)

        // Attempting to create second base version should throw
        XCTAssertThrowsError(try service.createBaseVersion(for: recipe, context: modelContext)) { error in
            XCTAssertTrue(error is RecipeVersionError)
            if let versionError = error as? RecipeVersionError {
                XCTAssertEqual(versionError, .baseVersionAlreadyExists)
            }
        }
    }

    func testCreateContributorVersion() throws {
        let recipe = Recipe(title: "Test Recipe")
        recipe.instructions = ["Step 1", "Step 2"]
        modelContext.insert(recipe)

        let version = try service.createVersion(for: recipe, context: modelContext)

        XCTAssertNotNil(version)
        XCTAssertFalse(version.isBaseVersion)
        XCTAssertEqual(version.title, "Test Recipe")
        XCTAssertEqual(version.instructions?.count, 2)
        XCTAssertTrue(recipe.versions?.contains(where: { $0.id == version.id }) == true)
    }

    func testSelectVersion() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        let version = try service.createVersion(for: recipe, context: modelContext)
        try service.selectVersion(version, for: recipe, context: modelContext)

        XCTAssertEqual(recipe.selectedVersionID, version.id)
        XCTAssertEqual(recipe.activeVersion?.id, version.id)
    }

    func testSelectVersionFailsForWrongRecipe() throws {
        let recipe1 = Recipe(title: "Recipe 1")
        let recipe2 = Recipe(title: "Recipe 2")
        modelContext.insert(recipe1)
        modelContext.insert(recipe2)

        let version = try service.createVersion(for: recipe1, context: modelContext)

        // Trying to select version from recipe1 on recipe2 should fail
        XCTAssertThrowsError(try service.selectVersion(version, for: recipe2, context: modelContext)) { error in
            XCTAssertTrue(error is RecipeVersionError)
        }
    }

    func testRecordChange() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        let version = try service.createVersion(for: recipe, context: modelContext)

        try service.recordChange(
            in: version,
            field: "ingredient-0",
            from: "butter",
            to: "olive oil",
            context: modelContext
        )

        XCTAssertEqual(version.changeCount, 1)
        let changes = version.getChanges(for: "ingredient-0")
        XCTAssertEqual(changes.first?.from, "butter")
        XCTAssertEqual(changes.first?.to, "olive oil")
    }

    func testUpdateVersion() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        let version = try service.createVersion(for: recipe, context: modelContext)
        version.title = "Original Title"
        version.ingredients = ["butter", "sugar"]

        let updates = VersionUpdates(
            title: "New Title",
            ingredients: ["olive oil", "honey"],
            notes: "Updated recipe"
        )

        try service.updateVersion(version, with: updates, context: modelContext)

        XCTAssertEqual(version.title, "New Title")
        XCTAssertEqual(version.ingredients, ["olive oil", "honey"])
        XCTAssertEqual(version.notes, "Updated recipe")
        XCTAssertTrue(version.hasChanges)
        XCTAssertEqual(version.changeCount, 3) // title + 2 ingredients
    }

    func testDeactivateVersion() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        let version = try service.createVersion(for: recipe, context: modelContext)
        XCTAssertTrue(version.isActive)

        try service.deactivateVersion(version, context: modelContext)
        XCTAssertFalse(version.isActive)
    }

    func testCannotDeactivateBaseVersion() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        let baseVersion = try service.createBaseVersion(for: recipe, context: modelContext)

        XCTAssertThrowsError(try service.deactivateVersion(baseVersion, context: modelContext)) { error in
            XCTAssertTrue(error is RecipeVersionError)
            if let versionError = error as? RecipeVersionError {
                XCTAssertEqual(versionError, .cannotDeactivateBaseVersion)
            }
        }
    }

    func testReactivateVersion() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        let version = try service.createVersion(for: recipe, context: modelContext)
        try service.deactivateVersion(version, context: modelContext)
        XCTAssertFalse(version.isActive)

        try service.reactivateVersion(version, context: modelContext)
        XCTAssertTrue(version.isActive)
    }

    func testDeleteVersion() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        let version = try service.createVersion(for: recipe, context: modelContext)
        let versionID = version.id

        XCTAssertEqual(recipe.versions?.count, 1)

        try service.deleteVersion(version, from: recipe, context: modelContext)

        XCTAssertEqual(recipe.versions?.count, 0)
        XCTAssertNil(recipe.versions?.first(where: { $0.id == versionID }))
    }

    func testCannotDeleteBaseVersion() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        let baseVersion = try service.createBaseVersion(for: recipe, context: modelContext)

        XCTAssertThrowsError(try service.deleteVersion(baseVersion, from: recipe, context: modelContext)) { error in
            XCTAssertTrue(error is RecipeVersionError)
            if let versionError = error as? RecipeVersionError {
                XCTAssertEqual(versionError, .cannotDeleteBaseVersion)
            }
        }
    }

    func testMarkAsCooked() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        let version = try service.createVersion(for: recipe, context: modelContext)
        XCTAssertEqual(version.timesCooked, 0)
        XCTAssertNil(version.lastCooked)

        try service.markAsCooked(version, context: modelContext)

        XCTAssertEqual(version.timesCooked, 1)
        XCTAssertNotNil(version.lastCooked)
    }

    func testGetVersions() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        _ = try service.createBaseVersion(for: recipe, context: modelContext)
        _ = try service.createVersion(for: recipe, context: modelContext)
        _ = try service.createVersion(for: recipe, context: modelContext)

        let versions = service.getVersions(for: recipe)
        XCTAssertEqual(versions.count, 3)
    }

    func testGetContributorVersions() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        _ = try service.createBaseVersion(for: recipe, context: modelContext)
        _ = try service.createVersion(for: recipe, context: modelContext)
        _ = try service.createVersion(for: recipe, context: modelContext)

        let contributorVersions = service.getContributorVersions(for: recipe)
        XCTAssertEqual(contributorVersions.count, 2) // Excludes base version
    }

    func testPrepareForHeirloomSharing() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        XCTAssertEqual(recipe.sharingPermission, .regular)
        XCTAssertNil(recipe.baseVersion)

        try service.prepareForHeirloomSharing(recipe, context: modelContext)

        XCTAssertEqual(recipe.sharingPermission, .heirloom)
        XCTAssertNotNil(recipe.baseVersion)
    }

    func testHandleReceivedHeirloomShare() throws {
        let recipe = Recipe(title: "Shared Recipe")
        recipe.sharingPermission = .heirloom
        modelContext.insert(recipe)

        let userVersion = try service.handleReceivedHeirloomShare(recipe, context: modelContext)

        XCTAssertNotNil(recipe.baseVersion)
        XCTAssertEqual(recipe.versions?.count, 2) // Base + user version
        XCTAssertEqual(recipe.selectedVersionID, userVersion.id)
        XCTAssertFalse(userVersion.isBaseVersion)
    }

    // MARK: - Recipe Extension Tests

    func testRecipeBaseVersion() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        XCTAssertNil(recipe.baseVersion)

        _ = try service.createBaseVersion(for: recipe, context: modelContext)

        XCTAssertNotNil(recipe.baseVersion)
        XCTAssertTrue(recipe.baseVersion?.isBaseVersion == true)
    }

    func testRecipeActiveVersion() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        let base = try service.createBaseVersion(for: recipe, context: modelContext)
        XCTAssertEqual(recipe.activeVersion?.id, base.id)

        let userVersion = try service.createVersion(for: recipe, context: modelContext)
        try service.selectVersion(userVersion, for: recipe, context: modelContext)

        XCTAssertEqual(recipe.activeVersion?.id, userVersion.id)
    }

    func testRecipeHasMultipleVersions() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        XCTAssertFalse(recipe.hasMultipleVersions)

        _ = try service.createBaseVersion(for: recipe, context: modelContext)
        XCTAssertFalse(recipe.hasMultipleVersions) // Only base version

        _ = try service.createVersion(for: recipe, context: modelContext)
        XCTAssertTrue(recipe.hasMultipleVersions) // Base + contributor
    }

    func testRecipeGenerationLabel() throws {
        let recipe = Recipe(title: "Test Recipe")
        modelContext.insert(recipe)

        XCTAssertEqual(recipe.generationLabel, "Original")

        _ = try service.createBaseVersion(for: recipe, context: modelContext)
        XCTAssertEqual(recipe.generationLabel, "Original")

        _ = try service.createVersion(for: recipe, context: modelContext)
        XCTAssertEqual(recipe.generationLabel, "2 Generations")

        _ = try service.createVersion(for: recipe, context: modelContext)
        XCTAssertEqual(recipe.generationLabel, "3 Generations")
    }
}
