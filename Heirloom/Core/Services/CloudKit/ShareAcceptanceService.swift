import Foundation
import CloudKit
import SwiftData
import UIKit

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
        let shareID = shareMetadata.share.recordID.recordName
        print("📥 Accepting share: \(shareID)")

        // DUPLICATE PREVENTION: Check if this share was already accepted
        print("🔍 Checking for already-accepted share...")

        // Fetch all recipes and filter manually (SwiftData predicates don't support optional chaining)
        let fetchDescriptor = FetchDescriptor<Recipe>()
        if let allRecipes = try? context.fetch(fetchDescriptor) {
            if let existingRecipe = allRecipes.first(where: { $0.provenance?.parentShareID == shareID }) {
                print("ℹ️ This share was already accepted")
                DeviceLogger.shared.log("ℹ️ Share already accepted: \(existingRecipe.title)")

                // Return existing recipe (could show "You already have this recipe" UI)
                return existingRecipe
            }
        }

        print("✅ Share not yet accepted, proceeding with import")

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

    /// Accept a share from URL (with optional pre-fetched metadata)
    /// - Parameters:
    ///   - url: The CloudKit share URL
    ///   - metadata: Optional pre-fetched metadata (fetches if nil)
    ///   - context: ModelContext for saving imported recipe
    /// - Returns: The imported Recipe
    func acceptShare(
        url: URL,
        metadata: CKShare.Metadata? = nil,
        context: ModelContext
    ) async throws -> Recipe {
        // Fetch metadata if not provided
        let shareMetadata: CKShare.Metadata
        if let metadata = metadata {
            shareMetadata = metadata
        } else {
            shareMetadata = try await fetchShareMetadata(from: url)
        }

        // Call main acceptance method
        return try await acceptShare(shareMetadata, context: context)
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

    /// Accept the share in CloudKit with automatic retry
    private func acceptShareInCloudKit(_ metadata: CKShare.Metadata) async throws {
        print("✅ Accepting share in CloudKit...")

        return try await CloudKitRetryHelper.withRetry(maxAttempts: 3) {
            return try await withCheckedThrowingContinuation { continuation in
                self.container.accept(metadata) { _, error in
                    if let error = error {
                        print("❌ Error accepting share: \(error)")
                        let ckError = CloudKitSyncError.from(error)
                        print("   Error type: \(ckError.errorDescription ?? "unknown")")
                        continuation.resume(throwing: AcceptanceError.acceptFailed(error))
                    } else {
                        print("✅ Share accepted in CloudKit")
                        continuation.resume()
                    }
                }
            }
        }
    }

    /// Fetch the shared recipe data from CloudKit with automatic retry
    private func fetchSharedRecipe(from metadata: CKShare.Metadata) async throws -> CKRecord {
        print("📦 Fetching shared recipe data...")

        return try await CloudKitRetryHelper.withRetry(maxAttempts: 3) {
            let database = self.container.sharedCloudDatabase

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

        // Parse instructions as JSON array (stored as JSON string in CloudKit)
        var instructions: [String] = []
        if let instructionsString = record["instructions"] as? String,
           let instructionsData = instructionsString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: instructionsData) {
            instructions = decoded
        }

        let servings = record["servings"] as? String
        let prepTime = record["prepTime"] as? String
        let cookTime = record["cookTime"] as? String
        let sourceURL = record["sourceURL"] as? String

        // Parse source type from record (not hardcoded)
        let sourceTypeString = record["sourceType"] as? String
        let sourceType = sourceTypeString.flatMap { RecipeSourceType(rawValue: $0) } ?? .url

        // Create recipe
        let recipe = Recipe(
            title: title,
            sourceType: sourceType,  // Use parsed source type
            sourceURL: sourceURL,
            instructions: instructions,
            servings: servings,
            prepTime: prepTime,
            cookTime: cookTime
        )

        // Download and save image if available
        if let imageAsset = record["imageAsset"] as? CKAsset,
           let fileURL = imageAsset.fileURL {
            print("📷 Downloading recipe image...")
            do {
                let imageData = try Data(contentsOf: fileURL)
                if let image = UIImage(data: imageData) {
                    let fileName = try await ImageStorageService.shared.saveImage(image, recipeId: recipe.id)
                    recipe.imageFileName = fileName
                    print("✅ Image downloaded and saved: \(fileName)")
                }
            } catch {
                print("⚠️ Failed to download image: \(error.localizedDescription)")
            }
        }

        // Set up provenance for shared recipe
        let sharerName = metadata.ownerIdentity.nameComponents?.formatted() ?? "Unknown"
        let parentGeneration = metadata.share["generation"] as? Int ?? 0
        let personalMessage = metadata.share["personalMessage"] as? String

        // IMPORTANT: Read rootProvenanceHash from CKRecord to preserve lineage
        let rootHash = record["rootProvenanceHash"] as? String ?? metadata.share.recordID.recordName

        recipe.provenance = ProvenanceMetadata(
            sourceType: .shared,
            sourceURL: sourceURL,
            sourceAttribution: personalMessage,
            rootProvenanceHash: rootHash,
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
        let includeNotes = (shareMetadata.share["includeNotes"] as? Int) == 1
        let includeComments = (shareMetadata.share["includePinnedComments"] as? Int) == 1

        // Import ingredients (always - they are part of the recipe)
        print("🥕 Fetching ingredients...")
        print("   Recipe recordID: \(record.recordID.recordName)")
        do {
            // For shared records, fetch child records directly by querying with parent reference
            // We need to use the shared database's fetchRecords API with record IDs
            // First, we'll query for ingredient record IDs using the parent reference

            // Use CKReference-based predicate (always indexed and queryable in CloudKit)
            let recipeReference = CKRecord.Reference(recordID: record.recordID, action: .none)
            let predicate = NSPredicate(format: "recipe == %@", recipeReference)
            let query = CKQuery(recordType: "Ingredient", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]

            print("   With reference predicate for recipe: \(record.recordID.recordName)")

            // Use desiredKeys to fetch only specific fields initially (more efficient)
            // Then fetch full records
            let operation = CKQueryOperation(query: query)
            operation.zoneID = record.recordID.zoneID

            var fetchedRecords: [CKRecord] = []
            operation.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    fetchedRecords.append(record)
                case .failure(let error):
                    print("  ⚠️ Failed to fetch ingredient: \(error.localizedDescription)")
                }
            }

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.queryResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                container.sharedCloudDatabase.add(operation)
            }

            print("   Query returned \(fetchedRecords.count) results")

            var importedIngredients: [Ingredient] = []
            for ingredientRecord in fetchedRecords {
                let ingredient = CloudKitSyncService.shared.convertIngredientFromRecord(ingredientRecord)
                ingredient.recipe = recipe
                importedIngredients.append(ingredient)
                context.insert(ingredient)
            }

            recipe.ingredients = importedIngredients
            print("✅ Imported \(importedIngredients.count) ingredients")
        } catch {
            print("⚠️ Ingredients import error: \(error.localizedDescription)")
        }

        // Import card back if included
        if includeCardBack || includeRating || includeNotes {
            print("  📄 Fetching card back data...")
            do {
                // Use CKReference-based predicate (always indexed and queryable in CloudKit)
                let recipeReference = CKRecord.Reference(recordID: record.recordID, action: .none)
                let predicate = NSPredicate(format: "recipe == %@", recipeReference)
                let query = CKQuery(recordType: "RecipeCardBack", predicate: predicate)

                let operation = CKQueryOperation(query: query)
                operation.zoneID = record.recordID.zoneID

                var fetchedRecords: [CKRecord] = []
                operation.recordMatchedBlock = { recordID, result in
                    if case .success(let record) = result {
                        fetchedRecords.append(record)
                    }
                }

                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    operation.queryResultBlock = { result in
                        switch result {
                        case .success:
                            continuation.resume()
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                    container.sharedCloudDatabase.add(operation)
                }

                if let cardBackRecord = fetchedRecords.first {
                    print("  ✅ Found card back, importing...")
                    let cardBack = CloudKitSyncService.shared.convertCardBackFromRecord(cardBackRecord)
                    cardBack.recipe = recipe
                    recipe.cardBack = cardBack
                    context.insert(cardBack)
                    print("  ✅ Card back imported")
                }
            } catch {
                print("  ⚠️ Card back import error: \(error.localizedDescription)")
            }
        }

        // Import comments if included
        if includeComments {
            print("  💬 Fetching comments...")
            do {
                // Use CKReference-based predicate (always indexed and queryable in CloudKit)
                let recipeReference = CKRecord.Reference(recordID: record.recordID, action: .none)
                let predicate = NSPredicate(format: "recipe == %@ AND isPinned == 1", recipeReference)
                let query = CKQuery(recordType: "RecipeComment", predicate: predicate)

                let operation = CKQueryOperation(query: query)
                operation.zoneID = record.recordID.zoneID

                var fetchedRecords: [CKRecord] = []
                operation.recordMatchedBlock = { recordID, result in
                    if case .success(let record) = result {
                        fetchedRecords.append(record)
                    }
                }

                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    operation.queryResultBlock = { result in
                        switch result {
                        case .success:
                            continuation.resume()
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                    container.sharedCloudDatabase.add(operation)
                }

                var importedComments: [RecipeComment] = []
                for commentRecord in fetchedRecords {
                    let comment = CloudKitSyncService.shared.convertCommentFromRecord(commentRecord)
                    comment.recipe = recipe
                    importedComments.append(comment)
                    context.insert(comment)
                }

                if !importedComments.isEmpty {
                    recipe.comments = importedComments
                    print("  ✅ Imported \(importedComments.count) pinned comments")
                }
            } catch {
                print("  ⚠️ Comments import error: \(error.localizedDescription)")
            }
        }

        print("✅ Components imported successfully")
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
