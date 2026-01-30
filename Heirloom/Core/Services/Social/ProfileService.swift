//
//  ProfileService.swift
//  Heirloom
//
//  Social Layer Phase 3: User Profile Service
//  Manages user profiles, public profiles, handles, and avatar uploads
//

import Foundation
import UIKit
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

// MARK: - Protocol

/// Protocol for user profile management
@MainActor
protocol ProfileServiceProtocol {
    /// Fetch current authenticated user's profile
    func fetchCurrentUserProfile() async throws -> UserProfile

    /// Update current user's profile
    func updateProfile(_ profile: UserProfile) async throws

    /// Upload avatar image and update profile
    func uploadAvatar(_ image: UIImage) async throws -> String

    /// Fetch public profile by slug (e.g., heirloom.app/cook/john-chef)
    func fetchPublicProfile(slug: String) async throws -> PublicProfile?

    /// Create or update public profile from user profile
    func syncPublicProfile(from profile: UserProfile) async throws

    /// Check if handle is available for registration
    func isHandleAvailable(_ handle: String) async throws -> Bool

    /// Check if public profile slug is available
    func isSlugAvailable(_ slug: String) async throws -> Bool

    /// Clear cache (useful for logout or testing)
    func clearCache()
}

// MARK: - Implementation

/// Firebase implementation of profile service
@MainActor
class FirebaseProfileService: ProfileServiceProtocol {

    // MARK: - Dependencies

    private let db: Firestore
    private let auth: Auth
    private let storage: Storage

    // MARK: - Cache

    /// In-memory cache of user profiles (userId -> UserProfile)
    private var profileCache: [String: UserProfile] = [:]

    /// In-memory cache of public profiles (slug -> PublicProfile)
    private var publicProfileCache: [String: PublicProfile] = [:]

    /// Timestamp of last cache clear (for periodic refresh)
    private var lastCacheClear: Date = Date()

    /// Cache expiration time (24 hours)
    private let cacheExpirationSeconds: TimeInterval = 24 * 60 * 60

    // MARK: - Initialization

    init(
        firestore: Firestore = Firestore.firestore(),
        auth: Auth = Auth.auth(),
        storage: Storage = Storage.storage()
    ) {
        self.db = firestore
        self.auth = auth
        self.storage = storage
    }

    // MARK: - Profile Management

