//
//  FeatureRegistryData.swift
//  Heirloom
//
//  Comprehensive metadata for all features in the Heirloom app
//  Created: 2026-01-13
//

import Foundation

/// Metadata for a feature including dependencies, services, and lifecycle info
struct FeatureMetadata {
    let feature: Feature
    let displayName: String
    let description: String
    let state: FeatureState
    let dependencies: [Feature]
    let requiredServices: [String]
    let testCoverage: Double // 0.0 to 1.0
    let owner: String
    let introducedVersion: String?
    let deprecatedVersion: String?
    let removalVersion: String?
    let documentation: String?
}

/// Lifecycle state of a feature
enum FeatureState: String, CaseIterable {
    case development = "Development"
    case alpha = "Alpha"
    case beta = "Beta"
    case released = "Released"
    case deprecated = "Deprecated"
    case removed = "Removed"

    var requiresTestCoverage: Double {
        switch self {
        case .development:
            return 0.0 // No requirement during development
        case .alpha:
            return 0.4 // 40% coverage for alpha
        case .beta:
            return 0.6 // 60% coverage for beta
        case .released:
            return 0.8 // 80% coverage for released
        case .deprecated:
            return 0.8 // Maintain coverage for deprecated
        case .removed:
            return 0.0 // No longer applicable
        }
    }
}

/// Feature registry with all metadata
final class FeatureRegistry {

    static let shared = FeatureRegistry()

    private init() {}

    // MARK: - Feature Metadata

