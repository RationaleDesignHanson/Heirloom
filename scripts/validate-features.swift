#!/usr/bin/env swift
//
//  validate-features.swift
//  Heirloom
//
//  Validate feature dependencies and consistency
//  Usage: swift validate-features.swift
//

import Foundation

// MARK: - Models

struct Feature {
    let name: String
    let dependencies: [String]
    let state: String
}

// MARK: - Feature Dependency Data

let features: [Feature] = [
    // Core
    Feature(name: "recipeManagement", dependencies: [], state: "Released"),
    Feature(name: "collections", dependencies: ["recipeManagement"], state: "Released"),
    Feature(name: "tags", dependencies: ["recipeManagement"], state: "Released"),
    Feature(name: "scaling", dependencies: ["recipeManagement"], state: "Released"),

    // Premium
    Feature(name: "premiumSubscription", dependencies: [], state: "Released"),
    Feature(name: "videoImport", dependencies: ["recipeManagement", "premiumSubscription"], state: "Released"),
    Feature(name: "asmrProcessing", dependencies: ["videoImport", "premiumSubscription"], state: "Beta"),
    Feature(name: "cloudSync", dependencies: ["recipeManagement"], state: "Released"),
    Feature(name: "cookbookScan", dependencies: ["recipeManagement", "premiumSubscription"], state: "Development"),

    // Heritage
    Feature(name: "blindBoxCollections", dependencies: ["collections", "recipeManagement"], state: "Released"),
    Feature(name: "dailyHeritageDrop", dependencies: ["blindBoxCollections", "premiumSubscription"], state: "Released"),
    Feature(name: "heritageProvenance", dependencies: ["recipeManagement"], state: "Released"),

    // Social
    Feature(name: "recipeSharing", dependencies: ["recipeManagement", "premiumSubscription"], state: "Released"),
    Feature(name: "discovery", dependencies: ["recipeSharing"], state: "Alpha"),
    Feature(name: "dinnerParty", dependencies: ["recipeManagement", "shoppingLists"], state: "Development"),

    // Utility
    Feature(name: "shoppingLists", dependencies: ["recipeManagement"], state: "Beta"),
    Feature(name: "stats", dependencies: ["recipeManagement"], state: "Development"),

    // Developer
    Feature(name: "onboarding", dependencies: ["blindBoxCollections"], state: "Released"),
    Feature(name: "debugMenu", dependencies: [], state: "Released")
]

// MARK: - Main

func main() {
    printSection("Feature Dependency Validation")

    var hasErrors = false
    var errors: [String] = []

    // Build feature map
    var featureMap: [String: Feature] = [:]
    for feature in features {
        featureMap[feature.name] = feature
    }

    // Validate each feature
    for feature in features {
        // Check if all dependencies exist
        for dependency in feature.dependencies {
            guard let dependencyFeature = featureMap[dependency] else {
                errors.append("❌ \(feature.name) depends on unknown feature: \(dependency)")
                hasErrors = true
                continue
            }

            // Check if depending on removed feature
            if dependencyFeature.state == "Removed" {
                errors.append("❌ \(feature.name) depends on removed feature: \(dependency)")
                hasErrors = true
            }
        }
    }

    // Check for circular dependencies
    let circularDeps = findCircularDependencies(features: features, featureMap: featureMap)
    if !circularDeps.isEmpty {
        for cycle in circularDeps {
            errors.append("❌ Circular dependency detected: \(cycle.joined(separator: " → "))")
            hasErrors = true
        }
    }

    // Print results
    if hasErrors {
        print("")
        for error in errors {
            printError(error)
        }
        print("")
        printError("❌ Validation FAILED")
        exit(1)
    } else {
        print("")
        printSuccess("✅ All dependencies valid!")
        printSuccess("No circular dependencies detected")
        printSuccess("No missing or removed dependencies")
        exit(0)
    }
}

// MARK: - Helpers

func findCircularDependencies(features: [Feature], featureMap: [String: Feature]) -> [[String]] {
    var cycles: [[String]] = []
    var visiting: Set<String> = []
    var visited: Set<String> = []

    func dfs(_ name: String, path: [String]) {
        if visiting.contains(name) {
            // Found cycle
            if let cycleStart = path.firstIndex(of: name) {
                cycles.append(Array(path[cycleStart...]) + [name])
            }
            return
        }

        if visited.contains(name) {
            return
        }

        visiting.insert(name)

        if let feature = featureMap[name] {
            for dependency in feature.dependencies {
                dfs(dependency, path: path + [name])
            }
        }

        visiting.remove(name)
        visited.insert(name)
    }

    for feature in features {
        dfs(feature.name, path: [])
    }

    return cycles
}

func printSection(_ title: String) {
    print("=".repeating(count: 60))
    print(title)
    print("=".repeating(count: 60))
}

func printSuccess(_ message: String) {
    print("\u{001B}[0;32m\(message)\u{001B}[0;0m") // Green
}

func printError(_ message: String) {
    print("\u{001B}[0;31m\(message)\u{001B}[0;0m") // Red
}

extension String {
    func repeating(count: Int) -> String {
        return String(repeating: self, count: count)
    }
}

// Run main
main()
