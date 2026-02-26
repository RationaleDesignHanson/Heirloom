//
//  AccountDeletionService.swift
//  Heirloom
//
//  Apple Compliance: Account Deletion Service
//  Coordinates full account deletion across SwiftData, Firestore, Storage, and Auth
//

import Foundation
import SwiftData
import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

/// Represents the progress of account deletion
struct DeletionProgress: Equatable {
    var currentStep: DeletionStep
    var isComplete: Bool = false
    var error: String?

    enum DeletionStep: String, CaseIterable {
        case preparing = "Preparing..."
        case localData = "Deleting local data..."
        case cloudRecipes = "Clearing cloud recipes..."
        case cloudCollections = "Clearing collections..."
        case cloudImages = "Removing images..."
        case cloudProfile = "Removing profile..."
        case cloudConnections = "Clearing connections..."
        case cloudNotifications = "Clearing notifications..."
        case anonymizingLineage = "Anonymizing lineage..."
        case revokingAppleToken = "Revoking Apple sign-in..."
        case deletingAuth = "Deleting account..."
        case complete = "Account deleted"

        var displayText: String { rawValue }

        var stepIndex: Int {
            Self.allCases.firstIndex(of: self) ?? 0
        }

        static var totalSteps: Int {
            Self.allCases.count
        }
    }

    var percentComplete: Double {
        Double(currentStep.stepIndex) / Double(DeletionStep.totalSteps)
    }
}

/// Service for coordinating full account deletion
/// CRITICAL: Must delete ALL user data before deleting Firebase Auth user
@Observable
@MainActor
final class AccountDeletionService {

    // MARK: - Dependencies

    private let firebaseSync: FirebaseSyncService
    private let firebaseAuth: FirebaseAuthService
    private let subscriptionManager: SubscriptionManager
    private let imageStorageService: ImageStorageService
    private let logger: LoggingService

    // MARK: - State

    private(set) var progress: DeletionProgress = DeletionProgress(currentStep: .preparing)
    private(set) var isDeleting = false

    // MARK: - Initialization

    init() {
        self.firebaseSync = ServiceContainer.shared.resolve(FirebaseSyncService.self)
        self.firebaseAuth = ServiceContainer.shared.resolve(FirebaseAuthService.self)
        self.subscriptionManager = ServiceContainer.shared.resolve(SubscriptionManager.self)
        self.imageStorageService = ServiceContainer.shared.resolve(ImageStorageService.self)
        self.logger = ServiceContainer.shared.resolve(LoggingService.self)
    }

    // MARK: - Pre-deletion Checks

    /// Get data summary for confirmation display
    func getDataSummary(context: ModelContext) -> AccountDataSummary {
        let recipeCount = (try? context.fetch(FetchDescriptor<Recipe>()).count) ?? 0
        let collectionCount = (try? context.fetch(FetchDescriptor<RecipeCollection>()).count) ?? 0

        return AccountDataSummary(
            recipeCount: recipeCount,
            collectionCount: collectionCount,
            hasActiveSubscription: subscriptionManager.isPremium && !subscriptionManager.isInTrial,
            subscriptionExpiryDate: subscriptionManager.subscriptionExpiryDate
        )
    }

    /// Check if user has an active paid subscription
    var hasActiveSubscription: Bool {
        subscriptionManager.isPremium && !subscriptionManager.isInTrial
    }

    // MARK: - Account Deletion

