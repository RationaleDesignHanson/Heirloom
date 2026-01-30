//
//  FirebaseCollectionSync.swift
//  Heirloom
//
//  Phase 2 Week 3: Service Layer Refactoring
//  Sync operations for related entities (ingredients, comments, collections, tags, etc.)
//

import Foundation
import SwiftData
import FirebaseFirestore

/// Handles sync for recipe-related entities and collections
/// Responsibilities: Ingredients, Comments, Collections, Tags, Shopping Cart, Dinner Parties
@MainActor
class FirebaseCollectionSync: FirebaseCollectionSyncProtocol {

    // MARK: - Dependencies

    private let configuration: FirebaseConfiguration
    private let converter: FirebaseRecordConverter
    private let logger: LoggingService

    // MARK: - Initialization

    init(configuration: FirebaseConfiguration, converter: FirebaseRecordConverter, logger: LoggingService) {
        self.configuration = configuration
        self.converter = converter
        self.logger = logger
    }

    // MARK: - Ingredients Sync

    /// Upload ingredients for a recipe to Firestore subcollection
    /// - Parameters:
    ///   - ingredients: Array of ingredients to upload
    ///   - recipeId: Recipe ID for subcollection
    /// - Throws: FirebaseError if upload fails
    func uploadIngredients(_ ingredients: [Ingredient], for recipeId: String) async throws {
        guard configuration.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let ingredientsRef = try configuration.ingredientsSubcollection(recipeId: recipeId)

        // Delete old ingredients first
        let existingIngredients = try await ingredientsRef.getDocuments()

        if !existingIngredients.documents.isEmpty {
            logger.log("Deleting old ingredients", category: .sync, level: .debug, metadata: nil)

            let deleteBatch = configuration.db.batch()
            for doc in existingIngredients.documents {
                deleteBatch.deleteDocument(doc.reference)
            }
            try await deleteBatch.commit()
        }

        // Upload new ingredients
        if !ingredients.isEmpty {
            logger.log("Uploading ingredients", category: .sync, level: .info, metadata: nil)

            let uploadBatch = configuration.db.batch()
            for ingredient in ingredients {
                let ingredientRef = ingredientsRef.document(ingredient.id.uuidString)
                let ingredientData = FirebaseRecordConverter.convertIngredientToFirestoreData(ingredient)
                uploadBatch.setData(ingredientData, forDocument: ingredientRef)
            }
            try await uploadBatch.commit()

            logger.log("Ingredients uploaded successfully", category: .sync, level: .info, metadata: nil)
        }
    }

    /// Download ingredients for a recipe from Firestore subcollection
    /// - Parameters:
    ///   - recipeId: Recipe ID for subcollection
    ///   - recipe: Recipe to attach ingredients to
    /// - Throws: FirebaseError if download fails
    func downloadIngredients(for recipeId: String, recipe: Recipe) async throws {
        guard configuration.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let ingredientsRef = try configuration.ingredientsSubcollection(recipeId: recipeId)
        let snapshot = try await ingredientsRef.getDocuments()

        logger.log("Downloaded ingredients", category: .sync, level: .info, metadata: nil)

        let ingredients = snapshot.documents.map { doc in
            FirebaseRecordConverter.convertIngredientFromFirestoreData(doc.data(), id: doc.documentID)
        }

        // Sort by orderIndex
        recipe.ingredients = ingredients.sorted { $0.orderIndex < $1.orderIndex }
    }

    // MARK: - Comments Sync

