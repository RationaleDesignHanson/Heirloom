import SwiftUI

// MARK: - What's New Entry
struct WhatsNewEntry: Identifiable {
    let id = UUID()
    let version: String
    let date: String
    let features: [Feature]

    struct Feature: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
        let type: FeatureType

        enum FeatureType {
            case new
            case improvement
            case fix
        }
    }
}

// MARK: - What's New View
struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }

    private let releases: [WhatsNewEntry] = [
        WhatsNewEntry(
            version: "1.0.0",
            date: "December 2024",
            features: [
                WhatsNewEntry.Feature(
                    icon: "star.fill",
                    title: "Milestone Celebrations",
                    description: "Celebrate your cooking journey with confetti animations when you reach milestones like your first recipe or 10 recipes!",
                    type: .new
                ),
                WhatsNewEntry.Feature(
                    icon: "exclamationmark.triangle.fill",
                    title: "Improved Error Messages",
                    description: "Better error messages with recovery instructions and help links to guide you when something goes wrong.",
                    type: .improvement
                ),
                WhatsNewEntry.Feature(
                    icon: "paintbrush.fill",
                    title: "Card Personalization",
                    description: "Customize your recipe cards with stickers, annotations, and love marks to make them uniquely yours.",
                    type: .new
                ),
                WhatsNewEntry.Feature(
                    icon: "fork.knife",
                    title: "Dinner Party Planning",
                    description: "Plan dinner parties with guest counts, serving calculations, and shopping list integration.",
                    type: .new
                ),
                WhatsNewEntry.Feature(
                    icon: "cart.fill",
                    title: "Smart Shopping Lists",
                    description: "Ingredients are automatically organized by store aisle and intelligently aggregated across recipes.",
                    type: .new
                ),
                WhatsNewEntry.Feature(
                    icon: "camera.fill",
                    title: "Recipe Card Scanning",
                    description: "Scan physical recipe cards with your camera and let OCR + AI extract the recipe automatically.",
                    type: .new
                ),
                WhatsNewEntry.Feature(
                    icon: "flame.fill",
                    title: "Cooking Mode",
                    description: "Hands-free cooking with step-by-step instructions, timers, and voice feedback.",
                    type: .new
                ),
                WhatsNewEntry.Feature(
                    icon: "icloud.fill",
                    title: "iCloud Sync",
                    description: "Your recipes automatically sync across all your Apple devices using iCloud.",
                    type: .new
                ),
                WhatsNewEntry.Feature(
                    icon: "arrow.clockwise",
                    title: "Ingredient Scaling",
                    description: "Automatically scale recipe quantities when adjusting servings with smart rounding.",
                    type: .new
                ),
                WhatsNewEntry.Feature(
                    icon: "square.grid.2x2.fill",
                    title: "Recipe Collections",
                    description: "Organize recipes into custom collections like 'Holiday Favorites' or 'Quick Weeknight Meals'.",
                    type: .new
                )
            ]
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeirloomSpacing.xl) {
                // Header
                headerSection

                // Releases
                ForEach(releases) { release in
                    releaseSection(release)
                }
            }
            .padding(HeirloomSpacing.lg)
        }
        .background(HeirloomColors.appBackground)
        .navigationTitle("What's New")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            analytics.track(event: .featureUsed, properties: [
                "feature": "whats_new_view"
            ])
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundStyle(HeirloomColors.tomato)

                Text("What's New")
                    .font(HeirloomFonts.title())
                    .fontWeight(.bold)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Text("See what's new in Heirloom")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Release Section

    private func releaseSection(_ release: WhatsNewEntry) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            // Version header
            HStack(alignment: .firstTextBaseline) {
                Text("Version \(release.version)")
                    .font(HeirloomFonts.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(HeirloomColors.primaryText)

                Spacer()

                Text(release.date)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            // Features
            VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                ForEach(release.features) { feature in
                    featureRow(feature)
                }
            }
        }
        .padding(HeirloomSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .fill(.white)
                .heirloomShadow(HeirloomShadows.subtle)
        )
    }

    // MARK: - Feature Row

    private func featureRow(_ feature: WhatsNewEntry.Feature) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.md) {
            // Icon
            Image(systemName: feature.icon)
                .font(HeirloomFonts.title2)
                .foregroundStyle(featureColor(feature.type))
                .frame(width: 30)

            // Content
            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                HStack(spacing: HeirloomSpacing.sm) {
                    Text(feature.title)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    featureBadge(feature.type)
                }

                Text(feature.description)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
    }

    // MARK: - Feature Badge

    private func featureBadge(_ type: WhatsNewEntry.Feature.FeatureType) -> some View {
        Text(badgeText(type))
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(HeirloomColors.buttonTextLight)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(badgeColor(type))
            )
    }

    // MARK: - Helpers

    private func featureColor(_ type: WhatsNewEntry.Feature.FeatureType) -> Color {
        switch type {
        case .new:
            return HeirloomColors.tomato
        case .improvement:
            return .blue
        case .fix:
            return HeirloomColors.familyGreen
        }
    }

    private func badgeText(_ type: WhatsNewEntry.Feature.FeatureType) -> String {
        switch type {
        case .new:
            return "NEW"
        case .improvement:
            return "IMPROVED"
        case .fix:
            return "FIXED"
        }
    }

    private func badgeColor(_ type: WhatsNewEntry.Feature.FeatureType) -> Color {
        switch type {
        case .new:
            return HeirloomColors.tomato
        case .improvement:
            return .blue
        case .fix:
            return HeirloomColors.familyGreen
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        WhatsNewView()
    }
}
