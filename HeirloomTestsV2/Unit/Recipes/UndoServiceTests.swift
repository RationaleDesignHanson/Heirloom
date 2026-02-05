//
//  UndoServiceTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-04
//  Unit tests for UndoService to ensure recipe deletion with undo works correctly
//
//  Tests the following scenarios:
//  - Delete adds recipe to pending undos and removes from SwiftData
//  - Undo restores recipe to SwiftData and removes from pending undos
//  - Undo re-uploads to Firebase when Firebase is active
//  - Expiration removes from pending undos and deletes from Firebase
//  - hasPendingUndos correctly reflects state
//  - clearAll removes all pending undos
//

import XCTest
import SwiftData
import Combine
@testable import Heirloom

@MainActor
final class UndoServiceTests: XCTestCase {

    // MARK: - Properties

    var env: TestEnvironment!
    var undoService: UndoService!
    var mockFirebaseSync: MockFirebaseSyncService!
    var mockAnalytics: AnalyticsService!
    var backendConfig: BackendConfig!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        env = try await TestEnvironment.create(authenticated: true)

        // Create mock dependencies
        mockAnalytics = AnalyticsService()
        backendConfig = BackendConfig()
        backendConfig.setFirebaseActive(false) // Start with Firebase inactive
        mockFirebaseSync = MockFirebaseSyncService()

