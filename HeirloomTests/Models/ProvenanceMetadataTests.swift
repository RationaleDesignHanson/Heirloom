import XCTest
@testable import Heirloom

final class ProvenanceMetadataTests: XCTestCase {

    // MARK: - Initialization Tests

    func test_provenanceMetadata_initialization_userCreated() {
        let provenance = ProvenanceMetadata(
            sourceType: .userCreated,
            generation: 0
        )

        XCTAssertEqual(provenance.sourceType, .userCreated)
        XCTAssertEqual(provenance.generation, 0)
        XCTAssertNotNil(provenance.rootProvenanceHash)
        XCTAssertNil(provenance.parentShareID)
    }

    func test_provenanceMetadata_initialization_shared() {
        let parentHash = "parent-hash-123"
        let provenance = ProvenanceMetadata(
            sourceType: .shared,
            generation: 1,
            parentShareID: parentHash
        )

        XCTAssertEqual(provenance.sourceType, .shared)
        XCTAssertEqual(provenance.generation, 1)
        XCTAssertEqual(provenance.parentShareID, parentHash)
    }

    // MARK: - Root Provenance Hash Tests

    func test_rootProvenanceHash_uniquePerRecipe() {
        let provenance1 = ProvenanceMetadata(sourceType: .userCreated, generation: 0)
        let provenance2 = ProvenanceMetadata(sourceType: .userCreated, generation: 0)

        XCTAssertNotEqual(provenance1.rootProvenanceHash, provenance2.rootProvenanceHash)
    }

    func test_rootProvenanceHash_consistent() {
        let provenance = ProvenanceMetadata(sourceType: .userCreated, generation: 0)
        let hash1 = provenance.rootProvenanceHash
        let hash2 = provenance.rootProvenanceHash

        XCTAssertEqual(hash1, hash2)
    }

    func test_rootProvenanceHash_notEmpty() {
        let provenance = ProvenanceMetadata(sourceType: .userCreated, generation: 0)

        XCTAssertFalse(provenance.rootProvenanceHash.isEmpty)
        XCTAssertGreaterThan(provenance.rootProvenanceHash.count, 10)
    }

    // MARK: - Generation Tests

    func test_generation_zero_original() {
        let provenance = ProvenanceMetadata(sourceType: .userCreated, generation: 0)

        XCTAssertTrue(provenance.isOriginal)
        XCTAssertFalse(provenance.isShared)
    }

    func test_generation_one_firstFork() {
        let provenance = ProvenanceMetadata(sourceType: .shared, generation: 1)

        XCTAssertFalse(provenance.isOriginal)
        XCTAssertTrue(provenance.isShared)
    }

    func test_generation_multiple() {
        let provenance = ProvenanceMetadata(sourceType: .shared, generation: 5)

        XCTAssertEqual(provenance.generation, 5)
        XCTAssertTrue(provenance.isShared)
    }

    // MARK: - Generation Badge Tests

    func test_generationBadge_original() {
        let provenance = ProvenanceMetadata(sourceType: .userCreated, generation: 0)

        XCTAssertEqual(provenance.generationBadge, "Original")
    }

    func test_generationBadge_firstGen() {
        let provenance = ProvenanceMetadata(sourceType: .shared, generation: 1)

        XCTAssertEqual(provenance.generationBadge, "1st Gen")
    }

    func test_generationBadge_secondGen() {
        let provenance = ProvenanceMetadata(sourceType: .shared, generation: 2)

        XCTAssertEqual(provenance.generationBadge, "2nd Gen")
    }

    func test_generationBadge_thirdGen() {
        let provenance = ProvenanceMetadata(sourceType: .shared, generation: 3)

        XCTAssertEqual(provenance.generationBadge, "3rd Gen")
    }

    func test_generationBadge_higherGen() {
        let provenance = ProvenanceMetadata(sourceType: .shared, generation: 7)

        XCTAssertEqual(provenance.generationBadge, "7th Gen")
    }

