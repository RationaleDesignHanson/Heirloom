import Foundation
import CloudKit
import SwiftData

/// Service for syncing and aggregating comments across recipe lineage
/// Handles sharing comments that follow recipes through shares/pass-downs
@MainActor
final class SharedCommentService: ObservableObject {

    // MARK: - Singleton

    static let shared = SharedCommentService()

    // MARK: - Published State

    @Published var isSyncing = false
    @Published var lastError: Error?

    // MARK: - Constants

    private let container = CKContainer.default()
    private let recordType = "SharedComment"

    // MARK: - Initialization

    private init() {}

    // MARK: - Share Comment

    /// Share a comment to CloudKit for lineage visibility
    /// - Parameters:
    ///   - comment: The comment to share
    ///   - recipe: The recipe this comment belongs to
    /// - Throws: CloudKit errors
    func shareComment(_ comment: RecipeComment, from recipe: Recipe) async throws {
        guard comment.isVisibleToLineage else {
            print("⚠️ Comment is private, not sharing to CloudKit")
            return
        }

        guard let provenance = recipe.provenance else {
            throw CommentSharingError.missingProvenance
        }

        print("📤 Sharing comment to CloudKit lineage: \(provenance.rootProvenanceHash)")

        isSyncing = true
        defer { isSyncing = false }

        do {
            // Create CKRecord for comment
            let record = try serializeComment(comment, provenance: provenance)

            // Save to public database
            let publicDB = container.publicCloudDatabase
            _ = try await publicDB.save(record)

            print("✅ Comment shared to CloudKit")

            // Track analytics
            AnalyticsService.shared.track(event: .recipeShared, properties: [
                "type": "comment",
                "scope": comment.shareScope.rawValue,
                "provenance_hash": provenance.rootProvenanceHash
            ])

        } catch {
            lastError = error
            print("❌ Failed to share comment: \(error)")
            throw error
        }
    }

    /// Update comment endorsement count in CloudKit
    /// - Parameters:
    ///   - commentID: The comment's UUID
    ///   - increment: Whether to add or remove endorsement
    func updateEndorsement(for commentID: UUID, increment: Bool) async throws {
        print("👍 Updating endorsement for comment: \(commentID.uuidString)")

        isSyncing = true
        defer { isSyncing = false }

        let publicDB = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: "comment-\(commentID.uuidString)")

