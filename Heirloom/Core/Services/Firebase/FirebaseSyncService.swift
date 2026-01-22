//
//  FirebaseSyncService.swift
//  Heirloom
//
//  Created during Firebase Migration - Phase 2
//  Handles sync between local SwiftData and Firebase Firestore
//

import Foundation
import SwiftData
import UIKit
import os.log
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

/// Firebase sync service for hybrid architecture
/// Mirrors CloudKitSyncService API but uses Firestore backend
@MainActor
class FirebaseSyncService: ObservableObject, FirebaseSyncServiceProtocol {

    // MARK: - Dependencies

    private let configuration: FirebaseConfiguration
    private let recipeSync: FirebaseRecipeSync
    private let collectionSync: FirebaseCollectionSync
    private let imageService: FirebaseImageService
    private let lineageService: FirebaseLineageService
    private let logger: LoggingService
    internal let crdtMergeEngine: CRDTMergeEngine

    // MARK: - Published State

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published private(set) var syncError: Error?

    // MARK: - Sync State

    internal var modelContext: ModelContext?
    private var isAutoSyncEnabled = false

    // MARK: - Initialization

    init(
        configuration: FirebaseConfiguration,
        recipeSync: FirebaseRecipeSync,
        collectionSync: FirebaseCollectionSync,
        imageService: FirebaseImageService,
        lineageService: FirebaseLineageService,
        logger: LoggingService,
        crdtMergeEngine: CRDTMergeEngine
    ) {
        self.configuration = configuration
        self.recipeSync = recipeSync
        self.collectionSync = collectionSync
        self.imageService = imageService
        self.lineageService = lineageService
        self.logger = logger
        self.crdtMergeEngine = crdtMergeEngine
    }

    private var db: Firestore { configuration.db }
    private var auth: Auth { configuration.auth }

    // MARK: - Configuration

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext

        // Access db to trigger lazy initialization with settings
        _ = db

