//
//  StandardCollectionCard.swift
//  Heirloom
//
//  Refactored: 2026-01-27 - Unified vertical card layout
//

import SwiftUI

struct StandardCollectionCard: View {
    let collection: RecipeCollection

    private var recipeCount: Int {
        collection.recipes?.count ?? 0
    }

    /// Get first 2 recipes for small thumbnail display
    private var recipeImages: [Recipe] {
        let recipes = collection.recipes ?? []
        return Array(recipes.prefix(2))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Image collage (60/40 split)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    // Large image (60%) - Collection background or first recipe
                    largeImageView
                        .frame(width: geo.size.width * 0.6)

                    // Stacked small images (40%) - Recipe images
                    VStack(spacing: 2) {
                        recipeImageView(for: recipeImages.first)
                        recipeImageView(for: recipeImages.count > 1 ? recipeImages[1] : nil)
                    }
                    .frame(width: geo.size.width * 0.4 - 2)
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Info bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.displayName)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)
                        .lineLimit(1)

                    Text(collection.subtitleText)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                // Recipe count badge
                recipeCountBadge
            }
            .padding(.horizontal, HeirloomSpacing.md)
            .padding(.vertical, HeirloomSpacing.sm)
        }
        .background(HeirloomColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    // MARK: - Large Image View

    @ViewBuilder
    private var largeImageView: some View {
        // Priority 1: AI-generated background
        if let generatedPath = collection.generatedBackgroundImagePath {
            AsyncRecipeImage(
                imageFileName: generatedPath,
                firebaseImageURL: nil,
                placeholder: collection.iconName
            )
        }
        // Priority 2: Custom user-selected background
        else if let customPath = collection.customBackgroundImagePath {
            AsyncRecipeImage(
                imageFileName: customPath,
                firebaseImageURL: nil,
                placeholder: collection.iconName
            )
        }
        // Priority 3: First recipe's image (as fallback)
        else if let firstRecipe = recipeImages.first,
                firstRecipe.imageFileName != nil {
            AsyncRecipeImage(
                imageFileName: firstRecipe.imageFileName,
                firebaseImageURL: firstRecipe.firebaseImageURL,
                placeholder: collection.iconName
            )
        }
        // Priority 4: Placeholder
        else {
            placeholderView
        }
    }

    // MARK: - Recipe Image View (Small Thumbnails)

    @ViewBuilder
    private func recipeImageView(for recipe: Recipe?) -> some View {
        if let recipe = recipe,
           (recipe.imageFileName != nil || recipe.firebaseImageURL != nil) {
            AsyncRecipeImage(
                imageFileName: recipe.imageFileName,
                firebaseImageURL: recipe.firebaseImageURL,
                placeholder: collection.iconName
            )
        }
        // If only 1 recipe, show + affordance in empty slot
        else if recipeImages.count == 1 && recipe == nil {
            addRecipeAffordance
        }
        else {
            placeholderView
        }
    }

    // MARK: - Subviews

    private var addRecipeAffordance: some View {
        Rectangle()
            .fill(HeirloomColors.warmGray.opacity(0.1))
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(HeirloomColors.tomato)

                    Text("Add")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            )
    }

    private var recipeCountBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.text")
                .font(.caption)
            Text("\(recipeCount)")
                .font(HeirloomFonts.caption1)
        }
        .foregroundStyle(HeirloomColors.secondaryText)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(HeirloomColors.warmGray.opacity(0.1))
        .cornerRadius(8)
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        HeirloomColors.warmGray.opacity(0.15),
                        HeirloomColors.warmGray.opacity(0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: collection.iconName)
                    .font(.title2)
                    .foregroundStyle(HeirloomColors.warmGray.opacity(0.5))
            )
    }
}
