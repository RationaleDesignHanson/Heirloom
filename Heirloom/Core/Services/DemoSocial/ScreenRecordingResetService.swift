//
//  ScreenRecordingResetService.swift
//  Heirloom
//
//  Service for resetting app to first-time user state for screen recordings.
//  Clears local data, Firebase user data, and social connections while preserving theme data.
//

import Foundation
import SwiftData
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

/// Service for managing screen recording resets and mock data visibility
@MainActor
final class ScreenRecordingResetService: ObservableObject {

    // MARK: - Singleton

    static let shared = ScreenRecordingResetService()

    // MARK: - Published State

    @Published var isResetting = false
    @Published var resetProgress: String = ""
    @Published var lastResetVerification: ResetVerification?

    // MARK: - Dependencies

    private let db: Firestore?
    private let auth: Auth?
    private let storage: Storage?

    // MARK: - Initialization

    private init() {
        self.db = Firestore.firestore()
        self.auth = Auth.auth()
        self.storage = Storage.storage()
    }

    // MARK: - Reset Verification

    struct ResetVerification {
        let timestamp: Date
        let localRecipesRemaining: Int
        let localCollectionsRemaining: Int
        let firebaseRecipesRemaining: Int
        let firebaseConnectionsRemaining: Int
        let themeRecipesPreserved: Int
        let success: Bool
        let errors: [String]

        var summary: String {
            if success {
                return "Reset complete. Theme recipes: \(themeRecipesPreserved)"
            } else {
                return "Reset had issues: \(errors.joined(separator: ", "))"
            }
        }
    }

    // MARK: - First Time User Reset

    /// Reset app to first-time user state
    /// - Clears local SwiftData (user recipes, collections)
    /// - Clears Firebase user data (recipes, collections, connections, notifications)
    /// - Removes user from demo users' connection lists
    /// - Preserves theme recipes locally and in Firebase
    func resetToFirstTimeUser(context: ModelContext) async throws -> ResetVerification {
        guard let userId = auth?.currentUser?.uid else {
            throw ResetError.notAuthenticated
        }

        isResetting = true
        var errors: [String] = []

        defer {
            isResetting = false
            resetProgress = ""
        }

        // Step 1: Clear local SwiftData
        resetProgress = "Clearing local data..."
        let (localRecipesDeleted, localCollectionsDeleted, themeCount) = try await clearLocalData(context: context)
        Log.info("Local data cleared", category: .general, metadata: [
            "recipes_deleted": localRecipesDeleted,
            "collections_deleted": localCollectionsDeleted,
            "theme_preserved": themeCount
        ])

        // Step 2: Clear Firebase user data
        resetProgress = "Clearing cloud data..."
        do {
            try await clearFirebaseUserData(userId: userId)
        } catch {
            errors.append("Firebase clear failed: \(error.localizedDescription)")
            Log.error("Failed to clear Firebase data", category: .general, metadata: ["error": error.localizedDescription])
        }

        // Step 3: Remove user from demo users' connections
        resetProgress = "Cleaning up social connections..."
        do {
            try await removeUserFromDemoConnections(userId: userId)
        } catch {
            errors.append("Demo connections cleanup failed: \(error.localizedDescription)")
            Log.error("Failed to clean demo connections", category: .general, metadata: ["error": error.localizedDescription])
        }

        // Step 4: Reset onboarding state
        resetProgress = "Resetting app state..."
        resetOnboardingState()

        // Step 5: Verify reset
        resetProgress = "Verifying reset..."
        let verification = try await verifyReset(context: context, userId: userId, themeCount: themeCount, errors: errors)

        lastResetVerification = verification
        return verification
    }

    // MARK: - Clear Local Data

    private func clearLocalData(context: ModelContext) async throws -> (recipesDeleted: Int, collectionsDeleted: Int, themePreserved: Int) {
        // Fetch all non-theme recipes
        let recipeDescriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { !$0.isThemeRecipe }
        )
        let userRecipes = try context.fetch(recipeDescriptor)
        let recipesDeleted = userRecipes.count

