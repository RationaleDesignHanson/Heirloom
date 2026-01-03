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
class FirebaseCollectionSync {

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
            print("🗑️ [Firebase] Deleting \(existingIngredients.documents.count) old ingredients")

            let deleteBatch = config.db.batch()
            for doc in existingIngredients.documents {
                deleteBatch.deleteDocument(doc.reference)
            }
            try await deleteBatch.commit()
        }

        // Upload new ingredients
        if !ingredients.isEmpty {
            print("📤 [Firebase] Uploading \(ingredients.count) ingredients")

            let uploadBatch = config.db.batch()
            for ingredient in ingredients {
                let ingredientRef = ingredientsRef.document(ingredient.id.uuidString)
                let ingredientData = converter.convertIngredientToFirestoreData(ingredient)
                uploadBatch.setData(ingredientData, forDocument: ingredientRef)
            }
            try await uploadBatch.commit()

            print("✅ [Firebase] Ingredients uploaded")
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

        print("📥 [Firebase] Downloaded \(snapshot.documents.count) ingredients")

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

            print("✅ [Firebase] Comments uploaded: \(comments.count)")
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
        print("✅ [Firebase] Comments downloaded: \(comments.count)")
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
        print("✅ [Firebase] Card back uploaded")
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
            print("✅ [Firebase] Card back downloaded")
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
        print("✅ [Firebase] Collection uploaded: \(collection.name)")
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

        print("✅ [Firebase] Collection deleted: \(collectionId.uuidString)")
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
        print("✅ [Firebase] Tag uploaded: \(tag.name)")
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

        print("✅ [Firebase] Tag deleted: \(tagId.uuidString)")
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
        print("✅ [Firebase] Shopping cart recipe uploaded")
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

        print("✅ [Firebase] Shopping cart recipe deleted")
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
        print("✅ [Firebase] Dinner party uploaded: \(party.name)")
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

        print("✅ [Firebase] Dinner party deleted")
    }
}
