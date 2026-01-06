//
//  FirebaseConfiguration.swift
//  Heirloom
//
//  Phase 2 Week 3: Service Layer Refactoring
//  Centralized Firebase initialization and configuration
//

import Foundation
import SwiftData
import os.log
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

/// Centralized Firebase configuration and authentication helpers
/// Provides access to Firebase instances and user-scoped collection references
@MainActor
class FirebaseConfiguration: FirebaseConfigurationProtocol {

    // MARK: - Dependencies

    private let logger: LoggingService

    // MARK: - Initialization

    init(logger: LoggingService) {
        self.logger = logger
    }

    // MARK: - Dependencies

    /// Shared Firestore instance (settings configured in HeirloomApp.init)
    lazy var db: Firestore = {
        Firestore.firestore()
    }()

    /// Firebase Auth instance
    var auth: Auth {
        Auth.auth()
    }

    /// Firebase Storage instance
    var storage: Storage {
        Storage.storage()
    }

    // MARK: - State

    internal var modelContext: ModelContext?

    // MARK: - Configuration

    /// Configure Firebase services with SwiftData model context
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext

        // Trigger lazy initialization of Firestore
        _ = db

        logger.log("FirebaseConfiguration configured with model context", category: .firebase, level: .info, metadata: nil)
    }

    // MARK: - User Authentication

    /// Get current authenticated user ID
    /// Returns nil if user is not authenticated
    var currentUserId: String? {
        auth.currentUser?.uid
    }

    /// Check if user is currently authenticated
    var isAuthenticated: Bool {
        currentUserId != nil
    }

    // MARK: - Collection References

    /// Get user's recipes collection reference
    /// - Throws: FirebaseError.notAuthenticated if user not authenticated
    func recipesCollection() throws -> CollectionReference {
        guard let userId = currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        return db.collection("users/\(userId)/recipes")
    }

    /// Get specific recipe document reference
    /// - Parameter id: Recipe document ID
    /// - Throws: FirebaseError.notAuthenticated if user not authenticated
    func recipeDocument(id: String) throws -> DocumentReference {
        try recipesCollection().document(id)
    }

    /// Get user's tags collection reference
    /// - Throws: FirebaseError.notAuthenticated if user not authenticated
    func tagsCollection() throws -> CollectionReference {
        guard let userId = currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        return db.collection("users/\(userId)/tags")
    }

    /// Get user's collections collection reference
    /// - Throws: FirebaseError.notAuthenticated if user not authenticated
    func collectionsCollection() throws -> CollectionReference {
        guard let userId = currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        return db.collection("users/\(userId)/collections")
    }

    /// Get user's shopping cart collection reference
    /// - Throws: FirebaseError.notAuthenticated if user not authenticated
    func shoppingCartCollection() throws -> CollectionReference {
        guard let userId = currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        return db.collection("users/\(userId)/shoppingCart")
    }

    /// Get user's dinner parties collection reference
    /// - Throws: FirebaseError.notAuthenticated if user not authenticated
    func dinnerPartiesCollection() throws -> CollectionReference {
        guard let userId = currentUserId else {
            throw FirebaseError.notAuthenticated
        }
        return db.collection("users/\(userId)/dinnerParties")
    }

    // MARK: - Subcollection References

    /// Get ingredients subcollection for a recipe
    /// - Parameter recipeId: Recipe document ID
    /// - Throws: FirebaseError.notAuthenticated if user not authenticated
    func ingredientsSubcollection(recipeId: String) throws -> CollectionReference {
        try recipeDocument(id: recipeId).collection("ingredients")
    }

    /// Get comments subcollection for a recipe
    /// - Parameter recipeId: Recipe document ID
    /// - Throws: FirebaseError.notAuthenticated if user not authenticated
    func commentsSubcollection(recipeId: String) throws -> CollectionReference {
        try recipeDocument(id: recipeId).collection("comments")
    }

    /// Get card back document for a recipe
    /// - Parameter recipeId: Recipe document ID
    /// - Throws: FirebaseError.notAuthenticated if user not authenticated
    func cardBackDocument(recipeId: String) throws -> DocumentReference {
        try recipeDocument(id: recipeId).collection("metadata").document("cardBack")
    }
}

// MARK: - Errors

/// Firebase service errors
enum FirebaseError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case networkUnavailable
    case uploadFailed(Error)
    case downloadFailed(Error)
    case conflict
    case recipeNotFound
    case contextNotSet
    case invalidData
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Firebase services not configured with model context"
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
        case .invalidData:
            return "Invalid data received from Firebase"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        }
    }
}
