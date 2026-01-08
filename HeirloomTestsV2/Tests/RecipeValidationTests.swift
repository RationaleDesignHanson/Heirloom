import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class RecipeValidationTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([
            Heirloom.Recipe.self,
            Heirloom.Ingredient.self,
            Heirloom.Tag.self,
            Heirloom.RecipeCollection.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - Time Parsing Tests

    func testRecipe_ParsePrepTime_MinutesOnly() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.prepTime = "30 min"

        // Act & Assert
        XCTAssertEqual(recipe.parsedPrepTime, 30)
    }

    func testRecipe_ParsePrepTime_HoursAndMinutes() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.prepTime = "1 hr 30 min"

        // Act & Assert
        XCTAssertEqual(recipe.parsedPrepTime, 90)
    }

    func testRecipe_ParsePrepTime_HoursOnly() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.prepTime = "2 hours"

        // Act & Assert
        XCTAssertEqual(recipe.parsedPrepTime, 120)
    }

    func testRecipe_ParsePrepTime_PlainNumber() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.prepTime = "45"

        // Act & Assert
        XCTAssertEqual(recipe.parsedPrepTime, 45)
    }

    func testRecipe_ParsePrepTime_InvalidString() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.prepTime = "some time"

        // Act & Assert
        XCTAssertEqual(recipe.parsedPrepTime, 0)
    }

    func testRecipe_ParsePrepTime_NilValue() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.prepTime = nil

        // Act & Assert
        XCTAssertEqual(recipe.parsedPrepTime, 0)
    }

    func testRecipe_ParseCookTime_Success() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.cookTime = "1 hr 15 min"

        // Act & Assert
        XCTAssertEqual(recipe.parsedCookTime, 75)
    }

    // MARK: - Servings Parsing Tests

    func testRecipe_ParseServings_SimpleNumber() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.servings = "6"

        // Act & Assert
        XCTAssertEqual(recipe.parsedServingCount, 6)
    }

    func testRecipe_ParseServings_WithText() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.servings = "8 servings"

        // Act & Assert
        XCTAssertEqual(recipe.parsedServingCount, 8)
    }

    func testRecipe_ParseServings_MakesFormat() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.servings = "Makes 12 cookies"

        // Act & Assert
        XCTAssertEqual(recipe.parsedServingCount, 12)
    }

    func testRecipe_ParseServings_Range() throws {
        // Arrange - Should extract first number
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.servings = "4-6 servings"

        // Act & Assert
        XCTAssertEqual(recipe.parsedServingCount, 4)
    }

    func testRecipe_ParseServings_NilDefault() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.servings = nil

        // Act & Assert
        XCTAssertEqual(recipe.parsedServingCount, 4) // Default
    }

    func testRecipe_ParseServings_InvalidStringDefault() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.servings = "some servings"

        // Act & Assert
        XCTAssertEqual(recipe.parsedServingCount, 4) // Default
    }

    // MARK: - Scaling Validation Tests

    func testRecipe_Scaling_IsAllowedByDefault() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")

        // Act & Assert
        XCTAssertTrue(recipe.isScalingAllowed)
        XCTAssertEqual(recipe.scalability, .easy)
    }

    func testRecipe_Scaling_LockedRecipeNotAllowed() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.scalability = .locked

        // Act & Assert
        XCTAssertFalse(recipe.isScalingAllowed)
        XCTAssertNil(recipe.allowedServingRange)
    }

    func testRecipe_Scaling_AllowedRange_WithMax() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.minimumServings = 2
        recipe.maximumServings = 12

        // Act & Assert
        XCTAssertEqual(recipe.allowedServingRange, 2...12)
    }

    func testRecipe_Scaling_AllowedRange_DefaultMax() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.minimumServings = 1
        recipe.maximumServings = nil

        // Act & Assert
        XCTAssertEqual(recipe.allowedServingRange, 1...16) // Default max
    }

    func testRecipe_Scaling_DisplayString_Allowed() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.servings = "4 servings"
        recipe.scalability = .easy

        // Act & Assert
        XCTAssertEqual(recipe.scalingDisplayString, "4 servings")
    }

    func testRecipe_Scaling_DisplayString_Locked() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.servings = "6 servings"
        recipe.scalability = .locked

        // Act & Assert
        XCTAssertEqual(recipe.scalingDisplayString, "6 servings (fixed)")
    }

    func testRecipe_Scaling_AvailableServingSizes_LockedRecipe() throws {
        // Arrange - locked recipes without category still get default presets
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.servings = "8 servings"
        recipe.scalability = .locked

        // Act & Assert
        // Without category, locked recipes still get default presets [2,4,6,8,12]
        // The locked check only applies when category is set
        let sizes = recipe.availableServingSizes
        XCTAssertTrue(sizes.contains(8), "Should include original serving size")
        XCTAssertGreaterThan(sizes.count, 1, "Without category, gets default presets even when locked")
        XCTAssertEqual(sizes, [2, 4, 6, 8, 12])
    }

    func testRecipe_Scaling_AvailableServingSizes_IncludesOriginal() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.servings = "7 servings" // Non-standard number
        recipe.category = .casserole
        recipe.minimumServings = 2
        recipe.maximumServings = 12

        // Act & Assert
        let sizes = recipe.availableServingSizes
        XCTAssertTrue(sizes.contains(7), "Should include original serving size")
    }

    // MARK: - Love Marks Logic Tests

    func testRecipe_LoveMarks_NotShownUnderFiveCooks() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.timesCooked = 4

        // Act & Assert
        XCTAssertFalse(recipe.shouldShowLoveMarks)
    }

    func testRecipe_LoveMarks_ShownAtFiveCooks() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.timesCooked = 5

        // Act & Assert
        XCTAssertTrue(recipe.shouldShowLoveMarks)
    }

    func testRecipe_LoveMarks_ShownAboveFiveCooks() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.timesCooked = 20

        // Act & Assert
        XCTAssertTrue(recipe.shouldShowLoveMarks)
    }

    func testRecipe_LoveMarks_Intensity_MinimumThreshold() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.timesCooked = 5

        // Act & Assert
        XCTAssertEqual(recipe.loveMarkIntensity, 0.25, accuracy: 0.01)
    }

    func testRecipe_LoveMarks_Intensity_MaximumCapped() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.timesCooked = 50

        // Act & Assert
        XCTAssertEqual(recipe.loveMarkIntensity, 1.0, accuracy: 0.01) // Capped at 1.0
    }

    func testRecipe_LoveMarks_Intensity_MidRange() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.timesCooked = 10

        // Act & Assert
        XCTAssertEqual(recipe.loveMarkIntensity, 0.5, accuracy: 0.01)
    }

    // MARK: - Source Display Name Tests

    func testRecipe_SourceDisplayName_URL_WithHost() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.sourceType = .url
        recipe.sourceURL = "https://www.example.com/recipes/test"

        // Act & Assert
        XCTAssertEqual(recipe.sourceDisplayName, "example.com")
    }

    func testRecipe_SourceDisplayName_URL_WithoutHost() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.sourceType = .url
        recipe.sourceURL = "invalid-url"

        // Act & Assert
        XCTAssertEqual(recipe.sourceDisplayName, "Website")
    }

    func testRecipe_SourceDisplayName_Cookbook_WithPage() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.sourceType = .cookbook
        recipe.sourceBookTitle = "Joy of Cooking"
        recipe.sourceBookPage = 142

        // Act & Assert
        XCTAssertEqual(recipe.sourceDisplayName, "Joy of Cooking, p. 142")
    }

    func testRecipe_SourceDisplayName_Cookbook_NoPage() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.sourceType = .cookbook
        recipe.sourceBookTitle = "Joy of Cooking"

        // Act & Assert
        XCTAssertEqual(recipe.sourceDisplayName, "Joy of Cooking")
    }

    func testRecipe_SourceDisplayName_Family_WithDate() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.sourceType = .family
        recipe.sourcePerson = "Grandma"
        recipe.sourceDate = "1995"

        // Act & Assert
        XCTAssertEqual(recipe.sourceDisplayName, "Grandma, 1995")
    }

    func testRecipe_SourceDisplayName_Family_NoDate() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.sourceType = .family
        recipe.sourcePerson = "Grandma"

        // Act & Assert
        XCTAssertEqual(recipe.sourceDisplayName, "Grandma")
    }

    func testRecipe_SourceDisplayName_Manual() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.sourceType = .manual

        // Act & Assert
        XCTAssertEqual(recipe.sourceDisplayName, "My Recipe")
    }

    // MARK: - Ingredient Consolidation Tests

    func testRecipe_ConsolidatedIngredients_NoDuplicates() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        let ing1 = Heirloom.Ingredient(originalText: "1 cup flour", name: "flour", quantity: 1, unit: "cup", orderIndex: 0)
        let ing2 = Heirloom.Ingredient(originalText: "1 cup sugar", name: "sugar", quantity: 1, unit: "cup", orderIndex: 1)

        ing1.recipe = recipe
        ing2.recipe = recipe
        recipe.ingredients = [ing1, ing2]

        context.insert(recipe)
        context.insert(ing1)
        context.insert(ing2)
        try context.save()

        // Act
        let consolidated = recipe.consolidatedIngredients

        // Assert
        XCTAssertEqual(consolidated.count, 2)
    }

    func testRecipe_ConsolidatedIngredients_SameNameSameUnit() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        let ing1 = Heirloom.Ingredient(originalText: "1 cup flour", name: "flour", quantity: 1, unit: "cup", orderIndex: 0)
        let ing2 = Heirloom.Ingredient(originalText: "2 cups flour", name: "flour", quantity: 2, unit: "cup", orderIndex: 1)

        ing1.recipe = recipe
        ing2.recipe = recipe
        recipe.ingredients = [ing1, ing2]

        context.insert(recipe)
        context.insert(ing1)
        context.insert(ing2)
        try context.save()

        // Act
        let consolidated = recipe.consolidatedIngredients

        // Assert
        XCTAssertEqual(consolidated.count, 1, "Should consolidate duplicate ingredients")
        XCTAssertEqual(consolidated.first?.quantity, 3.0, "Should sum quantities")
        XCTAssertEqual(consolidated.first?.name, "flour")
    }

    func testRecipe_ConsolidatedIngredients_SameNameDifferentUnits() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        let ing1 = Heirloom.Ingredient(originalText: "1 cup flour", name: "flour", quantity: 1, unit: "cup", orderIndex: 0)
        let ing2 = Heirloom.Ingredient(originalText: "100g flour", name: "flour", quantity: 100, unit: "g", orderIndex: 1)

        ing1.recipe = recipe
        ing2.recipe = recipe
        recipe.ingredients = [ing1, ing2]

        context.insert(recipe)
        context.insert(ing1)
        context.insert(ing2)
        try context.save()

        // Act
        let consolidated = recipe.consolidatedIngredients

        // Assert
        XCTAssertEqual(consolidated.count, 2, "Should NOT consolidate different units")
    }

    func testRecipe_ConsolidatedIngredients_EmptyList() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.ingredients = []

        context.insert(recipe)
        try context.save()

        // Act
        let consolidated = recipe.consolidatedIngredients

        // Assert
        XCTAssertTrue(consolidated.isEmpty)
    }

    // MARK: - Generation and Provenance Tests

    func testRecipe_Generation_DefaultToOne() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")

        context.insert(recipe)
        try context.save()

        // Act & Assert
        XCTAssertEqual(recipe.generationCount, 1)
    }

    func testRecipe_Provenance_InitializedOnCreation() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe", sourceType: .manual)

        context.insert(recipe)
        try context.save()

        // Act & Assert
        XCTAssertNotNil(recipe.provenance)
        XCTAssertEqual(recipe.provenance?.sourceType, .userCreated)
        XCTAssertEqual(recipe.provenance?.generation, 0)
    }

    func testRecipe_IsOriginalRecipe_GenerationZero() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")

        context.insert(recipe)
        try context.save()

        // Act & Assert
        XCTAssertTrue(recipe.isOriginalRecipe)
    }

    func testRecipe_IsSharedRecipe_WithSharedBy() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.sharedBy = "Friend"

        context.insert(recipe)
        try context.save()

        // Act & Assert
        // Recipe automatically creates provenance with generation=0
        // isSharedRecipe checks provenance?.isShared which returns false (generation=0)
        // The sharedBy field is NOT checked when provenance exists
        XCTAssertFalse(recipe.isSharedRecipe, "Should be false when provenance.generation=0 even if sharedBy is set")
        XCTAssertEqual(recipe.sharedBy, "Friend", "sharedBy should still be set")
    }

    func testRecipe_GenerationDisplayText_FirstGeneration() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .shared,
            sourceURL: nil,
            generation: 1
        )

        context.insert(recipe)
        try context.save()

        // Act & Assert
        XCTAssertEqual(recipe.generationDisplayText, "1st Generation")
    }

    func testRecipe_GenerationDisplayText_SecondGeneration() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .shared,
            sourceURL: nil,
            generation: 2
        )

        context.insert(recipe)
        try context.save()

        // Act & Assert
        XCTAssertEqual(recipe.generationDisplayText, "2nd Generation")
    }

    func testRecipe_GenerationDisplayText_ThirdGeneration() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Test Recipe")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .shared,
            sourceURL: nil,
            generation: 3
        )

        context.insert(recipe)
        try context.save()

        // Act & Assert
        XCTAssertEqual(recipe.generationDisplayText, "3rd Generation")
    }

    // MARK: - Heritage Recipe Tests

    func testRecipe_HeritageRecipe_RequiresCollectionId() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Heritage Recipe")
        recipe.isHeritageRecipe = true
        recipe.heritageCollectionId = "presidential-pantry"

        context.insert(recipe)
        try context.save()

        // Act & Assert
        XCTAssertTrue(recipe.isHeritageRecipe)
        XCTAssertNotNil(recipe.heritageCollectionId)
    }

    func testRecipe_HeritageRecipe_ShouldNotCleanupIfCooked() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Heritage Recipe")
        recipe.isHeritageRecipe = true
        recipe.heritageCollectionId = "presidential-pantry"
        recipe.timesCooked = 3
        recipe.dateAdded = Calendar.current.date(byAdding: .day, value: -60, to: Date())!

        context.insert(recipe)
        try context.save()

        // Act & Assert
        XCTAssertFalse(recipe.shouldConsiderForCleanup)
    }

    func testRecipe_HeritageRecipe_ShouldNotCleanupIfFavorite() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Heritage Recipe")
        recipe.isHeritageRecipe = true
        recipe.heritageCollectionId = "presidential-pantry"
        recipe.isFavorite = true
        recipe.dateAdded = Calendar.current.date(byAdding: .day, value: -60, to: Date())!

        context.insert(recipe)
        try context.save()

        // Act & Assert
        XCTAssertFalse(recipe.shouldConsiderForCleanup)
    }

    func testRecipe_HeritageRecipe_ShouldNotCleanupIfHasNotes() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Heritage Recipe")
        recipe.isHeritageRecipe = true
        recipe.heritageCollectionId = "presidential-pantry"
        recipe.notes = "My notes"
        recipe.dateAdded = Calendar.current.date(byAdding: .day, value: -60, to: Date())!

        context.insert(recipe)
        try context.save()

        // Act & Assert
        XCTAssertFalse(recipe.shouldConsiderForCleanup)
    }

    func testRecipe_HeritageRecipe_ShouldNotCleanupIfTooNew() throws {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Heritage Recipe")
        recipe.isHeritageRecipe = true
        recipe.heritageCollectionId = "presidential-pantry"
        recipe.dateAdded = Calendar.current.date(byAdding: .day, value: -10, to: Date())!

        context.insert(recipe)
        try context.save()

        // Act & Assert
        XCTAssertFalse(recipe.shouldConsiderForCleanup)
    }

    // MARK: - RecipeSourceType Tests

    func testRecipeSourceType_AllCases_HaveIconNames() throws {
        // Act & Assert
        for sourceType in RecipeSourceType.allCases {
            XCTAssertFalse(sourceType.iconName.isEmpty, "\(sourceType) should have an icon name")
        }
    }

    func testRecipeSourceType_AllCases_HaveDisplayNames() throws {
        // Act & Assert
        for sourceType in RecipeSourceType.allCases {
            XCTAssertFalse(sourceType.displayName.isEmpty, "\(sourceType) should have a display name")
        }
    }
}