        // Create UndoService with mocks
        undoService = UndoService(
            analytics: mockAnalytics,
            backendConfig: backendConfig,
            firebaseSync: mockFirebaseSync
        )
        undoService.configure(modelContext: env.modelContext)
    }

    override func tearDown() async throws {
        undoService.clearAll()
        env.tearDown()
        env = nil
        undoService = nil
        mockFirebaseSync = nil
        mockAnalytics = nil
        backendConfig = nil
        try await super.tearDown()
    }

    // MARK: - Delete Tests

    /// Test 1: Delete recipe adds to pending undos
    func test_deleteRecipe_addsToPendingUndos() throws {
        // GIVEN: A recipe in the database
        let recipe = env.createTestRecipe(title: "Test Recipe")
        try env.save()

        // WHEN: Deleting the recipe
        undoService.deleteRecipe(recipe, context: env.modelContext)

        // THEN: Recipe should be in pending undos
        XCTAssertTrue(undoService.hasPendingUndos)
        XCTAssertEqual(undoService.pendingUndos.count, 1)
        XCTAssertEqual(undoService.pendingUndos.first?.description, "Test Recipe")
    }

    /// Test 2: Delete recipe removes from SwiftData context
    func test_deleteRecipe_removesFromContext() throws {
        // GIVEN: A recipe in the database
        let recipe = env.createTestRecipe(title: "Test Recipe")
        try env.save()
        XCTAssertEqual(try env.fetchAllRecipes().count, 1)

        // WHEN: Deleting the recipe
        undoService.deleteRecipe(recipe, context: env.modelContext)

        // THEN: Recipe should be removed from context
        XCTAssertEqual(try env.fetchAllRecipes().count, 0)
    }

    /// Test 3: Delete recipe stores recipe data for undo
    func test_deleteRecipe_storesRecipeData() throws {
        // GIVEN: A recipe with specific data
        let recipe = Recipe(
            title: "My Recipe",
            sourceType: .manual,
            instructions: ["Step 1", "Step 2"],
            servings: "4 servings"
        )
        env.modelContext.insert(recipe)
        try env.save()
        let recipeId = recipe.id

        // WHEN: Deleting the recipe
        undoService.deleteRecipe(recipe, context: env.modelContext)

        // THEN: Stored recipe should have the same ID
        XCTAssertEqual(undoService.pendingUndos.first?.recipeData.id, recipeId)
    }

    /// Test 4: Delete multiple recipes adds all to pending undos
    func test_deleteMultipleRecipes_addsAllToPendingUndos() throws {
        // GIVEN: Multiple recipes
        let recipe1 = env.createTestRecipe(title: "Recipe 1")
        let recipe2 = env.createTestRecipe(title: "Recipe 2")
        let recipe3 = env.createTestRecipe(title: "Recipe 3")
        try env.save()

        // WHEN: Deleting all recipes
        undoService.deleteRecipe(recipe1, context: env.modelContext)
        undoService.deleteRecipe(recipe2, context: env.modelContext)
        undoService.deleteRecipe(recipe3, context: env.modelContext)

        // THEN: All should be in pending undos
        XCTAssertEqual(undoService.pendingUndos.count, 3)
    }

    // MARK: - Undo Tests

    /// Test 5: Undo delete restores recipe to context
    func test_undoDelete_restoresRecipeToContext() throws {
        // GIVEN: A deleted recipe
        let recipe = env.createTestRecipe(title: "Restored Recipe")
        try env.save()
        undoService.deleteRecipe(recipe, context: env.modelContext)
        XCTAssertEqual(try env.fetchAllRecipes().count, 0)

        // WHEN: Undoing the delete
        let undoItem = undoService.pendingUndos.first!
        undoService.undoDelete(undoItem)

        // THEN: Recipe should be restored
        let recipes = try env.fetchAllRecipes()
        XCTAssertEqual(recipes.count, 1)
        XCTAssertEqual(recipes.first?.title, "Restored Recipe")
    }

    /// Test 6: Undo delete removes from pending undos
    func test_undoDelete_removesFromPendingUndos() throws {
        // GIVEN: A deleted recipe
        let recipe = env.createTestRecipe(title: "Test Recipe")
        try env.save()
        undoService.deleteRecipe(recipe, context: env.modelContext)
        XCTAssertTrue(undoService.hasPendingUndos)

        // WHEN: Undoing the delete
        let undoItem = undoService.pendingUndos.first!
        undoService.undoDelete(undoItem)

        // THEN: Pending undos should be empty
        XCTAssertFalse(undoService.hasPendingUndos)
        XCTAssertEqual(undoService.pendingUndos.count, 0)
    }

    /// Test 7: Undo delete re-uploads to Firebase when active
    func test_undoDelete_reuploadsToFirebase_whenActive() async throws {
        // GIVEN: Firebase is active and a deleted recipe
        backendConfig.setFirebaseActive(true)
        let recipe = env.createTestRecipe(title: "Firebase Recipe")
        try env.save()
        undoService.deleteRecipe(recipe, context: env.modelContext)

        // WHEN: Undoing the delete
        let undoItem = undoService.pendingUndos.first!
        undoService.undoDelete(undoItem)

        // Wait for async Firebase upload
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // THEN: Firebase should have received upload request
        XCTAssertEqual(mockFirebaseSync.uploadedRecipes.count, 1)
    }

    /// Test 8: Undo delete does not upload to Firebase when inactive
    func test_undoDelete_doesNotUploadToFirebase_whenInactive() async throws {
        // GIVEN: Firebase is inactive and a deleted recipe
        backendConfig.setFirebaseActive(false)
        let recipe = env.createTestRecipe(title: "Local Recipe")
        try env.save()
        undoService.deleteRecipe(recipe, context: env.modelContext)

        // WHEN: Undoing the delete
        let undoItem = undoService.pendingUndos.first!
        undoService.undoDelete(undoItem)

        // Wait to ensure no async operations happen
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // THEN: Firebase should not have received any requests
        XCTAssertEqual(mockFirebaseSync.uploadedRecipes.count, 0)
    }

    // MARK: - Expiration Tests

    /// Test 9: Undo item expiration deletes from Firebase
    func test_undoExpiration_deletesFromFirebase() async throws {
        // GIVEN: Firebase is active and a short undo window
        backendConfig.setFirebaseActive(true)
        let recipe = env.createTestRecipe(title: "Expiring Recipe")
        let recipeId = recipe.id
        try env.save()

        // Use a very short undo window (0.2 seconds)
        undoService.deleteRecipe(recipe, context: env.modelContext, undoWindow: 0.2)

        // WHEN: Waiting for expiration
        try await Task.sleep(nanoseconds: 400_000_000) // 400ms to ensure expiration

        // THEN: Firebase should have received delete request
        XCTAssertTrue(mockFirebaseSync.deletedRecipeIds.contains(recipeId))
    }

    /// Test 10: Expired undo item is removed from pending undos
    func test_undoExpiration_removesFromPendingUndos() async throws {
        // GIVEN: A deleted recipe with short undo window
        let recipe = env.createTestRecipe(title: "Expiring Recipe")
        try env.save()

        // Use a very short undo window (0.2 seconds)
        undoService.deleteRecipe(recipe, context: env.modelContext, undoWindow: 0.2)
        XCTAssertTrue(undoService.hasPendingUndos)

        // WHEN: Waiting for expiration
        try await Task.sleep(nanoseconds: 400_000_000) // 400ms

        // THEN: Pending undos should be empty
        XCTAssertFalse(undoService.hasPendingUndos)
    }

    // MARK: - State Tests

    /// Test 11: hasPendingUndos returns false when empty
    func test_hasPendingUndos_returnsFalse_whenEmpty() {
        // GIVEN: No pending undos (fresh state)

        // THEN: hasPendingUndos should be false
        XCTAssertFalse(undoService.hasPendingUndos)
    }

    /// Test 12: clearAll removes all pending undos
    func test_clearAll_removesAllPendingUndos() throws {
        // GIVEN: Multiple deleted recipes
        let recipe1 = env.createTestRecipe(title: "Recipe 1")
        let recipe2 = env.createTestRecipe(title: "Recipe 2")
        try env.save()
        undoService.deleteRecipe(recipe1, context: env.modelContext)
        undoService.deleteRecipe(recipe2, context: env.modelContext)
        XCTAssertEqual(undoService.pendingUndos.count, 2)

        // WHEN: Clearing all
        undoService.clearAll()

        // THEN: Pending undos should be empty
        XCTAssertEqual(undoService.pendingUndos.count, 0)
        XCTAssertFalse(undoService.hasPendingUndos)
    }

    /// Test 13: Undo item has correct expiration date
    func test_undoItem_hasCorrectExpirationDate() throws {
        // GIVEN: A recipe
        let recipe = env.createTestRecipe(title: "Test Recipe")
        try env.save()
        let beforeDelete = Date()

        // WHEN: Deleting with 5 second window
        undoService.deleteRecipe(recipe, context: env.modelContext, undoWindow: 5.0)

        // THEN: Expiration should be approximately 5 seconds from now
        let undoItem = undoService.pendingUndos.first!
        let expectedExpiration = beforeDelete.addingTimeInterval(5.0)
        XCTAssertEqual(
            undoItem.expirationDate.timeIntervalSince1970,
            expectedExpiration.timeIntervalSince1970,
            accuracy: 1.0 // 1 second tolerance
        )
    }

    /// Test 14: isExpired returns false for fresh undo item
    func test_undoItem_isExpired_returnsFalse_whenFresh() throws {
        // GIVEN: A freshly deleted recipe
        let recipe = env.createTestRecipe(title: "Fresh Recipe")
        try env.save()

        // WHEN: Deleting with default window
        undoService.deleteRecipe(recipe, context: env.modelContext)

        // THEN: Item should not be expired
        let undoItem = undoService.pendingUndos.first!
        XCTAssertFalse(undoItem.isExpired)
    }
}

