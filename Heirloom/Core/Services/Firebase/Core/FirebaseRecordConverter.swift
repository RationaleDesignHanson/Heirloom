//
//  FirebaseRecordConverter.swift
//  Heirloom
//
//  Phase 2 Week 3: Service Layer Refactoring
//  Pure data transformation logic for Firestore serialization
//

import Foundation
import SwiftData
import FirebaseFirestore

/// Pure data conversion utilities for Firestore serialization
/// No side effects, no I/O - just data transformations
struct FirebaseRecordConverter: FirebaseRecordConverterProtocol {

    // MARK: - Recipe Conversion

    /// Convert Recipe model to Firestore document data
    static func convertToFirestoreData(_ recipe: Recipe) -> [String: Any] {
        var data: [String: Any] = [:]

        // Identity
        data["id"] = recipe.id.uuidString
        data["title"] = recipe.title

        // Source information
        if let sourceType = recipe.sourceType {
            data["sourceType"] = sourceType.rawValue
        }
        data["sourceURL"] = recipe.sourceURL as Any

        // Content
        data["imageFileName"] = recipe.imageFileName as Any
        data["sourceImageURL"] = recipe.sourceImageURL as Any
        data["firebaseImageURL"] = recipe.firebaseImageURL as Any
        data["instructions"] = recipe.instructions
        data["servings"] = recipe.servings as Any
        data["prepTime"] = recipe.prepTime as Any
        data["cookTime"] = recipe.cookTime as Any
        data["notes"] = recipe.notes as Any

        // Metadata
        data["timesCooked"] = recipe.timesCooked
        data["lastCooked"] = recipe.lastCooked as Any
        data["isFavorite"] = recipe.isFavorite
        print("🔍 [Converter] Converting recipe '\(recipe.title)' - isFavorite=\(recipe.isFavorite)")

        // Timestamps
        data["createdAt"] = Timestamp(date: recipe.createdAt)
        data["modifiedAt"] = Timestamp(date: recipe.modifiedAt)

        // Social/Sharing
        data["sharedBy"] = recipe.sharedBy as Any
        data["sharedDate"] = recipe.sharedDate.map { Timestamp(date: $0) } as Any
        data["passedDownMessage"] = recipe.passedDownMessage as Any
        data["generationCount"] = recipe.generationCount

        // Provenance (as JSON string)
        if let provenance = recipe.provenance,
           let provenanceData = try? JSONEncoder().encode(provenance),
           let provenanceString = String(data: provenanceData, encoding: .utf8) {
            data["provenanceJSON"] = provenanceString
        }

        // Tags and Collections
        data["tagIds"] = recipe.tags?.map { $0.id.uuidString } ?? []
        data["collectionIds"] = recipe.collections?.map { $0.id.uuidString } ?? []

        // Sync metadata
        data["lastSyncedAt"] = Timestamp(date: Date())

        return data
    }

    /// Convert Firestore document to Recipe model
    static func convertFromFirestoreData(_ data: [String: Any], id: String, context: ModelContext) -> Recipe {
        // Basic info
        let title = data["title"] as? String ?? "Untitled"
        let sourceTypeString = data["sourceType"] as? String ?? "manual"
        let sourceType = RecipeSourceType(rawValue: sourceTypeString) ?? .manual

        // Instructions
        let instructions = data["instructions"] as? [String] ?? []

        // Create recipe
        let recipe = Recipe(
            title: title,
            sourceType: sourceType,
            sourceURL: data["sourceURL"] as? String,
            instructions: instructions,
            servings: data["servings"] as? String,
            prepTime: data["prepTime"] as? String,
            cookTime: data["cookTime"] as? String
        )

        // Set ID from Firestore document ID
        recipe.id = UUID(uuidString: id) ?? UUID()

        // Additional fields
        recipe.notes = data["notes"] as? String
        recipe.isFavorite = data["isFavorite"] as? Bool ?? false
        recipe.timesCooked = data["timesCooked"] as? Int ?? 0

        // Image fields
        recipe.imageFileName = data["imageFileName"] as? String
        recipe.sourceImageURL = data["sourceImageURL"] as? String
        recipe.firebaseImageURL = data["firebaseImageURL"] as? String

        // Timestamps
        if let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() {
            recipe.createdAt = createdAt
        }
        if let modifiedAt = (data["modifiedAt"] as? Timestamp)?.dateValue() {
            recipe.modifiedAt = modifiedAt
        }
        if let lastCooked = (data["lastCooked"] as? Timestamp)?.dateValue() {
            recipe.lastCooked = lastCooked
        }

        // Provenance
        if let provenanceString = data["provenanceJSON"] as? String,
           let provenanceData = provenanceString.data(using: .utf8),
           let provenance = try? JSONDecoder().decode(ProvenanceMetadata.self, from: provenanceData) {
            recipe.provenance = provenance
        }

        // Social/Sharing
        recipe.sharedBy = data["sharedBy"] as? String
        if let sharedDate = (data["sharedDate"] as? Timestamp)?.dateValue() {
            recipe.sharedDate = sharedDate
        }
        recipe.passedDownMessage = data["passedDownMessage"] as? String
        recipe.generationCount = data["generationCount"] as? Int ?? 0

        // Sync metadata
        recipe.lastSyncedAt = Date()

        return recipe
    }

    // MARK: - Ingredient Conversion

