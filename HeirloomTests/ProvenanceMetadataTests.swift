import XCTest
import CryptoKit
@testable import Heirloom

/// Unit tests for ProvenanceMetadata and lineage tracking
final class ProvenanceMetadataTests: XCTestCase {

    // MARK: - Initialization Tests

    func testProvenanceMetadataDefaultInit() throws {
        let provenance = ProvenanceMetadata(sourceType: .userCreated)

        XCTAssertEqual(provenance.sourceType, .userCreated)
        XCTAssertNotNil(provenance.rootProvenanceHash, "Should auto-generate hash")
        XCTAssertEqual(provenance.generation, 0)
        XCTAssertNil(provenance.parentShareID)
        XCTAssertNil(provenance.sharedByName)
        XCTAssertEqual(provenance.cachedMetrics.totalShares, 0)
    }

    func testProvenanceMetadataFullInit() throws {
        let customHash = "custom-hash-12345"
        let metrics = AggregatedMetrics(
            totalShares: 10,
            totalCooks: 25,
            averageRating: 4.5,
            ratingCount: 8
        )

        let provenance = ProvenanceMetadata(
            sourceType: .shared,
            sourceURL: "https://example.com/recipe",
            sourceAttribution: "Example.com",
            rootProvenanceHash: customHash,
            generation: 2,
            parentShareID: "parent-123",
            sharedByName: "Alice",
            cloudKitRecordID: "record-456",
            cachedMetrics: metrics
        )

        XCTAssertEqual(provenance.sourceType, .shared)
        XCTAssertEqual(provenance.sourceURL, "https://example.com/recipe")
        XCTAssertEqual(provenance.sourceAttribution, "Example.com")
        XCTAssertEqual(provenance.rootProvenanceHash, customHash)
        XCTAssertEqual(provenance.generation, 2)
        XCTAssertEqual(provenance.parentShareID, "parent-123")
        XCTAssertEqual(provenance.sharedByName, "Alice")
        XCTAssertEqual(provenance.cloudKitRecordID, "record-456")
        XCTAssertEqual(provenance.cachedMetrics.totalShares, 10)
    }

    // MARK: - Hash Generation Tests

    func testProvenanceHashUniqueness() throws {
        let provenance1 = ProvenanceMetadata(sourceType: .userCreated)
        let provenance2 = ProvenanceMetadata(sourceType: .userCreated)

        XCTAssertNotEqual(provenance1.rootProvenanceHash, provenance2.rootProvenanceHash,
                         "Each provenance should generate a unique hash")
    }

    func testProvenanceHashFormat() throws {
        let provenance = ProvenanceMetadata(sourceType: .userCreated)

        // SHA256 hash should be 64 characters (hex)
        XCTAssertEqual(provenance.rootProvenanceHash.count, 64)

        // Should only contain hex characters
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdef")
        let hashCharacters = CharacterSet(charactersIn: provenance.rootProvenanceHash)
        XCTAssertTrue(hexCharacterSet.isSuperset(of: hashCharacters))
    }

    func testCustomHashPreserved() throws {
        let customHash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        let provenance = ProvenanceMetadata(
            sourceType: .userCreated,
            rootProvenanceHash: customHash
        )

        XCTAssertEqual(provenance.rootProvenanceHash, customHash,
                      "Custom hash should be preserved, not regenerated")
    }

    func testRootProvenanceHashPropagation() throws {
        // Original recipe
        let original = ProvenanceMetadata(sourceType: .userCreated, generation: 0)
        let originalHash = original.rootProvenanceHash

        // First share (should preserve same root hash)
        let firstShare = ProvenanceMetadata(
            sourceType: .shared,
            rootProvenanceHash: originalHash,
            generation: 1,
            sharedByName: "Alice"
        )

        // Second generation share (should still have same root hash)
        let secondShare = ProvenanceMetadata(
            sourceType: .shared,
            rootProvenanceHash: originalHash,
            generation: 2,
            sharedByName: "Bob"
        )

        XCTAssertEqual(original.rootProvenanceHash, originalHash)
        XCTAssertEqual(firstShare.rootProvenanceHash, originalHash)
        XCTAssertEqual(secondShare.rootProvenanceHash, originalHash)
    }

    // MARK: - Generation Tracking Tests

    func testIsOriginal() throws {
        let original = ProvenanceMetadata(sourceType: .userCreated, generation: 0)
        XCTAssertTrue(original.isOriginal)
        XCTAssertFalse(original.isShared)
    }

    func testIsShared() throws {
        let shared1 = ProvenanceMetadata(sourceType: .shared, generation: 1, sharedByName: "Alice")
        let shared2 = ProvenanceMetadata(sourceType: .shared, generation: 2, sharedByName: "Bob")

        XCTAssertFalse(shared1.isOriginal)
        XCTAssertTrue(shared1.isShared)

        XCTAssertFalse(shared2.isOriginal)
        XCTAssertTrue(shared2.isShared)
    }

