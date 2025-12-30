import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class RecipeTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        modelContainer = try TestFixtures.createTestContainer()
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() async throws {
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    // MARK: - Version Property Tests

    func testHasMultipleVersions_NoVersions() {
        // Given
        let recipe = Recipe(title: "Test", sourceType: .manual)
        recipe.versions = []

        // Then
        XCTAssertFalse(recipe.hasMultipleVersions, "Should be false with 0 versions")
    }

    func testHasMultipleVersions_OneVersion() {
        // Given
        let recipe = Recipe(title: "Test", sourceType: .manual)
        let version = RecipeVersion(creatorUserID: "user1", creatorDisplayName: "User", creationYear: "2024", isBaseVersion: true)
        recipe.versions = [version]

        // Then
        XCTAssertFalse(recipe.hasMultipleVersions, "Should be false with only base version (no contributors)")
    }

    func testHasMultipleVersions_TwoVersions() {
        // Given
        let recipe = TestFixtures.mockRecipeWithVersions(context: modelContext)

        // Then
        XCTAssertTrue(recipe.hasMultipleVersions, "Should be true with 2+ versions")
        XCTAssertGreaterThanOrEqual(recipe.versions?.count ?? 0, 2, "Should have at least 2 versions")
    }

    func testHasMultipleVersions_NilVersions() {
        // Given
        let recipe = Recipe(title: "Test", sourceType: .manual)
        recipe.versions = nil

        // Then
        XCTAssertFalse(recipe.hasMultipleVersions, "Should be false with nil versions")
    }

    // MARK: - Base Version Tests

    func testBaseVersion_ReturnsFirstVersion() {
        // Given
        let recipe = Recipe(title: "Test", sourceType: .manual)
        let version1 = RecipeVersion(creatorUserID: "user1", creatorDisplayName: "First", creationYear: "2020", isBaseVersion: true)
        let version2 = RecipeVersion(creatorUserID: "user2", creatorDisplayName: "Second", creationYear: "2024")
        recipe.versions = [version1, version2]

        // Then
        XCTAssertEqual(recipe.baseVersion?.creatorDisplayName, "First", "Should return base version")
    }

    func testBaseVersion_NoVersions() {
        // Given
        let recipe = Recipe(title: "Test", sourceType: .manual)
        recipe.versions = []

        // Then
        XCTAssertNil(recipe.baseVersion, "Should be nil with no versions")
    }

    func testBaseVersion_NilVersions() {
        // Given
        let recipe = Recipe(title: "Test", sourceType: .manual)
        recipe.versions = nil

        // Then
        XCTAssertNil(recipe.baseVersion, "Should be nil with nil versions")
    }

    // MARK: - Active Version Tests

    func testActiveVersion_WithSelectedID() {
        // Given
        let recipe = Recipe(title: "Test", sourceType: .manual)
        let version1 = RecipeVersion(creatorUserID: "user1", creatorDisplayName: "First", creationYear: "2020", isBaseVersion: true)
        let version2 = RecipeVersion(creatorUserID: "user2", creatorDisplayName: "Second", creationYear: "2024")
        recipe.versions = [version1, version2]
        recipe.selectedVersionID = version2.id

        // Then
        XCTAssertEqual(recipe.activeVersion?.creatorDisplayName, "Second", "Should return selected version")
    }

    func testActiveVersion_NoSelection() {
        // Given
        let recipe = Recipe(title: "Test", sourceType: .manual)
        let version = RecipeVersion(creatorUserID: "user1", creatorDisplayName: "First", creationYear: "2020", isBaseVersion: true)
        recipe.versions = [version]
        recipe.selectedVersionID = nil

        // Then
        XCTAssertEqual(recipe.activeVersion?.creatorDisplayName, "First", "Should default to base version")
    }

    func testActiveVersion_InvalidSelection() {
        // Given
        let recipe = Recipe(title: "Test", sourceType: .manual)
        let version = RecipeVersion(creatorUserID: "user1", creatorDisplayName: "First", creationYear: "2020", isBaseVersion: true)
        recipe.versions = [version]
        recipe.selectedVersionID = UUID()  // Non-existent ID

        // Then
        XCTAssertEqual(recipe.activeVersion?.creatorDisplayName, "First", "Should fall back to base version")
    }

    // MARK: - Generation Label Tests

    func testGenerationLabel_NoVersions() {
        // Given
        let recipe = Recipe(title: "Test", sourceType: .manual)
        recipe.versions = []

        // Then
        XCTAssertEqual(recipe.generationLabel, "Original", "Should show 'Original' with no versions")
    }

    func testGenerationLabel_OneVersion() {
        // Given
        let recipe = Recipe(title: "Test", sourceType: .manual)
        let version = RecipeVersion(creatorUserID: "user1", creatorDisplayName: "User", creationYear: "2024")
        recipe.versions = [version]

        // Then
        XCTAssertEqual(recipe.generationLabel, "Original", "Should show 'Original' with 1 version")
    }

    func testGenerationLabel_TwoVersions() {
        // Given
        let recipe = Recipe(title: "Test", sourceType: .manual)
        let version1 = RecipeVersion(creatorUserID: "user1", creatorDisplayName: "First", creationYear: "2020", isBaseVersion: true)
        let version2 = RecipeVersion(creatorUserID: "user2", creatorDisplayName: "Second", creationYear: "2024")
        recipe.versions = [version1, version2]

        // Then
        XCTAssertEqual(recipe.generationLabel, "2 Generations", "Should show '2 Generations' with 2 versions")
    }

    func testGenerationLabel_ThreeVersions() {
        // Given
        let recipe = Recipe(title: "Test", sourceType: .manual)
        let version1 = RecipeVersion(creatorUserID: "user1", creatorDisplayName: "First", creationYear: "2020", isBaseVersion: true)
        let version2 = RecipeVersion(creatorUserID: "user2", creatorDisplayName: "Second", creationYear: "2024")
        let version3 = RecipeVersion(creatorUserID: "user3", creatorDisplayName: "Third", creationYear: "2025")
        recipe.versions = [version1, version2, version3]

        // Then
        XCTAssertEqual(recipe.generationLabel, "3 Generations", "Should show '3 Generations' with 3 versions")
    }

    func testGenerationLabel_ManyVersions() {
        // Given
        let recipe = Recipe(title: "Test", sourceType: .manual)
        var versions: [RecipeVersion] = []
        for index in 1...5 {
            let isBase = (index == 1)
            versions.append(RecipeVersion(
                creatorUserID: "user\(index)",
                creatorDisplayName: "User \(index)",
                creationYear: "202\(index)",
                isBaseVersion: isBase
            ))
        }
        recipe.versions = versions

        // Then
        XCTAssertEqual(recipe.generationLabel, "5 Generations", "Should show '5 Generations' with 5 versions")
    }

    // MARK: - Recipe Creation Tests

    func testRecipe_Initialization() {
        // When
        let recipe = Recipe(title: "Test Recipe", sourceType: .manual)

        // Then
        XCTAssertEqual(recipe.title, "Test Recipe")
        XCTAssertEqual(recipe.sourceType, .manual)
        XCTAssertNotNil(recipe.id, "Should have ID")
        XCTAssertNotNil(recipe.dateAdded, "Should have creation date")
        XCTAssertNotNil(recipe.lastModified, "Should have update date")
    }

    func testRecipe_DefaultValues() {
        // When
        let recipe = Recipe(title: "Test", sourceType: .manual)

        // Then
        XCTAssertFalse(recipe.isFavorite, "Should default to not favorite")
        XCTAssertTrue(recipe.instructions.isEmpty, "Should default to empty instructions")
        XCTAssertNil(recipe.servings)
        XCTAssertNil(recipe.prepTime)
        XCTAssertNil(recipe.cookTime)
    }

    // MARK: - Ingredient Relationship Tests

    func testRecipe_WithIngredients() {
        // Given
        let recipe = TestFixtures.mockRecipe(context: modelContext)

        // Then
        XCTAssertNotNil(recipe.ingredients, "Should have ingredients")
        XCTAssertGreaterThan(recipe.ingredients?.count ?? 0, 0, "Should have at least one ingredient")
    }

    func testRecipe_IngredientRecipeRelationship() {
        // Given
        let recipe = TestFixtures.mockRecipe(context: modelContext)

        // Then
        let firstIngredient = recipe.ingredients?.first
        XCTAssertNotNil(firstIngredient)
        XCTAssertEqual(firstIngredient?.recipe?.id, recipe.id, "Ingredient should reference recipe")
    }

    // MARK: - Version Selection Tests

    func testSelectVersion_ValidVersion() {
        // Given
        let recipe = TestFixtures.mockRecipeWithVersions(context: modelContext)
        let version = recipe.versions?.last
        XCTAssertNotNil(version)

        // When
        recipe.selectedVersionID = version?.id

        // Then
        XCTAssertEqual(recipe.selectedVersionID, version?.id)
        XCTAssertEqual(recipe.activeVersion?.id, version?.id)
    }

    func testSelectVersion_ClearsSelection() {
        // Given
        let recipe = TestFixtures.mockRecipeWithVersions(context: modelContext)
        recipe.selectedVersionID = recipe.versions?.first?.id

        // When
        recipe.selectedVersionID = nil

        // Then
        XCTAssertNil(recipe.selectedVersionID)
        XCTAssertNotNil(recipe.activeVersion, "Should fall back to base version")
    }

    // MARK: - Source Type Tests

    func testSourceType_AllValues() {
        // Test all source types can be created
        let manualRecipe = Recipe(title: "Manual", sourceType: .manual)
        XCTAssertEqual(manualRecipe.sourceType, .manual)

        let urlRecipe = Recipe(title: "URL", sourceType: .url)
        XCTAssertEqual(urlRecipe.sourceType, .url)

        let scanRecipe = Recipe(title: "Scan", sourceType: .scan)
        XCTAssertEqual(scanRecipe.sourceType, .scan)

        let cookbookRecipe = Recipe(title: "Cookbook", sourceType: .cookbook)
        XCTAssertEqual(cookbookRecipe.sourceType, .cookbook)

        let familyRecipe = Recipe(title: "Family", sourceType: .family)
        XCTAssertEqual(familyRecipe.sourceType, .family)
    }

    // MARK: - Persistence Tests

    func testRecipe_PersistsToDatabase() throws {
        // Given
        let recipe = Recipe(title: "Persistent Recipe", sourceType: .manual)
        modelContext.insert(recipe)

        // When
        try modelContext.save()

        // Then
        let descriptor = FetchDescriptor<Recipe>()
        let fetchedRecipes = try modelContext.fetch(descriptor)
        XCTAssertEqual(fetchedRecipes.count, 1)
        XCTAssertEqual(fetchedRecipes.first?.title, "Persistent Recipe")
    }

    func testRecipe_UpdateTimestamp() throws {
        // Given
        let recipe = Recipe(title: "Test", sourceType: .manual)
        modelContext.insert(recipe)
        try modelContext.save()

        let originalLastModified = recipe.lastModified

        // When
        recipe.title = "Updated Test"
        recipe.lastModified = Date()
        try modelContext.save()

        // Then
        XCTAssertGreaterThan(recipe.lastModified, originalLastModified, "Updated timestamp should be later")
    }
}
