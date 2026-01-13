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
    @EnvironmentObject private var notificationService: FirebaseNotificationService
    @State private var currentScreen: OnboardingScreen = .welcome

    /// Binding to control which tab should be selected after onboarding
    @Binding var selectedTab: Int

    /// Callback when onboarding is completed
    var onComplete: () -> Void

    enum OnboardingScreen {
        case welcome
        case importMethods
        case concept
        case features
    }

    var body: some View {
        NavigationStack {
            Group {
            switch currentScreen {
            case .welcome:
                OnboardingWelcomeScreen {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = .importMethods
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .importMethods:
                OnboardingImportMethodsScreen {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = .concept
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .concept:
                OnboardingConceptScreen {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = .features
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .features:
                OnboardingFeaturesScreen {
                    completeOnboarding()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
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

        // Navigate to Collections tab (index 1) instead of Recipes (index 0)
        selectedTab = 1

        // Notify parent that onboarding is complete
        onComplete()
    }
}

// MARK: - Preview

#Preview {
    OnboardingContainerView(selectedTab: .constant(0), onComplete: {})
}
