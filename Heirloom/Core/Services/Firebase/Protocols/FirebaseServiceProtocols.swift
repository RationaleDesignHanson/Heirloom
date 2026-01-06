//
//  FirebaseServiceProtocols.swift
//  Heirloom
//
//  Phase 2 Week 4: Protocol Abstraction Layer
//  Protocol-based service contracts for dependency injection
//

import Foundation
import UIKit
import SwiftData
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

// MARK: - Configuration Protocol

/// Protocol for Firebase configuration and initialization
@MainActor
protocol FirebaseConfigurationProtocol {
    /// Firestore database instance
    var db: Firestore { get }

    /// Firebase Auth instance
    var auth: Auth { get }

    /// Firebase Storage instance
    var storage: Storage { get }

    /// SwiftData model context
    var modelContext: ModelContext? { get set }

    /// Current authenticated user ID
    var currentUserId: String? { get }

    /// Whether user is authenticated
    var isAuthenticated: Bool { get }

    /// Configure Firebase with model context
    func configure(modelContext: ModelContext)

    // MARK: - Collection References

    /// Get recipes collection reference
    func recipesCollection() throws -> CollectionReference

    /// Get recipe document reference
    func recipeDocument(id: String) throws -> DocumentReference

    /// Get ingredients subcollection reference
    func ingredientsSubcollection(recipeId: String) throws -> CollectionReference

    /// Get comments subcollection reference
    func commentsSubcollection(recipeId: String) throws -> CollectionReference

    /// Get card back document reference
    func cardBackDocument(recipeId: String) throws -> DocumentReference

    /// Get collections collection reference
    func collectionsCollection() throws -> CollectionReference

    /// Get tags collection reference
    func tagsCollection() throws -> CollectionReference

    /// Get shopping cart collection reference
    func shoppingCartCollection() throws -> CollectionReference

    /// Get dinner parties collection reference
    func dinnerPartiesCollection() throws -> CollectionReference
}

// MARK: - Record Converter Protocol

/// Protocol for data transformation between SwiftData and Firestore
protocol FirebaseRecordConverterProtocol {
    /// Convert Recipe to Firestore data
    static func convertToFirestoreData(_ recipe: Recipe) -> [String: Any]

    /// Convert Firestore data to Recipe
    static func convertFromFirestoreData(_ data: [String: Any], id: String, context: ModelContext) -> Recipe

    /// Convert Ingredient to Firestore data
    static func convertIngredientToFirestoreData(_ ingredient: Ingredient) -> [String: Any]

    /// Convert Firestore data to Ingredient
    static func convertIngredientFromFirestoreData(_ data: [String: Any], id: String) -> Ingredient

    /// Convert RecipeComment to Firestore data
    static func convertCommentToFirestoreData(_ comment: RecipeComment) -> [String: Any]

    /// Convert Firestore data to RecipeComment
    static func convertCommentFromFirestoreData(_ data: [String: Any], id: String) -> RecipeComment

    /// Convert RecipeCardBack to Firestore data
    static func convertCardBackToFirestoreData(_ cardBack: RecipeCardBack) -> [String: Any]

    /// Convert Firestore data to RecipeCardBack
    static func convertCardBackFromFirestoreData(_ data: [String: Any]) -> RecipeCardBack
}

// MARK: - Image Service Protocol

/// Protocol for Firebase Storage image operations
@MainActor
protocol FirebaseImageServiceProtocol {
    /// Upload recipe image to Firebase Storage
    /// - Parameter recipe: Recipe with local image to upload
    /// - Returns: Download URL string, or nil if no image to upload
    /// - Throws: FirebaseError if upload fails
    func uploadImage(for recipe: Recipe) async throws -> String?

    /// Download recipe image from Firebase Storage and cache locally
    /// - Parameter recipe: Recipe with Firebase image URL to download
    /// - Throws: FirebaseError if download fails
    func downloadImage(for recipe: Recipe) async throws

    /// Delete recipe image from Firebase Storage
    /// - Parameter recipeId: ID of recipe whose image should be deleted
    /// - Throws: FirebaseError if delete fails
    func deleteImage(for recipeId: UUID) async throws

    /// Delete image from Firebase Storage by URL
    /// - Parameter url: Firebase Storage URL of image to delete
    /// - Throws: FirebaseError if delete fails
    func deleteImage(at url: String) async throws
}

// MARK: - Collection Sync Protocol

/// Protocol for syncing related entities and collections
@MainActor
protocol FirebaseCollectionSyncProtocol {
    // MARK: - Ingredients

    /// Upload ingredients for a recipe to Firestore subcollection
    func uploadIngredients(_ ingredients: [Ingredient], for recipeId: String) async throws

    /// Download ingredients for a recipe from Firestore subcollection
    func downloadIngredients(for recipeId: String, recipe: Recipe) async throws

    // MARK: - Comments

    /// Upload comments for a recipe to Firestore subcollection
    func uploadComments(_ comments: [RecipeComment], for recipeId: String) async throws

