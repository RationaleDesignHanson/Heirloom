import Testing
import Foundation
import SwiftData

@testable import Heirloom

@Suite("Recipe Heritage Lifecycle Tests")
struct RecipeHeritageLifecycleTests {

    // MARK: - Test Setup Helper

    func createTestContext() -> ModelContext {
        let schema = Schema([
            Heirloom.Recipe.self,
            Heirloom.Ingredient.self,
            Heirloom.Tag.self,
            Heirloom.RecipeCollection.self,
            Heirloom.RecipeCardBack.self,
            Heirloom.Customization.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    // MARK: - Basic Copy Tests

    @Test("createUserCopy creates a new recipe instance")
    func testCreateUserCopy_CreatesNewInstance() {
        // Arrange
        let context = createTestContext()
        let original = Heirloom.Recipe(title: "Heritage Chocolate Cake")
        context.insert(original)

        // Act
        let copy = original.createUserCopy(context: context)

        // Assert
        #expect(copy.id != original.id)
        #expect(copy.title == "Heritage Chocolate Cake")
    }

    @Test("createUserCopy copies basic recipe fields")
    func testCreateUserCopy_CopiesBasicFields() {
        // Arrange
        let context = createTestContext()
        let original = Heirloom.Recipe(
            title: "Test Recipe",
            sourceType: .cookbook,
            instructions: ["Mix and bake"],
            servings: "12 servings",
            prepTime: "30 min",
            cookTime: "45 min"
        )
        original.totalTime = "1 hr 15 min"
        original.sourceBookTitle = "Joy of Cooking"
        original.sourceBookAuthor = "Irma S. Rombauer"
        original.sourceBookPage = 123
        original.setNotes("Original notes")
        context.insert(original)

        // Act
        let copy = original.createUserCopy(context: context)

        // Assert
        #expect(copy.title == "Test Recipe")
        #expect(copy.sourceType == .cookbook)
        #expect(copy.instructions == ["Mix and bake"])
        #expect(copy.servings == "12 servings")
        #expect(copy.prepTime == "30 min")
        #expect(copy.cookTime == "45 min")
        #expect(copy.totalTime == "1 hr 15 min")
        #expect(copy.sourceBookTitle == "Joy of Cooking")
        #expect(copy.sourceBookAuthor == "Irma S. Rombauer")
        #expect(copy.sourceBookPage == 123)
        #expect(copy.notes == "Original notes")
    }

    @Test("createUserCopy copies image references")
    func testCreateUserCopy_CopiesImageReferences() {
        // Arrange
        let context = createTestContext()
        let original = Heirloom.Recipe(title: "Test Recipe")
        original.imageFileName = "recipe-123.jpg"
        original.sourceImageURL = "https://example.com/image.jpg"
        original.firebaseImageURL = "gs://bucket/image.jpg"
        original.blurhash = "LKO2?U%2Tw=w]~RBVZRi};RPxuwH"
        original.imageVariants = ["thumb": "recipe-123-thumb.jpg"]
        context.insert(original)

        // Act
        let copy = original.createUserCopy(context: context)

        // Assert
        #expect(copy.imageFileName == "recipe-123.jpg")
        #expect(copy.sourceImageURL == "https://example.com/image.jpg")
        #expect(copy.firebaseImageURL == "gs://bucket/image.jpg")
        #expect(copy.blurhash == "LKO2?U%2Tw=w]~RBVZRi};RPxuwH")
        #expect(copy.imageVariants == ["thumb": "recipe-123-thumb.jpg"])
    }

    // MARK: - Heritage Metadata Tests

    @Test("createUserCopy marks heritage copy as non-heritage")
    func testCreateUserCopy_HeritageRecipe_MarksAsNonHeritage() {
        // Arrange
        let context = createTestContext()
        let original = Heirloom.Recipe(title: "Heritage Recipe")
        original.isThemeRecipe = true
        original.sourceThemeId = "founding-collection-1"
        original.historicalText = "A recipe from 1890"
        original.historicalContext = "Victorian era baking"
        context.insert(original)

        // Act
        let copy = original.createUserCopy(context: context)

        // Assert
        #expect(copy.isThemeRecipe == false)
        #expect(copy.sourceThemeId == "founding-collection-1")
        #expect(copy.historicalText == "A recipe from 1890")
        #expect(copy.historicalContext == "Victorian era baking")
    }

    @Test("createUserCopy updates provenance for heritage recipes")
    func testCreateUserCopy_HeritageRecipe_UpdatesProvenance() {
        // Arrange
        let context = createTestContext()
        let original = Heirloom.Recipe(title: "Heritage Recipe")
        original.isThemeRecipe = true
        original.provenance = ProvenanceMetadata(
            sourceType: .userCreated,
            sourceURL: "https://example.com",
            sourceAttribution: "Original Heritage Collection",
            generation: 0
        )
        context.insert(original)

        // Act
        let copy = original.createUserCopy(context: context)

        // Assert
        #expect(copy.provenance != nil)
        #expect(copy.provenance?.sourceType == .shared)
        #expect(copy.provenance?.generation == 1)
        #expect(copy.provenance?.sourceAttribution == "Original Heritage Collection")
    }

    @Test("createUserCopy preserves provenance for non-heritage recipes")
    func testCreateUserCopy_NonHeritage_PreservesProvenance() {
        // Arrange
        let context = createTestContext()
        let original = Heirloom.Recipe(title: "User Recipe")
        original.isThemeRecipe = false
        original.provenance = ProvenanceMetadata(
            sourceType: .imported,
            sourceURL: "https://example.com",
            generation: 2
        )
        context.insert(original)

        // Act
        let copy = original.createUserCopy(context: context)

        // Assert
        #expect(copy.provenance?.sourceType == .imported)
        #expect(copy.provenance?.generation == 2)
    }

    // MARK: - Ingredient Copying Tests

    @Test("createUserCopy copies ingredients")
    func testCreateUserCopy_CopiesIngredients() {
        // Arrange
        let context = createTestContext()
        let original = Heirloom.Recipe(title: "Test Recipe")
        context.insert(original)

        let ingredient1 = Heirloom.Ingredient(
            originalText: "2 cups flour",
            name: "flour",
            quantity: 2.0,
            unit: "cups",
            category: .bakery,
            orderIndex: 0
        )
        ingredient1.recipe = original

        let ingredient2 = Heirloom.Ingredient(
            originalText: "1 tsp salt",
            name: "salt",
            quantity: 1.0,
            unit: "tsp",
            category: .spices,
            orderIndex: 1
        )
        ingredient2.recipe = original

        // Act
        let copy = original.createUserCopy(context: context)

        // Assert
        #expect(copy.ingredients?.count == 2)
        #expect(copy.ingredients?[0].name == "flour")
        #expect(copy.ingredients?[0].quantity == 2.0)
        #expect(copy.ingredients?[1].name == "salt")
        #expect(copy.ingredients?[1].quantity == 1.0)
    }

    @Test("createUserCopy creates new ingredient instances")
    func testCreateUserCopy_CreatesNewIngredientInstances() {
        // Arrange
        let context = createTestContext()
        let original = Heirloom.Recipe(title: "Test Recipe")
        context.insert(original)

        let ingredient = Heirloom.Ingredient(
            originalText: "2 cups flour",
            name: "flour",
            quantity: 2.0,
            unit: "cups",
            category: .bakery,
            orderIndex: 0
        )
        ingredient.recipe = original

        // Act
        let copy = original.createUserCopy(context: context)

        // Assert
        #expect(copy.ingredients?[0].id != ingredient.id)
        #expect(copy.ingredients?[0].recipe?.id == copy.id)
    }

    // MARK: - Collection and Tag Copying Tests

    @Test("createUserCopy copies collections")
    func testCreateUserCopy_CopiesCollections() {
        // Arrange
        let context = createTestContext()
        let original = Heirloom.Recipe(title: "Test Recipe")
        context.insert(original)

        let collection1 = RecipeCollection(name: "Desserts")
        let collection2 = RecipeCollection(name: "Favorites")
        context.insert(collection1)
        context.insert(collection2)

        original.collections = [collection1, collection2]

        // Act
        let copy = original.createUserCopy(context: context)

        // Assert
        #expect(copy.collections?.count == 2)
        #expect(copy.collections?.contains(where: { $0.name == "Desserts" }) == true)
        #expect(copy.collections?.contains(where: { $0.name == "Favorites" }) == true)
    }

    @Test("createUserCopy copies tags")
    func testCreateUserCopy_CopiesTags() {
        // Arrange
        let context = createTestContext()
        let original = Heirloom.Recipe(title: "Test Recipe")
        context.insert(original)

        let tag1 = Tag(name: "quick")
        let tag2 = Tag(name: "easy")
        context.insert(tag1)
        context.insert(tag2)

        original.tags = [tag1, tag2]

        // Act
        let copy = original.createUserCopy(context: context)

        // Assert
        #expect(copy.tags?.count == 2)
        #expect(copy.tags?.contains(where: { $0.name == "quick" }) == true)
        #expect(copy.tags?.contains(where: { $0.name == "easy" }) == true)
    }

    // MARK: - Scaling Metadata Tests

    @Test("createUserCopy copies scaling metadata")
    func testCreateUserCopy_CopiesScalingMetadata() {
        // Arrange
        let context = createTestContext()
        let original = Heirloom.Recipe(title: "Test Recipe")
        original.scalabilityRating = "moderate"
        original.recipeCategory = "Cookies"
        original.minimumServings = 6
        original.maximumServings = 48
        original.scalingNote = "Double carefully"
        context.insert(original)

        // Act
        let copy = original.createUserCopy(context: context)

        // Assert
        #expect(copy.scalabilityRating == "moderate")
        #expect(copy.recipeCategory == "Cookies")
        #expect(copy.minimumServings == 6)
        #expect(copy.maximumServings == 48)
        #expect(copy.scalingNote == "Double carefully")
    }

    // MARK: - Usage Stats Not Copied Tests

    @Test("createUserCopy does NOT copy usage stats")
    func testCreateUserCopy_DoesNotCopyUsageStats() {
        // Arrange
        let context = createTestContext()
        let original = Heirloom.Recipe(title: "Test Recipe")
        original.timesCooked = 15
        original.lastCooked = Date()
        original.isFavorite = true
        context.insert(original)

        // Act
        let copy = original.createUserCopy(context: context)

        // Assert
        #expect(copy.timesCooked == 0)
        #expect(copy.lastCooked == nil)
        #expect(copy.isFavorite == false)
    }

    @Test("createUserCopy does NOT copy social fields")
    func testCreateUserCopy_DoesNotCopySocialFields() {
        // Arrange
        let context = createTestContext()
        let original = Heirloom.Recipe(title: "Test Recipe")
        original.sharedBy = "Grandma"
        original.passedDownBy = "Mom"
        context.insert(original)

        // Act
        let copy = original.createUserCopy(context: context)

        // Assert
        #expect(copy.sharedBy == nil)
        #expect(copy.passedDownBy == nil)
    }

    // MARK: - Should Consider for Cleanup Tests

    @Test("shouldConsiderForCleanup returns false for non-heritage recipe")
    func testShouldConsiderForCleanup_NonHeritage_ReturnsFalse() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "User Recipe")
        recipe.isThemeRecipe = false

        // Act & Assert
        #expect(recipe.shouldConsiderForCleanup == false)
    }

    @Test("shouldConsiderForCleanup returns false when recipe is cooked")
    func testShouldConsiderForCleanup_Cooked_ReturnsFalse() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Heritage Recipe")
        recipe.isThemeRecipe = true
        recipe.timesCooked = 1

        // Act & Assert
        #expect(recipe.shouldConsiderForCleanup == false)
    }

