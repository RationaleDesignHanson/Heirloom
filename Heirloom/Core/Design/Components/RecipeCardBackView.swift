//
//  RecipeCardBackView.swift
//  Heirloom
//
//  Created by Claude on 1/5/26.
//  Redesigned for elegant typography on 2/19/26.
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

            // Content with scroll protection
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // Render visible sections in order
                    ForEach(cardBack.visibleSections, id: \.self) { section in
                        sectionView(for: section)
                    }
                }
                .padding(18)
            }

            // Border
            if cardBack.showBorder {
                RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                    .stroke(Color(hex: cardBack.borderColor) ?? Color(.systemGray4), lineWidth: 1.5)
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
            if let historicalText = recipe.historicalText, !historicalText.isEmpty {
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
                    Color(hex: "#EBD9C6") ?? .white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle texture overlay
            Color.brown.opacity(0.02)
        }
    }
}

// MARK: - Lined Paper Background

struct LinedPaperBackgroundView: View {
    var body: some View {
        ZStack {
            Color(hex: "#FFFEF0") ?? .white

            VStack(spacing: HeirloomSpacing.lg) {
                ForEach(0..<15, id: \.self) { _ in
                    Divider()
                        .background(Color.blue.opacity(0.15))
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
                ForEach(0..<15, id: \.self) { _ in
                    Divider()
                        .background(Color.gray.opacity(0.12))
                }
            }

            // Vertical lines
            HStack(spacing: 20) {
                ForEach(0..<10, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.12))
                        .frame(width: 0.5)
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
        if let attribution = cardBack.customAttributionText ?? recipe.attribution {
            VStack(alignment: .leading, spacing: 2) {
                Text("FROM")
                    .font(HeirloomFonts.CardBack.metadata)
                    .tracking(HeirloomSpacing.Tracking.label)
                    .foregroundColor(.secondary.opacity(0.7))

                Text(attribution)
                    .font(HeirloomFonts.CardBack.bodyEmphasis)
                    .foregroundColor(Color(hex: cardBack.textColor) ?? .primary)
                    .lineLimit(2)
            }
        }
    }
}

// MARK: - Note to Friends View

struct NoteToFriendsView: View {
    let note: String
    let cardBack: RecipeCardBack

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 12))
                    .foregroundColor(HeirloomColors.tomato.opacity(0.7))

                Text("A Note")
                    .font(HeirloomFonts.CardBack.sectionHeader)
                    .tracking(HeirloomSpacing.Tracking.header)
                    .foregroundColor(Color(hex: cardBack.textColor) ?? .primary)
            }

            // Body text with elegant italic serif
            Text(note)
                .font(HeirloomFonts.CardBack.personalNote)
                .lineSpacing(HeirloomSpacing.LineHeight.relaxed)
                .foregroundColor(Color(hex: cardBack.textColor)?.opacity(0.85) ?? .primary.opacity(0.85))
                .lineLimit(5)
                .truncationMode(.tail)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.brown.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - User Tips View

