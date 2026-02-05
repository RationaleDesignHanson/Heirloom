//
//  PrivacySettings.swift
//  Heirloom
//
//  Social Layer Phase 2: Privacy Settings Model
//  Granular privacy controls for user profiles and social features
//

import Foundation

/// Privacy settings for user's social features
/// Stored embedded in UserProfile for quick access
/// Also stored separately at users/{userId}/settings/privacy for atomic updates
struct PrivacySettings: Codable {
    // MARK: - Profile Visibility

    /// Who can see this user's profile
    var profileVisibility: ProfileVisibility

    /// Who can see this user's recipe collection
    var recipeVisibility: RecipeVisibility

    /// Who can see this user's Kitchen Table memberships
    var kitchenTableVisibility: KitchenTableVisibility

    // MARK: - Connection Settings

    /// Who can send connection requests to this user
    var whoCanConnect: WhoCanConnect

    /// Whether to auto-accept connection requests from Kitchen Table members
    var autoAcceptKitchenTableConnections: Bool

    /// Whether to show connection count on profile
    var showConnectionCount: Bool

    // MARK: - Recipe Sharing

    /// Who can see recipes this user has shared
    var sharedRecipeVisibility: SharedRecipeVisibility

    /// Whether to allow others to re-share this user's recipes
    var allowRecipeResharing: Bool

    /// Whether to show attribution when recipes are shared
    var showRecipeAttribution: Bool

    // MARK: - Communication

    /// Who can send direct messages (future feature)
    var whoCanMessage: WhoCanMessage

    /// Whether to allow @mentions in comments
    var allowMentions: Bool

    /// Whether to receive connection request notifications
    var notifyConnectionRequests: Bool

    /// Whether to receive recipe share notifications
    var notifyRecipeShares: Bool

    /// Whether to receive Kitchen Table invitation notifications
    var notifyKitchenTableInvites: Bool

    // MARK: - Public Profile

    /// Whether public profile is indexed for search engines
    var allowSearchIndexing: Bool

    /// Whether to show join date on public profile
    var showJoinDate: Bool

    /// Whether to show heritage generation stats on public profile
    var showHeritageStats: Bool

    // MARK: - Data & Analytics

    /// Whether to allow recipe usage analytics (times cooked, acceptance rate)
    var allowAnalytics: Bool

    /// Whether to appear in "Suggested Connections" for others
    var allowConnectionSuggestions: Bool

    // MARK: - Search Privacy

    /// Whether to hide from user search results
    var hideFromSearch: Bool

    /// Whether to show location in search results
    var showLocationInSearch: Bool

    /// Whether to show specialties in search results
    var showSpecialtiesInSearch: Bool

    // MARK: - Initialization

    init() {
        // Default to privacy-first settings
        self.profileVisibility = .connections
        self.recipeVisibility = .connections
        self.kitchenTableVisibility = .connections
        self.whoCanConnect = .everyone
        self.autoAcceptKitchenTableConnections = true
        self.showConnectionCount = true
        self.sharedRecipeVisibility = .connections
        self.allowRecipeResharing = true
        self.showRecipeAttribution = true
        self.whoCanMessage = .connections
        self.allowMentions = true
        self.notifyConnectionRequests = true
        self.notifyRecipeShares = true
        self.notifyKitchenTableInvites = true
        self.allowSearchIndexing = false
        self.showJoinDate = true
        self.showHeritageStats = true
        self.allowAnalytics = true
        self.allowConnectionSuggestions = true
        self.hideFromSearch = false
        self.showLocationInSearch = true
        self.showSpecialtiesInSearch = true
    }

    // MARK: - Custom Decoder (for backward compatibility with missing fields)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = PrivacySettings()