    private lazy var featureMetadata: [Feature: FeatureMetadata] = [

        // MARK: - Core Features

        .recipeManagement: FeatureMetadata(
            feature: .recipeManagement,
            displayName: "Recipe Management",
            description: "Core recipe CRUD operations, editing, and organization",
            state: .released,
            dependencies: [],
            requiredServices: ["ModelContext", "LoggingService", "AnalyticsService"],
            testCoverage: 0.85,
            owner: "Core Team",
            introducedVersion: "1.0.0",
            deprecatedVersion: nil,
            removalVersion: nil,
            documentation: "Manages all recipe-related operations including creation, editing, viewing, and deletion. Foundation of the app."
        ),

        .collections: FeatureMetadata(
            feature: .collections,
            displayName: "Collections",
            description: "Recipe organization into collections and categories",
            state: .released,
            dependencies: [.recipeManagement],
            requiredServices: ["ModelContext", "LoggingService", "AnalyticsService"],
            testCoverage: 1.0,
            owner: "Core Team",
            introducedVersion: "1.0.0",
            deprecatedVersion: nil,
            removalVersion: nil,
            documentation: "Allows users to organize recipes into collections. Supports blind box collections and custom collections."
        ),

        .tags: FeatureMetadata(
            feature: .tags,
            displayName: "Tags",
            description: "Recipe tagging and filtering system",
            state: .released,
            dependencies: [.recipeManagement],
            requiredServices: ["ModelContext", "LoggingService"],
            testCoverage: 0.75,
            owner: "Core Team",
            introducedVersion: "1.0.0",
            deprecatedVersion: nil,
            removalVersion: nil,
            documentation: "Tag-based organization and filtering for recipes."
        ),

        .scaling: FeatureMetadata(
            feature: .scaling,
            displayName: "Recipe Scaling",
            description: "Scale recipe servings and adjust ingredient quantities",
            state: .released,
            dependencies: [.recipeManagement],
            requiredServices: ["LoggingService"],
            testCoverage: 0.70,
            owner: "Core Team",
            introducedVersion: "1.0.0",
            deprecatedVersion: nil,
            removalVersion: nil,
            documentation: "Automatically scales ingredient quantities based on desired serving size."
        ),

        // MARK: - Premium Features

        .premiumSubscription: FeatureMetadata(
            feature: .premiumSubscription,
            displayName: "Premium Subscription",
            description: "In-app purchase system with trial and paywalls",
            state: .released,
            dependencies: [],
            requiredServices: ["StoreManager", "SubscriptionManager", "PaywallManager", "LoggingService", "AnalyticsService"],
            testCoverage: 1.0,
            owner: "Core Team",
            introducedVersion: "1.0.0",
            deprecatedVersion: nil,
            removalVersion: nil,
            documentation: "Manages premium subscriptions, trials (14-day), paywall triggers (soft/hard walls), and purchase flow."
        ),

        .videoImport: FeatureMetadata(
            feature: .videoImport,
            displayName: "Video Recipe Import",
            description: "Import recipes from YouTube cooking videos",
            state: .released,
            dependencies: [.recipeManagement, .premiumSubscription],
            requiredServices: ["VideoRecipeProcessor", "WhisperKitTranscriber", "ClaudeRecipeStructurer", "LoggingService", "AnalyticsService"],
            testCoverage: 0.80,
            owner: "Video Team",
            introducedVersion: "1.5.0",
            deprecatedVersion: nil,
            removalVersion: nil,
            documentation: "Extracts recipes from YouTube videos using audio transcription (WhisperKit) and AI structuring (Claude). Premium feature."
        ),

        .asmrProcessing: FeatureMetadata(
            feature: .asmrProcessing,
            displayName: "ASMR Processing",
            description: "Extract recipes from cooking sounds using 5-pass AI analysis",
            state: .beta,
            dependencies: [.videoImport, .premiumSubscription],
            requiredServices: ["ASMRRecipeProcessor", "ASMRSoundAnalyzer", "ASMRCreditManager", "LoggingService", "AnalyticsService"],
            testCoverage: 0.75,
            owner: "Video Team",
            introducedVersion: "2.0.0",
            deprecatedVersion: nil,
            removalVersion: nil,
            documentation: "Premium feature that analyzes cooking sounds to extract recipes. Uses 5-pass extraction with credit system (5 credits per extraction)."
        ),

        .cloudSync: FeatureMetadata(
            feature: .cloudSync,
            displayName: "Cloud Sync",
            description: "Sync recipes across devices via iCloud",
            state: .released,
            dependencies: [.recipeManagement, .premiumSubscription],
            requiredServices: ["CloudKitService", "LoggingService", "AnalyticsService"],
            testCoverage: 0.65,
            owner: "Sync Team",
            introducedVersion: "1.2.0",
            deprecatedVersion: nil,
            removalVersion: nil,
            documentation: "Premium feature that syncs recipes, collections, and settings across user's devices via iCloud."
        ),

        .cookbookScan: FeatureMetadata(
            feature: .cookbookScan,
            displayName: "Cookbook Scan",
            description: "OCR scan of physical cookbooks to import recipes",
            state: .development,
            dependencies: [.recipeManagement, .premiumSubscription],
            requiredServices: ["VisionKitScanner", "ClaudeRecipeStructurer", "LoggingService", "AnalyticsService"],
            testCoverage: 0.0,
            owner: "Scan Team",
            introducedVersion: nil,
            deprecatedVersion: nil,
            removalVersion: nil,
            documentation: "Planned premium feature for OCR scanning of physical cookbook pages. Not yet implemented."
        ),

        // MARK: - Heritage Features

        .blindBoxCollections: FeatureMetadata(
            feature: .blindBoxCollections,
            displayName: "Blind Box Collections",
            description: "Mystery recipe collections revealed by users",
            state: .released,
            dependencies: [.collections, .recipeManagement],
            requiredServices: ["ModelContext", "LoggingService", "AnalyticsService"],
            testCoverage: 0.90,
            owner: "Heritage Team",
            introducedVersion: "1.0.0",
            deprecatedVersion: nil,
            removalVersion: nil,
            documentation: "6 curated collections (Literary Kitchen, Regional American, European Classics, Asian Traditions, Latin American, Middle Eastern) revealed by users."
        ),

        .dailyHeritageDrop: FeatureMetadata(
            feature: .dailyHeritageDrop,
            displayName: "Daily Theme Drop",
            description: "Daily unlocking of theme recipes during trial",
            state: .development, // TODO: Change to .released in Phase A3
            dependencies: [.premiumSubscription],
            requiredServices: ["ThemeUnlockTracker", "SubscriptionManager", "LoggingService", "AnalyticsService"],
            testCoverage: 0.0, // TODO: Update test coverage in Phase A3
            owner: "Theme Team",
            introducedVersion: "2.0.0",
            deprecatedVersion: nil,
            removalVersion: nil,
            documentation: "Daily unlocks of theme recipes during 14-day trial. Stops after trial expires. Themes are selected by user during onboarding."
        ),

        .heritageProvenance: FeatureMetadata(
            feature: .heritageProvenance,
            displayName: "Heritage Provenance",
            description: "Track recipe lineage and cultural origins",
            state: .released,
            dependencies: [.recipeManagement],
            requiredServices: ["ModelContext", "LoggingService"],
            testCoverage: 0.70,
            owner: "Heritage Team",
            introducedVersion: "1.0.0",
            deprecatedVersion: nil,
            removalVersion: nil,
            documentation: "Tracks recipe origins, attribution, and lineage through generations."
        ),

        // MARK: - Social Features

        .recipeSharing: FeatureMetadata(
            feature: .recipeSharing,
            displayName: "Recipe Sharing",
            description: "Share recipes via Firebase with deep links and QR codes",
            state: .released,
            dependencies: [.recipeManagement, .premiumSubscription],
            requiredServices: ["FirebaseShareService", "DeepLinkHandler", "LoggingService", "AnalyticsService"],
            testCoverage: 0.80,
            owner: "Social Team",
            introducedVersion: "1.3.0",
            deprecatedVersion: nil,
            removalVersion: nil,
            documentation: "Premium feature for sharing recipes via deep links, QR codes, and Firebase storage. Includes lineage tracking."
        ),

        .discovery: FeatureMetadata(
            feature: .discovery,
            displayName: "Recipe Discovery",
            description: "Discover and browse community recipes",
            state: .alpha,
            dependencies: [.recipeSharing],
            requiredServices: ["FirebaseShareService", "LoggingService", "AnalyticsService"],
            testCoverage: 0.30,
            owner: "Social Team",
            introducedVersion: nil,
            deprecatedVersion: nil,
            removalVersion: nil,
            documentation: "Browse community-shared recipes. Early alpha development."
        ),

        .dinnerParty: FeatureMetadata(
            feature: .dinnerParty,
            displayName: "Meal Planning",
            description: "Plan meals, invite guests, manage shopping lists",
            state: .development,
            dependencies: [.recipeManagement, .shoppingLists],
            requiredServices: ["ModelContext", "LoggingService", "AnalyticsService"],
            testCoverage: 0.0,
            owner: "Social Team",
            introducedVersion: nil,
            deprecatedVersion: nil,
            removalVersion: nil,
            documentation: "Planned feature for meal planning and guest management. Not yet implemented."
        ),

        // MARK: - Utility Features

        .shoppingLists: FeatureMetadata(
            feature: .shoppingLists,
            displayName: "Shopping Lists",
            description: "Generate shopping lists from recipes",
            state: .beta,
            dependencies: [.recipeManagement],
            requiredServices: ["ModelContext", "LoggingService"],
            testCoverage: 0.55,
            owner: "Utility Team",
            introducedVersion: "1.8.0",
            deprecatedVersion: nil,
            removalVersion: nil,
            documentation: "Generate and manage shopping lists from recipe ingredients."
        ),

        .stats: FeatureMetadata(
            feature: .stats,
            displayName: "Cooking Stats",
            description: "Track cooking frequency, favorite recipes, and trends",
            state: .development,
            dependencies: [.recipeManagement],
            requiredServices: ["AnalyticsService", "LoggingService"],
            testCoverage: 0.0,
            owner: "Analytics Team",
            introducedVersion: nil,
            deprecatedVersion: nil,
            removalVersion: nil,
            documentation: "Planned feature for tracking user cooking activity and insights."
        ),

        // MARK: - Developer Features

        .onboarding: FeatureMetadata(
            feature: .onboarding,
            displayName: "Onboarding",
            description: "First-time user experience and setup flow",
            state: .released,
            dependencies: [.blindBoxCollections],
            requiredServices: ["ModelContext", "LoggingService", "AnalyticsService"],
            testCoverage: 0.80,
            owner: "Core Team",
            introducedVersion: "1.0.0",
            deprecatedVersion: nil,
            removalVersion: nil,
            documentation: "4-screen onboarding flow (welcome, import methods, concept, features) that seeds blind boxes and onboarding recipe."
        ),

        .debugMenu: FeatureMetadata(
            feature: .debugMenu,
            displayName: "Debug Menu",
            description: "Developer testing tools and feature flags",
            state: .released,
            dependencies: [],
            requiredServices: ["FeatureFlagManager", "LoggingService"],
            testCoverage: 0.60,
            owner: "Core Team",
            introducedVersion: "1.0.0",
            deprecatedVersion: nil,
            removalVersion: nil,
            documentation: "Debug tools for developers including feature flag toggles, logging controls, and test data generation."
        )
    ]

