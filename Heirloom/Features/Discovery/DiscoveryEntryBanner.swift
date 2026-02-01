import SwiftUI

/// Collection-style card that opens the public discovery feed
/// Matches UnifiedCollectionCard styling
struct DiscoveryEntryBanner: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Visual area (matches 180px height of collection cards)
                ZStack {
                    // Gradient background
                    LinearGradient(
                        colors: [
                            HeirloomColors.familyGreen.opacity(0.3),
                            HeirloomColors.familyGreen.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Globe icon
                    Image(systemName: "globe")
                        .font(.system(size: 64, weight: .medium))
                        .foregroundStyle(HeirloomColors.familyGreen.opacity(0.6))
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // Info bar (matches collection card style)
                HStack(spacing: HeirloomSpacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Discover Recipes")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)

                        Text("Trending recipes from the community")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    Spacer()

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HeirloomColors.warmGray)
                }
                .padding(HeirloomSpacing.md)
            }
            .background(HeirloomColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
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
