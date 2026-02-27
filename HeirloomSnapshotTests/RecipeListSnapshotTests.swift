import SnapshotTesting
import SwiftUI
import SwiftData
import XCTest
@testable import Heirloom

@MainActor
final class RecipeListSnapshotTests: SnapshotTestCase {

    // MARK: - Setup
    //
    // RecipeListView resolves many services from ServiceContainer:
    //   ImageStorageService, ToastManager, MilestoneManager,
    //   RecipeImageGeneratorProtocol, AnalyticsService, CRDTMergeEngine,
    //   BackendConfig, SubscriptionManager
    //
    // It also requires TabNavigationCoordinator as @EnvironmentObject.
    //
    // Register all required services in setUp below.

    private var tabCoordinator: TabNavigationCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        mockAuth = MockSnapshotAuth.authenticated()
        tabCoordinator = TabNavigationCoordinator()

        // NOTE: Register additional ServiceContainer dependencies here
        // if the view init crashes. Known dependencies listed in header comment.
    }

    override func tearDown() async throws {
        tabCoordinator = nil
        try await super.tearDown()
    }

    // MARK: - Empty State

    func testRecipeList_empty() {
        let view = RecipeListView()
            .environmentObject(tabCoordinator!)
            .environment(\.firebaseAuth, mockAuth)
            .environment(\.firebaseSync, mockSync)
            .environment(\.firebaseLineage, mockLineage)

        assertBothDevices(view, named: "recipeList_empty")
    }

    // MARK: - With 3 Recipes

    func testRecipeList_threeRecipes() throws {
        _ = createTestRecipe(
            title: "Grandma's Apple Pie",
            servings: "8 servings",
            prepTime: "30 min",
            cookTime: "45 min"
        )
        _ = createTestRecipe(
            title: "Mom's Chicken Soup",
            servings: "6 servings",
            prepTime: "15 min",
            cookTime: "1 hour"
        )
        _ = createTestRecipe(
            title: "Dad's BBQ Ribs",
            servings: "4 servings",
            prepTime: "20 min",
            cookTime: "4 hours"
        )
        try saveContext()

        let view = RecipeListView()
            .environmentObject(tabCoordinator!)
            .environment(\.firebaseAuth, mockAuth)
            .environment(\.firebaseSync, mockSync)
            .environment(\.firebaseLineage, mockLineage)

        assertBothDevices(view, named: "recipeList_threeRecipes")
    }
}
