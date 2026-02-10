//
//  OnboardingContainerView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-08.
//  Updated for new 6-screen onboarding flow on 2026-02-05
//

import SwiftUI
import SwiftData
import UIKit

/// Container view that manages the 6-screen onboarding flow
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
    @State private var pendingProfileData: OnboardingProfileData?

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
        case profileSetup      // Screen 6: Profile setup (display name + optional photo)
        case completing        // Final: Saving profile and finishing up
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
                        // Navigate to profile setup
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentScreen = .profileSetup
                        }
                    },
                    onExploreDiscover: {
                        // Navigate to Discover tab after profile setup
                        selectedTab = 1 // Discover tab
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentScreen = .profileSetup
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .profileSetup:
                OnboardingProfileSetupScreen(
                    onContinue: { profileData in
                        pendingProfileData = profileData
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentScreen = .completing
                        }
                        // Show theme selection after transitioning to completing screen
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showThemeSelection = true
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .completing:
                // Clean loading screen shown while theme selection sheet is presented
                // and while profile is being saved
                completingView
                    .transition(.opacity)
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

    // MARK: - Completing View

    private var completingView: some View {
        ZStack {
            // Background gradient (matching other onboarding screens)
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.95, blue: 0.90),
                    Color(red: 0.95, green: 0.90, blue: 0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(HeirloomColors.tomato)

                Text("Setting up your recipe box...")
                    .font(HeirloomFonts.body)
                    .foregroundColor(HeirloomColors.secondaryText)
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

            // Download initial recipes (fire and forget - can complete after onboarding)
            Task.detached {
                await self.downloadInitialRecipes(for: themeIds)
            }
        }

        // Close theme selection sheet
        showThemeSelection = false

        // Save profile and finalize onboarding
        // Must await profile save before finalizing to prevent task cancellation
        Task {
            await saveOnboardingProfile()
            await MainActor.run {
                finalizeOnboarding()
            }
        }
    }

    // MARK: - Profile Saving

    private func saveOnboardingProfile() async {
        guard let profileData = pendingProfileData, !profileData.displayName.isEmpty else { return }

        do {
            let profileService = ServiceContainer.shared.resolve(ProfileServiceProtocol.self)
            var profile = try await profileService.fetchCurrentUserProfile()

            // Update profile with collected data (fast - just text fields)
            profile.displayName = profileData.displayName
            profile.bio = profileData.bio
            profile.location = profileData.location
            profile.specialties = profileData.cuisines.isEmpty ? nil : profileData.cuisines

            // Save profile immediately without waiting for avatar upload
            try await profileService.updateProfile(profile)
            Log.info("Saved onboarding profile", category: .onboarding, metadata: [
                "displayName": profileData.displayName,
                "hasBio": profileData.bio != nil,
                "hasLocation": profileData.location != nil,
                "cuisineCount": profileData.cuisines.count
            ])

            // Upload avatar in background (don't block onboarding completion)
            if let image = profileData.avatarImage {
                Task.detached {
                    await self.uploadAvatarInBackground(image: image, profileService: profileService)
                }
            }
        } catch {
            Log.error("Failed to save onboarding profile", category: .onboarding, error: error)
        }
    }

    /// Upload avatar in background after onboarding completes
    private func uploadAvatarInBackground(image: UIImage, profileService: ProfileServiceProtocol) async {
        do {
            let photoURL = try await profileService.uploadAvatar(image)

            // Update profile with new photo URL
            var profile = try await profileService.fetchCurrentUserProfile()
            profile.photoURL = photoURL
            try await profileService.updateProfile(profile)

            Log.info("Avatar uploaded in background after onboarding", category: .onboarding)

            // Notify observers that profile was updated (for views that already loaded the profile)
            await MainActor.run {
                NotificationCenter.default.post(name: .userProfileDidUpdate, object: nil)
            }
        } catch {
            Log.error("Failed to upload avatar in background", category: .onboarding, error: error)
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

    private func finalizeOnboarding() {
        // Mark onboarding as complete
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // Navigate to Collections tab (now index 0 after removing Recipes tab)
        selectedTab = 0

        // Trigger demo social behaviors (welcome shares, proactive requests)
        DemoSocialBehaviorService.shared.onOnboardingComplete()

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