        logger.log("🔥 [Firebase] FirebaseSyncService configured", category: .sync, level: .info, metadata: nil)
        Log.info("FirebaseSyncService configured", category: .firebase)
    }

    // MARK: - User Authentication

    /// Get current user ID (required for all Firestore operations)
    internal var currentUserId: String? {
        auth.currentUser?.uid
    }

    /// Get user's recipes collection reference
    private func recipesCollection() throws -> CollectionReference {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }
        return db.collection("users/\(userId)/recipes")
    }

    /// Get specific recipe document reference
    internal func recipeDocument(id: String) throws -> DocumentReference {
        try recipesCollection().document(id)
    }

    // MARK: - Record Conversion: SwiftData → Firestore

    /// Convert a Recipe model to Firestore document data
    func convertToFirestoreData(_ recipe: Recipe) -> [String: Any] {
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
        logger.log("Converting recipe to Firestore", category: .sync, level: .debug, metadata: nil)

        // Timestamps
        data["dateAdded"] = Timestamp(date: recipe.dateAdded)
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
    func convertFromFirestoreData(_ data: [String: Any], id: String, context: ModelContext) -> Recipe {
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
        recipe.setNotes(data["notes"] as? String)
        recipe.isFavorite = data["isFavorite"] as? Bool ?? false
        recipe.timesCooked = data["timesCooked"] as? Int ?? 0

        // Image fields
        do {
            try recipe.setImageFileName(data["imageFileName"] as? String)
        } catch {
            Log.warning("Skipped invalid imageFileName during Firebase sync", category: .firebase, metadata: ["error": error.localizedDescription])
        }
        recipe.sourceImageURL = data["sourceImageURL"] as? String
        recipe.firebaseImageURL = data["firebaseImageURL"] as? String

        // Timestamps
        if let dateAdded = (data["dateAdded"] as? Timestamp)?.dateValue() {
            recipe.dateAdded = dateAdded
        }
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
    func convertIngredientToFirestoreData(_ ingredient: Ingredient) -> [String: Any] {
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
    func convertIngredientFromFirestoreData(_ data: [String: Any], id: String) -> Ingredient {
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
    func convertCommentToFirestoreData(_ comment: RecipeComment) -> [String: Any] {
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
    func convertCommentFromFirestoreData(_ data: [String: Any], id: String) -> RecipeComment {
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
    func convertCardBackToFirestoreData(_ cardBack: RecipeCardBack) -> [String: Any] {
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
    func convertCardBackFromFirestoreData(_ data: [String: Any]) -> RecipeCardBack {
        let cardBack = RecipeCardBack()

        cardBack.setNoteToFriends(data["noteToFriends"] as? String)
        // SECURITY FIX: Sanitize personalTips array from Firestore
        cardBack.setPersonalTips(data["personalTips"] as? [String] ?? [])
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

    // MARK: - Upload Operations

    /// Upload a single recipe to Firebase
    func uploadRecipe(_ recipe: Recipe) async throws {
        logger.log("uploadRecipe() START", category: .sync, level: .debug, metadata: nil)

        guard modelContext != nil else {
            throw SyncError.notConfigured
        }

        guard currentUserId != nil else {
            throw SyncError.notAuthenticated
        }

        logger.log("📤 [Firebase] Uploading recipe: \(recipe.title)", category: .sync, level: .info, metadata: nil)
        logger.log("📤 [Firebase] Uploading recipe: \(recipe.title)", category: .sync, level: .info, metadata: nil)
        logger.log("Uploading recipe", category: .sync, level: .info, metadata: nil)

        do {
            // Wrap all Firestore operations in timeout protection
            try await TaskTimeout.withTimeout(seconds: TaskTimeout.firebaseStandard) { [self] in
                let recipeId = recipe.id.uuidString
                let recipeRef = try self.recipeDocument(id: recipeId)

                // Step 1: Upload recipe document
                let recipeData = convertToFirestoreData(recipe)
                try await recipeRef.setData(recipeData)

            logger.log("✅ [Firebase] Uploaded recipe: \(recipe.title)", category: .sync, level: .info, metadata: nil)
            logger.log("Recipe uploaded successfully", category: .sync, level: .info, metadata: nil)

            // Step 2: Delete old ingredients from Firebase subcollection
            let ingredientsRef = recipeRef.collection("ingredients")
            let existingIngredients = try await ingredientsRef.getDocuments()

            if !existingIngredients.documents.isEmpty {
                logger.log("🗑️ [Firebase] Deleting \(existingIngredients.documents.count) old ingredients", category: .sync, level: .info, metadata: nil)
                logger.log("Deleting old ingredients", category: .sync, level: .debug, metadata: nil)

                let deleteBatch = db.batch()
                for doc in existingIngredients.documents {
                    deleteBatch.deleteDocument(doc.reference)
                }
                try await deleteBatch.commit()
            }

            // Step 3: Upload new ingredients to subcollection
            if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                logger.log("📤 [Firebase] Uploading \(ingredients.count) ingredients", category: .sync, level: .info, metadata: nil)
                logger.log("Uploading ingredients", category: .sync, level: .debug, metadata: nil)

                // Batch write for efficiency
                let batch = db.batch()
                for ingredient in ingredients {
                    let ingredientRef = ingredientsRef.document(ingredient.id.uuidString)
                    let ingredientData = convertIngredientToFirestoreData(ingredient)
                    batch.setData(ingredientData, forDocument: ingredientRef)
                }
                try await batch.commit()

                logger.log("✅ [Firebase] Uploaded \(ingredients.count) ingredients", category: .sync, level: .info, metadata: nil)
                logger.log("Ingredients uploaded successfully", category: .sync, level: .debug, metadata: nil)
            }

            Log.debug("After ingredients upload, before comments", category: .firebase)

            // Step 4: Upload comments to subcollection
            if let comments = recipe.comments, !comments.isEmpty {
                logger.log("Uploading comments", category: .sync, level: .debug, metadata: nil)

                let commentsRef = recipeRef.collection("comments")
                let batch = db.batch()
                for comment in comments {
                    let commentRef = commentsRef.document(comment.id.uuidString)
                    let commentData = convertCommentToFirestoreData(comment)
                    batch.setData(commentData, forDocument: commentRef)
                }
                try await batch.commit()

                logger.log("Comments uploaded successfully", category: .sync, level: .debug, metadata: nil)
            }

            // Step 4: Upload card back to subcollection
            if let cardBack = recipe.cardBack {
                Log.debug("Uploading card back", category: .firebase)

                let cardBackRef = recipeRef.collection("cardBack").document("metadata")
                let cardBackData = convertCardBackToFirestoreData(cardBack)
                try await cardBackRef.setData(cardBackData)

                Log.debug("Card back uploaded successfully", category: .firebase)
            }

            // Step 5: Upload image to Firebase Storage (if exists)
            if recipe.imageFileName != nil {
                do {
                    if let imageURL = try await uploadImage(for: recipe) {
                        recipe.firebaseImageURL = imageURL

                        // Update Firestore document with image URL
                        try await recipeRef.updateData(["firebaseImageURL": imageURL])
                        Log.info("Image uploaded and document updated", category: .storage, metadata: ["recipeId": recipeId])
                    }
                } catch {
                    // Log but don't fail the recipe upload if image upload fails
                    Log.warning("Image upload failed", category: .storage, metadata: ["error": error.localizedDescription])
                }
            }

            // Step 6: Track lineage modification if this is an heirloom recipe being edited
            logger.log("Checking lineage tracking eligibility", category: .sync, level: .debug, metadata: nil)
            if let context = modelContext {
                Log.debug("ModelContext available, recording modification", category: .firebase)
                do {
                    try await lineageService.recordModification(
                        recipeId: recipe.id,
                        changeType: .modified,
                        changeDescription: "Recipe '\(recipe.title)' was edited",
                        fieldChanged: nil,
                        context: context
                    )
                    logger.log("Lineage modification recorded", category: .sync, level: .info, metadata: nil)
                } catch {
                    // Log but don't fail the upload if lineage tracking fails
                    logger.log("Lineage tracking failed", category: .sync, level: .warning, metadata: nil)
                }
            } else {
                Log.warning("ModelContext is nil, cannot track lineage", category: .firebase)
            }

                // Update local sync metadata
                recipe.lastSyncedAt = Date()
                try? modelContext?.save()
            } // End TaskTimeout.withTimeout

        } catch {
            DeviceLogger.shared.log("❌ [Firebase] Upload failed: \(error.localizedDescription)", level: .error)
            logger.error("❌ [Firebase] Upload failed: \(error.localizedDescription)")
            Log.error("Recipe upload failed", category: .firebase, error: error, metadata: ["recipeId": recipe.id.uuidString])
            throw SyncError.uploadFailed(error)
        }
    }

    /// Upload multiple recipes in batch
    func uploadRecipes(_ recipes: [Recipe]) async throws {
        guard !recipes.isEmpty else { return }

        logger.log("📤 [Firebase] Batch uploading \(recipes.count) recipes...", category: .sync, level: .info, metadata: nil)
        logger.log("Batch uploading recipes", category: .sync, level: .info, metadata: nil)

        // Upload each recipe (Firestore batches are limited to 500 operations)
        // Subcollections make single batch difficult, so upload serially
        for recipe in recipes {
            try await uploadRecipe(recipe)
        }

        logger.log("✅ [Firebase] Batch upload complete: \(recipes.count) recipes", category: .sync, level: .info, metadata: nil)
        logger.log("Batch upload complete", category: .sync, level: .info, metadata: nil)
    }

    /// Download a single recipe from Firebase
    func downloadRecipe(id: String, context: ModelContext) async throws -> Recipe {
        return try await recipeSync.downloadRecipe(id: id, context: context)
    }

    /// Download all recipes from Firebase
    func downloadAllRecipes(context: ModelContext) async throws -> [Recipe] {
        return try await recipeSync.downloadAllRecipes(context: context)
    }

    // MARK: - Download Operations

    /// Fetch all remote changes since last sync
    func fetchRemoteChanges(since date: Date? = nil) async throws -> [DocumentSnapshot] {
        // Use January 1, 2020 as the earliest sync date (Firebase can't handle Date.distantPast)
        let syncDate = date ?? Date(timeIntervalSince1970: 1577836800) // 2020-01-01
        logger.log("📥 [Firebase] Fetching remote changes since: \(syncDate)", category: .sync, level: .info, metadata: nil)
        Log.info("Fetching remote changes", category: .sync, metadata: ["since": syncDate.description])

        do {
            let recipesRef = try recipesCollection()
            let snapshot = try await recipesRef
                .whereField("modifiedAt", isGreaterThan: Timestamp(date: syncDate))
                .getDocuments()

            logger.log("✅ [Firebase] Fetched \(snapshot.documents.count) remote changes", category: .sync, level: .info, metadata: nil)
            Log.info("Fetched remote changes", category: .sync, metadata: ["count": snapshot.documents.count])

            return snapshot.documents

        } catch {
            DeviceLogger.shared.log("❌ [Firebase] Fetch failed: \(error.localizedDescription)", level: .error)
            Log.error("Failed to fetch remote changes", category: .sync, error: error)
            throw SyncError.downloadFailed(error)
        }
    }

    // MARK: - Full Sync

    /// Perform a full bidirectional sync
    func syncChanges() async throws {
        guard let context = modelContext else {
            throw SyncError.notConfigured
        }

        guard currentUserId != nil else {
            throw SyncError.notAuthenticated
        }

        guard !isSyncing else {
            logger.log("⏸️ [Firebase] Sync already in progress, skipping", category: .sync, level: .info, metadata: nil)
            Log.warning("Sync already in progress, skipping", category: .sync)
            return
        }

        // DIAGNOSTIC: Count Heritage recipes BEFORE sync
        let heritageCountBefore = (try? context.fetch(FetchDescriptor<Recipe>()))?.filter { $0.isHeritageRecipe }.count ?? 0
        Log.info("🔍 SYNC START - Heritage recipes BEFORE sync", category: .sync, metadata: ["count": heritageCountBefore])

        isSyncing = true
        defer {
            isSyncing = false

            // DIAGNOSTIC: Count Heritage recipes AFTER sync
            let heritageCountAfter = (try? context.fetch(FetchDescriptor<Recipe>()))?.filter { $0.isHeritageRecipe }.count ?? 0
            Log.info("🔍 SYNC END - Heritage recipes AFTER sync", category: .sync, metadata: ["count": heritageCountAfter])

            if heritageCountBefore != heritageCountAfter {
                Log.error("🚨 HERITAGE RECIPES CHANGED DURING SYNC!", category: .sync, metadata: [
                    "before": heritageCountBefore,
                    "after": heritageCountAfter,
                    "delta": heritageCountAfter - heritageCountBefore
                ])
            }
        }

        logger.log("🔄 [Firebase] Starting full sync...", category: .sync, level: .info, metadata: nil)
        logger.log("🔄 [Firebase] Starting full sync...", category: .sync, level: .info, metadata: nil)
        Log.info("Starting full sync", category: .sync)

        do {
            // 1. Upload local changes
            let unsyncedRecipes = try fetchUnsyncedRecipes(context: context)
            if !unsyncedRecipes.isEmpty {
                logger.log("📤 [Firebase] Uploading \(unsyncedRecipes.count) local changes", category: .sync, level: .info, metadata: nil)
                Log.info("Uploading local changes", category: .sync, metadata: ["count": unsyncedRecipes.count])
                try await uploadRecipes(unsyncedRecipes)
            } else {
                logger.log("ℹ️ [Firebase] No local changes to upload", category: .sync, level: .info, metadata: nil)
            }

            // 2. Download remote changes
            let lastSync = UserDefaults.standard.object(forKey: "firebase_lastSyncDate") as? Date
            DeviceLogger.shared.log("📥 [Firebase] Fetching remote changes since: \(lastSync?.description ?? "beginning of time")")
            let remoteDocuments = try await fetchRemoteChanges(since: lastSync)

            if !remoteDocuments.isEmpty {
                logger.log("📥 [Firebase] Processing \(remoteDocuments.count) remote changes", category: .sync, level: .info, metadata: nil)
                Log.info("Processing remote changes", category: .sync, metadata: ["count": remoteDocuments.count])
                for document in remoteDocuments {
                    try await mergeRemoteDocument(document, context: context)
                }
            } else {
                logger.log("ℹ️ [Firebase] No remote changes to download", category: .sync, level: .info, metadata: nil)
            }

            // 3. Sync collections
            // Upload local collections
            let localCollections = try context.fetch(FetchDescriptor<RecipeCollection>())
            let userCreatedCollections = localCollections.filter { !$0.isSystemCollection && !$0.isAllRecipes }

            if !userCreatedCollections.isEmpty {
                logger.log("📤 [Firebase] Uploading \(userCreatedCollections.count) collections", category: .sync, level: .info, metadata: nil)
                for collection in userCreatedCollections {
                    try await uploadCollection(collection)
                }
                logger.log("✅ [Firebase] Collections uploaded", category: .sync, level: .info, metadata: nil)
            }

            // Download remote collections
            logger.log("📥 [Firebase] Downloading collections", category: .sync, level: .info, metadata: nil)
            let remoteCollections = try await downloadAllCollections(context: context)
            logger.log("✅ [Firebase] Downloaded \(remoteCollections.count) collections", category: .sync, level: .info, metadata: nil)

            // 4. Update sync timestamp
            let now = Date()
            UserDefaults.standard.set(now, forKey: "firebase_lastSyncDate")
            lastSyncDate = now
            syncError = nil

            logger.log("✅ [Firebase] Sync complete", category: .sync, level: .info, metadata: nil)
            logger.log("✅ [Firebase] Sync complete", category: .sync, level: .info, metadata: nil)
            Log.info("Sync complete", category: .sync)

        } catch {
            DeviceLogger.shared.log("❌ [Firebase] Sync failed: \(error.localizedDescription)", level: .error)
            logger.error("❌ [Firebase] Sync failed: \(error.localizedDescription)")
            Log.error("Sync failed", category: .sync, error: error)
            syncError = error
            throw error
        }
    }

    // MARK: - Conflict Resolution

    /// Merge a remote document into local database
    private func mergeRemoteDocument(_ document: DocumentSnapshot, context: ModelContext) async throws {
        guard let data = document.data() else { return }

        let documentId = document.documentID

        // Check if recipe exists locally
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { recipe in
                recipe.id.uuidString == documentId
            }
        )

        let targetRecipe: Recipe
        if let existingRecipe = try context.fetch(descriptor).first {
            // Conflict: Recipe exists locally and remotely
            let remoteRecipe = convertFromFirestoreData(data, id: documentId, context: context)
            let resolved = try await resolveConflict(
                local: existingRecipe,
                remote: remoteRecipe
            )

            // Update existing recipe with resolved data
            updateRecipe(existingRecipe, from: resolved)
            targetRecipe = existingRecipe

        } else {
            // No conflict: New recipe from remote
            let newRecipe = convertFromFirestoreData(data, id: documentId, context: context)
            context.insert(newRecipe)
            targetRecipe = newRecipe
        }

        // Fetch and restore child records
        try await fetchAndRestoreIngredients(for: targetRecipe, recipeId: documentId, context: context)
        try await fetchAndRestoreComments(for: targetRecipe, recipeId: documentId, context: context)
        try await fetchAndRestoreCardBack(for: targetRecipe, recipeId: documentId, context: context)

        try context.save()
    }

    /// Fetch ingredients from Firestore and restore them to the recipe
    func fetchAndRestoreIngredients(for recipe: Recipe, recipeId: String, context: ModelContext) async throws {
        logger.log("📥 [Firebase] Fetching ingredients for: \(recipe.title)", category: .sync, level: .info, metadata: nil)
        logger.log("Fetching ingredients", category: .sync, level: .debug, metadata: nil)

        do {
            let recipeRef = try recipeDocument(id: recipeId)
            let ingredientsSnapshot = try await recipeRef.collection("ingredients")
                .order(by: "orderIndex")
                .getDocuments()

            if !ingredientsSnapshot.documents.isEmpty {
                logger.log("✅ [Firebase] Found \(ingredientsSnapshot.documents.count) ingredients", category: .sync, level: .info, metadata: nil)
                logger.log("Found ingredients", category: .sync, level: .debug, metadata: nil)

                // Clear existing ingredients to avoid duplicates
                recipe.ingredients?.removeAll()

                // Convert documents to Ingredient objects and add to recipe
                for doc in ingredientsSnapshot.documents {
                    let data = doc.data()
                    let ingredient = convertIngredientFromFirestoreData(data, id: doc.documentID)
                    ingredient.recipe = recipe
                    context.insert(ingredient)

                    if recipe.ingredients == nil {
                        recipe.ingredients = []
                    }
                    recipe.ingredients?.append(ingredient)
                }
            } else {
                logger.log("ℹ️ [Firebase] No ingredients found for: \(recipe.title)", category: .sync, level: .info, metadata: nil)
                logger.log("No ingredients found", category: .sync, level: .debug, metadata: nil)
            }
        } catch {
            DeviceLogger.shared.log("❌ [Firebase] Failed to fetch ingredients: \(error.localizedDescription)", level: .error)
            Log.error("Failed to fetch ingredients", category: .firebase, error: error, metadata: ["title": recipe.title])
            // Don't throw - allow recipe sync to succeed even if ingredients fail
        }
    }

    /// Fetch comments from Firestore and restore them to the recipe
    func fetchAndRestoreComments(for recipe: Recipe, recipeId: String, context: ModelContext) async throws {
        do {
            let recipeRef = try recipeDocument(id: recipeId)
            let commentsSnapshot = try await recipeRef.collection("comments")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            if !commentsSnapshot.documents.isEmpty {
                logger.log("Found comments", category: .sync, level: .debug, metadata: nil)

                recipe.comments?.removeAll()

                for doc in commentsSnapshot.documents {
                    let data = doc.data()
                    let comment = convertCommentFromFirestoreData(data, id: doc.documentID)
                    comment.recipe = recipe
                    context.insert(comment)

                    if recipe.comments == nil {
                        recipe.comments = []
                    }
                    recipe.comments?.append(comment)
                }
            }
        } catch {
            Log.error("Failed to fetch comments", category: .firebase, error: error)
        }
    }

    /// Fetch card back from Firestore and restore it to the recipe
    func fetchAndRestoreCardBack(for recipe: Recipe, recipeId: String, context: ModelContext) async throws {
        do {
            let recipeRef = try recipeDocument(id: recipeId)
            let cardBackDoc = try await recipeRef.collection("cardBack").document("metadata").getDocument()

            if cardBackDoc.exists, let data = cardBackDoc.data() {
                Log.debug("Found card back", category: .firebase)
                let cardBack = convertCardBackFromFirestoreData(data)
                cardBack.recipe = recipe
                context.insert(cardBack)
                recipe.cardBack = cardBack
            }
        } catch {
            Log.error("Failed to fetch card back", category: .firebase, error: error)
        }
    }

    /// Resolve conflict between local and remote versions
    private func resolveConflict(local: Recipe, remote: Recipe) async throws -> Recipe {
        Log.warning("Conflict detected", category: .crdt, metadata: ["title": local.title])

        // Strategy: Last-write-wins based on modifiedAt
        if local.modifiedAt > remote.modifiedAt {
            Log.info("Keeping local version (newer)", category: .crdt)
            return local
        } else {
            Log.info("Keeping remote version (newer)", category: .crdt)
            return remote
        }
    }

    /// Update existing recipe with resolved data
    private func updateRecipe(_ existing: Recipe, from resolved: Recipe) {
        existing.title = resolved.title
        existing.instructions = resolved.instructions
        existing.servings = resolved.servings
        existing.prepTime = resolved.prepTime
        existing.cookTime = resolved.cookTime
        existing.setNotes(resolved.notes)
        existing.isFavorite = resolved.isFavorite
        existing.modifiedAt = resolved.modifiedAt
        existing.provenance = resolved.provenance
        existing.lastSyncedAt = Date()
    }

    // MARK: - Helpers

    /// Fetch recipes that need to be synced to Firebase
    internal func fetchUnsyncedRecipes(context: ModelContext) throws -> [Recipe] {
        logger.log("🔍 [Firebase] Fetching unsynced recipes...", category: .sync, level: .info, metadata: nil)

        let descriptor = FetchDescriptor<Recipe>()
        let allRecipes = try context.fetch(descriptor)

        logger.log("🔍 [Firebase] Found \(allRecipes.count) total recipes", category: .sync, level: .info, metadata: nil)

        // Count Heritage recipes for diagnostic
        let heritageCount = allRecipes.filter { $0.isHeritageRecipe }.count
        logger.log("🔍 [Firebase] Heritage recipes in database: \(heritageCount)", category: .sync, level: .info, metadata: nil)

        // Filter for unsynced recipes (EXCLUDING heritage and onboarding recipes)
        let unsynced = allRecipes.filter { recipe in
            // CRITICAL: Never sync heritage recipes to Firebase
            // Heritage recipes are read-only system content
            guard !recipe.isHeritageRecipe else {
                Log.debug("Skipping Heritage recipe from sync", category: .sync, metadata: ["title": recipe.title])
                return false
            }

            // CRITICAL: Never sync onboarding sample recipes
            // These are local tutorial recipes, each device gets their own copy
            let onboardingTitles = ["Classic Grilled Cheese", "Tomato Soup", "Perfect Grilled Cheese", "Creamy Tomato Soup"]
            if onboardingTitles.contains(recipe.title) && recipe.sourceStory != nil {
                return false
            }

            let needsSync = recipe.lastSyncedAt == nil || recipe.modifiedAt > recipe.lastSyncedAt!
            if needsSync {
                logger.log("📝 [Firebase] Recipe '\(recipe.title)' needs sync", category: .sync, level: .info, metadata: nil)
            }
            return needsSync
        }

        logger.log("🔍 [Firebase] \(unsynced.count) recipes need sync", category: .sync, level: .info, metadata: nil)
        return unsynced
    }

    // MARK: - Automatic Sync

    /// Start automatic background sync
    func startAutomaticSync() {
        guard !isAutoSyncEnabled else { return }
        isAutoSyncEnabled = true

        logger.log("🔄 [Firebase] Starting automatic sync...", category: .sync, level: .info, metadata: nil)
        logger.log("🔄 [Firebase] Starting automatic sync...", category: .sync, level: .info, metadata: nil)
        Log.info("Starting automatic sync", category: .sync)

        // Initial sync on start
        Task {
            do {
                logger.log("🔄 [Firebase] Performing initial sync on startup...", category: .sync, level: .info, metadata: nil)
                try await syncChangesWithCRDT()
            } catch {
                DeviceLogger.shared.log("❌ [Firebase] Initial sync failed: \(error.localizedDescription)", level: .error)
            }
        }

        // Sync periodically (every 5 minutes)
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                do {
                    try await self?.syncChangesWithCRDT()
                } catch {
                    DeviceLogger.shared.log("❌ [Firebase] Periodic sync failed: \(error.localizedDescription)", level: .error)
                }
            }
        }

        // Sync when app enters foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                do {
                    self?.logger.log("🔄 [Firebase] App entered foreground, syncing...", category: .sync, level: .info, metadata: nil)
                    try await self?.syncChangesWithCRDT()
                } catch {
                    DeviceLogger.shared.log("❌ [Firebase] Foreground sync failed: \(error.localizedDescription)", level: .error)
                }
            }
        }

        logger.log("✅ [Firebase] Automatic sync enabled", category: .sync, level: .info, metadata: nil)
        logger.log("✅ [Firebase] Automatic sync enabled", category: .sync, level: .info, metadata: nil)
        Log.info("Automatic sync enabled", category: .sync)
    }

    /// Stop automatic background sync
    func stopAutomaticSync() {
        guard isAutoSyncEnabled else { return }
        isAutoSyncEnabled = false

        logger.log("🛑 [Firebase] Stopping automatic sync", category: .sync, level: .info, metadata: nil)
        Log.info("Automatic sync disabled", category: .sync)
    }

    // MARK: - Firebase Storage (Images)

    /// Upload recipe image to Firebase Storage
    /// Returns the download URL
    func uploadImage(for recipe: Recipe) async throws -> String? {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        // Check if recipe has a local image
        guard recipe.imageFileName != nil else {
            return nil
        }

        // Load image data from local storage
        guard let image = await recipe.loadImage() else {
            Log.warning("No local image found for recipe", category: .storage, metadata: ["title": recipe.title])
            return nil
        }

        // Compress image (reuse ImageStorageService compression logic - max 1MB)
        guard let imageData = await compressImage(image, maxBytes: 1_000_000) else {
            Log.warning("Failed to compress image", category: .storage, metadata: ["title": recipe.title])
            return nil
        }

        let recipeId = recipe.id.uuidString
        let storagePath = "users/\(userId)/recipes/\(recipeId)/image.jpg"
        let storageRef = Storage.storage().reference().child(storagePath)

        Log.info("Uploading image to Firebase Storage", category: .storage, metadata: ["title": recipe.title, "path": storagePath])

        // Upload image data with timeout protection (60 seconds for large images)
        let urlString = try await TaskTimeout.withTimeout(seconds: TaskTimeout.firebaseLong) {
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            _ = try await storageRef.putDataAsync(imageData, metadata: metadata)

            // Get download URL
            let downloadURL = try await storageRef.downloadURL()
            return downloadURL.absoluteString
        }

        Log.info("Image uploaded successfully", category: .storage, metadata: ["path": storagePath])

        return urlString
    }

    /// Download recipe image from Firebase Storage and cache locally
    func downloadImage(for recipe: Recipe) async throws {
        guard let firebaseImageURL = recipe.firebaseImageURL else {
            return
        }

        // Skip if already cached locally
        if let imageFileName = recipe.imageFileName,
           await recipe.loadImage() != nil {
            Log.debug("Image already cached locally", category: .storage, metadata: ["fileName": imageFileName])
            return
        }

        Log.info("Downloading image from Firebase Storage", category: .storage, metadata: ["title": recipe.title])

        // Download from Firebase Storage
        let storageRef = Storage.storage().reference(forURL: firebaseImageURL)
        let imageData = try await storageRef.data(maxSize: 10 * 1024 * 1024) // Max 10MB

        guard let image = UIImage(data: imageData) else {
            Log.error("Failed to decode image data", category: .storage)
            throw SyncError.downloadFailed(NSError(domain: "FirebaseStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"]))
        }

        // Save to local cache
        try await recipe.saveImage(image)

        Log.info("Image downloaded and cached", category: .storage, metadata: ["fileName": recipe.imageFileName ?? "unknown"])
    }

    /// Delete recipe image from Firebase Storage
    func deleteImage(for recipeId: UUID) async throws {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        let storagePath = "users/\(userId)/recipes/\(recipeId.uuidString)/image.jpg"
        let storageRef = Storage.storage().reference().child(storagePath)

        Log.info("Deleting image from Storage", category: .storage, metadata: ["path": storagePath])

        do {
            try await storageRef.delete()
            Log.info("Image deleted successfully", category: .storage, metadata: ["path": storagePath])
        } catch {
            // Ignore "not found" errors (image may not exist)
            if (error as NSError).code == StorageErrorCode.objectNotFound.rawValue {
                Log.debug("Image not found (already deleted)", category: .storage, metadata: ["path": storagePath])
            } else {
                throw error
            }
        }
    }

    // MARK: - Image Compression

    /// Compress UIImage to target size (resize first for efficiency, then compress quality)
    private func compressImage(_ image: UIImage, maxBytes: Int) async -> Data? {
        var workingImage = image

        // Step 1: Resize first if image is too large (more efficient than quality reduction)
        let maxDimension: CGFloat = 1200
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)

        if scale < 1.0 {
            let newSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )

            let renderer = UIGraphicsImageRenderer(size: newSize)
            workingImage = renderer.image { context in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }

        // Step 2: Iteratively reduce quality until under max size
        var compression: CGFloat = 0.9
        var imageData = workingImage.jpegData(compressionQuality: compression)

        while let data = imageData, data.count > maxBytes && compression > 0.1 {
            compression -= 0.1
            imageData = workingImage.jpegData(compressionQuality: compression)
        }

        return imageData
    }

    // MARK: - Deletion Operations

    /// Delete recipe from Firebase (including subcollections and images)
    func deleteRecipe(_ recipeId: UUID) async throws {
        guard currentUserId != nil else {
            throw SyncError.notAuthenticated
        }

        let recipeIdString = recipeId.uuidString
        let recipeRef = try recipeDocument(id: recipeIdString)

        logger.log("Deleting recipe", category: .sync, level: .info, metadata: nil)

        // Delete subcollections first
        try await deleteSubcollection(recipeRef, named: "ingredients")
        try await deleteSubcollection(recipeRef, named: "comments")
        try await deleteSubcollection(recipeRef, named: "cardBack")

        // Delete recipe document
        try await recipeRef.delete()

        // Delete image from Storage
        try? await deleteImage(for: recipeId)

        logger.log("Recipe deleted successfully", category: .sync, level: .info, metadata: nil)
        logger.log("✅ [Firebase] Recipe deleted: \(recipeIdString)", category: .sync, level: .info, metadata: nil)
    }

    /// Delete a subcollection from a document
    private func deleteSubcollection(_ documentRef: DocumentReference, named subcollection: String) async throws {
        let snapshot = try await documentRef.collection(subcollection).getDocuments()

        for document in snapshot.documents {
            try await document.reference.delete()
        }

        if !snapshot.documents.isEmpty {
            logger.log("Deleted subcollection documents", category: .sync, level: .debug, metadata: nil)
        }
    }

    /// Delete individual comment
    func deleteComment(_ commentId: UUID, from recipeId: UUID) async throws {
        let recipeIdString = recipeId.uuidString
        let commentIdString = commentId.uuidString

        let commentRef = try recipeDocument(id: recipeIdString)
            .collection("comments")
            .document(commentIdString)

        try await commentRef.delete()
        logger.log("Comment deleted", category: .sync, level: .info, metadata: nil)
    }

    /// Upload individual comment (for standalone comment operations)
    func uploadComment(_ comment: RecipeComment, recipeId: UUID) async throws {
        guard currentUserId != nil else {
            throw SyncError.notAuthenticated
        }

        let recipeIdString = recipeId.uuidString
        let commentIdString = comment.id.uuidString

        let commentRef = try recipeDocument(id: recipeIdString)
            .collection("comments")
            .document(commentIdString)

        let commentData = convertCommentToFirestoreData(comment)
        try await commentRef.setData(commentData)

        logger.log("Comment uploaded", category: .sync, level: .info, metadata: nil)
    }

    /// Update card back (for standalone card back operations)
    func uploadCardBack(_ cardBack: RecipeCardBack, recipeId: UUID) async throws {
        guard currentUserId != nil else {
            throw SyncError.notAuthenticated
        }

        let recipeIdString = recipeId.uuidString
        let cardBackIdString = cardBack.id.uuidString

        let cardBackRef = try recipeDocument(id: recipeIdString)
            .collection("cardBack")
            .document(cardBackIdString)

        let cardBackData = convertCardBackToFirestoreData(cardBack)
        try await cardBackRef.setData(cardBackData)

        logger.log("Card back uploaded", category: .sync, level: .info, metadata: nil)
    }

    // MARK: - Collections & Tags

    /// Upload collection to Firebase
    func uploadCollection(_ collection: RecipeCollection) async throws {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        let collectionRef = db.collection("users/\(userId)/collections").document(collection.id.uuidString)

        var data: [String: Any] = [:]
        data["id"] = collection.id.uuidString
        data["name"] = collection.name
        data["desc"] = collection.desc as Any
        data["createdDate"] = Timestamp(date: collection.createdDate)
        data["recipeIds"] = collection.recipes?.map { $0.id.uuidString } ?? []

        // Heritage-specific fields
        data["isBlindBox"] = collection.isBlindBox
        data["isRevealed"] = collection.isRevealed
        data["heritageCollectionId"] = collection.heritageCollectionId as Any
        data["iconName"] = collection.iconName
        data["color"] = collection.color
        data["isSystemCollection"] = collection.isSystemCollection
        data["isAllRecipes"] = collection.isAllRecipes

        try await collectionRef.setData(data)
        logger.log("Collection uploaded", category: .sync, level: .info, metadata: nil)
    }

    /// Download all collections from Firebase
    func downloadAllCollections(context: ModelContext) async throws -> [RecipeCollection] {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        Log.info("Downloading collections from Firebase", category: .sync)

        let collectionsRef = db.collection("users/\(userId)/collections")
        let snapshot = try await collectionsRef.getDocuments()

        var collections: [RecipeCollection] = []

        for doc in snapshot.documents {
            let data = doc.data()
            let collectionId = UUID(uuidString: doc.documentID) ?? UUID()

            // Check if collection already exists locally
            let descriptor = FetchDescriptor<RecipeCollection>(
                predicate: #Predicate { collection in
                    collection.id == collectionId
                }
            )

            let existingCollection = try? context.fetch(descriptor).first

            let collection: RecipeCollection
            if let existing = existingCollection {
                // Update existing collection
                existing.name = data["name"] as? String ?? existing.name
                existing.desc = data["desc"] as? String

                // Update heritage-specific fields
                existing.isBlindBox = data["isBlindBox"] as? Bool ?? existing.isBlindBox
                existing.isRevealed = data["isRevealed"] as? Bool ?? existing.isRevealed
                existing.heritageCollectionId = data["heritageCollectionId"] as? String
                existing.iconName = data["iconName"] as? String ?? existing.iconName
                existing.color = data["color"] as? String ?? existing.color
                existing.isSystemCollection = data["isSystemCollection"] as? Bool ?? existing.isSystemCollection
                existing.isAllRecipes = data["isAllRecipes"] as? Bool ?? existing.isAllRecipes

                collection = existing
            } else {
                // Create new collection
                collection = RecipeCollection(
                    name: data["name"] as? String ?? "Untitled",
                    description: data["desc"] as? String,
                    iconName: data["iconName"] as? String ?? "folder.fill",
                    color: data["color"] as? String ?? "#FF6B6B"
                )
                collection.id = collectionId
                if let createdDate = (data["createdDate"] as? Timestamp)?.dateValue() {
                    collection.createdDate = createdDate
                }

                // Set heritage-specific fields
                collection.isBlindBox = data["isBlindBox"] as? Bool ?? false
                collection.isRevealed = data["isRevealed"] as? Bool ?? false
                collection.heritageCollectionId = data["heritageCollectionId"] as? String
                collection.isSystemCollection = data["isSystemCollection"] as? Bool ?? false
                collection.isAllRecipes = data["isAllRecipes"] as? Bool ?? false

                context.insert(collection)
            }

            // Restore recipe relationships
            if let recipeIds = data["recipeIds"] as? [String] {
                var linkedRecipes: [Recipe] = []
                for recipeIdString in recipeIds {
                    if let recipeId = UUID(uuidString: recipeIdString) {
                        let recipeDescriptor = FetchDescriptor<Recipe>(
                            predicate: #Predicate { recipe in
                                recipe.id == recipeId
                            }
                        )
                        if let recipe = try? context.fetch(recipeDescriptor).first {
                            linkedRecipes.append(recipe)
                        }
                    }
                }
                collection.recipes = linkedRecipes
            }

            collections.append(collection)
        }

        try context.save()
        Log.info("Downloaded collections from Firebase", category: .sync, metadata: ["count": collections.count])

        return collections
    }

    /// Delete collection from Firebase
    func deleteCollection(_ collectionId: UUID) async throws {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        let collectionRef = db.collection("users/\(userId)/collections").document(collectionId.uuidString)
        try await collectionRef.delete()

        logger.log("Collection deleted", category: .sync, level: .info, metadata: nil)
    }

    /// Upload tag to Firebase
    func uploadTag(_ tag: Tag) async throws {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        let tagRef = db.collection("users/\(userId)/tags").document(tag.id.uuidString)

        var data: [String: Any] = [:]
        data["id"] = tag.id.uuidString
        data["name"] = tag.name
        data["color"] = tag.color
        data["recipeIds"] = tag.recipes?.map { $0.id.uuidString } ?? []

        try await tagRef.setData(data)
        logger.log("Tag uploaded", category: .sync, level: .info, metadata: nil)
    }

    /// Delete tag from Firebase
    func deleteTag(_ tagId: UUID) async throws {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        let tagRef = db.collection("users/\(userId)/tags").document(tagId.uuidString)
        try await tagRef.delete()

        logger.log("Tag deleted", category: .sync, level: .info, metadata: nil)
    }

    // MARK: - Shopping Cart

    /// Upload shopping cart recipe
    func uploadShoppingCartRecipe(_ cartRecipe: ShoppingCartRecipe) async throws {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        let cartRef = db.collection("users/\(userId)/shoppingCart").document(cartRecipe.id.uuidString)

        var data: [String: Any] = [:]
        data["id"] = cartRecipe.id.uuidString
        data["recipeId"] = cartRecipe.recipe?.id.uuidString as Any
        data["targetServings"] = cartRecipe.targetServings
        data["dateAdded"] = Timestamp(date: cartRecipe.dateAdded)

        try await cartRef.setData(data)
        logger.log("Shopping cart recipe uploaded", category: .sync, level: .info, metadata: nil)
    }

    /// Delete shopping cart recipe
    func deleteShoppingCartRecipe(_ cartRecipeId: UUID) async throws {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        let cartRef = db.collection("users/\(userId)/shoppingCart").document(cartRecipeId.uuidString)
        try await cartRef.delete()

        logger.log("Shopping cart recipe deleted", category: .sync, level: .info, metadata: nil)
    }

    // MARK: - Dinner Parties

    /// Upload dinner party
    func uploadDinnerParty(_ party: DinnerParty) async throws {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        let partyRef = db.collection("users/\(userId)/dinnerParties").document(party.id.uuidString)

        var data: [String: Any] = [:]
        data["id"] = party.id.uuidString
        data["name"] = party.name
        data["mealTime"] = Timestamp(date: party.mealTime)
        data["guestCount"] = party.guestCount
        data["desc"] = party.desc as Any
        data["recipeIds"] = party.recipes?.map { $0.id.uuidString } ?? []
        data["createdDate"] = Timestamp(date: party.createdDate)

        try await partyRef.setData(data)
        logger.log("Dinner party uploaded", category: .sync, level: .info, metadata: nil)
    }

    /// Delete dinner party
    func deleteDinnerParty(_ partyId: UUID) async throws {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        let partyRef = db.collection("users/\(userId)/dinnerParties").document(partyId.uuidString)
        try await partyRef.delete()

        logger.log("Dinner party deleted", category: .sync, level: .info, metadata: nil)
    }
}

