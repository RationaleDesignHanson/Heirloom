//
//  OnboardingContainerView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-08.
//

import SwiftUI

/// Container view that manages the 2-screen onboarding flow
struct OnboardingContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var notificationService: FirebaseNotificationService
    @State private var currentScreen: OnboardingScreen = .importMethods

    /// Binding to control which tab should be selected after onboarding
    @Binding var selectedTab: Int

    enum OnboardingScreen {
        case importMethods, collectionsPreview
    }

    var body: some View {
        NavigationStack {
            Group {
            switch currentScreen {
            case .importMethods:
                OnboardingImportMethodsScreen {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = .collectionsPreview
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .collectionsPreview:
                OnboardingCollectionsPreviewScreen {
                    // Navigate to Recipes tab (index 0)
                    selectedTab = 0
                    dismiss()
                }
                .environmentObject(notificationService)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingContainerView(selectedTab: .constant(0))
}
