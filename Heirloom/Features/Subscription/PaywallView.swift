//
//  PaywallView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-08.
//

import SwiftUI
import StoreKit

/// Main paywall view with plan selection
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var storeManager: StoreManager
    @State private var subscriptionManager: SubscriptionManager
    @State private var paywallManager: PaywallManager
    @State private var selectedProduct: ProductIdentifier = .annual
    @State private var isPurchasing = false
    @State private var purchaseStatusMessage = "Processing..."
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isRestoringPurchases = false

    /// Trigger that caused this paywall to show (optional)
    let trigger: PaywallTrigger?

    /// Is this a soft wall (dismissible) or hard wall (must subscribe or cancel feature)?
    var isSoftWall: Bool {
        trigger?.isSoftWall ?? true
    }

    init(trigger: PaywallTrigger? = nil) {
        self.trigger = trigger
        let container = ServiceContainer.shared
        let subManager = container.resolve(SubscriptionManager.self)
        _storeManager = State(initialValue: container.resolve(StoreManager.self))
        _subscriptionManager = State(initialValue: subManager)
        _paywallManager = State(initialValue: container.resolve(PaywallManager.self))

        // Default to Annual plan (especially for upgraders)
        _selectedProduct = State(initialValue: .annual)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HeirloomSpacing.lg) {
                // Debug badges (DEBUG BUILDS ONLY)
                #if DEBUG
                if storeManager.isFakePaymentsEnabled || subscriptionManager.isAutoPremiumEnabled {
                    VStack(spacing: 8) {
                        // Fake payments badge
                        if storeManager.isFakePaymentsEnabled {
                            HStack {
                                Image(systemName: "theatermasks.fill")
                                Text("FAKE PAYMENTS ACTIVE")
                                    .font(.caption.bold())
                            }
                            .foregroundStyle(HeirloomColors.buttonTextLight)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.purple)
                            .cornerRadius(8)
                        }

                        // Auto Premium badge
                        if subscriptionManager.isAutoPremiumEnabled {
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "crown.fill")
                                    Text("AUTO PREMIUM ENABLED")
                                        .font(.caption.bold())
                                }
                                .foregroundStyle(HeirloomColors.buttonTextLight)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.orange)
                                .cornerRadius(8)

                                // Continue button (bypass paywall in debug mode)
                                Button {
                                    // Track bypass
                                    let analytics = ServiceContainer.shared.resolve(AnalyticsService.self)
                                    analytics.track(event: .appLaunched, properties: [
                                        "action": "paywall_debug_bypass",
                                        "trigger": trigger?.displayName ?? "unknown"
                                    ])
                                    // Dismiss paywall
                                    dismiss()
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.right.circle.fill")
                                        Text("Continue Anyway (Debug)")
                                            .font(.caption.bold())
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.green)
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                #endif

                // Header
                VStack(spacing: HeirloomSpacing.md) {
                    Image(systemName: upgradeHeaderIcon)
                        .font(.system(size: 56))
                        .foregroundStyle(upgradeHeaderColor)

                    Text(upgradeHeaderTitle)
                        .font(HeirloomFonts.title1)
                        .foregroundStyle(HeirloomColors.charcoal)

                    if let subtitle = upgradeHeaderSubtitle {
                        Text(subtitle)
                            .font(HeirloomFonts.body)
                            .foregroundStyle(upgradeHeaderColor)
                    }
                }
                .padding(.top, 20)

                // Feature List
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    featureRow(text: "Import from any recipe website")
                    featureRow(text: "Scan cookbook pages with OCR")
                    featureRow(text: "Sync across all your devices")
                    featureRow(text: "Export your data anytime")
                }
                .padding(.horizontal, 32)

                // Plan Selection
                VStack(spacing: 10) {
                    // Show plans based on current subscription status
                    if subscriptionManager.canUpgradeToLifetime {
                        // Annual users: Show only Lifetime upgrade
                        planOption(
                            productID: .lifetime,
                            price: "$149 once",
                            trial: "No more renewals",
                            badge: "UPGRADE NOW"
                        )
                    } else if subscriptionManager.canUpgradeToAnnual {
                        // Monthly users: Show Annual and Lifetime upgrades
                        planOption(
                            productID: .annual,
                            price: "$39.99/year",
                            trial: "Save over 50%",
                            badge: "RECOMMENDED"
                        )

                        planOption(
                            productID: .lifetime,
                            price: "$149 once",
                            trial: "No subscription",
                            badge: "ONE-TIME PAYMENT"
                        )
                    } else {
                        // New users: Show all plans
                        planOption(
                            productID: .annual,
                            price: "$39.99/year",
                            trial: "14-day free trial",
                            badge: "BEST VALUE"
                        )

                        planOption(
                            productID: .monthly,
                            price: "$6.99/month",
                            trial: "7-day free trial",
                            badge: nil
                        )

                        planOption(
                            productID: .lifetime,
                            price: "$149 once",
                            trial: "No subscription",
                            badge: "FOUNDING MEMBER • LIMITED"
                        )
                    }
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .background(HeirloomColors.cream)
        .safeAreaInset(edge: .bottom) {
            // Fixed bottom CTA section
            VStack(spacing: 12) {
                // CTA Buttons - side by side for soft walls
                HStack(spacing: 12) {
                    // Continue Free button (only for soft walls)
                    if isSoftWall {
                        Button {
                            dismissPaywall()
                        } label: {
                            Text("Continue Free")
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(HeirloomColors.charcoal)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(HeirloomColors.cardBackground)
                                .cornerRadius(HeirloomSpacing.cardCornerRadius)
                                .overlay(
                                    RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                                        .stroke(HeirloomColors.warmGray, lineWidth: 1)
                                )
                        }
                    }

                    // Subscribe button
                    Button {
                        purchase()
                    } label: {
                        HStack(spacing: 8) {
                            if isPurchasing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(HeirloomColors.buttonTextLight)
                                Text(purchaseStatusMessage)
                                    .font(HeirloomFonts.body)
                            } else {
                                Text(ctaText)
                                    .font(HeirloomFonts.bodyBold)
                            }
                        }
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isPurchasing ? HeirloomColors.warmGray : HeirloomColors.tomato)
                        .cornerRadius(HeirloomSpacing.cardCornerRadius)
                    }
                    .disabled(isPurchasing)
                }

                // Trust Line
                Text("Your recipes are always yours. Export anytime, even without a subscription.")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                // Restore Purchases (Apple Guideline 3.1.1 compliance)
                Button {
                    restorePurchases()
                } label: {
                    if isRestoringPurchases {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Restoring...")
                        }
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))
                    } else {
                        Text("Already subscribed? Restore Purchases")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.tomato)
                    }
                }
                .disabled(isRestoringPurchases)
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .background(HeirloomColors.cream)
        }
        .alert("Purchase Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            // Load products if not already loaded
            if storeManager.products.isEmpty {
                try? await storeManager.loadProducts()
            }
        }
    }

    // MARK: - Feature Row

    private func featureRow(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(HeirloomColors.familyGreen)
                .font(.system(size: 18))

            Text(text)
                .font(HeirloomFonts.subheadline)
                .foregroundStyle(HeirloomColors.charcoal)

            Spacer()
        }
    }

    // MARK: - Plan Option

    /// Check if a product is the user's current subscription (should be disabled)
    private func isCurrentSubscription(_ productID: ProductIdentifier) -> Bool {
        // Demo accounts: ONLY check currentProductID from this session
        // Don't use subscription status since RevenueCat sandbox has stale data
        // that can auto-complete purchases (e.g., showing Lifetime when user only bought Annual)
        if subscriptionManager.isDemoAccountConfigured {
            // If not premium, all plans are available
            guard subscriptionManager.status.isPremium else {
                return false
            }

            // Only disable the exact product they purchased THIS session
            // This allows demo accounts to test all upgrade paths
            if let currentID = subscriptionManager.currentProductID {
                return currentID == productID
            }

            // No session purchase - all plans available
            return false
        }

        // Regular users: Check cached product ID first
        if let currentID = subscriptionManager.currentProductID, currentID == productID {
            return true
        }

        // Also check subscription status directly (for sandbox scenarios)
        switch subscriptionManager.status {
        case .monthly:
            return productID == .monthly
        case .annual:
            return productID == .annual
        case .lifetime:
            return productID == .lifetime
        default:
            return false
        }
    }

    @ViewBuilder
    private func planOption(productID: ProductIdentifier, price: String, trial: String, badge: String?) -> some View {
        let isDisabled = isCurrentSubscription(productID)

        Button {
            selectedProduct = productID
            // Adjust trial if needed
            if productID.isSubscription {
                subscriptionManager.adjustTrialForPlan(productID)
            }
        } label: {
            HStack(spacing: HeirloomSpacing.md) {
                // Radio Button
                Image(systemName: selectedProduct == productID ? "checkmark.circle.fill" : "circle")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(
                        isDisabled ? HeirloomColors.warmGray.opacity(0.5) :
                        (selectedProduct == productID ? HeirloomColors.tomato : HeirloomColors.warmGray)
                    )

                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    HStack {
                        Text(productID.displayName)
                            .font(HeirloomFonts.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(isDisabled ? HeirloomColors.charcoal.opacity(0.4) : HeirloomColors.charcoal)

                        if isDisabled {
                            Text("CURRENT PLAN")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(HeirloomColors.warmGray)
                                .cornerRadius(4)
                        } else if let badge = badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(HeirloomColors.tomato)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(HeirloomColors.tomato.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }

                    Text(trial)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(isDisabled ? HeirloomColors.charcoal.opacity(0.3) : HeirloomColors.charcoal.opacity(0.6))

                    Text(price)
                        .font(HeirloomFonts.body)
                        .fontWeight(.medium)
                        .foregroundStyle(isDisabled ? HeirloomColors.charcoal.opacity(0.4) : HeirloomColors.charcoal)
                }

                Spacer()
            }
            .padding(.horizontal, HeirloomSpacing.md)
            .padding(.vertical, 12)
            .background(isDisabled ? HeirloomColors.cardBackground.opacity(0.6) : HeirloomColors.cardBackground)
            .cornerRadius(HeirloomSpacing.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                    .stroke(
                        isDisabled ? HeirloomColors.warmGray.opacity(0.3) :
                        (selectedProduct == productID ? HeirloomColors.tomato : Color.clear),
                        lineWidth: 2
                    )
            )
            .shadow(color: HeirloomShadows.card.color, radius: HeirloomShadows.card.radius, x: 0, y: 2)
        }
        .disabled(isDisabled)
    }

    // MARK: - Header Computed Properties

    private var upgradeHeaderIcon: String {
        if subscriptionManager.canUpgradeToLifetime {
            return "crown.fill"
        } else if subscriptionManager.canUpgradeToAnnual {
            return "arrow.up.circle.fill"
        } else {
            return "book.closed.fill"
        }
    }

    private var upgradeHeaderColor: Color {
        if subscriptionManager.canUpgradeToLifetime {
            return HeirloomColors.tomato
        } else if subscriptionManager.canUpgradeToAnnual {
            return .green
        } else {
            return HeirloomColors.tomato
        }
    }

    private var upgradeHeaderTitle: String {
        if subscriptionManager.canUpgradeToLifetime {
            return "Upgrade to Lifetime"
        } else if subscriptionManager.canUpgradeToAnnual {
            return "Upgrade to Annual"
        } else {
            return "Heirloom Premium"
        }
    }

    private var upgradeHeaderSubtitle: String? {
        if subscriptionManager.canUpgradeToLifetime {
            return "One payment, yours forever"
        } else if subscriptionManager.canUpgradeToAnnual {
            return "Save over 50% with Annual billing"
        } else {
            return nil
        }
    }

    // MARK: - CTA Text

    private var ctaText: String {
        // If user is upgrading to Lifetime
        if subscriptionManager.canUpgradeToLifetime {
            return "Buy Lifetime Access"
        }

        // If user is upgrading from Monthly
        if subscriptionManager.canUpgradeToAnnual {
            return selectedProduct == .annual ? "Upgrade to Annual" : "Buy Lifetime Access"
        }

        // Default CTA for new subscribers
        switch selectedProduct {
        case .annual:
            return "Start 14-Day Free Trial"
        case .monthly:
            return "Start 7-Day Free Trial"
        case .lifetime:
            return "Buy Lifetime Access"
        }
    }

    // MARK: - Actions

    private func purchase() {
        // Log when purchase is triggered for debugging mystery auto-purchases
        Log.info("PaywallView.purchase() called", category: .store, metadata: [
            "selectedProduct": selectedProduct.rawValue,
            "trigger": trigger?.displayName ?? "none",
            "isDemoAccount": subscriptionManager.isDemoAccountConfigured
        ])
        DeviceLogger.shared.log("💳 [PaywallView] purchase() triggered for \(selectedProduct.displayName)", level: .info)

        isPurchasing = true
        purchaseStatusMessage = "Processing purchase..."

        // Mark that user is initiating a purchase (for demo account handling)
        // Pass the product ID so we can distinguish from background transactions for other products
        subscriptionManager.markPurchaseStarted(for: selectedProduct)

        Task { @MainActor in
            let result = await storeManager.purchase(selectedProduct)

            switch result {
            case .success:
                // Show confirming status
                purchaseStatusMessage = "Confirming subscription..."

                // Wait for RevenueCat to process and retry refresh
                var confirmed = false
                for attempt in 1...3 {
                    // Small delay to let RevenueCat process
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000) // 0.5s, 1s, 1.5s

                    await subscriptionManager.refreshStatus(force: true)

                    if subscriptionManager.isPremium {
                        confirmed = true
                        break
                    }

                    purchaseStatusMessage = "Verifying subscription... (\(attempt)/3)"
                }

                isPurchasing = false

                if confirmed {
                    dismiss()
                } else {
                    // Purchase succeeded but status not confirmed yet - still dismiss
                    // RevenueCat will update status on next app launch
                    dismiss()
                }

            case .cancelled:
                isPurchasing = false
                // User cancelled - do nothing
                break

            case .pending:
                isPurchasing = false
                // ⭐ NEW: If fake payments enabled, treat pending as success
                if storeManager.isFakePaymentsEnabled {
                    await subscriptionManager.refreshStatus(force: true)
                    dismiss()
                } else {
                    errorMessage = "Your purchase is pending approval. You'll be notified when it's complete."
                    showError = true
                }

            case .failed(let error):
                isPurchasing = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func dismissPaywall() {
        paywallManager.dismiss()
        dismiss()
    }

    private func restorePurchases() {
        isRestoringPurchases = true

        Task { @MainActor in
            do {
                let transactions = try await storeManager.restorePurchases()

                // Refresh subscription status
                await subscriptionManager.refreshStatus(force: true)

                isRestoringPurchases = false

                if subscriptionManager.isPremium {
                    // Successfully restored - dismiss paywall
                    dismiss()
                } else if transactions.isEmpty {
                    errorMessage = "No previous purchases found for this Apple ID."
                    showError = true
                }
            } catch {
                isRestoringPurchases = false
                errorMessage = "Restore failed: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView(trigger: .firstRecipeAdded)
}
