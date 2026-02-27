import SnapshotTesting
import SwiftUI
import SwiftData
import XCTest
@testable import Heirloom

@MainActor
final class ThemeSelectionSnapshotTests: SnapshotTestCase {

    // MARK: - Empty State (loading)

    func testThemeSelection_empty() {
        let view = ThemeSelectionScreen(onComplete: { _ in })

        assertBothDevices(view, named: "themeSelection_empty")
    }

    // MARK: - With Themes

    func testThemeSelection_withThemes() throws {
        // ThemeCategory cases: .cuisine, .era, .source, .media, .difficulty
        _ = createTestTheme(
            firebaseId: "italian-1", name: "Italian Nonna",
            tagline: "Recipes from the Italian countryside",
            category: .cuisine, sortOrder: 0
        )
        _ = createTestTheme(
            firebaseId: "japanese-1", name: "Japanese Home Cooking",
            tagline: "Everyday comfort from Japanese kitchens",
            category: .cuisine, sortOrder: 1
        )
        _ = createTestTheme(
            firebaseId: "grandma-1", name: "Grandma's Kitchen",
            tagline: "Classic recipes from the 1950s",
            category: .era, sortOrder: 2
        )
        _ = createTestTheme(
            firebaseId: "cookbooks-1", name: "Classic Cookbooks",
            tagline: "Recipes from famous cookbooks",
            category: .source, sortOrder: 3
        )
        _ = createTestTheme(
            firebaseId: "tv-1", name: "TV Chefs",
            tagline: "Iconic recipes from television",
            category: .media, sortOrder: 4
        )
        _ = createTestTheme(
            firebaseId: "beginner-1", name: "Beginner Friendly",
            tagline: "Simple recipes for new cooks",
            category: .difficulty, sortOrder: 5
        )
        try saveContext()

        let view = ThemeSelectionScreen(onComplete: { _ in })

        assertBothDevices(view, named: "themeSelection_populated")
    }
}