    /// Download comments for a recipe from Firestore subcollection
    func downloadComments(for recipeId: String, recipe: Recipe) async throws

    // MARK: - Card Back

    /// Upload card back for a recipe to Firestore
    func uploadCardBack(_ cardBack: RecipeCardBack, for recipeId: String) async throws

    /// Download card back for a recipe from Firestore
    func downloadCardBack(for recipeId: String, recipe: Recipe) async throws

    // MARK: - Collections

    /// Upload collection to Firebase
    func uploadCollection(_ collection: RecipeCollection) async throws

    /// Delete collection from Firebase
    func deleteCollection(_ collectionId: UUID) async throws

    // MARK: - Tags

    /// Upload tag to Firebase
    func uploadTag(_ tag: Tag) async throws

    /// Delete tag from Firebase
    func deleteTag(_ tagId: UUID) async throws

    // MARK: - Shopping Cart

    /// Upload shopping cart recipe to Firebase
    func uploadShoppingCartRecipe(_ cartRecipe: ShoppingCartRecipe) async throws

    /// Delete shopping cart recipe from Firebase
    func deleteShoppingCartRecipe(_ cartRecipeId: UUID) async throws

    // MARK: - Dinner Parties

    /// Upload dinner party to Firebase
    func uploadDinnerParty(_ party: DinnerParty) async throws

    /// Delete dinner party from Firebase
    func deleteDinnerParty(_ partyId: UUID) async throws
}

// MARK: - Recipe Sync Protocol

/// Protocol for recipe-level sync orchestration
@MainActor
protocol FirebaseRecipeSyncProtocol: ObservableObject {
    /// Whether sync is in progress
    var isSyncing: Bool { get }

    /// Last successful sync date
    var lastSyncDate: Date? { get }

    /// Last sync error if any
    var syncError: Error? { get }

    /// Upload a single recipe to Firebase
    /// - Parameter recipe: Recipe to upload
    /// - Throws: FirebaseError if upload fails
    func uploadRecipe(_ recipe: Recipe) async throws

    /// Upload multiple recipes to Firebase
    /// - Parameter recipes: Array of recipes to upload
    /// - Throws: FirebaseError if any upload fails
    func uploadRecipes(_ recipes: [Recipe]) async throws

    /// Download a single recipe from Firebase
    /// - Parameters:
    ///   - recipeId: ID of recipe to download
    ///   - context: SwiftData model context
    /// - Returns: Downloaded recipe
    /// - Throws: FirebaseError if download fails
    func downloadRecipe(id recipeId: String, context: ModelContext) async throws -> Recipe

    /// Download all user's recipes from Firebase
    /// - Parameter context: SwiftData model context
    /// - Returns: Array of downloaded recipes
    /// - Throws: FirebaseError if download fails
    func downloadAllRecipes(context: ModelContext) async throws -> [Recipe]

    /// Sync local changes to Firebase and download remote changes
    /// - Throws: FirebaseError if sync fails
    func syncChanges() async throws

    /// Delete recipe from Firebase
    /// - Parameter recipeId: ID of recipe to delete
    /// - Throws: FirebaseError if delete fails
    func deleteRecipe(_ recipeId: UUID) async throws

    /// Start automatic background sync
    func startAutomaticSync()

    /// Stop automatic background sync
    func stopAutomaticSync()
}

// MARK: - Sync Service Protocol

/// Protocol for main Firebase sync orchestration
@MainActor
protocol FirebaseSyncServiceProtocol: ObservableObject {
    /// Configure sync with model context
    func configure(modelContext: ModelContext)

    /// Upload recipe to Firebase
    func uploadRecipe(_ recipe: Recipe) async throws

    /// Upload recipe to Firebase with transactional semantics
    func uploadRecipeTransactional(_ recipe: Recipe) async throws

    /// Download recipe from Firebase
    func downloadRecipe(id: String, context: ModelContext) async throws -> Recipe

    /// Download all recipes from Firebase
    func downloadAllRecipes(context: ModelContext) async throws -> [Recipe]

    /// Sync all local changes to Firebase
    func syncChanges() async throws

    /// Sync changes with CRDT-based conflict resolution
    func syncChangesWithCRDT() async throws

    /// Delete recipe from Firebase
    func deleteRecipe(_ recipeId: UUID) async throws

    /// Start automatic background sync
    func startAutomaticSync()

    /// Stop automatic background sync
    func stopAutomaticSync()

    /// Convert Firestore data to Recipe
    func convertFromFirestoreData(_ data: [String: Any], id: String, context: ModelContext) -> Recipe

    /// Convert Ingredient from Firestore data
    func convertIngredientFromFirestoreData(_ data: [String: Any], id: String) -> Ingredient

    /// Convert Comment from Firestore data
    func convertCommentFromFirestoreData(_ data: [String: Any], id: String) -> RecipeComment

    /// Convert CardBack from Firestore data
    func convertCardBackFromFirestoreData(_ data: [String: Any]) -> RecipeCardBack

    /// Upload image for recipe to Firebase Storage
    func uploadImage(for recipe: Recipe) async throws -> String?

