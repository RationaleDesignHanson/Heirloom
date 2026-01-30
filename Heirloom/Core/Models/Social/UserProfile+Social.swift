//
//  UserProfile+Social.swift
//  Heirloom
//
//  Social Layer Phase 2: User Profile Extensions
//  Adds social features to user profiles without modifying existing Firebase Auth structure
//

import Foundation
import FirebaseAuth

/// Extended user profile model for social features
/// Stored in Firestore at users/{userId}/profile
struct UserProfile: Codable {
    // MARK: - Identity

    /// Firebase Auth user ID
    let userId: String

    /// Display name (from Firebase Auth or custom)
    var displayName: String

    /// Profile photo URL (from Firebase Auth or custom upload)
    var photoURL: String?

    /// Custom handle for @mentions and public profile URLs
    /// Format: alphanumeric + underscores, 3-20 chars, unique across platform
    /// Example: @grandma_rose, heirloom.app/@grandma_rose
    var handle: String?

    // MARK: - Social Profile

    /// Bio or description (max 280 characters)
    var bio: String?

    /// User's location (optional, user-provided text)
    var location: String?

    /// Cooking specialties or interests
    var specialties: [String]?

    /// Link to personal website, blog, or other social media
    var websiteURL: String?

    // MARK: - Kitchen Table

    /// Current Kitchen Table the user is part of (if any)
    /// Kitchen Tables are private cooking groups (family, friends, cooking clubs)
    var currentKitchenTableId: String?

    /// All Kitchen Tables the user has been part of (current + historical)
    var kitchenTableIds: [String]?

    // MARK: - Connections

    /// Number of connections (bidirectional friendships)
    var connectionCount: Int

    /// Number of followers (people following this user)
    var followerCount: Int

    /// Number of people this user is following
    var followingCount: Int

    // MARK: - Recipe Stats

    /// Number of recipes shared with connections
    var sharedRecipeCount: Int

    /// Number of generations this user's recipes have spawned
    var heritageGenerationCount: Int

    /// Total times this user's recipes have been accepted by others
    var recipeAcceptanceCount: Int

    // MARK: - Privacy Settings

    /// Embedded privacy settings (denormalized for quick access)
    var privacySettings: PrivacySettings

    // MARK: - Public Profile

    /// Whether this user has enabled public profile URL
    var hasPublicProfile: Bool

    /// Custom slug for public profile URL (different from handle)
    /// Example: heirloom.app/cook/italian-nonna
    var publicProfileSlug: String?

    // MARK: - Metadata

    /// When the user joined Heirloom
    let joinedAt: Date

    /// Last time profile was updated
    var updatedAt: Date

    /// Last time user was active in the app
    var lastActiveAt: Date?

    /// User's preferred language/locale
    var locale: String?

    // MARK: - Verification

    /// Whether this is a verified account (for notable cooks, chefs, brands)
    var isVerified: Bool

    /// Type of verification (if verified)
    var verificationType: VerificationType?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case userId
        case displayName
        case photoURL
        case handle
        case bio
        case location
        case specialties
        case websiteURL
        case currentKitchenTableId
        case kitchenTableIds
        case connectionCount
        case followerCount
        case followingCount
        case sharedRecipeCount
        case heritageGenerationCount
        case recipeAcceptanceCount
        case privacySettings
        case hasPublicProfile
        case publicProfileSlug
        case joinedAt
        case updatedAt
        case lastActiveAt
        case locale
        case isVerified
        case verificationType
    }

    // MARK: - Initialization

    init(userId: String, displayName: String) {
        self.userId = userId
        self.displayName = displayName
        self.photoURL = nil
        self.handle = nil
        self.bio = nil
        self.location = nil
        self.specialties = nil
        self.websiteURL = nil
        self.currentKitchenTableId = nil
        self.kitchenTableIds = nil
        self.connectionCount = 0
        self.followerCount = 0
        self.followingCount = 0
        self.sharedRecipeCount = 0
        self.heritageGenerationCount = 0
        self.recipeAcceptanceCount = 0
        self.privacySettings = PrivacySettings()
        self.hasPublicProfile = false
        self.publicProfileSlug = nil
        self.joinedAt = Date()
        self.updatedAt = Date()
        self.lastActiveAt = nil
        self.locale = Locale.current.identifier
        self.isVerified = false
        self.verificationType = nil
    }
}

// MARK: - Verification Type

enum VerificationType: String, Codable {
    case chef           // Professional chef
    case author         // Cookbook author
    case influencer     // Food content creator
    case brand          // Restaurant, food brand
    case educator       // Culinary educator
}

// MARK: - Helper Extensions

extension UserProfile {
    /// Full @mention format for display
    var mentionHandle: String? {
        guard let handle = handle else { return nil }
        return "@\(handle)"
    }

    /// Public profile URL if enabled
    var publicProfileURL: URL? {
        guard hasPublicProfile, let slug = publicProfileSlug else { return nil }
        return URL(string: "https://heirloom.app/cook/\(slug)")
    }

    /// Whether this user can be mentioned
    var isMentionable: Bool {
        return handle != nil && privacySettings.allowMentions
    }

    /// Whether this user's profile is publicly visible
    var isPubliclyVisible: Bool {
        return hasPublicProfile && privacySettings.profileVisibility == .public
    }
}
