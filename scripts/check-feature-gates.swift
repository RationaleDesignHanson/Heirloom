#!/usr/bin/env swift
//
//  check-feature-gates.swift
//  Heirloom
//
//  Validate feature lifecycle gates (test coverage requirements)
//  Usage: swift check-feature-gates.swift
//

import Foundation

// MARK: - Models

enum FeatureState: String {
    case development = "Development"
    case alpha = "Alpha"
    case beta = "Beta"
    case released = "Released"
    case deprecated = "Deprecated"
    case removed = "Removed"

    var requiresTestCoverage: Double {
        switch self {
        case .development: return 0.0
        case .alpha: return 0.4  // 40%
        case .beta: return 0.6   // 60%
        case .released: return 0.8  // 80%
        case .deprecated: return 0.8
        case .removed: return 0.0
        }
    }
}

struct Feature {
    let name: String
    let state: FeatureState
    let testCoverage: Double
}

// MARK: - Feature Data (matches FeatureRegistryData.swift)

let features: [Feature] = [
    // Core
    Feature(name: "recipeManagement", state: .released, testCoverage: 0.85),
    Feature(name: "collections", state: .released, testCoverage: 1.0),
    Feature(name: "tags", state: .released, testCoverage: 0.75),
    Feature(name: "scaling", state: .released, testCoverage: 0.70),

    // Premium
    Feature(name: "premiumSubscription", state: .released, testCoverage: 1.0),
    Feature(name: "videoImport", state: .released, testCoverage: 0.80),
    Feature(name: "asmrProcessing", state: .beta, testCoverage: 0.75),
    Feature(name: "cloudSync", state: .released, testCoverage: 0.65),
    Feature(name: "cookbookScan", state: .development, testCoverage: 0.0),

    // Heritage
    Feature(name: "blindBoxCollections", state: .released, testCoverage: 0.90),
    Feature(name: "dailyHeritageDrop", state: .released, testCoverage: 1.0),
    Feature(name: "heritageProvenance", state: .released, testCoverage: 0.70),

    // Social
    Feature(name: "recipeSharing", state: .released, testCoverage: 0.80),
    Feature(name: "discovery", state: .alpha, testCoverage: 0.30),
    Feature(name: "dinnerParty", state: .development, testCoverage: 0.0),

    // Utility
    Feature(name: "shoppingLists", state: .beta, testCoverage: 0.55),
    Feature(name: "stats", state: .development, testCoverage: 0.0),

    // Developer
    Feature(name: "onboarding", state: .released, testCoverage: 0.80),
    Feature(name: "debugMenu", state: .released, testCoverage: 0.60)
]

// MARK: - Main

func main() {
    printSection("Feature Lifecycle Gate Validation")

    var violations: [(Feature, required: Double)] = []

    // Check each feature
    for feature in features {
        let required = feature.state.requiresTestCoverage
        let actual = feature.testCoverage

        let status: String
        if actual >= required {
            status = "✅ PASS"
        } else if feature.state == .development {
            status = "⚠️  DEV"
        } else {
            status = "❌ FAIL"
            violations.append((feature, required))
        }

        let actualPercent = Int(actual * 100)
        let requiredPercent = Int(required * 100)

        print(String(format: "%-25s [%10s] %3d%% (req: %3d%%) %s",
                     feature.name,
                     feature.state.rawValue,
                     actualPercent,
                     requiredPercent,
                     status))
    }

    // Print violations
    if !violations.isEmpty {
        printSection("Violations")
        printError("The following features violate lifecycle gates:")
        print("")

        for (feature, required) in violations {
            let gap = (required - feature.testCoverage) * 100
            printError(String(format: "  • %-25s needs +%.0f%% coverage (%@ requires %.0f%%)",
                              feature.name,
                              gap,
                              feature.state.rawValue,
                              required * 100))
        }

        print("")
        printError("❌ Gate validation FAILED")
        printError("Add tests to meet lifecycle requirements")
        exit(1)
    } else {
        printSection("Summary")
        printSuccess("✅ All feature gates satisfied!")
        printSuccess("All features meet their lifecycle coverage requirements")
        exit(0)
    }
}

// MARK: - Helpers

func printSection(_ title: String) {
    print("\n" + "=".repeating(count: 80))
    print(title)
    print("=".repeating(count: 80))
}

func printSuccess(_ message: String) {
    print("\u{001B}[0;32m\(message)\u{001B}[0;0m") // Green
}

func printError(_ message: String) {
    print("\u{001B}[0;31m\(message)\u{001B}[0;0m") // Red
}

func printWarning(_ message: String) {
    print("\u{001B}[0;33m\(message)\u{001B}[0;0m") // Yellow
}

extension String {
    func repeating(count: Int) -> String {
        return String(repeating: self, count: count)
    }
}

// Run main
main()
