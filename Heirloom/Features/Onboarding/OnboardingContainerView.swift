//
//  OnboardingContainerView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-08.
//

import SwiftUI
import SwiftData

/// Container view that manages the 3-screen onboarding flow
struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.firebaseAuth) private var firebaseAuth
    @EnvironmentObject private var notificationService: FirebaseNotificationService
    @EnvironmentObject private var themeUnlockTracker: ThemeUnlockTracker
    @State private var currentScreen: OnboardingScreen = .videoHero
    @State private var hasSeededHeritage = false
    @State private var selectedThemeIds: [String] = []

    /// Binding to control which tab should be selected after onboarding
    @Binding var selectedTab: Int

    /// Callback when onboarding is completed
    var onComplete: () -> Void

    enum OnboardingScreen {
        case videoHero
        case shareExtension
        case flexibility
        case organization
        case themeSelection // NEW: Theme selection
        case subscription
    }

    var body: some View {
        NavigationStack {
            switch currentScreen {
            case .videoHero:
                OnboardingVideoHeroScreen {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = .shareExtension
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .shareExtension:
                OnboardingShareExtensionScreen {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = .flexibility
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .flexibility:
                OnboardingFlexibilityScreen {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = .organization
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .organization:
                OnboardingOrganizationScreen {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = .themeSelection
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .themeSelection:
                ThemeSelectionScreen { themeIds in
                    handleThemeSelection(themeIds)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
                .task {
                    await loadThemesIfNeeded()
                }

            case .subscription:
                OnboardingSubscriptionScreen(
                    onStartTrial: {
                        // User chose to start trial - complete onboarding
                        completeOnboarding()
                    },
                    onSkip: {
                        // User chose to continue free - complete onboarding
                        completeOnboarding()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            }
        }
        .task {
            // Seed heritage recipes if user is already authenticated
            // (e.g., returning user who went through sign-in before onboarding)
            await seedHeritageRecipesIfNeeded()
        }
        .onChange(of: firebaseAuth.isAuthenticated) { oldValue, newValue in
            // CRITICAL: Watch for auth changes during onboarding
            // Firebase Auth takes ~15 seconds to hydrate from Keychain
            // This ensures we seed heritage recipes even if auth becomes true
            // after the initial .task {} has finished
            if newValue && !hasSeededHeritage {
                Task {
                    await seedHeritageRecipesIfNeeded()
                }
            }
        }
    }

    // MARK: - Private Methods

    // MARK: - Theme Selection Handler

    private func handleThemeSelection(_ themeIds: [String]) {
        selectedThemeIds = themeIds

        // Start the trial
        themeUnlockTracker.startTrial(withThemeIds: themeIds)

        // Create collections for selected themes
        createThemeCollections(for: themeIds)

        // Download initial recipes
        Task {
            await downloadInitialRecipes(for: themeIds)
        }

        // Continue to subscription
        withAnimation(.easeInOut(duration: 0.3)) {
            currentScreen = .subscription
        }
    }

    // MARK: - Theme Loading

    private func loadThemesIfNeeded() async {
        let descriptor = FetchDescriptor<RecipeTheme>()
        let existingThemes = (try? modelContext.fetch(descriptor)) ?? []

        // Only load if we don't have themes
        if existingThemes.isEmpty {
            let loader = ThemeLoader()
            do {
                _ = try await loader.loadThemes(into: modelContext)
                Log.info("Loaded themes from Firebase", category: .onboarding)
            } catch {
                Log.error("Failed to load themes", category: .onboarding, error: error)
            }
        }
    }

    // MARK: - Collection Creation

    private func createThemeCollections(for themeIds: [String]) {
        let descriptor = FetchDescriptor<RecipeTheme>()
        guard let allThemes = try? modelContext.fetch(descriptor) else { return }

        let selectedThemes = allThemes.filter { themeIds.contains($0.firebaseId) }

        for theme in selectedThemes {
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
                theme.collection = existing
            } else {
                // Create new collection
                let collection = RecipeCollection(
                    name: theme.name,
                    iconName: theme.iconName,
                    collectionType: .theme
                )
                collection.sourceTheme = theme
                theme.collection = collection
                modelContext.insert(collection)
            }
        }

        do {
            try modelContext.save()
            Log.info("Created collections for \(selectedThemes.count) themes", category: .onboarding)
        } catch {
            Log.error("Failed to create theme collections", category: .onboarding, error: error)
        }
    }

    private func downloadInitialRecipes(for themeIds: [String]) async {
        do {
            Log.info("Downloading initial recipes for \(themeIds.count) themes", category: .onboarding)

            let recipeService = ThemeRecipeService()
            let recipes = try await recipeService.downloadRecipes(for: themeIds, into: modelContext)

            // Link recipes to their collections by fetching collections directly
            // (avoids SwiftData duplicate registration error from theme.collection relationship)
            for themeId in themeIds {
                let recipesForTheme = recipes.filter { $0.sourceThemeId == themeId }

                // Fetch collection directly by theme name and type
                let collectionDescriptor = FetchDescriptor<RecipeCollection>(
                    predicate: #Predicate<RecipeCollection> { collection in
                        collection.collectionType == "theme" &&
                        collection.sourceTheme?.firebaseId == themeId
                    }
                )

                guard let collection = try? modelContext.fetch(collectionDescriptor).first else {
                    Log.warning("Collection not found for theme", category: .onboarding, metadata: ["themeId": themeId])
                    continue
                }

                // Add recipes to collection
                for recipe in recipesForTheme {
                    if collection.recipes == nil {
                        collection.recipes = [recipe]
                    } else if !(collection.recipes?.contains(where: { $0.id == recipe.id }) ?? false) {
                        collection.recipes?.append(recipe)
                    }
                }
            }

            try modelContext.save()

            Log.info("Downloaded and linked \(recipes.count) recipes to collections", category: .onboarding)
        } catch {
            Log.error("Failed to download initial recipes", category: .onboarding, error: error)
        }
    }

    private func completeOnboarding() {
        // Mark onboarding as complete
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // Seed onboarding recipe
        let seeder = OnboardingRecipeSeeder(modelContext: modelContext)
        Task {
            do {
                try await seeder.seedOnboardingRecipe()
            } catch {
                Log.error("Failed to seed onboarding recipe", category: .storage, metadata: ["error": error.localizedDescription])
            }
        }

        // Navigate to Collections tab (now index 0 after removing Recipes tab)
        selectedTab = 0

        // Notify parent that onboarding is complete
        onComplete()
    }

    // TODO: Re-implement for theme system in Phase B2
    private func seedHeritageRecipesIfNeeded() async {
        // Prevent duplicate seeding
        // guard !hasSeededHeritage else {
        //     Log.info("Theme recipes already seeded in this onboarding session", category: .storage)
        //     return
        // }
        //
        // // Check if user is authenticated via FirebaseAuthService
        // guard let authService = ServiceContainer.shared.resolveOptional(FirebaseAuthService.self),
        //       authService.isAuthenticated else {
        //     Log.info("Not authenticated during onboarding - theme seeding will happen after sign-in", category: .storage)
        //     return
        // }
        //
        // do {
        //     // Theme collections will be created based on user selection during onboarding
        //     // No pre-seeding needed - themes are loaded from Firebase after user selects them
        //
        //     // Analytics tracking for theme setup during onboarding
        //     let analytics = ServiceContainer.shared.resolve(AnalyticsService.self)
        //     analytics.track(event: AnalyticsEvent.appLaunched, properties: ["theme_setup": "pending_selection"])
        //
        //     // Mark as complete to prevent duplicate attempts
        //     hasSeededHeritage = true
        // } catch {
        //     Log.error("Failed to setup theme collections during onboarding", category: .storage, metadata: ["error": error.localizedDescription])
        //     DeviceLogger.shared.log("❌ [Theme] Failed to setup collections during onboarding: \(error.localizedDescription)")
        // }
    }
}

// MARK: - Preview

#Preview {
    OnboardingContainerView(selectedTab: .constant(0), onComplete: {})
}
