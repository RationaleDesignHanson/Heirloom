//
//  StandardCollectionCard.swift
//  Heirloom
//
//  Refactored: 2026-01-27 - Unified vertical card layout
//

import SwiftUI

struct StandardCollectionCard: View {
    let collection: RecipeCollection
    /// Optional callback when + affordance is tapped
    let onAddRecipeTap: (() -> Void)?

    init(collection: RecipeCollection, onAddRecipeTap: (() -> Void)? = nil) {
        self.collection = collection
        self.onAddRecipeTap = onAddRecipeTap
    }

    private var recipeCount: Int {
        collection.recipes?.count ?? 0
    }

    /// Get first 2 recipes for small thumbnail display
    private var recipeImages: [Recipe] {
        let recipes = collection.recipes ?? []
        return Array(recipes.prefix(2))
    }

    /// Check if large slot is using a recipe image (not AI/custom background)
    private var isLargeSlotUsingRecipeImage: Bool {
        // If custom background is enabled AND we have a background image, large slot uses that, not recipe
        if collection.useCustomBackground &&
           (collection.generatedBackgroundImagePath != nil || collection.customBackgroundImagePath != nil) {
            return false
        }
        // Otherwise, if we have a recipe with image, large slot uses it
        return recipeImages.first?.imageFileName != nil || recipeImages.first?.firebaseImageURL != nil
    }

    /// Get recipes for small slots (excluding the one used in large slot if applicable)
    private var recipesForSmallSlots: [Recipe?] {
        if isLargeSlotUsingRecipeImage {
            // Large slot is using first recipe, so small slots get recipe 2 and 3 (or nil)
            let remainingRecipes = Array((collection.recipes ?? []).dropFirst())
            return [
                remainingRecipes.first,
                remainingRecipes.count > 1 ? remainingRecipes[1] : nil
            ]
        } else {
            // Large slot is using AI/custom/placeholder, so small slots get recipe 1 and 2
            return [
                recipeImages.first,
                recipeImages.count > 1 ? recipeImages[1] : nil
            ]
        }
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
                        recipeImageView(for: recipesForSmallSlots[0], isFirstSlot: true)
                        recipeImageView(for: recipesForSmallSlots[1], isFirstSlot: false)
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
        // Priority 1: AI-generated background (if enabled)
        if collection.useCustomBackground,
           let generatedPath = collection.generatedBackgroundImagePath {
            AsyncRecipeImage(
                imageFileName: generatedPath,
                firebaseImageURL: nil,
                placeholder: collection.iconName
            )
        }
        // Priority 2: Custom user-selected background (if enabled)
        else if collection.useCustomBackground,
                let customPath = collection.customBackgroundImagePath {
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
    private func recipeImageView(for recipe: Recipe?, isFirstSlot: Bool) -> some View {
        if let recipe = recipe,
           (recipe.imageFileName != nil || recipe.firebaseImageURL != nil) {
            AsyncRecipeImage(
                imageFileName: recipe.imageFileName,
                firebaseImageURL: recipe.firebaseImageURL,
                placeholder: collection.iconName
            )
        }
        // Show + affordance in appropriate empty slots
        // - First slot when collection has 1 recipe
        // - Second slot when collection has 2 recipes
        else if recipe == nil && ((isFirstSlot && recipeCount == 1) || (!isFirstSlot && recipeCount == 2)) {
            addRecipeAffordance
        }
        else {
            placeholderView
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var addRecipeAffordance: some View {
        let content = VStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.title)
                .foregroundStyle(HeirloomColors.tomato)

            Text("Add Recipe")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(HeirloomColors.primaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HeirloomColors.cream)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    HeirloomColors.tomato.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )
        )

        if let onAddRecipeTap = onAddRecipeTap {
            // Interactive affordance (when tap handler provided)
            Button {
                onAddRecipeTap()
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            // Non-interactive affordance (for preview/non-interactive contexts)
            content
        }
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
