//
//  RecipeCardBackPreview.swift
//  Heirloom
//
//  Created by Claude on 1/5/26.
//

import SwiftUI

/// Condensed preview of recipe card back for use in RecipeDetailView flip card
/// Shows key sections in a compact 300pt height layout
struct RecipeCardBackPreview: View {
    // MARK: - Properties
    let cardBack: RecipeCardBack
    let recipe: Recipe

    // MARK: - Body
    var body: some View {
        ZStack {
            // Background with vintage styling
            backgroundView

            // Content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    // Heritage badge (if applicable)
                    if recipe.isHeritageRecipe, cardBack.visibleSections.contains(.heritageCollectionBadge) {
                        HeritageCollectionBadgeCompactView(recipe: recipe)
                    }

                    // Personal note (if present)
                    if let note = cardBack.noteToFriends, cardBack.visibleSections.contains(.noteToFriends) {
                        PersonalNoteCompactView(note: note)
                    }

                    // Top 2 tips (if present)
                    if !cardBack.personalTips.isEmpty, cardBack.visibleSections.contains(.userTips) {
                        TipsCompactView(tips: Array(cardBack.personalTips.prefix(2)))
                    }

                    // Heritage historical text (if applicable)
                    if recipe.isHeritageRecipe,
                       let historicalText = recipe.historicalText,
                       cardBack.visibleSections.contains(.historicalText) {
                        HistoricalTextCompactView(text: historicalText)
                    }

                    Spacer(minLength: 40)

                    // "Tap to customize" button at bottom
                    customizeButton
                }
                .padding(HeirloomSpacing.md)
            }

            // Border
            if cardBack.showBorder {
                RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                    .stroke(Color(hex: cardBack.borderColor), lineWidth: 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius))
    }

    // MARK: - Background
    @ViewBuilder
    private var backgroundView: some View {
        if recipe.isHeritageRecipe {
            // Vintage background for heritage recipes
            LinearGradient(
                colors: [
                    Color(hex: "#F5E6D3"),
                    Color(hex: "#E8D7C3")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(Color.black.opacity(0.02))
        } else {
            // Standard cream background
            Color(hex: "#FFF8DC")
        }
    }

    // MARK: - Customize Button
    private var customizeButton: some View {
        HStack {
            Spacer()

            VStack(spacing: HeirloomSpacing.xs) {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(HeirloomFonts.title2)
                Text("Tap to Customize")
                    .font(HeirloomFonts.caption1)
                    .fontWeight(.medium)
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
            )

            Spacer()
        }
    }
}

// MARK: - Compact Section Views

struct HeritageCollectionBadgeCompactView: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "book.closed.fill")
                .font(HeirloomFonts.title2)
                .foregroundColor(.brown)

            VStack(alignment: .leading, spacing: 2) {
                Text("Heritage Recipe")
                    .font(HeirloomFonts.caption2)
                    .foregroundColor(.secondary)

                if let collection = recipe.heritageCollectionId {
                    Text(collection)
                        .font(HeirloomFonts.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.brown)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.brown.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.brown.opacity(0.2), lineWidth: 1)
        )
    }
}

struct PersonalNoteCompactView: View {
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "heart.text.square")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(.red)
                Text("Note")
                    .font(HeirloomFonts.caption1)
                    .fontWeight(.semibold)
            }

            Text(note)
                .font(HeirloomFonts.caption1)
                .foregroundColor(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.white.opacity(0.3))
        .cornerRadius(6)
    }
}

struct TipsCompactView: View {
    let tips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(.yellow)
                Text("Tips")
                    .font(HeirloomFonts.caption1)
                    .fontWeight(.semibold)
            }

            ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .font(HeirloomFonts.caption2)
                    Text(tip)
                        .font(HeirloomFonts.caption1)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(10)
        .background(Color.yellow.opacity(0.05))
        .cornerRadius(6)
    }
}

struct HistoricalTextCompactView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "scroll")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(.brown)
                Text("Historical Note")
                    .font(HeirloomFonts.caption1)
                    .fontWeight(.semibold)
                    .foregroundColor(.brown)
            }

            Text(text)
                .font(HeirloomFonts.caption1)
                .foregroundColor(.primary)
                .italic()
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.brown.opacity(0.05))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.brown.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Standard Recipe") {
    let recipe = Recipe.example
    let cardBack = RecipeCardBack.sample(with: recipe)

    RecipeCardBackPreview(
        cardBack: cardBack,
        recipe: recipe
    )
    .frame(width: 350, height: 300)
    .padding()
}

#Preview("Heritage Recipe") {
    @Previewable @State var previewData: (Recipe, RecipeCardBack) = {
        let recipe = Recipe.example
        recipe.isHeritageRecipe = true
        recipe.heritageCollectionId = "1950s-american-classics"
        recipe.historicalText = "This recipe was featured in the 1952 Better Homes & Gardens cookbook and became a staple of mid-century American cuisine."

        let cardBack = RecipeCardBack.sample(with: recipe)
        cardBack.configureForHeritageRecipe()

        return (recipe, cardBack)
    }()

    RecipeCardBackPreview(
        cardBack: previewData.1,
        recipe: previewData.0
    )
    .frame(width: 350, height: 300)
    .padding()
}

#Preview("Minimal Content") {
    @Previewable @State var cardBack: RecipeCardBack = {
        let recipe = Recipe.example
        let cardBack = RecipeCardBack(recipe: recipe)
        cardBack.noteToFriends = "Simple and delicious!"
        cardBack.isComplete = true
        return cardBack
    }()

    let recipe = Recipe.example

    RecipeCardBackPreview(
        cardBack: cardBack,
        recipe: recipe
    )
    .frame(width: 350, height: 300)
    .padding()
}
