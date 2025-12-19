import Foundation
import CloudKit
import SwiftData

/// Service for creating and managing CKShare-based recipe sharing
/// Handles share creation, URL generation, permissions, and revocation
@MainActor
final class RecipeShareService {
    // MARK: - Singleton

    static let shared = RecipeShareService()

    private init() {}

    // MARK: - Dependencies

    private let container: CKContainer = CKContainer.default()
    private let coordinator = CloudKitSyncCoordinator.shared

    // MARK: - Share Creation

    /// Create a CKShare for a recipe with specified options
    /// - Parameters:
    ///   - recipe: The recipe to share
    ///   - options: Configuration for what to include
    ///   - context: ModelContext for SwiftData operations
    /// - Returns: The created CKShare with URL
    func createShare(
        for recipe: Recipe,
        options: ShareOptions,
        context: ModelContext
    ) async throws -> CKShare {
        print("📤 Creating share for recipe: \(recipe.title)")

        // 1. Ensure recipe has CloudKit record ID
        guard let recordID = try await ensureCloudKitRecord(for: recipe, context: context) else {
            throw ShareError.noRecordID
        }

        print("✅ Recipe has CloudKit record: \(recordID.recordName)")

        // 2. Create CKShare
        let share = CKShare(rootRecord: try await fetchRecord(recordID))

        // 3. Configure share metadata
        share[CKShare.SystemFieldKey.title] = recipe.title as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = "recipe" as CKRecordValue

        // Set thumbnail if available
        if recipe.imageFileName != nil {
            // TODO: Convert image to CKAsset
            // share[CKShare.SystemFieldKey.thumbnailImageData] = imageAsset
        }

        // 4. Configure permissions
        share.publicPermission = .none // Private share only
        // Store permission as custom field
        share["permission"] = options.permission.rawValue as CKRecordValue

        // 5. Set expiration (no built-in expiration, store as custom field for UI)
        if let expirationDate = options.expirationDuration?.expirationDate {
            share["expiresAt"] = expirationDate as CKRecordValue
        }

        // 6. Add custom metadata
        share["personalMessage"] = options.personalMessage as? CKRecordValue
        share["sharerName"] = options.sharerName as? CKRecordValue
        share["includeCardBack"] = (options.includeCardBack ? 1 : 0) as CKRecordValue
        share["includeRating"] = (options.includeRating ? 1 : 0) as CKRecordValue
        share["allowReSharing"] = (options.allowReSharing ? 1 : 0) as CKRecordValue
        share["generation"] = (recipe.provenance?.generation ?? 0) as CKRecordValue

        // 7. Save share to CloudKit
        let savedShare = try await saveShare(share)

        print("✅ Share created successfully: \(savedShare.url?.absoluteString ?? "no URL")")

        // 8. Update recipe provenance
        updateProvenanceForSharing(recipe: recipe, share: savedShare)

        // 9. Track analytics
        trackShareCreated(recipe: recipe, options: options)

        return savedShare
    }

    /// Generate a shareable URL from a CKShare
    /// - Parameter share: The CKShare to generate URL for
    /// - Returns: Shareable URL
    func generateShareURL(from share: CKShare) -> URL? {
        return share.url
    }

    /// Generate a short link for easier sharing
    /// - Parameter share: The CKShare
    /// - Returns: Shortened URL (e.g., heirloom.app/r/abc123)
    func generateShortLink(from share: CKShare) async throws -> URL {
        guard let longURL = share.url else {
            throw ShareError.noShareURL
        }

        // TODO: Implement short link generation via Cloud Function
        // For now, return the long URL
        return longURL
    }

    // MARK: - Share Management

    /// Revoke an existing share
    /// - Parameter share: The CKShare to revoke
    func revokeShare(_ share: CKShare) async throws {
        print("🗑️ Revoking share: \(share.recordID.recordName)")

        let database = container.privateCloudDatabase
        try await database.deleteRecord(withID: share.recordID)

        print("✅ Share revoked successfully")
    }

    /// Check the status of a share
    /// - Parameter shareID: The CKShare record ID
    /// - Returns: ShareStatus with participant info
    func checkShareStatus(_ shareID: String) async throws -> ShareStatus {
        let recordID = CKRecord.ID(recordName: shareID)
        let database = container.privateCloudDatabase

        do {
            let share = try await database.record(for: recordID) as? CKShare
            guard let share = share else {
                throw ShareError.shareNotFound
            }

            return ShareStatus(
                isActive: true,
                participantCount: share.participants.count,
                acceptedCount: share.participants.filter { $0.acceptanceStatus == .accepted }.count,
                owner: share.owner.userIdentity.nameComponents?.formatted() ?? "Unknown",
                createdAt: share.creationDate,
                expiresAt: share["expiresAt"] as? Date
            )
        } catch {
            print("❌ Error checking share status: \(error)")
            throw ShareError.checkFailed(error)
        }
    }

