import SwiftUI

/// Live preview of what the recipient will see when they receive the shared recipe
/// Shows the recipe card with selected personalization options
struct SharePreviewCard: View {
    let recipe: Recipe
    let options: ShareOptions

    @State private var recipeImage: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            // Preview label
            HStack {
                Image(systemName: "eye.fill")
                Text("Recipient's View")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(HeirloomColors.secondaryText)
            .padding(.bottom, 8)

            // Recipe card
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(HeirloomColors.cream)
                    .shadow(color: HeirloomColors.cardShadow, radius: 10)

                VStack(alignment: .leading, spacing: 12) {
                    // Recipe image
                    if let image = recipeImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Title
                    Text(recipe.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    // Attribution
                    if let sharerName = options.sharerName {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption)
                            Text("Shared by \(sharerName)")
                                .font(.subheadline)
                        }
                        .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    // Personal message
                    if let message = options.personalMessage, !message.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "quote.bubble.fill")
                                    .font(.caption)
                                Text("Note from \(options.sharerName ?? "sender")")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(HeirloomColors.secondaryText)

                            Text("\"\(message)\"")
                                .font(.subheadline)
                                .italic()
                                .foregroundStyle(HeirloomColors.secondaryText)
                                .padding(.leading, 8)
                        }
                        .padding(12)
                        .background(HeirloomColors.amber.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Rating (if included)
                    if options.includeRating, let rating = recipe.provenance?.cachedMetrics.averageRating {
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                            }
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        }
                    }

                    // Basic info
                    HStack(spacing: 16) {
                        if let servings = recipe.servings {
                            InfoPill(icon: "person.2.fill", text: servings)
                        }
                        if let prepTime = recipe.prepTime {
                            InfoPill(icon: "clock.fill", text: prepTime)
                        }
                    }

                    Spacer()

                    // What's included indicator
                    HStack(spacing: 8) {
                        if options.includeCardBack {
                            IncludedBadge(icon: "rectangle.portrait.fill", text: "Card Back")
                        }
                        if options.includePinnedComments {
                            IncludedBadge(icon: "pin.fill", text: "Comments")
                        }
                        if options.includeStickers {
                            IncludedBadge(icon: "star.circle.fill", text: "Stickers")
                        }
                    }
                }
                .padding(16)
            }
            .frame(height: 420)
        }
        .task {
            recipeImage = await recipe.loadImage()
        }
    }
}

// MARK: - Subcomponents

private struct InfoPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(HeirloomColors.warmGray.opacity(0.1))
        .clipShape(Capsule())
        .foregroundStyle(HeirloomColors.secondaryText)
    }
}

private struct IncludedBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.green.opacity(0.15))
        .foregroundStyle(.green)
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview("Share Preview Card") {
    let recipe = Recipe(title: "Grandma's Chocolate Chip Cookies")
    recipe.servings = "24 cookies"
    recipe.prepTime = "15 min"
    recipe.cookTime = "12 min"
    recipe.provenance = ProvenanceMetadata(
        sourceType: .userCreated,
        cachedMetrics: AggregatedMetrics(
            totalShares: 5,
            averageRating: 4.8,
            ratingCount: 12
        )
    )

    var options = ShareOptions.default
    options.sharerName = "Sarah Miller"
    options.personalMessage = "This is my grandmother's recipe - she made these every Sunday! The secret is to not overmix the batter."

    return SharePreviewCard(recipe: recipe, options: options)
        .padding()
        .frame(maxWidth: 400)
}
