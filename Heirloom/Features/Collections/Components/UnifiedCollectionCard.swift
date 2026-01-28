//
//  UnifiedCollectionCard.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-27.
//  Phase 5: Unified collection card component with variant support
//

import SwiftUI
import SwiftData

struct UnifiedCollectionCard: View {
    let collection: RecipeCollection
    let variant: CardVariant

    enum CardVariant {
        case standard(onAddRecipeTap: (() -> Void)?)
        case themed(currentDay: Int, unlockTracker: ThemeUnlockTracker, allRecipes: [Recipe], allThemes: [RecipeTheme])
    }

    // MARK: - Computed Properties

    private var recipeCount: Int {
        collection.recipes?.count ?? 0
    }

    /// Get recipes for display (themed uses filtered recipes, standard uses all)
    private var displayRecipes: [Recipe] {
        switch variant {
        case .standard:
            return collection.recipes ?? []
        case .themed(_, let unlockTracker, let allRecipes, _):
            guard let themeId = collection.sourceThemeId else { return [] }
            return allRecipes.filter { $0.sourceThemeId == themeId && unlockTracker.isUnlocked($0) }
        }
    }

    /// Get first 2 recipes for small thumbnail display
    private var recipeImages: [Recipe] {
        Array(displayRecipes.prefix(2))
    }

    /// Check if large slot is using a recipe image (standard only)
    private var isLargeSlotUsingRecipeImage: Bool {
        guard case .standard = variant else { return false }

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
        switch variant {
        case .standard:
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
        case .themed:
            // Themed: small slots always get first 2 recipes
            return [
                recipeImages.first,
                recipeImages.count > 1 ? recipeImages[1] : nil
            ]
        }
    }

    private var theme: RecipeTheme? {
        guard case .themed(_, _, _, let allThemes) = variant,
              let themeId = collection.sourceThemeId else { return nil }
        return allThemes.first { $0.firebaseId == themeId }
    }

    private var unlockProgress: (unlocked: Int, total: Int)? {
        guard case .themed(_, let unlockTracker, let allRecipes, _) = variant,
              let themeId = collection.sourceThemeId else { return nil }

        let themeRecipes = allRecipes.filter { $0.sourceThemeId == themeId }
        let unlocked = themeRecipes.filter { unlockTracker.isUnlocked($0) }.count
        return (unlocked, themeRecipes.count)
    }

    private var isComplete: Bool {
        guard let progress = unlockProgress else { return false }
        return progress.unlocked >= progress.total
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Image collage (60/40 split)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    // Large image (60%)
                    largeImageView
                        .frame(width: geo.size.width * 0.6)

                    // Stacked small images (40%)
                    VStack(spacing: 2) {
                        recipeImageView(for: recipesForSmallSlots[0], isFirstSlot: true)
                        recipeImageView(for: recipesForSmallSlots[1], isFirstSlot: false)
                    }
                    .frame(width: geo.size.width * 0.4 - 2)
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .topTrailing) {
                // Status badge (themed only)
                if case .themed = variant {
                    statusBadge
                        .padding(HeirloomSpacing.sm)
                }
            }

            // Info bar
            infoBar
        }
        .background(HeirloomColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    // MARK: - Large Image View

    @ViewBuilder
    private var largeImageView: some View {
        switch variant {
        case .standard:
            standardLargeImageView
        case .themed:
            themedLargeImageView
        }
    }

    @ViewBuilder
    private var standardLargeImageView: some View {
        // Priority 0: Empty collection affordance (if collection is empty and interactive)
        if recipeImages.isEmpty,
           case .standard(let onAddRecipeTap) = variant,
           onAddRecipeTap != nil {
            emptyCollectionAffordance
        }
        // Priority 1: AI-generated background (if enabled)
        else if collection.useCustomBackground,
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

    @ViewBuilder
    private var themedLargeImageView: some View {
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
        // Show + affordance in first empty slot when collection has exactly 1 recipe (standard only)
        else if case .standard(let onAddRecipeTap) = variant,
                recipeCount == 1 && recipe == nil && isFirstSlot {
            addRecipeAffordance(onTap: onAddRecipeTap)
        }
        else {
            placeholderView
        }
    }

    // MARK: - Info Bar

    private var infoBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .lineLimit(1)

                Text(subtitleText)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            // Variant-specific badge
            infoBadge
        }
        .padding(.horizontal, HeirloomSpacing.md)
        .padding(.vertical, HeirloomSpacing.sm)
    }

    private var displayName: String {
        switch variant {
        case .standard:
            return collection.displayName
        case .themed:
            return collection.name
        }
    }

    private var subtitleText: String {
        switch variant {
        case .standard:
            return collection.subtitleText
        case .themed:
            guard let progress = unlockProgress else { return "" }
            if progress.unlocked < progress.total {
                return "\(progress.unlocked) of \(progress.total) recipes unlocked"
            } else {
                return "All \(progress.total) recipes unlocked"
            }
        }
    }

    @ViewBuilder
    private var infoBadge: some View {
        switch variant {
        case .standard:
            // Recipe count badge
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

        case .themed:
            // Progress indicator or checkmark
            if !isComplete, let progress = unlockProgress {
                CircularProgressView(
                    progress: Double(progress.unlocked) / Double(max(progress.total, 1)),
                    lineWidth: 3
                )
                .frame(width: 32, height: 32)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(HeirloomColors.familyGreen)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func addRecipeAffordance(onTap: (() -> Void)?) -> some View {
        let affordanceContent = Rectangle()
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

        if let onTap = onTap {
            Button(action: onTap) {
                affordanceContent
            }
            .buttonStyle(.plain)
        } else {
            affordanceContent
        }
    }

    @ViewBuilder
    private var emptyCollectionAffordance: some View {
        if case .standard(let onAddRecipeTap) = variant {
            let affordanceContent = Rectangle()
                .fill(HeirloomColors.warmGray.opacity(0.05))
                .overlay(
                    VStack(spacing: HeirloomSpacing.md) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(HeirloomColors.tomato)

                        VStack(spacing: 4) {
                            Text("Add Your First Recipe")
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(HeirloomColors.primaryText)

                            Text(emptyAffordanceSubtitle)
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(HeirloomSpacing.lg)
                )

            if let onTap = onAddRecipeTap {
                Button(action: onTap) {
                    affordanceContent
                }
                .buttonStyle(.plain)
            } else {
                affordanceContent
            }
        }
    }

    private var emptyAffordanceSubtitle: String {
        switch collection.type {
        case .webImports:
            return "Tap to import from a website"
        case .videoImports:
            return "Tap to import from a video"
        case .cookbook:
            return "Tap to scan a cookbook page"
        case .photoImports:
            return "Tap to import from photos"
        default:
            return "Tap to add a recipe"
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if case .themed(let currentDay, _, _, _) = variant {
            if isComplete {
                Text("Complete")
                    .font(HeirloomFonts.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(HeirloomColors.familyGreen)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Text("Day \(currentDay)")
                    .font(HeirloomFonts.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(HeirloomColors.amber)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
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
