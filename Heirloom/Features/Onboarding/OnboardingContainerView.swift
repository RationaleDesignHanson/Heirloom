//
//  OnboardingContainerView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-08.
//  Updated for 7-screen onboarding flow on 2026-02-25
//  Aligned with pitch deck narrative: capture → transform → lineage → privacy → save → upsell → profile
//

import SwiftUI
import SwiftData
import UIKit

/// Container view that manages the 7-screen onboarding flow
struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.firebaseAuth) private var firebaseAuth
    @EnvironmentObject private var notificationService: FirebaseNotificationService
    @EnvironmentObject private var themeUnlockTracker: ThemeUnlockTracker
    @EnvironmentObject private var tabCoordinator: TabNavigationCoordinator
    @State private var currentScreen: OnboardingScreen = .capture
    @State private var hasSeededHeritage = false
    @State private var pendingProfileData: OnboardingProfileData?

    /// Binding to control which tab should be selected after onboarding
    @Binding var selectedTab: Int

    /// Callback when onboarding is completed
    var onComplete: () -> Void

    enum OnboardingScreen {
        case capture           // Screen 1: "Save from anywhere" - capture breadth
        case transformation    // Screen 2: "Heirloom structures them" - AI transformation
        case lineage           // Screen 3: "Recipes have history" - generational timeline
        case privacy           // Screen 4: "Private by default" - trust building
        case howToSave         // Screen 5: "Two ways to save" - share extension + in-app
        case premiumTrial      // Screen 6: Premium upsell
        case profileSetup      // Screen 7: Profile setup (name + photo)
        case completing        // Final: Saving profile and finishing up
    }

    @State private var showSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            switch currentScreen {
            case .capture:
                // Screen 1: "Save from anywhere" - capture breadth
                OnboardingWelcomeScreen(
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentScreen = .transformation
                        }
                    },
                    onRestoreFromBackup: {
                        // Restore completed - skip rest of onboarding
                        Log.info("Restore from backup completed - skipping onboarding", category: .onboarding)
                        finalizeOnboarding()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .transformation:
                // Screen 2: "Heirloom structures them for you" - AI transformation
                OnboardingTransformationScreen {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = .lineage
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .lineage:
                // Screen 3: "Recipes have history" - generational timeline
                OnboardingShareAndAcceptScreen {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = .privacy
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .privacy:
                // Screen 4: "Private by default" - trust building
                OnboardingPrivacyScreen {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = .howToSave
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .howToSave:
                // Screen 5: "Two ways to save recipes" - share extension + in-app
                OnboardingHowToSaveScreen {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = .premiumTrial
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .premiumTrial:
                // Screen 6: Premium subscription (mandatory - no skip option)
                OnboardingSubscriptionScreen(
                    onStartTrial: {
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
                // Screen 7: Profile setup (name + photo)
                OnboardingProfileSetupScreen(
                    onContinue: { profileData in
                        pendingProfileData = profileData
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentScreen = .completing
                        }
                        // Save profile and finalize directly (no theme selection)
                        Task {
                            await saveOnboardingProfile()
                            await MainActor.run {
                                finalizeOnboarding()
                            }
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .completing:
                // Final: Saving profile and finishing up
                completingView
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .topTrailing) {
            // Sign-out escape hatch for users stuck in onboarding
            // (e.g., Firebase auth restored from keychain after app deletion)
            if firebaseAuth.isAuthenticated {
                Button {
                    showSignOutConfirmation = true
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16))
                        .foregroundColor(HeirloomColors.secondaryText.opacity(0.5))
                        .padding(12)
                }
                .accessibilityLabel("Sign out")
                .padding(.top, 8)
                .padding(.trailing, 8)
            }
        }
        .confirmationDialog(
            "Sign Out?",
            isPresented: $showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                do {
                    try firebaseAuth.signOut()
                    Log.info("User signed out from onboarding", category: .auth)
                } catch {
                    Log.error("Failed to sign out from onboarding", category: .auth, error: error)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Sign out to return to the sign-in screen.")
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
        // Theme selection moved to Discovery tab
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
            profile.websiteURL = profileData.websiteURL
            profile.specialties = profileData.cuisines.isEmpty ? nil : profileData.cuisines

            // Save profile immediately without waiting for avatar upload
            try await profileService.updateProfile(profile)
            Log.info("Saved onboarding profile", category: .onboarding, metadata: [
                "displayName": profileData.displayName,
                "hasBio": profileData.bio != nil,
                "hasLocation": profileData.location != nil,
                "hasWebsite": profileData.websiteURL != nil,
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

    private func finalizeOnboarding() {
        // Mark onboarding as complete (local)
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        Log.info("Finalizing onboarding - set hasCompletedOnboarding=true in UserDefaults", category: .onboarding)

        // Sync profile to Firebase (sets hasCompletedOnboarding: true remotely)
        // This ensures returning users skip onboarding after sign-out/sign-in
        Task {
            if let profileService = ServiceContainer.shared.resolveOptional(FirebaseUserProfileService.self) {
                do {
                    try await profileService.syncCurrentUserProfile()
                    Log.info("Profile sync completed after onboarding", category: .onboarding)
                } catch {
                    Log.error("Profile sync FAILED after onboarding", category: .onboarding, error: error)
                }
            } else {
                Log.error("ProfileService not available for onboarding sync", category: .onboarding)
            }
        }

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