    /// Upload comments for a recipe to Firestore subcollection
    /// - Parameters:
    ///   - comments: Array of comments to upload
    ///   - recipeId: Recipe ID for subcollection
    /// - Throws: FirebaseError if upload fails
    func uploadComments(_ comments: [RecipeComment], for recipeId: String) async throws {
        guard configuration.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let commentsRef = try configuration.commentsSubcollection(recipeId: recipeId)

        // Delete old comments first
        let existingComments = try await commentsRef.getDocuments()

        if !existingComments.documents.isEmpty {
            let deleteBatch = configuration.db.batch()
            for doc in existingComments.documents {
                deleteBatch.deleteDocument(doc.reference)
            }
            try await deleteBatch.commit()
        }

        // Upload new comments
        if !comments.isEmpty {
            let uploadBatch = configuration.db.batch()
            for comment in comments {
                let commentRef = commentsRef.document(comment.id.uuidString)
                let commentData = FirebaseRecordConverter.convertCommentToFirestoreData(comment)
                uploadBatch.setData(commentData, forDocument: commentRef)
            }
            try await uploadBatch.commit()

            logger.log("Comments uploaded successfully", category: .sync, level: .info, metadata: nil)
        }
    }

    /// Download comments for a recipe from Firestore subcollection
    /// - Parameters:
    ///   - recipeId: Recipe ID for subcollection
    ///   - recipe: Recipe to attach comments to
    /// - Throws: FirebaseError if download fails
    func downloadComments(for recipeId: String, recipe: Recipe) async throws {
        guard configuration.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let commentsRef = try configuration.commentsSubcollection(recipeId: recipeId)
        let snapshot = try await commentsRef.getDocuments()

        let comments = snapshot.documents.map { doc in
            FirebaseRecordConverter.convertCommentFromFirestoreData(doc.data(), id: doc.documentID)
        }

        recipe.comments = comments
        logger.log("Comments downloaded successfully", category: .sync, level: .info, metadata: nil)
    }

    // MARK: - Card Back Sync

    /// Upload card back for a recipe to Firestore
    /// - Parameters:
    ///   - cardBack: Card back to upload
    ///   - recipeId: Recipe ID
    /// - Throws: FirebaseError if upload fails
    func uploadCardBack(_ cardBack: RecipeCardBack, for recipeId: String) async throws {
        guard configuration.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let cardBackRef = try configuration.cardBackDocument(recipeId: recipeId)
        let cardBackData = FirebaseRecordConverter.convertCardBackToFirestoreData(cardBack)

        try await cardBackRef.setData(cardBackData)
        logger.log("Card back uploaded successfully", category: .sync, level: .info, metadata: nil)
    }

    /// Download card back for a recipe from Firestore
    /// - Parameters:
    ///   - recipeId: Recipe ID
    ///   - recipe: Recipe to attach card back to
    /// - Throws: FirebaseError if download fails
    func downloadCardBack(for recipeId: String, recipe: Recipe) async throws {
        guard configuration.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let cardBackRef = try configuration.cardBackDocument(recipeId: recipeId)
        let snapshot = try await cardBackRef.getDocument()

        if snapshot.exists, let data = snapshot.data() {
            recipe.cardBack = FirebaseRecordConverter.convertCardBackFromFirestoreData(data)
            logger.log("Card back downloaded successfully", category: .sync, level: .info, metadata: nil)
        }
    }

    // MARK: - Collections Sync

    /// Upload collection to Firebase
    /// - Parameter collection: RecipeCollection to upload
    /// - Throws: FirebaseError if upload fails
    func uploadCollection(_ collection: RecipeCollection) async throws {
        guard configuration.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let collectionRef = try configuration.collectionsCollection().document(collection.id.uuidString)

        var data: [String: Any] = [:]
        data["id"] = collection.id.uuidString
        data["name"] = collection.name
        data["desc"] = collection.desc as Any
        data["createdDate"] = Timestamp(date: collection.createdDate)
        data["recipeIds"] = collection.recipes?.map { $0.id.uuidString } ?? []

        try await collectionRef.setData(data)
        logger.log("Collection uploaded successfully", category: .sync, level: .info, metadata: nil)
    }

    /// Delete collection from Firebase
    /// - Parameter collectionId: ID of collection to delete
    /// - Throws: FirebaseError if delete fails
    func deleteCollection(_ collectionId: UUID) async throws {
        guard configuration.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let collectionRef = try configuration.collectionsCollection().document(collectionId.uuidString)
        try await collectionRef.delete()

        logger.log("Collection deleted successfully", category: .sync, level: .info, metadata: nil)
    }

