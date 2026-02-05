//
//  PublicRecipe.swift
//  Heirloom
//
//  Public recipe model for discovery feature
//  Stored in Firestore publicRecipes collection
//

import Foundation
import FirebaseFirestore

/// Public recipe document stored in Firestore
/// Read-only snapshot of a user's recipe made available for discovery
struct PublicRecipe: Codable, Identifiable {
    /// Firestore document ID (auto-generated)
    let id: String

    /// Reference to original Recipe.id in user's local SwiftData
    let sourceRecipeId: String

    /// Firebase User ID of recipe owner
    let ownerId: String

    // MARK: - Recipe Content

    var title: String
    var description: String?
    var imageURL: String?

    /// Ingredient names only (for search and display)
    var ingredients: [String]

    var category: String?
    var tags: [String]
    var servings: String?
    var prepTime: String?
    var cookTime: String?

    // MARK: - Creator Attribution

    var creatorName: String
    var creatorPhotoURL: String?
    var creatorProfileSlug: String?

    // MARK: - Engagement Metrics

    var viewCount: Int
    var saveCount: Int

    // MARK: - Search Optimization

    /// Lowercase keywords for search (title + ingredients + creator)
    var searchKeywords: [String]

    // MARK: - Moderation

    /// Whether this recipe has been hidden due to reports
    var isHidden: Bool
    /// Number of user reports received
    var reportCount: Int
    /// Moderation status: nil, "pending_review", "approved", "hidden"
    var moderationStatus: String?

    // MARK: - Timestamps

    let publishedAt: Date
    var updatedAt: Date

    // MARK: - Firestore Encoding

    enum CodingKeys: String, CodingKey {
        case id
        case sourceRecipeId
        case ownerId
        case title
        case description
        case imageURL
        case ingredients
        case category
        case tags
        case servings
        case prepTime
        case cookTime
        case creatorName
        case creatorPhotoURL
        case creatorProfileSlug
        case viewCount
        case saveCount
        case searchKeywords
        case isHidden
        case reportCount
        case moderationStatus
        case publishedAt
        case updatedAt
    }

    // MARK: - Search Keywords Generation

    /// Generate search keywords from recipe content
    /// Filters words >= 3 characters and lowercases
    static func generateSearchKeywords(
        title: String,
        ingredients: [String],
        creatorName: String
    ) -> [String] {
        var keywords = Set<String>()

        // Add title words
        let titleWords = title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
        keywords.formUnion(titleWords)

        // Add ingredient words
        for ingredient in ingredients {
            let ingredientWords = ingredient
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 3 }
            keywords.formUnion(ingredientWords)
        }

        // Add creator name words
        let creatorWords = creatorName
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
        keywords.formUnion(creatorWords)

        return Array(keywords).sorted()
    }

    // MARK: - Validation

    /// Check if recipe content is suitable for publishing
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !ingredients.isEmpty &&
        !creatorName.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Firestore Timestamp Conversion

extension PublicRecipe {
    /// Decode from Firestore document data
    init(from document: DocumentSnapshot) throws {
        guard let data = document.data() else {
            throw NSError(
                domain: "PublicRecipe",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Document data not found"]
            )
        }

        self.id = document.documentID
        self.sourceRecipeId = data["sourceRecipeId"] as? String ?? ""
        self.ownerId = data["ownerId"] as? String ?? ""
        self.title = data["title"] as? String ?? ""
        self.description = data["description"] as? String
        self.imageURL = data["imageURL"] as? String
        self.ingredients = data["ingredients"] as? [String] ?? []
        self.category = data["category"] as? String
        self.tags = data["tags"] as? [String] ?? []
        self.servings = data["servings"] as? String
        self.prepTime = data["prepTime"] as? String
        self.cookTime = data["cookTime"] as? String
        self.creatorName = data["creatorName"] as? String ?? ""
        self.creatorPhotoURL = data["creatorPhotoURL"] as? String
        self.creatorProfileSlug = data["creatorProfileSlug"] as? String
        self.viewCount = data["viewCount"] as? Int ?? 0
        self.saveCount = data["saveCount"] as? Int ?? 0
        self.searchKeywords = data["searchKeywords"] as? [String] ?? []

        // Moderation fields
        self.isHidden = data["isHidden"] as? Bool ?? false
        self.reportCount = data["reportCount"] as? Int ?? 0
        self.moderationStatus = data["moderationStatus"] as? String

        // Convert Firestore Timestamps to Date
        if let timestamp = data["publishedAt"] as? Timestamp {
            self.publishedAt = timestamp.dateValue()
        } else {
            self.publishedAt = Date()
        }

        if let timestamp = data["updatedAt"] as? Timestamp {
            self.updatedAt = timestamp.dateValue()
        } else {
            self.updatedAt = Date()
        }
    }

    /// Convert to Firestore document data
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "sourceRecipeId": sourceRecipeId,
            "ownerId": ownerId,
            "title": title,
            "ingredients": ingredients,
            "tags": tags,
            "creatorName": creatorName,
            "viewCount": viewCount,
            "saveCount": saveCount,
            "searchKeywords": searchKeywords,
            "isHidden": isHidden,
            "reportCount": reportCount,
            "publishedAt": Timestamp(date: publishedAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]

        if let moderationStatus = moderationStatus {
            data["moderationStatus"] = moderationStatus
        }

        // Add optional fields
        if let description = description {
            data["description"] = description
        }
        if let imageURL = imageURL {
            data["imageURL"] = imageURL
        }
        if let category = category {
            data["category"] = category
        }
        if let servings = servings {
            data["servings"] = servings
        }
        if let prepTime = prepTime {
            data["prepTime"] = prepTime
        }
        if let cookTime = cookTime {
            data["cookTime"] = cookTime
        }
        if let creatorPhotoURL = creatorPhotoURL {
            data["creatorPhotoURL"] = creatorPhotoURL
        }
        if let creatorProfileSlug = creatorProfileSlug {
            data["creatorProfileSlug"] = creatorProfileSlug
        }

        return data
    }
}
