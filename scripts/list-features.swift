#!/usr/bin/env swift
//
//  list-features.swift
//  Heirloom
//
//  List all features with their states and test coverage
//  Usage: swift list-features.swift [state]
//

import Foundation

// MARK: - Models

enum FeatureState: String, CaseIterable {
    case development = "Development"
    case alpha = "Alpha"
    case beta = "Beta"
    case released = "Released"
    case deprecated = "Deprecated"
    case removed = "Removed"
}

enum FeatureCategory: String {
    case core = "Core"
    case premium = "Premium"
    case heritage = "Heritage"
    case social = "Social"
    case utility = "Utility"
    case developer = "Developer"
}

struct Feature {
    let name: String
    let displayName: String
    let category: FeatureCategory
    let state: FeatureState
    let testCoverage: Double
    let requiresPremium: Bool
}

// MARK: - Feature Data

let features: [Feature] = [
    // Core
    Feature(name: "recipeManagement", displayName: "Recipe Management", category: .core, state: .released, testCoverage: 0.85, requiresPremium: false),
    Feature(name: "collections", displayName: "Collections", category: .core, state: .released, testCoverage: 1.0, requiresPremium: false),
    Feature(name: "tags", displayName: "Tags", category: .core, state: .released, testCoverage: 0.75, requiresPremium: false),
    Feature(name: "scaling", displayName: "Recipe Scaling", category: .core, state: .released, testCoverage: 0.70, requiresPremium: false),

    // Premium
    Feature(name: "premiumSubscription", displayName: "Premium Subscription", category: .premium, state: .released, testCoverage: 1.0, requiresPremium: false),
    Feature(name: "videoImport", displayName: "Video Import", category: .premium, state: .released, testCoverage: 0.80, requiresPremium: true),
    Feature(name: "asmrProcessing", displayName: "ASMR Processing", category: .premium, state: .beta, testCoverage: 0.75, requiresPremium: true),
    Feature(name: "cloudSync", displayName: "Cloud Sync", category: .premium, state: .released, testCoverage: 0.65, requiresPremium: true),
    Feature(name: "cookbookScan", displayName: "Cookbook Scan", category: .premium, state: .development, testCoverage: 0.0, requiresPremium: true),

    // Heritage
    Feature(name: "blindBoxCollections", displayName: "Blind Box Collections", category: .heritage, state: .released, testCoverage: 0.90, requiresPremium: false),
    Feature(name: "dailyHeritageDrop", displayName: "Daily Heritage Drop", category: .heritage, state: .released, testCoverage: 1.0, requiresPremium: false),
    Feature(name: "heritageProvenance", displayName: "Heritage Provenance", category: .heritage, state: .released, testCoverage: 0.70, requiresPremium: false),

    // Social
    Feature(name: "recipeSharing", displayName: "Recipe Sharing", category: .social, state: .released, testCoverage: 0.80, requiresPremium: true),
    Feature(name: "discovery", displayName: "Recipe Discovery", category: .social, state: .alpha, testCoverage: 0.30, requiresPremium: false),
    Feature(name: "dinnerParty", displayName: "Dinner Party", category: .social, state: .development, testCoverage: 0.0, requiresPremium: false),

    // Utility
    Feature(name: "shoppingLists", displayName: "Shopping Lists", category: .utility, state: .beta, testCoverage: 0.55, requiresPremium: false),
    Feature(name: "stats", displayName: "Cooking Stats", category: .utility, state: .development, testCoverage: 0.0, requiresPremium: false),

    // Developer
    Feature(name: "onboarding", displayName: "Onboarding", category: .developer, state: .released, testCoverage: 0.80, requiresPremium: false),
    Feature(name: "debugMenu", displayName: "Debug Menu", category: .developer, state: .released, testCoverage: 0.60, requiresPremium: false)
]

// MARK: - Main

func main() {
    // Filter by state if provided
    let filteredFeatures: [Feature]
    if CommandLine.arguments.count > 1,
       let stateFilter = FeatureState(rawValue: CommandLine.arguments[1]) {
        filteredFeatures = features.filter { $0.state == stateFilter }
        print("Features in state: \(stateFilter.rawValue)")
        print("")
    } else {
        filteredFeatures = features
    }

    // Group by category
    let categories = FeatureCategory.allCases

    for category in categories {
        let categoryFeatures = filteredFeatures.filter { $0.category == category }
        guard !categoryFeatures.isEmpty else { continue }

        printCategory(category.rawValue)

        for feature in categoryFeatures.sorted(by: { $0.displayName < $1.displayName }) {
            printFeature(feature)
        }

        print("")
    }

    // Summary
    printSummary(features: filteredFeatures)
}

// MARK: - Helpers

func printCategory(_ name: String) {
    print("──────────────────────────────────────────────")
    print(name)
    print("──────────────────────────────────────────────")
}

func printFeature(_ feature: Feature) {
    let stateIcon: String
    switch feature.state {
    case .development: stateIcon = "🔨"
    case .alpha: stateIcon = "🧪"
    case .beta: stateIcon = "🚧"
    case .released: stateIcon = "✅"
    case .deprecated: stateIcon = "⚠️"
    case .removed: stateIcon = "❌"
    }

    let premiumBadge = feature.requiresPremium ? " 💎" : ""
    let coveragePercent = Int(feature.testCoverage * 100)
    let coverageBar = progressBar(percent: feature.testCoverage, width: 10)

    print(String(format: "  %@ %-30s [%3d%% %s] %10s%s",
                 stateIcon,
                 feature.displayName,
                 coveragePercent,
                 coverageBar,
                 feature.state.rawValue,
                 premiumBadge))
}

func progressBar(percent: Double, width: Int) -> String {
    let filled = Int(percent * Double(width))
    let empty = width - filled
    return String(repeating: "█", count: filled) + String(repeating: "░", count: empty)
}

func printSummary(features: [Feature]) {
    print("──────────────────────────────────────────────")
    print("Summary")
    print("──────────────────────────────────────────────")

    let totalFeatures = features.count
    let byState = Dictionary(grouping: features, by: { $0.state })

    print("Total features: \(totalFeatures)")
    print("")

    print("By State:")
    for state in FeatureState.allCases {
        let count = byState[state]?.count ?? 0
        if count > 0 {
            print("  • \(state.rawValue): \(count)")
        }
    }

    print("")

    let avgCoverage = features.reduce(0.0) { $0 + $1.testCoverage } / Double(features.count)
    print("Average Coverage: \(Int(avgCoverage * 100))%")

    let premiumCount = features.filter { $0.requiresPremium }.count
    print("Premium Features: \(premiumCount)")
}

extension FeatureCategory: CaseIterable {
    static var allCases: [FeatureCategory] {
        return [.core, .premium, .heritage, .social, .utility, .developer]
    }
}

// Run main
main()
