//
//  OnboardingSubscriptionScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-23.
//  Updated for new 5-screen onboarding flow on 2026-02-01
//  Task 2: Credit system visualization
//

import SwiftUI
import UIKit
import StoreKit

/// Premium trial screen - Screen 2 of 5
/// Shows the credit system with visual meter and example costs
struct OnboardingSubscriptionScreen: View {

    // MARK: - Environment

    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(StoreManager.self) private var storeManager
    @Environment(PaywallManager.self) private var paywallManager

    // MARK: - State

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isLoadingProducts = true

    // MARK: - Callbacks

    var onStartTrial: () -> Void
    var onSkip: () -> Void

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.95, blue: 0.90), // Warm cream
                    Color(red: 0.95, green: 0.90, blue: 0.85)  // Soft beige
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                Text("2/5")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(HeirloomColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                // Scrollable content
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Text("Save recipes for free")
                                .font(HeirloomFonts.title1Elevated)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .kerning(-0.5)

                            Text("Most features are free. Credits power video imports and large cookbooks.")
                                .font(HeirloomFonts.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // What's free section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Always free")
                                .font(HeirloomFonts.bodyBold)
                                .foregroundColor(HeirloomColors.primaryText)

                            FreeFeatureRow(icon: "link", label: "Save from any link")
                            FreeFeatureRow(icon: "camera", label: "Scan a recipe card")
                            FreeFeatureRow(icon: "sparkles", label: "Generate with AI")
                            FreeFeatureRow(icon: "folder", label: "Organize collections")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(HeirloomColors.familyGreen.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 24)

                        // Premium features
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(HeirloomColors.tomato)
                                Text("Premium unlocks")
                                    .font(HeirloomFonts.bodyBold)
                                    .foregroundColor(HeirloomColors.primaryText)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                PremiumFeatureRow(icon: "person.2.fill", label: "Share with friends & family")
                                PremiumFeatureRow(icon: "globe", label: "Publish to Discover")
                                PremiumFeatureRow(icon: "video.fill", label: "Import from videos")
                                PremiumFeatureRow(icon: "book.fill", label: "Bulk cookbook scans")
                            }

                            Text("Your free trial includes 50 credits. Premium subscribers get 100 credits each month. You'll always see costs before confirming.")
                                .font(HeirloomFonts.caption1)
                                .foregroundColor(HeirloomColors.secondaryText)
                                .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(HeirloomColors.tomato.opacity(0.08))
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 16)
                }

                // Fixed bottom CTAs
                VStack(spacing: 12) {
                    // Start Free Trial Button - PRIMARY (always show)
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        startTrial()
                    }) {
                        VStack(spacing: 4) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text("Start free trial")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                if let annualProduct = storeManager.products[ProductIdentifier.annual] {
                                    Text("Then \(annualProduct.displayPrice)/year")
                                        .font(.caption)
                                        .opacity(0.9)
                                } else {
                                    Text("7 days free")
                                        .font(.caption)
                                        .opacity(0.9)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(HeirloomColors.tomato)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: HeirloomColors.tomato.opacity(0.3), radius: 12, y: 6)
                    }
                    .disabled(isLoading)

                    // Continue Free Button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSkip()
                    }) {
                        Text("Continue free")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .disabled(isLoading)
                    .padding(.bottom, 4)

                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Microcopy
                    VStack(spacing: 4) {
                        Text("Cancel anytime")
                            .font(HeirloomFonts.caption2)
                            .foregroundColor(.secondary.opacity(0.6))

                        HStack(spacing: 8) {
                            Link("Terms", destination: URL(string: "https://heirloom-ios-prod.web.app/terms.html")!)
                            Text("•")
                            Link("Privacy", destination: URL(string: "https://heirloom-ios-prod.web.app/privacy.html")!)
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.90, blue: 0.85).opacity(0),
                            Color(red: 0.95, green: 0.90, blue: 0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .task {
            // Load products when screen appears
            if storeManager.products.isEmpty {
                do {
                    try await storeManager.loadProducts()
                    isLoadingProducts = false
                } catch {
                    errorMessage = "Could not load subscription options"
                    isLoadingProducts = false
                    Log.error("Failed to load products during onboarding", category: .store, metadata: [
                        "error": error.localizedDescription
                    ])
                }
            } else {
                // Products already loaded
                isLoadingProducts = false
            }
        }
    }

    // MARK: - Actions

    private func startTrial() {
        isLoading = true
        errorMessage = nil

        Task {
            // Track analytics
            let analytics = ServiceContainer.shared.resolve(AnalyticsService.self)
            analytics.track(event: .appLaunched, properties: [
                "location": "onboarding_trial_started"
            ])

            // Attempt purchase
            let result = await storeManager.purchase(.annual)

            switch result {
            case .success:
                // Trial started successfully
                Log.info("Trial started from onboarding", category: .store)
                onStartTrial()

            case .cancelled:
                // User cancelled - treat as skip
                Log.info("Trial cancelled during onboarding", category: .store)
                isLoading = false
                onSkip()

            case .pending:
                // Purchase pending - treat as success
                Log.info("Trial purchase pending", category: .store)
                onStartTrial()

            case .failed(let error):
                // Show error but allow continuing
                errorMessage = error.errorDescription
                isLoading = false
                Log.error("Trial purchase failed during onboarding", category: .store, metadata: [
                    "error": error.errorDescription ?? "unknown"
                ])

                analytics.track(event: .appLaunched, properties: [
                    "action": "onboarding_trial_failed",
                    "error": error.errorDescription ?? "unknown"
                ])
            }
        }
    }

    private func subscribeNow() {
        isLoading = true
        errorMessage = nil

        Task {
            // Track analytics
            let analytics = ServiceContainer.shared.resolve(AnalyticsService.self)
            analytics.track(event: .appLaunched, properties: [
                "location": "onboarding_subscribe_now"
            ])

            // Purchase annual subscription immediately (no trial)
            let result = await storeManager.purchase(.annual)

            switch result {
            case .success:
                // Subscription successful
                Log.info("Direct subscription from onboarding", category: .store)
                onStartTrial() // Same callback - user is subscribed

            case .cancelled:
                // User cancelled - just stop loading
                Log.info("Direct subscription cancelled during onboarding", category: .store)
                isLoading = false

            case .pending:
                // Purchase pending - treat as success
                Log.info("Direct subscription pending", category: .store)
                onStartTrial()

            case .failed(let error):
                // Show error but allow continuing
                errorMessage = error.errorDescription
                isLoading = false
                Log.error("Direct subscription failed during onboarding", category: .store, metadata: [
                    "error": error.errorDescription ?? "unknown"
                ])

                analytics.track(event: .appLaunched, properties: [
                    "action": "onboarding_subscribe_failed",
                    "error": error.errorDescription ?? "unknown"
                ])
            }
        }
    }
}

// MARK: - Free Feature Row

private struct FreeFeatureRow: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(HeirloomColors.familyGreen)

            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(HeirloomColors.primaryText)
                .frame(width: 20)

            Text(label)
                .font(HeirloomFonts.body)
                .foregroundColor(HeirloomColors.primaryText)
        }
    }
}

// MARK: - Premium Feature Row

private struct PremiumFeatureRow: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(HeirloomColors.tomato)
                .frame(width: 20)

            Text(label)
                .font(HeirloomFonts.body)
                .foregroundColor(HeirloomColors.primaryText)
        }
    }
}

// MARK: - Preview

// Preview disabled due to complex dependency injection requirements
// Test in app instead
