import SnapshotTesting
import SwiftUI
import SwiftData
import XCTest
@testable import Heirloom

@MainActor
final class RecipeDetailSnapshotTests: SnapshotTestCase {

    // MARK: - Setup
    //
    // RecipeDetailView(recipe:) resolves services from ServiceContainer:
    //   RecipeImageGeneratorProtocol, BackendConfig, RecipeExportService,
    //   ToastManager, AnalyticsService, CommentService, RecipeLineageService
    //
    // It also requires FirebaseNotificationService as @EnvironmentObject.

    private var notificationService: FirebaseNotificationService!
    private let logger: LoggingService = HeirloomLogger()

    override func setUp() async throws {
        try await super.setUp()
        mockAuth = MockSnapshotAuth.authenticated()

        let config = FirebaseConfiguration(logger: logger)
        notificationService = FirebaseNotificationService(
            configuration: config, logger: logger
        )
    }

    override func tearDown() async throws {
        notificationService = nil
        try await super.tearDown()
    }

    // MARK: - Full Recipe

    func testRecipeDetail_fullRecipe() throws {
        let recipe = createTestRecipe(
            title: "Grandma's Apple Pie",
            servings: "8 servings",
            prepTime: "30 min",
            cookTime: "45 min",
            notes: "A beloved family recipe passed down through four generations."
        )

        // Add ingredients
        var ingredients: [Ingredient] = []
        let ingredientNames = [
            "6 large Granny Smith apples",
            "3/4 cup granulated sugar",
            "2 tablespoons all-purpose flour",
            "1 teaspoon ground cinnamon",
            "1/4 teaspoon ground nutmeg",
            "1 tablespoon lemon juice",
            "1 tablespoon butter",
            "2 pie crusts (homemade or store-bought)",
        ]
        for name in ingredientNames {
            let ingredient = Ingredient()
            ingredient.name = name
            modelContext.insert(ingredient)
            ingredients.append(ingredient)
        }
        recipe.ingredients = ingredients

        // Add instructions
        recipe.instructions = [
            "Preheat oven to 425°F (220°C).",
            "Peel, core, and slice the apples into thin wedges.",
            "Toss apples with sugar, flour, cinnamon, nutmeg, and lemon juice.",
            "Line a 9-inch pie dish with one crust.",
            "Fill with apple mixture and dot with butter.",
            "Cover with second crust, crimp edges, and cut slits for steam.",
            "Bake 45-50 minutes until golden brown and bubbly.",
            "Cool on a wire rack for at least 2 hours before slicing.",
        ]

        try saveContext()

        let view = RecipeDetailView(recipe: recipe)
            .environmentObject(notificationService!)
            .environment(\.firebaseAuth, mockAuth)
            .environment(\.firebaseSync, mockSync)

        assertBothDevices(view, named: "recipeDetail_full")
    }

    // MARK: - Card Back

    func testRecipeDetail_cardBack() throws {
        let recipe = createTestRecipe(
            title: "Grandma's Apple Pie",
            servings: "8 servings"
        )

        // Set up a card back with note content
        let cardBack = RecipeCardBack()
        cardBack.noteToFriends = "This recipe has been in our family since 1952, when Grandma Rose first made it for Thanksgiving."
        cardBack.personalTips = ["Use a mix of Granny Smith and Honeycrisp apples", "Let the dough rest 30 min before rolling"]
        recipe.cardBack = cardBack

        try saveContext()

        let view = RecipeDetailView(recipe: recipe)
            .environmentObject(notificationService!)
            .environment(\.firebaseAuth, mockAuth)
            .environment(\.firebaseSync, mockSync)

        assertBothDevices(view, named: "recipeDetail_cardBack")
    }
}