    /// Delete image for recipe from Firebase Storage
    func deleteImage(for recipeId: UUID) async throws

    /// Download image for recipe
    func downloadImage(for recipe: Recipe) async throws

    /// Upload tag to Firebase
    func uploadTag(_ tag: Tag) async throws

    /// Delete tag from Firebase
    func deleteTag(_ tagId: UUID) async throws

    /// Upload collection to Firebase
    func uploadCollection(_ collection: RecipeCollection) async throws

    /// Delete collection from Firebase
    func deleteCollection(_ collectionId: UUID) async throws

    /// Upload dinner party to Firebase
    func uploadDinnerParty(_ party: DinnerParty) async throws

    /// Delete dinner party from Firebase
    func deleteDinnerParty(_ partyId: UUID) async throws

    /// Upload card back for a recipe
    func uploadCardBack(_ cardBack: RecipeCardBack, recipeId: UUID) async throws
}

// MARK: - Share Service Protocol

/// Protocol for Firebase recipe sharing
@MainActor
protocol FirebaseShareServiceProtocol {
    /// Create a share for a recipe
    func createShare(
        for recipe: Recipe,
        options: ShareOptions,
        context: ModelContext
    ) async throws -> (shareId: String, shareURL: URL)

    /// Accept a shared recipe
    func acceptShare(
        shareId: String,
        context: ModelContext
    ) async throws -> Recipe

    /// Fetch share metadata without accepting
    func fetchShareMetadata(shareId: String) async throws -> [String: Any]

    /// Revoke a share
    func revokeShare(shareId: String) async throws

    /// List all shares for a recipe
    func listShares(for recipe: Recipe) async throws -> [[String: Any]]

    /// Generate shareable URL
    func generateShareURL(shareId: String) -> URL

    /// Generate web-friendly shareable URL
    func generateWebShareURL(shareId: String) -> URL
}

// MARK: - Lineage Service Protocol

/// Protocol for recipe lineage tracking
@MainActor
protocol FirebaseLineageServiceProtocol: ObservableObject {
    /// Create root lineage for a new recipe
    func createRootLineage(
        recipeId: UUID,
        context: ModelContext
    ) async throws

    /// Create descendant lineage when accepting shared recipe
    func createDescendantLineage(
        rootRecipeId: UUID,
        parentRecipeId: UUID,
        currentRecipeId: UUID,
        rootOwnerId: String,
        generation: Int,
        sharedByName: String?,
        context: ModelContext
    ) async throws

    /// Record a modification to a recipe
    func recordModification(
        recipeId: UUID,
        changeType: ModificationRecord.ChangeType,
        changeDescription: String,
        fieldChanged: String?,
        context: ModelContext
    ) async throws

    /// Fetch lineage for a recipe
    func fetchLineage(
        for recipeId: UUID,
        context: ModelContext
    ) throws -> RecipeLineage?

    /// Fetch descendant modifications
    func fetchDescendantModifications(
        for rootRecipeId: UUID
    ) async throws -> [DescendantModification]
}

// MARK: - Notification Service Protocol

/// Protocol for Firebase notification service
@MainActor
protocol FirebaseNotificationServiceProtocol: ObservableObject {
    /// Published notifications array
    var notifications: [LineageNotification] { get }

    /// Published unread count
    var unreadCount: Int { get }

    /// Start listening for notifications
    func startListening()

    /// Stop listening for notifications
    func stopListening()

    /// Get unread notifications for a specific recipe
    func unreadNotifications(for recipeId: UUID) -> [LineageNotification]

    /// Get unread count for a specific recipe
    func unreadCount(for recipeId: UUID) -> Int

    /// Check if there are any unread notifications
    var hasUnreadNotifications: Bool { get }

    /// Mark a notification as read
    func markAsRead(_ notification: LineageNotification) async throws

    /// Mark all notifications for a recipe as read
    func markAllAsRead(for recipeId: UUID) async throws

    /// Mark all notifications as read
    func markAllAsRead() async throws
}

// MARK: - Auth Service Protocol

/// Protocol for Firebase authentication
@MainActor
protocol FirebaseAuthServiceProtocol: ObservableObject {
    /// Whether user is authenticated
    var isAuthenticated: Bool { get }

    /// Current Firebase user
    var currentUser: User? { get }

    /// Current user ID
    var currentUserId: String? { get }

    /// Current user email
    var currentUserEmail: String? { get }

    /// Whether authentication is in progress
    var isAuthenticating: Bool { get }

    /// Authentication error if any
    var authError: Error? { get }

    /// Sign in with Apple
    func signInWithApple() async throws

    /// Sign in with Google
    func signInWithGoogle() async throws

    /// Sign in with email and password
    func signInWithEmail(email: String, password: String) async throws

    /// Create account with email and password
    func createAccountWithEmail(email: String, password: String) async throws

    /// Send password reset email
    func sendPasswordReset(email: String) async throws

    /// Sign out
    func signOut() throws

    /// Delete account
    func deleteAccount() async throws
}
