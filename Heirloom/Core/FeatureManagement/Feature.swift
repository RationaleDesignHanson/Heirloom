//
//  Feature.swift
//  Heirloom
//
//  Enum defining all features in the Heirloom app for feature flag management
//  Created: 2026-01-13
//

import Foundation

/// All features in the Heirloom app
/// Each feature can be individually enabled/disabled via feature flags
enum Feature: String, CaseIterable, Codable {
    // MARK: - Core Features

    /// Manual recipe entry and editing
    case recipeManagement = "recipe_management"

    /// Recipe collections and organization
    case collections = "collections"

    /// Recipe tags and categorization
    case tags = "tags"

    /// Recipe comments and notes
    case comments = "comments"

    /// Recipe scaling (adjust servings)
    case scaling = "scaling"

    // MARK: - Premium/Subscription Features

    /// Premium subscription system with trial and paywalls
    case premiumSubscription = "premium_subscription"

    /// Video recipe import (YouTube URLs)
    case videoImport = "video_import"

    /// ASMR video processing (5-pass extraction)
    case asmrProcessing = "asmr_processing"

    /// Recipe sharing via deep links
    case recipeSharing = "recipe_sharing"

    /// iCloud sync across devices
    case cloudSync = "cloud_sync"

    /// Cookbook scanning (photo → recipe)
    case cookbookScan = "cookbook_scan"

    // MARK: - Heritage Features

    /// Blind box heritage collections
    case blindBoxCollections = "blind_box_collections"

    /// Daily heritage recipe unlocks (7 per day during trial)
    case dailyHeritageDrop = "daily_heritage_drop"

    /// Heritage recipe lineage and provenance tracking
    case heritageProvenance = "heritage_provenance"

    // MARK: - Social/Discovery Features

    /// Recipe discovery and recommendations
    case discovery = "discovery"

    /// Dinner party planning and management
    case dinnerParty = "dinner_party"

    // MARK: - Utility Features

    /// Shopping list generation from recipes
    case shoppingLists = "shopping_lists"

    /// Recipe statistics and insights
    case stats = "stats"

    /// User onboarding flow
    case onboarding = "onboarding"

    // MARK: - Upcoming Features

    /// Card customization with stickers (gated until sticker assets are verified)
    case cardCustomization = "card_customization"

    // MARK: - Developer Tools

    /// Debug menu and developer tools
    case debugMenu = "debug_menu"
}

// MARK: - Feature Metadata

extension Feature {
    /// Display name for the feature (shown in debug menu)
    var displayName: String {
        switch self {
        case .recipeManagement: return "Recipe Management"
        case .collections: return "Collections"
        case .tags: return "Tags"
        case .comments: return "Comments"
        case .scaling: return "Recipe Scaling"
        case .premiumSubscription: return "Premium Subscription"
        case .videoImport: return "Video Import"
        case .asmrProcessing: return "ASMR Processing"
        case .recipeSharing: return "Recipe Sharing"
        case .cloudSync: return "Cloud Sync"
        case .cookbookScan: return "Cookbook Scan"
        case .blindBoxCollections: return "Blind Box Collections"
        case .dailyHeritageDrop: return "Daily Heritage Drop"
        case .heritageProvenance: return "Heritage Provenance"
        case .discovery: return "Discovery"
        case .dinnerParty: return "Meal Planning"
        case .shoppingLists: return "Shopping Lists"
        case .stats: return "Stats"
        case .onboarding: return "Onboarding"
        case .cardCustomization: return "Card Customization"
        case .debugMenu: return "Debug Menu"
        }
    }

    /// Short description of the feature
    var description: String {
        switch self {
        case .recipeManagement: return "Create, edit, and manage recipes manually"
        case .collections: return "Organize recipes into collections"
        case .tags: return "Categorize recipes with tags"
        case .comments: return "Add comments and notes to recipes"
        case .scaling: return "Adjust recipe servings automatically"
        case .premiumSubscription: return "In-app purchase system with trial and paywalls"
        case .videoImport: return "Import recipes from YouTube videos"
        case .asmrProcessing: return "Advanced ASMR video extraction (5-pass)"
        case .recipeSharing: return "Share recipes via deep links with lineage tracking"
        case .cloudSync: return "Sync recipes across devices via iCloud"
        case .cookbookScan: return "Extract recipes from cookbook photos"
        case .blindBoxCollections: return "Mystery heritage recipe collections"
        case .dailyHeritageDrop: return "Unlock 7 heritage recipes daily during trial"
        case .heritageProvenance: return "Track recipe lineage and sources"
        case .discovery: return "Discover and explore recommended recipes"
        case .dinnerParty: return "Plan multi-course meals"
        case .shoppingLists: return "Generate shopping lists from recipes"
        case .stats: return "View recipe statistics and insights"
        case .onboarding: return "First-time user onboarding flow"
        case .cardCustomization: return "Sticker decorations on recipe cards"
        case .debugMenu: return "Developer tools and debugging features"
        }
    }

    /// Whether this feature requires premium subscription
    var requiresPremium: Bool {
        switch self {
        case .videoImport, .asmrProcessing, .cloudSync, .cookbookScan:
            return true
        default:
            return false
        }
    }

    /// Feature category for grouping in debug menu
    var category: FeatureCategory {
        switch self {
        case .recipeManagement, .collections, .tags, .comments, .scaling:
            return .core
        case .premiumSubscription, .videoImport, .asmrProcessing, .cloudSync, .cookbookScan:
            return .premium
        case .blindBoxCollections, .dailyHeritageDrop, .heritageProvenance:
            return .heritage
        case .recipeSharing, .discovery, .dinnerParty:
            return .social
        case .shoppingLists, .stats, .onboarding:
            return .utility
        case .cardCustomization:
            return .core
        case .debugMenu:
            return .developer
        }
    }
}

/// Feature category for grouping related features
enum FeatureCategory: String, CaseIterable {
    case core = "Core"
    case premium = "Premium"
    case heritage = "Heritage"
    case social = "Social"
    case utility = "Utility"
    case developer = "Developer"
}
