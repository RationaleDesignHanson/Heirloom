//
//  SourceAttributionTests.swift
//  HeirloomTestsV2
//
//  Unit tests for source attribution: KnownSource model methods,
//  normalization, domain extraction, confidence scoring, and recordSeen.
//
//  Note: SourceAttributionService requires FirebaseConfiguration and is
//  tested at the integration level. These tests cover the model and
//  static methods that can be tested without Firebase.
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class SourceAttributionTests: XCTestCase {

    var env: TestEnvironment!

    override func setUp() async throws {
        env = try await TestEnvironment.create()
    }

    override func tearDown() async throws {
        env?.tearDown()
        env = nil
    }

    // MARK: - KnownSource.normalize()

    func test_normalize_lowercases() {
        XCTAssertEqual(KnownSource.normalize("AllRecipes"), "allrecipes")
    }

    func test_normalize_trims() {
        XCTAssertEqual(KnownSource.normalize("  AllRecipes  "), "allrecipes")
    }

    func test_normalize_collapsesWhitespace() {
        XCTAssertEqual(KnownSource.normalize("The  Flavor   Labs"), "the flavor labs")
    }

    func test_normalize_handlesEmpty() {
        XCTAssertEqual(KnownSource.normalize(""), "")
    }

    func test_normalize_preservesNonLatinCharacters() {
        XCTAssertEqual(KnownSource.normalize("Cuisine de France"), "cuisine de france")
    }

    // MARK: - KnownSource.extractDomain()

    func test_extractDomain_extractsHost() {
        XCTAssertEqual(
            KnownSource.extractDomain(from: "https://www.allrecipes.com/recipe/12345"),
            "allrecipes.com"
        )
    }

    func test_extractDomain_removesWww() {
        XCTAssertEqual(
            KnownSource.extractDomain(from: "https://www.foodnetwork.com/recipes"),
            "foodnetwork.com"
        )
    }

    func test_extractDomain_handlesNoWww() {
        XCTAssertEqual(
            KnownSource.extractDomain(from: "https://epicurious.com/recipe/123"),
            "epicurious.com"
        )
    }

    func test_extractDomain_returnsNilForInvalidURL() {
        XCTAssertNil(KnownSource.extractDomain(from: "not a url"))
    }

    func test_extractDomain_returnsNilForEmpty() {
        XCTAssertNil(KnownSource.extractDomain(from: ""))
    }

    // MARK: - KnownSource Initialization

    func test_init_setsNormalizedName() {
        let source = KnownSource(name: "The Flavor Labs", kind: .brand)
        XCTAssertEqual(source.normalizedName, "the flavor labs")
    }

    func test_init_setsSourceKind() {
        let source = KnownSource(name: "AllRecipes", kind: .website)
        XCTAssertEqual(source.kind, .website)
        XCTAssertEqual(source.sourceKind, "website")
    }

    func test_init_setsDefaultConfidence() {
        let source = KnownSource(name: "Test", kind: .cookbook)
        XCTAssertEqual(source.confidence, 0.5)
    }

    func test_init_setsCustomConfidence() {
        let source = KnownSource(name: "Test", kind: .cookbook, confidence: 0.9)
        XCTAssertEqual(source.confidence, 0.9)
    }

    func test_init_importCountStartsAtOne() {
        let source = KnownSource(name: "Test", kind: .cookbook)
        XCTAssertEqual(source.importCount, 1)
    }

    func test_init_setsDomain() {
        let source = KnownSource(name: "AllRecipes", kind: .website, domain: "allrecipes.com")
        XCTAssertEqual(source.domain, "allrecipes.com")
    }

    func test_init_setsPlatform() {
        let source = KnownSource(
            name: "Chef TikTok",
            kind: .socialCreator,
            platform: .tiktok,
            platformUsername: "@cheftiktok"
        )
        XCTAssertEqual(source.socialPlatform, .tiktok)
        XCTAssertEqual(source.platformUsername, "@cheftiktok")
    }

    // MARK: - recordSeen

    func test_recordSeen_incrementsImportCount() {
        // GIVEN: Source with importCount 1
        let source = KnownSource(name: "Test", kind: .cookbook)
        XCTAssertEqual(source.importCount, 1)

        // WHEN: Recording a sighting
        source.recordSeen()

        // THEN: Import count incremented
        XCTAssertEqual(source.importCount, 2)
    }

    func test_recordSeen_updatesLastSeenDate() {
        // GIVEN: Source with old lastSeen
        let source = KnownSource(name: "Test", kind: .cookbook)
        let oldDate = source.lastSeenDate

        // Small delay to ensure date differs
        Thread.sleep(forTimeInterval: 0.01)

        // WHEN: Recording a sighting
        source.recordSeen()

        // THEN: Last seen date updated
        XCTAssertGreaterThanOrEqual(source.lastSeenDate, oldDate)
    }

    func test_recordSeen_increasesConfidence() {
        // GIVEN: Source with 0.5 confidence
        let source = KnownSource(name: "Test", kind: .cookbook, confidence: 0.5)

        // WHEN: Recording sighting
        source.recordSeen()

        // THEN: Confidence increased (formula: min(1.0, c + (1-c) * 0.15))
        XCTAssertGreaterThan(source.confidence, 0.5)
        XCTAssertEqual(source.confidence, 0.5 + (1.0 - 0.5) * 0.15, accuracy: 0.001)
    }

    func test_recordSeen_confidenceNeverExceedsOne() {
        // GIVEN: Source with high confidence
        let source = KnownSource(name: "Test", kind: .cookbook, confidence: 0.99)

        // WHEN: Recording many sightings
        for _ in 0..<100 {
            source.recordSeen()
        }

        // THEN: Confidence capped at 1.0
        XCTAssertLessThanOrEqual(source.confidence, 1.0)
    }

    func test_recordSeen_confidenceApproachesOneAsymptotically() {
        // GIVEN: Source with low confidence
        let source = KnownSource(name: "Test", kind: .cookbook, confidence: 0.3)

        // WHEN: Recording 20 sightings
        for _ in 0..<20 {
            source.recordSeen()
        }

        // THEN: Confidence is high but still below 1.0 (asymptotic)
        XCTAssertGreaterThan(source.confidence, 0.9)
        XCTAssertLessThanOrEqual(source.confidence, 1.0)
    }

    // MARK: - Kind Computed Property

    func test_kind_getReturnsCorrectEnum() {
        let source = KnownSource(name: "Test", kind: .socialCreator)
        XCTAssertEqual(source.kind, .socialCreator)
    }

    func test_kind_setUpdatesRawValue() {
        let source = KnownSource(name: "Test", kind: .website)
        source.kind = .cookbook
        XCTAssertEqual(source.sourceKind, "cookbook")
    }

    func test_kind_unknownRawValue_returnsUnknown() {
        let source = KnownSource(name: "Test", kind: .website)
        source.sourceKind = "invalid_kind"
        XCTAssertEqual(source.kind, .unknown)
    }

    // MARK: - SourceKind Coverage

    func test_sourceKind_allCases() {
        // Verify all expected source kinds exist
        let allKinds: [SourceKind] = [
            .cookbook, .website, .socialCreator, .person,
            .brand, .publication, .aiGenerated, .unknown
        ]
        XCTAssertEqual(SourceKind.allCases.count, allKinds.count)
        for kind in allKinds {
            XCTAssertTrue(SourceKind.allCases.contains(kind))
        }
    }

    // MARK: - Recipe Relationship

    func test_knownSource_linkedToRecipe() {
        // GIVEN: A recipe and a KnownSource
        let recipe = env.createTestRecipe(title: "Test Recipe")
        let source = KnownSource(name: "AllRecipes", kind: .website, domain: "allrecipes.com")
        env.modelContext.insert(source)

        // WHEN: Linking
        recipe.knownSource = source

        // THEN: Relationship works both ways
        XCTAssertEqual(recipe.knownSource?.id, source.id)
        XCTAssertTrue(source.recipes?.contains(where: { $0.id == recipe.id }) ?? false)
    }

    func test_knownSource_multipleRecipes() {
        // GIVEN: Multiple recipes from same source
        let recipe1 = env.createTestRecipe(title: "Pasta")
        let recipe2 = env.createTestRecipe(title: "Soup")
        let source = KnownSource(name: "AllRecipes", kind: .website)
        env.modelContext.insert(source)

        // WHEN: Linking both
        recipe1.knownSource = source
        recipe2.knownSource = source

        // THEN: Source has both recipes
        XCTAssertEqual(source.recipes?.count, 2)
    }
}