    // MARK: - Public API

    /// Get metadata for a feature
    func metadata(for feature: Feature) -> FeatureMetadata? {
        return featureMetadata[feature]
    }

    /// Get all features in a given state
    func features(inState state: FeatureState) -> [Feature] {
        return featureMetadata
            .filter { $0.value.state == state }
            .map { $0.key }
            .sorted { $0.rawValue < $1.rawValue }
    }

    /// Get all features with test coverage below required threshold
    func featuresNeedingTests() -> [(Feature, required: Double, actual: Double)] {
        return featureMetadata
            .compactMap { feature, metadata in
                let required = metadata.state.requiresTestCoverage
                let actual = metadata.testCoverage
                if actual < required {
                    return (feature, required, actual)
                }
                return nil
            }
            .sorted { $0.required > $1.required }
    }

    /// Validate that all feature dependencies are satisfied
    func validateDependencies() -> [String] {
        var errors: [String] = []

        for (feature, metadata) in featureMetadata {
            for dependency in metadata.dependencies {
                // Check if dependency exists
                guard let dependencyMetadata = featureMetadata[dependency] else {
                    errors.append("Feature \(feature.rawValue) depends on unknown feature \(dependency.rawValue)")
                    continue
                }

                // Check if dependency is removed
                if dependencyMetadata.state == .removed {
                    errors.append("Feature \(feature.rawValue) depends on removed feature \(dependency.rawValue)")
                }
            }
        }

        return errors
    }

    /// Get all features depending on a given feature
    func dependents(of feature: Feature) -> [Feature] {
        return featureMetadata
            .filter { $0.value.dependencies.contains(feature) }
            .map { $0.key }
            .sorted { $0.rawValue < $1.rawValue }
    }

    /// Get overall test coverage across all released features
    func overallCoverage() -> Double {
        let releasedFeatures = featureMetadata.filter { $0.value.state == .released }
        guard !releasedFeatures.isEmpty else { return 0.0 }

        let totalCoverage = releasedFeatures.reduce(0.0) { $0 + $1.value.testCoverage }
        return totalCoverage / Double(releasedFeatures.count)
    }

    /// Get test coverage by category
    func coverageByCategory() -> [FeatureCategory: Double] {
        var categoryScores: [FeatureCategory: (total: Double, count: Int)] = [:]

        for (feature, metadata) in featureMetadata where metadata.state == .released {
            let category = feature.category
            let current = categoryScores[category, default: (0.0, 0)]
            categoryScores[category] = (current.total + metadata.testCoverage, current.count + 1)
        }

        return categoryScores.mapValues { $0.count > 0 ? $0.total / Double($0.count) : 0.0 }
    }
}
