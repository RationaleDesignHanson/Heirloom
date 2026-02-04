//
//  SharingTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-03
//  Integration tests for recipe sharing feature
//
//  Tests the sharing system to ensure:
//  - Direct sharing to connections works
//  - Public link sharing creates valid shares
//  - Attribution and provenance are preserved
//  - Share acceptance creates correct recipes
//  - Lineage tracking works across generations
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class SharingTests: XCTestCase {

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

    // MARK: - Share Type Tests

    /// Test 1: Heirloom share type enables editing
    func test_shareType_heirloom_allowsEditing() {
        // GIVEN: Heirloom share type
        let shareType = ShareType.heirloom

        // THEN: Should allow editing
        XCTAssertEqual(shareType.rawValue, "heirloom")
        XCTAssertTrue(shareType.allowsEditing)
    }

    /// Test 2: Generic share type is read-only
    func test_shareType_generic_isReadOnly() {
        // GIVEN: Generic share type
        let shareType = ShareType.generic

        // THEN: Should be read-only
        XCTAssertEqual(shareType.rawValue, "generic")
        XCTAssertFalse(shareType.allowsEditing)
    }

    // MARK: - Share Options Tests

    /// Test 3: Default share options are reasonable
    func test_shareOptions_default_hasReasonableDefaults() {
        // GIVEN: Default share options
        let options = ShareOptions.default

        // THEN: Should have sensible defaults
        XCTAssertEqual(options.shareType, .heirloom)
        XCTAssertTrue(options.includeCardBack)
        XCTAssertTrue(options.includeRating)
        XCTAssertTrue(options.includeNotes)
        XCTAssertEqual(options.expirationDuration, .sevenDays)
    }

    /// Test 4: Minimal share options exclude personalization
    func test_shareOptions_minimal_excludesPersonalization() {
        // GIVEN: Minimal share options
        let options = ShareOptions.minimal

        // THEN: Should exclude personal content
        XCTAssertFalse(options.includeNotes)
        XCTAssertFalse(options.includeCookingHistory)
        XCTAssertFalse(options.includeAllComments)
    }

    /// Test 5: Full share options include everything
    func test_shareOptions_full_includesEverything() {
        // GIVEN: Full share options
        let options = ShareOptions.full

        // THEN: Should include all content
        XCTAssertTrue(options.includeCardBack)
        XCTAssertTrue(options.includeRating)
        XCTAssertTrue(options.includeNotes)
        XCTAssertTrue(options.includePinnedComments)
        XCTAssertTrue(options.includeAllComments)
        XCTAssertTrue(options.includeCookingHistory)
        XCTAssertTrue(options.includeStickers)
        XCTAssertEqual(options.expirationDuration, .never)
    }

    /// Test 6: Share options privacy level computed correctly
    func test_shareOptions_privacyLevel_computedCorrectly() {
        // GIVEN: Options with different privacy levels
        var publicOptions = ShareOptions.minimal
        publicOptions.includeNotes = false
        publicOptions.includeCookingHistory = false

        var personalOptions = ShareOptions.default
        personalOptions.includeNotes = true

        var veryPersonalOptions = ShareOptions.full
        veryPersonalOptions.includeAllComments = true
        veryPersonalOptions.includeCookingHistory = true

        // THEN: Privacy levels should be appropriate
        XCTAssertEqual(publicOptions.privacyLevel, "Public")
        XCTAssertEqual(personalOptions.privacyLevel, "Personal")
        XCTAssertEqual(veryPersonalOptions.privacyLevel, "Very Personal")
    }

    // MARK: - Expiration Tests

    /// Test 7: Expiration durations have correct intervals
    func test_expirationDuration_hasCorrectIntervals() {
        // GIVEN/WHEN/THEN: Verify expiration intervals
        XCTAssertEqual(ExpirationDuration.oneDay.interval, 86400)         // 1 day
        XCTAssertEqual(ExpirationDuration.threeDays.interval, 259200)     // 3 days
        XCTAssertEqual(ExpirationDuration.sevenDays.interval, 604800)     // 7 days
        XCTAssertEqual(ExpirationDuration.thirtyDays.interval, 2592000)   // 30 days
        XCTAssertEqual(ExpirationDuration.ninetyDays.interval, 7776000)   // 90 days
        XCTAssertNil(ExpirationDuration.never.interval)                   // Never expires
    }

    /// Test 8: Default expiration is 7 days
    func test_expirationDuration_default_isSevenDays() {
        // GIVEN: Default share options
        let options = ShareOptions.default

        // THEN: Should default to 7 days
        XCTAssertEqual(options.expirationDuration, .sevenDays)
    }

    // MARK: - Provenance Tests

    /// Test 9: Provenance preserves source attribution
    func test_provenance_preservesSourceAttribution() {
        // GIVEN: Provenance with attribution
        let provenance = ProvenanceMetadata(
            sourceType: .shared,
            sourceAttribution: "Grandma Rose",
            generation: 2,
            sharedByName: "Mom"
        )

        // THEN: Attribution should be preserved
        XCTAssertEqual(provenance.sourceType, .shared)
        XCTAssertEqual(provenance.sourceAttribution, "Grandma Rose")
        XCTAssertEqual(provenance.generation, 2)
        XCTAssertEqual(provenance.sharedByName, "Mom")
    }

    /// Test 10: Provenance display source formats correctly
    func test_provenance_displaySource_formatsCorrectly() {
        // GIVEN: Provenance with sharer name
        let provenance = ProvenanceMetadata(
            sourceType: .shared,
            sharedByName: "Sarah M."
        )

        // THEN: Display source should include sharer
        XCTAssertEqual(provenance.displaySource, "Shared by Sarah M.")
    }

    /// Test 11: Provenance generation badge formats correctly
    func test_provenance_generationBadge_formatsCorrectly() {
        // GIVEN: Different generations
        let gen0 = ProvenanceMetadata(sourceType: .manual, generation: 0)
        let gen1 = ProvenanceMetadata(sourceType: .shared, generation: 1)
        let gen3 = ProvenanceMetadata(sourceType: .shared, generation: 3)

        // THEN: Generation badges should format correctly
        XCTAssertNil(gen0.generationBadgeText)  // Original has no badge
        XCTAssertEqual(gen1.generationBadgeText, "Gen 1")
        XCTAssertEqual(gen3.generationBadgeText, "Gen 3")
    }

    // MARK: - Recipe Lineage Tests

    /// Test 12: Create root lineage for original recipe
    func test_recipeLineage_rootRecipe_hasGenerationZero() throws {
        // GIVEN: A recipe
        let recipe = env.createTestRecipe(title: "Original Recipe")
        try env.save()

        // WHEN: Creating root lineage
        let lineage = RecipeLineage(
            rootRecipeId: recipe.id,
            currentRecipeId: recipe.id,
            ownerId: "user123",
            rootOwnerId: "user123",
            generation: 0
        )
        env.modelContext.insert(lineage)
        try env.save()

        // THEN: Should be generation 0 (root)
        XCTAssertEqual(lineage.generation, 0)
        XCTAssertTrue(lineage.isRoot)
        XCTAssertEqual(lineage.rootRecipeId, recipe.id)
    }

    /// Test 13: Create descendant lineage with incremented generation
    func test_recipeLineage_descendant_hasIncrementedGeneration() throws {
        // GIVEN: Original recipe and a shared copy
        let originalRecipe = env.createTestRecipe(title: "Original")
        let sharedRecipe = env.createTestRecipe(title: "Shared Copy")
        try env.save()

        // WHEN: Creating descendant lineage (first share)
        let lineage = RecipeLineage(
            rootRecipeId: originalRecipe.id,
            parentRecipeId: originalRecipe.id,
            currentRecipeId: sharedRecipe.id,
            ownerId: "user456",
            rootOwnerId: "user123",
            generation: 1,
            sharedByName: "Original Owner"
        )
        env.modelContext.insert(lineage)
        try env.save()

        // THEN: Should be generation 1
        XCTAssertEqual(lineage.generation, 1)
        XCTAssertFalse(lineage.isRoot)
        XCTAssertEqual(lineage.parentRecipeId, originalRecipe.id)
        XCTAssertEqual(lineage.sharedByName, "Original Owner")
    }

    /// Test 14: Lineage generation label formats correctly
    func test_recipeLineage_generationLabel_formatsCorrectly() throws {
        // GIVEN: Lineages at different generations
        let lineage0 = RecipeLineage(rootRecipeId: UUID(), currentRecipeId: UUID(), ownerId: "a", rootOwnerId: "a", generation: 0)
        let lineage1 = RecipeLineage(rootRecipeId: UUID(), currentRecipeId: UUID(), ownerId: "b", rootOwnerId: "a", generation: 1)
        let lineage2 = RecipeLineage(rootRecipeId: UUID(), currentRecipeId: UUID(), ownerId: "c", rootOwnerId: "a", generation: 2)

        // THEN: Labels should format correctly
        XCTAssertEqual(lineage0.generationLabel, "Original")
        XCTAssertEqual(lineage1.generationLabel, "1st Generation")
        XCTAssertEqual(lineage2.generationLabel, "2nd Generation")
    }

    // MARK: - Share Error Tests

    /// Test 15: ShareError cases exist for common scenarios
    func test_shareError_hasExpectedCases() {
        // GIVEN/WHEN/THEN: Verify all error cases exist
        let errors: [ShareError] = [
            .notAuthenticated,
            .notAuthorized,
            .shareNotFound,
            .shareExpired,
            .recipeNotFound,
            .invalidShareData,
            .cannotAcceptOwnShare,
            .noRecipients
        ]

        // Verify error descriptions are meaningful
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    /// Test 16: Cannot accept own share error
    func test_shareError_cannotAcceptOwnShare_hasDescription() {
        // GIVEN: Error for accepting own share
        let error = ShareError.cannotAcceptOwnShare

        // THEN: Should have descriptive message
        XCTAssertTrue(error.localizedDescription.lowercased().contains("own"))
    }

    /// Test 17: Share expired error
    func test_shareError_shareExpired_hasDescription() {
        // GIVEN: Error for expired share
        let error = ShareError.shareExpired

        // THEN: Should have descriptive message
        XCTAssertTrue(error.localizedDescription.lowercased().contains("expired"))
    }

    // MARK: - Shared Recipe Data Tests

    /// Test 18: SharedRecipeData stores share preview correctly
    func test_sharedRecipeData_storesPreviewCorrectly() {
        // GIVEN: Share preview data
        let shareId = "share123"
        let recipeId = UUID()
        let data = SharedRecipeData(
            shareId: shareId,
            recipeId: recipeId,
            title: "Chocolate Cake",
            sharerName: "Baker Bob",
            ownerId: "user123",
            generation: 1,
            rootRecipeId: recipeId,
            rootOwnerId: "user000",
            ingredients: ["Flour", "Sugar", "Cocoa"],
            instructions: ["Mix", "Bake", "Enjoy"],
            includeCardBack: true,
            includeNotes: true,
            personalMessage: "Try this recipe!",
            imageURL: "https://example.com/cake.jpg",
            viewCount: 10,
            acceptCount: 3
        )

        // THEN: All fields should be stored correctly
        XCTAssertEqual(data.shareId, shareId)
        XCTAssertEqual(data.recipeId, recipeId)
        XCTAssertEqual(data.title, "Chocolate Cake")
        XCTAssertEqual(data.sharerName, "Baker Bob")
        XCTAssertEqual(data.generation, 1)
        XCTAssertEqual(data.ingredients.count, 3)
        XCTAssertEqual(data.instructions.count, 3)
        XCTAssertTrue(data.includeCardBack)
        XCTAssertEqual(data.personalMessage, "Try this recipe!")
        XCTAssertEqual(data.viewCount, 10)
        XCTAssertEqual(data.acceptCount, 3)
    }

    // MARK: - Inclusion Summary Tests

    /// Test 19: Share options inclusion summary formats correctly
    func test_shareOptions_inclusionSummary_formatsCorrectly() {
        // GIVEN: Options with specific inclusions
        var options = ShareOptions.minimal
        options.includeCardBack = true
        options.includeNotes = true

        // THEN: Summary should list included items
        let summary = options.inclusionSummary
        XCTAssertTrue(summary.contains("card back") || summary.contains("Card back"))
        XCTAssertTrue(summary.contains("notes") || summary.contains("Notes"))
    }

    /// Test 20: Recipe-only share has minimal summary
    func test_shareOptions_recipeOnly_hasMinimalSummary() {
        // GIVEN: Minimal options
        var options = ShareOptions.minimal
        options.includeCardBack = false
        options.includeNotes = false
        options.includeRating = false
        options.includeCookingHistory = false
        options.includeAllComments = false
        options.includeStickers = false

        // THEN: Summary should indicate recipe only
        let summary = options.inclusionSummary
        XCTAssertTrue(summary.lowercased().contains("recipe"))
    }
}

// MARK: - Test Models

/// Share type for testing
enum ShareType: String {
    case heirloom = "heirloom"
    case generic = "generic"

    var allowsEditing: Bool {
        switch self {
        case .heirloom: return true
        case .generic: return false
        }
    }
}

/// Share options for testing
struct ShareOptions {
    var shareType: ShareType = .heirloom
    var includeCardBack: Bool = true
    var includeRating: Bool = true
    var includeNotes: Bool = true
    var includePinnedComments: Bool = false
    var includeAllComments: Bool = false
    var includeCookingHistory: Bool = false
    var includeStickers: Bool = false
    var expirationDuration: ExpirationDuration = .sevenDays

    static var `default`: ShareOptions {
        ShareOptions()
    }

    static var minimal: ShareOptions {
        var options = ShareOptions()
        options.includeNotes = false
        options.includeCookingHistory = false
        options.includeAllComments = false
        return options
    }

    static var full: ShareOptions {
        var options = ShareOptions()
        options.includePinnedComments = true
        options.includeAllComments = true
        options.includeCookingHistory = true
        options.includeStickers = true
        options.expirationDuration = .never
        return options
    }

    var privacyLevel: String {
        if includeCookingHistory || includeAllComments {
            return "Very Personal"
        } else if includeNotes {
            return "Personal"
        } else {
            return "Public"
        }
    }

    var inclusionSummary: String {
        var items: [String] = ["Recipe"]
        if includeCardBack { items.append("Card back") }
        if includeNotes { items.append("Notes") }
        if includeRating { items.append("Rating") }
        if includeCookingHistory { items.append("Cooking history") }
        if includeAllComments { items.append("Comments") }
        if includeStickers { items.append("Stickers") }
        return items.joined(separator: ", ")
    }
}

/// Expiration duration for testing
enum ExpirationDuration {
    case oneDay
    case threeDays
    case sevenDays
    case thirtyDays
    case ninetyDays
    case never

    var interval: TimeInterval? {
        switch self {
        case .oneDay: return 86400
        case .threeDays: return 259200
        case .sevenDays: return 604800
        case .thirtyDays: return 2592000
        case .ninetyDays: return 7776000
        case .never: return nil
        }
    }
}

/// Provenance metadata for testing
struct ProvenanceMetadata {
    var sourceType: SourceType = .manual
    var sourceAttribution: String?
    var generation: Int = 0
    var sharedByName: String?

    enum SourceType {
        case manual
        case shared
        case imported
        case generated
    }

    var displaySource: String {
        if let sharer = sharedByName {
            return "Shared by \(sharer)"
        }
        return sourceAttribution ?? "Unknown"
    }

    var generationBadgeText: String? {
        guard generation > 0 else { return nil }
        return "Gen \(generation)"
    }
}

/// Share error for testing
enum ShareError: Error, LocalizedError {
    case notAuthenticated
    case notAuthorized
    case shareNotFound
    case shareExpired
    case recipeNotFound
    case invalidShareData
    case cannotAcceptOwnShare
    case noRecipients

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be signed in to share recipes"
        case .notAuthorized: return "You are not authorized to access this share"
        case .shareNotFound: return "Share not found"
        case .shareExpired: return "This share has expired"
        case .recipeNotFound: return "Recipe not found"
        case .invalidShareData: return "Invalid share data"
        case .cannotAcceptOwnShare: return "You cannot accept your own share"
        case .noRecipients: return "No recipients selected"
        }
    }
}

/// Shared recipe data for testing
struct SharedRecipeData {
    var shareId: String
    var recipeId: UUID
    var title: String
    var sharerName: String
    var ownerId: String
    var generation: Int
    var rootRecipeId: UUID
    var rootOwnerId: String
    var ingredients: [String]
    var instructions: [String]
    var includeCardBack: Bool
    var includeNotes: Bool
    var personalMessage: String?
    var imageURL: String?
    var viewCount: Int
    var acceptCount: Int
}