    /// Delete all user data and account
    /// CRITICAL: Order matters - delete all data BEFORE deleting Firebase Auth
    /// - Parameters:
    ///   - context: SwiftData model context
    ///   - appleAuthorizationCode: Authorization code from Apple re-auth (for token revocation)
    func deleteAccount(context: ModelContext, appleAuthorizationCode: String? = nil) async throws {
        guard !isDeleting else {
            throw AccountDeletionError.alreadyInProgress
        }

        guard let userId = firebaseAuth.currentUserId else {
            throw AccountDeletionError.notAuthenticated
        }

        isDeleting = true
        progress = DeletionProgress(currentStep: .preparing)

        logger.log("Starting full account deletion for user: \(userId)", category: .auth, level: .info, metadata: nil)

        do {
            // Step 1: Cancel ongoing sync to prevent race conditions
            await firebaseSync.cancelSync()

            // Step 2: Delete local SwiftData
            progress.currentStep = .localData
            try await deleteLocalData(context: context)

            // Step 3: Delete Firebase Firestore data
            progress.currentStep = .cloudRecipes
            try await deleteFirestoreRecipes(userId: userId)

            progress.currentStep = .cloudCollections
            try await deleteFirestoreCollections(userId: userId)

            progress.currentStep = .cloudProfile
            try await deleteFirestoreProfile(userId: userId)

            progress.currentStep = .cloudConnections
            try await deleteFirestoreConnections(userId: userId)

            progress.currentStep = .cloudNotifications
            try await deleteFirestoreNotifications(userId: userId)

            // Step 4: Anonymize lineage records where user is owner
            progress.currentStep = .anonymizingLineage
            try await anonymizeLineageRecords(userId: userId)

            // Step 5: Delete Firebase Storage images
            progress.currentStep = .cloudImages
            try await deleteStorageImages(userId: userId)

            // Step 6: Clear local user defaults and in-memory caches
            clearUserDefaults()
            clearServiceCaches()

            // Step 7: Revoke Apple Sign-In token (if applicable)
            // CRITICAL: Apple requires token revocation for Sign in with Apple users
            if let authCode = appleAuthorizationCode {
                progress.currentStep = .revokingAppleToken
                try await revokeAppleToken(authorizationCode: authCode)
            }

            // Step 8: Delete Firebase Auth user (LAST STEP)
            progress.currentStep = .deletingAuth
            try await firebaseAuth.deleteAccount()

            // Complete
            progress.currentStep = .complete
            progress.isComplete = true
            isDeleting = false

            logger.log("Account deletion completed successfully", category: .auth, level: .info, metadata: nil)

        } catch {
            progress.error = error.localizedDescription
            isDeleting = false

            logger.log("Account deletion failed: \(error.localizedDescription)", category: .auth, level: .error, metadata: nil)

            throw error
        }
    }

    // MARK: - Local Data Deletion

    private func deleteLocalData(context: ModelContext) async throws {
        logger.log("Deleting local SwiftData...", category: .storage, level: .info, metadata: nil)

        // Delete all recipes (cascades to ingredients, comments, cardbacks, etc.)
        let recipes = try context.fetch(FetchDescriptor<Recipe>())
        for recipe in recipes {
            // Force-resolve optional attributes to prevent SwiftData faulting errors
            _ = recipe.sourceType
            _ = recipe.sourceURL
            _ = recipe.imageFileName
            _ = recipe.ingredients
            _ = recipe.tags
            _ = recipe.collections
            context.delete(recipe)
        }

        // Delete all collections
        let collections = try context.fetch(FetchDescriptor<RecipeCollection>())
        for collection in collections {
            context.delete(collection)
        }

        // Delete all tags
        let tags = try context.fetch(FetchDescriptor<Tag>())
        for tag in tags {
            context.delete(tag)
        }

        // Delete all shopping cart items
        let cartItems = try context.fetch(FetchDescriptor<ShoppingCartRecipe>())
        for item in cartItems {
            context.delete(item)
        }

        // Delete all dinner parties
        let parties = try context.fetch(FetchDescriptor<DinnerParty>())
        for party in parties {
            context.delete(party)
        }

        // Delete user credits
        let credits = try context.fetch(FetchDescriptor<UserCredits>())
        for credit in credits {
            context.delete(credit)
        }

        // Delete customizations
        let customizations = try context.fetch(FetchDescriptor<Customization>())
        for customization in customizations {
            context.delete(customization)
        }

        // Delete tombstones
        let tombstones = try context.fetch(FetchDescriptor<DeletedCollectionRecord>())
        for tombstone in tombstones {
            context.delete(tombstone)
        }

        try context.save()

        // Clean up local image files
        _ = await imageStorageService.cleanupOrphanedImages(validImageFileNames: [])

        logger.log("Local data deleted successfully", category: .storage, level: .info, metadata: nil)
    }

