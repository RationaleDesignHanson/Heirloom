//
//  CollectionRouterTests.swift
//  HeirloomTestsV2
//
//  Unit tests for CollectionRouter: routing recipes to collections,
//  deduplication, cookbook name cleaning, and job-level caching.
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class CollectionRouterTests: XCTestCase {

    var env: TestEnvironment!
    var router: CollectionRouter!

    override func setUp() async throws {
        env = try await TestEnvironment.create()
        router = CollectionRouter(modelContext: env.modelContext)
    }

    override func tearDown() async throws {
        env?.tearDown()
        env = nil
        router = nil
    }

    // MARK: - routeToSpecificCollection

    func test_routeToSpecificCollection_addsRecipeToCollection() {
        // GIVEN: A recipe and a collection
        let recipe = env.createTestRecipe(title: "Pasta")
        let collection = env.createTestCollection(name: "Italian")

        // WHEN: Routing to specific collection
        router.routeToSpecificCollection(recipe, collection: collection)

        // THEN: Recipe is in collection
        XCTAssertTrue(recipe.collections?.contains(where: { $0.id == collection.id }) ?? false)
    }

    func test_routeToSpecificCollection_batch_addsAllRecipes() {
        // GIVEN: Multiple recipes and a collection
        let recipes = [
            env.createTestRecipe(title: "Pasta"),
            env.createTestRecipe(title: "Pizza"),
            env.createTestRecipe(title: "Risotto")
        ]
        let collection = env.createTestCollection(name: "Italian")

        // WHEN: Routing batch
        router.routeToSpecificCollection(recipes, collection: collection)

        // THEN: All recipes in collection
        for recipe in recipes {
            XCTAssertTrue(recipe.collections?.contains(where: { $0.id == collection.id }) ?? false,
                         "\(recipe.title) should be in collection")
        }
    }

    func test_routeToSpecificCollection_idempotent_doesNotDuplicate() {
        // GIVEN: Recipe already in collection
        let recipe = env.createTestRecipe(title: "Pasta")
        let collection = env.createTestCollection(name: "Italian")
        router.routeToSpecificCollection(recipe, collection: collection)

        // WHEN: Routing again
        router.routeToSpecificCollection(recipe, collection: collection)

        // THEN: Recipe only appears once
        let count = recipe.collections?.filter({ $0.id == collection.id }).count ?? 0
        XCTAssertEqual(count, 1)
    }

    // MARK: - routeSharedRecipe

    func test_routeSharedRecipe_createsFromFriendsCollection() {
        // GIVEN: A recipe shared by a friend
        let recipe = env.createTestRecipe(title: "Grandma's Cookies")

        // WHEN: Routing shared recipe
        router.routeSharedRecipe(recipe, from: "Jane")

        // THEN: Recipe is in "From Friends" collection
        let fromFriends = recipe.collections?.first(where: { $0.name == "From Friends" })
        XCTAssertNotNil(fromFriends)
        XCTAssertEqual(fromFriends?.collectionType, CollectionType.fromFriends.rawValue)
    }

    func test_routeSharedRecipe_setsSharingMetadata() {
        // GIVEN: A recipe
        let recipe = env.createTestRecipe(title: "Cookies")

        // WHEN: Routing with sender name
        router.routeSharedRecipe(recipe, from: "Jane")

        // THEN: Metadata set
        XCTAssertEqual(recipe.sharedBy, "Jane")
        XCTAssertNotNil(recipe.sharedDate)
    }

    func test_routeSharedRecipe_reusesExistingCollection() {
        // GIVEN: Two shared recipes
        let recipe1 = env.createTestRecipe(title: "Cookies")
        let recipe2 = env.createTestRecipe(title: "Cake")

        // WHEN: Routing both
        router.routeSharedRecipe(recipe1, from: "Jane")
        router.routeSharedRecipe(recipe2, from: "Bob")

        // THEN: Both in same "From Friends" collection
        let collection1 = recipe1.collections?.first(where: { $0.name == "From Friends" })
        let collection2 = recipe2.collections?.first(where: { $0.name == "From Friends" })
        XCTAssertNotNil(collection1)
        XCTAssertEqual(collection1?.id, collection2?.id)
    }

    // MARK: - routeURLImport

    func test_routeURLImport_createsFromWebCollection() {
        // GIVEN: A recipe imported from URL
        let recipe = env.createTestRecipe(title: "Pasta Carbonara")
        let url = URL(string: "https://allrecipes.com/recipe/12345")!

        // WHEN: Routing
        router.routeURLImport(recipe, sourceURL: url)

        // THEN: In "From Web" collection
        let fromWeb = recipe.collections?.first(where: { $0.name == "From Web" })
        XCTAssertNotNil(fromWeb)
        XCTAssertEqual(fromWeb?.collectionType, CollectionType.webImports.rawValue)
    }

    func test_routeURLImport_setsSourceURL() {
        // GIVEN: A recipe
        let recipe = env.createTestRecipe(title: "Pasta")
        let url = URL(string: "https://example.com/recipe")!

        // WHEN: Routing
        router.routeURLImport(recipe, sourceURL: url)

        // THEN: Source URL set
        XCTAssertEqual(recipe.sourceURL, "https://example.com/recipe")
    }

    // MARK: - routeVideoImport

    func test_routeVideoImport_createsFromVideosCollection() {
        // GIVEN: A recipe from video
        let recipe = env.createTestRecipe(title: "TikTok Pasta")

        // WHEN: Routing
        router.routeVideoImport(recipe)

        // THEN: In "From Videos" collection
        let fromVideos = recipe.collections?.first(where: { $0.name == "From Videos" })
        XCTAssertNotNil(fromVideos)
        XCTAssertEqual(fromVideos?.collectionType, CollectionType.videoImports.rawValue)
    }

    // MARK: - routePhotoImport

    func test_routePhotoImport_createsFromPhotosCollection() {
        // GIVEN: A recipe from photo OCR
        let recipe = env.createTestRecipe(title: "Handwritten Recipe")

        // WHEN: Routing
        router.routePhotoImport(recipe)

        // THEN: In "From Photos" collection
        let fromPhotos = recipe.collections?.first(where: { $0.name == "From Photos" })
        XCTAssertNotNil(fromPhotos)
        XCTAssertEqual(fromPhotos?.collectionType, CollectionType.photoImports.rawValue)
    }

    // MARK: - routeReadRecipe

    func test_routeReadRecipe_createsReadRecipesCollection() {
        // GIVEN: A recipe read aloud
        let recipe = env.createTestRecipe(title: "Read Recipe")

        // WHEN: Routing
        router.routeReadRecipe(recipe)

        // THEN: In "Read Recipes" collection
        let readRecipes = recipe.collections?.first(where: { $0.name == "Read Recipes" })
        XCTAssertNotNil(readRecipes)
        XCTAssertEqual(readRecipes?.collectionType, CollectionType.readRecipes.rawValue)
    }

    // MARK: - routeCookbookImport

    func test_routeCookbookImport_createsNamedCollection() {
        // GIVEN: Recipes from a named cookbook
        let recipe = env.createTestRecipe(title: "Beef Stew")

        // WHEN: Routing as cookbook import
        router.routeCookbookImport([recipe], cookbookName: "Joy of Cooking")

        // THEN: In cookbook collection (name cleaned: "the" prefix removed)
        let cookbookCollection = recipe.collections?.first(where: {
            $0.collectionType == CollectionType.cookbook.rawValue
        })
        XCTAssertNotNil(cookbookCollection)
    }

    func test_routeCookbookImport_setsAuthor() {
        // GIVEN: Cookbook with author
        let recipe = env.createTestRecipe(title: "Beef Stew")

        // WHEN: Routing with author
        router.routeCookbookImport([recipe], cookbookName: "My Cookbook", authorName: "Julia Child")

        // THEN: Author set on collection
        let collection = recipe.collections?.first(where: {
            $0.collectionType == CollectionType.cookbook.rawValue
        })
        XCTAssertEqual(collection?.sourceAuthor, "Julia Child")
    }

    func test_routeCookbookImport_cookbookPages_consolidatesGlobally() {
        // GIVEN: Two batches of "Cookbook Pages" imports
        let recipe1 = env.createTestRecipe(title: "Recipe 1")
        let recipe2 = env.createTestRecipe(title: "Recipe 2")
        let jobID1 = UUID()
        let jobID2 = UUID()

        // WHEN: Routing both batches
        router.routeCookbookImport([recipe1], cookbookName: "Cookbook Pages", jobID: jobID1)
        router.routeCookbookImport([recipe2], cookbookName: "Cookbook Pages", jobID: jobID2)

        // THEN: Both in same collection
        let collection1 = recipe1.collections?.first(where: {
            $0.collectionType == CollectionType.cookbook.rawValue
        })
        let collection2 = recipe2.collections?.first(where: {
            $0.collectionType == CollectionType.cookbook.rawValue
        })
        XCTAssertNotNil(collection1)
        XCTAssertEqual(collection1?.id, collection2?.id)
    }

    func test_routeCookbookImport_cookbookPages_doesNotSetSourceCookbook() {
        // GIVEN: "Cookbook Pages" catch-all
        let recipe = env.createTestRecipe(title: "Recipe")

        // WHEN: Routing
        router.routeCookbookImport([recipe], cookbookName: "Cookbook Pages")

        // THEN: sourceCookbook not set (it's the catch-all)
        XCTAssertNil(recipe.sourceCookbook)
    }

    func test_routeCookbookImport_namedCookbook_setsSourceCookbook() {
        // GIVEN: Named cookbook
        let recipe = env.createTestRecipe(title: "Recipe")

        // WHEN: Routing
        router.routeCookbookImport([recipe], cookbookName: "My Cookbook")

        // THEN: sourceCookbook set
        XCTAssertEqual(recipe.sourceCookbook, "My Cookbook")
    }

    // MARK: - findOrCreateCollection Deduplication

    func test_findOrCreateCollection_reusesExisting() {
        // GIVEN: An existing collection
        let existing = router.findOrCreateCollection(
            name: "From Web",
            type: .webImports,
            iconName: "link"
        )

        // WHEN: Finding again
        let found = router.findOrCreateCollection(
            name: "From Web",
            type: .webImports,
            iconName: "link"
        )

        // THEN: Same collection
        XCTAssertEqual(existing.id, found.id)
    }

    func test_findOrCreateCollection_differentTypes_createsSeparate() {
        // GIVEN: Collection with one type
        let web = router.findOrCreateCollection(
            name: "Test",
            type: .webImports,
            iconName: "link"
        )

        // WHEN: Same name but different type
        let video = router.findOrCreateCollection(
            name: "Test",
            type: .videoImports,
            iconName: "video"
        )

        // THEN: Different collections
        XCTAssertNotEqual(web.id, video.id)
    }

    // MARK: - Job Caching

    func test_jobTracking_reusesSameCollectionWithinJob() {
        // GIVEN: Two batches with same jobID
        let recipe1 = env.createTestRecipe(title: "Video 1")
        let recipe2 = env.createTestRecipe(title: "Video 2")
        let jobID = UUID()

        // WHEN: Routing both with same job
        router.routeVideoImport([recipe1], jobID: jobID)
        router.routeVideoImport([recipe2], jobID: jobID)

        // THEN: Same collection used
        let col1 = recipe1.collections?.first(where: { $0.name == "From Videos" })
        let col2 = recipe2.collections?.first(where: { $0.name == "From Videos" })
        XCTAssertNotNil(col1)
        XCTAssertEqual(col1?.id, col2?.id)
    }

    // MARK: - Cookbook Name Cleaning

    func test_cleanCookbookName_removesPdfExtension() {
        // GIVEN: Cookbook with .pdf extension
        let recipe = env.createTestRecipe(title: "Recipe")

        // WHEN: Routing with PDF filename
        router.routeCookbookImport([recipe], cookbookName: "My Cookbook.pdf")

        // THEN: Extension removed
        let collection = recipe.collections?.first(where: {
            $0.collectionType == CollectionType.cookbook.rawValue
        })
        XCTAssertNotNil(collection)
        XCTAssertFalse(collection?.name.contains(".pdf") ?? true)
    }

    func test_cleanCookbookName_removesThePrefix() {
        // GIVEN: Cookbook with "the" prefix
        let recipe = env.createTestRecipe(title: "Recipe")

        // WHEN: Routing
        router.routeCookbookImport([recipe], cookbookName: "the Joy of Cooking")

        // THEN: "the" removed and first letter capitalized
        let collection = recipe.collections?.first(where: {
            $0.collectionType == CollectionType.cookbook.rawValue
        })
        XCTAssertNotNil(collection)
        XCTAssertEqual(collection?.name, "Joy of Cooking")
    }

    func test_cleanCookbookName_removesAPrefix() {
        let recipe = env.createTestRecipe(title: "Recipe")
        router.routeCookbookImport([recipe], cookbookName: "a Simple Cookbook")

        let collection = recipe.collections?.first(where: {
            $0.collectionType == CollectionType.cookbook.rawValue
        })
        XCTAssertEqual(collection?.name, "Simple Cookbook")
    }

    func test_cleanCookbookName_capitalizesFirstLetter() {
        let recipe = env.createTestRecipe(title: "Recipe")
        router.routeCookbookImport([recipe], cookbookName: "my recipes")

        let collection = recipe.collections?.first(where: {
            $0.collectionType == CollectionType.cookbook.rawValue
        })
        XCTAssertEqual(collection?.name, "My recipes")
    }
}
