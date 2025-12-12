import SwiftUI

/// Heirloom typography system
enum HeirloomFonts {
    // MARK: - Title Fonts (Serif)
    static func title(_ size: CGFloat = 24, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static let largeTitle = Font.system(size: 34, weight: .bold, design: .serif)
    static let title1 = Font.system(size: 28, weight: .semibold, design: .serif)
    static let title2 = Font.system(size: 22, weight: .semibold, design: .serif)
    static let title3 = Font.system(size: 20, weight: .medium, design: .serif)

    // MARK: - Body Fonts (Sans-serif)
    static let body = Font.system(size: 17, weight: .regular)
    static let bodyBold = Font.system(size: 17, weight: .semibold)
    static let callout = Font.system(size: 16, weight: .regular)
    static let subheadline = Font.system(size: 15, weight: .regular)
    static let footnote = Font.system(size: 13, weight: .regular)
    static let caption1 = Font.system(size: 12, weight: .regular)
    static let caption1Bold = Font.system(size: 12, weight: .semibold)
    static let caption2 = Font.system(size: 11, weight: .regular)
    static let caption2Bold = Font.system(size: 11, weight: .semibold)

    // MARK: - Special Fonts
    static func handwritten(_ size: CGFloat = 18) -> Font {
        // For Phase 2: Will use custom handwritten font
        // For now: Serif italic approximation
        .system(size: size, weight: .medium, design: .serif).italic()
    }

    static func typewriter(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
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
