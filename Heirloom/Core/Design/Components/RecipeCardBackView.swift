//
//  RecipeCardBackView.swift
//  Heirloom
//
//  Created by Claude on 1/5/26.
//

import SwiftUI

/// Renders the back side of a recipe card with all configured sections
struct RecipeCardBackView: View {
    // MARK: - Properties
    let cardBack: RecipeCardBack
    let recipe: Recipe
    let cardSize: CGSize

    // MARK: - Body
    var body: some View {
        ZStack {
            // Background
            backgroundView

            // Content
            VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                // Render visible sections in order
                ForEach(cardBack.visibleSections, id: \.self) { section in
                    sectionView(for: section)
                }

                Spacer()
            }
            .padding(20)

            // Border
            if cardBack.showBorder {
                RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                    .stroke(Color(hex: cardBack.borderColor) ?? Color(.systemGray4), lineWidth: 2)
            }
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius))
    }

    // MARK: - Background View
    @ViewBuilder
    private var backgroundView: some View {
        switch cardBack.backgroundStyle {
        case .cream:
            Color(hex: "#FFF8DC") ?? Color(.systemBackground)

        case .vintage:
            VintageBackgroundView()

        case .lined:
            LinedPaperBackgroundView()

        case .grid:
            GridPaperBackgroundView()

        case .photo:
            Color(.systemGray6)

        case .solid:
            Color(hex: cardBack.textColor) ?? Color(.systemBackground)
        }
    }

    // MARK: - Section Views
    @ViewBuilder
    private func sectionView(for section: CardBackSection) -> some View {
        switch section {
        case .attribution:
            if cardBack.showAttribution {
                AttributionView(recipe: recipe, cardBack: cardBack)
            }

        case .noteToFriends:
            if let note = cardBack.noteToFriends {
                NoteToFriendsView(note: note, cardBack: cardBack)
            }

        case .userTips:
            if !cardBack.personalTips.isEmpty {
                UserTipsView(tips: cardBack.personalTips, cardBack: cardBack)
            }

        case .userRating:
            if let rating = cardBack.userRating {
                UserRatingView(rating: rating, cardBack: cardBack)
            }

        case .userTags:
            if !cardBack.userTags.isEmpty {
                UserTagsView(tags: cardBack.userTags, cardBack: cardBack)
            }

        case .pinnedComments:
            if !cardBack.pinnedCommentIDs.isEmpty {
                PinnedCommentsView(commentIDs: cardBack.pinnedCommentIDs, cardBack: cardBack)
            }

        case .cookingHistory:
            CookingHistoryView(recipe: recipe, cardBack: cardBack)

        // MARK: - Heritage Sections
        case .heritageCollectionBadge:
            if recipe.isThemeRecipe {
                HeritageCollectionBadgeView(recipe: recipe, cardBack: cardBack)
            }

        case .heritageProvenance:
            if recipe.isThemeRecipe {
                HeritageProvenanceView(recipe: recipe, cardBack: cardBack)
            }

        case .historicalText:
            if recipe.isThemeRecipe, let historicalText = recipe.historicalText {
                HistoricalTextView(text: historicalText, cardBack: cardBack)
            }
        }
    }
}

// MARK: - Vintage Background

struct VintageBackgroundView: View {
    var body: some View {
        ZStack {
            // Base aged paper color
            LinearGradient(
                colors: [
                    Color(hex: "#F5E6D3") ?? .white,
                    Color(hex: "#E8D7C3") ?? .white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle texture overlay
            Color.black.opacity(0.02)
        }
    }
}

// MARK: - Lined Paper Background

struct LinedPaperBackgroundView: View {
    var body: some View {
        ZStack {
            Color(hex: "#FFFEF0") ?? .white

            VStack(spacing: HeirloomSpacing.lg) {
                ForEach(0..<15) { _ in
                    Divider()
                        .background(Color.blue.opacity(0.2))
                }
            }
            .padding(.top, 40)
        }
    }
}

// MARK: - Grid Paper Background

struct GridPaperBackgroundView: View {
    var body: some View {
        ZStack {
            Color.white

            // Horizontal lines
            VStack(spacing: 20) {
                ForEach(0..<15) { _ in
                    Divider()
                        .background(Color.gray.opacity(0.15))
                }
            }

            // Vertical lines
            HStack(spacing: 20) {
                ForEach(0..<10) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 1)
                }
            }
        }
    }
}

// MARK: - Attribution View

struct AttributionView: View {
    let recipe: Recipe
    let cardBack: RecipeCardBack

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
            if let attribution = cardBack.customAttributionText ?? recipe.attribution {
                Text("From:")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(.secondary)

                Text(attribution)
                    .font(HeirloomFonts.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: cardBack.textColor) ?? .primary)
            }
        }
    }
}

// MARK: - Note to Friends View

struct NoteToFriendsView: View {
    let note: String
    let cardBack: RecipeCardBack

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Image(systemName: "heart.text.square")
                    .foregroundColor(.red)
                Text("A Note From Me")
                    .font(HeirloomFonts.title3)
            }

            Text(note)
                .font(HeirloomFonts.body)
                .foregroundColor(Color(hex: cardBack.textColor) ?? .primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.white.opacity(0.3))
        .cornerRadius(8)
    }
}

