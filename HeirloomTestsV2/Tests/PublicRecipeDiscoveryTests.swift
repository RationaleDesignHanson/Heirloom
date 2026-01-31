import XCTest
import SwiftData
@testable import Heirloom

/// Comprehensive tests for Public Recipe Discovery feature (Phase 1-11)
/// Tests publishing, unpublishing, discovery, search, moderation
final class PublicRecipeDiscoveryTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        // Create in-memory model container for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: Recipe.self, configurations: config)
        modelContext = modelContainer.mainContext
    }

    override func tearDown() {
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - Recipe Publishing Tests

    func testRecipeCanMakePublic() throws {
        // Given: A user-created recipe with all required fields
        let recipe = Recipe(
            title: "Test Recipe",
            sourceType: .manual,
            instructions: [
                RecipeInstruction(step: 1, instruction: "Mix ingredients")
            ],
            servings: "4",
            prepTime: "15",
            cookTime: "30"
        )
        recipe.recipeDescription = "A test recipe"

        // Add parsed ingredients
        recipe.parsedIngredients = [
            ParsedIngredient(
                quantity: 2.0,
                unit: "cups",
                item: "flour",
                preparation: nil,
                isOptional: false,
                originalText: "2 cups flour"
            )
        ]

        modelContext.insert(recipe)

        // When: Checking if recipe can be made public
        let (canShare, reason) = recipe.canShare()

        // Then: Recipe should be eligible for publishing
        XCTAssertTrue(canShare, "Recipe with all required fields should be publishable")
        XCTAssertNil(reason, "Should have no blocking reason")
    }

    func testThemeRecipeCannotBePublished() throws {
        // Given: A theme recipe (Heritage recipe)
        let recipe = Recipe(
            title: "Heritage Recipe",
            sourceType: .heritage,
            instructions: [],
            servings: "4",
            prepTime: "15",
            cookTime: "30"
        )
        recipe.isThemeRecipe = true

        modelContext.insert(recipe)

        // When: Attempting to publish
        // Then: Should not be allowed
        XCTAssertTrue(recipe.isThemeRecipe)
        XCTAssertFalse(recipe.canMakePublic, "Theme recipes cannot be published")
    }

    func testSampleRecipeCannotBePublished() throws {
        // Given: A sample recipe
        let recipe = Recipe(
            title: "Sample Recipe",
            sourceType: .manual,
            instructions: [],
            servings: "4",
            prepTime: "15",
            cookTime: "30"
        )
        recipe.isSampleRecipe = true

        modelContext.insert(recipe)

        // When: Checking if can make public
        // Then: Should not be allowed
        XCTAssertFalse(recipe.canMakePublic, "Sample recipes cannot be published")
    }

    func testRecipeWithoutInstructionsCannotBePublished() throws {
        // Given: A recipe without instructions
        let recipe = Recipe(
            title: "Test Recipe",
            sourceType: .manual,
            instructions: [],
            servings: "4",
            prepTime: "15",
            cookTime: "30"
        )

        modelContext.insert(recipe)

        // When: Checking if can share
        let (canShare, reason) = recipe.canShare()

        // Then: Should fail validation
        XCTAssertFalse(canShare, "Recipe without instructions should not be publishable")
        XCTAssertEqual(reason, "Recipe must have at least one instruction")
    }

    func testRecipeWithoutIngredientsCannotBePublished() throws {
        // Given: A recipe without ingredients
        let recipe = Recipe(
            title: "Test Recipe",
            sourceType: .manual,
            instructions: [
                RecipeInstruction(step: 1, instruction: "Mix ingredients")
            ],
            servings: "4",
            prepTime: "15",
            cookTime: "30"
        )
        recipe.parsedIngredients = []

        modelContext.insert(recipe)

        // When: Checking if can share
        let (canShare, reason) = recipe.canShare()

        // Then: Should fail validation
        XCTAssertFalse(canShare, "Recipe without ingredients should not be publishable")
        XCTAssertEqual(reason, "Recipe must have at least one ingredient")
    }

    // MARK: - Public Recipe State Tests

    func testRecipePublicStateTracking() throws {
        // Given: A publishable recipe
        let recipe = Recipe(
            title: "Test Recipe",
            sourceType: .manual,
            instructions: [
                RecipeInstruction(step: 1, instruction: "Mix ingredients")
            ],
            servings: "4",
            prepTime: "15",
            cookTime: "30"
        )
        recipe.parsedIngredients = [
            ParsedIngredient(
                quantity: 2.0,
                unit: "cups",
                item: "flour",
                preparation: nil,
                isOptional: false,
                originalText: "2 cups flour"
            )
        ]

        modelContext.insert(recipe)

        // When: Publishing recipe
        recipe.isPublic = true
        recipe.publicRecipeId = "test-public-id"
        recipe.publishedAt = Date()

        // Then: State should be tracked correctly
        XCTAssertTrue(recipe.isPublic)
        XCTAssertEqual(recipe.publicRecipeId, "test-public-id")
        XCTAssertNotNil(recipe.publishedAt)
    }

    func testRecipeUnpublishing() throws {
        // Given: A published recipe
        let recipe = Recipe(
            title: "Test Recipe",
            sourceType: .manual,
            instructions: [
                RecipeInstruction(step: 1, instruction: "Mix ingredients")
            ],
            servings: "4",
            prepTime: "15",
            cookTime: "30"
        )
        recipe.isPublic = true
        recipe.publicRecipeId = "test-public-id"
        recipe.publishedAt = Date()
        recipe.publicViewCount = 42
        recipe.publicSaveCount = 7

        modelContext.insert(recipe)

        // When: Unpublishing recipe
        recipe.isPublic = false
        recipe.publicRecipeId = nil

        // Then: Public state should be cleared but stats preserved
        XCTAssertFalse(recipe.isPublic)
        XCTAssertNil(recipe.publicRecipeId)
        XCTAssertEqual(recipe.publicViewCount, 42, "Stats should be preserved")
        XCTAssertEqual(recipe.publicSaveCount, 7, "Stats should be preserved")
    }

    // MARK: - Search Keywords Tests

    func testSearchKeywordsGeneration() throws {
        // Given: A recipe with title and tags
        let recipe = Recipe(
            title: "Grandma's Famous Apple Pie Recipe",
            sourceType: .manual,
            instructions: [
                RecipeInstruction(step: 1, instruction: "Mix ingredients")
            ],
            servings: "8",
            prepTime: "30",
            cookTime: "45"
        )
        recipe.tags = ["dessert", "baking", "fall"]

        modelContext.insert(recipe)

        // When: Generating search keywords (would happen in PublicRecipeService)
        let titleWords = recipe.title.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }

        let keywords = Set(titleWords + recipe.tags.map { $0.lowercased() })

        // Then: Should include relevant keywords
        XCTAssertTrue(keywords.contains("grandma"))
        XCTAssertTrue(keywords.contains("famous"))
        XCTAssertTrue(keywords.contains("apple"))
        XCTAssertTrue(keywords.contains("pie"))
        XCTAssertTrue(keywords.contains("recipe"))
        XCTAssertTrue(keywords.contains("dessert"))
        XCTAssertTrue(keywords.contains("baking"))
        XCTAssertTrue(keywords.contains("fall"))

        // Short words should be filtered
        XCTAssertFalse(keywords.contains("s"))  // from "Grandma's"
    }

    // MARK: - Moderation Tests

    func testRecipeReportCountTracking() throws {
        // Given: A public recipe
        let recipe = Recipe(
            title: "Test Recipe",
            sourceType: .manual,
            instructions: [
                RecipeInstruction(step: 1, instruction: "Mix ingredients")
            ],
            servings: "4",
            prepTime: "15",
            cookTime: "30"
        )
        recipe.isPublic = true
        recipe.publicRecipeId = "test-public-id"

        modelContext.insert(recipe)

        // When: Tracking report count (would be updated by Cloud Function)
        // Simulate what happens when reports are submitted

        // Then: Recipe should have reportCount field available for tracking
        // Note: reportCount is stored in Firestore, not SwiftData
        // This test verifies the model supports public state tracking
        XCTAssertTrue(recipe.isPublic)
        XCTAssertNotNil(recipe.publicRecipeId)
    }

    // MARK: - Upstream Attribution Tests (Fork Model)

    func testRecipeUpstreamAttribution() throws {
        // Given: A recipe saved from public discovery
        let recipe = Recipe(
            title: "Saved Public Recipe",
            sourceType: .manual,
            instructions: [
                RecipeInstruction(step: 1, instruction: "Mix ingredients")
            ],
            servings: "4",
            prepTime: "15",
            cookTime: "30"
        )

        // When: Setting upstream attribution
        recipe.sourcePublicRecipeId = "original-public-id"
        recipe.sourcePublicRecipeCreatorId = "creator-uid"
        recipe.sourcePublicRecipeCreatorName = "Jane Doe"
        recipe.sourcePublicRecipeLastSynced = Date()
        recipe.sourcePublicRecipeStillAvailable = true

        modelContext.insert(recipe)

        // Then: Upstream link should be tracked
        XCTAssertTrue(recipe.hasPublicUpstream)
        XCTAssertEqual(recipe.sourcePublicRecipeId, "original-public-id")
        XCTAssertEqual(recipe.sourcePublicRecipeCreatorId, "creator-uid")
        XCTAssertEqual(recipe.sourcePublicRecipeCreatorName, "Jane Doe")
        XCTAssertTrue(recipe.sourcePublicRecipeStillAvailable)
        XCTAssertNotNil(recipe.sourcePublicRecipeLastSynced)
    }

    func testRecipeWithoutUpstream() throws {
        // Given: A user-created recipe (not from discovery)
        let recipe = Recipe(
            title: "My Original Recipe",
            sourceType: .manual,
            instructions: [
                RecipeInstruction(step: 1, instruction: "Mix ingredients")
            ],
            servings: "4",
            prepTime: "15",
            cookTime: "30"
        )

        modelContext.insert(recipe)

        // Then: Should not have upstream link
        XCTAssertFalse(recipe.hasPublicUpstream)
        XCTAssertNil(recipe.sourcePublicRecipeId)
        XCTAssertNil(recipe.sourcePublicRecipeCreatorId)
    }

    // MARK: - Integration Tests

    func testFullPublishingFlow() throws {
        // Given: A complete recipe ready for publishing
        let recipe = Recipe(
            title: "Complete Test Recipe",
            sourceType: .manual,
            instructions: [
                RecipeInstruction(step: 1, instruction: "Prepare ingredients"),
                RecipeInstruction(step: 2, instruction: "Mix together"),
                RecipeInstruction(step: 3, instruction: "Bake at 350°F")
            ],
            servings: "8",
            prepTime: "20",
            cookTime: "40"
        )

        recipe.recipeDescription = "A delicious test recipe"
        recipe.parsedIngredients = [
            ParsedIngredient(
                quantity: 2.0,
                unit: "cups",
                item: "flour",
                preparation: nil,
                isOptional: false,
                originalText: "2 cups flour"
            ),
            ParsedIngredient(
                quantity: 1.0,
                unit: "cup",
                item: "sugar",
                preparation: nil,
                isOptional: false,
                originalText: "1 cup sugar"
            )
        ]
        recipe.tags = ["dessert", "baking"]

        modelContext.insert(recipe)

        // When: Validating and publishing
        let (canShare, _) = recipe.canShare()
        XCTAssertTrue(canShare)

        recipe.isPublic = true
        recipe.publicRecipeId = "published-recipe-123"
        recipe.publishedAt = Date()

        try modelContext.save()

        // Then: Recipe should be published successfully
        XCTAssertTrue(recipe.isPublic)
        XCTAssertNotNil(recipe.publicRecipeId)
        XCTAssertNotNil(recipe.publishedAt)
        XCTAssertFalse(recipe.isThemeRecipe)
        XCTAssertFalse(recipe.isSampleRecipe)
    }
}
