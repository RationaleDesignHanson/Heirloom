//
//  ThemePacksSheet.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-25.
//  Theme pack browsing for Discovery tab - add themes individually
//

import SwiftUI
import SwiftData

/// Sheet for browsing and adding theme packs from the Discovery tab
/// Users can have max 3 active themes at once
struct ThemePacksSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RecipeTheme.sortOrder) private var themes: [RecipeTheme]

    @State private var isLoading = false
    @State private var addingThemeId: String?
    @State private var themeToConfirm: RecipeTheme?
    @State private var hasSyncedWithFirebase = false

    @AppStorage("hasSeenThemeCommitmentExplanation") private var hasSeenExplanation = false

    private let themeUnlockTracker: ThemeUnlockTracker
    private let maxActiveThemes = 3

    init() {
        self.themeUnlockTracker = ServiceContainer.shared.resolve(ThemeUnlockTracker.self)
    }

    /// Themes user has added (includes both in-progress and complete)
    private var addedThemes: [RecipeTheme] {
        themes.filter { $0.addedDate != nil }
    }

    /// Themes currently in progress (not yet complete)
    private var inProgressThemes: [RecipeTheme] {
        themes.filter { $0.isInProgress }
    }

    /// Themes that are complete (14+ days)
    private var completedThemes: [RecipeTheme] {
        themes.filter { $0.isComplete }
    }

    /// Count of in-progress themes (this is what counts toward limit)
    private var activeCount: Int {
        inProgressThemes.count
    }

    /// Whether user can add more themes (only in-progress count toward limit)
    private var canAddMore: Bool {
        activeCount < maxActiveThemes
    }

    /// Check if a specific theme has been added
    private func isAdded(_ theme: RecipeTheme) -> Bool {
        theme.addedDate != nil
    }

    /// Themes grouped by category
    private var groupedThemes: [(ThemeCategory, [RecipeTheme])] {
        let grouped = Dictionary(grouping: themes) { $0.category }
        return ThemeCategory.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { category in
                guard let themes = grouped[category], !themes.isEmpty else {
                    return nil
                }
                return (category, themes)
            }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status header
                statusHeader

                // Theme categories
                if themes.isEmpty {
                    loadingState
                } else {
                    themesScrollView
                }
            }
            .background(HeirloomColors.appBackground)
            .navigationTitle("Heritage Themes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadThemesIfNeeded()
            }
            .alert("How Theme Journeys Work", isPresented: Binding(
                get: { themeToConfirm != nil },
                set: { if !$0 { themeToConfirm = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    themeToConfirm = nil
                }
                Button("Got It") {
                    hasSeenExplanation = true
                    if let theme = themeToConfirm {
                        Task {
                            await addTheme(theme)
                        }
                    }
                    themeToConfirm = nil
                }
            } message: {
                Text("Each theme takes one of your 3 slots and delivers new recipes over 14 days. Once started, the slot stays filled until the journey completes.")
            }
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Progress indicator
            ZStack {
                Circle()
                    .stroke(HeirloomColors.warmGray.opacity(0.2), lineWidth: 4)
                    .frame(width: 48, height: 48)

                Circle()
                    .trim(from: 0, to: CGFloat(activeCount) / CGFloat(maxActiveThemes))
                    .stroke(HeirloomColors.tomato, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))

                Text("\(activeCount)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(activeCount) of \(maxActiveThemes) active")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                if completedThemes.count > 0 {
                    Text("\(completedThemes.count) complete • \(maxActiveThemes - activeCount) slots open")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.familyGreen)
                } else if canAddMore {
                    Text("Tap a theme to start a 14-day journey")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                } else {
                    Text("All slots in use • complete a journey to add more")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.tomato)
                }
            }

            Spacer()
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
    }

    // MARK: - Themes List

    private var themesScrollView: some View {
        ScrollView {
            LazyVStack(spacing: HeirloomSpacing.lg) {
                ForEach(groupedThemes, id: \.0) { category, categoryThemes in
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        // Section header
                        HStack(spacing: HeirloomSpacing.xs) {
                            Image(systemName: category.iconName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(HeirloomColors.tomato)

                            Text(category.displayName)
                                .font(HeirloomFonts.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(HeirloomColors.primaryText)
                        }
                        .padding(.horizontal, HeirloomSpacing.md)

                        // Horizontal scroll of theme cards
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: HeirloomSpacing.sm) {
                                ForEach(categoryThemes.sorted(by: { $0.sortOrder < $1.sortOrder })) { theme in
                                    themeCard(theme)
                                }
                            }
                            .padding(.horizontal, HeirloomSpacing.md)
                        }
                    }
                }
            }
            .padding(.vertical, HeirloomSpacing.md)
        }
    }

    // MARK: - Theme Card

    private func themeCard(_ theme: RecipeTheme) -> some View {
        let isAdding = addingThemeId == theme.firebaseId
        let themeIsAdded = isAdded(theme)
        let canAddTheme = canAddMore && !themeIsAdded

        return VStack(alignment: .leading, spacing: 0) {
            // Image area
            ZStack(alignment: .topTrailing) {
                // Background image
                if let urlString = theme.coverImageURL,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 160, height: 100)
                                .clipped()
                        case .failure, .empty:
                            placeholderImage(for: theme)
                        @unknown default:
                            placeholderImage(for: theme)
                        }
                    }
                } else {
                    placeholderImage(for: theme)
                }

                // Status badge
                if theme.isComplete {
                    Text("Complete")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(HeirloomColors.familyGreen)
                        .cornerRadius(4)
                        .padding(8)
                } else if theme.isInProgress {
                    Text("Day \(theme.currentDay)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(HeirloomColors.tomato)
                        .cornerRadius(4)
                        .padding(8)
                }
            }
            .frame(width: 160, height: 100)

            // Content area
            VStack(alignment: .leading, spacing: 6) {
                Text(theme.name)
                    .font(HeirloomFonts.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .lineLimit(1)

                // Status-specific subtitle
                if theme.isComplete {
                    Text("All \(theme.totalRecipes) recipes unlocked")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.familyGreen)
                } else if theme.isInProgress {
                    Text("\(theme.daysRemaining) days left")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.tomato)
                } else {
                    Text(theme.tagline)
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    // Recipe count (only for non-added themes)
                    if !themeIsAdded {
                        HStack(spacing: 3) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 10))
                            Text("\(theme.totalRecipes) recipes")
                                .font(HeirloomFonts.caption2)
                        }
                        .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    Spacer()

                    // Status indicator / Add button
                    if theme.isComplete {
                        Image(systemName: "star.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(HeirloomColors.familyGreen)
                    } else if theme.isInProgress {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(HeirloomColors.tomato)
                    } else {
                        Button {
                            if hasSeenExplanation {
                                Task { await addTheme(theme) }
                            } else {
                                themeToConfirm = theme
                            }
                        } label: {
                            if isAdding {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(canAddTheme ? HeirloomColors.tomato : HeirloomColors.warmGray)
                            }
                        }
                        .disabled(!canAddTheme || isAdding)
                    }
                }
            }
            .padding(HeirloomSpacing.sm)
        }
        .frame(width: 160)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
    }

    private func placeholderImage(for theme: RecipeTheme) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [HeirloomColors.warmGray.opacity(0.3), HeirloomColors.warmGray.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 160, height: 100)
            .overlay(
                Image(systemName: theme.iconName)
                    .font(.system(size: 32))
                    .foregroundStyle(HeirloomColors.warmGray.opacity(0.5))
            )
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: HeirloomSpacing.md) {
            Spacer()

            ProgressView()
                .scaleEffect(1.2)

            Text("Loading themes...")
                .font(HeirloomFonts.subheadline)
                .foregroundStyle(HeirloomColors.secondaryText)

            Spacer()
        }
    }

    // MARK: - Actions

    private func loadThemesIfNeeded() async {
        // CRITICAL: First sync theme selections with Firebase
        // This clears stale SwiftData selections if Firebase has no data for this user
        await syncThemeSelectionsWithFirebase()

        guard themes.isEmpty else { return }

        isLoading = true
        let themeLoader = ThemeLoader()
        do {
            _ = try await themeLoader.loadThemes(into: modelContext)
            Log.info("Loaded themes for Discovery", category: .onboarding)
        } catch {
            Log.error("Failed to load themes", category: .onboarding, error: error)
        }
        isLoading = false
    }

    /// Sync local theme selections with Firebase
    /// If Firebase has themeAddedDates, apply them. If not, clear all local selections.
    private func syncThemeSelectionsWithFirebase() async {
        // Only sync once per sheet presentation to avoid race conditions
        guard !hasSyncedWithFirebase else { return }
        hasSyncedWithFirebase = true

        guard let profileService = ServiceContainer.shared.resolveOptional(FirebaseUserProfileService.self) else {
            return
        }

        // Fetch current theme data from Firebase
        let firebaseThemeDates = await profileService.fetchThemeAddedDatesFromFirebase()

        // Get all themes from SwiftData
        let allThemes = themes

        if firebaseThemeDates.isEmpty {
            // User has NO theme selections in Firebase - clear all local selections
            var clearedCount = 0
            for theme in allThemes {
                if theme.addedDate != nil || theme.isSelected {
                    theme.addedDate = nil
                    theme.isSelected = false
                    clearedCount += 1
                }
            }
            if clearedCount > 0 {
                try? modelContext.save()
                Log.info("Cleared stale theme selections (Firebase has no data)", category: .theme, metadata: [
                    "clearedCount": clearedCount
                ])
            }
        } else {
            // User HAS theme selections in Firebase - sync them
            var updatedCount = 0
            for theme in allThemes {
                if let addedDate = firebaseThemeDates[theme.firebaseId] {
                    // Theme is in Firebase - apply the date
                    if theme.addedDate != addedDate {
                        theme.addedDate = addedDate
                        theme.isSelected = true
                        updatedCount += 1
                    }
                } else {
                    // Theme is NOT in Firebase - clear local selection
                    if theme.addedDate != nil || theme.isSelected {
                        theme.addedDate = nil
                        theme.isSelected = false
                        updatedCount += 1
                    }
                }
            }
            if updatedCount > 0 {
                try? modelContext.save()
                Log.info("Synced theme selections with Firebase", category: .theme, metadata: [
                    "updatedCount": updatedCount,
                    "firebaseThemes": firebaseThemeDates.keys.joined(separator: ", ")
                ])
            }
        }
    }

    private func addTheme(_ theme: RecipeTheme) async {
        guard canAddMore else { return }

        addingThemeId = theme.firebaseId

        // Set the add date (this starts the 14-day clock for THIS theme)
        let addedDate = Date()
        theme.addedDate = addedDate
        theme.isSelected = true
        try? modelContext.save()

        // Sync to Firebase for cross-device persistence
        if let profileService = ServiceContainer.shared.resolveOptional(FirebaseUserProfileService.self) {
            try? await profileService.syncThemeAddedDate(themeId: theme.firebaseId, addedDate: addedDate)
        }

        // Also update legacy tracker for backward compatibility
        var currentIds = themeUnlockTracker.selectedThemeIds
        if !currentIds.contains(theme.firebaseId) {
            currentIds.append(theme.firebaseId)
            themeUnlockTracker.selectedThemeIds = currentIds
        }

        // Create collection for this theme
        await createCollectionForTheme(theme)

        // Download recipes for this theme
        await downloadRecipesForTheme(theme)

        addingThemeId = nil

        // Show success toast
        let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
        toastManager.success(
            title: "Journey Started!",
            message: "\(theme.name) — Day 1 recipes are ready"
        )

        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func createCollectionForTheme(_ theme: RecipeTheme) async {
        // Check if collection already exists
        let themeName = theme.name
        let collectionDescriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate<RecipeCollection> { collection in
                collection.name == themeName && collection.collectionType == "theme"
            }
        )

        if let existing = try? modelContext.fetch(collectionDescriptor).first {
            // Link existing collection to theme
            existing.sourceTheme = theme
            existing.sourceThemeId = theme.firebaseId
            theme.collection = existing
            Log.info("Linked existing theme collection", category: .onboarding, metadata: ["theme": themeName])
        } else {
            // Create new collection
            let collection = RecipeCollection(
                name: theme.name,
                description: theme.tagline,
                collectionType: .theme
            )
            collection.sourceTheme = theme
            collection.sourceThemeId = theme.firebaseId
            collection.iconName = theme.iconName

            // Use theme cover image as collection background
            if let coverURL = theme.coverImageURL {
                collection.generatedBackgroundImagePath = coverURL
                collection.useCustomBackground = true
            }

            theme.collection = collection
            modelContext.insert(collection)

            Log.info("Created theme collection", category: .onboarding, metadata: [
                "theme": themeName,
                "collection": collection.name
            ])
        }

        try? modelContext.save()
    }

    private func downloadRecipesForTheme(_ theme: RecipeTheme) async {
        let recipeService = ThemeRecipeService()
        do {
            let recipes = try await recipeService.downloadRecipesForTheme(
                themeId: theme.firebaseId,
                into: modelContext
            )
            Log.info("Downloaded \(recipes.count) recipes for theme \(theme.name)", category: .onboarding)
        } catch {
            Log.error("Failed to download recipes for theme \(theme.name)", category: .onboarding, error: error)
        }
    }
}

// MARK: - Preview

#Preview {
    ThemePacksSheet()
        .modelContainer(for: [RecipeTheme.self, RecipeCollection.self], inMemory: true)
}
