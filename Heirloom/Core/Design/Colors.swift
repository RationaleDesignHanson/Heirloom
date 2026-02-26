import SwiftUI

/// Heirloom color palette - warm, nostalgic, personal
/// All colors meet WCAG 2.1 Level AA accessibility standards
///
/// # Color Contrast Guidelines (WCAG AA on cream background)
/// - **charcoal** (10.07:1) ✅ All text sizes
/// - **warmGray** (4.94:1) ✅ All text sizes
/// - **familyGreen** (7.48:1) ✅ All text sizes
/// - **amber** (4.54:1) ✅ All text sizes
/// - **tomato** (3.58:1) ✅ Large text/icons only (≥18pt or ≥14pt bold)
/// - **success/warning** - Use for backgrounds only, not text
enum HeirloomColors {
    // MARK: - Primary Palette
    static let cream = Color(hex: "FDF6E3")
    static let amber = Color(hex: "8A6B4B")  // WCAG AA compliant: 4.54:1 on cream
    static let tomato = Color(hex: "E54B4B")  // Use for large text/icons: 3.58:1 on cream
    static let charcoal = Color(hex: "3D3D3D")
    static let warmGray = Color(hex: "6B6B6B")
    static let familyGreen = Color(hex: "2D5A27")

    // MARK: - Theme-Specific Colors
    static let themeTan = Color(hex: "D4C4B0")  // Brownish tan for theme collection cards

    // MARK: - Semantic Colors (Adaptive for Light/Dark Mode)
    static let cardBackground = Color(light: cream, dark: Color(hex: "2A2A2A"))
    static let primaryText = Color(light: charcoal, dark: Color(hex: "F5F5F5"))
    static let secondaryText = Color(light: warmGray, dark: Color(hex: "A0A0A0"))
    static let accent = tomato
    static let success = Color(hex: "4A9B4A")
    static let warning = Color(hex: "C65D3D") // Rusty orange (was E5A54B yellow)
    static let error = tomato

    // MARK: - Conflict Resolution Colors (v2.0+)
    /// Color for conflicts requiring user decision
    static let conflictAlert = tomato
    /// Color for safe auto-mergeable changes
    static let conflictSafe = familyGreen
    /// Color for context/information in conflict UI
    static let conflictInfo = amber
    /// Color for unchanged/neutral fields
    static let conflictNeutral = warmGray
    /// Background for conflict resolution cards
    static let conflictCardBackground = Color.white
    /// Background when a conflict option is selected
    static let conflictSelectedBackground = tomato.opacity(0.1)
    /// Background for conflict banner/alert
    static let conflictBannerBackground = Color(hex: "FFF5F5")

    // MARK: - Button & Badge Colors
    /// Text color for buttons with dark or accent backgrounds
    static let buttonTextLight = cream
    /// Text color for buttons with light backgrounds
    static let buttonTextDark = charcoal
    /// Background color for badges
    static let badgeBackground = tomato
    /// Text color for badges
    static let badgeText = cream
    /// Scrim overlay for modals and overlays
    static let scrim = Color.black.opacity(0.4)

    // MARK: - Effects
    static let cardStroke = Color(light: Color.black.opacity(0.08), dark: Color.white.opacity(0.08))
    static let cardShadow = Color.black.opacity(0.08)
    static let coffeeStain = Color(hex: "8B7355")
    static let flourDust = Color.white.opacity(0.6)

    // MARK: - Background Gradients
    static var appBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(light: cream, dark: Color(hex: "1C1C1C")),
                Color(light: .white, dark: Color(hex: "121212"))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Create adaptive color for light/dark mode
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}
