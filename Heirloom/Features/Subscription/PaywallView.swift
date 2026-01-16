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
    @State private var showError = false
    @State private var errorMessage = ""

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
            VStack(spacing: 32) {
                // ⭐ NEW: Debug badge when fake payments are active
                if storeManager.isFakePaymentsEnabled {
                    HStack {
                        Image(systemName: "theatermasks.fill")
                        Text("FAKE PAYMENTS ACTIVE")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple)
                    .cornerRadius(8)
                    .padding(.top, 8)
                }

                // Header
                VStack(spacing: 16) {
                    Image(systemName: subscriptionManager.canUpgrade ? "arrow.up.circle.fill" : "book.closed.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(subscriptionManager.canUpgrade ? .green : HeirloomColors.tomato)

                    Text(subscriptionManager.canUpgrade ? "Upgrade to Annual" : "Heirloom Premium")
                        .font(HeirloomFonts.title1)
                        .foregroundStyle(HeirloomColors.charcoal)

                    if subscriptionManager.canUpgrade {
                        Text("Save over 50% with Annual billing")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.top, 40)

                // Feature List
                VStack(alignment: .leading, spacing: 16) {
                    featureRow(text: "Import from any recipe website")
                    featureRow(text: "Scan cookbook pages with OCR")
                    featureRow(text: "Sync across all your devices")
                    featureRow(text: "Export your data anytime")
                }
                .padding(.horizontal, 32)

                // Plan Selection
                VStack(spacing: 12) {
                    // Show all plans if not upgrading, or only Annual if upgrading from Monthly
                    if !subscriptionManager.canUpgrade {
                        planOption(
                            productID: .annual,
                            price: "$29.99/year",
                            trial: "14-day free trial",
                            badge: "BEST VALUE"
                        )

                        planOption(
                            productID: .monthly,
                            price: "$4.99/month",
                            trial: "7-day free trial",
                            badge: nil
                        )

                        planOption(
                            productID: .lifetime,
                            price: "$99 once",
                            trial: "No subscription",
                            badge: "FOUNDING MEMBER • LIMITED"
                        )
                    } else {
                        // Upgrading from Monthly to Annual
                        planOption(
                            productID: .annual,
                            price: "$29.99/year",
                            trial: "Save over 50%",
                            badge: "RECOMMENDED"
                        )

                        planOption(
                            productID: .lifetime,
                            price: "$99 once",
                            trial: "No subscription",
                            badge: "ONE-TIME PAYMENT"
                        )
                    }
                }
                .padding(.horizontal, 32)

                // CTA Button
                Button {
                    purchase()
                } label: {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Text(ctaText)
                                .font(HeirloomFonts.bodyBold)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(12)
                }
                .disabled(isPurchasing)
                .padding(.horizontal, 32)

                // Dismiss Link (only for soft walls)
                if isSoftWall {
                    Button {
                        dismissPaywall()
                    } label: {
                        Text("Maybe later")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))
                    }
                }

                // Trust Line
                Text("Your recipes are always yours. Export anytime, even without a subscription.")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
            }
        }
        .background(HeirloomColors.cream)
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
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(HeirloomColors.familyGreen)
                .font(.title3)

            Text(text)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.charcoal)

            Spacer()
        }
    }

    // MARK: - Plan Option

    private func planOption(productID: ProductIdentifier, price: String, trial: String, badge: String?) -> some View {
        Button {
            selectedProduct = productID
            // Adjust trial if needed
            if productID.isSubscription {
                subscriptionManager.adjustTrialForPlan(productID)
            }
        } label: {
            HStack(spacing: 16) {
                // Radio Button
                Image(systemName: selectedProduct == productID ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selectedProduct == productID ? HeirloomColors.tomato : HeirloomColors.warmGray)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(productID.displayName)
                            .font(HeirloomFonts.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(HeirloomColors.charcoal)

                        if let badge = badge {
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
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))

                    Text(price)
                        .font(HeirloomFonts.body)
                        .fontWeight(.medium)
                        .foregroundStyle(HeirloomColors.charcoal)
                }

                Spacer()
            }
            .padding(16)
            .background(.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        selectedProduct == productID ? HeirloomColors.tomato : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(color: HeirloomShadows.card.color, radius: HeirloomShadows.card.radius, x: 0, y: 2)
        }
    }

    // MARK: - CTA Text

    private var ctaText: String {
        // If user is upgrading
        if subscriptionManager.canUpgrade {
            return selectedProduct == .annual ? "Upgrade to Annual" : "Change Plan"
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
        isPurchasing = true

        Task { @MainActor in
            let result = await storeManager.purchase(selectedProduct)

            isPurchasing = false

            switch result {
            case .success:
                // Refresh subscription status
                await subscriptionManager.refreshStatus(force: true)
                dismiss()

            case .cancelled:
                // User cancelled - do nothing
                break

            case .pending:
                errorMessage = "Your purchase is pending approval. You'll be notified when it's complete."
                showError = true

            case .failed(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func dismissPaywall() {
        paywallManager.dismiss()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    PaywallView(trigger: .firstRecipeAdded)
}
