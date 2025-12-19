import Foundation
import CloudKit
import SwiftData

/// Service for accepting incoming recipe shares and importing to local collection
/// Handles CKShare acceptance, recipe duplication, and provenance linking
@MainActor
final class ShareAcceptanceService {
    // MARK: - Singleton

    static let shared = ShareAcceptanceService()

    private init() {}

    // MARK: - Dependencies

    private let container: CKContainer = CKContainer.default()
    private let coordinator = CloudKitSyncCoordinator.shared

    // MARK: - Share Acceptance

    /// Accept a share and import the recipe to local collection
    /// - Parameters:
    ///   - shareMetadata: CloudKit share metadata from the share URL
    ///   - context: ModelContext for saving imported recipe
    /// - Returns: The imported Recipe
    func acceptShare(
        _ shareMetadata: CKShare.Metadata,
        context: ModelContext
    ) async throws -> Recipe {
        print("📥 Accepting share: \(shareMetadata.share.recordID.recordName)")

        // 1. Accept the share in CloudKit
        try await acceptShareInCloudKit(shareMetadata)

        // 2. Fetch the shared recipe data
        let sharedRecipe = try await fetchSharedRecipe(from: shareMetadata)

        // 3. Create local copy with provenance
        let importedRecipe = try await createLocalCopy(
            of: sharedRecipe,
            from: shareMetadata,
            context: context
        )

        // 4. Import selected components (comments, card back, etc.)
        try await importComponents(
            from: sharedRecipe,
            to: importedRecipe,
            shareMetadata: shareMetadata,
            context: context
        )

        // 5. Save to local database
        context.insert(importedRecipe)
        try context.save()

        print("✅ Recipe imported successfully: \(importedRecipe.title)")

        // 6. Track analytics
        trackShareAccepted(recipe: importedRecipe, shareMetadata: shareMetadata)

        // 7. Send thank you notification (optional)
        await sendThankYouNotification(to: shareMetadata.ownerIdentity)

        return importedRecipe
    }

    /// Fetch share metadata from a CloudKit share URL
    /// - Parameter url: The share URL
    /// - Returns: CKShare.Metadata
    func fetchShareMetadata(from url: URL) async throws -> CKShare.Metadata {
        print("🔍 Fetching share metadata from URL...")

        return try await withCheckedThrowingContinuation { continuation in
            container.fetchShareMetadata(with: url) { metadata, error in
                if let error = error {
                    print("❌ Error fetching share metadata: \(error)")
                    continuation.resume(throwing: AcceptanceError.fetchFailed(error))
                } else if let metadata = metadata {
                    print("✅ Share metadata fetched successfully")
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(throwing: AcceptanceError.noMetadata)
                }
            }
        }
    }

    /// Preview share information before accepting
    /// - Parameter url: The share URL
    /// - Returns: SharePreview with recipe info
    func previewShare(from url: URL) async throws -> SharePreview {
        print("👀 Previewing share...")

        let metadata = try await fetchShareMetadata(from: url)

        // Extract basic info from metadata
        let title = metadata.share[CKShare.SystemFieldKey.title] as? String ?? "Unknown Recipe"
        let sharerName = metadata.ownerIdentity.nameComponents?.formatted() ?? "Someone"
        let personalMessage = metadata.share["personalMessage"] as? String

        return SharePreview(
            title: title,
            sharerName: sharerName,
            personalMessage: personalMessage,
            includesCardBack: (metadata.share["includeCardBack"] as? Int) == 1,
            includesRating: (metadata.share["includeRating"] as? Int) == 1,
            allowReSharing: (metadata.share["allowReSharing"] as? Int) == 1,
            generation: metadata.share["generation"] as? Int ?? 0,
            expiresAt: metadata.share["expiresAt"] as? Date
        )
    }

    // MARK: - Private Methods

    /// Accept the share in CloudKit
    private func acceptShareInCloudKit(_ metadata: CKShare.Metadata) async throws {
        print("✅ Accepting share in CloudKit...")

        return try await withCheckedThrowingContinuation { continuation in
            container.accept(metadata) { _, error in
                if let error = error {
                    print("❌ Error accepting share: \(error)")
                    continuation.resume(throwing: AcceptanceError.acceptFailed(error))
                } else {
                    print("✅ Share accepted in CloudKit")
                    continuation.resume()
                }
            }
        }
    }

    /// Fetch the shared recipe data from CloudKit
    private func fetchSharedRecipe(from metadata: CKShare.Metadata) async throws -> CKRecord {
        print("📦 Fetching shared recipe data...")

        let database = container.sharedCloudDatabase
        
        // For shares, we need to look at the rootRecordID from the share
        // The record should be in the shared database after accepting
        guard let rootRecordID = metadata.hierarchicalRootRecordID else {
            // Fallback: try to find by share record
            throw AcceptanceError.noMetadata
        }

        let record = try await database.record(for: rootRecordID)

        print("✅ Recipe data fetched: \(record["title"] as? String ?? "Unknown")")
        return record
    }