        // Delete user recipes
        for recipe in userRecipes {
            // Force-resolve relationships to prevent faulting errors
            _ = recipe.ingredients
            _ = recipe.collections
            _ = recipe.tags
            context.delete(recipe)
        }

        // Fetch all collections (non-system, non-theme)
        let collectionDescriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { !$0.isSystemCollection && !$0.isAllRecipes }
        )
        let collections = try context.fetch(collectionDescriptor)

        // Delete non-theme collections
        var collectionsDeleted = 0
        for collection in collections {
            if collection.sourceTheme == nil {
                // Create tombstone for sync
                let tombstone = DeletedCollectionRecord(collectionId: collection.id)
                context.insert(tombstone)
                context.delete(collection)
                collectionsDeleted += 1
            }
        }

        // Count preserved theme recipes
        let themeDescriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isThemeRecipe }
        )
        let themeCount = try context.fetchCount(themeDescriptor)

        try context.save()

        return (recipesDeleted, collectionsDeleted, themeCount)
    }

    // MARK: - Clear Firebase User Data

    private func clearFirebaseUserData(userId: String) async throws {
        guard let db = db else { return }

        let batch = db.batch()

        // Clear recipes subcollection
        let recipesRef = db.collection("users").document(userId).collection("recipes")
        let recipesSnapshot = try await recipesRef.getDocuments()
        for doc in recipesSnapshot.documents {
            // Delete subcollections first (ingredients, comments, cardBack)
            try await deleteSubcollections(parentRef: doc.reference)
            batch.deleteDocument(doc.reference)
        }

        // Clear collections subcollection
        let collectionsRef = db.collection("users").document(userId).collection("collections")
        let collectionsSnapshot = try await collectionsRef.getDocuments()
        for doc in collectionsSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }

        // Clear connections subcollection
        let connectionsRef = db.collection("users").document(userId).collection("connections")
        let connectionsSnapshot = try await connectionsRef.getDocuments()
        for doc in connectionsSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }

        // Clear notifications subcollection
        let notificationsRef = db.collection("users").document(userId).collection("notifications")
        let notificationsSnapshot = try await notificationsRef.getDocuments()
        for doc in notificationsSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }

        // Clear recipe shares (received)
        let sharesRef = db.collection("users").document(userId).collection("recipeShares")
        let sharesSnapshot = try await sharesRef.getDocuments()
        for doc in sharesSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }

        try await batch.commit()

        // Delete user's images from storage
        try await deleteUserStorage(userId: userId)

        Log.info("Firebase user data cleared", category: .general, metadata: [
            "recipes": recipesSnapshot.documents.count,
            "collections": collectionsSnapshot.documents.count,
            "connections": connectionsSnapshot.documents.count,
            "notifications": notificationsSnapshot.documents.count,
            "shares": sharesSnapshot.documents.count
        ])
    }

    private func deleteSubcollections(parentRef: DocumentReference) async throws {
        guard let db = db else { return }

        let subcollectionNames = ["ingredients", "comments", "cardBack"]

        for name in subcollectionNames {
            let subcollectionRef = parentRef.collection(name)
            let snapshot = try await subcollectionRef.getDocuments()
            for doc in snapshot.documents {
                try await doc.reference.delete()
            }
        }
    }

    private func deleteUserStorage(userId: String) async throws {
        guard let storage = storage else { return }

        let userStorageRef = storage.reference().child("users/\(userId)")

        do {
            let result = try await userStorageRef.listAll()
            for item in result.items {
                try await item.delete()
            }
            // Recursively delete folders
            for prefix in result.prefixes {
                try await deleteStorageFolder(prefix)
            }
        } catch {
            // Storage might be empty - that's OK
            Log.debug("Storage deletion note", category: .general, metadata: ["note": error.localizedDescription])
        }
    }

    private func deleteStorageFolder(_ ref: StorageReference) async throws {
        let result = try await ref.listAll()
        for item in result.items {
            try await item.delete()
        }
        for prefix in result.prefixes {
            try await deleteStorageFolder(prefix)
        }
    }

    // MARK: - Remove User from Demo Connections

    private func removeUserFromDemoConnections(userId: String) async throws {
        guard let db = db else { return }

        let batch = db.batch()
        var deletedCount = 0

        for demoUserId in DemoSocialBehaviorService.demoUserIds {
            // Check if this demo user has a connection record with the current user
            let connectionsRef = db.collection("users").document(demoUserId).collection("connections")
            let snapshot = try await connectionsRef
                .whereField("connectedUserId", isEqualTo: userId)
                .getDocuments()

            for doc in snapshot.documents {
                batch.deleteDocument(doc.reference)
                deletedCount += 1
            }

            // Also check by document ID (connection IDs are shared between both users)
            let userConnectionsRef = db.collection("users").document(userId).collection("connections")
            let userSnapshot = try await userConnectionsRef.getDocuments()

            for userDoc in userSnapshot.documents {
                // Try to delete matching doc from demo user's connections
                let demoDocRef = connectionsRef.document(userDoc.documentID)
                batch.deleteDocument(demoDocRef)
            }
        }

        try await batch.commit()

        Log.info("Removed user from demo connections", category: .general, metadata: [
            "deleted_count": deletedCount
        ])
    }

    // MARK: - Reset Onboarding State

    private func resetOnboardingState() {
        // Clear onboarding completion flag to show first-time user experience
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "hasSeenAddRecipeBanner")
        UserDefaults.standard.removeObject(forKey: "addRecipeBannerDismissCount")

        // Clear any cached sync state
        UserDefaults.standard.removeObject(forKey: "lastFirebaseSyncDate")

        // Clear connection service cache
        ServiceContainer.shared.resolveOptional(ConnectionServiceProtocol.self)?.clearCache()

        Log.info("Onboarding state reset", category: .general)
    }

    // MARK: - Verify Reset

    private func verifyReset(context: ModelContext, userId: String, themeCount: Int, errors: [String]) async throws -> ResetVerification {
        // Check local state
        let localRecipeDescriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { !$0.isThemeRecipe }
        )
        let localRecipesRemaining = try context.fetchCount(localRecipeDescriptor)

        let localCollectionDescriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { !$0.isSystemCollection && !$0.isAllRecipes }
        )
        let localCollections = try context.fetch(localCollectionDescriptor)
        let localCollectionsRemaining = localCollections.filter { $0.sourceTheme == nil }.count

        // Check Firebase state
        var firebaseRecipesRemaining = 0
        var firebaseConnectionsRemaining = 0

        if let db = db {
            let recipesSnapshot = try await db.collection("users").document(userId).collection("recipes").getDocuments()
            firebaseRecipesRemaining = recipesSnapshot.documents.count

            let connectionsSnapshot = try await db.collection("users").document(userId).collection("connections").getDocuments()
            firebaseConnectionsRemaining = connectionsSnapshot.documents.count
        }

        var allErrors = errors
        if localRecipesRemaining > 0 {
            allErrors.append("\(localRecipesRemaining) local recipes not deleted")
        }
        if firebaseRecipesRemaining > 0 {
            allErrors.append("\(firebaseRecipesRemaining) Firebase recipes not deleted")
        }

        let success = localRecipesRemaining == 0 && firebaseRecipesRemaining == 0 && firebaseConnectionsRemaining == 0

        return ResetVerification(
            timestamp: Date(),
            localRecipesRemaining: localRecipesRemaining,
            localCollectionsRemaining: localCollectionsRemaining,
            firebaseRecipesRemaining: firebaseRecipesRemaining,
            firebaseConnectionsRemaining: firebaseConnectionsRemaining,
            themeRecipesPreserved: themeCount,
            success: success,
            errors: allErrors
        )
    }

    // MARK: - Errors

    enum ResetError: LocalizedError {
        case notAuthenticated

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "Not signed in. Please sign in first."
            }
        }
    }
}