    /// Fetch current authenticated user's profile
    func fetchCurrentUserProfile() async throws -> UserProfile {
        guard let userId = auth.currentUser?.uid else {
            Log.error("No authenticated user", category: .social)
            throw NSError(
                domain: "ProfileService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }

        // Clear cache if expired
        clearCacheIfExpired()

        // Check cache first
        if let cached = profileCache[userId] {
            Log.debug("Profile cache hit", category: .social, metadata: ["userId": userId])
            return cached
        }

        // Fetch from Firestore
        let docRef = db.collection("users").document(userId).collection("profile").document("data")
        let snapshot = try await docRef.getDocument()

        guard snapshot.exists, let data = snapshot.data() else {
            // Profile doesn't exist yet - create default profile
            Log.info("Creating default profile for new user", category: .social, metadata: ["userId": userId])
            let newProfile = UserProfile.defaultProfile(userId: userId)
            try await updateProfile(newProfile)
            return newProfile
        }

        // Decode profile
        let profile = try Firestore.Decoder().decode(UserProfile.self, from: data)

        // Update cache
        profileCache[userId] = profile

        Log.info("Fetched user profile", category: .social, metadata: [
            "userId": userId,
            "displayName": profile.displayName,
            "hasHandle": profile.handle != nil
        ])

        return profile
    }

    /// Update current user's profile
    func updateProfile(_ profile: UserProfile) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(
                domain: "ProfileService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }

        // Validate handle if present
        if let handle = profile.handle {
            guard handle.count >= 3 && handle.count <= 30 else {
                throw NSError(
                    domain: "ProfileService",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "Handle must be 3-30 characters"]
                )
            }

            // Check handle availability (skip check if it's unchanged)
            let currentProfile = profileCache[userId]
            if currentProfile?.handle != handle {
                let available = try await isHandleAvailable(handle)
                if !available {
                    throw NSError(
                        domain: "ProfileService",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Handle already taken"]
                    )
                }
            }
        }

        // Update timestamp
        var updatedProfile = profile
        updatedProfile.updatedAt = Date()

        // Encode and save to Firestore
        let data = try Firestore.Encoder().encode(updatedProfile)
        let docRef = db.collection("users").document(userId).collection("profile").document("data")
        try await docRef.setData(data, merge: false)

        // Update cache
        profileCache[userId] = updatedProfile

        Log.info("Updated user profile", category: .social, metadata: [
            "userId": userId,
            "displayName": updatedProfile.displayName
        ])

        // Sync public profile if enabled
        if updatedProfile.hasPublicProfile {
            try await syncPublicProfile(from: updatedProfile)
        }
    }

    /// Upload avatar image and update profile
    func uploadAvatar(_ image: UIImage) async throws -> String {
        guard let userId = auth.currentUser?.uid else {
            throw NSError(
                domain: "ProfileService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }

        // Compress image (max 500KB for avatars)
        guard let imageData = await compressImage(image, maxBytes: 500_000) else {
            throw NSError(
                domain: "ProfileService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Failed to compress avatar image"]
            )
        }

        // Upload to Firebase Storage
        let storagePath = "users/\(userId)/profile/avatar.jpg"
        let storageRef = storage.reference().child(storagePath)

        Log.info("Uploading avatar to Firebase Storage", category: .social, metadata: ["userId": userId])

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)

        // Get download URL
        let downloadURL = try await storageRef.downloadURL()
        let urlString = downloadURL.absoluteString

        Log.info("Avatar uploaded successfully", category: .social, metadata: [
            "userId": userId,
            "url": urlString
        ])

        return urlString
    }

    // MARK: - Public Profile Management

    /// Fetch public profile by slug
    func fetchPublicProfile(slug: String) async throws -> PublicProfile? {
        // Validate slug format
        guard PublicProfile.isValidSlug(slug) else {
            Log.warning("Invalid public profile slug format", category: .social, metadata: ["slug": slug])
            return nil
        }

        // Clear cache if expired
        clearCacheIfExpired()

        // Check cache first
        if let cached = publicProfileCache[slug] {
            Log.debug("Public profile cache hit", category: .social, metadata: ["slug": slug])
            return cached
        }

        // Fetch from Firestore
        let docRef = db.collection("publicProfiles").document(slug)
        let snapshot = try await docRef.getDocument()

        guard snapshot.exists, let data = snapshot.data() else {
            Log.info("Public profile not found", category: .social, metadata: ["slug": slug])
            return nil
        }

        // Decode public profile
        let publicProfile = try Firestore.Decoder().decode(PublicProfile.self, from: data)

        // Update cache
        publicProfileCache[slug] = publicProfile

        // Increment view count (fire and forget)
        Task.detached {
            try? await docRef.updateData([
                "viewCount": FieldValue.increment(Int64(1)),
                "lastViewedAt": Timestamp(date: Date())
            ])
        }

        Log.info("Fetched public profile", category: .social, metadata: [
            "slug": slug,
            "userId": publicProfile.userId
        ])

        return publicProfile
    }

    /// Create or update public profile from user profile
    func syncPublicProfile(from profile: UserProfile) async throws {
        guard profile.hasPublicProfile else {
            Log.debug("Profile doesn't have public profile enabled", category: .social, metadata: ["userId": profile.userId])
            return
        }

        // Generate slug from handle or display name
        let slug: String
        if let handle = profile.handle {
            slug = handle.lowercased()
        } else {
            // Fallback: slugify display name
            slug = profile.displayName
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
        }

        // Validate slug
        guard PublicProfile.isValidSlug(slug) else {
            throw NSError(
                domain: "ProfileService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid slug format: \(slug)"]
            )
        }

        // Check if slug is available (skip if unchanged)
        if profile.publicProfileSlug != slug {
            let available = try await isSlugAvailable(slug)
            if !available {
                throw NSError(
                    domain: "ProfileService",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "Public profile slug already taken"]
                )
            }
        }

