//
//  FirebaseUserProfileService.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-14.
//  Provides user profile lookup with caching
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Service for fetching and caching user display names
/// Used for showing modifier names in lineage history
@MainActor
class FirebaseUserProfileService {

    // MARK: - Properties

    private let db: Firestore
    private let auth: Auth

    /// In-memory cache of user profiles (userId -> displayName)
    private var profileCache: [String: String] = [:]

    /// Timestamp of last cache clear (for periodic refresh)
    private var lastCacheClear: Date = Date()

    /// Cache expiration time (24 hours)
    private let cacheExpirationSeconds: TimeInterval = 24 * 60 * 60

    // MARK: - Initialization

    init(firestore: Firestore = Firestore.firestore(), auth: Auth = Auth.auth()) {
        self.db = firestore
        self.auth = auth
    }

    // MARK: - Public Methods

    /// Fetch display name for a user ID
    /// Uses cache first, falls back to Firestore, then Firebase Auth
    func fetchDisplayName(for userId: String) async throws -> String? {
        // Clear cache if expired
        clearCacheIfExpired()

        // Check cache first
        if let cachedName = profileCache[userId] {
            Log.debug("User profile cache hit", category: .auth, metadata: ["userId": userId, "name": cachedName])
            return cachedName
        }

        // Try Firestore user profiles collection
        if let firestoreName = try? await fetchFromFirestore(userId: userId) {
            profileCache[userId] = firestoreName
            return firestoreName
        }

        // Fallback: Try Firebase Auth (only works for current user)
        if userId == auth.currentUser?.uid, let authName = auth.currentUser?.displayName {
            profileCache[userId] = authName
            return authName
        }

        Log.warning("No display name found for user", category: .auth, metadata: ["userId": userId])
        return nil
    }

    /// Sync current user's profile to Firestore
    /// Call this after sign-in to ensure display name is persisted
    func syncCurrentUserProfile() async throws {
        guard let user = auth.currentUser else {
            throw NSError(domain: "FirebaseUserProfileService", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "No authenticated user"
            ])
        }

        guard let displayName = user.displayName, !displayName.isEmpty else {
            Log.warning("Current user has no display name to sync", category: .auth)
            return
        }

        let profileData: [String: Any] = [
            "displayName": displayName,
            "email": user.email as Any,
            "lastUpdated": Timestamp(date: Date()),
            "photoURL": user.photoURL?.absoluteString as Any
        ]

        try await db.collection("userProfiles").document(user.uid).setData(profileData, merge: true)

        // Update cache
        profileCache[user.uid] = displayName

        Log.info("Synced user profile to Firestore", category: .auth, metadata: [
            "userId": user.uid,
            "displayName": displayName
        ])
    }

    /// Manually set a display name in cache (for testing or immediate updates)
    func setCachedDisplayName(_ name: String, for userId: String) {
        profileCache[userId] = name
        Log.debug("Manually cached display name", category: .auth, metadata: ["userId": userId, "name": name])
    }

    /// Clear the entire cache (useful for testing or logout)
    func clearCache() {
        profileCache.removeAll()
        lastCacheClear = Date()
        Log.info("Cleared user profile cache", category: .auth)
    }

    // MARK: - Private Methods

    /// Fetch user profile from Firestore
    private func fetchFromFirestore(userId: String) async throws -> String? {
        let doc = try await db.collection("userProfiles").document(userId).getDocument()

        guard doc.exists, let data = doc.data() else {
            Log.debug("No Firestore profile for user", category: .auth, metadata: ["userId": userId])
            return nil
        }

        // Try display name first, fall back to email username
        if let displayName = data["displayName"] as? String, !displayName.isEmpty {
            Log.info("Fetched user profile from Firestore", category: .auth, metadata: [
                "userId": userId,
                "displayName": displayName
            ])
            return displayName
        }

        // Fallback: Use email username (part before @)
        if let email = data["email"] as? String, !email.isEmpty {
            let username = email.components(separatedBy: "@").first ?? email
            Log.info("Using email username as fallback display name", category: .auth, metadata: [
                "userId": userId,
                "email": email,
                "username": username
            ])
            return username
        }

        Log.warning("No display name or email found in Firestore profile", category: .auth, metadata: ["userId": userId])
        return nil
    }

    /// Clear cache if it has expired
    private func clearCacheIfExpired() {
        let timeSinceLastClear = Date().timeIntervalSince(lastCacheClear)

        if timeSinceLastClear > cacheExpirationSeconds {
            Log.info("User profile cache expired, clearing", category: .auth, metadata: [
                "age": "\(Int(timeSinceLastClear))s"
            ])
            clearCache()
        }
    }
}
