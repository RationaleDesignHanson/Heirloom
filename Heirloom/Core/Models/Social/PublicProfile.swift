//
//  PublicProfile.swift
//  Heirloom
//
//  Social Layer Phase 2: Public Profile Model
//  Read-only public view of a user's profile for public URLs
//

import Foundation

/// Public-facing profile for users who have enabled public URLs
/// Stored in Firestore at publicProfiles/{slug}
/// Contains only information the user has chosen to make public
struct PublicProfile: Codable, Identifiable {
    // MARK: - Identity

    /// Public profile slug (URL-friendly identifier)
    /// Example: "italian-nonna" -> heirloom.app/cook/italian-nonna
    let id: String // This is the slug

    /// Firebase user ID (for linking to full profile if user has access)
    let userId: String

    /// Display name
    var displayName: String

    /// Profile photo URL
    var photoURL: String?

    /// User's @handle (if they have one)
    var handle: String?

    // MARK: - Public Profile Content

    /// Bio or description (sanitized, max 280 chars)
    var bio: String?

    /// Location (if user chose to share)
    var location: String?

    /// Cooking specialties
    var specialties: [String]?

    /// External website URL
    var websiteURL: String?

    // MARK: - Stats (based on privacy settings)

    /// Number of public recipes (if user allows)
    var publicRecipeCount: Int?

    /// Number of recipe generations (if user allows heritage stats)
    var heritageGenerationCount: Int?

    /// Total recipe acceptance count (if user allows)
    var recipeAcceptanceCount: Int?

    /// Number of connections (if user shows connection count)
    var connectionCount: Int?

    /// When user joined Heirloom (if user allows)
    var joinedAt: Date?

    // MARK: - Verification

    /// Whether this is a verified account
    var isVerified: Bool

    /// Type of verification
    var verificationType: VerificationType?

    // MARK: - Featured Content

    /// Featured recipe IDs (recipes user has chosen to showcase)
    var featuredRecipeIds: [String]?

    /// Featured Kitchen Table IDs (if any are public)
    var featuredKitchenTableIds: [String]?

    // MARK: - SEO & Discovery

    /// Keywords for search/discovery (user-provided)
    var searchKeywords: [String]?

    /// Whether this profile is indexed for search engines
    var isSearchIndexed: Bool

    // MARK: - Metadata

    /// When this public profile was created
    let createdAt: Date

    /// When this public profile was last updated
    var updatedAt: Date

    /// View count (for analytics)
    var viewCount: Int

    /// Last time this profile was viewed
    var lastViewedAt: Date?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case displayName
        case photoURL
        case handle
        case bio
        case location
        case specialties
        case websiteURL
        case publicRecipeCount
        case heritageGenerationCount
        case recipeAcceptanceCount
        case connectionCount
        case joinedAt
        case isVerified
        case verificationType
        case featuredRecipeIds
        case featuredKitchenTableIds
        case searchKeywords
        case isSearchIndexed
        case createdAt
        case updatedAt
        case viewCount
        case lastViewedAt
    }

    // MARK: - Initialization

    init(
        slug: String,
        userId: String,
        displayName: String,
        photoURL: String? = nil
    ) {
        self.id = slug
        self.userId = userId
        self.displayName = displayName
        self.photoURL = photoURL
        self.handle = nil
        self.bio = nil
        self.location = nil
        self.specialties = nil
        self.websiteURL = nil
        self.publicRecipeCount = nil
        self.heritageGenerationCount = nil
        self.recipeAcceptanceCount = nil
        self.connectionCount = nil
        self.joinedAt = nil
        self.isVerified = false
        self.verificationType = nil
        self.featuredRecipeIds = nil
        self.featuredKitchenTableIds = nil
        self.searchKeywords = nil
        self.isSearchIndexed = false
        self.createdAt = Date()
        self.updatedAt = Date()
        self.viewCount = 0
        self.lastViewedAt = nil
    }
}

// MARK: - Helper Extensions

extension PublicProfile {
    /// Full public URL for this profile
    var publicURL: URL? {
        return URL(string: "https://heirloom.app/cook/\(id)")
    }

    /// Shareable URL text
    var shareableURL: String {
        return "heirloom.app/cook/\(id)"
    }

    /// @mention handle if available
    var mentionHandle: String? {
        guard let handle = handle else { return nil }
        return "@\(handle)"
    }

    /// Whether this profile has any stats to show
    var hasStats: Bool {
        return publicRecipeCount != nil ||
               heritageGenerationCount != nil ||
               recipeAcceptanceCount != nil ||
               connectionCount != nil
    }

    /// Whether this profile has featured content
    var hasFeaturedContent: Bool {
        return !(featuredRecipeIds?.isEmpty ?? true) ||
               !(featuredKitchenTableIds?.isEmpty ?? true)
    }

    /// Sanitized display name (for URL slugs)
    static func sanitizeSlug(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        return input
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: allowed.inverted)
            .joined()
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Validate slug format
    static func isValidSlug(_ slug: String) -> Bool {
        let pattern = "^[a-z0-9][a-z0-9-]{1,48}[a-z0-9]$"
        return slug.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Search & Discovery

extension PublicProfile {
    /// Search score for relevance (used by discovery algorithm)
    func searchScore(for query: String) -> Int {
        var score = 0
        let queryLower = query.lowercased()

        // Exact match on display name = highest score
        if displayName.lowercased() == queryLower {
            score += 100
        } else if displayName.lowercased().contains(queryLower) {
            score += 50
        }

        // Match on handle
        if let handle = handle?.lowercased(), handle.contains(queryLower) {
            score += 40
        }

        // Match on bio
        if let bio = bio?.lowercased(), bio.contains(queryLower) {
            score += 20
        }

        // Match on specialties
        if let specialties = specialties {
            for specialty in specialties {
                if specialty.lowercased().contains(queryLower) {
                    score += 10
                }
            }
        }

        // Match on keywords
        if let keywords = searchKeywords {
            for keyword in keywords {
                if keyword.lowercased().contains(queryLower) {
                    score += 15
                }
            }
        }

        // Boost verified accounts
        if isVerified {
            score += 25
        }

        // Boost popular accounts
        if let recipeCount = publicRecipeCount, recipeCount > 10 {
            score += min(recipeCount / 10, 20)
        }

        return score
    }
}