        self.profileVisibility = try container.decodeIfPresent(ProfileVisibility.self, forKey: .profileVisibility) ?? defaults.profileVisibility
        self.recipeVisibility = try container.decodeIfPresent(RecipeVisibility.self, forKey: .recipeVisibility) ?? defaults.recipeVisibility
        self.kitchenTableVisibility = try container.decodeIfPresent(KitchenTableVisibility.self, forKey: .kitchenTableVisibility) ?? defaults.kitchenTableVisibility
        self.whoCanConnect = try container.decodeIfPresent(WhoCanConnect.self, forKey: .whoCanConnect) ?? defaults.whoCanConnect
        self.autoAcceptKitchenTableConnections = try container.decodeIfPresent(Bool.self, forKey: .autoAcceptKitchenTableConnections) ?? defaults.autoAcceptKitchenTableConnections
        self.showConnectionCount = try container.decodeIfPresent(Bool.self, forKey: .showConnectionCount) ?? defaults.showConnectionCount
        self.sharedRecipeVisibility = try container.decodeIfPresent(SharedRecipeVisibility.self, forKey: .sharedRecipeVisibility) ?? defaults.sharedRecipeVisibility
        self.allowRecipeResharing = try container.decodeIfPresent(Bool.self, forKey: .allowRecipeResharing) ?? defaults.allowRecipeResharing
        self.showRecipeAttribution = try container.decodeIfPresent(Bool.self, forKey: .showRecipeAttribution) ?? defaults.showRecipeAttribution
        self.whoCanMessage = try container.decodeIfPresent(WhoCanMessage.self, forKey: .whoCanMessage) ?? defaults.whoCanMessage
        self.allowMentions = try container.decodeIfPresent(Bool.self, forKey: .allowMentions) ?? defaults.allowMentions
        self.notifyConnectionRequests = try container.decodeIfPresent(Bool.self, forKey: .notifyConnectionRequests) ?? defaults.notifyConnectionRequests
        self.notifyRecipeShares = try container.decodeIfPresent(Bool.self, forKey: .notifyRecipeShares) ?? defaults.notifyRecipeShares
        self.notifyKitchenTableInvites = try container.decodeIfPresent(Bool.self, forKey: .notifyKitchenTableInvites) ?? defaults.notifyKitchenTableInvites
        self.allowSearchIndexing = try container.decodeIfPresent(Bool.self, forKey: .allowSearchIndexing) ?? defaults.allowSearchIndexing
        self.showJoinDate = try container.decodeIfPresent(Bool.self, forKey: .showJoinDate) ?? defaults.showJoinDate
        self.showHeritageStats = try container.decodeIfPresent(Bool.self, forKey: .showHeritageStats) ?? defaults.showHeritageStats
        self.allowAnalytics = try container.decodeIfPresent(Bool.self, forKey: .allowAnalytics) ?? defaults.allowAnalytics
        self.allowConnectionSuggestions = try container.decodeIfPresent(Bool.self, forKey: .allowConnectionSuggestions) ?? defaults.allowConnectionSuggestions
        self.hideFromSearch = try container.decodeIfPresent(Bool.self, forKey: .hideFromSearch) ?? defaults.hideFromSearch
        self.showLocationInSearch = try container.decodeIfPresent(Bool.self, forKey: .showLocationInSearch) ?? defaults.showLocationInSearch
        self.showSpecialtiesInSearch = try container.decodeIfPresent(Bool.self, forKey: .showSpecialtiesInSearch) ?? defaults.showSpecialtiesInSearch
    }

    private enum CodingKeys: String, CodingKey {
        case profileVisibility
        case recipeVisibility
        case kitchenTableVisibility
        case whoCanConnect
        case autoAcceptKitchenTableConnections
        case showConnectionCount
        case sharedRecipeVisibility
        case allowRecipeResharing
        case showRecipeAttribution
        case whoCanMessage
        case allowMentions
        case notifyConnectionRequests
        case notifyRecipeShares
        case notifyKitchenTableInvites
        case allowSearchIndexing
        case showJoinDate
        case showHeritageStats
        case allowAnalytics
        case allowConnectionSuggestions
        case hideFromSearch
        case showLocationInSearch
        case showSpecialtiesInSearch
    }
}

// MARK: - Visibility Enums

enum ProfileVisibility: String, Codable {
    case `public`       // Anyone can view profile
    case connections    // Only connections can view full profile
    case `private`      // Only user can view profile (hidden from others)
}

enum RecipeVisibility: String, Codable {
    case `public`       // Anyone can see shared recipes
    case connections    // Only connections can see shared recipes
    case kitchenTable   // Only Kitchen Table members can see
    case `private`      // Only user can see their recipes
}

enum KitchenTableVisibility: String, Codable {
    case `public`       // Anyone can see Kitchen Table memberships
    case connections    // Only connections can see
    case `private`      // Hidden from everyone
}

enum SharedRecipeVisibility: String, Codable {
    case `public`       // Anyone can see recipes shared by this user
    case connections    // Only connections can see
    case kitchenTable   // Only Kitchen Table members can see
    case `private`      // Only user can see their shared recipes
}

// MARK: - Permission Enums

enum WhoCanConnect: String, Codable {
    case everyone       // Anyone can send connection requests
    case connections    // Only connections of connections can request
    case kitchenTable   // Only Kitchen Table members can request
    case noOne          // No one can send connection requests
}

enum WhoCanMessage: String, Codable {
    case everyone       // Anyone can send messages (future feature)
    case connections    // Only connections can send messages
    case noOne          // No one can send messages
}

// MARK: - Helper Extensions

extension PrivacySettings {
    /// Whether this user's profile is fully public
    var isPublicProfile: Bool {
        return profileVisibility == .public
    }

    /// Whether this user accepts connection requests
    var acceptsConnectionRequests: Bool {
        return whoCanConnect != .noOne
    }

    /// Whether this user's recipes can be discovered publicly
    var hasPublicRecipes: Bool {
        return recipeVisibility == .public || sharedRecipeVisibility == .public
    }

    /// Preset: Maximum privacy
    static var maxPrivacy: PrivacySettings {
        var settings = PrivacySettings()
        settings.profileVisibility = .private
        settings.recipeVisibility = .private
        settings.kitchenTableVisibility = .private
        settings.whoCanConnect = .noOne
        settings.showConnectionCount = false
        settings.sharedRecipeVisibility = .private
        settings.allowRecipeResharing = false
        settings.whoCanMessage = .noOne
        settings.allowMentions = false
        settings.allowSearchIndexing = false
        settings.showHeritageStats = false
        settings.allowConnectionSuggestions = false
        settings.hideFromSearch = true
        settings.showLocationInSearch = false
        settings.showSpecialtiesInSearch = false
        return settings
    }

    /// Preset: Fully public (for content creators)
    static var fullyPublic: PrivacySettings {
        var settings = PrivacySettings()
        settings.profileVisibility = .public
        settings.recipeVisibility = .public
        settings.kitchenTableVisibility = .public
        settings.whoCanConnect = .everyone
        settings.showConnectionCount = true
        settings.sharedRecipeVisibility = .public
        settings.allowRecipeResharing = true
        settings.whoCanMessage = .everyone
        settings.allowMentions = true
        settings.allowSearchIndexing = true
        settings.showHeritageStats = true
        settings.allowConnectionSuggestions = true
        settings.hideFromSearch = false
        settings.showLocationInSearch = true
        settings.showSpecialtiesInSearch = true
        return settings
    }
}
