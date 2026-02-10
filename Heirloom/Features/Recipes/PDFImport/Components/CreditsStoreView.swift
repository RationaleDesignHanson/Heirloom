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
struct CreditsStoreView: View {

    // MARK: - Properties

    @State private var storeManager: CreditStoreManager
    let userCredits: UserCredits?
    @Environment(\.dismiss) private var dismiss

    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    // MARK: - Initialization

    init(storeManager: CreditStoreManager, userCredits: UserCredits? = nil) {
        _storeManager = State(initialValue: storeManager)
        self.userCredits = userCredits
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // Header Icon
                    Image(systemName: "giftcard.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(HeirloomColors.familyGreen.gradient)
                        .padding(.top, 20)

                    // Title & Description
                    VStack(spacing: 8) {
                        Text("Purchase Credits")
                            .font(.title.bold())

                        Text("Import more cookbooks without waiting for your monthly tier credits to reset")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Current Balance Card
                    CurrentBalanceCard(balance: userCredits?.availableCredits ?? 0)

                    // Purchase Options
                    VStack(spacing: 16) {

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

                    // Info Section
                    VStack(spacing: 12) {
                        InfoRow(
                            icon: "checkmark.circle.fill",
                            text: "Credits never expire"
                        )

                        InfoRow(
                            icon: "arrow.clockwise.circle.fill",
                            text: "Roll over to the next day"
                        )

                        InfoRow(
                            icon: "doc.text.fill",
                            text: "Text-rich PDFs cost only 1 credit"
                        )

                        InfoRow(
                            icon: "doc.viewfinder.fill",
                            text: "Scanned PDFs cost 5 credits"
                        )
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

    var body: some View {
        VStack(spacing: 8) {
            Text("CURRENT BALANCE")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "giftcard.fill")
                    .foregroundColor(HeirloomColors.familyGreen)
                Text("\(balance)")
                    .font(.system(size: 48, weight: .bold))
                Text("credits")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Credit Purchase Button

struct CreditPurchaseButton: View {
    let productID: CreditProductIdentifier
    let product: Product?
    let isProcessing: Bool
    let onPurchase: () async -> Void

    @State private var isPurchasing = false

    var body: some View {
        Button {
            Task {
                await onPurchase()
            }
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
