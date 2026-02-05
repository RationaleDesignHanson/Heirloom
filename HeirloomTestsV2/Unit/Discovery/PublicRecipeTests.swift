//
//  PublicRecipeTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-05
//  Unit tests for PublicRecipe model and creator attribution
//
//  Tests cover:
//  - Creator attribution fields (name, avatar, profile)
//  - Search keyword generation
//  - Validation logic
//  - Firestore data encoding
//

import XCTest
@testable import Heirloom

final class PublicRecipeTests: XCTestCase {

    // MARK: - Creator Attribution Tests

    /// Test 1: PublicRecipe stores creator name correctly
    func test_publicRecipe_creatorName_stored() {
        // GIVEN: A public recipe with creator name
        let recipe = createTestPublicRecipe(creatorName: "Chef Avery")

        // THEN: Creator name should be accessible
        XCTAssertEqual(recipe.creatorName, "Chef Avery")
    }

    /// Test 2: PublicRecipe stores creator photo URL correctly
    func test_publicRecipe_creatorPhotoURL_stored() {
        // GIVEN: A public recipe with creator photo URL
        let photoURL = "https://example.com/avatars/chef-avery.jpg"
        let recipe = createTestPublicRecipe(creatorPhotoURL: photoURL)

        // THEN: Creator photo URL should be accessible
        XCTAssertEqual(recipe.creatorPhotoURL, photoURL)
    }

    /// Test 3: PublicRecipe stores creator profile slug correctly
    func test_publicRecipe_creatorProfileSlug_stored() {
        // GIVEN: A public recipe with creator profile slug
        let slug = "chef-avery"
        let recipe = createTestPublicRecipe(creatorProfileSlug: slug)

        // THEN: Creator profile slug should be accessible
        XCTAssertEqual(recipe.creatorProfileSlug, slug)
    }

    /// Test 4: PublicRecipe handles nil creator photo URL
    func test_publicRecipe_creatorPhotoURL_nil_handledGracefully() {
        // GIVEN: A public recipe without creator photo URL
        let recipe = createTestPublicRecipe(creatorPhotoURL: nil)

        // THEN: Creator photo URL should be nil
        XCTAssertNil(recipe.creatorPhotoURL)
    }

    /// Test 5: PublicRecipe handles nil creator profile slug
    func test_publicRecipe_creatorProfileSlug_nil_handledGracefully() {
        // GIVEN: A public recipe without creator profile slug
        let recipe = createTestPublicRecipe(creatorProfileSlug: nil)

        // THEN: Creator profile slug should be nil
        XCTAssertNil(recipe.creatorProfileSlug)
    }

    /// Test 6: Full creator attribution with all fields
    func test_publicRecipe_fullCreatorAttribution() {
        // GIVEN: A public recipe with complete creator attribution
        let recipe = createTestPublicRecipe(
            creatorName: "Chef Avery",
            creatorPhotoURL: "https://example.com/avatar.jpg",
            creatorProfileSlug: "chef-avery"
        )

        // THEN: All attribution fields should be accessible
        XCTAssertEqual(recipe.creatorName, "Chef Avery")
        XCTAssertEqual(recipe.creatorPhotoURL, "https://example.com/avatar.jpg")
        XCTAssertEqual(recipe.creatorProfileSlug, "chef-avery")
    }

    // MARK: - Search Keywords Tests

    /// Test 7: Search keywords include title words
    func test_searchKeywords_includesTitleWords() {
        // GIVEN: Title with multiple words
        let keywords = PublicRecipe.generateSearchKeywords(
            title: "Grandma's Apple Pie",
            ingredients: [],
            creatorName: ""
        )

        // THEN: Title words (>= 3 chars) should be included
        XCTAssertTrue(keywords.contains("grandma"))
        XCTAssertTrue(keywords.contains("apple"))
        XCTAssertTrue(keywords.contains("pie"))
    }

