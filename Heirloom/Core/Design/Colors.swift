import SwiftUI

/// Heirloom color palette - warm, nostalgic, personal
enum HeirloomColors {
    // MARK: - Primary Palette
    static let cream = Color(hex: "FDF6E3")
    static let amber = Color(hex: "D4A574")
    static let tomato = Color(hex: "E54B4B")
    static let charcoal = Color(hex: "3D3D3D")
    static let warmGray = Color(hex: "6B6B6B")
    static let familyGreen = Color(hex: "2D5A27")

    // MARK: - Semantic Colors
    static let cardBackground = cream
    static let primaryText = charcoal
    static let secondaryText = warmGray
    static let accent = tomato
    static let success = Color(hex: "4A9B4A")
    static let warning = Color(hex: "E5A54B")
    static let error = tomato

    // MARK: - Effects
    static let cardShadow = Color.black.opacity(0.08)
    static let coffeeStain = Color(hex: "8B7355")
    static let flourDust = Color.white.opacity(0.6)

    // MARK: - Background Gradients
    static let appBackground = LinearGradient(
        colors: [cream, Color.white],
        startPoint: .top,
        endPoint: .bottom
    )
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
}
