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
    @State private var currentScreen: OnboardingScreen = .screen1

    /// Binding to control which tab should be selected after onboarding
    @Binding var selectedTab: Int

    enum OnboardingScreen {
        case screen1, screen2
    }

    var body: some View {
        NavigationStack {
            Group {
            switch currentScreen {
            case .screen1:
                OnboardingScreen1 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentScreen = .screen2
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .screen2:
                OnboardingScreen2 {
                    // Navigate to Collections tab (index 1)
                    selectedTab = 1
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
