//
//  StandardCollectionCard.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import SwiftUI

struct StandardCollectionCard: View {
    let collection: RecipeCollection

    private var recipeCount: Int {
        collection.recipes?.count ?? 0
    }

    private var previewRecipe: Recipe? {
        collection.recipes?.first
    }

    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Thumbnail
            thumbnailView
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                // Collection type badge
                HStack(spacing: 4) {
                    Image(systemName: collection.type.defaultIconName)
                        .font(.system(size: 10))
                    Text(collection.type.displayName)
                        .font(HeirloomFonts.caption2)
                }
                .foregroundStyle(HeirloomColors.secondaryText)

                // Name
                Text(collection.name)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .lineLimit(1)

                // Subtitle
                Text(collection.subtitleText)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HeirloomColors.warmGray)
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        // Priority 1: Collection's custom or generated background
        if let bgPath = collection.customBackgroundImagePath ?? collection.generatedBackgroundImagePath {
            AsyncRecipeImage(
                imageFileName: bgPath,
                firebaseImageURL: nil,
                placeholder: collection.iconName
            )
        }
        // Priority 2: First recipe's image
        else if let recipe = previewRecipe,
                recipe.imageFileName != nil {
            AsyncRecipeImage(
                imageFileName: recipe.imageFileName,
                firebaseImageURL: recipe.firebaseImageURL,
                placeholder: collection.iconName
            )
        }
        // Priority 3: Placeholder
        else {
            placeholderView
        }
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
