//
//  OnboardingSubscriptionScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-23.
//  Updated for new 5-screen onboarding flow on 2026-02-01
//  Redesigned with plan selection cards on 2026-02-10
//

import SwiftUI
import UIKit
import StoreKit

/// Premium trial screen - Screen 2 of 5
/// Plan selection cards with dynamic CTA and subscribe flourish
struct OnboardingSubscriptionScreen: View {

    // MARK: - Environment

    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(StoreManager.self) private var storeManager
    @Environment(PaywallManager.self) private var paywallManager

    // MARK: - State

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isLoadingProducts = true
    @State private var selectedPlan: ProductIdentifier = .annual
    @State private var showSuccessFlourish = false
    @State private var flourishScale: CGFloat = 0.5
    @State private var flourishOpacity: Double = 0

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
                Text("5/6")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(HeirloomColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                // Scrollable content
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 10) {
                            Text("Choose your plan")
                                .font(HeirloomFonts.title1Elevated)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .kerning(-0.5)

                            Text("Start with a free trial. Cancel anytime.")
                                .font(HeirloomFonts.body)
                                .foregroundColor(HeirloomColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)

                        // Plan selection cards
                        VStack(spacing: 10) {
                            planCard(
                                plan: .annual,
                                badge: "BEST VALUE",
                                badgeColor: HeirloomColors.tomato
                            )
                            planCard(
                                plan: .monthly,
                                badge: nil,
                                badgeColor: .clear
                            )
                            planCard(
                                plan: .lifetime,
                                badge: "ONE-TIME",
                                badgeColor: HeirloomColors.tomato
                            )
                        }
                        .padding(.horizontal, 24)

                        // Compact feature comparison
                        featureComparison
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }

