//
//  OnboardingDataSelector.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-10.
//

import Foundation
import SwiftData
import SwiftUI

/// Helper class for selecting collections and recipes to display in onboarding
/// Ensures Literary Kitchen is always shown plus one random other collection
@MainActor
class OnboardingDataSelector {

    // MARK: - Collection Selection

    /// Selects collections for onboarding preview
    /// - Parameter collections: All available heritage collections
    /// - Returns: Tuple of (Literary Kitchen, random other collection)
    static func selectCollectionsForPreview(
        from collections: [RecipeCollection]
    ) -> (primary: RecipeCollection?, secondary: RecipeCollection?) {
        // Find Literary Kitchen (always primary)
        let literaryKitchen = collections.first { $0.sourceTheme?.firebaseId == "literary-kitchen" }

        // Get other collections (excluding Literary Kitchen)
        let otherCollections = collections.filter { $0.sourceTheme?.firebaseId != "literary-kitchen" }

        // Select random other collection
        let randomOther = otherCollections.randomElement()

        return (primary: literaryKitchen, secondary: randomOther)
    }

    // MARK: - Recipe Selection

    /// Selects recipes for onboarding preview
    /// - Parameters:
    ///   - recipes: All available heritage recipes
    ///   - primaryCollection: Primary collection (Literary Kitchen)
    ///   - secondaryCollection: Secondary random collection
    /// - Returns: Array of 2 recipes (1 from each collection)
    static func selectRecipesForPreview(
        from recipes: [Recipe],
        primaryCollection: RecipeCollection?,
        secondaryCollection: RecipeCollection?
    ) -> [Recipe] {
        var selectedRecipes: [Recipe] = []

        // Select 1 recipe from primary collection (Literary Kitchen)
        if let primaryCollection = primaryCollection {
            let primaryRecipes = recipes.filter { recipe in
                recipe.sourceThemeId == primaryCollection.sourceTheme?.firebaseId
            }
            if let randomPrimary = primaryRecipes.randomElement() {
                selectedRecipes.append(randomPrimary)
            }
        }

        // Select 1 recipe from secondary collection
        if let secondaryCollection = secondaryCollection {
            let secondaryRecipes = recipes.filter { recipe in
                recipe.sourceThemeId == secondaryCollection.sourceTheme?.firebaseId
            }
            if let randomSecondary = secondaryRecipes.randomElement() {
                selectedRecipes.append(randomSecondary)
            }
        }

        return selectedRecipes
    }

    // MARK: - Validation

    /// Checks if there are sufficient heritage collections and recipes for onboarding
    /// - Parameters:
    ///   - collections: Available heritage collections
    ///   - recipes: Available heritage recipes
    /// - Returns: True if onboarding can be shown with preview content
    static func canShowOnboardingPreview(
        collections: [RecipeCollection],
        recipes: [Recipe]
    ) -> Bool {
        // Need at least 2 collections (Literary + 1 other)
        guard collections.count >= 2 else { return false }

        // Need Literary Kitchen to be present
        guard collections.contains(where: { $0.sourceTheme?.firebaseId == "literary-kitchen" }) else {
            return false
        }

        // Need at least 2 recipes (1 from each collection)
        guard recipes.count >= 2 else { return false }

        return true
    }
}