    @Test("shouldConsiderForCleanup returns false when recipe is favorited")
    func testShouldConsiderForCleanup_Favorited_ReturnsFalse() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Heritage Recipe")
        recipe.isThemeRecipe = true
        recipe.isFavorite = true

        // Act & Assert
        #expect(recipe.shouldConsiderForCleanup == false)
    }

    @Test("shouldConsiderForCleanup returns false when recipe has notes")
    func testShouldConsiderForCleanup_HasNotes_ReturnsFalse() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Heritage Recipe")
        recipe.isThemeRecipe = true
        recipe.notes = "My modifications"

        // Act & Assert
        #expect(recipe.shouldConsiderForCleanup == false)
    }

    @Test("shouldConsiderForCleanup returns false when recipe is less than 30 days old")
    func testShouldConsiderForCleanup_LessThan30Days_ReturnsFalse() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Heritage Recipe")
        recipe.isThemeRecipe = true
        recipe.dateAdded = Calendar.current.date(byAdding: .day, value: -20, to: Date())!

        // Act & Assert
        #expect(recipe.shouldConsiderForCleanup == false)
    }

    @Test("shouldConsiderForCleanup returns true for unmodified heritage recipe over 30 days")
    func testShouldConsiderForCleanup_UnmodifiedOld_ReturnsTrue() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Heritage Recipe")
        recipe.isThemeRecipe = true
        recipe.timesCooked = 0
        recipe.isFavorite = false
        recipe.notes = nil
        recipe.dateAdded = Calendar.current.date(byAdding: .day, value: -31, to: Date())!

        // Act & Assert
        #expect(recipe.shouldConsiderForCleanup == true)
    }

    @Test("shouldConsiderForCleanup returns false when notes is empty string")
    func testShouldConsiderForCleanup_EmptyNotes_ReturnsTrue() {
        // Arrange
        let recipe = Heirloom.Recipe(title: "Heritage Recipe")
        recipe.isThemeRecipe = true
        recipe.timesCooked = 0
        recipe.isFavorite = false
        recipe.notes = ""
        recipe.dateAdded = Calendar.current.date(byAdding: .day, value: -31, to: Date())!

        // Act & Assert
        #expect(recipe.shouldConsiderForCleanup == true)
    }
}