// MARK: - User Tips View

struct UserTipsView: View {
    let tips: [String]
    let cardBack: RecipeCardBack

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.yellow)
                Text("My Tips")
                    .font(HeirloomFonts.title3)
            }

            ForEach(Array(tips.prefix(3).enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
                    Text("•")
                        .foregroundColor(Color(hex: cardBack.textColor) ?? .primary)
                    Text(tip)
                        .font(HeirloomFonts.subheadline)
                        .foregroundColor(Color(hex: cardBack.textColor) ?? .primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - User Rating View

struct UserRatingView: View {
    let rating: Int
    let cardBack: RecipeCardBack

    var body: some View {
        HStack(spacing: HeirloomSpacing.xs) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .foregroundColor(star <= rating ? .yellow : .gray)
                    .font(HeirloomFonts.caption1)
            }
        }
    }
}

// MARK: - User Tags View

struct UserTagsView: View {
    let tags: [String]
    let cardBack: RecipeCardBack

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HeirloomSpacing.sm) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(HeirloomFonts.caption1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.2))
                        .foregroundColor(.accentColor)
                        .cornerRadius(12)
                }
            }
        }
    }
}

// MARK: - Pinned Comments View

struct PinnedCommentsView: View {
    let commentIDs: [UUID]
    let cardBack: RecipeCardBack

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Image(systemName: "pin")
                    .foregroundColor(.orange)
                Text("Pinned Comments")
                    .font(HeirloomFonts.title3)
            }

            Text("\(commentIDs.count) comment(s) pinned")
                .font(HeirloomFonts.caption1)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Cooking History View

struct CookingHistoryView: View {
    let recipe: Recipe
    let cardBack: RecipeCardBack

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
            Text("Cooking History")
                .font(HeirloomFonts.title3)

            Text("Made this recipe 3 times")
                .font(HeirloomFonts.caption1)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Heritage Collection Badge View

struct HeritageCollectionBadgeView: View {
    let recipe: Recipe
    let cardBack: RecipeCardBack

    var body: some View {
        HStack(spacing: 12) {
            // Heritage badge icon
            Image(systemName: "book.closed.fill")
                .font(.title2)
                .foregroundColor(.brown)
                .padding(HeirloomSpacing.sm)
                .background(
                    Circle()
                        .fill(Color.brown.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Heritage Recipe")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(.secondary)

                if let collection = recipe.heritageCollection {
                    Text(collection)
                        .font(HeirloomFonts.title3)
                        .foregroundColor(.brown)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.brown.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.brown.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Heritage Provenance View

struct HeritageProvenanceView: View {
    let recipe: Recipe
    let cardBack: RecipeCardBack

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(.brown)
                Text("Provenance")
                    .font(HeirloomFonts.title3)
                    .foregroundColor(.brown)
            }

            // Show provenance chain
            if let originalRecipe = recipe.originalHeritageRecipeId {
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    provenanceRow(
                        icon: "doc.text",
                        text: "Original Heritage Recipe",
                        isFirst: true
                    )

                    if let parentId = recipe.parentRecipeId {
                        provenanceRow(
                            icon: "arrow.down",
                            text: "Shared Copy",
                            isFirst: false
                        )
                    }

                    provenanceRow(
                        icon: "person",
                        text: "Your Copy",
                        isFirst: false
                    )
                }
            }
        }
        .padding(12)
        .background(Color.brown.opacity(0.05))
        .cornerRadius(8)
    }

    private func provenanceRow(icon: String, text: String, isFirst: Bool) -> some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: icon)
                .font(HeirloomFonts.caption1)
                .foregroundColor(isFirst ? .brown : .secondary)

            Text(text)
                .font(HeirloomFonts.caption1)
                .foregroundColor(isFirst ? .brown : .secondary)
        }
    }
}

// MARK: - Historical Text View

struct HistoricalTextView: View {
    let text: String
    let cardBack: RecipeCardBack

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Image(systemName: "scroll")
                    .foregroundColor(.brown)
                Text("Historical Note")
                    .font(HeirloomFonts.title3)
                    .foregroundColor(.brown)
            }

            Text(text)
                .font(HeirloomFonts.subheadline)
                .foregroundColor(Color(hex: cardBack.textColor) ?? .primary)
                .italic()
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.brown.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.brown.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    let recipe = Recipe.sample()
    recipe.isThemeRecipe = true
    recipe.heritageCollection = "1950s American Classics"
    recipe.historicalText = "This recipe was featured in the 1952 Better Homes & Gardens cookbook and became a staple of mid-century American cuisine."

    let cardBack = RecipeCardBack.sample(with: recipe)
    cardBack.configureForHeritageRecipe()

    return RecipeCardBackView(
        cardBack: cardBack,
        recipe: recipe,
        cardSize: CGSize(width: 350, height: 500)
    )
    .padding()
}
