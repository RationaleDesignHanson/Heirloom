//
//  HeritageTestFixtures.swift
//  HeirloomTestsV2
//
//  Test fixtures for heritage recipes and blind box collections
//  Created: 2026-01-13
//

import Foundation
@testable import Heirloom

/// Fixtures for testing heritage recipe unlocking and blind boxes
enum HeritageTestFixtures {

    // MARK: - Collection IDs

    /// Standard heritage collection IDs used in the app
    enum CollectionID {
        static let literaryKitchen = "literary_kitchen"
        static let regional001 = "regional_001"
        static let regional002 = "regional_002"
        static let regional003 = "regional_003"
        static let regional004 = "regional_004"

        static let all = [
            literaryKitchen,
            regional001,
            regional002,
            regional003,
            regional004
        ]
    }

    // MARK: - Collection Metadata

    struct CollectionMetadata {
        let id: String
        let title: String
        let description: String
        let recipeCount: Int
    }

    /// Sample collection metadata
    static let collectionMetadata: [CollectionMetadata] = [
        CollectionMetadata(
            id: CollectionID.literaryKitchen,
            title: "Literary Kitchen",
            description: "Recipes inspired by classic literature",
            recipeCount: 50
        ),
        CollectionMetadata(
            id: CollectionID.regional001,
            title: "New England Classics",
            description: "Traditional recipes from New England",
            recipeCount: 12
        ),
        CollectionMetadata(
            id: CollectionID.regional002,
            title: "Southern Comfort",
            description: "Soul food and Southern classics",
            recipeCount: 13
        ),
        CollectionMetadata(
            id: CollectionID.regional003,
            title: "Pacific Northwest",
            description: "Fresh ingredients from the Pacific coast",
            recipeCount: 12
        ),
        CollectionMetadata(
            id: CollectionID.regional004,
            title: "Southwest Flavors",
            description: "Spicy and vibrant Southwestern cuisine",
            recipeCount: 13
        )
    ]

    // MARK: - Sample Heritage Recipe Titles

    /// Sample Literary Kitchen recipe titles
    static let literaryKitchenTitles = [
        "Pride and Prejudice Lemon Cake",
        "Great Gatsby's Mint Julep",
        "Moby Dick's Clam Chowder",
        "Oliver Twist's Gruel (Improved)",
        "Alice's Wonderland Tea Sandwiches",
        "Sherlock's Baker Street Scones",
        "Hobbit's Second Breakfast",
        "Narnia's Turkish Delight",
        "Tom Sawyer's Whitewash Cookies",
        "Little Women's Apple Dumplings"
    ]

    /// Sample Regional recipe titles
    static let regionalTitles = [
        "Boston Cream Pie",
        "Clam Bake",
        "Fried Chicken and Waffles",
        "Shrimp and Grits",
        "Salmon with Berry Glaze",
        "Dungeness Crab Cakes",
        "Green Chile Stew",
        "Carne Adovada",
        "Cornbread",
        "Sweet Tea"
    ]

    // MARK: - Recipe ID Patterns

    /// Generate consistent recipe IDs for testing
    /// Format: "{collectionId}_recipe_{index}"
    static func recipeID(collection: String, index: Int) -> String {
        return "\(collection)_recipe_\(String(format: "%03d", index))"
    }

    /// Generate set of recipe IDs for a collection
    static func recipeIDs(collection: String, count: Int) -> Set<String> {
        return Set((0..<count).map { recipeID(collection: collection, index: $0) })
    }

    /// Generate recipe IDs with 70% Literary Kitchen, 30% Regional split
    static func balancedRecipeIDs(totalCount: Int) -> Set<String> {
        let literaryCount = Int(Double(totalCount) * 0.7)
        let regionalCount = totalCount - literaryCount

        var ids = Set<String>()

        // Add Literary Kitchen recipes
        ids.formUnion(recipeIDs(collection: CollectionID.literaryKitchen, count: literaryCount))

        // Add Regional recipes (distributed across collections)
        let perRegional = regionalCount / 4
        ids.formUnion(recipeIDs(collection: CollectionID.regional001, count: perRegional))
        ids.formUnion(recipeIDs(collection: CollectionID.regional002, count: perRegional))
        ids.formUnion(recipeIDs(collection: CollectionID.regional003, count: perRegional))
        ids.formUnion(recipeIDs(collection: CollectionID.regional004, count: regionalCount - (perRegional * 3)))

        return ids
    }

    // MARK: - Unlock Scenarios

    /// Predefined unlock scenarios for testing
    enum UnlockScenario {
        case day1Complete    // 7 recipes (5 Literary, 2 Regional)
        case day7Complete    // 49 recipes (34 Literary, 15 Regional)
        case day14Complete   // 98 recipes (69 Literary, 29 Regional)
        case quotaMet        // 100 recipes (70 Literary, 30 Regional)

        var recipeCount: Int {
            switch self {
            case .day1Complete: return 7
            case .day7Complete: return 49
            case .day14Complete: return 98
            case .quotaMet: return 100
            }
        }

        var recipeIDs: Set<String> {
            return HeritageTestFixtures.balancedRecipeIDs(totalCount: recipeCount)
        }
    }

    // MARK: - Test Data Validation

    /// Validate that a set of recipe IDs matches the expected distribution
    static func validateDistribution(_ ids: Set<String>) -> (literary: Int, regional: Int, isValid: Bool) {
        let literaryCount = ids.filter { $0.hasPrefix(CollectionID.literaryKitchen) }.count
        let regionalCount = ids.count - literaryCount

        let expectedLiterary = Int(Double(ids.count) * 0.7)
        let tolerance = 2 // Allow ±2 recipes

        let isValid = abs(literaryCount - expectedLiterary) <= tolerance

        return (literaryCount, regionalCount, isValid)
    }
}

// MARK: - Collection Fixtures

extension HeritageTestFixtures {

    /// Generate a full set of blind box collection data
    static func generateBlindBoxData() -> [(id: String, title: String, description: String)] {
        return collectionMetadata.map { metadata in
            (id: metadata.id, title: metadata.title, description: metadata.description)
        }
    }

    /// Get total recipe count across all heritage collections
    static var totalHeritageRecipeCount: Int {
        return collectionMetadata.reduce(0) { $0 + $1.recipeCount }
    }
}
