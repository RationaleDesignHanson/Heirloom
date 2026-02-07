//
//  KnownSource.swift
//  Heirloom
//
//  Source Attribution Registry — local cache of known recipe sources.
//  Links recipes to recognized sources (cookbooks, websites, creators, people).
//

import Foundation
import SwiftData

// MARK: - SourceKind

/// The type of recipe source
enum SourceKind: String, Codable, CaseIterable {
    case cookbook        // Physical/PDF cookbooks
    case website        // Recipe websites
    case socialCreator  // TikTok, Instagram, YouTube creators
    case person         // Family members, friends (local only, never synced)
    case brand          // Food brands ("The Flavor Labs")
    case publication    // Magazines, newspapers
    case aiGenerated    // AI-generated recipes
    case unknown
}

// MARK: - SocialPlatform

/// Social media platform for creator sources
enum SocialPlatform: String, Codable, CaseIterable {
    case tiktok
    case instagram
    case youtube
    case facebook
    case pinterest
    case unknown
}

// MARK: - KnownSource Model

@Model
final class KnownSource {
    var id: UUID = UUID()
    var name: String = ""                    // "The Flavor Labs", "AllRecipes.com"
    var normalizedName: String = ""          // "the flavor labs" (lowercase, trimmed)
    var sourceKind: String = ""              // SourceKind raw value
    var domain: String?                      // "allrecipes.com" for URL sources
    var aliases: [String]?                   // ["Flavor Labs", "TheFlavorLabs"]
    var platformUsername: String?            // "@flavorlabs" for social
    var platform: String?                    // SocialPlatform raw value
    var confidence: Double = 0.0            // 0.0-1.0, increases with repeated matches
    var discoveryMethod: String = ""        // "pdf_vision", "url_metadata", "user_manual", "migration"
    var importCount: Int = 0                // Times this source has been seen locally
    var firstSeenDate: Date = Date()
    var lastSeenDate: Date = Date()

    // Firebase sync
    var firebaseCatalogId: String?          // ID in source_catalog/ if contributed
    var isSyncedToFirebase: Bool = false

    // Relationships
    @Relationship(inverse: \Recipe.knownSource) var recipes: [Recipe]? = []

    init(
        name: String,
        kind: SourceKind,
        domain: String? = nil,
        platform: SocialPlatform? = nil,
        platformUsername: String? = nil,
        discoveryMethod: String = "",
        confidence: Double = 0.5
    ) {
        self.id = UUID()
        self.name = name
        self.normalizedName = KnownSource.normalize(name)
        self.sourceKind = kind.rawValue
        self.domain = domain
        self.platform = platform?.rawValue
        self.platformUsername = platformUsername
        self.discoveryMethod = discoveryMethod
        self.confidence = confidence
        self.importCount = 1
        self.firstSeenDate = Date()
        self.lastSeenDate = Date()
    }

    // MARK: - Computed Properties

    var kind: SourceKind {
        get { SourceKind(rawValue: sourceKind) ?? .unknown }
        set { sourceKind = newValue.rawValue }
    }

    var socialPlatform: SocialPlatform? {
        get { platform.flatMap { SocialPlatform(rawValue: $0) } }
        set { platform = newValue?.rawValue }
    }

    /// Increment import count and update last seen date
    func recordSeen() {
        importCount += 1
        lastSeenDate = Date()
        // Increase confidence with each sighting, asymptotically approaching 1.0
        confidence = min(1.0, confidence + (1.0 - confidence) * 0.15)
    }

    // MARK: - Normalization

    /// Normalize a source name for matching (lowercase, trimmed, stripped)
    static func normalize(_ name: String) -> String {
        name.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    /// Extract domain from a URL string
    static func extractDomain(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let host = url.host() else { return nil }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}
