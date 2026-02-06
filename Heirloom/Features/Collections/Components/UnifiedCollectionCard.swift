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
    var totalRecipeCount: Int? = nil  // For "All Recipes" collection (overrides relationship count)
    var allRecipesForThumbnails: [Recipe]? = nil  // For "All Recipes" collection thumbnails
    var onViewInvitesTap: (() -> Void)? = nil  // For "From Friends" collection with few recipes
    var pendingInvitesCount: Int = 0  // Count of pending recipe invites

    @EnvironmentObject private var syncService: FirebaseSyncService
    @Environment(\.openURL) private var openURL

    enum CardVariant {
        case standard(onAddRecipeTap: (() -> Void)?)
        case themed(currentDay: Int, unlockTracker: ThemeUnlockTracker, allRecipes: [Recipe], allThemes: [RecipeTheme])
    }

    // MARK: - Computed Properties

    private var recipeCount: Int {
        // For "All Recipes" collection, use the passed total count
        if collection.isAllRecipes, let total = totalRecipeCount {
            return total
        }
        return collection.recipes?.count ?? 0
    }

    /// Get recipes for display (themed uses filtered recipes, standard uses all)
    private var displayRecipes: [Recipe] {
        switch variant {
        case .standard:
            // For "All Recipes", use the passed recipes
            if collection.isAllRecipes, let allRecipes = allRecipesForThumbnails {
                return allRecipes
            }
            return collection.recipes ?? []
        case .themed(_, let unlockTracker, let allRecipes, _):
            guard let themeId = collection.sourceThemeId else { return [] }
            return allRecipes.filter { $0.sourceThemeId == themeId && unlockTracker.isUnlocked($0) }
        }
    }

    /// Get 2 random recipes for small thumbnail display (for "All Recipes" we pick randomly)
    private var recipeImages: [Recipe] {
        if collection.isAllRecipes {
            // Pick 2 random recipes that have images for variety
            let recipesWithImages = displayRecipes.filter {
                $0.imageFileName != nil || $0.firebaseImageURL != nil
            }
            if recipesWithImages.count >= 2 {
                // Use a seeded shuffle based on date to get consistent "random" picks per day
                let seed = Calendar.current.component(.day, from: Date())
                var rng = SeededRandomNumberGenerator(seed: UInt64(seed))
                return Array(recipesWithImages.shuffled(using: &rng).prefix(2))
            }
            return Array(recipesWithImages.prefix(2))
        }
        return Array(displayRecipes.prefix(2))
    }

    /// Check if large slot is using a recipe image (standard only)
    private var isLargeSlotUsingRecipeImage: Bool {
        guard case .standard = variant else { return false }

        // "All Recipes" uses preset background, not recipe image
        if collection.isAllRecipes {
            return false
        }

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
            // "All Recipes" always uses preset background, so small slots get the random picks
            if collection.isAllRecipes {
                return [
                    recipeImages.first,
                    recipeImages.count > 1 ? recipeImages[1] : nil
                ]
            }

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

    private var cardBackgroundColor: Color {
        switch variant {
        case .standard:
            return HeirloomColors.cardBackground
        case .themed:
            return HeirloomColors.themeTan
        }
    }

    private var cardBorderColor: Color {
        switch variant {
        case .standard:
            return HeirloomColors.cardStroke
        case .themed:
            return HeirloomColors.familyGreen.opacity(0.2)
        }
    }

    private var cardBorderWidth: CGFloat {
        switch variant {
        case .standard:
            return 1
        case .themed:
            return 1
        }
    }

    private var textColor: Color {
        switch variant {
        case .standard:
            return HeirloomColors.primaryText
        case .themed:
            return Color(red: 0.4, green: 0.26, blue: 0.13) // Dark brown
        }
    }

    private var subtitleColor: Color {
        switch variant {
        case .standard:
            return HeirloomColors.secondaryText
        case .themed:
            return Color(red: 0.4, green: 0.26, blue: 0.13).opacity(0.8) // Dark brown with opacity
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Image area - full width for "All Recipes", 60/40 split for others
            if collection.isAllRecipes {
                // Full-width single image for "All Recipes"
                allRecipesImageView
                    .frame(height: 180)
                    // Use top corners matching card radius (20), bottom corners 0 since info bar is below
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 20, style: .continuous))
            } else {
                // Standard 60/40 split collage
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        // Large image (60%)
                        largeImageView
                            .frame(width: geo.size.width * 0.6)
                            .clipped()

                        // Stacked small images (40%)
                        VStack(spacing: 2) {
                            recipeImageView(for: recipesForSmallSlots[0], isFirstSlot: true)
                            recipeImageView(for: recipesForSmallSlots[1], isFirstSlot: false)
                        }
                        .frame(width: geo.size.width * 0.4 - 2)
                    }
                }
                .frame(height: 180)
                // Use top corners matching card radius (20), bottom corners 0 since info bar is below
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 20, style: .continuous))
                .overlay(alignment: .topLeading) {
                    // NEW badge (when collection has new recipes)
                    if collection.hasNewRecipes {
                        newBadge
                            .padding(HeirloomSpacing.sm)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    // Status badge (themed only)
                    if case .themed = variant {
                        statusBadge
                            .padding(HeirloomSpacing.sm)
                    }
                }
            }

            // Info bar
            infoBar
        }
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(cardBorderColor, lineWidth: cardBorderWidth)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    // MARK: - All Recipes Full-Width Image

    @ViewBuilder
    private var allRecipesImageView: some View {
        // Use preset background image if available, otherwise use placeholder
        if let presetPath = collection.customBackgroundImagePath {
            AsyncRecipeImage(
                imageFileName: presetPath,
                firebaseImageURL: nil,
                placeholder: "book.closed.fill"
            )
        } else {
            allRecipesPlaceholderView
        }
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
        // Exception: Collections with preset backgrounds should show the preset instead
        let hasPresetBackground = collection.customBackgroundImagePath?.hasPrefix("preset-") == true
        if recipeImages.isEmpty,
           case .standard(let onAddRecipeTap) = variant,
           onAddRecipeTap != nil,
           !collection.isAllRecipes,
           !hasPresetBackground {
            emptyCollectionAffordance
        }
        // Priority 0.5: "All Recipes" preset background
        else if collection.isAllRecipes {
            // Use preset background image if available, otherwise use icon placeholder
            if let presetPath = collection.customBackgroundImagePath {
                AsyncRecipeImage(
                    imageFileName: presetPath,
                    firebaseImageURL: nil,
                    placeholder: "book.closed.fill"
                )
            } else {
                allRecipesPlaceholderView
            }
        }
        // Priority 1: Cookbook cover image (for cookbook collections)
        else if let coverPath = collection.cookbookCoverImagePath {
            AsyncRecipeImage(
                imageFileName: coverPath,
                firebaseImageURL: nil,
                placeholder: collection.iconName
            )
        }
        // Priority 2: AI-generated background (if enabled)
        else if collection.useCustomBackground,
                let generatedPath = collection.generatedBackgroundImagePath {
            AsyncRecipeImage(
                imageFileName: generatedPath,
                firebaseImageURL: nil,
                placeholder: collection.iconName
            )
        }
        // Priority 3: Custom user-selected background (if enabled)
        else if collection.useCustomBackground,
                let customPath = collection.customBackgroundImagePath {
            AsyncRecipeImage(
                imageFileName: customPath,
                firebaseImageURL: nil,
                placeholder: collection.iconName
            )
        }
        // Priority 4: First recipe's image (as fallback)
        else if let firstRecipe = recipeImages.first,
                (firstRecipe.imageFileName != nil || firstRecipe.firebaseImageURL != nil) {
            AsyncRecipeImage(
                imageFileName: firstRecipe.imageFileName,
                firebaseImageURL: firstRecipe.firebaseImageURL,
                placeholder: collection.iconName
            )
        }
        // Priority 5: Placeholder
        else {
            placeholderView
        }
    }

    /// Placeholder view specifically for "All Recipes" collection
    private var allRecipesPlaceholderView: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        HeirloomColors.familyGreen.opacity(0.3),
                        HeirloomColors.familyGreen.opacity(0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("All Recipes")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(.white.opacity(0.7))
                }
            )
    }

    @ViewBuilder
    private var themedLargeImageView: some View {
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
        // Priority 3: Theme cover image (fallback)
        else if let theme = theme,
                let coverImageURL = theme.coverImageURL,
                let url = URL(string: coverImageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                case .failure, .empty:
                    placeholderView
                @unknown default:
                    placeholderView
                }
            }
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
        // For "From Friends" collection with few recipes: show "View Invites" affordance
        else if collection.type == .fromFriends,
                !isFirstSlot,
                onViewInvitesTap != nil,
                case .standard = variant {
            viewInvitesAffordance
        }
        // Show + affordance in ANY empty slot (standard only)
        // This allows users to add recipes directly from the collection card
        else if case .standard(let onAddRecipeTap) = variant,
                recipe == nil,
                onAddRecipeTap != nil {
            addRecipeAffordance(onTap: onAddRecipeTap)
        }
        else {
            placeholderView
        }
    }

    // MARK: - Info Bar

    @ViewBuilder
    private var infoBar: some View {
        let verticalPadding: CGFloat = {
            switch variant {
            case .themed: return 8
            case .standard: return HeirloomSpacing.sm
            }
        }()

        HStack(spacing: 8) {
            // For themed: title left, progress right, for standard: stacked layout
            if case .themed = variant {
                // Title on left
                MarqueeText(text: displayName, font: HeirloomFonts.bodyBold, foregroundColor: textColor)

                Spacer()

                // Unlock progress right-aligned (before badge)
                Text(subtitleText)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(subtitleColor)
                    .lineLimit(1)
            } else {
                // Stacked layout for standard cards
                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(text: displayName, font: HeirloomFonts.bodyBold, foregroundColor: textColor)

                    if isSubtitleTappable {
                        // Tappable subtitle for cookbook collections - opens web search
                        Button {
                            openCookbookSearch()
                        } label: {
                            HStack(spacing: 4) {
                                Text(subtitleText)
                                    .font(HeirloomFonts.caption1)
                                    .foregroundStyle(HeirloomColors.familyGreen)
                                    .lineLimit(1)

                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(HeirloomColors.familyGreen.opacity(0.7))
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(subtitleText)
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(subtitleColor)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            // Variant-specific badge
            infoBadge
        }
        .padding(.horizontal, HeirloomSpacing.md)
        .padding(.vertical, verticalPadding)
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
            // For "All Recipes", use the total count from parameter
            if collection.isAllRecipes, let total = totalRecipeCount {
                if total == 0 {
                    return "No recipes yet"
                } else if total == 1 {
                    return "1 recipe"
                } else {
                    return "\(total) recipes"
                }
            }
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

    /// Whether the subtitle is tappable (for cookbook collections with source info)
    private var isSubtitleTappable: Bool {
        guard case .standard = variant,
              collection.type == .cookbook else { return false }
        return collection.sourceAuthor != nil || collection.sourceCookbook != nil
    }

    /// Search URL for the cookbook (opens in browser)
    private var cookbookSearchURL: URL? {
        guard collection.type == .cookbook else { return nil }

        var searchQuery = ""
        if let cookbook = collection.sourceCookbook {
            searchQuery = cookbook
            if let author = collection.sourceAuthor {
                searchQuery += " by \(author)"
            }
        }

        guard !searchQuery.isEmpty else { return nil }

        let encoded = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchQuery
        return URL(string: "https://www.google.com/search?q=\(encoded)+cookbook")
    }

    /// Open cookbook search in browser
    private func openCookbookSearch() {
        guard let url = cookbookSearchURL else { return }
        openURL(url)
    }

    @ViewBuilder
    private var infoBadge: some View {
        switch variant {
        case .standard:
            // Recipe count badge with loading indicator
            HStack(spacing: 4) {
                // Show loading spinner if collection is syncing
                if syncService.loadingCollectionIds.contains(collection.id) {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "doc.text")
                        .font(.caption)
                }

                Text("\(recipeCount)")
                    .font(HeirloomFonts.caption1)

                // Show progress fraction if loading
                if let progress = syncService.syncProgress[collection.id] {
                    Text("/\(progress.totalRecipes)")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText.opacity(0.7))
                }
            }
            .foregroundStyle(HeirloomColors.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(HeirloomColors.warmGray.opacity(0.1))
            .cornerRadius(8)

        case .themed:
            // Just show checkmark when complete, nothing when in progress
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.4, green: 0.26, blue: 0.13)) // Dark brown
            }
        }
    }

    // MARK: - Subviews

    private var smallAffordanceText: String {
        switch collection.type {
        case .webImports:
            return "Import"
        case .videoImports:
            return "Video"
        case .cookbook:
            return "Scan"
        case .photoImports:
            return "Photos"
        default:
            return "Add"
        }
    }

    @ViewBuilder
    private func addRecipeAffordance(onTap: (() -> Void)?) -> some View {
        let affordanceContent = Rectangle()
            .fill(HeirloomColors.warmGray.opacity(0.1))
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(HeirloomColors.tomato)

                    Text(smallAffordanceText)
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

    /// Affordance for "From Friends" collection to view recipe invites
    @ViewBuilder
    private var viewInvitesAffordance: some View {
        let hasInvites = pendingInvitesCount > 0

        let affordanceContent = Rectangle()
            .fill(hasInvites ? HeirloomColors.familyGreen.opacity(0.1) : HeirloomColors.warmGray.opacity(0.1))
            .overlay(
                VStack(spacing: 4) {
                    ZStack {
                        Image(systemName: "tray.full")
                            .font(.title3)
                            .foregroundStyle(hasInvites ? HeirloomColors.familyGreen : HeirloomColors.warmGray)

                        // Badge for pending invites
                        if pendingInvitesCount > 0 {
                            Text("\(pendingInvitesCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(HeirloomColors.tomato)
                                .clipShape(Capsule())
                                .offset(x: 12, y: -10)
                        }
                    }

                    Text(hasInvites ? "Invites" : "Inbox")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(hasInvites ? HeirloomColors.familyGreen : HeirloomColors.secondaryText)
                }
            )

        if let onTap = onViewInvitesTap {
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
    /// NEW badge for collections with unviewed recipes
    private var newBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkle")
                .font(.system(size: 10, weight: .semibold))

            Text("NEW")
                .font(HeirloomFonts.caption2)
                .fontWeight(.semibold)

            if collection.newRecipeCount > 1 {
                Text("(\(collection.newRecipeCount))")
                    .font(HeirloomFonts.caption2)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(HeirloomColors.tomato)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
    }

    private var statusBadge: some View {
        Group {
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

// MARK: - Marquee Text

/// A text view that auto-scrolls horizontally when the text is wider than the container.
/// Starts scrolling after a delay when visible in the middle third of the screen.
struct MarqueeText: View {
    let text: String
    let font: Font
    let foregroundColor: Color

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var isAnimating = false
    @State private var isInMiddleThird = false
    @State private var delayTask: Task<Void, Never>?

    private var overflow: CGFloat {
        max(0, textWidth - containerWidth)
    }

    private var shouldAnimate: Bool {
        overflow > 0
    }

    var body: some View {
        GeometryReader { outerGeo in
            let midY = outerGeo.frame(in: .global).midY
            let screenHeight = UIScreen.main.bounds.height
            let topThreshold = screenHeight / 3
            let bottomThreshold = screenHeight * 2 / 3

            Text(text)
                .font(font)
                .foregroundStyle(foregroundColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    GeometryReader { textGeo in
                        Color.clear
                            .onAppear {
                                textWidth = textGeo.size.width
                            }
                    }
                )
                .offset(x: offset)
                .onAppear {
                    containerWidth = outerGeo.size.width
                }
                .onChange(of: outerGeo.size.width) { _, newWidth in
                    containerWidth = newWidth
                }
                .onChange(of: midY) { _, newMidY in
                    let nowInMiddle = newMidY >= topThreshold && newMidY <= bottomThreshold
                    if nowInMiddle != isInMiddleThird {
                        isInMiddleThird = nowInMiddle
                        if nowInMiddle && shouldAnimate {
                            startDelayedAnimation()
                        } else {
                            stopAnimation()
                        }
                    }
                }
        }
        .frame(height: UIFont.preferredFont(forTextStyle: .body).lineHeight)
        .clipped()
    }

    private func startDelayedAnimation() {
        delayTask?.cancel()
        delayTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, isInMiddleThird, shouldAnimate else { return }
            isAnimating = true
            animateCycle()
        }
    }

    private func stopAnimation() {
        delayTask?.cancel()
        isAnimating = false
        withAnimation(.easeOut(duration: 0.3)) {
            offset = 0
        }
    }

    private func animateCycle() {
        guard isAnimating, shouldAnimate else { return }
        // Scroll left
        withAnimation(.linear(duration: Double(overflow) / 30.0)) {
            offset = -overflow
        }
        // Wait, then scroll back
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Double(overflow) / 30.0 + 1.5))
            guard isAnimating else { return }
            withAnimation(.linear(duration: Double(overflow) / 30.0)) {
                offset = 0
            }
            try? await Task.sleep(for: .seconds(Double(overflow) / 30.0 + 1.0))
            guard isAnimating else { return }
            animateCycle()
        }
    }
}

// MARK: - Seeded Random Number Generator

/// Simple seeded RNG for consistent "random" picks per day
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // Simple xorshift algorithm
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