// MARK: - Errors

extension FirebaseSyncService {
    enum SyncError: LocalizedError {
        case notConfigured
        case notAuthenticated
        case networkUnavailable
        case uploadFailed(Error)
        case downloadFailed(Error)
        case conflict
        case recipeNotFound
        case contextNotSet

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Sync service not configured with model context"
            case .notAuthenticated:
                return "User not authenticated with Firebase. Please sign in."
            case .networkUnavailable:
                return "Network unavailable - changes will sync when connection is restored"
            case .uploadFailed(let error):
                return "Upload failed: \(error.localizedDescription)"
            case .downloadFailed(let error):
                return "Download failed: \(error.localizedDescription)"
            case .conflict:
                return "Sync conflict detected"
            case .recipeNotFound:
                return "Recipe not found in Firebase"
            case .contextNotSet:
                return "Model context not configured"
            }
        }
    }
}

// MARK: - Global Convenience

extension FirebaseSyncService {
    /// Global accessor that resolves from ServiceContainer for proper DI
    /// Maintains backward compatibility with existing .shared usage
    /// Note: Safe to use from any context - ServiceContainer is thread-safe
    nonisolated(unsafe) static var shared: FirebaseSyncService {
        MainActor.assumeIsolated {
            ServiceContainer.shared.resolve(FirebaseSyncService.self)
        }
    }
}