    /// List all active shares for the current user
    func listActiveShares() async throws -> [CKShare] {
        print("📋 Fetching active shares...")

        let database = container.privateCloudDatabase
        let query = CKQuery(
            recordType: "cloudkit.share",
            predicate: NSPredicate(value: true)
        )

        let results = try await database.records(matching: query)
        let shares = results.matchResults.compactMap { try? $0.1.get() as? CKShare }

        print("✅ Found \(shares.count) active shares")
        return shares
    }

    // MARK: - Helper Methods

    /// Ensure recipe has a CloudKit record
    private func ensureCloudKitRecord(
        for recipe: Recipe,
        context: ModelContext
    ) async throws -> CKRecord.ID? {
        // Check if recipe already has CloudKit metadata
        if let existingRecordID = recipe.provenance?.cloudKitRecordID {
            return CKRecord.ID(recordName: existingRecordID)
        }

        // Create new CloudKit record for recipe
        let recordID = CKRecord.ID(recordName: "recipe-\(recipe.id.uuidString)")
        let record = CKRecord(recordType: "Recipe", recordID: recordID)

        // Populate record with recipe data
        record["title"] = recipe.title as CKRecordValue
        record["instructions"] = (recipe.instructions.joined(separator: "\n")) as CKRecordValue
        record["servings"] = recipe.servings as? CKRecordValue
        record["prepTime"] = recipe.prepTime as? CKRecordValue
        record["cookTime"] = recipe.cookTime as? CKRecordValue
        record["sourceURL"] = recipe.sourceURL as? CKRecordValue

        // Save to CloudKit
        let database = container.privateCloudDatabase
        let savedRecord = try await database.save(record)

        // Update recipe with CloudKit ID
        recipe.provenance?.cloudKitRecordID = savedRecord.recordID.recordName
        recipe.provenance?.lastSyncedAt = Date()

        try context.save()

        return savedRecord.recordID
    }

    /// Fetch a CloudKit record by ID
    private func fetchRecord(_ recordID: CKRecord.ID) async throws -> CKRecord {
        let database = container.privateCloudDatabase
        return try await database.record(for: recordID)
    }

    /// Save a share to CloudKit
    private func saveShare(_ share: CKShare) async throws -> CKShare {
        let database = container.privateCloudDatabase
        let savedRecord = try await database.save(share)

        guard let savedShare = savedRecord as? CKShare else {
            throw ShareError.saveFailed
        }

        return savedShare
    }

    /// Update recipe provenance after sharing
    private func updateProvenanceForSharing(recipe: Recipe, share: CKShare) {
        guard var provenance = recipe.provenance else { return }

        // Increment share count
        provenance.cachedMetrics.totalShares += 1
        provenance.cachedMetrics.lastUpdated = Date()

        // Update CloudKit metadata
        provenance.cloudKitRecordID = share.recordID.recordName
        provenance.lastSyncedAt = Date()

        recipe.provenance = provenance
    }

    /// Track share creation analytics
    private func trackShareCreated(recipe: Recipe, options: ShareOptions) {
        // TODO: Send to analytics service
        print("📊 Analytics: Recipe shared - \(recipe.title)")
        print("   Permission: \(options.permission.rawValue)")
        print("   Expiration: \(options.expirationDuration?.displayName ?? "Never")")
        print("   Includes personalization: \(options.includesPersonalization)")
    }
}

// MARK: - Supporting Types

extension RecipeShareService {
    struct ShareStatus {
        let isActive: Bool
        let participantCount: Int
        let acceptedCount: Int
        let owner: String
        let createdAt: Date?
        let expiresAt: Date?

        var isExpired: Bool {
            guard let expiresAt = expiresAt else { return false }
            return expiresAt < Date()
        }

        var pendingCount: Int {
            participantCount - acceptedCount
        }

        var statusText: String {
            if isExpired {
                return "Expired"
            } else if acceptedCount == 0 {
                return "Pending"
            } else if acceptedCount == participantCount {
                return "Active (\(acceptedCount) accepted)"
            } else {
                return "Partially accepted (\(acceptedCount)/\(participantCount))"
            }
        }
    }

    enum ShareError: LocalizedError {
        case noRecordID
        case noShareURL
        case shareNotFound
        case saveFailed
        case checkFailed(Error)

        var errorDescription: String? {
            switch self {
            case .noRecordID:
                return "Recipe does not have a CloudKit record ID"
            case .noShareURL:
                return "Share was created but no URL was generated"
            case .shareNotFound:
                return "Share not found in CloudKit"
            case .saveFailed:
                return "Failed to save share to CloudKit"
            case .checkFailed(let error):
                return "Failed to check share status: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Convenience Methods

extension RecipeShareService {
    /// Quick share with default options
    func quickShare(recipe: Recipe, context: ModelContext) async throws -> CKShare {
        return try await createShare(for: recipe, options: .default, context: context)
    }

    /// Share with personal message
    func shareWithMessage(
        recipe: Recipe,
        message: String,
        context: ModelContext
    ) async throws -> CKShare {
        var options = ShareOptions.default
        options.personalMessage = message
        return try await createShare(for: recipe, options: options, context: context)
    }
}