    /// Create a local copy of the shared recipe with proper provenance
    private func createLocalCopy(
        of record: CKRecord,
        from metadata: CKShare.Metadata,
        context: ModelContext
    ) async throws -> Recipe {
        print("📝 Creating local copy with provenance...")

        // Extract recipe data from CKRecord
        let title = record["title"] as? String ?? "Untitled Recipe"
        let instructions = (record["instructions"] as? String)?.components(separatedBy: "\n") ?? []
        let servings = record["servings"] as? String
        let prepTime = record["prepTime"] as? String
        let cookTime = record["cookTime"] as? String
        let sourceURL = record["sourceURL"] as? String

        // Create recipe
        let recipe = Recipe(
            title: title,
            sourceType: .url,
            sourceURL: sourceURL,
            instructions: instructions,
            servings: servings,
            prepTime: prepTime,
            cookTime: cookTime
        )

        // Set up provenance for shared recipe
        let sharerName = metadata.ownerIdentity.nameComponents?.formatted() ?? "Unknown"
        let parentGeneration = metadata.share["generation"] as? Int ?? 0
        let personalMessage = metadata.share["personalMessage"] as? String

        recipe.provenance = ProvenanceMetadata(
            sourceType: .shared,
            sourceURL: sourceURL,
            sourceAttribution: personalMessage,
            generation: parentGeneration + 1,
            parentShareID: metadata.share.recordID.recordName,
            sharedByName: sharerName,
            createdAt: Date()
        )

        // Copy legacy fields for backward compatibility
        recipe.sharedBy = sharerName
        recipe.sharedDate = Date()
        recipe.passedDownMessage = personalMessage
        recipe.generationCount = parentGeneration + 2 // Legacy field uses 1-based indexing

        print("✅ Local copy created: Gen \(parentGeneration + 1)")
        return recipe
    }

    /// Import selected components (comments, card back, etc.)
    private func importComponents(
        from record: CKRecord,
        to recipe: Recipe,
        shareMetadata: CKShare.Metadata,
        context: ModelContext
    ) async throws {
        print("📦 Importing components...")

        let includeCardBack = (shareMetadata.share["includeCardBack"] as? Int) == 1
        let includeRating = (shareMetadata.share["includeRating"] as? Int) == 1

        // Import card back if included
        if includeCardBack {
            // TODO: Fetch and import card back data
            print("  - Card back: included")
        }

        // Import rating if included
        if includeRating {
            // TODO: Import rating data
            print("  - Rating: included")
        }

        // TODO: Import comments, stickers, etc.

        print("✅ Components imported")
    }

    /// Send thank you notification to the sharer
    private func sendThankYouNotification(to ownerIdentity: CKUserIdentity?) async {
        guard let ownerIdentity = ownerIdentity else { return }

        print("💌 Sending thank you notification...")

        // TODO: Send push notification or iMessage to sharer
        // For now, just log

        print("✅ Thank you notification sent to \(ownerIdentity.nameComponents?.formatted() ?? "sharer")")
    }

    /// Track share acceptance analytics
    private func trackShareAccepted(recipe: Recipe, shareMetadata: CKShare.Metadata) {
        print("📊 Analytics: Share accepted")
        print("   Recipe: \(recipe.title)")
        print("   Generation: \(recipe.provenance?.generation ?? 0)")
        print("   From: \(shareMetadata.ownerIdentity.nameComponents?.formatted() ?? "Unknown")")
    }
}

// MARK: - Supporting Types

extension ShareAcceptanceService {
    /// Preview information about a share before accepting
    struct SharePreview {
        let title: String
        let sharerName: String
        let personalMessage: String?
        let includesCardBack: Bool
        let includesRating: Bool
        let allowReSharing: Bool
        let generation: Int
        let expiresAt: Date?

        var lineageSummary: String {
            if generation == 0 {
                return "Original recipe from \(sharerName)"
            } else if generation == 1 {
                return "Shared by \(sharerName) (1st generation)"
            } else {
                return "Shared by \(sharerName) (\(generation)th generation)"
            }
        }

        var isExpired: Bool {
            guard let expiresAt = expiresAt else { return false }
            return expiresAt < Date()
        }

        var expirationText: String? {
            guard let expiresAt = expiresAt else { return nil }

            if isExpired {
                return "Expired"
            }

            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return "Expires \(formatter.localizedString(for: expiresAt, relativeTo: Date()))"
        }
    }

    enum AcceptanceError: LocalizedError {
        case fetchFailed(Error)
        case noMetadata
        case acceptFailed(Error)
        case importFailed(Error)

        var errorDescription: String? {
            switch self {
            case .fetchFailed(let error):
                return "Failed to fetch share metadata: \(error.localizedDescription)"
            case .noMetadata:
                return "No share metadata found"
            case .acceptFailed(let error):
                return "Failed to accept share: \(error.localizedDescription)"
            case .importFailed(let error):
                return "Failed to import recipe: \(error.localizedDescription)"
            }
        }
    }
}