    /// Convert Ingredient to Firestore document data
    static func convertIngredientToFirestoreData(_ ingredient: Ingredient) -> [String: Any] {
        var data: [String: Any] = [:]

        data["id"] = ingredient.id.uuidString
        data["originalText"] = ingredient.originalText
        data["name"] = ingredient.name
        data["quantity"] = ingredient.quantity as Any
        data["quantityMax"] = ingredient.quantityMax as Any
        data["unit"] = ingredient.unit as Any
        data["normalizedUnit"] = ingredient.normalizedUnit as Any
        data["preparation"] = ingredient.preparation as Any
        data["size"] = ingredient.size as Any

        if let category = ingredient.category {
            data["category"] = category.rawValue
        }
        data["orderIndex"] = ingredient.orderIndex

        data["isSelected"] = ingredient.isSelected
        data["isCheckedOff"] = ingredient.isCheckedOff
        data["isOptional"] = ingredient.isOptional

        return data
    }

    /// Convert Firestore document to Ingredient
    static func convertIngredientFromFirestoreData(_ data: [String: Any], id: String) -> Ingredient {
        let ingredient = Ingredient(
            originalText: data["originalText"] as? String ?? "",
            name: data["name"] as? String ?? "",
            quantity: data["quantity"] as? Double,
            unit: data["unit"] as? String,
            category: GroceryCategory(rawValue: data["category"] as? String ?? "") ?? .other,
            orderIndex: data["orderIndex"] as? Int ?? 0
        )

        ingredient.id = UUID(uuidString: id) ?? UUID()
        ingredient.quantityMax = data["quantityMax"] as? Double
        ingredient.normalizedUnit = data["normalizedUnit"] as? String
        ingredient.preparation = data["preparation"] as? String
        ingredient.size = data["size"] as? String
        ingredient.isSelected = data["isSelected"] as? Bool ?? false
        ingredient.isCheckedOff = data["isCheckedOff"] as? Bool ?? false
        ingredient.isOptional = data["isOptional"] as? Bool ?? false

        return ingredient
    }

    // MARK: - Comment Conversion

    /// Convert RecipeComment to Firestore document data
    static func convertCommentToFirestoreData(_ comment: RecipeComment) -> [String: Any] {
        var data: [String: Any] = [:]

        data["id"] = comment.id.uuidString
        data["text"] = comment.text
        data["authorName"] = comment.authorName as Any
        data["createdAt"] = Timestamp(date: comment.createdAt)
        data["isPinned"] = comment.isPinned
        data["sentimentScore"] = comment.sentimentScore as Any

        return data
    }

    /// Convert Firestore document to RecipeComment
    static func convertCommentFromFirestoreData(_ data: [String: Any], id: String) -> RecipeComment {
        let comment = RecipeComment(
            text: data["text"] as? String ?? "",
            authorName: data["authorName"] as? String
        )

        comment.id = UUID(uuidString: id) ?? UUID()
        if let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() {
            comment.createdAt = createdAt
        }
        comment.isPinned = data["isPinned"] as? Bool ?? false
        comment.sentimentScore = data["sentimentScore"] as? Double

        return comment
    }

    // MARK: - Card Back Conversion

    /// Convert RecipeCardBack to Firestore document data
    static func convertCardBackToFirestoreData(_ cardBack: RecipeCardBack) -> [String: Any] {
        var data: [String: Any] = [:]

        data["noteToFriends"] = cardBack.noteToFriends as Any
        data["personalTips"] = cardBack.personalTips
        data["userRating"] = cardBack.userRating as Any
        data["showAttribution"] = cardBack.showAttribution
        data["customAttributionText"] = cardBack.customAttributionText as Any
        data["attributionPosition"] = cardBack.attributionPosition.rawValue
        data["pinnedCommentIDs"] = cardBack.pinnedCommentIDs.map { $0.uuidString }
        data["maxCommentsToDisplay"] = cardBack.maxCommentsToDisplay
        data["backgroundStyle"] = cardBack.backgroundStyle.rawValue
        data["textColor"] = cardBack.textColor
        data["visibleSections"] = cardBack.visibleSections.map { $0.rawValue }

        return data
    }

    /// Convert Firestore document to RecipeCardBack
    static func convertCardBackFromFirestoreData(_ data: [String: Any]) -> RecipeCardBack {
        let cardBack = RecipeCardBack()

        cardBack.noteToFriends = data["noteToFriends"] as? String
        cardBack.personalTips = data["personalTips"] as? [String] ?? []
        cardBack.userRating = data["userRating"] as? Int
        cardBack.showAttribution = data["showAttribution"] as? Bool ?? true
        cardBack.customAttributionText = data["customAttributionText"] as? String

        if let position = data["attributionPosition"] as? String,
           let positionEnum = AttributionPosition(rawValue: position) {
            cardBack.attributionPosition = positionEnum
        }

        if let commentIDs = data["pinnedCommentIDs"] as? [String] {
            cardBack.pinnedCommentIDs = commentIDs.compactMap { UUID(uuidString: $0) }
        }

        if let maxComments = data["maxCommentsToDisplay"] as? Int {
            cardBack.maxCommentsToDisplay = maxComments
        }

        if let bgStyle = data["backgroundStyle"] as? String,
           let styleEnum = CardBackgroundStyle(rawValue: bgStyle) {
            cardBack.backgroundStyle = styleEnum
        }

        if let textColor = data["textColor"] as? String {
            cardBack.textColor = textColor
        }

        if let sections = data["visibleSections"] as? [String] {
            cardBack.visibleSections = sections.compactMap { CardBackSection(rawValue: $0) }
        }

        return cardBack
    }
}
