//
//  SharedRecipeData.swift
//  Heirloom
//
//  View model for displaying shared recipe preview.
//  Constructed from Firebase share metadata for UI presentation.
//

import Foundation
import FirebaseFirestore

/// View model for displaying shared recipe preview
/// Constructed from Firebase share metadata for UI presentation
struct SharedRecipeData {
    // MARK: - Identity
    let shareId: String
    let recipeId: UUID
    let title: String

    // MARK: - Sharer Info
    let sharerName: String
    let ownerId: String

    // MARK: - Lineage
    let generation: Int
    let rootRecipeId: UUID
    let rootOwnerId: String

    // MARK: - Recipe Preview Data
    let ingredients: [String]
    let instructions: [String]
    let servings: String?
    let prepTime: String?
    let cookTime: String?

    // MARK: - Share Options
    let personalMessage: String?
    let shareType: ShareOptions.ShareType
    let includeCardBack: Bool
    let includeNotes: Bool
    let includePinnedComments: Bool

    // MARK: - Expiration
    let createdAt: Date
    let expiresAt: Date?

    // MARK: - Metadata
    let imageURL: String?
    let viewCount: Int
    let acceptCount: Int

    // MARK: - Computed Properties

    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt < Date()
    }

    var generationDisplay: String {
        switch generation {
        case 0: return "Original recipe"
        case 1: return "1st generation share"
        case 2: return "2nd generation share"
        case 3: return "3rd generation share"
        default: return "\(generation)th generation share"
        }
    }

    // MARK: - Factory

    /// Construct from Firebase share metadata
    static func from(shareMetadata: [String: Any]) throws -> SharedRecipeData {
        // Extract required fields
        guard let shareId = shareMetadata["shareId"] as? String,
              let recipeIdString = shareMetadata["recipeId"] as? String,
              let recipeId = UUID(uuidString: recipeIdString),
              let title = shareMetadata["recipeTitle"] as? String,
              let sharerName = shareMetadata["ownerName"] as? String,
              let ownerId = shareMetadata["ownerId"] as? String,
              let generation = shareMetadata["generation"] as? Int,
              let shareTypeRaw = shareMetadata["shareType"] as? String else {
            throw SharedRecipeDataError.invalidMetadata
        }

        // Parse share type
        let shareType = ShareOptions.ShareType(rawValue: shareTypeRaw) ?? .generic

        // Extract lineage info
        let rootRecipeIdString = shareMetadata["rootRecipeId"] as? String ?? recipeIdString
        let rootRecipeId = UUID(uuidString: rootRecipeIdString) ?? recipeId
        let rootOwnerId = shareMetadata["rootOwnerId"] as? String ?? ownerId

        // Extract preview data (stored as arrays in share document)
        // Note: Full recipe data is fetched from owner's collection during acceptance
        let ingredients = shareMetadata["ingredientsPreview"] as? [String] ?? []
        let instructions = shareMetadata["instructionsPreview"] as? [String] ?? []

        // Extract metadata
        let servings = shareMetadata["servings"] as? String
        let prepTime = shareMetadata["prepTime"] as? String
        let cookTime = shareMetadata["cookTime"] as? String
        let personalMessage = shareMetadata["personalMessage"] as? String
        let imageURL = shareMetadata["firebaseImageURL"] as? String
        let viewCount = shareMetadata["viewCount"] as? Int ?? 0
        let acceptCount = shareMetadata["acceptCount"] as? Int ?? 0

        // Extract share options
        let includeCardBack = shareMetadata["includeCardBack"] as? Bool ?? false
        let includeNotes = shareMetadata["includeNotes"] as? Bool ?? false
        let includePinnedComments = shareMetadata["includePinnedComments"] as? Bool ?? false

        // Extract timestamps
        let createdAt = (shareMetadata["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let expiresAt = (shareMetadata["expiresAt"] as? Timestamp)?.dateValue()

        return SharedRecipeData(
            shareId: shareId,
            recipeId: recipeId,
            title: title,
            sharerName: sharerName,
            ownerId: ownerId,
            generation: generation,
            rootRecipeId: rootRecipeId,
            rootOwnerId: rootOwnerId,
            ingredients: ingredients,
            instructions: instructions,
            servings: servings,
            prepTime: prepTime,
            cookTime: cookTime,
            personalMessage: personalMessage,
            shareType: shareType,
            includeCardBack: includeCardBack,
            includeNotes: includeNotes,
            includePinnedComments: includePinnedComments,
            createdAt: createdAt,
            expiresAt: expiresAt,
            imageURL: imageURL,
            viewCount: viewCount,
            acceptCount: acceptCount
        )
    }
}

enum SharedRecipeDataError: LocalizedError {
    case invalidMetadata

    var errorDescription: String? {
        switch self {
        case .invalidMetadata:
            return "Invalid share metadata - missing required fields"
        }
    }
}
