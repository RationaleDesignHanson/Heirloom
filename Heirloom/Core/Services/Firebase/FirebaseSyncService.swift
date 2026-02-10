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

    // Loading state for collections (tracks which collections are loading recipes)
    @Published var loadingCollectionIds: Set<UUID> = []
    @Published var syncProgress: [UUID: SyncProgress] = [:] // Collection ID -> progress

    struct SyncProgress {
        var loadedRecipes: Int
        var totalRecipes: Int

        var percentComplete: Double {
            guard totalRecipes > 0 else { return 0 }
            return Double(loadedRecipes) / Double(totalRecipes)
        }
    }

    // MARK: - Sync State

    internal var modelContext: ModelContext?
    private var isAutoSyncEnabled = false
    /// UUID remapping from downloadAllCollections: maps Firebase UUID → local UUID for merged collections
    internal var collectionUUIDRemapping: [String: UUID] = [:]

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

    internal var db: Firestore { configuration.db }
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
        // Only include collectionIds if the recipe actually has collections loaded.
        // This prevents wiping existing collectionIds in Firebase when a fresh device
        // uploads a recipe before its collections are downloaded.
        if let collections = recipe.collections, !collections.isEmpty {
            data["collectionIds"] = collections.map { $0.id.uuidString }
        }

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

        // Check if reset is in progress - skip sync to prevent race condition
        if ScreenRecordingResetService.shared.isResetInProgress {
            Log.info("Sync skipped - reset in progress", category: .sync)
            return
        }

        // DIAGNOSTIC: Count Heritage recipes BEFORE sync
        let heritageCountBefore = (try? context.fetch(FetchDescriptor<Recipe>()))?.filter { $0.isThemeRecipe }.count ?? 0
        Log.info("🔍 SYNC START - Heritage recipes BEFORE sync", category: .sync, metadata: ["count": heritageCountBefore])

        isSyncing = true
        defer {
            isSyncing = false

            // DIAGNOSTIC: Count Heritage recipes AFTER sync
            let heritageCountAfter = (try? context.fetch(FetchDescriptor<Recipe>()))?.filter { $0.isThemeRecipe }.count ?? 0
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
            // 1. Sync collections FIRST (fast - shows UI immediately)
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

            // Download remote collections (FAST - UI shows immediately)
            logger.log("📥 [Firebase] Downloading collections", category: .sync, level: .info, metadata: nil)
            let remoteCollections = try await downloadAllCollections(context: context)
            logger.log("✅ [Firebase] Downloaded \(remoteCollections.count) collections", category: .sync, level: .info, metadata: nil)

            // 2. Upload local recipe changes
            let unsyncedRecipes = try fetchUnsyncedRecipes(context: context)
            if !unsyncedRecipes.isEmpty {
                logger.log("📤 [Firebase] Uploading \(unsyncedRecipes.count) local changes", category: .sync, level: .info, metadata: nil)
                Log.info("Uploading local changes", category: .sync, metadata: ["count": unsyncedRecipes.count])
                try await uploadRecipes(unsyncedRecipes)
            } else {
                logger.log("ℹ️ [Firebase] No local changes to upload", category: .sync, level: .info, metadata: nil)
            }

            // 3. Download remote recipe changes (SLOW - but UI already visible)
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

            // 4. Update sync timestamp (collections already synced in Step 1)
            let now = Date()
            UserDefaults.standard.set(now, forKey: "firebase_lastSyncDate")
            lastSyncDate = now
            syncError = nil

            logger.log("✅ [Firebase] Sync complete", category: .sync, level: .info, metadata: nil)
            logger.log("✅ [Firebase] Sync complete", category: .sync, level: .info, metadata: nil)
            Log.info("Sync complete", category: .sync)

            // Clean up old tombstones after successful sync
            cleanupOldTombstones(context: context)

            // Clear any remaining loading states — all downloads are complete at this point
            if !loadingCollectionIds.isEmpty {
                Log.info("Clearing stale loading states after sync", category: .sync, metadata: [
                    "collections": loadingCollectionIds.count
                ])
                loadingCollectionIds.removeAll()
                syncProgress.removeAll()
            }

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

        // Check if this recipe is pending undo (recently deleted, user might restore)
        // If so, skip downloading to avoid resurrecting a deleted recipe
        if let recipeUUID = UUID(uuidString: documentId) {
            let undoService = ServiceContainer.shared.resolve(UndoService.self)
            if undoService.isRecipePendingUndo(recipeUUID) {
                Log.info("Skipping download of recipe pending undo", category: .sync, metadata: [
                    "recipeId": documentId
                ])
                return
            }
        }

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

        // Update collection loading progress
        await updateCollectionLoadingProgress(for: targetRecipe.id, context: context)
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
        let heritageCount = allRecipes.filter { $0.isThemeRecipe }.count
        logger.log("🔍 [Firebase] Heritage recipes in database: \(heritageCount)", category: .sync, level: .info, metadata: nil)

        // Filter for unsynced recipes (EXCLUDING heritage and onboarding recipes)
        let unsynced = allRecipes.filter { recipe in
            // CRITICAL: Never sync heritage recipes to Firebase
            // Heritage recipes are read-only system content
            guard !recipe.isThemeRecipe else {
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

        // Initial sync on start - use background priority to not block UI
        Task.detached(priority: .utility) {
            // Small delay to let UI render first
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            do {
                await self.logger.log("🔄 [Firebase] Performing initial sync on startup...", category: .sync, level: .info, metadata: nil)
                try await self.syncChangesWithCRDT()
            } catch {
                DeviceLogger.shared.log("❌ [Firebase] Initial sync failed: \(error.localizedDescription)", level: .error)
            }
        }

        // Sync periodically (every 5 minutes) - use background priority to not block UI
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task.detached(priority: .utility) {
                do {
                    try await self?.syncChangesWithCRDT()
                } catch {
                    DeviceLogger.shared.log("❌ [Firebase] Periodic sync failed: \(error.localizedDescription)", level: .error)
                }
            }
        }

        // Sync when app enters foreground - use background priority to not block UI
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task.detached(priority: .utility) {
                do {
                    await self?.logger.log("🔄 [Firebase] App entered foreground, syncing...", category: .sync, level: .info, metadata: nil)
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

    /// Cancel any currently running sync operation
    /// Called during reset to prevent race conditions
    func cancelSync() async {
        if isSyncing {
            isSyncing = false
            Log.info("Sync cancelled by reset operation", category: .sync)
        }
    }

    // MARK: - Background Lifecycle Handling

    /// Tracks whether listeners are currently paused due to backgrounding
    private var listenersArePaused = false

    /// Set up background/foreground observers to pause real-time listeners
    /// This prevents battery drain from continuous Firebase connections when app is backgrounded
    func setupBackgroundHandling() {
        // Pause listeners when app enters background
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.pauseListenersForBackground()
            }
        }

        // Resume listeners when app returns to foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.resumeListenersFromBackground()
            }
        }

        logger.log("✅ [Firebase] Background handling configured", category: .sync, level: .info, metadata: nil)
        Log.info("Firebase background handling configured", category: .sync)
    }

    /// Pause Firebase real-time listeners to save battery when app is backgrounded
    private func pauseListenersForBackground() {
        guard !listenersArePaused else { return }

        logger.log("⏸️ [Firebase] Pausing listeners for background", category: .sync, level: .info, metadata: nil)
        Log.info("Pausing Firebase listeners for background", category: .sync)

        // Save last sync timestamp
        UserDefaults.standard.set(Date(), forKey: "firebase_lastBackgroundedAt")

        // Pause notification listener
        let notificationService = ServiceContainer.shared.resolve(FirebaseNotificationService.self)
        notificationService.stopListening()

        // Pause badge listener
        let badgeService = ServiceContainer.shared.resolve(BadgeService.self)
        badgeService.stopListening()

        listenersArePaused = true

        logger.log("✅ [Firebase] Listeners paused for background", category: .sync, level: .info, metadata: nil)
    }

    /// Resume Firebase real-time listeners when app returns to foreground
    private func resumeListenersFromBackground() {
        guard listenersArePaused else { return }
        guard currentUserId != nil else {
            // Not authenticated, nothing to resume
            listenersArePaused = false
            return
        }

        logger.log("▶️ [Firebase] Resuming listeners from background", category: .sync, level: .info, metadata: nil)
        Log.info("Resuming Firebase listeners from background", category: .sync)

        // Resume notification listener
        let notificationService = ServiceContainer.shared.resolve(FirebaseNotificationService.self)
        notificationService.startListening()

        // Resume badge listener
        let badgeService = ServiceContainer.shared.resolve(BadgeService.self)
        badgeService.startListening()

        listenersArePaused = false

        // Log time spent in background
        if let backgroundedAt = UserDefaults.standard.object(forKey: "firebase_lastBackgroundedAt") as? Date {
            let duration = Date().timeIntervalSince(backgroundedAt)
            logger.log("✅ [Firebase] Listeners resumed after \(Int(duration))s in background", category: .sync, level: .info, metadata: nil)
            Log.info("Firebase listeners resumed", category: .sync, metadata: ["backgroundDuration": Int(duration)])
        }
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
        guard let firebaseImageURL = recipe.firebaseImageURL, !firebaseImageURL.isEmpty else {
            return
        }

        // Skip if already cached locally
        if let imageFileName = recipe.imageFileName,
           await recipe.loadImage() != nil {
            Log.debug("Image already cached locally", category: .storage, metadata: ["fileName": imageFileName])
            return
        }

        Log.info("Downloading image from Firebase Storage", category: .storage, metadata: ["title": recipe.title])

        let imageData: Data

        // Check URL format and download appropriately
        if firebaseImageURL.hasPrefix("gs://") {
            // Use Firebase Storage SDK for gs:// URLs
            let storageRef = Storage.storage().reference(forURL: firebaseImageURL)
            imageData = try await storageRef.data(maxSize: 10 * 1024 * 1024) // Max 10MB
        } else if firebaseImageURL.contains("firebasestorage.googleapis.com") {
            // Use Firebase Storage SDK for Firebase download URLs
            let storageRef = Storage.storage().reference(forURL: firebaseImageURL)
            imageData = try await storageRef.data(maxSize: 10 * 1024 * 1024) // Max 10MB
        } else if let url = URL(string: firebaseImageURL) {
            // Use URLSession for direct HTTP/HTTPS URLs (e.g., storage.googleapis.com)
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                Log.error("Failed to download image: HTTP error", category: .storage, metadata: ["url": firebaseImageURL])
                throw SyncError.downloadFailed(NSError(domain: "FirebaseStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "HTTP download failed"]))
            }
            imageData = data
        } else {
            Log.error("Invalid image URL format", category: .storage, metadata: ["url": firebaseImageURL])
            throw SyncError.downloadFailed(NSError(domain: "FirebaseStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL format"]))
        }

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
        // Only include recipeIds if the collection actually has recipes loaded.
        // Using merge: true ensures we never wipe existing recipeIds in Firebase
        // when a fresh device uploads a collection before its recipes are downloaded.
        if let recipes = collection.recipes, !recipes.isEmpty {
            data["recipeIds"] = recipes.map { $0.id.uuidString }
        }

        // Theme-specific fields
        // TODO: Update for theme system in Phase A3
        // data["sourceThemeId"] = collection.sourceTheme?.firebaseId as Any
        data["collectionType"] = collection.collectionType
        data["iconName"] = collection.iconName
        data["color"] = collection.color
        data["isSystemCollection"] = collection.isSystemCollection
        data["isAllRecipes"] = collection.isAllRecipes
        data["isDemoSeed"] = collection.isDemoSeed

        try await collectionRef.setData(data, merge: true)
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

        // Pre-build name-based lookup for system-like collections to prevent UUID mismatch duplication.
        // When a fresh device creates "Generated Recipes" with UUID-A, and Firebase has it with UUID-B
        // from another device, we merge into the local one instead of creating a duplicate.
        let allLocalCollections = try context.fetch(FetchDescriptor<RecipeCollection>())
        var localCollectionsByNameAndType: [String: RecipeCollection] = [:]
        for local in allLocalCollections {
            let key = "\(local.name)|\(local.collectionType)"
            localCollectionsByNameAndType[key] = local
        }

        // Track UUID remapping when Firebase UUID differs from local UUID (for relinking later)
        var uuidRemapping: [String: UUID] = [:]

        for doc in snapshot.documents {
            let data = doc.data()
            let collectionId = UUID(uuidString: doc.documentID) ?? UUID()

            // Check if this collection is pending undo (recently deleted, user might restore)
            let undoService = ServiceContainer.shared.resolve(UndoService.self)
            if undoService.isCollectionPendingUndo(collectionId) {
                Log.info("Skipping collection download - pending undo", category: .sync, metadata: [
                    "collectionId": collectionId.uuidString
                ])
                continue
            }

            // Check if this collection was deleted locally (tombstone check)
            let tombstoneDescriptor = FetchDescriptor<DeletedCollectionRecord>(
                predicate: #Predicate { record in
                    record.collectionId == collectionId
                }
            )
            if let tombstone = try? context.fetch(tombstoneDescriptor).first {
                Log.info("Skipping collection download - locally deleted (tombstone found)", category: .sync, metadata: [
                    "collectionId": collectionId.uuidString,
                    "syncedToFirebase": tombstone.syncedToFirebase
                ])
                continue // Skip this collection, it was deleted locally
            }

            // Check if collection already exists locally by UUID
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

                // Update theme-specific fields
                // TODO: Update for theme system in Phase A3
                if let collectionTypeStr = data["collectionType"] as? String {
                    existing.collectionType = collectionTypeStr
                }
                existing.iconName = data["iconName"] as? String ?? existing.iconName
                existing.color = data["color"] as? String ?? existing.color
                existing.isSystemCollection = data["isSystemCollection"] as? Bool ?? existing.isSystemCollection
                existing.isAllRecipes = data["isAllRecipes"] as? Bool ?? existing.isAllRecipes
                existing.isDemoSeed = data["isDemoSeed"] as? Bool ?? existing.isDemoSeed

                collection = existing
            } else {
                // UUID not found locally — check if a local collection with the same name+type
                // already exists (e.g., "Generated Recipes" created at startup with a different UUID).
                // Merge into the local one to prevent duplication and preserve preset backgrounds.
                let firebaseName = data["name"] as? String ?? ""
                let firebaseType = data["collectionType"] as? String ?? ""
                let lookupKey = "\(firebaseName)|\(firebaseType)"

                if let localMatch = localCollectionsByNameAndType[lookupKey],
                   localMatch.id != collectionId {
                    // Merge into existing local collection (keep local UUID, keep presets)
                    Log.info("Merging Firebase collection into existing local by name", category: .sync, metadata: [
                        "name": firebaseName,
                        "firebaseUUID": collectionId.uuidString,
                        "localUUID": localMatch.id.uuidString
                    ])
                    uuidRemapping[collectionId.uuidString.lowercased()] = localMatch.id
                    collection = localMatch
                } else {
                    // Create new collection (no local match by UUID or name)
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

                    // Set theme-specific fields
                    // TODO: Update for theme system in Phase A3
                    if let collectionTypeStr = data["collectionType"] as? String {
                        collection.collectionType = collectionTypeStr
                    }
                    collection.isSystemCollection = data["isSystemCollection"] as? Bool ?? false
                    collection.isAllRecipes = data["isAllRecipes"] as? Bool ?? false
                    collection.isDemoSeed = data["isDemoSeed"] as? Bool ?? false

                    context.insert(collection)
                }
            }

            // Restore recipe relationships and track loading state
            if let recipeIds = data["recipeIds"] as? [String] {
                let expectedRecipeCount = recipeIds.count
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

                // MERGE Firebase recipes into existing local recipes rather than replacing.
                // This prevents wiping locally-seeded relationships when Firebase recipeIds
                // are empty (e.g., corrupted by a prior sync from a fresh device).
                let existingRecipes = collection.recipes ?? []
                if !linkedRecipes.isEmpty {
                    // Merge: add any Firebase recipes not already linked locally
                    var merged = existingRecipes
                    let existingIds = Set(existingRecipes.map { $0.id })
                    for recipe in linkedRecipes {
                        if !existingIds.contains(recipe.id) {
                            merged.append(recipe)
                        }
                    }
                    collection.recipes = merged
                }
                // If Firebase recipeIds is empty, keep existing local recipes untouched

                // Track loading state for collections with missing recipes (10+ threshold)
                let missingRecipeCount = expectedRecipeCount - linkedRecipes.count
                if missingRecipeCount > 0 && expectedRecipeCount >= 10 {
                    // Mark collection as loading
                    await MainActor.run {
                        loadingCollectionIds.insert(collectionId)
                        syncProgress[collectionId] = SyncProgress(
                            loadedRecipes: linkedRecipes.count,
                            totalRecipes: expectedRecipeCount
                        )
                    }
                    Log.info("Collection has missing recipes, tracking load progress", category: .sync, metadata: [
                        "collectionId": collectionId.uuidString,
                        "loaded": linkedRecipes.count,
                        "total": expectedRecipeCount
                    ])
                }
            }

            collections.append(collection)
        }

        // Deduplicate "Generated Recipes" collections that may have different UUIDs
        // (local createSystemCollections checks by name, but download checks by UUID)
        let generatedRecipesCollections = collections.filter { $0.name == "Generated Recipes" }
        if generatedRecipesCollections.count > 1 {
            Log.warning("Found duplicate Generated Recipes collections after download", category: .sync, metadata: [
                "count": generatedRecipesCollections.count
            ])

            // Keep the one with the most recipes
            let sorted = generatedRecipesCollections.sorted { ($0.recipes?.count ?? 0) > ($1.recipes?.count ?? 0) }
            let primary = sorted[0]
            let duplicates = sorted.dropFirst()

            for duplicate in duplicates {
                // Merge recipes from duplicate into primary
                if let dupeRecipes = duplicate.recipes {
                    for recipe in dupeRecipes {
                        let alreadyLinked = primary.recipes?.contains(where: { $0.id == recipe.id }) ?? false
                        if !alreadyLinked {
                            if primary.recipes == nil { primary.recipes = [] }
                            primary.recipes?.append(recipe)
                        }
                    }
                }

                // Delete duplicate from SwiftData
                context.delete(duplicate)
                collections.removeAll { $0.id == duplicate.id }

                // Delete duplicate from Firestore
                if let userId = currentUserId {
                    let dupeRef = db.collection("users/\(userId)/collections").document(duplicate.id.uuidString)
                    try? await dupeRef.delete()
                }
            }

            Log.info("Deduplicated Generated Recipes collections after download", category: .sync, metadata: [
                "kept": primary.id.uuidString,
                "deleted": duplicates.count
            ])
        }

        // Restore preset backgrounds for all system/import collections after download+dedup.
        // Firebase doesn't sync background fields, so downloaded collections lose their presets.
        restoreCollectionPresets(collections: collections, context: context)

        // Store UUID remapping for relinkRecipesToCollections
        self.collectionUUIDRemapping = uuidRemapping

        try context.save()
        Log.info("Downloaded collections from Firebase", category: .sync, metadata: ["count": collections.count])

        return collections
    }

    /// Restore preset backgrounds for collections that have hardcoded assets.
    /// Called after Firebase download since background fields aren't synced.
    private func restoreCollectionPresets(collections: [RecipeCollection], context: ModelContext) {
        // Also check ALL local collections, not just downloaded ones
        let allCollections: [RecipeCollection]
        if let fetched = try? context.fetch(FetchDescriptor<RecipeCollection>()) {
            allCollections = fetched
        } else {
            allCollections = collections
        }

        let presetMap: [(String, String?, String)] = [
            // (name, collectionType, assetName)
            ("Generated Recipes", nil, "generated-recipes-bg"),
            ("Cookbook Pages", "cookbook", "cookbook-pages-bg"),
            ("From Web", "webImports", "from-web-bg"),
            ("From Videos", "videoImports", "from-videos-bg"),
            ("From Photos", "photoImports", "from-photos-bg"),
            ("From Friends", "fromFriends", "from-friends-bg"),
            ("Read Recipes", "readRecipes", "read-recipes-bg"),
        ]

        for collection in allCollections {
            // Check if this collection matches any preset
            for (name, collectionType, assetName) in presetMap {
                let nameMatch = collection.name == name
                let typeMatch = collectionType == nil || collection.collectionType == collectionType
                guard nameMatch && typeMatch else { continue }

                // Only apply if no custom background is set, or if preset was cleared
                let hasPreset = collection.customBackgroundImagePath?.hasPrefix("preset-") == true
                if !hasPreset, UIImage(named: assetName) != nil {
                    collection.customBackgroundImagePath = "preset-\(assetName)"
                    collection.useCustomBackground = true
                    // Clear any stale AI-generated background
                    if collection.generatedBackgroundImagePath != nil {
                        collection.generatedBackgroundImagePath = nil
                    }
                    Log.info("Restored preset background after sync", category: .sync, metadata: [
                        "collection": collection.name,
                        "preset": assetName
                    ])
                }
                break
            }
        }
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

    /// Clean up old tombstones that have been synced to Firebase
    /// Should be called periodically (e.g., after successful sync)
    func cleanupOldTombstones(context: ModelContext) {
        // Delete tombstones that are:
        // 1. Successfully synced to Firebase (syncedToFirebase = true)
        // 2. Older than 30 days (safety buffer for multi-device sync)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        let descriptor = FetchDescriptor<DeletedCollectionRecord>(
            predicate: #Predicate { record in
                record.syncedToFirebase == true && record.deletedAt < thirtyDaysAgo
            }
        )

        do {
            let oldTombstones = try context.fetch(descriptor)
            for tombstone in oldTombstones {
                context.delete(tombstone)
                Log.debug("Cleaned up old tombstone", category: .sync, metadata: [
                    "collectionId": tombstone.collectionId.uuidString,
                    "deletedAt": tombstone.deletedAt.ISO8601Format()
                ])
            }

            if !oldTombstones.isEmpty {
                try context.save()
                Log.info("Cleaned up old tombstones", category: .sync, metadata: ["count": oldTombstones.count])
            }
        } catch {
            Log.error("Failed to clean up old tombstones", category: .sync, error: error)
        }
    }

    /// Update loading progress for collections after a recipe is synced
    func updateCollectionLoadingProgress(for recipeId: UUID, context: ModelContext) async {
        // Find which collections contain this recipe
        let recipeDescriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { recipe in
                recipe.id == recipeId
            }
        )

        guard let recipe = try? context.fetch(recipeDescriptor).first,
              let collections = recipe.collections else {
            return
        }

        for collection in collections {
            // Only track collections that are marked as loading
            guard loadingCollectionIds.contains(collection.id) else { continue }

            // Update progress
            let currentRecipeCount = collection.recipes?.count ?? 0
            if var progress = syncProgress[collection.id] {
                progress.loadedRecipes = currentRecipeCount

                await MainActor.run {
                    syncProgress[collection.id] = progress

                    // Remove from loading if complete
                    if currentRecipeCount >= progress.totalRecipes {
                        loadingCollectionIds.remove(collection.id)
                        syncProgress.removeValue(forKey: collection.id)
                        Log.info("Collection finished loading", category: .sync, metadata: [
                            "collectionId": collection.id.uuidString,
                            "recipeCount": currentRecipeCount
                        ])
                    }
                }
            }
        }
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
        logger.log("Meal plan uploaded", category: .sync, level: .info, metadata: nil)
    }

    /// Delete dinner party
    func deleteDinnerParty(_ partyId: UUID) async throws {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        let partyRef = db.collection("users/\(userId)/dinnerParties").document(partyId.uuidString)
        try await partyRef.delete()

        logger.log("Meal plan deleted", category: .sync, level: .info, metadata: nil)
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
