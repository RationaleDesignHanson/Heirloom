import SwiftUI

/// Heirloom typography system
/// All fonts support Dynamic Type and scale with accessibility settings
///
/// # Dynamic Type Guidelines
///
/// ## Use Scalable Fonts For:
/// - All user-facing text content (titles, body text, labels)
/// - Button labels and interactive text
/// - Any text users need to read
///
/// ## Use Fixed Fonts For:
/// - Decorative SF Symbols/icons (e.g., `.font(.system(size: 24))` for icons)
/// - Small visual indicators (badges, dots)
/// - Elements where scaling would break layout (emoji displays)
///
/// ## Touch Targets:
/// - Interactive elements must have MINIMUM 44x44pt hit area
/// - SwiftUI buttons automatically expand hit areas to 44pt minimum
/// - Use `.frame(minWidth: 44, minHeight: 44)` for custom interactive elements
///
/// ## Testing:
/// - Test with Settings > Accessibility > Display & Text Size > Larger Text
/// - Enable "Larger Accessibility Sizes" and test at AX5 (largest)
/// - Verify text doesn't truncate and remains readable
enum HeirloomFonts {
    // MARK: - Title Fonts (Serif) - Dynamic Type Support
    /// Use this for custom title sizes that need to scale with Dynamic Type
    /// - Parameters:
    ///   - textStyle: The base text style for scaling reference
    ///   - weight: Font weight
    /// - Returns: A scalable serif font
    static func title(_ textStyle: Font.TextStyle = .title, weight: Font.Weight = .semibold) -> Font {
        .system(textStyle, design: .serif, weight: weight)
    }

    // Scalable title fonts that adapt to accessibility settings
    static let largeTitle = Font.system(.largeTitle, design: .serif, weight: .bold)
    static let title1 = Font.system(.title, design: .serif, weight: .semibold)
    static let title2 = Font.system(.title2, design: .serif, weight: .semibold)
    static let title3 = Font.system(.title3, design: .serif, weight: .medium)

    // MARK: - Body Fonts (Sans-serif) - Dynamic Type Support
    static let body = Font.system(.body, weight: .regular)
    static let bodyBold = Font.system(.body, weight: .semibold)
    static let callout = Font.system(.callout, weight: .regular)
    static let subheadline = Font.system(.subheadline, weight: .regular)
    static let footnote = Font.system(.footnote, weight: .regular)
    static let caption1 = Font.system(.caption, weight: .regular)
    static let caption1Bold = Font.system(.caption, weight: .semibold)
    static let caption2 = Font.system(.caption2, weight: .regular)
    static let caption2Bold = Font.system(.caption2, weight: .semibold)

    // MARK: - Special Fonts - Dynamic Type Support
    /// Handwritten-style font that scales with accessibility settings
    static func handwritten(_ textStyle: Font.TextStyle = .body) -> Font {
        // For Phase 2: Will use custom handwritten font
        // For now: Serif italic approximation that scales
        .system(textStyle, design: .serif, weight: .medium).italic()
    }

    /// Typewriter/monospaced font that scales with accessibility settings
    static func typewriter(_ textStyle: Font.TextStyle = .body) -> Font {
        .system(textStyle, design: .monospaced, weight: .regular)
    }

    // MARK: - Fixed Size Fonts (Use Sparingly)
    /// Fixed-size fonts for decorative elements that should NOT scale
    /// Only use when Dynamic Type scaling would break the design (e.g., icons, badges)
    enum Fixed {
        static func decorative(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight)
        }

        static func icon(_ size: CGFloat) -> Font {
            .system(size: size)
        }
    }
}

// MARK: - Scaled Metric Helper
/// Helper for creating scalable custom sizes
/// Usage: @ScaledMetric(relativeTo: .body) var fontSize: CGFloat = 18
/// Then use: .font(.system(size: fontSize))
struct ScalableFont {
    let baseSize: CGFloat
    let textStyle: Font.TextStyle

    func font(weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: baseSize, weight: weight, design: design)
    }
}

// MARK: - Spacing System
enum HeirloomSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    static let cardPadding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 16
    static let gridSpacing: CGFloat = 16
}

// MARK: - Shadows
enum HeirloomShadows {
    static let card = (
        color: HeirloomColors.cardShadow,
        radius: CGFloat(8),
        x: CGFloat(0),
        y: CGFloat(4)
    )

    static let elevated = (
        color: Color.black.opacity(0.12),
        radius: CGFloat(16),
        x: CGFloat(0),
        y: CGFloat(8)
    )

    static let subtle = (
        color: Color.black.opacity(0.04),
        radius: CGFloat(4),
        x: CGFloat(0),
        y: CGFloat(2)
    )
}
