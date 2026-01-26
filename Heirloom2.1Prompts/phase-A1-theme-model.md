# Heirloom Collections Overhaul
## Phase A1: Theme Model & Types

**Branch:** `feature/collections-A1-theme-model`
**Estimated Time:** 30-45 minutes
**Dependencies:** None (foundational)

---

## Objective

Create the core data models for the theme-based recipe discovery system. This replaces the "heritage" concept with a more flexible "theme" system.

---

## Task A1.1: Create RecipeTheme Model

**New File:** `Heirloom/Core/Models/RecipeTheme.swift`

```swift
//
//  RecipeTheme.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import Foundation
import SwiftData

/// A curated theme of recipes users can select during onboarding
@Model
final class RecipeTheme {
    // MARK: - Identity
    var id: UUID = UUID()
    var firebaseId: String // Reference to Firebase document
    
    // MARK: - Display
    var name: String
    var tagline: String // Short hook: "Recipes from restaurants that no longer exist"
    var themeDescription: String // Note: 'description' is reserved in Swift
    var iconName: String // SF Symbol
    var coverImageURL: String?
    
    // MARK: - Classification
    var category: ThemeCategory
    var source: String? // "MSU Feeding America", "Horn & Hardart", etc.
    var era: String? // "1940s", "Victorian", etc.
    var region: String? // "American South", "Scandinavian", etc.
    
    // MARK: - Content
    var totalRecipes: Int
    var unlockSchedule: [Int] // Days on which recipes unlock [1, 3, 5, 7, 10, 14]
    
    // MARK: - User State
    var isSelected: Bool = false
    var sortOrder: Int = 0
    
    // MARK: - Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // MARK: - Relationships
    @Relationship(deleteRule: .nullify, inverse: \RecipeCollection.sourceTheme)
    var collection: RecipeCollection?
    
    init(
        firebaseId: String,
        name: String,
        tagline: String,
        themeDescription: String,
        iconName: String,
        category: ThemeCategory,
        totalRecipes: Int,
        unlockSchedule: [Int]
    ) {
        self.firebaseId = firebaseId
        self.name = name
        self.tagline = tagline
        self.themeDescription = themeDescription
        self.iconName = iconName
        self.category = category
        self.totalRecipes = totalRecipes
        self.unlockSchedule = unlockSchedule
    }
}

// MARK: - Theme Category

enum ThemeCategory: String, Codable, CaseIterable {
    case cuisine = "cuisine"
    case era = "era"
    case source = "source"
    case difficulty = "difficulty"
    case dietary = "dietary"
    
    var displayName: String {
        switch self {
        case .cuisine: return "World Cuisines"
        case .era: return "Eras & Nostalgia"
        case .source: return "Hidden Treasures"
        case .difficulty: return "By Effort"
        case .dietary: return "Dietary"
        }
    }
    
    var iconName: String {
        switch self {
        case .cuisine: return "globe"
        case .era: return "clock.arrow.circlepath"
        case .source: return "archivebox"
        case .difficulty: return "timer"
        case .dietary: return "leaf"
        }
    }
    
    /// Sort order for display
    var sortOrder: Int {
        switch self {
        case .source: return 0      // Hidden Treasures first (most unique)
        case .era: return 1
        case .cuisine: return 2
        case .difficulty: return 3
        case .dietary: return 4
        }
    }
}
```

---

## Task A1.2: Create CollectionType Enum

**New File:** `Heirloom/Core/Models/CollectionType.swift`

```swift
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
```

---

## Task A1.3: Update RecipeCollection Model

**File:** `Heirloom/Core/Models/RecipeCollection.swift`

**Add these properties to the existing RecipeCollection model:**

```swift
// Add to RecipeCollection @Model class:

// MARK: - Type Classification
var collectionType: CollectionType = .userCreated

// MARK: - Theme Relationship (for theme collections)
var sourceTheme: RecipeTheme?

// MARK: - Computed Properties

/// Subtitle text for collection cards
var subtitleText: String {
    switch collectionType {
    case .theme:
        guard let theme = sourceTheme else {
            return "\(recipes?.count ?? 0) recipes"
        }
        let unlocked = recipes?.count ?? 0
        let total = theme.totalRecipes
        if unlocked < total {
            return "\(unlocked) of \(total) recipes unlocked"
        } else {
            return "All \(total) recipes unlocked"
        }
    case .fromFriends:
        return "Recipes shared with you"
    case .imports:
        return "Saved from the web"
    case .cookbook:
        return sourceCookbook ?? "Cookbook recipes"
    case .userCreated:
        let count = recipes?.count ?? 0
        return "\(count) recipe\(count == 1 ? "" : "s")"
    case .system:
        return ""
    }
}

/// Whether this collection should appear in the main list
var isVisibleInMainList: Bool {
    // Must be a visible type
    guard collectionType.isVisibleInMainList else { return false }
    
    // Must have recipes (no empty collections)
    guard (recipes?.count ?? 0) > 0 else { return false }
    
    return true
}
```

**Also add if not present:**

```swift
// For cookbook imports
var sourceCookbook: String?

// For tracking recipe origin
var sourceURL: String?
```

---

## Task A1.4: Update Recipe Model

**File:** `Heirloom/Core/Models/Recipe.swift`

**Add these properties for curated recipe tracking:**

```swift
// Add to Recipe @Model class:

// MARK: - Curation Metadata

/// Whether this recipe came from curated theme content
var isCurated: Bool = false

/// The theme this recipe belongs to (for curated recipes)
var sourceThemeId: String?

/// The day this recipe unlocks (1-14, for curated recipes)
var unlockDay: Int?

/// Historical context or story about this recipe
var story: String?

/// Original source attribution (e.g., "Horn & Hardart Archives, 1952")
var sourceAttribution: String?

// MARK: - Sharing Metadata

/// Name of person who shared this recipe
var sharedBy: String?

/// When the recipe was shared
var sharedAt: Date?
```

---

## Verification Checklist

- [ ] `RecipeTheme.swift` compiles without errors
- [ ] `CollectionType.swift` compiles without errors
- [ ] `RecipeCollection.swift` additions compile
- [ ] `Recipe.swift` additions compile
- [ ] Run `xcodebuild` - no compiler errors
- [ ] SwiftData migration handled (if needed)

---

## Commit Message

```
feat(models): Add theme-based collection infrastructure

- Create RecipeTheme model for curated recipe themes
- Add ThemeCategory enum for theme classification
- Create CollectionType enum for collection routing
- Update RecipeCollection with type and theme relationship
- Update Recipe with curation and sharing metadata

Part of collections overhaul Phase A1
```

---

## Next Phase

→ **Phase A2:** Rename Heritage services to Theme services
