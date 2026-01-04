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

    // MARK: - Singleton

    static let shared = FirebaseCollectionSync()

    private init() {}

    // MARK: - Dependencies

    private var config: FirebaseConfiguration {
        FirebaseConfiguration.shared
    }

    private var converter: FirebaseRecordConverter.Type {
        FirebaseRecordConverter.self
    }

    // MARK: - Ingredients Sync

    /// Upload ingredients for a recipe to Firestore subcollection
    /// - Parameters:
    ///   - ingredients: Array of ingredients to upload
    ///   - recipeId: Recipe ID for subcollection
    /// - Throws: FirebaseError if upload fails
    func uploadIngredients(_ ingredients: [Ingredient], for recipeId: String) async throws {
        guard config.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let ingredientsRef = try config.ingredientsSubcollection(recipeId: recipeId)

        // Delete old ingredients first
        let existingIngredients = try await ingredientsRef.getDocuments()

        if !existingIngredients.documents.isEmpty {
            Log.debug("Deleting old ingredients", category: .firebase, metadata: ["count": existingIngredients.documents.count])

            let deleteBatch = config.db.batch()
            for doc in existingIngredients.documents {
                deleteBatch.deleteDocument(doc.reference)
            }
            try await deleteBatch.commit()
        }

        // Upload new ingredients
        if !ingredients.isEmpty {
            Log.info("Uploading ingredients", category: .firebase, metadata: ["count": ingredients.count, "recipeId": recipeId])

            let uploadBatch = config.db.batch()
            for ingredient in ingredients {
                let ingredientRef = ingredientsRef.document(ingredient.id.uuidString)
                let ingredientData = converter.convertIngredientToFirestoreData(ingredient)
                uploadBatch.setData(ingredientData, forDocument: ingredientRef)
            }
            try await uploadBatch.commit()

            Log.info("Ingredients uploaded successfully", category: .firebase, metadata: ["count": ingredients.count])
        }
    }

    /// Download ingredients for a recipe from Firestore subcollection
    /// - Parameters:
    ///   - recipeId: Recipe ID for subcollection
    ///   - recipe: Recipe to attach ingredients to
    /// - Throws: FirebaseError if download fails
    func downloadIngredients(for recipeId: String, recipe: Recipe) async throws {
        guard config.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let ingredientsRef = try config.ingredientsSubcollection(recipeId: recipeId)
        let snapshot = try await ingredientsRef.getDocuments()

        Log.info("Downloaded ingredients", category: .firebase, metadata: ["count": snapshot.documents.count, "recipeId": recipeId])

        let ingredients = snapshot.documents.map { doc in
            converter.convertIngredientFromFirestoreData(doc.data(), id: doc.documentID)
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
        guard config.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let commentsRef = try config.commentsSubcollection(recipeId: recipeId)

        // Delete old comments first
        let existingComments = try await commentsRef.getDocuments()

        if !existingComments.documents.isEmpty {
            let deleteBatch = config.db.batch()
            for doc in existingComments.documents {
                deleteBatch.deleteDocument(doc.reference)
            }
            try await deleteBatch.commit()
        }

        // Upload new comments
        if !comments.isEmpty {
            let uploadBatch = config.db.batch()
            for comment in comments {
                let commentRef = commentsRef.document(comment.id.uuidString)
                let commentData = converter.convertCommentToFirestoreData(comment)
                uploadBatch.setData(commentData, forDocument: commentRef)
            }
            try await uploadBatch.commit()

            Log.info("Comments uploaded successfully", category: .firebase, metadata: ["count": comments.count, "recipeId": recipeId])
        }
    }

    /// Download comments for a recipe from Firestore subcollection
    /// - Parameters:
    ///   - recipeId: Recipe ID for subcollection
    ///   - recipe: Recipe to attach comments to
    /// - Throws: FirebaseError if download fails
    func downloadComments(for recipeId: String, recipe: Recipe) async throws {
        guard config.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let commentsRef = try config.commentsSubcollection(recipeId: recipeId)
        let snapshot = try await commentsRef.getDocuments()

        let comments = snapshot.documents.map { doc in
            converter.convertCommentFromFirestoreData(doc.data(), id: doc.documentID)
        }

        recipe.comments = comments
        Log.info("Comments downloaded successfully", category: .firebase, metadata: ["count": comments.count, "recipeId": recipeId])
    }

    // MARK: - Card Back Sync

    /// Upload card back for a recipe to Firestore
    /// - Parameters:
    ///   - cardBack: Card back to upload
    ///   - recipeId: Recipe ID
    /// - Throws: FirebaseError if upload fails
    func uploadCardBack(_ cardBack: RecipeCardBack, for recipeId: String) async throws {
        guard config.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let cardBackRef = try config.cardBackDocument(recipeId: recipeId)
        let cardBackData = converter.convertCardBackToFirestoreData(cardBack)

        try await cardBackRef.setData(cardBackData)
        Log.info("Card back uploaded successfully", category: .firebase, metadata: ["recipeId": recipeId])
    }

    /// Download card back for a recipe from Firestore
    /// - Parameters:
    ///   - recipeId: Recipe ID
    ///   - recipe: Recipe to attach card back to
    /// - Throws: FirebaseError if download fails
    func downloadCardBack(for recipeId: String, recipe: Recipe) async throws {
        guard config.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let cardBackRef = try config.cardBackDocument(recipeId: recipeId)
        let snapshot = try await cardBackRef.getDocument()

        if snapshot.exists, let data = snapshot.data() {
            recipe.cardBack = converter.convertCardBackFromFirestoreData(data)
            Log.info("Card back downloaded successfully", category: .firebase, metadata: ["recipeId": recipeId])
        }
    }

    // MARK: - Collections Sync

    /// Upload collection to Firebase
    /// - Parameter collection: RecipeCollection to upload
    /// - Throws: FirebaseError if upload fails
    func uploadCollection(_ collection: RecipeCollection) async throws {
        guard config.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let collectionRef = try config.collectionsCollection().document(collection.id.uuidString)

        var data: [String: Any] = [:]
        data["id"] = collection.id.uuidString
        data["name"] = collection.name
        data["desc"] = collection.desc as Any
        data["createdDate"] = Timestamp(date: collection.createdDate)
        data["recipeIds"] = collection.recipes?.map { $0.id.uuidString } ?? []

        try await collectionRef.setData(data)
        Log.info("Collection uploaded successfully", category: .firebase, metadata: ["name": collection.name, "collectionId": collection.id.uuidString])
    }

    /// Delete collection from Firebase
    /// - Parameter collectionId: ID of collection to delete
    /// - Throws: FirebaseError if delete fails
    func deleteCollection(_ collectionId: UUID) async throws {
        guard config.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let collectionRef = try config.collectionsCollection().document(collectionId.uuidString)
        try await collectionRef.delete()

        Log.info("Collection deleted successfully", category: .firebase, metadata: ["collectionId": collectionId.uuidString])
    }

    // MARK: - Tags Sync

    /// Upload tag to Firebase
    /// - Parameter tag: Tag to upload
    /// - Throws: FirebaseError if upload fails
    func uploadTag(_ tag: Tag) async throws {
        guard config.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let tagRef = try config.tagsCollection().document(tag.id.uuidString)

        var data: [String: Any] = [:]
        data["id"] = tag.id.uuidString
        data["name"] = tag.name
        data["color"] = tag.color
        data["recipeIds"] = tag.recipes?.map { $0.id.uuidString } ?? []

        try await tagRef.setData(data)
        Log.info("Tag uploaded successfully", category: .firebase, metadata: ["name": tag.name, "tagId": tag.id.uuidString])
    }

    /// Delete tag from Firebase
    /// - Parameter tagId: ID of tag to delete
    /// - Throws: FirebaseError if delete fails
    func deleteTag(_ tagId: UUID) async throws {
        guard config.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let tagRef = try config.tagsCollection().document(tagId.uuidString)
        try await tagRef.delete()

        Log.info("Tag deleted successfully", category: .firebase, metadata: ["tagId": tagId.uuidString])
    }

    // MARK: - Shopping Cart Sync

    /// Upload shopping cart recipe to Firebase
    /// - Parameter cartRecipe: ShoppingCartRecipe to upload
    /// - Throws: FirebaseError if upload fails
    func uploadShoppingCartRecipe(_ cartRecipe: ShoppingCartRecipe) async throws {
        guard config.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let cartRef = try config.shoppingCartCollection().document(cartRecipe.id.uuidString)

        var data: [String: Any] = [:]
        data["id"] = cartRecipe.id.uuidString
        data["recipeId"] = cartRecipe.recipe?.id.uuidString as Any
        data["targetServings"] = cartRecipe.targetServings
        data["dateAdded"] = Timestamp(date: cartRecipe.dateAdded)

        try await cartRef.setData(data)
        Log.info("Shopping cart recipe uploaded successfully", category: .firebase, metadata: ["cartRecipeId": cartRecipe.id.uuidString])
    }

    /// Delete shopping cart recipe from Firebase
    /// - Parameter cartRecipeId: ID of cart recipe to delete
    /// - Throws: FirebaseError if delete fails
    func deleteShoppingCartRecipe(_ cartRecipeId: UUID) async throws {
        guard config.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let cartRef = try config.shoppingCartCollection().document(cartRecipeId.uuidString)
        try await cartRef.delete()

        Log.info("Shopping cart recipe deleted successfully", category: .firebase, metadata: ["cartRecipeId": cartRecipeId.uuidString])
    }

    // MARK: - Dinner Parties Sync

    /// Upload dinner party to Firebase
    /// - Parameter party: DinnerParty to upload
    /// - Throws: FirebaseError if upload fails
    func uploadDinnerParty(_ party: DinnerParty) async throws {
        guard config.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let partyRef = try config.dinnerPartiesCollection().document(party.id.uuidString)

        var data: [String: Any] = [:]
        data["id"] = party.id.uuidString
        data["name"] = party.name
        data["mealTime"] = Timestamp(date: party.mealTime)
        data["guestCount"] = party.guestCount
        data["desc"] = party.desc as Any
        data["recipeIds"] = party.recipes?.map { $0.id.uuidString } ?? []
        data["createdDate"] = Timestamp(date: party.createdDate)

        try await partyRef.setData(data)
        Log.info("Dinner party uploaded successfully", category: .firebase, metadata: ["name": party.name, "partyId": party.id.uuidString])
    }

    /// Delete dinner party from Firebase
    /// - Parameter partyId: ID of dinner party to delete
    /// - Throws: FirebaseError if delete fails
    func deleteDinnerParty(_ partyId: UUID) async throws {
        guard config.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let partyRef = try config.dinnerPartiesCollection().document(partyId.uuidString)
        try await partyRef.delete()

        Log.info("Dinner party deleted successfully", category: .firebase, metadata: ["partyId": partyId.uuidString])
    }
}
