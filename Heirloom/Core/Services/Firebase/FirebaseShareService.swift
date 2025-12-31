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
class FirebaseShareService: ObservableObject {

    // MARK: - Singleton

    static let shared = FirebaseShareService()

    private init() {}

    // MARK: - Dependencies

    private let db = Firestore.firestore()
    private var auth: Auth { Auth.auth() }

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

        print("📤 [Firebase Share] Creating share for recipe: \(recipe.title)")

        // 1. Ensure recipe is uploaded to Firebase
        try await FirebaseSyncService.shared.uploadRecipe(recipe)

        // 2. Create share document
        let shareId = UUID().uuidString
        let shareData: [String: Any] = [
            "shareId": shareId,
            "recipeId": recipe.id.uuidString,
            "ownerId": userId,
            "ownerName": options.sharerName ?? "Someone",
            "recipeTitle": recipe.title,
            "permission": options.permission.rawValue,
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

            // Acceptance tracking
            "acceptedBy": [] as [String], // Array of user IDs who accepted
            "acceptCount": 0,
            "viewCount": 0
        ]

        // 3. Save to Firestore shares collection (top-level, not user-scoped)
        try await db.collection("shares").document(shareId).setData(shareData)

        print("✅ [Firebase Share] Share created: \(shareId)")

        // 4. Generate shareable URL
        let shareURL = generateShareURL(shareId: shareId)

        // 5. Update recipe metadata
        recipe.sharedDate = Date()
        recipe.sharedBy = options.sharerName
        try context.save()

        // 6. Track analytics
        AnalyticsService.shared.track(event: .recipeShared, properties: [
            "method": "firebase",
            "permission": options.permission.rawValue,
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

        print("📥 [Firebase Share] Accepting share: \(shareId)")

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
        let permission = ShareOptions.SharePermission(rawValue: shareData["permission"] as? String ?? "readOnly") ?? .readOnly

        // Prevent accepting own share
        if ownerId == userId {
            throw ShareError.cannotAcceptOwnShare
        }

        // Check if already accepted
        let acceptedBy = shareData["acceptedBy"] as? [String] ?? []
        if acceptedBy.contains(userId) {
            print("ℹ️ [Firebase Share] Already accepted this share")
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
        let sharedRecipe = FirebaseSyncService.shared.convertFromFirestoreData(recipeData, id: recipeId, context: context)

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

        // 11. Create new ID for the imported recipe (copy, not reference)
        sharedRecipe.id = UUID()
        sharedRecipe.dateAdded = Date()

        // 12. Insert into local database
        context.insert(sharedRecipe)
        try context.save()

        // 13. Upload to recipient's Firebase collection
        try await FirebaseSyncService.shared.uploadRecipe(sharedRecipe)

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

        print("✅ [Firebase Share] Share accepted successfully")

        // 15. Track analytics
        AnalyticsService.shared.track(event: .recipeReceived, properties: [
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

        print("✅ [Firebase Share] Share revoked: \(shareId)")
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
