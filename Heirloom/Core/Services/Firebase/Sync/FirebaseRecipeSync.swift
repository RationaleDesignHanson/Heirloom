//
//  FirebaseRecipeSync.swift
//  Heirloom
//
//  Phase 2 Week 3: Service Layer Refactoring
//  Recipe-level sync orchestration and conflict resolution
//

import Foundation
import SwiftData
import UIKit
import os.log
import FirebaseFirestore
import Combine

/// Orchestrates recipe sync between local SwiftData and Firebase Firestore
/// Responsibilities: Upload, download, full sync, conflict resolution, automatic sync
@MainActor
class FirebaseRecipeSync: ObservableObject, FirebaseRecipeSyncProtocol {

    // MARK: - Singleton

    static let shared = FirebaseRecipeSync()

    private init() {}

    // MARK: - Logging

    private let logger = Logger(subsystem: "com.matthanson.heirloom", category: "FirebaseSync")

    // MARK: - Published State

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published private(set) var syncError: Error?

    // MARK: - Dependencies

    private var config: FirebaseConfiguration {
        FirebaseConfiguration.shared
    }

    private var converter: FirebaseRecordConverter.Type {
        FirebaseRecordConverter.self
    }

    private var imageService: FirebaseImageService {
        FirebaseImageService.shared
    }

    private var collectionSync: FirebaseCollectionSync {
        FirebaseCollectionSync.shared
    }

    // MARK: - State

    private var isAutoSyncEnabled = false
    private var autoSyncTimer: Timer?

    // MARK: - Upload Operations

