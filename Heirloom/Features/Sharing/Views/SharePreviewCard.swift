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
                    .font(HeirloomFonts.caption1)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(HeirloomColors.secondaryText)
            .padding(.bottom, 8)

            // Recipe card
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(HeirloomColors.cream)
                    .heirloomShadow(HeirloomShadows.card)

                VStack(alignment: .leading, spacing: 12) {
                    // Recipe image
                    if let image = recipeImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius))
                    }

                    // Title
                    Text(recipe.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    // Attribution
                    if let sharerName = options.sharerName {
                        HStack(spacing: HeirloomSpacing.xs) {
                            Image(systemName: "person.fill")
                                .font(HeirloomFonts.caption1)
                            Text("Shared by \(sharerName)")
                                .font(HeirloomFonts.body)
                        }
                        .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    // Personal message
                    if let message = options.personalMessage, !message.isEmpty {
                        VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                            HStack(spacing: HeirloomSpacing.xs) {
                                Image(systemName: "quote.bubble.fill")
                                    .font(HeirloomFonts.caption1)
                                Text("Note from \(options.sharerName ?? "sender")")
                                    .font(HeirloomFonts.caption1)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(HeirloomColors.secondaryText)

                            Text("\"\(message)\"")
                                .font(HeirloomFonts.body)
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
                        HStack(spacing: HeirloomSpacing.xs) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                    .foregroundStyle(.yellow)
                                    .font(HeirloomFonts.caption1)
                            }
                            Text(String(format: "%.1f", rating))
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        }
                    }

                    // Basic info
                    HStack(spacing: HeirloomSpacing.md) {
                        if let servings = recipe.servings {
                            InfoPill(icon: "person.2.fill", text: servings)
                        }
                        if let prepTime = recipe.prepTime {
                            InfoPill(icon: "clock.fill", text: prepTime)
                        }
                    }

                    Spacer()

                    // What's included indicator
                    HStack(spacing: HeirloomSpacing.sm) {
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
                .padding(HeirloomSpacing.md)
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
        HStack(spacing: HeirloomSpacing.xs) {
            Image(systemName: icon)
                .font(HeirloomFonts.caption2)
            Text(text)
                .font(HeirloomFonts.caption1)
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
                .font(HeirloomFonts.caption2)
            Text(text)
                .font(HeirloomFonts.caption2)
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