// MARK: - Mock Firebase Sync Service

@MainActor
final class MockFirebaseSyncService: ObservableObject, FirebaseSyncServiceProtocol {
    nonisolated(unsafe) let objectWillChange = ObservableObjectPublisher()

    var uploadedRecipes: [Recipe] = []
    var deletedRecipeIds: [UUID] = []
    var shouldFailUpload: Bool = false
    var shouldFailDelete: Bool = false

    func configure(modelContext: ModelContext) {}

    func uploadRecipe(_ recipe: Recipe) async throws {
        if shouldFailUpload {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock upload failed"])
        }
        uploadedRecipes.append(recipe)
    }

    func uploadRecipeTransactional(_ recipe: Recipe) async throws {
        try await uploadRecipe(recipe)
    }

    func downloadRecipe(id: String, context: ModelContext) async throws -> Recipe {
        throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
    }

    func downloadAllRecipes(context: ModelContext) async throws -> [Recipe] {
        return []
    }

    func syncChanges() async throws {}

    func syncChangesWithCRDT() async throws {}

    func deleteRecipe(_ recipeId: UUID) async throws {
        if shouldFailDelete {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock delete failed"])
        }
        deletedRecipeIds.append(recipeId)
    }

    func startAutomaticSync() {}

    func stopAutomaticSync() {}

    func convertFromFirestoreData(_ data: [String: Any], id: String, context: ModelContext) -> Recipe {
        return Recipe(title: "Mock Recipe")
    }

    func convertIngredientFromFirestoreData(_ data: [String: Any], id: String) -> Ingredient {
        return Ingredient(originalText: "Mock Ingredient", name: "Mock")
    }

    func convertCommentFromFirestoreData(_ data: [String: Any], id: String) -> RecipeComment {
        return RecipeComment(text: "Mock Comment", authorName: "Test")
    }

    func convertCardBackFromFirestoreData(_ data: [String: Any]) -> RecipeCardBack {
        return RecipeCardBack()
    }

    func uploadImage(for recipe: Recipe) async throws -> String? {
        return nil
    }

    func deleteImage(for recipeId: UUID) async throws {}

    func downloadImage(for recipe: Recipe) async throws {}

    func uploadTag(_ tag: Tag) async throws {}

    func deleteTag(_ tagId: UUID) async throws {}