                // Fixed bottom CTAs - Split button layout
                VStack(spacing: 12) {
                    // Split buttons: Trial on left, Free on right
                    HStack(spacing: 12) {
                        // Start Free Trial Button (Left)
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            purchaseSelectedPlan()
                        }) {
                            VStack(spacing: 3) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text(ctaTitle)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    if let subtitle = ctaSubtitle {
                                        Text(subtitle)
                                            .font(.caption2)
                                            .opacity(0.85)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(HeirloomColors.tomato)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .shadow(color: HeirloomColors.tomato.opacity(0.25), radius: 8, y: 4)
                        }
                        .disabled(isLoading)

                        // Continue Free Button (Right)
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onSkip()
                        }) {
                            VStack(spacing: 3) {
                                Text("Continue")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Free")
                                    .font(.caption2)
                                    .opacity(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .foregroundColor(HeirloomColors.primaryText)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                        }
                        .disabled(isLoading)
                    }

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

            // Success flourish overlay
            if showSuccessFlourish {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(HeirloomColors.familyGreen)
                        .scaleEffect(flourishScale)

                    Text("Welcome to Heirloom!")
                        .font(HeirloomFonts.title2)
                        .foregroundColor(.white)
                }
                .opacity(flourishOpacity)
                .transition(.opacity)
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

    // MARK: - Plan Card

    private func planCard(plan: ProductIdentifier, badge: String?, badgeColor: Color) -> some View {
        let isSelected = selectedPlan == plan

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedPlan = plan
            }
        } label: {
            HStack(spacing: 12) {
                // Radio button
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? HeirloomColors.tomato : Color.gray.opacity(0.4))

                // Plan details
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(plan.displayName)
                            .font(HeirloomFonts.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(HeirloomColors.primaryText)

                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(badgeColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(badgeColor.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }

                    Text(planTrialText(for: plan))
                        .font(HeirloomFonts.caption1)
                        .foregroundColor(HeirloomColors.secondaryText)

                    HStack(spacing: 4) {
                        Text(planPriceText(for: plan))
                            .font(HeirloomFonts.body)
                            .fontWeight(.medium)
                            .foregroundColor(HeirloomColors.primaryText)

                        if plan == .annual {
                            Text("Save 52% vs monthly")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(HeirloomColors.familyGreen)
                        }
                    }
                }

                Spacer()
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? HeirloomColors.tomato : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(isSelected ? 0.08 : 0.04), radius: isSelected ? 8 : 4, y: 2)
        }
    }

    // MARK: - Plan Helpers

    private func planTrialText(for plan: ProductIdentifier) -> String {
        switch plan {
        case .annual, .monthly:
            return "7-day free trial"
        case .lifetime:
            return "No subscription"
        }
    }

    private func planPriceText(for plan: ProductIdentifier) -> String {
        switch plan {
        case .annual:
            if let product = storeManager.products[.annual] {
                return "\(product.displayPrice)/year ($3.33/mo)"
            }
            return "$39.99/year ($3.33/mo)"
        case .monthly:
            if let product = storeManager.products[.monthly] {
                return "\(product.displayPrice)/month"
            }
            return "$6.99/month"
        case .lifetime:
            if let product = storeManager.products[.lifetime] {
                return product.displayPrice
            }
            return "$149"
        }
    }

    // MARK: - Feature Comparison

    private var featureComparison: some View {
        HStack(alignment: .top, spacing: 24) {
            // Free column
            VStack(alignment: .leading, spacing: 8) {
                Text("Free")
                    .font(HeirloomFonts.caption1)
                    .fontWeight(.semibold)
                    .foregroundColor(HeirloomColors.primaryText)

                comparisonRow(icon: "checkmark", iconColor: HeirloomColors.familyGreen, text: "Save from links")
                comparisonRow(icon: "checkmark", iconColor: HeirloomColors.familyGreen, text: "Scan recipe cards")
                comparisonRow(icon: "checkmark", iconColor: HeirloomColors.familyGreen, text: "AI generation")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Premium column
            VStack(alignment: .leading, spacing: 8) {
                Text("Premium adds")
                    .font(HeirloomFonts.caption1)
                    .fontWeight(.semibold)
                    .foregroundColor(HeirloomColors.primaryText)

                comparisonRow(icon: "star.fill", iconColor: HeirloomColors.tomato, text: "Share with family")
                comparisonRow(icon: "star.fill", iconColor: HeirloomColors.tomato, text: "Import from videos")
                comparisonRow(icon: "star.fill", iconColor: HeirloomColors.tomato, text: "Bulk cookbook scans")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.white.opacity(0.6))
        .cornerRadius(12)
    }

    private func comparisonRow(icon: String, iconColor: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(iconColor)
                .frame(width: 14)

            Text(text)
                .font(HeirloomFonts.caption1)
                .foregroundColor(HeirloomColors.secondaryText)
        }
    }

    // MARK: - Dynamic CTA

    private var ctaTitle: String {
        switch selectedPlan {
        case .annual, .monthly:
            return "Start free trial"
        case .lifetime:
            return "Buy lifetime access"
        }
    }

    private var ctaSubtitle: String? {
        switch selectedPlan {
        case .annual:
            if let product = storeManager.products[.annual] {
                return "Then \(product.displayPrice)/year"
            }
            return "Then $39.99/year"
        case .monthly:
            if let product = storeManager.products[.monthly] {
                return "Then \(product.displayPrice)/month"
            }
            return "Then $6.99/month"
        case .lifetime:
            return nil
        }
    }

    // MARK: - Actions

    private func purchaseSelectedPlan() {
        isLoading = true
        errorMessage = nil

        // Mark that user is initiating a purchase (for demo account handling)
        // Pass the product ID so we can distinguish from background transactions for other products
        subscriptionManager.markPurchaseStarted(for: selectedPlan)

        Task {
            // Track analytics
            let analytics = ServiceContainer.shared.resolve(AnalyticsService.self)
            analytics.track(event: .appLaunched, properties: [
                "location": "onboarding_plan_selected",
                "plan": selectedPlan.rawValue
            ])

            // Attempt purchase of selected plan
            let result = await storeManager.purchase(selectedPlan)

            switch result {
            case .success:
                Log.info("Subscription started from onboarding", category: .store)
                await showFlourish()
                onStartTrial()

            case .cancelled:
                Log.info("Purchase cancelled during onboarding", category: .store)
                isLoading = false
                onSkip()

            case .pending:
                Log.info("Purchase pending", category: .store)
                await showFlourish()
                onStartTrial()

            case .failed(let error):
                errorMessage = error.errorDescription
                isLoading = false
                Log.error("Purchase failed during onboarding", category: .store, metadata: [
                    "error": error.errorDescription ?? "unknown"
                ])

                analytics.track(event: .appLaunched, properties: [
                    "action": "onboarding_purchase_failed",
                    "error": error.errorDescription ?? "unknown"
                ])
            }
        }
    }

    @MainActor
    private func showFlourish() async {
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.easeOut(duration: 0.2)) {
            showSuccessFlourish = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            flourishScale = 1.0
            flourishOpacity = 1.0
        }

        try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2s
    }
}

// MARK: - Preview

// Preview disabled due to complex dependency injection requirements
// Test in app instead