    /// Upload a single recipe to Firebase
    /// - Parameter recipe: Recipe to upload
    /// - Throws: FirebaseError if upload fails
    func uploadRecipe(_ recipe: Recipe) async throws {
        Log.debug("Starting recipe upload", category: .firebase, metadata: ["title": recipe.title])

        guard let context = config.modelContext else {
            throw FirebaseError.notConfigured
        }

        guard config.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        DeviceLogger.shared.log("📤 [Firebase] Uploading recipe: \(recipe.title)")
        logger.info("📤 [Firebase] Uploading recipe: \(recipe.title)")
        Log.info("Uploading recipe", category: .firebase, metadata: ["title": recipe.title])

        do {
            let recipeId = recipe.id.uuidString
            let recipeRef = try config.recipeDocument(id: recipeId)

            // Step 1: Upload recipe document
            let recipeData = converter.convertToFirestoreData(recipe)
            try await recipeRef.setData(recipeData)

            DeviceLogger.shared.log("✅ [Firebase] Uploaded recipe: \(recipe.title)")
            Log.info("Recipe uploaded successfully", category: .firebase, metadata: ["title": recipe.title, "recipeId": recipeId])

            // Step 2: Upload ingredients subcollection
            if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                try await collectionSync.uploadIngredients(ingredients, for: recipeId)
            }

            // Step 3: Upload comments subcollection
            if let comments = recipe.comments, !comments.isEmpty {
                try await collectionSync.uploadComments(comments, for: recipeId)
            }

            // Step 4: Upload card back
            if let cardBack = recipe.cardBack {
                Log.debug("Uploading card back", category: .firebase)
                try await collectionSync.uploadCardBack(cardBack, for: recipeId)
            }

            // Step 5: Upload image to Firebase Storage (if exists)
            if recipe.imageFileName != nil {
                do {
                    if let imageURL = try await imageService.uploadImage(for: recipe) {
                        recipe.firebaseImageURL = imageURL

                        // Update Firestore document with image URL
                        try await recipeRef.updateData(["firebaseImageURL": imageURL])
                        Log.info("Image uploaded and document updated", category: .storage)
                    }
                } catch {
                    // Log but don't fail the recipe upload if image upload fails
                    Log.warning("Image upload failed", category: .storage, metadata: ["error": error.localizedDescription])
                }
            }

            // Step 6: Track lineage modification if this is an heirloom recipe being edited
            Log.debug("Checking lineage tracking", category: .firebase, metadata: ["title": recipe.title])
            do {
                try await FirebaseLineageService.shared.recordModification(
                    recipeId: recipe.id,
                    changeType: .modified,
                    changeDescription: "Recipe '\(recipe.title)' was edited",
                    fieldChanged: nil,
                    context: context
                )
                Log.info("Lineage modification recorded", category: .firebase, metadata: ["title": recipe.title])
            } catch {
                // Log but don't fail the upload if lineage tracking fails
                Log.warning("Failed to record lineage modification", category: .firebase, metadata: ["error": error.localizedDescription])
            }

            // Update local sync metadata
            recipe.lastSyncedAt = Date()
            try? context.save()

        } catch {
            DeviceLogger.shared.log("❌ [Firebase] Upload failed: \(error.localizedDescription)", level: .error)
            logger.error("❌ [Firebase] Upload failed: \(error.localizedDescription)")
            Log.error("Recipe upload failed", category: .firebase, error: error)
            throw FirebaseError.uploadFailed(error)
        }
    }

    /// Upload multiple recipes in batch
    /// - Parameter recipes: Array of recipes to upload
    /// - Throws: FirebaseError if upload fails
    func uploadRecipes(_ recipes: [Recipe]) async throws {
        guard !recipes.isEmpty else { return }

        DeviceLogger.shared.log("📤 [Firebase] Batch uploading \(recipes.count) recipes...")
        Log.info("Starting batch recipe upload", category: .firebase, metadata: ["count": recipes.count])

        // Upload each recipe (Firestore batches are limited to 500 operations)
        // Subcollections make single batch difficult, so upload serially
        for recipe in recipes {
            try await uploadRecipe(recipe)
        }

        DeviceLogger.shared.log("✅ [Firebase] Batch upload complete: \(recipes.count) recipes")
        Log.info("Batch upload complete", category: .firebase, metadata: ["count": recipes.count])
    }

    // MARK: - Download Operations

    /// Fetch all remote changes since last sync
    /// - Parameter date: Date to fetch changes since (nil = fetch all)
    /// - Returns: Array of document snapshots with changes
    /// - Throws: FirebaseError if fetch fails
    func fetchRemoteChanges(since date: Date? = nil) async throws -> [DocumentSnapshot] {
        // Use January 1, 2020 as the earliest sync date (Firebase can't handle Date.distantPast)
        let syncDate = date ?? Date(timeIntervalSince1970: 1577836800) // 2020-01-01
        DeviceLogger.shared.log("📥 [Firebase] Fetching remote changes since: \(syncDate)")
        Log.info("Fetching remote changes", category: .firebase, metadata: ["sinceDate": syncDate.description])

        do {
            let recipesRef = try config.recipesCollection()
            let snapshot = try await recipesRef
                .whereField("modifiedAt", isGreaterThan: Timestamp(date: syncDate))
                .getDocuments()

            DeviceLogger.shared.log("✅ [Firebase] Fetched \(snapshot.documents.count) remote changes")
            Log.info("Fetched remote changes", category: .firebase, metadata: ["count": snapshot.documents.count])

            return snapshot.documents

        } catch {
            DeviceLogger.shared.log("❌ [Firebase] Fetch failed: \(error.localizedDescription)", level: .error)
            Log.error("Failed to fetch remote changes", category: .firebase, error: error)
            throw FirebaseError.downloadFailed(error)
        }
    }

    // MARK: - Full Sync Orchestration

    /// Perform a full bidirectional sync
    /// - Throws: FirebaseError if sync fails
    func syncChanges() async throws {
        guard let context = config.modelContext else {
            throw FirebaseError.notConfigured
        }

        guard config.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        guard !isSyncing else {
            DeviceLogger.shared.log("⏸️ [Firebase] Sync already in progress, skipping")
            Log.warning("Sync already in progress, skipping", category: .sync)
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        DeviceLogger.shared.log("🔄 [Firebase] Starting full sync...")
        logger.info("🔄 [Firebase] Starting full sync...")
        Log.info("Starting full sync", category: .sync)

        do {
            // 1. Upload local changes
            let unsyncedRecipes = try fetchUnsyncedRecipes(context: context)
            if !unsyncedRecipes.isEmpty {
                DeviceLogger.shared.log("📤 [Firebase] Uploading \(unsyncedRecipes.count) local changes")
                Log.info("Uploading local changes", category: .sync, metadata: ["count": unsyncedRecipes.count])
                try await uploadRecipes(unsyncedRecipes)
            } else {
                DeviceLogger.shared.log("ℹ️ [Firebase] No local changes to upload")
            }

            // 2. Download remote changes
            let lastSync = UserDefaults.standard.object(forKey: "firebase_lastSyncDate") as? Date
            DeviceLogger.shared.log("📥 [Firebase] Fetching remote changes since: \(lastSync?.description ?? "beginning of time")")
            let remoteDocuments = try await fetchRemoteChanges(since: lastSync)

            if !remoteDocuments.isEmpty {
                DeviceLogger.shared.log("📥 [Firebase] Processing \(remoteDocuments.count) remote changes")
                Log.info("Processing remote changes", category: .sync, metadata: ["count": remoteDocuments.count])
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
    /// - Parameters:
    ///   - document: Remote Firestore document
    ///   - context: SwiftData model context
    /// - Throws: FirebaseError if merge fails
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
            let remoteRecipe = converter.convertFromFirestoreData(data, id: documentId, context: context)
            let resolved = try await resolveConflict(
                local: existingRecipe,
                remote: remoteRecipe
            )

            // Update existing recipe with resolved data
            updateRecipe(existingRecipe, from: resolved)
            targetRecipe = existingRecipe

        } else {
            // No conflict: New recipe from remote
            let newRecipe = converter.convertFromFirestoreData(data, id: documentId, context: context)
            context.insert(newRecipe)
            targetRecipe = newRecipe
        }

        // Fetch and restore child records
        try await fetchAndRestoreIngredients(for: targetRecipe, recipeId: documentId, context: context)
        try await fetchAndRestoreComments(for: targetRecipe, recipeId: documentId, context: context)
        try await fetchAndRestoreCardBack(for: targetRecipe, recipeId: documentId, context: context)

        try context.save()
    }

    /// Resolve conflict between local and remote versions
    /// Strategy: Last-write-wins based on modifiedAt
    /// - Parameters:
    ///   - local: Local recipe version
    ///   - remote: Remote recipe version
    /// - Returns: Winning recipe version
    private func resolveConflict(local: Recipe, remote: Recipe) async throws -> Recipe {
        Log.warning("Conflict detected", category: .sync, metadata: ["title": local.title])

        // Strategy: Last-write-wins based on modifiedAt
        if local.modifiedAt > remote.modifiedAt {
            Log.info("Keeping local version (newer)", category: .sync)
            return local
        } else {
            Log.info("Keeping remote version (newer)", category: .sync)
            return remote
        }
    }

    /// Update existing recipe with resolved data
    /// - Parameters:
    ///   - existing: Existing recipe to update
    ///   - resolved: Resolved recipe data
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

    // MARK: - Restore Child Records

    /// Fetch ingredients from Firestore and restore them to the recipe
    private func fetchAndRestoreIngredients(for recipe: Recipe, recipeId: String, context: ModelContext) async throws {
        DeviceLogger.shared.log("📥 [Firebase] Fetching ingredients for: \(recipe.title)")
        Log.debug("Fetching ingredients", category: .firebase, metadata: ["title": recipe.title])

        do {
            try await collectionSync.downloadIngredients(for: recipeId, recipe: recipe)

            // Insert ingredients into context
            if let ingredients = recipe.ingredients {
                for ingredient in ingredients {
                    ingredient.recipe = recipe
                    context.insert(ingredient)
                }
            }
        } catch {
            DeviceLogger.shared.log("❌ [Firebase] Failed to fetch ingredients: \(error.localizedDescription)", level: .error)
            Log.error("Failed to fetch ingredients", category: .firebase, error: error)
            // Don't throw - allow recipe sync to succeed even if ingredients fail
        }
    }

    /// Fetch comments from Firestore and restore them to the recipe
    private func fetchAndRestoreComments(for recipe: Recipe, recipeId: String, context: ModelContext) async throws {
        do {
            try await collectionSync.downloadComments(for: recipeId, recipe: recipe)

            // Insert comments into context
            if let comments = recipe.comments {
                for comment in comments {
                    comment.recipe = recipe
                    context.insert(comment)
                }
            }
        } catch {
            Log.error("Failed to fetch comments", category: .firebase, error: error)
        }
    }

    /// Fetch card back from Firestore and restore it to the recipe
    private func fetchAndRestoreCardBack(for recipe: Recipe, recipeId: String, context: ModelContext) async throws {
        do {
            try await collectionSync.downloadCardBack(for: recipeId, recipe: recipe)

            // Insert card back into context
            if let cardBack = recipe.cardBack {
                cardBack.recipe = recipe
                context.insert(cardBack)
            }
        } catch {
            Log.error("Failed to fetch card back", category: .firebase, error: error)
        }
    }

    // MARK: - Helpers

    /// Fetch recipes that need to be synced to Firebase
    /// - Parameter context: SwiftData model context
    /// - Returns: Array of unsynced recipes
    /// - Throws: Error if fetch fails
    func fetchUnsyncedRecipes(context: ModelContext) throws -> [Recipe] {
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

    // MARK: - Deletion Operations

    /// Delete recipe from Firebase (including subcollections and images)
    /// - Parameter recipeId: ID of recipe to delete
    /// - Throws: FirebaseError if delete fails
    func deleteRecipe(_ recipeId: UUID) async throws {
        guard config.isAuthenticated else {
            throw FirebaseError.notAuthenticated
        }

        let recipeIdString = recipeId.uuidString
        let recipeRef = try config.recipeDocument(id: recipeIdString)

        Log.info("Deleting recipe from Firebase", category: .firebase, metadata: ["recipeId": recipeIdString])

        // Delete subcollections first
        try await deleteSubcollection(recipeRef, named: "ingredients")
        try await deleteSubcollection(recipeRef, named: "comments")
        try await deleteSubcollection(recipeRef, named: "metadata")

        // Delete recipe document
        try await recipeRef.delete()

        // Delete image from Storage
        try? await imageService.deleteImage(for: recipeId)

        Log.info("Recipe deleted from Firebase", category: .firebase, metadata: ["recipeId": recipeIdString])
        DeviceLogger.shared.log("✅ [Firebase] Recipe deleted: \(recipeIdString)")
    }

    /// Delete a subcollection from a document
    /// - Parameters:
    ///   - documentRef: Parent document reference
    ///   - subcollection: Name of subcollection to delete
    /// - Throws: FirebaseError if delete fails
    private func deleteSubcollection(_ documentRef: DocumentReference, named subcollection: String) async throws {
        let snapshot = try await documentRef.collection(subcollection).getDocuments()

        for document in snapshot.documents {
            try await document.reference.delete()
        }

        if !snapshot.documents.isEmpty {
            Log.debug("Deleted subcollection documents", category: .firebase, metadata: ["subcollection": subcollection, "count": snapshot.documents.count])
        }
    }

    // MARK: - Automatic Sync

    /// Start automatic background sync
    func startAutomaticSync() {
        guard !isAutoSyncEnabled else { return }
        isAutoSyncEnabled = true

        DeviceLogger.shared.log("🔄 [Firebase] Starting automatic sync...")
        logger.info("🔄 [Firebase] Starting automatic sync...")
        Log.info("Starting automatic sync", category: .sync)

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
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
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
        Log.info("Automatic sync enabled", category: .sync)
    }

    /// Stop automatic background sync
    func stopAutomaticSync() {
        isAutoSyncEnabled = false
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil

        NotificationCenter.default.removeObserver(self)

        Log.info("Automatic sync stopped", category: .sync)
    }
}