    // MARK: - Source Type Tests

    func test_sourceType_userCreated() {
        let provenance = ProvenanceMetadata(sourceType: .userCreated, generation: 0)

        XCTAssertEqual(provenance.sourceType, .userCreated)
    }

    func test_sourceType_imported() {
        let provenance = ProvenanceMetadata(sourceType: .imported, generation: 0)

        XCTAssertEqual(provenance.sourceType, .imported)
    }

    func test_sourceType_shared() {
        let provenance = ProvenanceMetadata(sourceType: .shared, generation: 1)

        XCTAssertEqual(provenance.sourceType, .shared)
    }

    func test_sourceType_scanned() {
        let provenance = ProvenanceMetadata(sourceType: .scanned, generation: 0)

        XCTAssertEqual(provenance.sourceType, .scanned)
    }

    // MARK: - Display Format Tests

    func test_displayFormat_originalUserCreated() {
        let provenance = ProvenanceMetadata(sourceType: .userCreated, generation: 0)

        let display = provenance.displayFormat()

        XCTAssertTrue(display.contains("Original"))
    }

    func test_displayFormat_sharedFirstGen() {
        let provenance = ProvenanceMetadata(sourceType: .shared, generation: 1, parentShareID: "parent123")

        let display = provenance.displayFormat()

        XCTAssertTrue(display.contains("1st Gen"))
    }

    func test_displayFormat_withAttribution() {
        let provenance = ProvenanceMetadata(sourceType: .shared, generation: 1, attribution: "John Doe")

        let display = provenance.displayFormat()

        XCTAssertTrue(display.contains("John Doe"))
    }

    // MARK: - Share Tracking Tests

    func test_shareTracking_totalShares() {
        let provenance = ProvenanceMetadata(sourceType: .userCreated, generation: 0)
        provenance.totalShares = 5

        XCTAssertEqual(provenance.totalShares, 5)
    }

    func test_shareTracking_totalForks() {
        let provenance = ProvenanceMetadata(sourceType: .userCreated, generation: 0)
        provenance.totalForks = 3

        XCTAssertEqual(provenance.totalForks, 3)
    }

    func test_shareTracking_lastShared() {
        let provenance = ProvenanceMetadata(sourceType: .userCreated, generation: 0)
        let shareDate = Date()
        provenance.lastShared = shareDate

        XCTAssertEqual(provenance.lastShared, shareDate)
    }

    // MARK: - Parent-Child Relationship Tests

    func test_parentChild_rootHasNoParent() {
        let provenance = ProvenanceMetadata(sourceType: .userCreated, generation: 0)

        XCTAssertNil(provenance.parentShareID)
        XCTAssertTrue(provenance.isOriginal)
    }

    func test_parentChild_childHasParent() {
        let parentHash = "parent-abc-123"
        let provenance = ProvenanceMetadata(sourceType: .shared, generation: 1, parentShareID: parentHash)

        XCTAssertEqual(provenance.parentShareID, parentHash)
        XCTAssertFalse(provenance.isOriginal)
    }

    func test_parentChild_generationIncrement() {
        let provenance1 = ProvenanceMetadata(sourceType: .userCreated, generation: 0)
        let provenance2 = ProvenanceMetadata(
            sourceType: .shared,
            generation: provenance1.generation + 1,
            parentShareID: provenance1.rootProvenanceHash
        )

        XCTAssertEqual(provenance2.generation, 1)
        XCTAssertEqual(provenance2.parentShareID, provenance1.rootProvenanceHash)
    }

    // MARK: - Trending Status Tests

    func test_trendingStatus_notTrending() {
        let provenance = ProvenanceMetadata(sourceType: .userCreated, generation: 0)

        XCTAssertFalse(provenance.isTrending)
        XCTAssertEqual(provenance.trendingScore, 0.0)
    }

