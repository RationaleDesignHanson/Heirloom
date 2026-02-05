//
//  ImageCleanupTests.swift
//  HeirloomTestsV2
//
//  Unit tests for orphaned image cleanup logic
//  Tests the collection of valid image filenames from recipes
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class ImageCleanupTests: XCTestCase {

    // MARK: - Properties

    var env: TestEnvironment!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        env = try await TestEnvironment.create()
    }

    override func tearDown() async throws {
        env.tearDown()
        env = nil
        try await super.tearDown()
    }

    // MARK: - Valid Image Filename Collection Tests

    /// Test 1: Recipe with imageFileName is collected
    func test_imageFilenameCollection_recipeWithImage_collected() throws {
        // GIVEN: A recipe with an image filename
        let recipe = env.createTestRecipe(title: "Recipe With Image")
        recipe.imageFileName = "recipe-abc123.jpg"
        try env.save()

        // WHEN: Collecting valid image filenames
        let validFileNames = try collectValidImageFileNames(context: env.modelContext)

        // THEN: Image filename should be in the set
        XCTAssertTrue(validFileNames.contains("recipe-abc123.jpg"))
        XCTAssertEqual(validFileNames.count, 1)
    }

    /// Test 2: Recipe without imageFileName doesn't add to collection
    func test_imageFilenameCollection_recipeWithoutImage_notCollected() throws {
        // GIVEN: A recipe without an image filename
        let recipe = env.createTestRecipe(title: "Recipe Without Image")
        recipe.imageFileName = nil
        try env.save()

        // WHEN: Collecting valid image filenames
        let validFileNames = try collectValidImageFileNames(context: env.modelContext)

        // THEN: Set should be empty
        XCTAssertEqual(validFileNames.count, 0)
    }

    /// Test 3: Multiple recipes with images all collected
    func test_imageFilenameCollection_multipleRecipes_allCollected() throws {
        // GIVEN: Multiple recipes with images
        let recipe1 = env.createTestRecipe(title: "Recipe 1")
        recipe1.imageFileName = "recipe-1.jpg"

        let recipe2 = env.createTestRecipe(title: "Recipe 2")
        recipe2.imageFileName = "recipe-2.jpg"

        let recipe3 = env.createTestRecipe(title: "Recipe 3")
        recipe3.imageFileName = "recipe-3.jpg"

        try env.save()

        // WHEN: Collecting valid image filenames
        let validFileNames = try collectValidImageFileNames(context: env.modelContext)

        // THEN: All filenames should be collected
        XCTAssertEqual(validFileNames.count, 3)
        XCTAssertTrue(validFileNames.contains("recipe-1.jpg"))
        XCTAssertTrue(validFileNames.contains("recipe-2.jpg"))
        XCTAssertTrue(validFileNames.contains("recipe-3.jpg"))
    }

    /// Test 4: Recipe with image variants has all variants collected
    func test_imageFilenameCollection_recipeWithVariants_allVariantsCollected() throws {
        // GIVEN: A heritage recipe with image variants
        let recipe = env.createTestRecipe(title: "Heritage Recipe")
        recipe.imageFileName = "recipe-heritage-main.jpg"
        recipe.imageVariants = [
            "hero": "recipe-heritage-hero.jpg",
            "card": "recipe-heritage-card.jpg",
            "thumbnail": "recipe-heritage-thumbnail.jpg"
        ]
        try env.save()

        // WHEN: Collecting valid image filenames
        let validFileNames = try collectValidImageFileNames(context: env.modelContext)

        // THEN: Main image and all variants should be collected
        XCTAssertEqual(validFileNames.count, 4)
        XCTAssertTrue(validFileNames.contains("recipe-heritage-main.jpg"))
        XCTAssertTrue(validFileNames.contains("recipe-heritage-hero.jpg"))
        XCTAssertTrue(validFileNames.contains("recipe-heritage-card.jpg"))
        XCTAssertTrue(validFileNames.contains("recipe-heritage-thumbnail.jpg"))
    }

    /// Test 5: Recipe with only variants (no main image) has variants collected
    func test_imageFilenameCollection_onlyVariants_collected() throws {
        // GIVEN: A recipe with only image variants (no main imageFileName)
        let recipe = env.createTestRecipe(title: "Variants Only Recipe")
        recipe.imageFileName = nil
        recipe.imageVariants = [
            "hero": "recipe-hero.jpg",
            "thumbnail": "recipe-thumb.jpg"
        ]
        try env.save()

        // WHEN: Collecting valid image filenames
        let validFileNames = try collectValidImageFileNames(context: env.modelContext)

        // THEN: Variants should be collected
        XCTAssertEqual(validFileNames.count, 2)
        XCTAssertTrue(validFileNames.contains("recipe-hero.jpg"))
        XCTAssertTrue(validFileNames.contains("recipe-thumb.jpg"))
    }

    /// Test 6: Empty database returns empty set
    func test_imageFilenameCollection_emptyDatabase_emptySet() throws {
        // GIVEN: Empty database
        let recipes = try env.fetchAllRecipes()
        XCTAssertEqual(recipes.count, 0)

        // WHEN: Collecting valid image filenames
        let validFileNames = try collectValidImageFileNames(context: env.modelContext)

        // THEN: Set should be empty
        XCTAssertEqual(validFileNames.count, 0)
    }

    /// Test 7: Duplicate filenames are deduplicated
    func test_imageFilenameCollection_duplicateFilenames_deduplicated() throws {
        // GIVEN: Two recipes referencing the same image (edge case)
        let recipe1 = env.createTestRecipe(title: "Recipe 1")
        recipe1.imageFileName = "shared-image.jpg"

        let recipe2 = env.createTestRecipe(title: "Recipe 2")
        recipe2.imageFileName = "shared-image.jpg"

        try env.save()

        // WHEN: Collecting valid image filenames
        let validFileNames = try collectValidImageFileNames(context: env.modelContext)

        // THEN: Set should have only 1 entry (deduplicated)
        XCTAssertEqual(validFileNames.count, 1)
        XCTAssertTrue(validFileNames.contains("shared-image.jpg"))
    }

    /// Test 8: Mixed recipes with and without images
    func test_imageFilenameCollection_mixedRecipes_onlyImagesCollected() throws {
        // GIVEN: Mix of recipes with and without images
        let recipe1 = env.createTestRecipe(title: "With Image")
        recipe1.imageFileName = "recipe-with.jpg"

        let recipe2 = env.createTestRecipe(title: "Without Image")
        recipe2.imageFileName = nil

        let recipe3 = env.createTestRecipe(title: "With Variants")
        recipe3.imageFileName = nil
        recipe3.imageVariants = ["hero": "recipe-hero.jpg"]

        try env.save()

        // WHEN: Collecting valid image filenames
        let validFileNames = try collectValidImageFileNames(context: env.modelContext)

        // THEN: Only recipes with images should contribute
        XCTAssertEqual(validFileNames.count, 2)
        XCTAssertTrue(validFileNames.contains("recipe-with.jpg"))
        XCTAssertTrue(validFileNames.contains("recipe-hero.jpg"))
    }

    // MARK: - Test Helpers

    /// Replicates the logic from JobCleanupService.cleanupOrphanedImages
    /// to collect valid image filenames from recipes
    private func collectValidImageFileNames(context: ModelContext) throws -> Set<String> {
        let descriptor = FetchDescriptor<Recipe>()
        let allRecipes = try context.fetch(descriptor)
        var validImageFileNames = Set<String>()

        for recipe in allRecipes {
            // Add main image filename
            if let imageFileName = recipe.imageFileName {
                validImageFileNames.insert(imageFileName)
            }

            // Add image variant filenames (for heritage/theme recipes)
            if let variants = recipe.imageVariants {
                for fileName in variants.values {
                    validImageFileNames.insert(fileName)
                }
            }
        }

        return validImageFileNames
    }
}