    // MARK: - Firestore Deletion

    private func deleteFirestoreRecipes(userId: String) async throws {
        let db = Firestore.firestore()
        let recipesRef = db.collection("users/\(userId)/recipes")

        logger.log("Deleting Firestore recipes...", category: .firebase, level: .info, metadata: nil)

        let snapshot = try await recipesRef.getDocuments()

        for doc in snapshot.documents {
            // Delete subcollections first
            let ingredientsSnapshot = try await doc.reference.collection("ingredients").getDocuments()
            for ingredient in ingredientsSnapshot.documents {
                try await ingredient.reference.delete()
            }

            let commentsSnapshot = try await doc.reference.collection("comments").getDocuments()
            for comment in commentsSnapshot.documents {
                try await comment.reference.delete()
            }

            let cardBackSnapshot = try await doc.reference.collection("cardBack").getDocuments()
            for cardBack in cardBackSnapshot.documents {
                try await cardBack.reference.delete()
            }

            // Delete the recipe document
            try await doc.reference.delete()
        }

        logger.log("Deleted \(snapshot.documents.count) recipes from Firestore", category: .firebase, level: .info, metadata: nil)
    }

    private func deleteFirestoreCollections(userId: String) async throws {
        let db = Firestore.firestore()
        let collectionsRef = db.collection("users/\(userId)/collections")

        logger.log("Deleting Firestore collections...", category: .firebase, level: .info, metadata: nil)

        let snapshot = try await collectionsRef.getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }

        // Also delete tags
        let tagsRef = db.collection("users/\(userId)/tags")
        let tagsSnapshot = try await tagsRef.getDocuments()
        for doc in tagsSnapshot.documents {
            try await doc.reference.delete()
        }

