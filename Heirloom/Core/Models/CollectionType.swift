//
//  CollectionType.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import Foundation

/// Types of recipe collections with different behaviors
enum CollectionType: String, Codable, CaseIterable {
    /// System collections (All Recipes, Favorites) - hidden from main view
    case system = "system"

    /// User-selected discovery themes with progressive unlocking
    case theme = "theme"

    /// Recipes shared by friends
    case fromFriends = "fromFriends"

    /// Recipes imported from video transcription
    case videoImports = "videoImports"

    /// Recipes imported via URL (not from cookbook)
    case webImports = "webImports"

    /// Recipes from single-photo OCR (recipe cards, screenshots, handwritten recipes)
    case photoImports = "photoImports"

    /// Recipes imported from voice dictation (user reads a real recipe aloud)
    case readRecipes = "readRecipes"

    /// Recipes imported from multi-page cookbook scans (CookbookScannerView)
    case cookbook = "cookbook"

    /// User-created custom collections
    case userCreated = "userCreated"

    /// Recipes saved from public discovery
    case communityRecipes = "communityRecipes"

    // MARK: - Display Properties

    var displayName: String {
        switch self {
        case .system: return "System"
        case .theme: return "Discovery"
        case .fromFriends: return "From Friends"
        case .videoImports: return "From Videos"
        case .webImports: return "From Web"
        case .photoImports: return "From Photos"
        case .readRecipes: return "Read Recipes"
        case .cookbook: return "From Cookbooks"
        case .userCreated: return "My Collection"
        case .communityRecipes: return "Community Recipes"
        }
    }

    var defaultIconName: String {
        switch self {
        case .system: return "gear"
        case .theme: return "sparkles"
        case .fromFriends: return "person.2.fill"
        case .videoImports: return "video.fill"
        case .webImports: return "link"
        case .photoImports: return "photo.fill"
        case .readRecipes: return "text.book.closed"
        case .cookbook: return "book.closed.fill"
        case .userCreated: return "folder.fill"
        case .communityRecipes: return "globe"
        }
    }

    /// Whether this collection type should show on the main Collections page
    var isVisibleInMainList: Bool {
        switch self {
        case .system: return false
        case .theme, .fromFriends, .videoImports, .webImports, .photoImports, .readRecipes, .cookbook, .userCreated, .communityRecipes: return true
        }
    }

    /// Sort priority for collections list (lower = higher priority)
    /// NOTE: My Collections section appears ABOVE Your Discoveries (themes)
    var sortPriority: Int {
        switch self {
        case .communityRecipes: return -1  // Community Recipes appears FIRST
        case .fromFriends: return 0
        case .videoImports: return 1
        case .webImports: return 2
        case .readRecipes: return 3
        case .photoImports: return 4
        case .cookbook: return 5
        case .userCreated: return 6
        case .theme: return 10  // Themes appear AFTER My Collections
        case .system: return 99
        }
    }

    // MARK: - Task #6: Collection Categories and Rules

    /// Collection category for organizational grouping
    var category: CollectionCategory {
        switch self {
        case .fromFriends, .videoImports, .webImports, .photoImports, .readRecipes, .communityRecipes:
            return .imported
        case .cookbook:
            return .cookbooks
        case .theme:
            return .themes
        case .userCreated:
            return .user
        case .system:
            return .system
        }
    }

    /// Whether collections of this type can be shared with other users
    var canShare: Bool {
        switch self {
        case .fromFriends:
            // Don't allow resharing recipes from friends (prevents unauthorized redistribution)
            return false
        case .theme:
            // Don't allow sharing theme collections (curated content, licensing)
            return false
        case .system:
            // System collections can't be shared
            return false
        case .communityRecipes:
            // Community recipes can be reshared
            return true
        case .videoImports, .webImports, .photoImports, .readRecipes, .cookbook, .userCreated:
            // User's own imports and collections can be shared
            return true
        }
    }

    /// Whether collections of this type are system-managed (not deletable)
    var isSystemManaged: Bool {
        switch self {
        case .fromFriends, .videoImports, .webImports, .photoImports, .readRecipes, .communityRecipes, .theme, .system:
            // Auto-created collections are system-managed
            return true
        case .cookbook, .userCreated:
            // User-created and cookbook collections can be deleted
            return false
        }
    }

    /// Explanation text when user tries to share a restricted collection
    var shareRestrictionReason: String? {
        switch self {
        case .fromFriends:
            return "Collections of recipes from friends cannot be reshared to prevent unauthorized distribution."
        case .theme:
            return "Theme collections are curated content and cannot be shared individually. Share individual recipes instead."
        case .system:
            return "System collections cannot be shared."
        default:
            return nil
        }
    }
}

/// Collection category for UI grouping
enum CollectionCategory: String, Codable {
    case imported      // System-managed import collections (From Friends, From Web, etc.)
    case cookbooks     // Auto-created from cookbook scans
    case themes        // Curated theme collections (Discovery)
    case user          // User-created custom collections
    case system        // System collections (hidden)

    var displayName: String {
        switch self {
        case .imported: return "Imported"
        case .cookbooks: return "Cookbooks"
        case .themes: return "Themes"
        case .user: return "My Collections"
        case .system: return "System"
        }
    }

    var sectionIcon: String {
        switch self {
        case .imported: return "square.and.arrow.down"
        case .cookbooks: return "book.closed"
        case .themes: return "sparkles"
        case .user: return "folder"
        case .system: return "gear"
        }
    }

    /// Display order for category sections
    var displayOrder: Int {
        switch self {
        case .imported: return 1
        case .cookbooks: return 2
        case .themes: return 3
        case .user: return 4
        case .system: return 99
        }
    }
}
