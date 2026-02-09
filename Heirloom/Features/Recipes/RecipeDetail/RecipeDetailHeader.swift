//
//  RecipeDetailHeader.swift
//  Heirloom
//
//  Phase 3: View Layer Decomposition
//  Header component for RecipeDetailView
//

import SwiftUI

/// Recipe detail header showing title, source, and action buttons
struct RecipeDetailHeader: View {
    // MARK: - Properties

    @Environment(\.openURL) private var openURL

    let recipe: Recipe
    let displayTitle: String
    let isInShoppingCart: Bool
    let selectedVersionCreatorName: String?  // Name of creator when viewing another version
    let onToggleFavorite: () -> Void
    let onAddToShoppingList: () -> Void
    let onViewOriginalRecipe: (() -> Void)?

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Title
            Text(displayTitle)
                .font(HeirloomFonts.title1)
                .foregroundStyle(HeirloomColors.charcoal)

            // Source Badge
            if let sourceURL = recipe.sourceURL,
               let url = URL(string: sourceURL),
               recipe.sourceType == .url {
                // Tappable link for URL sources
                Link(destination: url) {
                    HStack(spacing: HeirloomSpacing.xs) {
                        Image(systemName: "globe")
                            .font(HeirloomFonts.caption1)
                        Text(recipe.sourceDisplayName)
                            .font(HeirloomFonts.caption1)
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                            .opacity(0.7)
                    }
                    .foregroundStyle(HeirloomColors.tomato)
                }
            } else if let searchURL = cookbookSearchURL {
                // Tappable link for cookbook/scan sources — opens web search for cookbook+author
                Button {
                    openURL(searchURL)
                } label: {
                    HStack(spacing: HeirloomSpacing.xs) {
                        Image(systemName: recipe.sourceType?.iconName ?? "book.closed.fill")
                            .font(HeirloomFonts.caption1)
                        Text(recipe.sourceDisplayName)
                            .font(HeirloomFonts.caption1)
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                            .opacity(0.7)
                    }
                    .foregroundStyle(HeirloomColors.tomato)
                }
                .buttonStyle(.plain)
            } else {
                // Non-tappable for manual/family/heritage sources
                HStack(spacing: HeirloomSpacing.xs) {
                    Image(systemName: recipe.sourceType?.iconName ?? "square.and.pencil")
                        .font(HeirloomFonts.caption1)
                    // Show selected version's creator name if viewing another version, otherwise show recipe source
                    Text(selectedVersionCreatorName ?? recipe.sourceDisplayName)
                        .font(HeirloomFonts.caption1)

                    // Community attribution (if from public recipe) - tappable to view original
                    if let creatorName = recipe.sourcePublicRecipeCreatorName,
                       recipe.hasPublicUpstream,
                       let onViewOriginal = onViewOriginalRecipe {
                        Text("•")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.charcoal.opacity(0.4))

                        Button {
                            onViewOriginal()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .font(.system(size: 10))

                                Text("by \(creatorName)")
                                    .font(HeirloomFonts.caption1)

                                Image(systemName: "arrow.up.forward.square")
                                    .font(.system(size: 9))
                                    .opacity(0.7)
                            }
                            .foregroundStyle(HeirloomColors.familyGreen)
                        }
                    }
                }
                .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))
            }

            // Action Buttons
            HStack(spacing: HeirloomSpacing.md) {
                // Favorite Button
                Button {
                    onToggleFavorite()
                } label: {
                    Label(
                        recipe.isFavorite ? "Favorited" : "Favorite",
                        systemImage: recipe.isFavorite ? "heart.fill" : "heart"
                    )
                    .font(HeirloomFonts.bodyBold)
                }
                .buttonStyle(SecondaryButtonStyle())

                // Add to Shopping List Button
                Button {
                    onAddToShoppingList()
                } label: {
                    Label(
                        isInShoppingCart ? "In List" : "Shopping List",
                        systemImage: isInShoppingCart ? "checkmark.circle.fill" : "cart"
                    )
                    .font(HeirloomFonts.bodyBold)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    // MARK: - Cookbook Search

    /// Search URL for cookbook/scan recipes with book title or author
    private var cookbookSearchURL: URL? {
        let sourceType = recipe.sourceType ?? .manual
        guard sourceType == .cookbook || sourceType == .scan else { return nil }

        var searchQuery = ""
        if let title = recipe.sourceBookTitle, !title.isEmpty {
            searchQuery = title
        }
        if let author = recipe.sourceBookAuthor, !author.isEmpty {
            if !searchQuery.isEmpty { searchQuery += " by " }
            searchQuery += author
        }

        guard !searchQuery.isEmpty else { return nil }

        let encoded = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchQuery
        return URL(string: "https://www.google.com/search?q=\(encoded)+cookbook")
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var recipe: Recipe = {
        let recipe = Recipe(
            title: "Classic Chocolate Chip Cookies",
            sourceType: .manual,
            sourceURL: nil,
            instructions: ["Mix ingredients", "Bake at 350°F"],
            servings: "24 cookies",
            prepTime: "15 min",
            cookTime: "12 min"
        )
        recipe.isFavorite = true
        return recipe
    }()

    RecipeDetailHeader(
        recipe: recipe,
        displayTitle: "Classic Chocolate Chip Cookies",
        isInShoppingCart: false,
        selectedVersionCreatorName: nil,
        onToggleFavorite: { Log.debug("Preview: Toggle favorite", category: .ui) },
        onAddToShoppingList: { Log.debug("Preview: Add to shopping list", category: .ui) },
        onViewOriginalRecipe: nil
    )
    .padding()
    .background(HeirloomColors.cream)
}
