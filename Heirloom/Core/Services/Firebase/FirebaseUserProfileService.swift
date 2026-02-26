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

        // Check demo user static data
        if let demoInfo = DemoSocialBehaviorService.demoUserInfo[userId] {
            let name = demoInfo.displayName
            profileCache[userId] = name
            return name
        }

        Log.warning("No display name found for user", category: .auth, metadata: ["userId": userId])
        return nil
    }

    /// Sync current user's profile to Firestore
    /// Call this after sign-in to ensure display name is persisted
    /// Writes to users/{userId}/profile/data to trigger Algolia indexing
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

        // Get theme selections from UserDefaults
        let selectedThemeIds = UserDefaults.standard.stringArray(forKey: "selected_theme_ids") ?? []
        let trialStartDate = UserDefaults.standard.object(forKey: "theme_trial_start_date") as? Date

        // Check if user has completed onboarding (from local UserDefaults)
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        Log.info("Profile sync - checking local state", category: .auth, metadata: [
            "hasCompletedOnboarding": hasCompletedOnboarding,
            "selectedThemeCount": selectedThemeIds.count,
            "hasTrialStartDate": trialStartDate != nil
        ])

        // Profile data for the main profile document (triggers Algolia sync)
        var profileData: [String: Any] = [
            "userId": user.uid,
            "displayName": displayName,
            "email": user.email as Any,
            "photoURL": user.photoURL?.absoluteString as Any,
            "updatedAt": Timestamp(date: Date()),
            // Default privacy settings - allow search indexing by default
            "privacySettings": [
                "hideFromSearch": false,
                "showLocationInSearch": true,
                "showSpecialtiesInSearch": true
            ],
            // Initialize social fields
            "connectionCount": 0,
            "followerCount": 0,
            "isVerified": false
        ]

        // Only set hasCompletedOnboarding if actually completed (don't overwrite with false)
        if hasCompletedOnboarding {
            profileData["hasCompletedOnboarding"] = true
        }

        // Include theme selections if present (only sync if user has selected themes)
        if !selectedThemeIds.isEmpty {
            profileData["selectedThemeIds"] = selectedThemeIds
        }
        if let trialStart = trialStartDate {
            profileData["themeTrialStartDate"] = Timestamp(date: trialStart)
        }

        // Write to the correct path that Algolia trigger watches
        // Path: users/{userId}/profile/data
        let profileDocRef = db.collection("users").document(user.uid)
            .collection("profile").document("data")
        try await profileDocRef.setData(profileData, merge: true)

        // Also write to legacy userProfiles collection for backwards compatibility
        let legacyData: [String: Any] = [
            "displayName": displayName,
            "email": user.email as Any,
            "lastUpdated": Timestamp(date: Date()),
            "photoURL": user.photoURL?.absoluteString as Any
        ]
        try await db.collection("userProfiles").document(user.uid).setData(legacyData, merge: true)

        // Update cache
        profileCache[user.uid] = displayName

        Log.info("Synced user profile to Firestore", category: .auth, metadata: [
            "userId": user.uid,
            "displayName": displayName,
            "email": user.email ?? "none",
            "hasCompletedOnboarding": hasCompletedOnboarding,
            "selectedThemeCount": selectedThemeIds.count
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

    /// Sync a single theme's added date to Firebase
    /// Called when user adds a theme from ThemePacksSheet
    func syncThemeAddedDate(themeId: String, addedDate: Date) async throws {
        guard let userId = auth.currentUser?.uid else {
            Log.warning("Cannot sync theme added date - no authenticated user", category: .auth)
            return
        }

        // Get existing theme added dates or start fresh
        let profileDocRef = db.collection("users").document(userId)
            .collection("profile").document("data")

        let doc = try? await profileDocRef.getDocument()
        var themeAddedDates = doc?.data()?["themeAddedDates"] as? [String: Timestamp] ?? [:]

        // Add/update this theme's date
        themeAddedDates[themeId] = Timestamp(date: addedDate)

        // Also update selectedThemeIds array
        var selectedThemeIds = doc?.data()?["selectedThemeIds"] as? [String] ?? []
        if !selectedThemeIds.contains(themeId) {
            selectedThemeIds.append(themeId)
        }

        try await profileDocRef.setData([
            "themeAddedDates": themeAddedDates,
            "selectedThemeIds": selectedThemeIds,
            "updatedAt": Timestamp(date: Date())
        ], merge: true)

        Log.info("Synced theme added date to Firebase", category: .auth, metadata: [
            "themeId": themeId,
            "addedDate": addedDate.description
        ])
    }

    /// Get theme added dates that were restored from Firebase
    /// Used by syncThemeDataOnLogin to apply dates to RecipeTheme objects
    private(set) var restoredThemeAddedDates: [String: Date] = [:]

    /// Restore theme selections from Firebase profile (for returning users)
    /// Returns true if theme data was restored
    @discardableResult
    func restoreThemeSelectionsFromFirebase() async -> Bool {
        guard let userId = auth.currentUser?.uid else {
            Log.warning("Cannot restore theme selections - no authenticated user", category: .auth)
            return false
        }

        do {
            let profileDoc = try await db.collection("users").document(userId)
                .collection("profile").document("data").getDocument()

            guard let data = profileDoc.data() else {
                Log.info("No profile data to restore themes from", category: .auth, metadata: [
                    "userId": userId
                ])
                return false
            }

            var restored = false
            var restoredThemeIds: [String] = []

            // Restore theme selections
            if let themeIds = data["selectedThemeIds"] as? [String], !themeIds.isEmpty {
                let currentThemes = UserDefaults.standard.stringArray(forKey: "selected_theme_ids") ?? []
                if currentThemes.isEmpty {
                    UserDefaults.standard.set(themeIds, forKey: "selected_theme_ids")
                    restoredThemeIds = themeIds
                    Log.info("Restored theme selections from Firebase", category: .auth, metadata: [
                        "themeCount": themeIds.count,
                        "themes": themeIds.joined(separator: ", ")
                    ])
                    restored = true
                } else {
                    Log.info("Theme selections already exist locally, skipping restore", category: .auth, metadata: [
                        "localThemes": currentThemes.count,
                        "firebaseThemes": themeIds.count
                    ])
                }
            } else {
                Log.info("No selectedThemeIds in Firebase profile", category: .auth, metadata: [
                    "availableKeys": Array(data.keys).joined(separator: ", ")
                ])
            }

            // Restore trial start date
            if let trialTimestamp = data["themeTrialStartDate"] as? Timestamp {
                let currentStart = UserDefaults.standard.object(forKey: "theme_trial_start_date") as? Date
                if currentStart == nil {
                    let trialDate = trialTimestamp.dateValue()
                    UserDefaults.standard.set(trialDate, forKey: "theme_trial_start_date")

                    // Calculate trial day for logging
                    let daysSinceStart = Calendar.current.dateComponents([.day], from: trialDate, to: Date()).day ?? 0
                    let trialDay = min(max(daysSinceStart + 1, 1), 15)

                    Log.info("Restored trial start date from Firebase", category: .auth, metadata: [
                        "trialStartDate": trialDate.description,
                        "currentTrialDay": trialDay
                    ])
                    restored = true
                }
            }

            // Restore per-theme added dates (new Discovery tab model)
            if let themeAddedDates = data["themeAddedDates"] as? [String: Timestamp] {
                restoredThemeAddedDates = themeAddedDates.mapValues { $0.dateValue() }
                Log.info("Restored theme added dates from Firebase", category: .auth, metadata: [
                    "themeCount": restoredThemeAddedDates.count,
                    "themes": restoredThemeAddedDates.keys.joined(separator: ", ")
                ])
                restored = true
            }

            // Force synchronize UserDefaults to ensure values are persisted immediately
            UserDefaults.standard.synchronize()

            // Post notification to update ThemeUnlockTracker
            if restored {
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ThemeProgressRestored"),
                        object: nil,
                        userInfo: ["selectedThemeIds": restoredThemeIds]
                    )
                }
                Log.info("Posted ThemeProgressRestored notification", category: .auth)
            }

            return restored
        } catch {
            Log.error("Failed to restore theme selections from Firebase", category: .auth, error: error, metadata: [
                "userId": userId
            ])
            return false
        }
    }

    /// Fetch theme added dates directly from Firebase (for just-in-time sync)
    /// Returns empty dictionary if user has no theme selections
    func fetchThemeAddedDatesFromFirebase() async -> [String: Date] {
        guard let userId = Auth.auth().currentUser?.uid else {
            return [:]
        }

        do {
            let doc = try await db.collection("users").document(userId)
                .collection("profile").document("data").getDocument()

            guard let data = doc.data(),
                  let themeAddedDates = data["themeAddedDates"] as? [String: Timestamp] else {
                return [:]
            }

            return themeAddedDates.mapValues { $0.dateValue() }
        } catch {
            Log.error("Failed to fetch theme dates from Firebase", category: .theme, error: error)
            return [:]
        }
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
