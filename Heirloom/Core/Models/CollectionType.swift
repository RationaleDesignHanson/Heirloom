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

    /// Recipes imported from multi-page cookbook scans (CookbookScannerView)
    case cookbook = "cookbook"

    /// User-created custom collections
    case userCreated = "userCreated"

    // MARK: - Display Properties

    var displayName: String {
        switch self {
        case .system: return "System"
        case .theme: return "Discovery"
        case .fromFriends: return "From Friends"
        case .videoImports: return "From Videos"
        case .webImports: return "From Web"
        case .photoImports: return "From Photos"
        case .cookbook: return "From Cookbooks"
        case .userCreated: return "My Collection"
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
        case .cookbook: return "book.closed.fill"
        case .userCreated: return "folder.fill"
        }
    }

    /// Whether this collection type should show on the main Collections page
    var isVisibleInMainList: Bool {
        switch self {
        case .system: return false
        case .theme, .fromFriends, .videoImports, .webImports, .photoImports, .cookbook, .userCreated: return true
        }
    }

    /// Sort priority for collections list (lower = higher priority)
    /// NOTE: My Collections section appears ABOVE Your Discoveries (themes)
    var sortPriority: Int {
        switch self {
        case .fromFriends: return 0
        case .videoImports: return 1
        case .webImports: return 2
        case .photoImports: return 3
        case .cookbook: return 4
        case .userCreated: return 5
        case .theme: return 10  // Themes appear AFTER My Collections
        case .system: return 99
        }
    }
}
