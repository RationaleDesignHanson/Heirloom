//
//  OnboardingContainerView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-08.
//  Updated for new 5-screen onboarding flow on 2026-02-01
//

import SwiftUI
import SwiftData

/// Container view that manages the 5-screen onboarding flow
struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.firebaseAuth) private var firebaseAuth
    @EnvironmentObject private var notificationService: FirebaseNotificationService
    @EnvironmentObject private var themeUnlockTracker: ThemeUnlockTracker
    @EnvironmentObject private var tabCoordinator: TabNavigationCoordinator
    @State private var currentScreen: OnboardingScreen = .welcome
    @State private var hasSeededHeritage = false
    @State private var selectedThemeIds: [String] = []
    @State private var showThemeSelection = false

    /// Binding to control which tab should be selected after onboarding
    @Binding var selectedTab: Int

    /// Callback when onboarding is completed
    var onComplete: () -> Void

    enum OnboardingScreen {
        case welcome           // Screen 1: Recipe box vision
        case premiumTrial      // Screen 2: Early premium upsell
        case shareSheetAha     // Screen 3: One-tap save tutorial
        case shareAndAccept    // Screen 4: Intentional sharing model
        case discover          // Screen 5: Optional community
    }

    var body: some View {
        NavigationStack {
            switch currentScreen {
            case .welcome:
                OnboardingWelcomeScreen(
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentScreen = .premiumTrial
                        }
                    },
                    onSkip: {
                        // User chose to skip entire onboarding
                        completeOnboarding()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .premiumTrial:
                OnboardingSubscriptionScreen(
                    onStartTrial: {
                        // User started trial - continue to next screen
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentScreen = .shareSheetAha
                        }
                    },
                    onSkip: {
                        // User chose to continue free - continue to next screen
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentScreen = .shareSheetAha
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .shareSheetAha:
                OnboardingShareExtensionScreen {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = .shareAndAccept
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .shareAndAccept:
                OnboardingShareAndAcceptScreen {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = .discover
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .discover:
                OnboardingDiscoverScreen(
                    onStartSaving: {
                        // Complete onboarding and navigate to Collections tab
                        completeOnboarding()
                    },
                    onExploreDiscover: {
                        // Complete onboarding and navigate to Discover tab
                        selectedTab = 1 // Discover tab
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
        .sheet(isPresented: $showThemeSelection) {
            ThemeSelectionScreen { themeIds in
                handleThemeSelection(themeIds)
            }
            .task {
                await loadThemesIfNeeded()
            }
        }
    }

    // MARK: - Private Methods

    // MARK: - Theme Selection Handler

    private func handleThemeSelection(_ themeIds: [String]) {
        selectedThemeIds = themeIds

        // Only setup themes if user selected any
        if !themeIds.isEmpty {
            // Start the trial (if user has premium)
            themeUnlockTracker.startTrial(withThemeIds: themeIds)

            // Create collections for selected themes
            createThemeCollections(for: themeIds)

            // Download initial recipes
            Task {
                await downloadInitialRecipes(for: themeIds)
            }
        }

        // Close theme selection sheet
        showThemeSelection = false

        // Complete onboarding (theme selection was the final step after main flow)
        finalizeOnboarding()
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
                existing.sourceThemeId = theme.firebaseId
                theme.collection = existing
            } else {
                // Create new collection
                let collection = RecipeCollection(
                    name: theme.name,
                    iconName: theme.iconName,
                    collectionType: .theme
                )
                collection.sourceTheme = theme
                collection.sourceThemeId = theme.firebaseId
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

            // Recipes are downloaded with sourceThemeId - collections will find them via queries
            // No need to set the many-to-many relationship explicitly - SwiftData manages it

            try modelContext.save()

            Log.info("Downloaded \(recipes.count) recipes", category: .onboarding)
        } catch {
            Log.error("Failed to download initial recipes", category: .onboarding, error: error)
        }
    }

    private func completeOnboarding() {
        // Show theme selection sheet after main onboarding flow
        // User can select heritage themes or skip
        showThemeSelection = true
    }

    private func finalizeOnboarding() {
        // Mark onboarding as complete
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

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
