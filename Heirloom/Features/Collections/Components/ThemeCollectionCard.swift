//
//  ThemeCollectionCard.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import SwiftUI
import SwiftData

struct ThemeCollectionCard: View {
    let collection: RecipeCollection
    let currentDay: Int
    let unlockTracker: ThemeUnlockTracker
    let allRecipes: [Recipe]
    let allThemes: [RecipeTheme]

    private var theme: RecipeTheme? {
        guard let themeId = collection.sourceThemeId else { return nil }
        return allThemes.first { $0.firebaseId == themeId }
    }

    private var themeRecipes: [Recipe] {
        // Get recipes for this theme by sourceThemeId (avoid accessing collection.recipes relationship)
        guard let themeId = collection.sourceThemeId else { return [] }
        return allRecipes.filter { $0.sourceThemeId == themeId }
    }

    private var recipeImages: [Recipe] {
        // Get first 2 unlocked recipes for display (we only show 2 small images now)
        let unlockedRecipes = themeRecipes.filter { unlockTracker.isUnlocked($0) }
        return Array(unlockedRecipes.prefix(2))
    }

    private var unlockProgress: (unlocked: Int, total: Int) {
        // Count unlocked recipes vs total recipes
        let unlocked = themeRecipes.filter { unlockTracker.isUnlocked($0) }.count
        let total = themeRecipes.count
        return (unlocked, total)
    }

    private var isComplete: Bool {
        unlockProgress.unlocked >= unlockProgress.total
    }

    private var subtitleText: String {
        let progress = unlockProgress
        if progress.unlocked < progress.total {
            return "\(progress.unlocked) of \(progress.total) recipes unlocked"
        } else {
            return "All \(progress.total) recipes unlocked"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Image collage (60/40 split)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    // Large image (60%) - Theme cover image
                    themeImageView
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
            .overlay(alignment: .topTrailing) {
                // Status badge
                statusBadge
                    .padding(HeirloomSpacing.sm)
            }

            // Info bar
            HStack(spacing: 8) {
                // Name and unlock progress inline
                HStack(spacing: 8) {
                    Text(collection.name)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(.white)

                    Text(subtitleText)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                // Progress indicator
                if !isComplete {
                    VStack(spacing: 4) {
                        Text("\(unlockProgress.unlocked)/\(unlockProgress.total)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white.opacity(0.3))
                                    .frame(height: 4)

                                // Progress
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white)
                                    .frame(
                                        width: geometry.size.width * (Double(unlockProgress.unlocked) / Double(max(unlockProgress.total, 1))),
                                        height: 4
                                    )
                            }
                        }
                        .frame(height: 4)
                    }
                    .frame(width: 60)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, HeirloomSpacing.md)
            .padding(.vertical, 8)
        }
        .background(HeirloomColors.themeTan)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(HeirloomColors.familyGreen.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var themeImageView: some View {
        if let theme = theme,
           let coverImageURL = theme.coverImageURL,
           let url = URL(string: coverImageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    placeholderView
                @unknown default:
                    placeholderView
                }
            }
        } else {
            placeholderView
        }
    }

    @ViewBuilder
    private func recipeImageView(for recipe: Recipe?) -> some View {
        if let recipe = recipe,
           (recipe.imageFileName != nil || recipe.firebaseImageURL != nil) {
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
