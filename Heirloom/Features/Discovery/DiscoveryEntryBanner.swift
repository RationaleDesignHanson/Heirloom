import SwiftUI

/// Banner/card that opens the public discovery feed
/// Shown in RecipeListView above theme sections
struct DiscoveryEntryBanner: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: HeirloomSpacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(HeirloomColors.familyBlue.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: "globe")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(HeirloomColors.familyBlue)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Discover Recipes")
                        .font(HeirloomFonts.headlineBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Browse trending recipes from the community")
                        .font(HeirloomFonts.caption)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HeirloomColors.warmGray)
            }
            .padding(HeirloomSpacing.md)
            .background(HeirloomColors.cardBackground)
            .cornerRadius(12)
            .shadow(
                color: HeirloomShadows.card.color,
                radius: HeirloomShadows.card.radius,
                x: HeirloomShadows.card.x,
                y: HeirloomShadows.card.y
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        DiscoveryEntryBanner(onTap: {})

        DiscoveryEntryBanner(onTap: {})
            .padding()
            .background(HeirloomColors.appBackground)
    }
    .padding()
}
