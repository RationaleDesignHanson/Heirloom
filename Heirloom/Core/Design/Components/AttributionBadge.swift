import SwiftUI

/// Badge component displaying recipe source attribution and provenance
/// Shows where the recipe came from and its generation in the share chain
struct AttributionBadge: View {
    let recipe: Recipe
    let style: BadgeStyle

    enum BadgeStyle {
        case compact    // Small badge for list views
        case detailed   // Full badge with generation info
        case minimal    // Just icon and text, no background
    }

    var body: some View {
        switch style {
        case .compact:
            compactView
        case .detailed:
            detailedView
        case .minimal:
            minimalView
        }
    }

    // MARK: - Compact Style

    private var compactView: some View {
        HStack(spacing: 4) {
            sourceIcon
                .font(.caption2)

            Text(sourceText)
                .font(.caption2)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .foregroundStyle(foregroundColor)
        .clipShape(Capsule())
    }

    // MARK: - Detailed Style

    private var detailedView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                sourceIcon
                    .font(.subheadline)

                Text(sourceText)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if let generationText = recipe.generationDisplayText {
                    generationBadge(text: generationText)
                }

                if recipe.isTrending {
                    trendingIndicator
                }
            }

            if let shareCount = shareCountText {
                Text(shareCount)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(backgroundColor.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Minimal Style

    private var minimalView: some View {
        HStack(spacing: 4) {
            sourceIcon
                .font(.caption)

            Text(sourceText)
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Subviews

    private var sourceIcon: some View {
        Image(systemName: iconName)
            .foregroundStyle(iconColor)
    }

    private func generationBadge(text: String) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(HeirloomColors.amber.opacity(0.3))
            .clipShape(Capsule())
    }

    private var trendingIndicator: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
            Text("Trending")
        }
        .font(.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(.orange)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.orange.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Computed Properties

    private var sourceText: String {
        recipe.displaySource
    }

    private var iconName: String {
        if let provenance = recipe.provenance {
            return provenance.sourceType.iconName
        }

        // Fallback to legacy source type
        switch recipe.sourceType {
        case .manual:
            return "pencil.circle.fill"
        case .url:
            return "arrow.down.circle.fill"
        case .family:
            return "person.2.fill"
        case .cookbook:
            return "book.closed.fill"
        default:
            return "doc.fill"
        }
    }

    private var iconColor: Color {
        if let provenance = recipe.provenance {
            switch provenance.sourceType {
            case .userCreated:
                return HeirloomColors.charcoal
            case .imported:
                return .blue
            case .shared:
                return .purple
            case .scanned:
                return .orange
            case .ai:
                return .pink
            case .video:
                return HeirloomColors.tomato
            }
        }

        // Fallback colors
        switch recipe.sourceType {
        case .manual:
            return HeirloomColors.charcoal
        case .url:
            return .blue
        case .family:
            return .purple
        case .cookbook:
            return .orange
        default:
            return .gray
        }
    }

    private var backgroundColor: Color {
        if let provenance = recipe.provenance {
            switch provenance.sourceType {
            case .userCreated:
                return HeirloomColors.cream
            case .imported:
                return Color.blue.opacity(0.1)
            case .shared:
                return Color.purple.opacity(0.1)
            case .scanned:
                return Color.orange.opacity(0.1)
            case .ai:
                return Color.pink.opacity(0.1)
            case .video:
                return HeirloomColors.tomato.opacity(0.1)
            }
        }

        return HeirloomColors.cream
    }

    private var foregroundColor: Color {
        iconColor
    }

    private var shareCountText: String? {
        let count = recipe.totalShares
        guard count > 0 else { return nil }
        return recipe.shareCountDisplay
    }
}

// MARK: - Convenience Initializers

extension AttributionBadge {
    /// Create a compact badge for list views
    static func compact(for recipe: Recipe) -> AttributionBadge {
        AttributionBadge(recipe: recipe, style: .compact)
    }

    /// Create a detailed badge with full info
    static func detailed(for recipe: Recipe) -> AttributionBadge {
        AttributionBadge(recipe: recipe, style: .detailed)
    }

    /// Create a minimal badge (no background)
    static func minimal(for recipe: Recipe) -> AttributionBadge {
        AttributionBadge(recipe: recipe, style: .minimal)
    }
}

// MARK: - Previews

#Preview("Attribution Badge Styles") {
    PreviewBadgeStylesView()
}

#Preview("Badge on Recipe Card") {
    PreviewBadgeOnCardView()
}

// MARK: - Preview Helper Views

private struct PreviewBadgeStylesView: View {
    var body: some View {
        VStack(spacing: 20) {
            // User created recipe
            let userRecipe = makeUserCreatedRecipe()

            VStack(alignment: .leading, spacing: 12) {
                Text("User Created")
                    .font(.headline)

                AttributionBadge.compact(for: userRecipe)
                AttributionBadge.detailed(for: userRecipe)
                AttributionBadge.minimal(for: userRecipe)
            }

            Divider()

            // Imported recipe
            let importedRecipe = makeImportedRecipe()

            VStack(alignment: .leading, spacing: 12) {
                Text("Imported from Web")
                    .font(.headline)

                AttributionBadge.compact(for: importedRecipe)
                AttributionBadge.detailed(for: importedRecipe)
                AttributionBadge.minimal(for: importedRecipe)
            }

            Divider()

            // Shared recipe
            let sharedRecipe = makeSharedRecipe()

            VStack(alignment: .leading, spacing: 12) {
                Text("Shared Recipe")
                    .font(.headline)

                AttributionBadge.compact(for: sharedRecipe)
                AttributionBadge.detailed(for: sharedRecipe)
                AttributionBadge.minimal(for: sharedRecipe)
            }
        }
        .padding()
    }

    private func makeUserCreatedRecipe() -> Recipe {
        let recipe = Recipe(title: "My Chocolate Chip Cookies")
        recipe.provenance = .sampleUserCreated()
        return recipe
    }

    private func makeImportedRecipe() -> Recipe {
        let recipe = Recipe(title: "Web Recipe")
        recipe.provenance = .sampleImported()
        return recipe
    }

    private func makeSharedRecipe() -> Recipe {
        let recipe = Recipe(title: "Shared from Friend")
        recipe.provenance = .sampleShared()
        return recipe
    }
}

private struct PreviewBadgeOnCardView: View {
    var body: some View {
        VStack {
            let recipe = makeTrendingRecipe()

            ZStack(alignment: .topLeading) {
                // Recipe card
                RoundedRectangle(cornerRadius: 20)
                    .fill(HeirloomColors.cream)
                    .frame(width: 300, height: 200)
                    .shadow(radius: 5)

                VStack(alignment: .leading) {
                    Text(recipe.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    AttributionBadge.detailed(for: recipe)
                }
                .padding()
            }
            .frame(width: 300, height: 200)
        }
        .padding()
    }

    private func makeTrendingRecipe() -> Recipe {
        let recipe = Recipe(title: "Grandma's Apple Pie")
        recipe.provenance = ProvenanceMetadata(
            sourceType: .shared,
            sourceAttribution: "Originally from Betty Crocker",
            generation: 2,
            sharedByName: "Mom",
            cachedMetrics: AggregatedMetrics(
                totalShares: 23,
                totalCooks: 156,
                averageRating: 4.8,
                ratingCount: 42,
                trendingScore: 15.3
            )
        )
        return recipe
    }
}
