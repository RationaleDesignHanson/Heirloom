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

    /// Recipes imported via URL (not from cookbook)
    case imports = "imports"

    /// Recipes imported from a scanned/imported cookbook
    case cookbook = "cookbook"

    /// User-created custom collections
    case userCreated = "userCreated"

    // MARK: - Display Properties

    var displayName: String {
        switch self {
        case .system: return "System"
        case .theme: return "Discovery"
        case .fromFriends: return "From Friends"
        case .imports: return "My Imports"
        case .cookbook: return "Cookbook"
        case .userCreated: return "My Collection"
        }
    }

    var defaultIconName: String {
        switch self {
        case .system: return "gear"
        case .theme: return "sparkles"
        case .fromFriends: return "person.2.fill"
        case .imports: return "square.and.arrow.down.fill"
        case .cookbook: return "book.closed.fill"
        case .userCreated: return "folder.fill"
        }
    }

    /// Whether this collection type should show on the main Collections page
    var isVisibleInMainList: Bool {
        switch self {
        case .system: return false
        case .theme, .fromFriends, .imports, .cookbook, .userCreated: return true
        }
    }

    /// Sort priority for collections list (lower = higher priority)
    var sortPriority: Int {
        switch self {
        case .theme: return 0
        case .fromFriends: return 1
        case .imports: return 2
        case .cookbook: return 3
        case .userCreated: return 4
        case .system: return 99
        }
    }
}