    // Collection methods for undo testing
    var uploadedCollections: [RecipeCollection] = []
    var deletedCollectionIds: [UUID] = []

    func uploadCollection(_ collection: RecipeCollection) async throws {
        uploadedCollections.append(collection)
    }

    func deleteCollection(_ collectionId: UUID) async throws {
        deletedCollectionIds.append(collectionId)
    }

    func uploadDinnerParty(_ party: DinnerParty) async throws {}

    func deleteDinnerParty(_ partyId: UUID) async throws {}

    func uploadCardBack(_ cardBack: RecipeCardBack, recipeId: UUID) async throws {}
}

// MARK: - Collection Undo Tests

@MainActor
final class CollectionUndoServiceTests: XCTestCase {

    // MARK: - Properties

    var env: TestEnvironment!
    var undoService: UndoService!
    var mockFirebaseSync: MockFirebaseSyncService!
    var mockAnalytics: AnalyticsService!
    var backendConfig: BackendConfig!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        env = try await TestEnvironment.create(authenticated: true)

        // Create mock dependencies
        mockAnalytics = AnalyticsService()
        backendConfig = BackendConfig()
        backendConfig.setFirebaseActive(false)
        mockFirebaseSync = MockFirebaseSyncService()

        // Create UndoService with mocks
        undoService = UndoService(
            analytics: mockAnalytics,
            backendConfig: backendConfig,
            firebaseSync: mockFirebaseSync
        )
        undoService.configure(modelContext: env.modelContext)
    }

    override func tearDown() async throws {
        undoService.clearAll()
        env.tearDown()
        env = nil
        undoService = nil
        mockFirebaseSync = nil
        mockAnalytics = nil
        backendConfig = nil
        try await super.tearDown()
    }

    // MARK: - Delete Collection Keeping Recipes Tests

    /// Test: Delete collection keeping recipes adds to pending undos
    func test_deleteCollectionKeepingRecipes_addsToPendingUndos() throws {
        // GIVEN: A collection with recipes
        let collection = RecipeCollection(name: "Test Collection")
        let recipe = env.createTestRecipe(title: "Test Recipe")
        env.modelContext.insert(collection)
        collection.recipes = [recipe]
        recipe.collections = [collection]
        try env.save()

        // WHEN: Deleting the collection
        undoService.deleteCollectionKeepingRecipes(collection, context: env.modelContext)

        // THEN: Collection should be in pending undos
        XCTAssertTrue(undoService.hasPendingCollectionUndos)
        XCTAssertEqual(undoService.pendingCollectionUndos.count, 1)
        XCTAssertEqual(undoService.pendingCollectionUndos.first?.description, "Test Collection")
    }

    /// Test: Delete collection keeping recipes preserves recipes in database
    func test_deleteCollectionKeepingRecipes_preservesRecipes() throws {
        // GIVEN: A collection with recipes
        let collection = RecipeCollection(name: "Test Collection")
        let recipe = env.createTestRecipe(title: "Test Recipe")
        env.modelContext.insert(collection)
        collection.recipes = [recipe]
        recipe.collections = [collection]
        try env.save()

        // WHEN: Deleting the collection
        undoService.deleteCollectionKeepingRecipes(collection, context: env.modelContext)

        // THEN: Recipe should still exist
        let recipes = try env.fetchAllRecipes()
        XCTAssertEqual(recipes.count, 1)
        XCTAssertEqual(recipes.first?.title, "Test Recipe")
    }

    /// Test: Delete collection keeping recipes stores recipe IDs for restoration
    func test_deleteCollectionKeepingRecipes_storesRecipeIds() throws {
        // GIVEN: A collection with recipes
        let collection = RecipeCollection(name: "Test Collection")
        let recipe1 = env.createTestRecipe(title: "Recipe 1")
        let recipe2 = env.createTestRecipe(title: "Recipe 2")
        env.modelContext.insert(collection)
        collection.recipes = [recipe1, recipe2]
        recipe1.collections = [collection]
        recipe2.collections = [collection]
        try env.save()
        let recipeIds = [recipe1.id, recipe2.id]

        // WHEN: Deleting the collection
        undoService.deleteCollectionKeepingRecipes(collection, context: env.modelContext)

        // THEN: Undo item should have recipe IDs
        let undoItem = undoService.pendingCollectionUndos.first!
        XCTAssertEqual(Set(undoItem.recipeIds), Set(recipeIds))
        XCTAssertFalse(undoItem.recipesWereDeleted)
    }

    // MARK: - Delete Collection And Recipes Tests

    /// Test: Delete collection and recipes removes recipes from database
    func test_deleteCollectionAndRecipes_removesRecipes() throws {
        // GIVEN: A collection with recipes
        let collection = RecipeCollection(name: "Test Collection")
        let recipe = env.createTestRecipe(title: "Test Recipe")
        env.modelContext.insert(collection)
        collection.recipes = [recipe]
        recipe.collections = [collection]
        try env.save()
        XCTAssertEqual(try env.fetchAllRecipes().count, 1)

        // WHEN: Deleting the collection and recipes
        undoService.deleteCollectionAndRecipes(collection, context: env.modelContext)

        // THEN: Recipe should be removed
        XCTAssertEqual(try env.fetchAllRecipes().count, 0)
    }

    /// Test: Delete collection and recipes stores deleted recipes for restoration
    func test_deleteCollectionAndRecipes_storesDeletedRecipes() throws {
        // GIVEN: A collection with recipes
        let collection = RecipeCollection(name: "Test Collection")
        let recipe = env.createTestRecipe(title: "Test Recipe")
        env.modelContext.insert(collection)
        collection.recipes = [recipe]
        recipe.collections = [collection]
        try env.save()

        // WHEN: Deleting the collection and recipes
        undoService.deleteCollectionAndRecipes(collection, context: env.modelContext)

        // THEN: Undo item should have deleted recipes
        let undoItem = undoService.pendingCollectionUndos.first!
        XCTAssertTrue(undoItem.recipesWereDeleted)
        XCTAssertEqual(undoItem.deletedRecipeData.count, 1)
    }

    // MARK: - Undo Collection Deletion Tests

    /// Test: Undo collection deletion restores collection
    func test_undoCollectionDelete_restoresCollection() throws {
        // GIVEN: A deleted collection
        let collection = RecipeCollection(name: "Restored Collection")
        env.modelContext.insert(collection)
        try env.save()
        undoService.deleteCollectionKeepingRecipes(collection, context: env.modelContext)

        // WHEN: Undoing the delete
        let undoItem = undoService.pendingCollectionUndos.first!
        undoService.undoCollectionDelete(undoItem)

        // THEN: Collection should be restored
        let descriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { $0.name == "Restored Collection" }
        )
        let collections = try env.modelContext.fetch(descriptor)
        XCTAssertEqual(collections.count, 1)
    }

    /// Test: Undo collection and recipes deletion restores both
    func test_undoCollectionAndRecipesDelete_restoresBoth() throws {
        // GIVEN: A collection with recipes, deleted together
        let collection = RecipeCollection(name: "Test Collection")
        let recipe = env.createTestRecipe(title: "Test Recipe")
        env.modelContext.insert(collection)
        collection.recipes = [recipe]
        recipe.collections = [collection]
        try env.save()

        undoService.deleteCollectionAndRecipes(collection, context: env.modelContext)
        XCTAssertEqual(try env.fetchAllRecipes().count, 0)

        // WHEN: Undoing the delete
        let undoItem = undoService.pendingCollectionUndos.first!
        undoService.undoCollectionDelete(undoItem)

        // THEN: Both should be restored
        XCTAssertEqual(try env.fetchAllRecipes().count, 1)
    }

    /// Test: Undo collection deletion removes from pending undos
    func test_undoCollectionDelete_removesFromPendingUndos() throws {
        // GIVEN: A deleted collection
        let collection = RecipeCollection(name: "Test Collection")
        env.modelContext.insert(collection)
        try env.save()
        undoService.deleteCollectionKeepingRecipes(collection, context: env.modelContext)
        XCTAssertTrue(undoService.hasPendingCollectionUndos)

        // WHEN: Undoing the delete
        let undoItem = undoService.pendingCollectionUndos.first!
        undoService.undoCollectionDelete(undoItem)

        // THEN: Pending undos should be empty
        XCTAssertFalse(undoService.hasPendingCollectionUndos)
    }

    /// Test: Undo collection deletion re-uploads to Firebase when active
    func test_undoCollectionDelete_reuploadsToFirebase_whenActive() async throws {
        // GIVEN: Firebase is active and a deleted collection
        backendConfig.setFirebaseActive(true)
        let collection = RecipeCollection(name: "Firebase Collection")
        env.modelContext.insert(collection)
        try env.save()
        undoService.deleteCollectionKeepingRecipes(collection, context: env.modelContext)

        // WHEN: Undoing the delete
        let undoItem = undoService.pendingCollectionUndos.first!
        undoService.undoCollectionDelete(undoItem)

        // Wait for async Firebase upload
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // THEN: Firebase should have received upload request
        XCTAssertEqual(mockFirebaseSync.uploadedCollections.count, 1)
    }
}

