//
//  UXCopy.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import Foundation

/// Centralized UX copy for consistency
enum UXCopy {

    // MARK: - Theme Selection

    enum ThemeSelection {
        static let title = "What sounds delicious?"
        static let subtitle = "Pick 2-5 themes. We'll unlock recipes from your selections over the next 14 days."
        static let minSelectionsHint = "Select at least %d more theme%@"
        static let maxSelectionsHint = "Maximum themes selected"
        static let continueButton = "Continue"
    }

    // MARK: - Collections

    enum Collections {
        static let discoverySectionTitle = "Your Discoveries"
        static let collectionsSectionTitle = "Your Collections"
        static let emptyTitle = "No Collections Yet"
        static let emptySubtitle = "Import recipes, have friends share with you, or create your own collections."
    }

    // MARK: - Unlock Progress

    enum Unlock {
        static func dayProgress(_ current: Int) -> String {
            "Day \(current) of 14"
        }

        static func recipesUnlocked(_ unlocked: Int, _ total: Int) -> String {
            if unlocked < total {
                return "\(unlocked) of \(total) recipes unlocked"
            }
            return "All \(total) recipes unlocked"
        }

        static let complete = "Complete"
        static let newBadge = "New!"
    }

    // MARK: - Nudges

    enum Nudges {
        static let addYourOwn = "Make it yours"
        static let addRecipeTitle = "Add Your Own Recipes"

        static func addRecipeSubtitle(themeName: String) -> String {
            "Do you have your own \(themeName.lowercased()) recipes? Add them here to keep everything together."
        }
    }

    // MARK: - Celebration

    enum Celebration {
        static let title = "New Recipes Unlocked!"
        static let viewButton = "View Recipes"
        static let laterButton = "Later"

        static func description(count: Int, themeNames: [String]) -> String {
            let recipeWord = count == 1 ? "recipe" : "recipes"
            let verb = count == 1 ? "is" : "are"

            if themeNames.count == 1 {
                return "\(count) new \(recipeWord) from \(themeNames[0]) \(verb) ready to explore."
            } else {
                let names = themeNames.prefix(2).joined(separator: " and ")
                let suffix = themeNames.count > 2 ? " and more" : ""
                return "\(count) new \(recipeWord) from \(names)\(suffix) \(verb) ready to explore."
            }
        }
    }
}
