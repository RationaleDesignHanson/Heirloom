import Foundation
import CloudKit
import SwiftData

@MainActor
class CloudKitShareService {
    static let shared = CloudKitShareService()

    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase

    private init() {
        // Use default container (configured in entitlements)
        self.container = CKContainer.default()
        self.publicDatabase = container.publicCloudDatabase
        self.privateDatabase = container.privateCloudDatabase
    }

    // MARK: - Share Recipe

    /// Share a recipe with another user via CloudKit
    func shareRecipe(
        _ recipe: Recipe,
        message: String? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        Task {
            do {
                // Convert Recipe to CloudKit record
                let record = try createRecipeRecord(from: recipe, message: message)

                // Save to public database
                try await saveRecord(record, to: publicDatabase)

                // Create share URL
                let shareURL = try await createShareURL(for: record)

                // Update recipe with share metadata
                recipe.sharedDate = Date()

                // Track analytics
                AnalyticsService.shared.track(event: .recipeShared, properties: [
                    "method": "cloudkit",
                    "has_message": message != nil
                ])

                completion(.success(shareURL))
            } catch {
                print("❌ CloudKit share failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    /// Pass down a recipe (special sharing action with generational tracking)
    func passDownRecipe(
        _ recipe: Recipe,
        to recipient: String,
        message: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        Task {
            do {
                // Create record with pass-down metadata
                let record = try createRecipeRecord(
                    from: recipe,
                    message: message,
                    passDownRecipient: recipient
                )

                // Save to public database
                try await saveRecord(record, to: publicDatabase)

                // Create share URL
                let shareURL = try await createShareURL(for: record)

                // Update recipe with pass-down metadata
                recipe.passedDownDate = Date()
                recipe.sharedDate = Date()

                // Track analytics
                AnalyticsService.shared.track(event: .recipeShared, properties: [
                    "method": "cloudkit_passdown",
                    "generation": recipe.generationCount
                ])

                completion(.success(shareURL))
            } catch {
                print("❌ CloudKit pass-down failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Receive Recipe

    /// Accept a shared recipe from another user
    func acceptSharedRecipe(
        from url: URL,
        modelContext: ModelContext,
        completion: @escaping (Result<Recipe, Error>) -> Void
    ) {
        Task {
            do {
                // Fetch share metadata
                let metadata = try await fetchShareMetadata(from: url)

                // Accept share
                try await acceptShare(metadata)

                // Fetch the actual recipe record
                let recordID = metadata.share.recordID
                let record = try await fetchRecord(recordID, from: publicDatabase)

                // Convert CloudKit record to Recipe
                let recipe = try createRecipe(from: record)

                // Insert into local database
                modelContext.insert(recipe)
                try modelContext.save()

                // Track analytics
                AnalyticsService.shared.track(event: .recipeImported, properties: [
                    "source": "cloudkit_share",
                    "generation": recipe.generationCount
                ])

                completion(.success(recipe))
            } catch {
                print("❌ CloudKit receive failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - User Info

    /// Get current user's name for attribution
    func getCurrentUserName() async throws -> String {
        let userRecordID = try await container.userRecordID()
        let userRecord = try await privateDatabase.record(for: userRecordID)

        // Try to get user's name from CKUserIdentity
        if let firstName = userRecord["firstName"] as? String,
           let lastName = userRecord["lastName"] as? String {
            return "\(firstName) \(lastName)"
        }

        // Fallback to record name
        return userRecordID.recordName
    }

    // MARK: - Private Helpers

    private func createRecipeRecord(
        from recipe: Recipe,
        message: String? = nil,
        passDownRecipient: String? = nil
    ) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: recipe.id.uuidString)
        let record = CKRecord(recordType: "SharedRecipe", recordID: recordID)

        // Basic info
        record["title"] = recipe.title as CKRecordValue
        record["sourceURL"] = recipe.sourceURL as CKRecordValue?
        record["servings"] = recipe.servings as CKRecordValue?
        record["prepTime"] = recipe.prepTime as CKRecordValue?
        record["cookTime"] = recipe.cookTime as CKRecordValue?
        record["notes"] = recipe.notes as CKRecordValue?

        // Instructions
        if !recipe.instructions.isEmpty {
            record["instructions"] = recipe.instructions as CKRecordValue
        }

        // Ingredients (as strings)
        if let ingredients = recipe.ingredients {
            let ingredientStrings = ingredients.map { $0.originalText }
            record["ingredients"] = ingredientStrings as CKRecordValue
        }

        // Share metadata
        if let message = message {
            record["shareMessage"] = message as CKRecordValue
        }

        // Provenance
        record["generationCount"] = recipe.generationCount as CKRecordValue
        record["timesCooked"] = recipe.timesCooked as CKRecordValue

        if let passDownRecipient = passDownRecipient {
            record["passDownRecipient"] = passDownRecipient as CKRecordValue
        }

        // Image (if available)
        if recipe.imageFileName != nil {
            Task {
                if let image = await recipe.loadImage() {
                    if let imageData = image.jpegData(compressionQuality: 0.7) {
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent("\(recipe.id.uuidString).jpg")
                        try? imageData.write(to: tempURL)

                        let asset = CKAsset(fileURL: tempURL)
                        record["image"] = asset
                    }
                }
            }
        }

        return record
    }

    private func createRecipe(from record: CKRecord) throws -> Recipe {
        guard let title = record["title"] as? String else {
            throw CloudKitError.invalidRecord
        }

        let recipe = Recipe(
            title: title,
            sourceType: .url,
            instructions: record["instructions"] as? [String] ?? [],
            servings: record["servings"] as? String,
            prepTime: record["prepTime"] as? String,
            cookTime: record["cookTime"] as? String
        )

        recipe.sourceURL = record["sourceURL"] as? String
        recipe.notes = record["notes"] as? String

        // Share metadata
        recipe.sharedDate = record.creationDate
        recipe.sharedBy = record.creatorUserRecordID?.recordName

        if let message = record["shareMessage"] as? String {
            recipe.passedDownMessage = message
        }

        // Provenance
        if let generation = record["generationCount"] as? Int {
            recipe.generationCount = generation + 1 // Increment for recipient
        }

        if let recipient = record["passDownRecipient"] as? String {
            recipe.passedDownBy = recipient
            recipe.passedDownDate = record.creationDate
        }

        // Note: Ingredients and image would need separate handling
        // For now, we store ingredient strings in recipe.notes
        if let ingredients = record["ingredients"] as? [String] {
            let ingredientsText = ingredients.joined(separator: "\n")
            if let notes = recipe.notes {
                recipe.notes = notes + "\n\nIngredients:\n" + ingredientsText
            } else {
                recipe.notes = "Ingredients:\n" + ingredientsText
            }
        }

        return recipe
    }

    private func saveRecord(_ record: CKRecord, to database: CKDatabase) async throws {
        _ = try await database.save(record)
    }

    private func fetchRecord(_ recordID: CKRecord.ID, from database: CKDatabase) async throws -> CKRecord {
        return try await database.record(for: recordID)
    }

    private func createShareURL(for record: CKRecord) async throws -> URL {
        // Create a CKShare for the record
        let share = CKShare(rootRecord: record)
        share.publicPermission = .readOnly

        // Save the share
        _ = try await publicDatabase.save(share)

        // Return the share URL
        guard let url = share.url else {
            throw CloudKitError.shareCreationFailed
        }

        return url
    }

    private func fetchShareMetadata(from url: URL) async throws -> CKShare.Metadata {
        return try await container.shareMetadata(for: url)
    }

    private func acceptShare(_ metadata: CKShare.Metadata) async throws {
        _ = try await container.accept(metadata)
    }
}

// MARK: - Errors

enum CloudKitError: LocalizedError {
    case notAvailable
    case invalidRecord
    case invalidShare
    case shareCreationFailed
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "iCloud is not available. Please check your iCloud settings."
        case .invalidRecord:
            return "The recipe data is invalid or corrupted."
        case .invalidShare:
            return "The share link is invalid or has expired."
        case .shareCreationFailed:
            return "Failed to create share link. Please try again."
        case .userNotFound:
            return "User information not found."
        }
    }
}
