//
//  UserSearchResult.swift
//  Heirloom
//
//  Phase 7: User Discovery
//  Lightweight model for user search results
//

import Foundation

/// Lightweight model for user search results
/// Used for display in search UI without exposing full UserProfile
struct UserSearchResult: Codable, Identifiable {
    /// Unique user ID
    let id: String

    /// User's display name
    let displayName: String

    /// User's email (for disambiguation when multiple users have same name)
    let email: String?

    /// Optional profile photo URL
    let photoURL: String?

    /// Optional user bio
    let bio: String?

    /// Whether this is a demo/seed user (from Algolia isDemoSeed field)
    let isDemoUser: Bool?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id = "objectID"  // Algolia uses objectID
        case displayName
        case email
        case photoURL
        case bio
        case isDemoUser = "isDemoSeed"
    }

    // MARK: - Convenience

    /// Whether to show demo badge (only if demo mode enabled and user is demo)
    @MainActor
    var shouldShowDemoBadge: Bool {
        (isDemoUser ?? false) && DemoSocialGate.shared.isEnabled
    }
}