    func testGenerationBadgeText() throws {
        let gen0 = ProvenanceMetadata(sourceType: .userCreated, generation: 0)
        XCTAssertNil(gen0.generationBadgeText, "Original should not have badge")

        let gen1 = ProvenanceMetadata(sourceType: .shared, generation: 1, sharedByName: "Alice")
        XCTAssertEqual(gen1.generationBadgeText, "Gen 1")

        let gen3 = ProvenanceMetadata(sourceType: .shared, generation: 3, sharedByName: "Charlie")
        XCTAssertEqual(gen3.generationBadgeText, "Gen 3")
    }

    // MARK: - Display Logic Tests

    func testDisplaySourceUserCreated() throws {
        let provenance = ProvenanceMetadata(sourceType: .userCreated)
        XCTAssertEqual(provenance.displaySource, "My Recipe")
    }

    func testDisplaySourceImported() throws {
        let provenance = ProvenanceMetadata(
            sourceType: .imported,
            sourceURL: "https://www.allrecipes.com/recipe/12345"
        )
        XCTAssertEqual(provenance.displaySource, "Allrecipes.com")
    }

    func testDisplaySourceImportedWithAttribution() throws {
        let provenance = ProvenanceMetadata(
            sourceType: .imported,
            sourceURL: "https://www.allrecipes.com/recipe/12345",
            sourceAttribution: "From AllRecipes"
        )
        XCTAssertEqual(provenance.displaySource, "From AllRecipes")
    }

    func testDisplaySourceShared() throws {
        let provenance = ProvenanceMetadata(
            sourceType: .shared,
            generation: 1,
            sharedByName: "Sarah M."
        )
        XCTAssertEqual(provenance.displaySource, "Shared by Sarah M.")
    }

    func testDisplaySourceScanned() throws {
        let provenance = ProvenanceMetadata(sourceType: .scanned)
        XCTAssertEqual(provenance.displaySource, "Scanned")
    }

    func testDisplaySourceAI() throws {
        let provenance = ProvenanceMetadata(sourceType: .ai)
        XCTAssertEqual(provenance.displaySource, "AI Generated")
    }

    // MARK: - Source Type Tests

    func testSourceTypeDisplayNames() throws {
        XCTAssertEqual(ProvenanceMetadata.SourceType.userCreated.displayName, "User Created")
        XCTAssertEqual(ProvenanceMetadata.SourceType.imported.displayName, "Imported")
        XCTAssertEqual(ProvenanceMetadata.SourceType.shared.displayName, "Shared")
        XCTAssertEqual(ProvenanceMetadata.SourceType.scanned.displayName, "Scanned")
        XCTAssertEqual(ProvenanceMetadata.SourceType.ai.displayName, "AI Generated")
    }

    func testSourceTypeIconNames() throws {
        XCTAssertEqual(ProvenanceMetadata.SourceType.userCreated.iconName, "pencil.circle.fill")
        XCTAssertEqual(ProvenanceMetadata.SourceType.imported.iconName, "arrow.down.circle.fill")
        XCTAssertEqual(ProvenanceMetadata.SourceType.shared.iconName, "person.2.fill")
        XCTAssertEqual(ProvenanceMetadata.SourceType.scanned.iconName, "doc.text.viewfinder")
        XCTAssertEqual(ProvenanceMetadata.SourceType.ai.iconName, "sparkles")
    }

    func testSourceTypeCodable() throws {
        let provenance = ProvenanceMetadata(sourceType: .imported, sourceURL: "https://example.com")

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(provenance)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ProvenanceMetadata.self, from: data)

