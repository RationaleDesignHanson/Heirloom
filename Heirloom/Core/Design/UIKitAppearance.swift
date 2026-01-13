import UIKit
import SwiftUI

/// Global UIKit appearance configuration for Heirloom
/// Ensures UIKit components (navigation bars, tab bars) respect forced light mode
enum UIKitAppearance {

    /// Configure all UIKit appearances - call once at app launch
    static func configure() {
        configureNavigationBar()
        configureTabBar()
    }

    // MARK: - Navigation Bar

    private static func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()

        // Start with default opaque background
        appearance.configureWithOpaqueBackground()

        // Light mode colors - cream background with dark charcoal text for maximum contrast
        appearance.backgroundColor = UIColor(HeirloomColors.cream)
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.1)

        // Title attributes with explicit colors
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(HeirloomColors.charcoal),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]

        // Large title attributes with explicit colors
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(HeirloomColors.charcoal),
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        // Button colors (back button, toolbar items)
        appearance.buttonAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(HeirloomColors.familyGreen)
        ]
        appearance.doneButtonAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(HeirloomColors.familyGreen)
        ]

        // Configure the global navigation bar appearance
        let navBar = UINavigationBar.appearance()

        // Tint color for SF Symbols and back button chevron
        navBar.tintColor = UIColor(HeirloomColors.familyGreen)

        // Apply appearance to ALL navigation bar states
        navBar.standardAppearance = appearance
        navBar.compactAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        if #available(iOS 15.0, *) {
            navBar.compactScrollEdgeAppearance = appearance
        }

        // Ensure navigation bar is visible and not translucent
        navBar.isTranslucent = false
        navBar.barTintColor = UIColor(HeirloomColors.cream)

        // Force light user interface style
        navBar.overrideUserInterfaceStyle = .light
    }

    // MARK: - Tab Bar

    private static func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()

        // Light mode colors - cream background
        appearance.backgroundColor = UIColor(HeirloomColors.cream)

        // Selected tab color (familyGreen accent)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(HeirloomColors.familyGreen)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(HeirloomColors.familyGreen)
        ]

        // Unselected tab color (warmGray)
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(HeirloomColors.warmGray)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(HeirloomColors.warmGray)
        ]

        // Apply to all tab bars
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // Force light user interface style
        UITabBar.appearance().overrideUserInterfaceStyle = .light
    }
}