    /// Test 8: Search keywords include ingredient words
    func test_searchKeywords_includesIngredientWords() {
        // GIVEN: Ingredients list
        let keywords = PublicRecipe.generateSearchKeywords(
            title: "Recipe",
            ingredients: ["2 cups flour", "1 tsp vanilla extract"],
            creatorName: ""
        )

        // THEN: Ingredient words (>= 3 chars) should be included
        XCTAssertTrue(keywords.contains("cups"))
        XCTAssertTrue(keywords.contains("flour"))
        XCTAssertTrue(keywords.contains("vanilla"))
        XCTAssertTrue(keywords.contains("extract"))
    }

    /// Test 9: Search keywords include creator name
    func test_searchKeywords_includesCreatorName() {
        // GIVEN: Creator name
        let keywords = PublicRecipe.generateSearchKeywords(
            title: "Recipe",
            ingredients: [],
            creatorName: "Chef Avery"
        )

        // THEN: Creator name words (>= 3 chars) should be included
        XCTAssertTrue(keywords.contains("chef"))
        XCTAssertTrue(keywords.contains("avery"))
    }

    /// Test 10: Search keywords filter short words
    func test_searchKeywords_filtersShortWords() {
        // GIVEN: Content with short words
        let keywords = PublicRecipe.generateSearchKeywords(
            title: "A to Z Pie",
            ingredients: ["1 lb of sugar"],
            creatorName: "Mr X"
        )

        // THEN: Words < 3 chars should be excluded
        XCTAssertFalse(keywords.contains("a"))
        XCTAssertFalse(keywords.contains("to"))
        XCTAssertFalse(keywords.contains("z"))
        XCTAssertFalse(keywords.contains("of"))
        XCTAssertFalse(keywords.contains("mr"))
        XCTAssertFalse(keywords.contains("x"))
    }

    /// Test 11: Search keywords are lowercased
    func test_searchKeywords_areLowercased() {
        // GIVEN: Mixed case content
        let keywords = PublicRecipe.generateSearchKeywords(
            title: "CHOCOLATE Cake",
            ingredients: ["SUGAR"],
            creatorName: "CHEF"
        )

        // THEN: All keywords should be lowercase
        XCTAssertTrue(keywords.contains("chocolate"))
        XCTAssertTrue(keywords.contains("cake"))
        XCTAssertTrue(keywords.contains("sugar"))
        XCTAssertTrue(keywords.contains("chef"))
        XCTAssertFalse(keywords.contains("CHOCOLATE"))
        XCTAssertFalse(keywords.contains("CAKE"))
    }

    /// Test 12: Search keywords are unique (no duplicates)
    func test_searchKeywords_areUnique() {
        // GIVEN: Content with repeated words
        let keywords = PublicRecipe.generateSearchKeywords(
            title: "Chocolate Chocolate Chip",
            ingredients: ["chocolate chips", "chocolate sauce"],
            creatorName: "Chocolate Chef"
        )

        // THEN: Each keyword should appear only once
        let chocolateCount = keywords.filter { $0 == "chocolate" }.count
        XCTAssertEqual(chocolateCount, 1)
    }

    /// Test 13: Search keywords are sorted
    func test_searchKeywords_areSorted() {
        // GIVEN: Content that would produce multiple keywords
        let keywords = PublicRecipe.generateSearchKeywords(
            title: "Zesty Apple Pie",
            ingredients: ["butter", "cinnamon"],
            creatorName: "Chef"
        )

        // THEN: Keywords should be sorted alphabetically
        let sortedKeywords = keywords.sorted()
        XCTAssertEqual(keywords, sortedKeywords)
    }

    // MARK: - Validation Tests

    /// Test 14: Valid recipe passes validation
    func test_isValid_withValidRecipe_returnsTrue() {
        // GIVEN: A recipe with required fields
        let recipe = createTestPublicRecipe(
            title: "Apple Pie",
            ingredients: ["apples", "sugar"],
            creatorName: "Chef"
        )

        // THEN: Should be valid
        XCTAssertTrue(recipe.isValid)
    }

    /// Test 15: Empty title fails validation
    func test_isValid_withEmptyTitle_returnsFalse() {
        // GIVEN: A recipe with empty title
        let recipe = createTestPublicRecipe(
            title: "",
            ingredients: ["apples"],
            creatorName: "Chef"
        )

        // THEN: Should be invalid
        XCTAssertFalse(recipe.isValid)
    }