        XCTAssertEqual(decoded.sourceType, .imported)
        XCTAssertEqual(decoded.sourceURL, "https://example.com")
    }

    // MARK: - Aggregated Metrics Tests

    func testAggregatedMetricsDefault() throws {
        let metrics = AggregatedMetrics()

        XCTAssertEqual(metrics.totalShares, 0)
        XCTAssertEqual(metrics.totalCooks, 0)
        XCTAssertNil(metrics.averageRating)
        XCTAssertEqual(metrics.ratingCount, 0)
        XCTAssertEqual(metrics.commentCount, 0)
        XCTAssertEqual(metrics.trendingScore, 0.0)
        XCTAssertNil(metrics.lastUpdated)
    }

    func testAggregatedMetricsIsTrending() throws {
        var metrics = AggregatedMetrics()
        XCTAssertFalse(metrics.isTrending, "Default should not be trending")

        // High score but low shares
        metrics.trendingScore = 15.0
        metrics.totalShares = 3
        XCTAssertFalse(metrics.isTrending, "Need >5 shares to trend")

        // High shares but low score
        metrics.trendingScore = 5.0
        metrics.totalShares = 10
        XCTAssertFalse(metrics.isTrending, "Need >10.0 score to trend")

        // Both high
        metrics.trendingScore = 15.0
        metrics.totalShares = 10
        XCTAssertTrue(metrics.isTrending, "Should be trending")
    }

    func testAggregatedMetricsDisplayShareCount() throws {
        var metrics = AggregatedMetrics()

        metrics.totalShares = 0
        XCTAssertEqual(metrics.displayShareCount, "")

        metrics.totalShares = 1
        XCTAssertEqual(metrics.displayShareCount, "1 share")

        metrics.totalShares = 42
        XCTAssertEqual(metrics.displayShareCount, "42 shares")

        metrics.totalShares = 100
        XCTAssertEqual(metrics.displayShareCount, "100+ shares")

        metrics.totalShares = 500
        XCTAssertEqual(metrics.displayShareCount, "100+ shares")
    }

    func testAggregatedMetricsCodable() throws {
        let metrics = AggregatedMetrics(
            totalShares: 15,
            totalCooks: 42,
            averageRating: 4.5,
            ratingCount: 12,
            commentCount: 8,
            trendingScore: 18.5,
            lastUpdated: Date()
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(metrics)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AggregatedMetrics.self, from: data)

        XCTAssertEqual(decoded.totalShares, 15)
        XCTAssertEqual(decoded.totalCooks, 42)
        XCTAssertEqual(decoded.averageRating, 4.5)
        XCTAssertEqual(decoded.ratingCount, 12)
        XCTAssertEqual(decoded.commentCount, 8)
        XCTAssertEqual(decoded.trendingScore, 18.5)
    }

    // MARK: - String Extension Tests

    func testSHA256Hash() throws {
        let input = "test-string"
        let hash = input.sha256Hash()

        // SHA256 produces 64-character hex string
        XCTAssertEqual(hash.count, 64)

        // Same input produces same hash
        let hash2 = input.sha256Hash()
        XCTAssertEqual(hash, hash2)

        // Different input produces different hash
        let differentHash = "different-string".sha256Hash()
        XCTAssertNotEqual(hash, differentHash)
    }

    func testExtractDomain() throws {
        XCTAssertEqual("https://www.allrecipes.com/recipe/12345".extractDomain(), "Allrecipes.com")
        XCTAssertEqual("https://example.com/path/to/recipe".extractDomain(), "Example.com")
        XCTAssertEqual("http://www.nytimes.com/cooking".extractDomain(), "Nytimes.com")
        XCTAssertNil("invalid-url".extractDomain())
    }

    func testExtractDomainRemovesWWW() throws {
        XCTAssertEqual("https://www.example.com".extractDomain(), "Example.com")
        XCTAssertEqual("https://example.com".extractDomain(), "Example.com")
    }

    func testExtractDomainCapitalizesFirst() throws {
        XCTAssertEqual("https://allrecipes.com".extractDomain(), "Allrecipes.com")
        XCTAssertEqual("https://ALLRECIPES.COM".extractDomain(), "ALLRECIPES.COM")
    }

    // MARK: - Sample Data Tests

    func testSampleUserCreated() throws {
        let sample = ProvenanceMetadata.sampleUserCreated()

        XCTAssertEqual(sample.sourceType, .userCreated)
        XCTAssertEqual(sample.sourceAttribution, "My Recipe")
        XCTAssertEqual(sample.generation, 0)
        XCTAssertTrue(sample.isOriginal)
    }

    func testSampleImported() throws {
        let sample = ProvenanceMetadata.sampleImported()

        XCTAssertEqual(sample.sourceType, .imported)
        XCTAssertNotNil(sample.sourceURL)
        XCTAssertEqual(sample.generation, 0)
        XCTAssertGreaterThan(sample.cachedMetrics.totalShares, 0)
        XCTAssertGreaterThan(sample.cachedMetrics.totalCooks, 0)
    }

    func testSampleShared() throws {
        let sample = ProvenanceMetadata.sampleShared()

        XCTAssertEqual(sample.sourceType, .shared)
        XCTAssertEqual(sample.generation, 1)
        XCTAssertNotNil(sample.sharedByName)
        XCTAssertNotNil(sample.parentShareID)
        XCTAssertTrue(sample.isShared)
        XCTAssertFalse(sample.isOriginal)
    }

    // MARK: - Hashable Tests

    func testProvenanceMetadataHashable() throws {
        let sameDate = Date()

        let provenance1 = ProvenanceMetadata(
            sourceType: .userCreated,
            rootProvenanceHash: "same-hash",
            generation: 0,
            createdAt: sameDate
        )

        let provenance2 = ProvenanceMetadata(
            sourceType: .userCreated,
            rootProvenanceHash: "same-hash",
            generation: 0,
            createdAt: sameDate
        )

        let provenance3 = ProvenanceMetadata(
            sourceType: .userCreated,
            rootProvenanceHash: "different-hash",
            generation: 0,
            createdAt: sameDate
        )

        XCTAssertEqual(provenance1, provenance2)
        XCTAssertNotEqual(provenance1, provenance3)
    }

    // MARK: - CloudKit Sync Tests

    func testCloudKitRecordTracking() throws {
        var provenance = ProvenanceMetadata(sourceType: .userCreated)

        XCTAssertNil(provenance.cloudKitRecordID)
        XCTAssertNil(provenance.lastSyncedAt)

        // Simulate sync
        provenance.cloudKitRecordID = "CKRecord-12345"
        provenance.lastSyncedAt = Date()

        XCTAssertEqual(provenance.cloudKitRecordID, "CKRecord-12345")
        XCTAssertNotNil(provenance.lastSyncedAt)
    }
}
