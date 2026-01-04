//
//  FirebaseShareService.swift
//  Heirloom
//
//  Created during Firebase Migration - Phase 6
//  Handles recipe sharing via Firestore
//

import Foundation
import SwiftData
import UIKit
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

/// Firebase-based recipe sharing service
/// Replaces CloudKit CKShare with Firestore-based sharing system
@MainActor
class FirebaseShareService: ObservableObject, FirebaseShareServiceProtocol {

    // MARK: - Dependencies

    private let configuration: FirebaseConfigurationProtocol
    private let logger: LoggingService

    // MARK: - Initialization

    init(configuration: FirebaseConfigurationProtocol, logger: LoggingService) {
        self.configuration = configuration
        self.logger = logger
    }

    private var db: Firestore { configuration.db }
    private var auth: Auth { configuration.auth }

    // MARK: - Share Creation

    /// Create a share for a recipe with specified options
    /// - Parameters:
    ///   - recipe: The recipe to share
    ///   - options: Configuration for what to include
    ///   - context: ModelContext for SwiftData operations
    /// - Returns: Share ID and shareable URL
    func createShare(
        for recipe: Recipe,
        options: ShareOptions,
        context: ModelContext
    ) async throws -> (shareId: String, shareURL: URL) {
        guard let userId = auth.currentUser?.uid else {
            throw ShareError.notAuthenticated
        }

        logger.log("Creating Firebase share for recipe", category: .firebase, level: .info)

        // 1. Ensure recipe is uploaded to Firebase (including image)
        try await FirebaseSyncService.shared.uploadRecipe(recipe)

        // Wait briefly for image URL to be set (uploadRecipe updates it asynchronously)
        if recipe.imageFileName != nil && recipe.firebaseImageURL == nil {
            // Give it a moment to update
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        // 1.5. Fetch lineage information if this is a heirloom share
        var lineage: RecipeLineage?
        if options.shareType == .heirloom {
            lineage = try? FirebaseLineageService.shared.fetchLineage(for: recipe.id, context: context)

            // If no lineage exists and this is a heirloom share, create root lineage
            if lineage == nil {
                try await FirebaseLineageService.shared.createRootLineage(
                    recipeId: recipe.id,
                    context: context
                )
                lineage = try? FirebaseLineageService.shared.fetchLineage(for: recipe.id, context: context)
            }
        }

        // 2. Create share document
        let shareId = UUID().uuidString
        let shareData: [String: Any] = [
            "shareId": shareId,
            "recipeId": recipe.id.uuidString,
            "ownerId": userId,
            "ownerName": options.sharerName ?? "Someone",
            "recipeTitle": recipe.title,
            "shareType": options.shareType.rawValue,
            "createdAt": Timestamp(date: Date()),
            "expiresAt": options.expirationDuration?.expirationDate.map { Timestamp(date: $0) } as Any,

            // Share options
            "includeCardBack": options.includeCardBack,
            "includeRating": options.includeRating,
            "includeNotes": options.includeNotes,
            "includePinnedComments": options.includePinnedComments,
            "includeAllComments": options.includeAllComments,
            "includeCookingHistory": options.includeCookingHistory,
            "includeStickers": options.includeStickers,
            "personalMessage": options.personalMessage as Any,
            "allowReSharing": options.allowReSharing,

            // Metadata
            "generation": recipe.provenance?.generation ?? 0,
            "servings": recipe.servings as Any,
            "prepTime": recipe.prepTime as Any,
            "cookTime": recipe.cookTime as Any,
            "ingredientCount": recipe.ingredients?.count ?? 0,
            "instructionCount": recipe.instructions.count,

            // Image URL (critical for sharing with images)
            "firebaseImageURL": recipe.firebaseImageURL as Any,

            // Lineage tracking (for heirloom shares)
            "rootRecipeId": lineage?.rootRecipeId.uuidString ?? recipe.id.uuidString,
            "rootOwnerId": lineage?.rootOwnerId ?? userId,

            // Acceptance tracking
            "acceptedBy": [] as [String], // Array of user IDs who accepted
            "acceptCount": 0,
            "viewCount": 0
        ]

        // 3. Save to Firestore shares collection (top-level, not user-scoped)
        try await db.collection("shares").document(shareId).setData(shareData)

        logger.log("Firebase share created successfully", category: .firebase, level: .info)

        // 4. Generate shareable URL
        let shareURL = generateShareURL(shareId: shareId)

        // 5. Update recipe metadata
        recipe.sharedDate = Date()
        recipe.sharedBy = options.sharerName
        try context.save()

        // 6. Track analytics
        AnalyticsService.shared.track(event: .recipeShared, properties: [
            "method": "firebase",
            "share_type": options.shareType.rawValue,
            "has_message": options.personalMessage != nil
        ])

        return (shareId, shareURL)
    }

    /// Generate a shareable URL from a share ID
    func generateShareURL(shareId: String) -> URL {
        // Use heirloom:// deep link format for app launching
        // Format: heirloom://share/{shareId}
        let urlString = "heirloom://share/\(shareId)"
        return URL(string: urlString)!
    }

    /// Generate a web-friendly shareable URL
    func generateWebShareURL(shareId: String) -> URL {
        // Format: https://heirloom.app/share/{shareId}
        // This redirects to app if installed, otherwise shows web preview
        let urlString = "https://heirloom.app/share/\(shareId)"
        return URL(string: urlString)!
    }

    // MARK: - Share Acceptance

    /// Accept a shared recipe
    /// - Parameters:
    ///   - shareId: The share ID from the URL
    ///   - context: ModelContext for SwiftData operations
    /// - Returns: The accepted recipe
    func acceptShare(
        shareId: String,
        context: ModelContext
    ) async throws -> Recipe {
        guard let userId = auth.currentUser?.uid else {
            throw ShareError.notAuthenticated
        }

        logger.log("Accepting Firebase share", category: .firebase, level: .info)

        // 1. Fetch share document
        let shareDoc = try await db.collection("shares").document(shareId).getDocument()

        guard shareDoc.exists else {
            throw ShareError.shareNotFound
        }

        guard let shareData = shareDoc.data() else {
            throw ShareError.invalidShareData
        }

        // 2. Check expiration
        if let expiresAt = (shareData["expiresAt"] as? Timestamp)?.dateValue(),
           expiresAt < Date() {
            throw ShareError.shareExpired
        }

        // 3. Extract share metadata
        let recipeId = shareData["recipeId"] as? String ?? ""
        let ownerId = shareData["ownerId"] as? String ?? ""
        let shareType = ShareOptions.ShareType(rawValue: shareData["shareType"] as? String ?? "generic") ?? .generic

        // Prevent accepting own share
        if ownerId == userId {
            throw ShareError.cannotAcceptOwnShare
        }

        // Check if already accepted
        let acceptedBy = shareData["acceptedBy"] as? [String] ?? []
        if acceptedBy.contains(userId) {
            logger.log("Share already accepted by user", category: .firebase, level: .info)
            // Try to fetch the already-imported recipe
            if let existingRecipe = try? await fetchAcceptedRecipe(recipeId: recipeId, context: context) {
                return existingRecipe
            }
        }

        // 4. Fetch the shared recipe from owner's collection
        let recipeDoc = try await db.collection("users/\(ownerId)/recipes").document(recipeId).getDocument()

        guard recipeDoc.exists, let recipeData = recipeDoc.data() else {
            throw ShareError.recipeNotFound
        }

        // 5. Convert to Recipe model
        var sharedRecipe = FirebaseSyncService.shared.convertFromFirestoreData(recipeData, id: recipeId, context: context)

        // 6. Download ingredients
        let ingredientsSnapshot = try await db.collection("users/\(ownerId)/recipes/\(recipeId)/ingredients").getDocuments()
        var ingredients: [Ingredient] = []

        for ingredientDoc in ingredientsSnapshot.documents {
            let ingredientData = ingredientDoc.data()
            let ingredient = FirebaseSyncService.shared.convertIngredientFromFirestoreData(
                ingredientData,
                id: ingredientDoc.documentID
            )
            ingredient.recipe = sharedRecipe
            ingredients.append(ingredient)
            context.insert(ingredient)
        }

        sharedRecipe.ingredients = ingredients.isEmpty ? nil : ingredients

        // 7. Download comments if included
        if shareData["includePinnedComments"] as? Bool == true || shareData["includeAllComments"] as? Bool == true {
            let commentsSnapshot = try await db.collection("users/\(ownerId)/recipes/\(recipeId)/comments").getDocuments()
            var comments: [RecipeComment] = []

            for commentDoc in commentsSnapshot.documents {
                let commentData = commentDoc.data()
                let comment = FirebaseSyncService.shared.convertCommentFromFirestoreData(
                    commentData,
                    id: commentDoc.documentID
                )
                comment.recipe = sharedRecipe
                comments.append(comment)
                context.insert(comment)
            }

            sharedRecipe.comments = comments.isEmpty ? nil : comments
        }

        // 8. Download card back if included
        if shareData["includeCardBack"] as? Bool == true {
            let cardBackDoc = try await db.collection("users/\(ownerId)/recipes/\(recipeId)/cardBack").document("metadata").getDocument()

            if cardBackDoc.exists, let cardBackData = cardBackDoc.data() {
                let cardBack = FirebaseSyncService.shared.convertCardBackFromFirestoreData(cardBackData)
                cardBack.recipe = sharedRecipe
                sharedRecipe.cardBack = cardBack
                context.insert(cardBack)
            }
        }

        // 9. Download image if available
        if let firebaseImageURL = shareData["firebaseImageURL"] as? String {
            sharedRecipe.firebaseImageURL = firebaseImageURL
            try await FirebaseSyncService.shared.downloadImage(for: sharedRecipe)
        }

        // 10. Update provenance
        let generation = (shareData["generation"] as? Int ?? 0) + 1
        let ownerName = shareData["ownerName"] as? String

        sharedRecipe.provenance = ProvenanceMetadata(
            sourceType: .shared,
            sourceURL: nil,
            sourceAttribution: ownerName,
            generation: generation,
            sharedByName: ownerName,
            createdAt: Date()
        )

        sharedRecipe.sharedBy = ownerName
        sharedRecipe.sharedDate = Date()
        sharedRecipe.generationCount = generation + 1

        // 11. KEEP ORIGINAL ID for immutable recipe identity (v2.0+)
        // Original: sharedRecipe.id = UUID() // This broke lineage tracking
        // New: Keep original ID so recipe maintains identity across shares
        let originalRecipeId = sharedRecipe.id
        logger.log("Using immutable recipe ID for share", category: .firebase, level: .info)

        // Check if recipe with this ID already exists locally
        let descriptor = FetchDescriptor<Recipe>(predicate: #Predicate<Recipe> { $0.id == originalRecipeId })
        let existingRecipes = try context.fetch(descriptor)

        if let existingRecipe = existingRecipes.first {
            // Recipe already exists - merge/update instead of insert
            logger.log("Recipe already exists locally, updating instead of inserting", category: .firebase, level: .info)
            existingRecipe.title = sharedRecipe.title
            existingRecipe.instructions = sharedRecipe.instructions
            existingRecipe.ingredients = sharedRecipe.ingredients
            existingRecipe.servings = sharedRecipe.servings
            existingRecipe.prepTime = sharedRecipe.prepTime
            existingRecipe.cookTime = sharedRecipe.cookTime
            existingRecipe.notes = sharedRecipe.notes
            existingRecipe.sharedBy = ownerName
            existingRecipe.sharedDate = Date()
            existingRecipe.generationCount = generation + 1
            existingRecipe.modifiedAt = Date()

            sharedRecipe = existingRecipe // Use existing recipe for subsequent operations
        } else {
            // 12. Insert new recipe into local database (keeps original ID)
            sharedRecipe.dateAdded = Date()
            context.insert(sharedRecipe)
            logger.log("Inserted new recipe with original ID", category: .firebase, level: .info)
        }

        try context.save()

        // 13. Upload to recipient's Firebase collection (with original ID)
        try await FirebaseSyncService.shared.uploadRecipe(sharedRecipe)

        // 13.5. Create lineage record if this is a heirloom share
        if shareType == .heirloom {
            let rootRecipeIdString = shareData["rootRecipeId"] as? String ?? recipeId
            let rootOwnerId = shareData["rootOwnerId"] as? String ?? ownerId

            if let rootRecipeId = UUID(uuidString: rootRecipeIdString),
               let parentRecipeId = UUID(uuidString: recipeId) {
                do {
                    try await FirebaseLineageService.shared.createDescendantLineage(
                        rootRecipeId: rootRecipeId,
                        parentRecipeId: parentRecipeId,
                        currentRecipeId: sharedRecipe.id,
                        rootOwnerId: rootOwnerId,
                        generation: generation,
                        sharedByName: ownerName,
                        context: context
                    )
                    logger.log("Lineage record created for shared recipe", category: .firebase, level: .info)
                } catch {
                    logger.log("Failed to create lineage for shared recipe", category: .firebase, level: .warning)
                    // Continue without lineage tracking
                }
            } else {
                Log.warning("Invalid lineage IDs, skipping lineage tracking", category: .firebase)
            }
        }

        // 14. Update share document (track acceptance)
        var updatedAcceptedBy = acceptedBy
        if !updatedAcceptedBy.contains(userId) {
            updatedAcceptedBy.append(userId)
        }

        try await db.collection("shares").document(shareId).updateData([
            "acceptedBy": updatedAcceptedBy,
            "acceptCount": FieldValue.increment(Int64(1)),
            "lastAcceptedAt": Timestamp(date: Date())
        ])

        logger.log("Firebase share accepted successfully", category: .firebase, level: .info)

        // 15. Track analytics
        AnalyticsService.shared.track(event: .recipeImported, properties: [
            "source": "firebase_share",
            "method": "firebase",
            "generation": generation,
            "has_message": shareData["personalMessage"] != nil
        ])

        return sharedRecipe
    }

    // MARK: - Share Management

    /// Fetch share metadata without accepting
    func fetchShareMetadata(shareId: String) async throws -> [String: Any] {
        let shareDoc = try await db.collection("shares").document(shareId).getDocument()

        guard shareDoc.exists, let shareData = shareDoc.data() else {
            throw ShareError.shareNotFound
        }

        // Check expiration
        if let expiresAt = (shareData["expiresAt"] as? Timestamp)?.dateValue(),
           expiresAt < Date() {
            throw ShareError.shareExpired
        }

        // Increment view count
        try await db.collection("shares").document(shareId).updateData([
            "viewCount": FieldValue.increment(Int64(1))
        ])

        return shareData
    }

    /// Revoke a share (delete it)
    func revokeShare(shareId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw ShareError.notAuthenticated
        }

        // Verify ownership
        let shareDoc = try await db.collection("shares").document(shareId).getDocument()
        guard let shareData = shareDoc.data(),
              let ownerId = shareData["ownerId"] as? String,
              ownerId == userId else {
            throw ShareError.notAuthorized
        }

        // Delete share
        try await db.collection("shares").document(shareId).delete()

        logger.log("Firebase share revoked", category: .firebase, level: .info)
    }

    /// List all shares created by current user for a recipe
    func listShares(for recipe: Recipe) async throws -> [[String: Any]] {
        guard let userId = auth.currentUser?.uid else {
            throw ShareError.notAuthenticated
        }

        let snapshot = try await db.collection("shares")
            .whereField("recipeId", isEqualTo: recipe.id.uuidString)
            .whereField("ownerId", isEqualTo: userId)
            .getDocuments()

        return snapshot.documents.map { $0.data() }
    }

    // MARK: - Helper Methods

    private func fetchAcceptedRecipe(recipeId: String, context: ModelContext) async throws -> Recipe? {
        // Query local database for recipe with matching original ID
        // (This would require storing the original share recipeId in a field)
        // For now, return nil and let it re-import
        return nil
    }
}

// MARK: - Errors

extension FirebaseShareService {
    enum ShareError: LocalizedError {
        case notAuthenticated
        case notAuthorized
        case shareNotFound
        case shareExpired
        case recipeNotFound
        case invalidShareData
        case cannotAcceptOwnShare

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "You must be signed in to share recipes"
            case .notAuthorized:
                return "You don't have permission to perform this action"
            case .shareNotFound:
                return "This share link is invalid or has been deleted"
            case .shareExpired:
                return "This share link has expired"
            case .recipeNotFound:
                return "The shared recipe could not be found"
            case .invalidShareData:
                return "The share data is invalid or corrupted"
            case .cannotAcceptOwnShare:
                return "You cannot accept your own share"
            }
        }
    }
}
