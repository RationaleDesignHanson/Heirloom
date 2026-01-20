import SwiftUI

/// Reusable card component with consistent styling across the app
/// Provides standard padding, corner radius, background, and shadow
struct HeirloomCard<Content: View>: View {
    let showBorder: Bool
    let padding: CGFloat
    let shadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)
    @ViewBuilder let content: () -> Content

    init(
        showBorder: Bool = false,
        padding: CGFloat = HeirloomSpacing.cardPadding,
        shadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = HeirloomShadows.card,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.showBorder = showBorder
        self.padding = padding
        self.shadow = shadow
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                    .fill(HeirloomColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                    .stroke(HeirloomColors.warmGray.opacity(0.2), lineWidth: showBorder ? 1 : 0)
            )
            .heirloomShadow(shadow)
    }
}

// MARK: - Convenience Initializers

extension HeirloomCard {
    /// Card with subtle shadow (for nested or secondary cards)
    init(
        subtle: Bool,
        showBorder: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) where Content: View {
        self.init(
            showBorder: showBorder,
            padding: HeirloomSpacing.cardPadding,
            shadow: HeirloomShadows.subtle,
            content: content
        )
    }

    /// Card with elevated shadow (for important or interactive cards)
    init(
        elevated: Bool,
        showBorder: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) where Content: View {
        self.init(
            showBorder: showBorder,
            padding: HeirloomSpacing.cardPadding,
            shadow: HeirloomShadows.elevated,
            content: content
        )
    }

    /// Compact card with reduced padding
    init(
        compact: Bool,
        showBorder: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) where Content: View {
        self.init(
            showBorder: showBorder,
            padding: HeirloomSpacing.md,
            shadow: HeirloomShadows.card,
            content: content
        )
    }
}

// MARK: - Preview

#Preview("Standard Card") {
    VStack(spacing: HeirloomSpacing.lg) {
        HeirloomCard {
            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                Text("Standard Card")
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("This is a standard card with default padding and shadow.")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }

        HeirloomCard(showBorder: true) {
            Text("Card with Border")
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
        }

        HeirloomCard(subtle: true) {
            Text("Subtle Shadow Card")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)
        }

        HeirloomCard(elevated: true) {
            Text("Elevated Card")
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
        }

        HeirloomCard(compact: true) {
            Text("Compact Card (reduced padding)")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }
    .padding()
    .background(HeirloomColors.appBackground)
}