        logger.log("Deleted \(snapshot.documents.count) collections from Firestore", category: .firebase, level: .info, metadata: nil)
    }

    private func deleteFirestoreProfile(userId: String) async throws {
        let db = Firestore.firestore()

        logger.log("Deleting Firestore profile...", category: .firebase, level: .info, metadata: nil)

        // Delete user parent document (may not exist, but try anyway)
        let userDocRef = db.collection("users").document(userId)
        try? await userDocRef.delete() // Soft fail - may not exist

        // Delete from userProfiles collection (stores display names for version history)
        let userProfileRef = db.collection("userProfiles").document(userId)
        try? await userProfileRef.delete() // Soft fail - may not exist

        // Delete user's public profile if they have one
        // Note: publicProfiles uses slug as document ID, so we query by userId
        let publicProfilesRef = db.collection("publicProfiles")
        let publicProfileQuery = publicProfilesRef.whereField("userId", isEqualTo: userId)
        let publicSnapshot = try? await publicProfileQuery.getDocuments()
        for doc in publicSnapshot?.documents ?? [] {
            try? await doc.reference.delete()
        }

        logger.log("Deleted user profile from Firestore", category: .firebase, level: .info, metadata: nil)
    }

    private func deleteFirestoreConnections(userId: String) async throws {
        let db = Firestore.firestore()
        let connectionsRef = db.collection("users/\(userId)/connections")

        logger.log("Deleting Firestore connections...", category: .firebase, level: .info, metadata: nil)

        let snapshot = try await connectionsRef.getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }

        // Also delete from shopping cart
        let cartRef = db.collection("users/\(userId)/shoppingCart")
        let cartSnapshot = try await cartRef.getDocuments()
        for doc in cartSnapshot.documents {
            try await doc.reference.delete()
        }

        // Delete dinner parties
        let partiesRef = db.collection("users/\(userId)/dinnerParties")
        let partiesSnapshot = try await partiesRef.getDocuments()
        for doc in partiesSnapshot.documents {
            try await doc.reference.delete()
        }

        logger.log("Deleted \(snapshot.documents.count) connections from Firestore", category: .firebase, level: .info, metadata: nil)
    }

    private func deleteFirestoreNotifications(userId: String) async throws {
        let db = Firestore.firestore()
        let notificationsRef = db.collection("users/\(userId)/notifications")

        logger.log("Deleting Firestore notifications...", category: .firebase, level: .info, metadata: nil)

        let snapshot = try await notificationsRef.getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }

        logger.log("Deleted \(snapshot.documents.count) notifications from Firestore", category: .firebase, level: .info, metadata: nil)
    }

    // MARK: - Lineage Anonymization

    private func anonymizeLineageRecords(userId: String) async throws {
        let db = Firestore.firestore()

        logger.log("Anonymizing lineage records...", category: .firebase, level: .info, metadata: nil)

        // Find all lineage records where this user is the owner
        let lineagesRef = db.collection("lineages")
        let ownerQuery = lineagesRef.whereField("ownerId", isEqualTo: userId)
        let ownerSnapshot = try await ownerQuery.getDocuments()

        for doc in ownerSnapshot.documents {
            try await doc.reference.updateData([
                "ownerName": "Deleted User",
                "ownerId": FieldValue.delete()
            ])
        }

        // Find all lineage records where this user is the root owner
        let rootOwnerQuery = lineagesRef.whereField("rootOwnerId", isEqualTo: userId)
        let rootOwnerSnapshot = try await rootOwnerQuery.getDocuments()

        for doc in rootOwnerSnapshot.documents {
            try await doc.reference.updateData([
                "rootOwnerName": "Deleted User",
                "rootOwnerId": FieldValue.delete()
            ])
        }

        // Delete user's own lineages collection
        let userLineagesRef = db.collection("users/\(userId)/lineages")
        let userLineagesSnapshot = try await userLineagesRef.getDocuments()
        for doc in userLineagesSnapshot.documents {
            try await doc.reference.delete()
        }

        // Unpublish any public recipes (remove from discovery)
        let publicRecipesRef = db.collection("publicRecipes")
        let publicQuery = publicRecipesRef.whereField("ownerId", isEqualTo: userId)
        let publicSnapshot = try await publicQuery.getDocuments()

        for doc in publicSnapshot.documents {
            try await doc.reference.delete()
        }

        // Anonymize share documents
        let sharesRef = db.collection("shares")
        let senderQuery = sharesRef.whereField("senderId", isEqualTo: userId)
        let senderSnapshot = try await senderQuery.getDocuments()

        for doc in senderSnapshot.documents {
            try await doc.reference.updateData([
                "senderName": "Deleted User",
                "senderId": FieldValue.delete()
            ])
        }

        logger.log("Anonymized lineage and share records", category: .firebase, level: .info, metadata: nil)
    }

    // MARK: - Storage Deletion

    private func deleteStorageImages(userId: String) async throws {
        let storage = Storage.storage()
        let userStorageRef = storage.reference().child("users/\(userId)")

        logger.log("Deleting Firebase Storage images...", category: .storage, level: .info, metadata: nil)

        do {
            // List all items recursively
            let result = try await userStorageRef.listAll()

            // Delete all items
            for item in result.items {
                try? await item.delete() // Soft fail individual deletions
            }

            // Recursively delete prefixes (folders)
            for prefix in result.prefixes {
                let subResult = try await prefix.listAll()
                for item in subResult.items {
                    try? await item.delete()
                }
            }

            logger.log("Deleted \(result.items.count) images from Firebase Storage", category: .storage, level: .info, metadata: nil)

        } catch {
            // Storage folder may not exist - this is OK
            if (error as NSError).code == StorageErrorCode.objectNotFound.rawValue {
                logger.log("No storage folder found for user (OK)", category: .storage, level: .info, metadata: nil)
            } else {
                throw error
            }
        }
    }

    // MARK: - User Defaults

    private func clearUserDefaults() {
        logger.log("Clearing UserDefaults...", category: .storage, level: .info, metadata: nil)

        let keysToRemove = [
            "firebase_lastSyncDate",
            "lastSyncTimestamp",
            "OnboardingRecipeSeeded",
            "hasCompletedOnboarding",
            "subscription_status",
            "subscription_expiry_date",
            "trial_expiry_date",
            "first_launch_date",
            "cached_product_id",
            "hasSeenPrivacyNotice",
            // Theme tracker keys (must match ThemeUnlockTracker.Keys)
            "theme_trial_start_date",
            "selected_theme_ids",
            "unlocked_recipe_ids",
            "last_unlock_check_date",
            "last_unlock_day",
            // Legacy theme keys
            "lastThemeUnlockDate",
            "unlockedThemeRecipeIds"
        ]

        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
        }

        UserDefaults.standard.synchronize()

        logger.log("UserDefaults cleared", category: .storage, level: .info, metadata: nil)
    }

    /// Clear in-memory caches from profile services
    /// Prevents stale user data from appearing after deletion
    private func clearServiceCaches() {
        logger.log("Clearing service caches...", category: .storage, level: .info, metadata: nil)

        // Clear FirebaseUserProfileService cache
        if let profileService = ServiceContainer.shared.resolveOptional(FirebaseUserProfileService.self) {
            profileService.clearCache()
        }

        // Clear FirebaseProfileService cache
        if let socialProfileService = ServiceContainer.shared.resolveOptional(FirebaseProfileService.self) {
            socialProfileService.clearCache()
        }

        logger.log("Service caches cleared", category: .storage, level: .info, metadata: nil)
    }

    // MARK: - Apple Token Revocation

    /// Revoke Apple Sign-In token (Apple compliance requirement)
    /// Must be called before deleting Firebase Auth user for Sign in with Apple users
    private func revokeAppleToken(authorizationCode: String) async throws {
        logger.log("Revoking Apple Sign-In token...", category: .auth, level: .info, metadata: nil)

        do {
            // Firebase provides this method to revoke Apple tokens
            try await Auth.auth().revokeToken(withAuthorizationCode: authorizationCode)
            logger.log("Apple Sign-In token revoked successfully", category: .auth, level: .info, metadata: nil)
        } catch {
            // Log but don't fail - account deletion should still proceed
            // Apple will clean up orphaned tokens eventually
            logger.log("Failed to revoke Apple token (non-fatal): \(error.localizedDescription)", category: .auth, level: .warning, metadata: nil)
        }
    }
}

// MARK: - Supporting Types

struct AccountDataSummary {
    let recipeCount: Int
    let collectionCount: Int
    let hasActiveSubscription: Bool
    let subscriptionExpiryDate: Date?

    var hasSignificantData: Bool {
        recipeCount > 0 || collectionCount > 0
    }
}

enum AccountDeletionError: LocalizedError {
    case notAuthenticated
    case alreadyInProgress
    case firestoreDeletionFailed(Error)
    case storageDeletionFailed(Error)
    case authDeletionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to delete your account"
        case .alreadyInProgress:
            return "Account deletion is already in progress"
        case .firestoreDeletionFailed(let error):
            return "Failed to delete cloud data: \(error.localizedDescription)"
        case .storageDeletionFailed(let error):
            return "Failed to delete images: \(error.localizedDescription)"
        case .authDeletionFailed(let error):
            return "Failed to delete account: \(error.localizedDescription)"
        }
    }
}
