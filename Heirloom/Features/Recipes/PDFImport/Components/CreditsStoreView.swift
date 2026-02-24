//
//  CreditsStoreView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-03.
//

import SwiftUI
import StoreKit

/// Purchase credits UI
/// - Shows available credit packs
/// - Current balance
/// - Purchase flow
/// - Option to subscribe for users with expired subscriptions
struct CreditsStoreView: View {

    // MARK: - Properties

    @State private var storeManager: CreditStoreManager
    @State private var subscriptionStoreManager: StoreManager
    @State private var subscriptionManager: SubscriptionManager
    let userCredits: UserCredits?
    @Environment(\.dismiss) private var dismiss

    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var showPaywall = false

    /// Whether to show the subscription upsell (for non-premium users)
    private var showSubscriptionOption: Bool {
        !subscriptionManager.isPremium
    }

    // MARK: - Initialization

    init(storeManager: CreditStoreManager, userCredits: UserCredits? = nil) {
        _storeManager = State(initialValue: storeManager)
        _subscriptionStoreManager = State(initialValue: ServiceContainer.shared.resolve(StoreManager.self))
        _subscriptionManager = State(initialValue: ServiceContainer.shared.resolve(SubscriptionManager.self))
        self.userCredits = userCredits
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Compact Header: Icon + Title inline
                    HStack(spacing: 12) {
                        Image(systemName: "giftcard.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(HeirloomColors.familyGreen.gradient)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Purchase Credits")
                                .font(.title2.bold())

                            Text("Import without waiting")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 4)

                    // Current Balance Card
                    CurrentBalanceCard(
                        balance: userCredits?.availableCredits ?? 0,
                        subscriptionCredits: userCredits?.tierCreditsRemaining ?? 0,
                        purchasedCredits: userCredits?.creditsBalance ?? 0
                    )

                    // Purchase Options
                    VStack(spacing: 12) {
                        ForEach(CreditProductIdentifier.allCases, id: \.self) { productID in
                            CreditPurchaseButton(
                                productID: productID,
                                product: storeManager.products[productID],
                                isProcessing: isProcessing
                            ) {
                                await purchaseCredits(productID)
                            }
                        }
                    }

                    // Subscription Upsell (for non-premium users) - moved ABOVE info section
                    if showSubscriptionOption {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(HeirloomColors.tomato)
                                Text("Or Subscribe for More")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                            }

                            Text("Premium: monthly credits, URL import, cookbook scanning & sync")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                showPaywall = true
                            } label: {
                                HStack {
                                    Image(systemName: "crown.fill")
                                    Text("View Premium Plans")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(HeirloomColors.tomato)
                                .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(HeirloomColors.tomato.opacity(0.08))
                        .cornerRadius(12)
                    }

                    // Info Section (collapsed)
                    DisclosureGroup {
                        VStack(spacing: 8) {
                            InfoRow(icon: "checkmark.circle.fill", text: "Credits never expire")
                            InfoRow(icon: "arrow.clockwise.circle.fill", text: "Roll over to the next day")
                            InfoRow(icon: "doc.text.fill", text: "Text PDFs: 1 credit")
                            InfoRow(icon: "doc.viewfinder.fill", text: "Scanned PDFs: 5 credits")
                            InfoRow(icon: "book.closed.fill", text: "Cookbook scans: 5 credits each")
                            InfoRow(icon: "video.fill", text: "Video transcription: 5 credits")
                        }
                    } label: {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(HeirloomColors.familyGreen)
                            Text("Credit usage info")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Debug toggle (if enabled)
                    if storeManager.isFakePurchasesEnabled {
                        VStack(spacing: 8) {
                            Text("⚠️ DEBUG MODE")
                                .font(.caption.bold())
                                .foregroundColor(.orange)

                            Text("Purchases are simulated and free")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Purchase Successful", isPresented: $showSuccess) {
                Button("OK") {
                    showSuccess = false
                    // CRITICAL: Reset paywall state to prevent any lingering sheet issues
                    showPaywall = false
                    dismiss()
                }
            } message: {
                Text("Your credits have been added to your account")
            }
            .alert("Purchase Failed", isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .sheet(isPresented: $showPaywall, onDismiss: {
                // Log when PaywallView is dismissed to track any lingering state issues
                Log.info("PaywallView dismissed from CreditsStoreView", category: .store)
            }) {
                PaywallView(trigger: .urlImport)
                    .onAppear {
                        Log.info("PaywallView opened from CreditsStoreView", category: .store)
                        DeviceLogger.shared.log("💳 [CreditsStore] PaywallView sheet opened", level: .info)
                    }
            }
            .task {
                // Load products when view appears
                await storeManager.loadProducts()
            }
            .overlay {
                if isProcessing {
                    ProgressView("Processing purchase...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Actions

    private func purchaseCredits(_ productID: CreditProductIdentifier) async {
        isProcessing = true

        let result = await storeManager.purchase(productID)

        isProcessing = false

        switch result {
        case .success(let creditsAdded, _):
            showSuccess = true
            Log.info("Credits purchased successfully", category: .store, metadata: [
                "credits": creditsAdded
            ])

        case .cancelled:
            // User cancelled - no action needed
            break

        case .pending:
            errorMessage = "Your purchase is pending. You'll receive your credits soon."
            showError = true

        case .failed(let error):
            errorMessage = error.errorDescription
            showError = true
            Log.error("Credit purchase failed", category: .store, error: error, metadata: [
                "product": productID.rawValue
            ])
        }
    }
}

// MARK: - Current Balance Card

struct CurrentBalanceCard: View {
    let balance: Int
    var subscriptionCredits: Int = 0
    var purchasedCredits: Int = 0

    /// Show breakdown only when there are both types of credits
    private var showBreakdown: Bool {
        subscriptionCredits > 0 || purchasedCredits > 0
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BALANCE")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        Text("\(balance)")
                            .font(.system(size: 32, weight: .bold))
                        Text("credits")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "giftcard.fill")
                    .font(.system(size: 28))
                    .foregroundColor(HeirloomColors.familyGreen)
            }

            // Breakdown of credit sources
            if showBreakdown {
                Divider()

                HStack(spacing: 16) {
                    if subscriptionCredits > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundColor(HeirloomColors.tomato)
                            Text("\(subscriptionCredits) subscription")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if purchasedCredits > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "bag.fill")
                                .font(.caption)
                                .foregroundColor(HeirloomColors.familyGreen)
                            Text("\(purchasedCredits) purchased")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Credit Purchase Button

struct CreditPurchaseButton: View {
    let productID: CreditProductIdentifier
    let product: Product?
    let isProcessing: Bool
    let onPurchase: () async -> Void

    @State private var showConfirmation = false

    var body: some View {
        Button {
            showConfirmation = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(productID.displayName)
                            .font(.headline)

                        if productID.isPopular {
                            Text("Popular")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(HeirloomColors.familyGreen)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }

                    Text("\(productID.creditAmount) credits for instant import")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(product?.displayPrice ?? productID.displayPrice)
                    .font(.title3.bold())
                    .foregroundColor(HeirloomColors.familyGreen)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(productID.isPopular ? HeirloomColors.familyGreen.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(productID.isPopular ? HeirloomColors.familyGreen : Color.clear, lineWidth: 2)
            )
        }
        .disabled(isProcessing)
        .opacity(isProcessing ? 0.6 : 1.0)
        .confirmationDialog(
            "Purchase \(productID.displayName)",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Buy for \(product?.displayPrice ?? productID.displayPrice)") {
                Task {
                    await onPurchase()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll receive \(productID.creditAmount) credits to use for importing cookbooks.")
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(HeirloomColors.familyGreen)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    // Preview not available - requires service container initialization
    Text("CreditsStoreView Preview")
        .font(.title)
}
