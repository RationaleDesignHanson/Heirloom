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

    /// Optional profile photo URL
    let photoURL: String?

    /// Optional user bio
    let bio: String?
}
