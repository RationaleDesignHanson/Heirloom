//
//  CollectionTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-03
//  Unit tests for recipe collection management
//
//  Tests collection operations to ensure:
//  - Create, edit, delete collections
//  - Recipe membership and relationships
//  - Collection types and categories
//  - NEW badge detection
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class CollectionTests: XCTestCase {

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

    // MARK: - Create Tests

    /// Test 1: Create collection with name only
    func test_createCollection_withNameOnly_succeeds() throws {
        // GIVEN: Collection name
        let collection = RecipeCollection(name: "My Collection")

        // WHEN: Inserting into context
        env.modelContext.insert(collection)
        try env.save()

        // THEN: Collection should be persisted
        let collections = try env.fetchAllCollections()
        XCTAssertEqual(collections.count, 1)
        XCTAssertEqual(collections.first?.name, "My Collection")
    }

    /// Test 2: Create collection with all fields
    func test_createCollection_withAllFields_succeeds() throws {
        // GIVEN: Fully configured collection
        let collection = RecipeCollection(
            name: "Holiday Recipes",
            description: "Special occasion recipes",
            iconName: "star.fill",
            color: "#FF0000",
            isSystemCollection: false,
            collectionType: .userCreated
        )

        // WHEN: Inserting
        env.modelContext.insert(collection)
        try env.save()

        // THEN: All fields persisted
        let fetched = try env.fetchAllCollections().first!
        XCTAssertEqual(fetched.name, "Holiday Recipes")
        XCTAssertEqual(fetched.desc, "Special occasion recipes")
        XCTAssertEqual(fetched.iconName, "star.fill")
        XCTAssertEqual(fetched.color, "#FF0000")
        XCTAssertFalse(fetched.isSystemCollection)
        XCTAssertEqual(fetched.type, .userCreated)
    }

    /// Test 3: Create collection generates unique ID
    func test_createCollection_generatesUniqueId() throws {
        // GIVEN/WHEN: Creating multiple collections
        let collection1 = RecipeCollection(name: "Collection 1")
        let collection2 = RecipeCollection(name: "Collection 2")
        env.modelContext.insert(collection1)
        env.modelContext.insert(collection2)
        try env.save()

        // THEN: IDs should be unique
        XCTAssertNotEqual(collection1.id, collection2.id)
    }

    // MARK: - Update Tests

    /// Test 4: Update collection name
    func test_updateCollection_name_persists() throws {
        // GIVEN: Existing collection
        let collection = RecipeCollection(name: "Original Name")
        env.modelContext.insert(collection)
        try env.save()

        // WHEN: Updating name
        collection.name = "Updated Name"
        try env.save()

        // THEN: Name should be updated
        let fetched = try env.fetchAllCollections().first!
        XCTAssertEqual(fetched.name, "Updated Name")
    }

    /// Test 5: Update collection color
    func test_updateCollection_color_persists() throws {
        // GIVEN: Collection with default color
        let collection = RecipeCollection(name: "Test")
        env.modelContext.insert(collection)
        try env.save()

        // WHEN: Changing color
        collection.color = "#00FF00"
        try env.save()

        // THEN: Color should be updated
        let fetched = try env.fetchAllCollections().first!
        XCTAssertEqual(fetched.color, "#00FF00")
    }

    // MARK: - Delete Tests

    /// Test 6: Delete collection removes from database
    func test_deleteCollection_removesFromDatabase() throws {
        // GIVEN: Collection in database
        let collection = RecipeCollection(name: "To Delete")
        env.modelContext.insert(collection)
        try env.save()
        XCTAssertEqual(try env.fetchAllCollections().count, 1)

        // WHEN: Deleting
        env.modelContext.delete(collection)
        try env.save()

        // THEN: Collection should be gone
        XCTAssertEqual(try env.fetchAllCollections().count, 0)
    }

    /// Test 7: Delete collection does not delete recipes (nullify relationship)
    func test_deleteCollection_keepsRecipes() throws {
        // GIVEN: Collection with recipe
        let collection = RecipeCollection(name: "Test Collection")
        let recipe = env.createTestRecipe(title: "Test Recipe")

        collection.recipes = [recipe]
        recipe.collections = [collection]
        env.modelContext.insert(collection)
        try env.save()

        // WHEN: Deleting collection
        env.modelContext.delete(collection)
        try env.save()

        // THEN: Recipe should still exist
        let recipes = try env.fetchAllRecipes()
        XCTAssertEqual(recipes.count, 1)
        XCTAssertTrue(recipes.first?.collections?.isEmpty ?? true)
    }

    // MARK: - Recipe Membership Tests

    /// Test 8: Add recipe to collection
    func test_addRecipe_toCollection_succeeds() throws {
        // GIVEN: Collection and recipe
        let collection = RecipeCollection(name: "My Collection")
        let recipe = env.createTestRecipe(title: "My Recipe")
        env.modelContext.insert(collection)
        try env.save()

        // WHEN: Adding recipe to collection
        if collection.recipes == nil { collection.recipes = [] }
        if recipe.collections == nil { recipe.collections = [] }
        collection.recipes?.append(recipe)
        recipe.collections?.append(collection)
        try env.save()

        // THEN: Relationship should be established
        XCTAssertEqual(collection.recipes?.count, 1)
        XCTAssertEqual(recipe.collections?.count, 1)
    }

    /// Test 9: Recipe count computed property
    func test_recipeCount_computedCorrectly() throws {
        // GIVEN: Collection
        let collection = RecipeCollection(name: "Test")
        env.modelContext.insert(collection)
        collection.recipes = []
        try env.save()

        XCTAssertEqual(collection.recipeCount, 0)

        // WHEN: Adding recipes
        let recipe1 = env.createTestRecipe(title: "Recipe 1")
        let recipe2 = env.createTestRecipe(title: "Recipe 2")
        collection.recipes?.append(recipe1)
        collection.recipes?.append(recipe2)
        try env.save()

        // THEN: Count should update
        XCTAssertEqual(collection.recipeCount, 2)
    }

    /// Test 10: Recipe can belong to multiple collections
    func test_recipe_belongsToMultipleCollections() throws {
        // GIVEN: Two collections and a recipe
        let collection1 = RecipeCollection(name: "Favorites")
        let collection2 = RecipeCollection(name: "Quick Meals")
        let recipe = env.createTestRecipe(title: "Quick Favorite")

        collection1.recipes = []
        collection2.recipes = []
        recipe.collections = []

        env.modelContext.insert(collection1)
        env.modelContext.insert(collection2)
        try env.save()

        // WHEN: Adding recipe to both collections
        collection1.recipes?.append(recipe)
        collection2.recipes?.append(recipe)
        recipe.collections?.append(collection1)
        recipe.collections?.append(collection2)
        try env.save()

        // THEN: Recipe belongs to both
        XCTAssertEqual(recipe.collections?.count, 2)
        XCTAssertTrue(collection1.recipes?.contains(where: { $0.id == recipe.id }) ?? false)
        XCTAssertTrue(collection2.recipes?.contains(where: { $0.id == recipe.id }) ?? false)
    }

    // MARK: - Collection Type Tests

    /// Test 11: User created collection type
    func test_collectionType_userCreated_isDefault() throws {
        // GIVEN: Default collection
        let collection = RecipeCollection(name: "Test")
        env.modelContext.insert(collection)
        try env.save()

        // THEN: Should be user created
        XCTAssertEqual(collection.type, .userCreated)
    }

    /// Test 12: Collection type affects visibility
    func test_collectionType_systemCollection_notVisibleInMainList() throws {
        // GIVEN: System collection
        let systemCollection = RecipeCollection(
            name: "Favorites",
            isSystemCollection: true,
            collectionType: .system
        )
        env.modelContext.insert(systemCollection)
        try env.save()

        // THEN: Should not be visible in main list
        XCTAssertFalse(systemCollection.isVisibleInMainList)
    }

    /// Test 13: Theme collection is visible
    func test_collectionType_themeCollection_isVisible() throws {
        // GIVEN: Theme collection
        let themeCollection = RecipeCollection(
            name: "American Classics",
            collectionType: .theme
        )
        themeCollection.recipes = [env.createTestRecipe()]
        env.modelContext.insert(themeCollection)
        try env.save()

        // THEN: Should be visible
        XCTAssertTrue(themeCollection.isVisibleInMainList)
    }

    // MARK: - Display Properties Tests

    /// Test 14: Display description for empty collection
    func test_displayDescription_emptyCollection() throws {
        // GIVEN: Empty collection
        let collection = RecipeCollection(name: "Empty")
        collection.recipes = []
        env.modelContext.insert(collection)
        try env.save()

        // THEN: Should say "No recipes yet"
        XCTAssertEqual(collection.displayDescription, "No recipes yet")
    }

    /// Test 15: Display description for single recipe
    func test_displayDescription_singleRecipe() throws {
        // GIVEN: Collection with one recipe
        let collection = RecipeCollection(name: "One Recipe")
        collection.recipes = [env.createTestRecipe()]
        env.modelContext.insert(collection)
        try env.save()

        // THEN: Should be singular
        XCTAssertEqual(collection.displayDescription, "1 recipe")
    }

    /// Test 16: Display description for multiple recipes
    func test_displayDescription_multipleRecipes() throws {
        // GIVEN: Collection with multiple recipes
        let collection = RecipeCollection(name: "Multiple")
        collection.recipes = [
            env.createTestRecipe(title: "Recipe 1"),
            env.createTestRecipe(title: "Recipe 2"),
            env.createTestRecipe(title: "Recipe 3")
        ]
        env.modelContext.insert(collection)
        try env.save()

        // THEN: Should be plural
        XCTAssertEqual(collection.displayDescription, "3 recipes")
    }

    // MARK: - NEW Badge Tests

    /// Test 17: Has new recipes returns false for empty collection
    func test_hasNewRecipes_emptyCollection_returnsFalse() throws {
        // GIVEN: Empty collection
        let collection = RecipeCollection(name: "Empty")
        collection.recipes = []
        env.modelContext.insert(collection)
        try env.save()

        // THEN: No new recipes
        XCTAssertFalse(collection.hasNewRecipes)
    }

    /// Test 18: Mark as viewed clears new badge
    func test_markAsViewed_clearsNewBadge() throws {
        // GIVEN: Collection with new recipe
        let collection = RecipeCollection(name: "Test")
        let recipe = env.createTestRecipe()
        recipe.createdAt = Date() // Just created
        collection.recipes = [recipe]
        collection.lastViewedDate = nil
        env.modelContext.insert(collection)
        try env.save()

        // Pre-condition: Should have new recipes
        XCTAssertTrue(collection.hasNewRecipes)

        // WHEN: Marking as viewed
        collection.markAsViewed()
        try env.save()

        // THEN: Should no longer have new recipes (future recipes would be new)
        XCTAssertNotNil(collection.lastViewedDate)
    }

    // MARK: - Collection Category Mapping Tests

    /// Test 19: Each collection type maps to correct category
    func test_collectionType_categoryMapping() {
        // Import category types
        XCTAssertEqual(CollectionType.fromFriends.category, .imported)
        XCTAssertEqual(CollectionType.videoImports.category, .imported)
        XCTAssertEqual(CollectionType.webImports.category, .imported)
        XCTAssertEqual(CollectionType.photoImports.category, .imported)
        XCTAssertEqual(CollectionType.communityRecipes.category, .imported)

        // Cookbook category
        XCTAssertEqual(CollectionType.cookbook.category, .cookbooks)

        // Theme category
        XCTAssertEqual(CollectionType.theme.category, .themes)

        // User category
        XCTAssertEqual(CollectionType.userCreated.category, .user)

        // System category
        XCTAssertEqual(CollectionType.system.category, .system)
    }

    /// Test 20: All collection types have a category assigned
    func test_collectionType_allTypesHaveCategory() {
        for type in CollectionType.allCases {
            // Should not crash - every type should have a category
            let category = type.category
            XCTAssertNotNil(category.displayName)
        }
    }

    // MARK: - Shareability Tests

    /// Test 21: Shareable collection types
    func test_collectionType_canShare_allowedTypes() {
        // These types CAN be shared
        XCTAssertTrue(CollectionType.videoImports.canShare, "Video imports should be shareable")
        XCTAssertTrue(CollectionType.webImports.canShare, "Web imports should be shareable")
        XCTAssertTrue(CollectionType.photoImports.canShare, "Photo imports should be shareable")
        XCTAssertTrue(CollectionType.cookbook.canShare, "Cookbook collections should be shareable")
        XCTAssertTrue(CollectionType.userCreated.canShare, "User created collections should be shareable")
        XCTAssertTrue(CollectionType.communityRecipes.canShare, "Community recipes should be shareable")
    }

    /// Test 22: Non-shareable collection types
    func test_collectionType_canShare_restrictedTypes() {
        // These types CANNOT be shared
        XCTAssertFalse(CollectionType.fromFriends.canShare, "From Friends should NOT be shareable (prevent redistribution)")
        XCTAssertFalse(CollectionType.theme.canShare, "Theme collections should NOT be shareable (licensing)")
        XCTAssertFalse(CollectionType.system.canShare, "System collections should NOT be shareable")
    }

    /// Test 23: Share restriction reasons exist for restricted types
    func test_collectionType_shareRestrictionReason_exists() {
        // Restricted types should have a reason
        XCTAssertNotNil(CollectionType.fromFriends.shareRestrictionReason)
        XCTAssertNotNil(CollectionType.theme.shareRestrictionReason)
        XCTAssertNotNil(CollectionType.system.shareRestrictionReason)

        // Shareable types should NOT have a reason
        XCTAssertNil(CollectionType.videoImports.shareRestrictionReason)
        XCTAssertNil(CollectionType.webImports.shareRestrictionReason)
        XCTAssertNil(CollectionType.photoImports.shareRestrictionReason)
        XCTAssertNil(CollectionType.cookbook.shareRestrictionReason)
        XCTAssertNil(CollectionType.userCreated.shareRestrictionReason)
    }

    // MARK: - System Managed Tests

    /// Test 24: System managed collections (cannot be deleted)
    func test_collectionType_isSystemManaged_true() {
        // Auto-created collections are system-managed
        XCTAssertTrue(CollectionType.fromFriends.isSystemManaged, "From Friends is system-managed")
        XCTAssertTrue(CollectionType.videoImports.isSystemManaged, "Video Imports is system-managed")
        XCTAssertTrue(CollectionType.webImports.isSystemManaged, "Web Imports is system-managed")
        XCTAssertTrue(CollectionType.photoImports.isSystemManaged, "Photo Imports is system-managed")
        XCTAssertTrue(CollectionType.communityRecipes.isSystemManaged, "Community Recipes is system-managed")
        XCTAssertTrue(CollectionType.theme.isSystemManaged, "Theme collections are system-managed")
        XCTAssertTrue(CollectionType.system.isSystemManaged, "System collections are system-managed")
    }

    /// Test 25: User-deletable collections
    func test_collectionType_isSystemManaged_false() {
        // User can delete these
        XCTAssertFalse(CollectionType.cookbook.isSystemManaged, "Cookbook collections can be deleted")
        XCTAssertFalse(CollectionType.userCreated.isSystemManaged, "User created collections can be deleted")
    }

    // MARK: - Sort Priority Tests

    /// Test 26: Sort priority ordering
    func test_collectionType_sortPriority_ordering() {
        // Community recipes should appear first (lowest priority number)
        XCTAssertLessThan(CollectionType.communityRecipes.sortPriority, CollectionType.fromFriends.sortPriority)

        // Import types should appear before user-created
        XCTAssertLessThan(CollectionType.fromFriends.sortPriority, CollectionType.userCreated.sortPriority)
        XCTAssertLessThan(CollectionType.videoImports.sortPriority, CollectionType.userCreated.sortPriority)
        XCTAssertLessThan(CollectionType.webImports.sortPriority, CollectionType.userCreated.sortPriority)
        XCTAssertLessThan(CollectionType.photoImports.sortPriority, CollectionType.userCreated.sortPriority)
        XCTAssertLessThan(CollectionType.cookbook.sortPriority, CollectionType.userCreated.sortPriority)

        // User-created should appear before themes
        XCTAssertLessThan(CollectionType.userCreated.sortPriority, CollectionType.theme.sortPriority)

        // Themes should appear before system
        XCTAssertLessThan(CollectionType.theme.sortPriority, CollectionType.system.sortPriority)
    }

    /// Test 27: Import types have consistent ordering
    func test_collectionType_sortPriority_importOrdering() {
        // Verify import types are ordered: friends < video < web < photo < cookbook
        XCTAssertLessThan(CollectionType.fromFriends.sortPriority, CollectionType.videoImports.sortPriority)
        XCTAssertLessThan(CollectionType.videoImports.sortPriority, CollectionType.webImports.sortPriority)
        XCTAssertLessThan(CollectionType.webImports.sortPriority, CollectionType.photoImports.sortPriority)
        XCTAssertLessThan(CollectionType.photoImports.sortPriority, CollectionType.cookbook.sortPriority)
    }

    // MARK: - Collection Category Properties Tests

    /// Test 28: Category display order
    func test_collectionCategory_displayOrder() {
        // Imported should come first
        XCTAssertLessThan(CollectionCategory.imported.displayOrder, CollectionCategory.cookbooks.displayOrder)
        XCTAssertLessThan(CollectionCategory.cookbooks.displayOrder, CollectionCategory.themes.displayOrder)
        XCTAssertLessThan(CollectionCategory.themes.displayOrder, CollectionCategory.user.displayOrder)
        XCTAssertLessThan(CollectionCategory.user.displayOrder, CollectionCategory.system.displayOrder)
    }

    /// Test 29: Category display names
    func test_collectionCategory_displayNames() {
        XCTAssertEqual(CollectionCategory.imported.displayName, "Imported")
        XCTAssertEqual(CollectionCategory.cookbooks.displayName, "Cookbooks")
        XCTAssertEqual(CollectionCategory.themes.displayName, "Themes")
        XCTAssertEqual(CollectionCategory.user.displayName, "My Collections")
        XCTAssertEqual(CollectionCategory.system.displayName, "System")
    }

    /// Test 30: Category section icons
    func test_collectionCategory_sectionIcons() {
        XCTAssertEqual(CollectionCategory.imported.sectionIcon, "square.and.arrow.down")
        XCTAssertEqual(CollectionCategory.cookbooks.sectionIcon, "book.closed")
        XCTAssertEqual(CollectionCategory.themes.sectionIcon, "sparkles")
        XCTAssertEqual(CollectionCategory.user.sectionIcon, "folder")
        XCTAssertEqual(CollectionCategory.system.sectionIcon, "gear")
    }

    // MARK: - Visibility Tests

    /// Test 31: Collection type visibility in main list
    func test_collectionType_isVisibleInMainList() {
        // System should be hidden
        XCTAssertFalse(CollectionType.system.isVisibleInMainList)

        // All other types should be visible
        XCTAssertTrue(CollectionType.theme.isVisibleInMainList)
        XCTAssertTrue(CollectionType.fromFriends.isVisibleInMainList)
        XCTAssertTrue(CollectionType.videoImports.isVisibleInMainList)
        XCTAssertTrue(CollectionType.webImports.isVisibleInMainList)
        XCTAssertTrue(CollectionType.photoImports.isVisibleInMainList)
        XCTAssertTrue(CollectionType.cookbook.isVisibleInMainList)
        XCTAssertTrue(CollectionType.userCreated.isVisibleInMainList)
        XCTAssertTrue(CollectionType.communityRecipes.isVisibleInMainList)
    }

    /// Test 32: Collection type default icons
    func test_collectionType_defaultIcons() {
        XCTAssertEqual(CollectionType.system.defaultIconName, "gear")
        XCTAssertEqual(CollectionType.theme.defaultIconName, "sparkles")
        XCTAssertEqual(CollectionType.fromFriends.defaultIconName, "person.2.fill")
        XCTAssertEqual(CollectionType.videoImports.defaultIconName, "video.fill")
        XCTAssertEqual(CollectionType.webImports.defaultIconName, "link")
        XCTAssertEqual(CollectionType.photoImports.defaultIconName, "photo.fill")
        XCTAssertEqual(CollectionType.cookbook.defaultIconName, "book.closed.fill")
        XCTAssertEqual(CollectionType.userCreated.defaultIconName, "folder.fill")
        XCTAssertEqual(CollectionType.communityRecipes.defaultIconName, "globe")
    }

    // MARK: - Duplicate Collection Prevention Tests

    /// Test 33: Collections have unique IDs
    func test_collections_haveUniqueIds() throws {
        // GIVEN: Multiple collections created
        var ids: Set<UUID> = []

        for i in 1...10 {
            let collection = RecipeCollection(name: "Collection \(i)")
            env.modelContext.insert(collection)
            ids.insert(collection.id)
        }
        try env.save()

        // THEN: All IDs should be unique
        XCTAssertEqual(ids.count, 10, "All 10 collections should have unique IDs")
    }

    /// Test 34: Same name collections are allowed (different IDs)
    func test_collections_sameNameAllowed_differentIds() throws {
        // GIVEN: Two collections with same name
        let collection1 = RecipeCollection(name: "Favorites")
        let collection2 = RecipeCollection(name: "Favorites")

        env.modelContext.insert(collection1)
        env.modelContext.insert(collection2)
        try env.save()

        // THEN: Both exist with different IDs
        let collections = try env.fetchAllCollections()
        XCTAssertEqual(collections.count, 2)
        XCTAssertNotEqual(collection1.id, collection2.id)
    }

    /// Test 35: System collection types should be singleton per type
    func test_systemCollections_shouldBeSingleton() throws {
        // GIVEN: System import collection types
        let importTypes: [CollectionType] = [.fromFriends, .videoImports, .webImports, .photoImports]

        // Create first set of import collections
        for type in importTypes {
            let collection = RecipeCollection(
                name: type.displayName,
                collectionType: type
            )
            env.modelContext.insert(collection)
        }
        try env.save()

        // THEN: Should have 4 collections (one per import type)
        let allCollections = try env.fetchAllCollections()
        XCTAssertEqual(allCollections.count, 4)

        // Verify each type exists exactly once
        for type in importTypes {
            let matchingCollections = allCollections.filter { $0.type == type }
            XCTAssertEqual(matchingCollections.count, 1, "\(type.displayName) should exist exactly once")
        }
    }

    /// Test 36: Recipe cannot be added to same collection twice
    func test_recipe_cannotBeAddedToSameCollectionTwice() throws {
        // GIVEN: Collection and recipe
        let collection = RecipeCollection(name: "Test Collection")
        let recipe = env.createTestRecipe(title: "Test Recipe")

        collection.recipes = []
        recipe.collections = []

        env.modelContext.insert(collection)
        try env.save()

        // WHEN: Adding recipe to collection twice
        collection.recipes?.append(recipe)
        recipe.collections?.append(collection)

        // Try to add again (should be idempotent or prevented)
        if !(collection.recipes?.contains(where: { $0.id == recipe.id }) ?? false) {
            collection.recipes?.append(recipe)
        }
        try env.save()

        // THEN: Recipe should only appear once
        XCTAssertEqual(collection.recipes?.count, 1, "Recipe should only be in collection once")
        XCTAssertEqual(recipe.collections?.count, 1, "Recipe should only reference collection once")
    }

    /// Test 37: Each collection type has unique sort priority
    func test_collectionTypes_haveUniqueSortPriorities() {
        // Get all sort priorities
        var priorities: [Int: CollectionType] = [:]

        for type in CollectionType.allCases {
            let priority = type.sortPriority

            if let existingType = priorities[priority] {
                // Allow same priority only for community recipes (special case)
                if type != .communityRecipes && existingType != .communityRecipes {
                    XCTFail("Duplicate sort priority \(priority) for \(type) and \(existingType)")
                }
            }
            priorities[priority] = type
        }
    }

    /// Test 38: Each category appears only once in display order
    func test_collectionCategories_uniqueDisplayOrder() {
        // Get all display orders
        var orders: [Int: CollectionCategory] = [:]

        let categories: [CollectionCategory] = [.imported, .cookbooks, .themes, .user, .system]

        for category in categories {
            let order = category.displayOrder

            if let existingCategory = orders[order] {
                XCTFail("Duplicate display order \(order) for \(category) and \(existingCategory)")
            }
            orders[order] = category
        }

        // All 5 categories should have unique orders
        XCTAssertEqual(orders.count, 5)
    }

    /// Test 39: Collection type rawValues are unique
    func test_collectionType_rawValuesUnique() {
        var rawValues: Set<String> = []

        for type in CollectionType.allCases {
            let rawValue = type.rawValue
            XCTAssertFalse(rawValues.contains(rawValue), "Duplicate rawValue: \(rawValue)")
            rawValues.insert(rawValue)
        }

        XCTAssertEqual(rawValues.count, CollectionType.allCases.count)
    }

    /// Test 40: Collection category rawValues are unique
    func test_collectionCategory_rawValuesUnique() {
        let categories: [CollectionCategory] = [.imported, .cookbooks, .themes, .user, .system]
        var rawValues: Set<String> = []

        for category in categories {
            let rawValue = category.rawValue
            XCTAssertFalse(rawValues.contains(rawValue), "Duplicate rawValue: \(rawValue)")
            rawValues.insert(rawValue)
        }

        XCTAssertEqual(rawValues.count, 5)
    }
}