        // Create public profile
        let publicProfile = PublicProfile(
            id: slug,
            userId: profile.userId,
            displayName: profile.displayName,
            photoURL: profile.photoURL,
            bio: profile.bio,
            location: profile.location,
            specialties: profile.specialties,
            websiteURL: profile.websiteURL,
            publicRecipeCount: nil, // Will be updated by recipe sync
            heritageGenerationCount: profile.heritageGenerationCount > 0 ? profile.heritageGenerationCount : nil,
            joinedAt: profile.joinedAt,
            isVerified: profile.isVerified,
            verificationType: profile.verificationType,
            featuredRecipeIds: nil, // User can set this separately
            featuredKitchenTableIds: nil,
            isSearchIndexed: profile.privacySettings.allowSearchIndexing,
            createdAt: Date(),
            updatedAt: Date()
        )

        // Save to Firestore
        let data = try Firestore.Encoder().encode(publicProfile)
        try await db.collection("publicProfiles").document(slug).setData(data, merge: true)

        // Update user profile with slug
        var updatedProfile = profile
        updatedProfile.publicProfileSlug = slug
        try await updateProfile(updatedProfile)

        // Update cache
        publicProfileCache[slug] = publicProfile

        Log.info("Synced public profile", category: .social, metadata: [
            "userId": profile.userId,
            "slug": slug
        ])
    }

    // MARK: - Validation

    /// Check if handle is available for registration
    func isHandleAvailable(_ handle: String) async throws -> Bool {
        let normalizedHandle = handle.lowercased()

        // Query users with this handle
        let query = db.collectionGroup("profile")
            .whereField("handle", isEqualTo: normalizedHandle)
            .limit(to: 1)

        let snapshot = try await query.getDocuments()
        let isAvailable = snapshot.documents.isEmpty

        Log.debug("Handle availability check", category: .social, metadata: [
            "handle": handle,
            "available": isAvailable
        ])

        return isAvailable
    }

    /// Check if public profile slug is available
    func isSlugAvailable(_ slug: String) async throws -> Bool {
        let docRef = db.collection("publicProfiles").document(slug)
        let snapshot = try await docRef.getDocument()
        let isAvailable = !snapshot.exists

        Log.debug("Slug availability check", category: .social, metadata: [
            "slug": slug,
            "available": isAvailable
        ])

        return isAvailable
    }

    // MARK: - Cache Management

    /// Clear the entire cache (useful for testing or logout)
    func clearCache() {
        profileCache.removeAll()
        publicProfileCache.removeAll()
        lastCacheClear = Date()
        Log.info("Cleared profile cache", category: .social)
    }

    /// Clear cache if it has expired
    private func clearCacheIfExpired() {
        let timeSinceLastClear = Date().timeIntervalSince(lastCacheClear)

        if timeSinceLastClear > cacheExpirationSeconds {
            Log.info("Profile cache expired, clearing", category: .social, metadata: [
                "age": "\(Int(timeSinceLastClear))s"
            ])
            clearCache()
        }
    }

    // MARK: - Image Compression

    /// Compress UIImage to target size
    private func compressImage(_ image: UIImage, maxBytes: Int) async -> Data? {
        var workingImage = image

        // Resize first if image is too large (avatars should be square-ish)
        let maxDimension: CGFloat = 800
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

        // Iteratively reduce quality until under max size
        var compression: CGFloat = 0.9
        var imageData = workingImage.jpegData(compressionQuality: compression)

        while let data = imageData, data.count > maxBytes && compression > 0.1 {
            compression -= 0.1
            imageData = workingImage.jpegData(compressionQuality: compression)
        }

        return imageData
    }
}