        do {
            // Fetch existing record
            let record = try await publicDB.record(for: recordID)

            // Update endorsement count
            let currentCount = record["endorsementCount"] as? Int ?? 0
            record["endorsementCount"] = (increment ? currentCount + 1 : max(0, currentCount - 1)) as CKRecordValue
            record["lastEndorsedAt"] = Date() as CKRecordValue

            // Save back
            _ = try await publicDB.save(record)

            print("✅ Endorsement updated: \(increment ? "+" : "-")1")

        } catch {
            lastError = error
            print("❌ Failed to update endorsement: \(error)")
            throw error
        }
    }

    // MARK: - Fetch Lineage Comments

    /// Fetch all comments from recipe lineage (across all shares)
    /// - Parameters:
    ///   - provenanceHash: Root provenance hash of the recipe
    ///   - limit: Maximum number of comments to fetch
    /// - Returns: Array of aggregated comment data
    func fetchLineageComments(
        provenanceHash: String,
        limit: Int = 100
    ) async throws -> [AggregatedCommentData] {
        print("📥 Fetching comments for lineage: \(provenanceHash)")

        isSyncing = true
        defer { isSyncing = false }

        let publicDB = container.publicCloudDatabase

        // Query for comments with matching provenance hash
        let predicate = NSPredicate(format: "rootProvenanceHash == %@", provenanceHash)
        let query = CKQuery(recordType: recordType, predicate: predicate)

        // Sort by endorsement count and date
        query.sortDescriptors = [
            NSSortDescriptor(key: "endorsementCount", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]

        do {
            // Fetch records
            let results = try await publicDB.records(matching: query, resultsLimit: limit)

            // Deserialize to AggregatedCommentData
            var comments: [AggregatedCommentData] = []
            for (recordID, result) in results.matchResults {
                switch result {
                case .success(let record):
                    if let commentData = try? deserializeComment(record) {
                        comments.append(commentData)
                    }
                case .failure(let error):
                    print("⚠️ Failed to fetch record \(recordID): \(error)")
                }
            }

            print("✅ Fetched \(comments.count) lineage comments")
            return comments

        } catch {
            lastError = error
            print("❌ Failed to fetch lineage comments: \(error)")
            throw error
        }
    }

    /// Fetch comments for a specific recipe generation
    /// - Parameters:
    ///   - provenanceHash: Root provenance hash
    ///   - generation: Generation number to filter by
    /// - Returns: Comments from that specific generation
    func fetchCommentsForGeneration(
        provenanceHash: String,
        generation: Int
    ) async throws -> [AggregatedCommentData] {
        print("📥 Fetching comments for generation \(generation)")

        isSyncing = true
        defer { isSyncing = false }

        let publicDB = container.publicCloudDatabase

        // Query for comments with matching provenance and generation
        let predicate = NSPredicate(
            format: "rootProvenanceHash == %@ AND generation == %d",
            provenanceHash,
            generation
        )
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            let results = try await publicDB.records(matching: query)

            var comments: [AggregatedCommentData] = []
            for (_, result) in results.matchResults {
                if case .success(let record) = result,
                   let commentData = try? deserializeComment(record) {
                    comments.append(commentData)
                }
            }

            print("✅ Fetched \(comments.count) comments from generation \(generation)")
            return comments

        } catch {
            lastError = error
            throw error
        }
    }

    // MARK: - Sync Local Comment

    /// Sync a local comment's CloudKit data back to SwiftData
    /// - Parameters:
    ///   - comment: Local comment to update
    ///   - context: SwiftData context
    func syncCommentEndorsements(_ comment: RecipeComment, context: ModelContext) async throws {
        guard comment.isVisibleToLineage else { return }

        print("🔄 Syncing endorsements for comment: \(comment.id.uuidString)")

        let publicDB = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: "comment-\(comment.id.uuidString)")

        do {
            let record = try await publicDB.record(for: recordID)

            // Update local endorsement count from CloudKit
            let cloudEndorsements = record["endorsementCount"] as? Int ?? 0
            if cloudEndorsements != comment.endorsementCount {
                comment.endorsementCount = cloudEndorsements
                try context.save()
                print("✅ Updated local endorsement count: \(cloudEndorsements)")
            }

        } catch let error as CKError where error.code == .unknownItem {
            // Comment not yet in CloudKit, share it
            if let recipe = comment.recipe {
                try await shareComment(comment, from: recipe)
            }
        } catch {
            throw error
        }
    }

    // MARK: - Private: Serialization

    /// Serialize a comment to CKRecord
    private func serializeComment(_ comment: RecipeComment, provenance: ProvenanceMetadata) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: "comment-\(comment.id.uuidString)")
        let record = CKRecord(recordType: recordType, recordID: recordID)

        // Core data
        record["commentID"] = comment.id.uuidString as CKRecordValue
        record["text"] = comment.text as CKRecordValue
        record["authorName"] = (comment.authorName ?? "Anonymous") as CKRecordValue

        // Provenance tracking
        record["rootProvenanceHash"] = provenance.rootProvenanceHash as CKRecordValue
        record["generation"] = provenance.generation as CKRecordValue
        record["originProvenanceHash"] = (comment.originProvenanceHash ?? provenance.rootProvenanceHash) as CKRecordValue

        // Scope and classification
        record["shareScope"] = comment.shareScope.rawValue as CKRecordValue
        record["commentType"] = comment.commentType.rawValue as CKRecordValue

        // Engagement
        record["endorsementCount"] = comment.endorsementCount as CKRecordValue
        record["upvotes"] = comment.upvotes as CKRecordValue

        // Analysis data
        if let sentiment = comment.sentimentScore {
            record["sentimentScore"] = sentiment as CKRecordValue
        }
        if !comment.topics.isEmpty {
            record["topics"] = comment.topics as CKRecordValue
        }

        // Timestamps
        record["createdAt"] = comment.createdAt as CKRecordValue
        record["lastEndorsedAt"] = Date() as CKRecordValue

        return record
    }

    /// Deserialize CKRecord to AggregatedCommentData
    private func deserializeComment(_ record: CKRecord) throws -> AggregatedCommentData {
        guard let commentID = record["commentID"] as? String,
              let text = record["text"] as? String,
              let authorName = record["authorName"] as? String,
              let rootHash = record["rootProvenanceHash"] as? String else {
            throw CommentSharingError.invalidData
        }

        return AggregatedCommentData(
            commentID: UUID(uuidString: commentID) ?? UUID(),
            text: text,
            authorName: authorName,
            rootProvenanceHash: rootHash,
            generation: record["generation"] as? Int ?? 0,
            originProvenanceHash: record["originProvenanceHash"] as? String,
            shareScope: CommentScope(rawValue: record["shareScope"] as? String ?? "lineage") ?? .lineage,
            commentType: CommentType(rawValue: record["commentType"] as? String ?? "general") ?? .general,
            endorsementCount: record["endorsementCount"] as? Int ?? 0,
            upvotes: record["upvotes"] as? Int ?? 0,
            sentimentScore: record["sentimentScore"] as? Double,
            topics: record["topics"] as? [String] ?? [],
            createdAt: record["createdAt"] as? Date ?? Date(),
            lastEndorsedAt: record["lastEndorsedAt"] as? Date
        )
    }
}

// MARK: - Supporting Types

/// Aggregated comment data from CloudKit
struct AggregatedCommentData: Identifiable {
    let commentID: UUID
    let text: String
    let authorName: String
    let rootProvenanceHash: String
    let generation: Int
    let originProvenanceHash: String?
    let shareScope: CommentScope
    let commentType: CommentType
    let endorsementCount: Int
    let upvotes: Int
    let sentimentScore: Double?
    let topics: [String]
    let createdAt: Date
    let lastEndorsedAt: Date?

    var id: UUID { commentID }

    /// Display string for comment source
    var sourceDisplay: String {
        if generation == 0 {
            return "Original Recipe"
        } else if generation == 1 {
            return "1st Generation"
        } else {
            return "\(generation)th Generation"
        }
    }

    /// Total engagement score
    var engagementScore: Int {
        endorsementCount + upvotes
    }

    /// Whether comment is from original recipe
    var isFromOriginal: Bool {
        generation == 0
    }

    /// Display string for engagement
    var engagementDisplay: String {
        let total = engagementScore
        if total == 0 { return "" }
        if total == 1 { return "1 like" }
        return "\(total) likes"
    }
}

/// Errors specific to comment sharing
enum CommentSharingError: LocalizedError {
    case missingProvenance
    case invalidData
    case notFound
    case syncFailed(Error)

    var errorDescription: String? {
        switch self {
        case .missingProvenance:
            return "Recipe is missing provenance metadata"
        case .invalidData:
            return "Invalid comment data from CloudKit"
        case .notFound:
            return "Comment not found in CloudKit"
        case .syncFailed(let error):
            return "Failed to sync comment: \(error.localizedDescription)"
        }
    }
}
