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
    @State private var currentScreen: OnboardingScreen = .videoHero
    @State private var hasSeededHeritage = false

    /// Binding to control which tab should be selected after onboarding
    @Binding var selectedTab: Int

    /// Callback when onboarding is completed
    var onComplete: () -> Void

    enum OnboardingScreen {
        case videoHero
        case shareExtension
        case flexibility
        case organization
        case subscription // NEW: Optional subscription screen
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
                        currentScreen = .subscription
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

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

    private func seedHeritageRecipesIfNeeded() async {
        // Prevent duplicate seeding
        guard !hasSeededHeritage else {
            Log.info("Heritage recipes already seeded in this onboarding session", category: .storage)
            return
        }

        // Check if user is authenticated via FirebaseAuthService
        guard let authService = ServiceContainer.shared.resolveOptional(FirebaseAuthService.self),
              authService.isAuthenticated else {
            Log.info("Not authenticated during onboarding - heritage seeding will happen after sign-in", category: .storage)
            return
        }

        do {
            // Create heritage collections (but NO recipes)
            RecipeCollection.createHeritageCollections(context: modelContext)

            // Create blind boxes for onboarding
            let blindBoxSeeder = BlindBoxSeeder(modelContext: modelContext)
            if !blindBoxSeeder.isSeeded() {
                try blindBoxSeeder.seedBlindBoxes()
                Log.info("Heritage blind boxes created during onboarding", category: .storage)
                DeviceLogger.shared.log("✅ [Heritage] Blind boxes created during onboarding (no recipes downloaded)")
            }

            // Analytics tracking for heritage setup during onboarding
            let analytics = ServiceContainer.shared.resolve(AnalyticsService.self)
            analytics.track(event: AnalyticsEvent.appLaunched, properties: ["heritage_setup": "collections_created"])

            // Mark as complete to prevent duplicate attempts
            hasSeededHeritage = true
        } catch {
            Log.error("Failed to setup heritage collections during onboarding", category: .storage, metadata: ["error": error.localizedDescription])
            DeviceLogger.shared.log("❌ [Heritage] Failed to setup collections during onboarding: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingContainerView(selectedTab: .constant(0), onComplete: {})
}
