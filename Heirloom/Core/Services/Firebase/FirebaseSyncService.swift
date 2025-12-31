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

/// Firebase sync service for hybrid architecture
/// Mirrors CloudKitSyncService API but uses Firestore backend
@MainActor
class FirebaseSyncService: ObservableObject {

    // Device-visible logging
    private let logger = Logger(subsystem: "com.matthanson.heirloom", category: "FirebaseSync")

    // MARK: - Singleton

    static let shared = FirebaseSyncService()

    private init() {}

    // MARK: - Published State

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncError: Error?

    // MARK: - Dependencies

    private let db = Firestore.firestore()
    private var auth: Auth { Auth.auth() }

    // MARK: - Sync State

    private var modelContext: ModelContext?
    private var isAutoSyncEnabled = false

    // MARK: - Configuration

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext

        // Configure Firestore settings (offline support with unlimited cache)
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()  // Default = unlimited cache
        db.settings = settings

        DeviceLogger.shared.log("🔥 [Firebase] FirebaseSyncService configured")
        logger.info("🔥 [Firebase] FirebaseSyncService configured")
        print("🔥 FirebaseSyncService configured")
    }

    // MARK: - User Authentication

    /// Get current user ID (required for all Firestore operations)
    private var currentUserId: String? {
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
    private func recipeDocument(id: String) throws -> DocumentReference {
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
        data["instructions"] = recipe.instructions
        data["servings"] = recipe.servings as Any
        data["prepTime"] = recipe.prepTime as Any
        data["cookTime"] = recipe.cookTime as Any
        data["notes"] = recipe.notes as Any

        // Metadata
        data["timesCooked"] = recipe.timesCooked
        data["lastCooked"] = recipe.lastCooked as Any
        data["isFavorite"] = recipe.isFavorite

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
        recipe.notes = data["notes"] as? String
        recipe.isFavorite = data["isFavorite"] as? Bool ?? false
        recipe.timesCooked = data["timesCooked"] as? Int ?? 0

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

    // MARK: - Upload Operations

    /// Upload a single recipe to Firebase
    func uploadRecipe(_ recipe: Recipe) async throws {
        guard let context = modelContext else {
            throw SyncError.notConfigured
        }

        guard currentUserId != nil else {
            throw SyncError.notAuthenticated
        }

        DeviceLogger.shared.log("📤 [Firebase] Uploading recipe: \(recipe.title)")
        logger.info("📤 [Firebase] Uploading recipe: \(recipe.title)")
        print("📤 [Firebase] Uploading recipe: \(recipe.title)")

        do {
            let recipeId = recipe.id.uuidString
            let recipeRef = try recipeDocument(id: recipeId)

            // Step 1: Upload recipe document
            let recipeData = convertToFirestoreData(recipe)
            try await recipeRef.setData(recipeData)

            DeviceLogger.shared.log("✅ [Firebase] Uploaded recipe: \(recipe.title)")
            print("✅ [Firebase] Uploaded recipe: \(recipe.title)")

            // Step 2: Upload ingredients to subcollection
            if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                DeviceLogger.shared.log("📤 [Firebase] Uploading \(ingredients.count) ingredients")
                print("📤 [Firebase] Uploading \(ingredients.count) ingredients")

                let ingredientsRef = recipeRef.collection("ingredients")

                // Batch write for efficiency
                let batch = db.batch()
                for ingredient in ingredients {
                    let ingredientRef = ingredientsRef.document(ingredient.id.uuidString)
                    let ingredientData = convertIngredientToFirestoreData(ingredient)
                    batch.setData(ingredientData, forDocument: ingredientRef)
                }
                try await batch.commit()

                DeviceLogger.shared.log("✅ [Firebase] Uploaded \(ingredients.count) ingredients")
                print("✅ [Firebase] Uploaded \(ingredients.count) ingredients")
            }

            // Step 3: Upload comments to subcollection
            if let comments = recipe.comments, !comments.isEmpty {
                print("📤 [Firebase] Uploading \(comments.count) comments")

                let commentsRef = recipeRef.collection("comments")
                let batch = db.batch()
                for comment in comments {
                    let commentRef = commentsRef.document(comment.id.uuidString)
                    let commentData = convertCommentToFirestoreData(comment)
                    batch.setData(commentData, forDocument: commentRef)
                }
                try await batch.commit()

                print("✅ [Firebase] Uploaded \(comments.count) comments")
            }

            // Step 4: Upload card back to subcollection
            if let cardBack = recipe.cardBack {
                print("📤 [Firebase] Uploading card back")

                let cardBackRef = recipeRef.collection("cardBack").document("metadata")
                let cardBackData = convertCardBackToFirestoreData(cardBack)
                try await cardBackRef.setData(cardBackData)

                print("✅ [Firebase] Uploaded card back")
            }

            // Update local sync metadata
            recipe.lastSyncedAt = Date()
            try context.save()

        } catch {
            DeviceLogger.shared.log("❌ [Firebase] Upload failed: \(error.localizedDescription)", level: .error)
            logger.error("❌ [Firebase] Upload failed: \(error.localizedDescription)")
            print("❌ [Firebase] Upload failed: \(error.localizedDescription)")
            throw SyncError.uploadFailed(error)
        }
    }

    /// Upload multiple recipes in batch
    func uploadRecipes(_ recipes: [Recipe]) async throws {
        guard !recipes.isEmpty else { return }

        DeviceLogger.shared.log("📤 [Firebase] Batch uploading \(recipes.count) recipes...")
        print("📤 [Firebase] Batch uploading \(recipes.count) recipes")

        // Upload each recipe (Firestore batches are limited to 500 operations)
        // Subcollections make single batch difficult, so upload serially
        for recipe in recipes {
            try await uploadRecipe(recipe)
        }

        DeviceLogger.shared.log("✅ [Firebase] Batch upload complete: \(recipes.count) recipes")
        print("✅ [Firebase] Batch upload complete: \(recipes.count) recipes")
    }

    // MARK: - Download Operations

    /// Fetch all remote changes since last sync
    func fetchRemoteChanges(since date: Date = .distantPast) async throws -> [DocumentSnapshot] {
        DeviceLogger.shared.log("📥 [Firebase] Fetching remote changes since: \(date)")
        print("📥 [Firebase] Fetching remote changes since: \(date)")

        do {
            let recipesRef = try recipesCollection()
            let snapshot = try await recipesRef
                .whereField("modifiedAt", isGreaterThan: Timestamp(date: date))
                .getDocuments()

            DeviceLogger.shared.log("✅ [Firebase] Fetched \(snapshot.documents.count) remote changes")
            print("✅ [Firebase] Fetched \(snapshot.documents.count) remote changes")

            return snapshot.documents

        } catch {
            DeviceLogger.shared.log("❌ [Firebase] Fetch failed: \(error.localizedDescription)", level: .error)
            print("❌ [Firebase] Fetch failed: \(error.localizedDescription)")
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
            DeviceLogger.shared.log("⏸️ [Firebase] Sync already in progress, skipping")
            print("⏸️ [Firebase] Sync already in progress, skipping")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        DeviceLogger.shared.log("🔄 [Firebase] Starting full sync...")
        logger.info("🔄 [Firebase] Starting full sync...")
        print("🔄 [Firebase] Starting full sync...")

        do {
            // 1. Upload local changes
            let unsyncedRecipes = try fetchUnsyncedRecipes(context: context)
            if !unsyncedRecipes.isEmpty {
                DeviceLogger.shared.log("📤 [Firebase] Uploading \(unsyncedRecipes.count) local changes")
                print("📤 [Firebase] Uploading \(unsyncedRecipes.count) local changes")
                try await uploadRecipes(unsyncedRecipes)
            } else {
                DeviceLogger.shared.log("ℹ️ [Firebase] No local changes to upload")
            }

            // 2. Download remote changes
            let lastSync = UserDefaults.standard.object(forKey: "firebase_lastSyncDate") as? Date ?? .distantPast
            DeviceLogger.shared.log("📥 [Firebase] Fetching remote changes since: \(lastSync)")
            let remoteDocuments = try await fetchRemoteChanges(since: lastSync)

            if !remoteDocuments.isEmpty {
                DeviceLogger.shared.log("📥 [Firebase] Processing \(remoteDocuments.count) remote changes")
                print("📥 [Firebase] Processing \(remoteDocuments.count) remote changes")
                for document in remoteDocuments {
                    try await mergeRemoteDocument(document, context: context)
                }
            } else {
                DeviceLogger.shared.log("ℹ️ [Firebase] No remote changes to download")
            }

            // 3. Update sync timestamp
            let now = Date()
            UserDefaults.standard.set(now, forKey: "firebase_lastSyncDate")
            lastSyncDate = now
            syncError = nil

            DeviceLogger.shared.log("✅ [Firebase] Sync complete")
            logger.info("✅ [Firebase] Sync complete")
            print("✅ [Firebase] Sync complete")

        } catch {
            DeviceLogger.shared.log("❌ [Firebase] Sync failed: \(error.localizedDescription)", level: .error)
            logger.error("❌ [Firebase] Sync failed: \(error.localizedDescription)")
            print("❌ [Firebase] Sync failed: \(error.localizedDescription)")
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
    private func fetchAndRestoreIngredients(for recipe: Recipe, recipeId: String, context: ModelContext) async throws {
        DeviceLogger.shared.log("📥 [Firebase] Fetching ingredients for: \(recipe.title)")
        print("📥 [Firebase] Fetching ingredients for: \(recipe.title)")

        do {
            let recipeRef = try recipeDocument(id: recipeId)
            let ingredientsSnapshot = try await recipeRef.collection("ingredients")
                .order(by: "orderIndex")
                .getDocuments()

            if !ingredientsSnapshot.documents.isEmpty {
                DeviceLogger.shared.log("✅ [Firebase] Found \(ingredientsSnapshot.documents.count) ingredients")
                print("✅ [Firebase] Found \(ingredientsSnapshot.documents.count) ingredients")

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
                DeviceLogger.shared.log("ℹ️ [Firebase] No ingredients found for: \(recipe.title)")
                print("ℹ️ [Firebase] No ingredients found for: \(recipe.title)")
            }
        } catch {
            DeviceLogger.shared.log("❌ [Firebase] Failed to fetch ingredients: \(error.localizedDescription)", level: .error)
            print("❌ [Firebase] Failed to fetch ingredients: \(error.localizedDescription)")
            // Don't throw - allow recipe sync to succeed even if ingredients fail
        }
    }

    /// Fetch comments from Firestore and restore them to the recipe
    private func fetchAndRestoreComments(for recipe: Recipe, recipeId: String, context: ModelContext) async throws {
        do {
            let recipeRef = try recipeDocument(id: recipeId)
            let commentsSnapshot = try await recipeRef.collection("comments")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            if !commentsSnapshot.documents.isEmpty {
                print("✅ [Firebase] Found \(commentsSnapshot.documents.count) comments")

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
            print("❌ [Firebase] Failed to fetch comments: \(error.localizedDescription)")
        }
    }

    /// Fetch card back from Firestore and restore it to the recipe
    private func fetchAndRestoreCardBack(for recipe: Recipe, recipeId: String, context: ModelContext) async throws {
        do {
            let recipeRef = try recipeDocument(id: recipeId)
            let cardBackDoc = try await recipeRef.collection("cardBack").document("metadata").getDocument()

            if cardBackDoc.exists, let data = cardBackDoc.data() {
                print("✅ [Firebase] Found card back")
                let cardBack = convertCardBackFromFirestoreData(data)
                cardBack.recipe = recipe
                context.insert(cardBack)
                recipe.cardBack = cardBack
            }
        } catch {
            print("❌ [Firebase] Failed to fetch card back: \(error.localizedDescription)")
        }
    }

    /// Resolve conflict between local and remote versions
    private func resolveConflict(local: Recipe, remote: Recipe) async throws -> Recipe {
        print("⚠️ [Firebase] Conflict detected: '\(local.title)'")

        // Strategy: Last-write-wins based on modifiedAt
        if local.modifiedAt > remote.modifiedAt {
            print("   → Keeping local version (newer)")
            return local
        } else {
            print("   → Keeping remote version (newer)")
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
        existing.notes = resolved.notes
        existing.isFavorite = resolved.isFavorite
        existing.modifiedAt = resolved.modifiedAt
        existing.provenance = resolved.provenance
        existing.lastSyncedAt = Date()
    }

    // MARK: - Helpers

    /// Fetch recipes that need to be synced to Firebase
    private func fetchUnsyncedRecipes(context: ModelContext) throws -> [Recipe] {
        DeviceLogger.shared.log("🔍 [Firebase] Fetching unsynced recipes...")

        let descriptor = FetchDescriptor<Recipe>()
        let allRecipes = try context.fetch(descriptor)

        DeviceLogger.shared.log("🔍 [Firebase] Found \(allRecipes.count) total recipes")

        // Filter for unsynced recipes
        let unsynced = allRecipes.filter { recipe in
            let needsSync = recipe.lastSyncedAt == nil || recipe.modifiedAt > recipe.lastSyncedAt!
            if needsSync {
                DeviceLogger.shared.log("📝 [Firebase] Recipe '\(recipe.title)' needs sync")
            }
            return needsSync
        }

        DeviceLogger.shared.log("🔍 [Firebase] \(unsynced.count) recipes need sync")
        return unsynced
    }

    // MARK: - Automatic Sync

    /// Start automatic background sync
    func startAutomaticSync() {
        guard !isAutoSyncEnabled else { return }
        isAutoSyncEnabled = true

        DeviceLogger.shared.log("🔄 [Firebase] Starting automatic sync...")
        logger.info("🔄 [Firebase] Starting automatic sync...")
        print("🔄 [Firebase] Starting automatic sync...")

        // Initial sync on start
        Task {
            do {
                DeviceLogger.shared.log("🔄 [Firebase] Performing initial sync on startup...")
                try await syncChanges()
            } catch {
                DeviceLogger.shared.log("❌ [Firebase] Initial sync failed: \(error.localizedDescription)", level: .error)
            }
        }

        // Sync periodically (every 5 minutes)
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                do {
                    try await self?.syncChanges()
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
                    DeviceLogger.shared.log("🔄 [Firebase] App entered foreground, syncing...")
                    try await self?.syncChanges()
                } catch {
                    DeviceLogger.shared.log("❌ [Firebase] Foreground sync failed: \(error.localizedDescription)", level: .error)
                }
            }
        }

        DeviceLogger.shared.log("✅ [Firebase] Automatic sync enabled")
        logger.info("✅ [Firebase] Automatic sync enabled")
        print("✅ [Firebase] Automatic sync enabled")
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
            }
        }
    }
}
