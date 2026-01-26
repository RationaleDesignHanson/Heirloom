//
//  ThemeCollectionCard.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import SwiftUI

struct ThemeCollectionCard: View {
    let collection: RecipeCollection
    let currentDay: Int

    private var theme: RecipeTheme? {
        collection.sourceTheme
    }

    private var recipeImages: [Recipe] {
        Array((collection.recipes ?? []).prefix(3))
    }

    private var unlockProgress: (unlocked: Int, total: Int) {
        let unlocked = collection.recipes?.count ?? 0
        let total = theme?.totalRecipes ?? unlocked
        return (unlocked, total)
    }

    private var isComplete: Bool {
        unlockProgress.unlocked >= unlockProgress.total
    }

    var body: some View {
        VStack(spacing: 0) {
            // Image collage (60/40 split)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    // Large image (60%)
                    recipeImageView(for: recipeImages.first)
                        .frame(width: geo.size.width * 0.6)

                    // Stacked small images (40%)
                    VStack(spacing: 2) {
                        recipeImageView(for: recipeImages.count > 1 ? recipeImages[1] : nil)
                        recipeImageView(for: recipeImages.count > 2 ? recipeImages[2] : nil)
                    }
                    .frame(width: geo.size.width * 0.4 - 2)
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .topTrailing) {
                // Status badge
                statusBadge
                    .padding(HeirloomSpacing.sm)
            }

            // Info bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.name)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text(collection.subtitleText)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Spacer()

                // Progress indicator
                if !isComplete {
                    CircularProgressView(
                        progress: Double(unlockProgress.unlocked) / Double(max(unlockProgress.total, 1)),
                        lineWidth: 3
                    )
                    .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(HeirloomColors.familyGreen)
                }
            }
            .padding(.horizontal, HeirloomSpacing.md)
            .padding(.vertical, HeirloomSpacing.sm)
        }
        .background(HeirloomColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func recipeImageView(for recipe: Recipe?) -> some View {
        if let recipe = recipe,
           recipe.imageFileName != nil {
            AsyncRecipeImage(
                imageFileName: recipe.imageFileName,
                firebaseImageURL: recipe.firebaseImageURL,
                placeholder: collection.iconName
            )
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(HeirloomColors.warmGray.opacity(0.2))
            .overlay(
                Image(systemName: collection.iconName)
                    .font(.title2)
                    .foregroundStyle(HeirloomColors.warmGray.opacity(0.5))
            )
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isComplete {
            Text("Complete")
                .font(HeirloomFonts.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(HeirloomColors.familyGreen)
                .foregroundStyle(.white)
                .cornerRadius(6)
        } else {
            Text("Day \(currentDay)")
                .font(HeirloomFonts.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(HeirloomColors.amber)
                .foregroundStyle(.white)
                .cornerRadius(6)
        }
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(HeirloomColors.warmGray.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(HeirloomColors.tomato, style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round
                ))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
    }
}