    // MARK: - Tags Sync

    /// Upload tag to Firebase
    /// - Parameter tag: Tag to upload
    /// - Throws: FirebaseError if upload fails
    func uploadTag(_ tag: Tag) async throws {
        guard configuration.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let tagRef = try configuration.tagsCollection().document(tag.id.uuidString)

        var data: [String: Any] = [:]
        data["id"] = tag.id.uuidString
        data["name"] = tag.name
        data["color"] = tag.color
        data["recipeIds"] = tag.recipes?.map { $0.id.uuidString } ?? []

        try await tagRef.setData(data)
        logger.log("Tag uploaded successfully", category: .sync, level: .info, metadata: nil)
    }

    /// Delete tag from Firebase
    /// - Parameter tagId: ID of tag to delete
    /// - Throws: FirebaseError if delete fails
    func deleteTag(_ tagId: UUID) async throws {
        guard configuration.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let tagRef = try configuration.tagsCollection().document(tagId.uuidString)
        try await tagRef.delete()

        logger.log("Tag deleted successfully", category: .sync, level: .info, metadata: nil)
    }

    // MARK: - Shopping Cart Sync

    /// Upload shopping cart recipe to Firebase
    /// - Parameter cartRecipe: ShoppingCartRecipe to upload
    /// - Throws: FirebaseError if upload fails
    func uploadShoppingCartRecipe(_ cartRecipe: ShoppingCartRecipe) async throws {
        guard configuration.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let cartRef = try configuration.shoppingCartCollection().document(cartRecipe.id.uuidString)

        var data: [String: Any] = [:]
        data["id"] = cartRecipe.id.uuidString
        data["recipeId"] = cartRecipe.recipe?.id.uuidString as Any
        data["targetServings"] = cartRecipe.targetServings
        data["dateAdded"] = Timestamp(date: cartRecipe.dateAdded)

        try await cartRef.setData(data)
        logger.log("Shopping cart recipe uploaded successfully", category: .sync, level: .info, metadata: nil)
    }

    /// Delete shopping cart recipe from Firebase
    /// - Parameter cartRecipeId: ID of cart recipe to delete
    /// - Throws: FirebaseError if delete fails
    func deleteShoppingCartRecipe(_ cartRecipeId: UUID) async throws {
        guard configuration.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let cartRef = try configuration.shoppingCartCollection().document(cartRecipeId.uuidString)
        try await cartRef.delete()

        logger.log("Shopping cart recipe deleted successfully", category: .sync, level: .info, metadata: nil)
    }

    // MARK: - Dinner Parties Sync

    /// Upload dinner party to Firebase
    /// - Parameter party: DinnerParty to upload
    /// - Throws: FirebaseError if upload fails
    func uploadDinnerParty(_ party: DinnerParty) async throws {
        guard configuration.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let partyRef = try configuration.dinnerPartiesCollection().document(party.id.uuidString)

        var data: [String: Any] = [:]
        data["id"] = party.id.uuidString
        data["name"] = party.name
        data["mealTime"] = Timestamp(date: party.mealTime)
        data["guestCount"] = party.guestCount
        data["desc"] = party.desc as Any
        data["recipeIds"] = party.recipes?.map { $0.id.uuidString } ?? []
        data["createdDate"] = Timestamp(date: party.createdDate)

        try await partyRef.setData(data)
        logger.log("Meal plan uploaded successfully", category: .sync, level: .info, metadata: nil)
    }

    /// Delete dinner party from Firebase
    /// - Parameter partyId: ID of dinner party to delete
    /// - Throws: FirebaseError if delete fails
    func deleteDinnerParty(_ partyId: UUID) async throws {
        guard configuration.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let partyRef = try configuration.dinnerPartiesCollection().document(partyId.uuidString)
        try await partyRef.delete()

        logger.log("Meal plan deleted successfully", category: .sync, level: .info, metadata: nil)
    }
}