    func test_trendingStatus_trending() {
        let provenance = ProvenanceMetadata(sourceType: .userCreated, generation: 0)
        provenance.isTrending = true
        provenance.trendingScore = 85.5

        XCTAssertTrue(provenance.isTrending)
        XCTAssertEqual(provenance.trendingScore, 85.5)
    }

    func test_trendingStatus_lastTrendingUpdate() {
        let provenance = ProvenanceMetadata(sourceType: .userCreated, generation: 0)
        let updateDate = Date()
        provenance.lastTrendingUpdate = updateDate

        XCTAssertEqual(provenance.lastTrendingUpdate, updateDate)
    }

    // MARK: - Attribution Tests

    func test_attribution_withAuthor() {
        let provenance = ProvenanceMetadata(
            sourceType: .shared,
            generation: 1,
            attribution: "Jane Smith"
        )

        XCTAssertEqual(provenance.attribution, "Jane Smith")
    }

    func test_attribution_withoutAuthor() {
        let provenance = ProvenanceMetadata(sourceType: .userCreated, generation: 0)

        XCTAssertNil(provenance.attribution)
    }

    // MARK: - Lineage Tree Tests

    func test_lineageTree_buildSimpleChain() {
        // Generation 0 (root)
        let gen0 = ProvenanceMetadata(sourceType: .userCreated, generation: 0)

        // Generation 1 (fork from gen0)
        let gen1 = ProvenanceMetadata(
            sourceType: .shared,
            generation: 1,
            parentShareID: gen0.rootProvenanceHash
        )

        // Generation 2 (fork from gen1)
        let gen2 = ProvenanceMetadata(
            sourceType: .shared,
            generation: 2,
            parentShareID: gen1.rootProvenanceHash
        )

        XCTAssertEqual(gen0.generation, 0)
        XCTAssertEqual(gen1.generation, 1)
        XCTAssertEqual(gen2.generation, 2)

        XCTAssertEqual(gen1.parentShareID, gen0.rootProvenanceHash)
        XCTAssertEqual(gen2.parentShareID, gen1.rootProvenanceHash)
    }

    // MARK: - Metadata Persistence Tests

    func test_metadata_encoding() throws {
        let provenance = ProvenanceMetadata(
            sourceType: .shared,
            generation: 2,
            parentShareID: "parent123",
            attribution: "Test Author"
        )

        // Should be encodable
        let encoder = JSONEncoder()
        let data = try encoder.encode(provenance)

        XCTAssertGreaterThan(data.count, 0)
    }

    func test_metadata_decoding() throws {
        let provenance = ProvenanceMetadata(
            sourceType: .shared,
            generation: 2,
            parentShareID: "parent123",
            attribution: "Test Author"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(provenance)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ProvenanceMetadata.self, from: data)

        XCTAssertEqual(decoded.sourceType, provenance.sourceType)
        XCTAssertEqual(decoded.generation, provenance.generation)
        XCTAssertEqual(decoded.parentShareID, provenance.parentShareID)
        XCTAssertEqual(decoded.attribution, provenance.attribution)
    }

    // MARK: - Edge Cases

    func test_edgeCase_negativeGeneration() {
        // Generation should never be negative, but handle gracefully
        let provenance = ProvenanceMetadata(sourceType: .userCreated, generation: -1)

        // Should still create, but generation badge might be odd
        XCTAssertEqual(provenance.generation, -1)
    }

    func test_edgeCase_largeGeneration() {
        // Test very deep lineage
        let provenance = ProvenanceMetadata(sourceType: .shared, generation: 100)

        XCTAssertEqual(provenance.generation, 100)
        XCTAssertEqual(provenance.generationBadge, "100th Gen")
    }

    func test_edgeCase_emptyParentHash() {
        let provenance = ProvenanceMetadata(sourceType: .shared, generation: 1, parentShareID: "")

        XCTAssertNotNil(provenance.parentShareID)
        XCTAssertEqual(provenance.parentShareID, "")
    }
}