    /// Test 16: Whitespace-only title fails validation
    func test_isValid_withWhitespaceTitle_returnsFalse() {
        // GIVEN: A recipe with whitespace-only title
        let recipe = createTestPublicRecipe(
            title: "   ",
            ingredients: ["apples"],
            creatorName: "Chef"
        )

        // THEN: Should be invalid
        XCTAssertFalse(recipe.isValid)
    }

    /// Test 17: Empty ingredients fails validation
    func test_isValid_withEmptyIngredients_returnsFalse() {
        // GIVEN: A recipe with no ingredients
        let recipe = createTestPublicRecipe(
            title: "Apple Pie",
            ingredients: [],
            creatorName: "Chef"
        )

        // THEN: Should be invalid
        XCTAssertFalse(recipe.isValid)
    }

    /// Test 18: Empty creator name fails validation
    func test_isValid_withEmptyCreatorName_returnsFalse() {
        // GIVEN: A recipe with empty creator name
        let recipe = createTestPublicRecipe(
            title: "Apple Pie",
            ingredients: ["apples"],
            creatorName: ""
        )

        // THEN: Should be invalid
        XCTAssertFalse(recipe.isValid)
    }

    /// Test 19: Whitespace-only creator name fails validation
    func test_isValid_withWhitespaceCreatorName_returnsFalse() {
        // GIVEN: A recipe with whitespace-only creator name
        let recipe = createTestPublicRecipe(
            title: "Apple Pie",
            ingredients: ["apples"],
            creatorName: "   "
        )

        // THEN: Should be invalid
        XCTAssertFalse(recipe.isValid)
    }

    // MARK: - Firestore Encoding Tests

    /// Test 20: toFirestoreData includes creator name
    func test_toFirestoreData_includesCreatorName() {
        // GIVEN: A recipe with creator name
        let recipe = createTestPublicRecipe(creatorName: "Chef Avery")

        // WHEN: Converting to Firestore data
        let data = recipe.toFirestoreData()

        // THEN: Creator name should be in data
        XCTAssertEqual(data["creatorName"] as? String, "Chef Avery")
    }

    /// Test 21: toFirestoreData includes creator photo URL when present
    func test_toFirestoreData_includesCreatorPhotoURL_whenPresent() {
        // GIVEN: A recipe with creator photo URL
        let photoURL = "https://example.com/avatar.jpg"
        let recipe = createTestPublicRecipe(creatorPhotoURL: photoURL)

        // WHEN: Converting to Firestore data
        let data = recipe.toFirestoreData()

        // THEN: Creator photo URL should be in data
        XCTAssertEqual(data["creatorPhotoURL"] as? String, photoURL)
    }

    /// Test 22: toFirestoreData excludes creator photo URL when nil
    func test_toFirestoreData_excludesCreatorPhotoURL_whenNil() {
        // GIVEN: A recipe without creator photo URL
        let recipe = createTestPublicRecipe(creatorPhotoURL: nil)

        // WHEN: Converting to Firestore data
        let data = recipe.toFirestoreData()

        // THEN: Creator photo URL should not be in data
        XCTAssertNil(data["creatorPhotoURL"])
    }

    /// Test 23: toFirestoreData includes creator profile slug when present
    func test_toFirestoreData_includesCreatorProfileSlug_whenPresent() {
        // GIVEN: A recipe with creator profile slug
        let slug = "chef-avery"
        let recipe = createTestPublicRecipe(creatorProfileSlug: slug)

        // WHEN: Converting to Firestore data
        let data = recipe.toFirestoreData()

        // THEN: Creator profile slug should be in data
        XCTAssertEqual(data["creatorProfileSlug"] as? String, slug)
    }

