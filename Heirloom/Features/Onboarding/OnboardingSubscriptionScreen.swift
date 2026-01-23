//
//  OnboardingSubscriptionScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-23.
//  Subscription offer screen during onboarding flow
//

import SwiftUI

/// Subscription offer screen shown at end of onboarding
/// Presents trial offer with option to skip
struct OnboardingSubscriptionScreen: View {

    // MARK: - Environment

    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var paywallManager: PaywallManager

    // MARK: - State

    @State private var isLoading = false
    @State private var errorMessage: String?

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

            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 40)

                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.orange, Color.pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Try Premium Free")
                            .font(HeirloomFonts.title1Elevated)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .kerning(-0.5)

                        Text("Start your 14-day free trial")
                            .font(HeirloomFonts.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)

                    // Features
                    VStack(spacing: 20) {
                        FeatureRow(
                            icon: "video.fill",
                            title: "Unlimited Video Imports",
                            description: "Extract recipes from any cooking video"
                        )

                        FeatureRow(
                            icon: "book.fill",
                            title: "Cookbook Scanner",
                            description: "Digitize recipes from physical cookbooks"
                        )

                        FeatureRow(
                            icon: "sparkles",
                            title: "Visual Recipe Extraction",
                            description: "ASMR-style recipe extraction from videos"
                        )

                        FeatureRow(
                            icon: "calendar.badge.plus",
                            title: "Daily Heritage Recipes",
                            description: "New classic recipes delivered daily during your trial"
                        )

                        FeatureRow(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Sync Across Devices",
                            description: "Access your recipes on all your devices"
                        )
                    }
                    .padding(.horizontal, 24)

                    // Pricing
                    if let annualProduct = storeManager.products[.annual] {
                        VStack(spacing: 8) {
                            Text("Then \(annualProduct.displayPrice)/year")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text("Cancel anytime during trial")
                                .font(.caption)
                                .foregroundColor(.tertiary)
                        }
                    }

                    // CTA Buttons
                    VStack(spacing: 16) {
                        // Start Trial Button
                        Button(action: {
                            startTrial()
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text("Start Free Trial")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color.orange, Color.pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                        .disabled(isLoading)

                        // Skip Button
                        Button(action: {
                            onSkip()
                        }) {
                            Text("Continue with Free Version")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 32)

                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Legal
                    VStack(spacing: 8) {
                        // Primary focus on trial and pricing
                        Text("Free for 14 days, then \(storeManager.products[.annual]?.displayPrice ?? "$29.99")/year")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)

                        // Secondary benefit - daily recipe bonuses
                        Text("Includes daily heritage recipe bonuses during trial")
                            .font(.caption2)
                            .foregroundColor(.tertiary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 16) {
                            Link("Terms", destination: URL(string: "https://heirloom-ios-prod.web.app/terms.html")!)
                            Text("•")
                            Link("Privacy", destination: URL(string: "https://heirloom-ios-prod.web.app/privacy.html")!)
                        }
                        .font(.caption2)
                        .foregroundColor(.tertiary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
        }
        .task {
            // Load products when screen appears
            if storeManager.products.isEmpty {
                do {
                    try await storeManager.loadProducts()
                } catch {
                    errorMessage = "Could not load subscription options"
                    Log.error("Failed to load products during onboarding", category: .store, metadata: [
                        "error": error.localizedDescription
                    ])
                }
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
            analytics.track(event: AnalyticsEvent(name: "onboarding_trial_started"), properties: [
                "location": "onboarding_screen"
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

                analytics.track(event: AnalyticsEvent(name: "onboarding_trial_failed"), properties: [
                    "error": error.errorDescription ?? "unknown"
                ])
            }
        }
    }
}

// MARK: - Feature Row Component

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.orange, Color.pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingSubscriptionScreen(
        onStartTrial: {
            print("Started trial")
        },
        onSkip: {
            print("Skipped")
        }
    )
    .environmentObject(SubscriptionManager(
        storeManager: StoreManager(logger: LoggingService(), analytics: AnalyticsService()),
        logger: LoggingService(),
        analytics: AnalyticsService()
    ))
    .environmentObject(StoreManager(logger: LoggingService(), analytics: AnalyticsService()))
    .environmentObject(PaywallManager())
}