struct UserTipsView: View {
    let tips: [String]
    let cardBack: RecipeCardBack

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow.opacity(0.9))

                Text("Tips")
                    .font(HeirloomFonts.CardBack.sectionHeader)
                    .tracking(HeirloomSpacing.Tracking.header)
                    .foregroundColor(Color(hex: cardBack.textColor) ?? .primary)
            }

            // Tips list
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(tips.prefix(3).enumerated()), id: \.offset) { _, tip in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(HeirloomFonts.CardBack.bodyText)
                            .foregroundColor(Color(hex: cardBack.textColor)?.opacity(0.5) ?? .secondary)

                        Text(tip)
                            .font(HeirloomFonts.CardBack.bodyText)
                            .lineSpacing(HeirloomSpacing.LineHeight.standard)
                            .foregroundColor(Color(hex: cardBack.textColor) ?? .primary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }
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
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .foregroundColor(star <= rating ? .yellow : .gray.opacity(0.3))
                    .font(.system(size: 14))
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
            HStack(spacing: 6) {
                ForEach(tags.prefix(4), id: \.self) { tag in
                    Text(tag)
                        .font(HeirloomFonts.CardBack.metadata)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(HeirloomColors.tomato.opacity(0.1))
                        .foregroundColor(HeirloomColors.tomato)
                        .cornerRadius(10)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)

                Text("Pinned")
                    .font(HeirloomFonts.CardBack.sectionHeader)
                    .tracking(HeirloomSpacing.Tracking.header)
                    .foregroundColor(Color(hex: cardBack.textColor) ?? .primary)
            }

            Text("\(commentIDs.count) comment\(commentIDs.count == 1 ? "" : "s")")
                .font(HeirloomFonts.CardBack.metadata)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Cooking History View

struct CookingHistoryView: View {
    let recipe: Recipe
    let cardBack: RecipeCardBack

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cooking History")
                .font(HeirloomFonts.CardBack.sectionHeader)
                .tracking(HeirloomSpacing.Tracking.header)
                .foregroundColor(Color(hex: cardBack.textColor) ?? .primary)

            Text("Made this recipe 3 times")
                .font(HeirloomFonts.CardBack.metadata)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Heritage Collection Badge View

struct HeritageCollectionBadgeView: View {
    let recipe: Recipe
    let cardBack: RecipeCardBack

    var body: some View {
        HStack(spacing: 10) {
            // Heritage badge icon
            Image(systemName: "book.closed.fill")
                .font(.system(size: 18))
                .foregroundColor(.brown.opacity(0.8))
                .padding(8)
                .background(
                    Circle()
                        .fill(Color.brown.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("HERITAGE RECIPE")
                    .font(HeirloomFonts.CardBack.metadata)
                    .tracking(HeirloomSpacing.Tracking.label)
                    .foregroundColor(.brown.opacity(0.6))

                if let collection = recipe.heritageCollection {
                    Text(collection)
                        .font(HeirloomFonts.CardBack.sectionHeader)
                        .foregroundColor(.brown)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.brown.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.brown.opacity(0.15), lineWidth: 0.5)
        )
    }
}

// MARK: - Heritage Provenance View

struct HeritageProvenanceView: View {
    let recipe: Recipe
    let cardBack: RecipeCardBack

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 11))
                    .foregroundColor(.brown.opacity(0.7))

                Text("Provenance")
                    .font(HeirloomFonts.CardBack.sectionHeader)
                    .tracking(HeirloomSpacing.Tracking.header)
                    .foregroundColor(.brown)
            }

            // Show provenance chain
            if recipe.originalHeritageRecipeId != nil {
                VStack(alignment: .leading, spacing: 4) {
                    provenanceRow(
                        icon: "doc.text",
                        text: "Original Heritage Recipe",
                        isFirst: true
                    )

                    if recipe.parentRecipeId != nil {
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
        .padding(10)
        .background(Color.brown.opacity(0.03))
        .cornerRadius(10)
    }

    private func provenanceRow(icon: String, text: String, isFirst: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(isFirst ? .brown : .secondary.opacity(0.6))
                .frame(width: 14)

            Text(text)
                .font(HeirloomFonts.CardBack.metadata)
                .foregroundColor(isFirst ? .brown : .secondary)
        }
    }
}

// MARK: - Historical Text View

struct HistoricalTextView: View {
    let text: String
    let cardBack: RecipeCardBack

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "scroll.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.brown.opacity(0.7))

                Text("Historical Note")
                    .font(HeirloomFonts.CardBack.sectionHeader)
                    .tracking(HeirloomSpacing.Tracking.header)
                    .foregroundColor(.brown)
            }

            // Historical text with elegant serif italic
            Text(text)
                .font(HeirloomFonts.CardBack.heritageText)
                .lineSpacing(HeirloomSpacing.LineHeight.relaxed)
                .foregroundColor(.brown.opacity(0.8))
                .lineLimit(6)
                .truncationMode(.tail)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.brown.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.brown.opacity(0.12), lineWidth: 0.5)
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