    /// Test 24: toFirestoreData excludes creator profile slug when nil
    func test_toFirestoreData_excludesCreatorProfileSlug_whenNil() {
        // GIVEN: A recipe without creator profile slug
        let recipe = createTestPublicRecipe(creatorProfileSlug: nil)

        // WHEN: Converting to Firestore data
        let data = recipe.toFirestoreData()

        // THEN: Creator profile slug should not be in data
        XCTAssertNil(data["creatorProfileSlug"])
    }

    // MARK: - Engagement Metrics Tests

    /// Test 25: View count defaults to zero
    func test_publicRecipe_viewCount_defaultsToZero() {
        // GIVEN: A new public recipe
        let recipe = createTestPublicRecipe()

        // THEN: View count should be zero
        XCTAssertEqual(recipe.viewCount, 0)
    }

    /// Test 26: Save count defaults to zero
    func test_publicRecipe_saveCount_defaultsToZero() {
        // GIVEN: A new public recipe
        let recipe = createTestPublicRecipe()

        // THEN: Save count should be zero
        XCTAssertEqual(recipe.saveCount, 0)
    }

    /// Test 27: toFirestoreData includes engagement metrics
    func test_toFirestoreData_includesEngagementMetrics() {
        // GIVEN: A recipe with engagement metrics
        var recipe = createTestPublicRecipe()
        recipe.viewCount = 42
        recipe.saveCount = 7

        // WHEN: Converting to Firestore data
        let data = recipe.toFirestoreData()

        // THEN: Engagement metrics should be in data
        XCTAssertEqual(data["viewCount"] as? Int, 42)
        XCTAssertEqual(data["saveCount"] as? Int, 7)
    }

    // MARK: - Moderation Fields Tests

    /// Test 28: isHidden defaults to false
    func test_publicRecipe_isHidden_defaultsToFalse() {
        // GIVEN: A new public recipe
        let recipe = createTestPublicRecipe()

        // THEN: isHidden should be false
        XCTAssertFalse(recipe.isHidden)
    }

    /// Test 29: reportCount defaults to zero
    func test_publicRecipe_reportCount_defaultsToZero() {
        // GIVEN: A new public recipe
        let recipe = createTestPublicRecipe()

        // THEN: reportCount should be zero
        XCTAssertEqual(recipe.reportCount, 0)
    }

    /// Test 30: toFirestoreData includes moderation fields
    func test_toFirestoreData_includesModerationFields() {
        // GIVEN: A recipe with moderation fields
        var recipe = createTestPublicRecipe()
        recipe.isHidden = true
        recipe.reportCount = 3
        recipe.moderationStatus = "pending_review"

        // WHEN: Converting to Firestore data
        let data = recipe.toFirestoreData()

        // THEN: Moderation fields should be in data
        XCTAssertEqual(data["isHidden"] as? Bool, true)
        XCTAssertEqual(data["reportCount"] as? Int, 3)
        XCTAssertEqual(data["moderationStatus"] as? String, "pending_review")
    }

    // MARK: - Helper Methods

    /// Create a test PublicRecipe with customizable fields
    private func createTestPublicRecipe(
        id: String = "test-recipe-id",
        title: String = "Test Recipe",
        description: String? = "A delicious test recipe",
        ingredients: [String] = ["ingredient1", "ingredient2"],
        creatorName: String = "Test Creator",
        creatorPhotoURL: String? = nil,
        creatorProfileSlug: String? = nil
    ) -> PublicRecipe {
        PublicRecipe(
            id: id,
            sourceRecipeId: "source-recipe-id",
            ownerId: "owner-user-id",
            title: title,
            description: description,
            imageURL: nil,
            ingredients: ingredients,
            category: nil,
            tags: [],
            servings: nil,
            prepTime: nil,
            cookTime: nil,
            creatorName: creatorName,
            creatorPhotoURL: creatorPhotoURL,
            creatorProfileSlug: creatorProfileSlug,
            viewCount: 0,
            saveCount: 0,
            searchKeywords: PublicRecipe.generateSearchKeywords(
                title: title,
                ingredients: ingredients,
                creatorName: creatorName
            ),
            isHidden: false,
            reportCount: 0,
            moderationStatus: nil,
            publishedAt: Date(),
            updatedAt: Date()
        )
    }
}
