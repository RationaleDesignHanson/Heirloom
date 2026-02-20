//
//  ManagePlanView.swift
//  Heirloom
//
//  Custom subscription management screen that shows before Apple's sheet
//  Prominently features Lifetime option which Apple's sheet doesn't show
//

import SwiftUI
import StoreKit
import SwiftData

struct ManagePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var subscriptionManager = ServiceContainer.shared.resolve(SubscriptionManager.self)
    @State private var storeManager = ServiceContainer.shared.resolve(StoreManager.self)
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showError = false
    @State private var showCreditsStore = false
    @State private var isRestoringPurchases = false
    @State private var showRestoreSuccess = false
    @State private var restoreMessage = ""

    private var currentPlanName: String {
        subscriptionManager.currentPlanName ?? "Free"
    }

    // MARK: - Price Helpers

    private var lifetimePrice: String {
        storeManager.products[.lifetime]?.displayPrice ?? "$99.99"
    }

    private var annualPrice: String {
        storeManager.products[.annual]?.displayPrice ?? "$29.99"
    }

    private var monthlyPrice: String {
        storeManager.products[.monthly]?.displayPrice ?? "$4.99"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.lg) {
                    // Current Plan Card
                    currentPlanCard
                        .padding(.top, HeirloomSpacing.md)

                    // Upgrade Options (show if not lifetime)
                    if subscriptionManager.status != .lifetime {
                        upgradeOptionsSection
                    } else {
                        // Lifetime users just see credits option
                        creditsSection
                    }

                    // Manage with Apple (for cancellation/billing - subscribers only)
                    if subscriptionManager.isPremiumActual && subscriptionManager.status != .lifetime {
                        appleManagementSection
                    }

                    // Restore Purchases (always show)
                    restorePurchasesSection

                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
            }
            .background(HeirloomColors.cream.ignoresSafeArea())
            .navigationTitle("Your Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showCreditsStore) {
                creditsStoreSheet
            }
            .alert("Purchase Error", isPresented: $showError) {
                Button("OK") { showError = false }
            } message: {
                Text(purchaseError ?? "Something went wrong")
            }
            .alert("Purchases Restored", isPresented: $showRestoreSuccess) {
                Button("OK") { showRestoreSuccess = false }
            } message: {
                Text(restoreMessage)
            }
            .overlay {
                if isPurchasing {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView("Processing...")
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                    }
                }
            }
            .task {
                // Delay to ensure sheet presentation animation completes
                // before making any state changes that could conflict with SwiftUI
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                // Load products if not already loaded
                if storeManager.products.isEmpty {
                    try? await storeManager.loadProducts()
                }

                // Refresh subscription status (moved from SettingsView to avoid presentation conflicts)
                await subscriptionManager.refreshStatus(force: true)
            }
        }
    }

    // MARK: - Credits Store Sheet

    @ViewBuilder
    private var creditsStoreSheet: some View {
        if let userId = ServiceContainer.shared.resolve(FirebaseAuthService.self).currentUserId {
            let creditStoreManager = CreditStoreManager(
                logger: ServiceContainer.shared.resolve(LoggingService.self),
                analytics: ServiceContainer.shared.resolve(AnalyticsService.self),
                modelContext: modelContext,
                userId: userId
            )
            CreditsStoreView(storeManager: creditStoreManager)
        }
    }

    // MARK: - Current Plan Card

    private var currentPlanCard: some View {
        VStack(spacing: HeirloomSpacing.md) {
            // Plan icon
            ZStack {
                Circle()
                    .fill(planIconBackground)
                    .frame(width: 64, height: 64)

                Image(systemName: planIcon)
                    .font(.system(size: 28))
                    .foregroundStyle(planIconColor)
            }

            // Plan name
            Text(currentPlanName)
                .font(.title2.bold())
                .foregroundStyle(HeirloomColors.primaryText)

            // Plan description
            Text(planDescription)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)

            // Renewal info
            if let dateText = renewalDateText {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(dateText)
                        .font(HeirloomFonts.caption1)
                }
                .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
        .padding(HeirloomSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Upgrade Options

    private var upgradeOptionsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text(subscriptionManager.isPremiumActual ? "Upgrade Your Plan" : "Choose a Plan")
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
                .padding(.leading, 4)

            VStack(spacing: HeirloomSpacing.sm) {
                // Lifetime - Always featured prominently
                lifetimeCard

                // Annual - show for non-subscribers (free, expired, trial) OR monthly users who can upgrade
                // Trial users should see all options since they haven't subscribed yet
                let showAnnual = !subscriptionManager.status.isSubscription || subscriptionManager.canUpgradeToAnnual
                if showAnnual {
                    annualCard
                }

                // Monthly - only for non-subscribers (free, expired, trial)
                // Trial users should see all options since they haven't subscribed yet
                let showMonthly = !subscriptionManager.status.isSubscription
                if showMonthly {
                    monthlyCard
                }
            }

            // Credits section
            creditsButton
        }
    }

    // MARK: - Credits Section (for Lifetime users)

    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("Credits")
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
                .padding(.leading, 4)

            creditsButton
        }
    }

    private var creditsButton: some View {
        Button {
            showCreditsStore = true
        } label: {
            HStack {
                Image(systemName: "giftcard.fill")
                    .font(.title3)
                    .foregroundStyle(HeirloomColors.familyGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Buy Credits")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)
                    Text("For importing cookbooks, videos & more")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Plan Cards

    private var lifetimeCard: some View {
        Button {
            Task { await purchase(.lifetime) }
        } label: {
            VStack(spacing: 0) {
                // Featured badge
                HStack {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text("BEST VALUE")
                        .font(.caption2.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(HeirloomColors.tomato)

                // Card content
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(HeirloomColors.tomato)
                            Text("Lifetime")
                                .font(.headline)
                                .foregroundStyle(HeirloomColors.primaryText)
                        }
                        Text("One-time purchase, yours forever")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(lifetimePrice)
                            .font(.title3.bold())
                            .foregroundStyle(HeirloomColors.tomato)
                        Text("once")
                            .font(.caption2)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }
                .padding()
            }
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(HeirloomColors.tomato, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var annualCard: some View {
        Button {
            Task { await purchase(.annual) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.green)
                        Text("Annual")
                            .font(.headline)
                            .foregroundStyle(HeirloomColors.primaryText)
                    }
                    Text("Save 50% vs monthly")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(.green)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(annualPrice)
                        .font(.title3.bold())
                        .foregroundStyle(HeirloomColors.primaryText)
                    Text("/year")
                        .font(.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var monthlyCard: some View {
        Button {
            Task { await purchase(.monthly) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "repeat")
                            .foregroundStyle(HeirloomColors.secondaryText)
                        Text("Monthly")
                            .font(.headline)
                            .foregroundStyle(HeirloomColors.primaryText)
                    }
                    Text("Flexible, cancel anytime")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(monthlyPrice)
                        .font(.title3.bold())
                        .foregroundStyle(HeirloomColors.primaryText)
                    Text("/month")
                        .font(.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Apple Management Section

    private var appleManagementSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text("Billing & Cancellation")
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
                .padding(.leading, 4)

            Button {
                openAppleSubscriptionManagement()
            } label: {
                HStack {
                    Image(systemName: "apple.logo")
                        .foregroundStyle(HeirloomColors.primaryText)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage with Apple")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.primaryText)
                        Text("Change billing, cancel subscription")
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.caption)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            // Note about Lifetime
            Text("Note: Lifetime is a one-time purchase and won't appear in Apple's subscription list.")
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.secondaryText)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Restore Purchases Section

    private var restorePurchasesSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Button {
                Task { await restorePurchases() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(HeirloomColors.primaryText)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isRestoringPurchases ? "Restoring..." : "Restore Purchases")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.primaryText)
                        Text("Recover purchases from another device")
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                    Spacer()
                    if isRestoringPurchases {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(isRestoringPurchases)
        }
    }

    // MARK: - Computed Properties

    private var planIcon: String {
        switch subscriptionManager.status {
        case .lifetime: return "crown.fill"
        case .annual: return "calendar"
        case .monthly: return "repeat"
        case .trial: return "clock.fill"
        default: return "person.fill"
        }
    }

    private var planIconColor: Color {
        switch subscriptionManager.status {
        case .lifetime: return HeirloomColors.tomato
        case .annual, .monthly: return HeirloomColors.familyGreen
        case .trial: return .orange
        default: return HeirloomColors.secondaryText
        }
    }

    private var planIconBackground: Color {
        planIconColor.opacity(0.15)
    }

    private var planDescription: String {
        switch subscriptionManager.status {
        case .lifetime:
            return "You have lifetime access to all premium features"
        case .annual:
            return "Annual subscription with all premium features"
        case .monthly:
            return "Monthly subscription with all premium features"
        case .trial:
            return "Exploring Heirloom with limited features"
        default:
            return "Upgrade to unlock all features"
        }
    }

    private var renewalDateText: String? {
        guard subscriptionManager.isPremiumActual,
              subscriptionManager.status != .lifetime else { return nil }

        if let date = subscriptionManager.subscriptionExpiryDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Renews \(formatter.string(from: date))"
        }
        return nil
    }

    // MARK: - Actions

    private func purchase(_ productID: ProductIdentifier) async {
        isPurchasing = true
        defer { isPurchasing = false }

        // Mark that user is initiating a purchase (for demo account handling)
        // This ensures the purchase notification is recognized as user-initiated
        // Pass the product ID so we can distinguish from background transactions for other products
        subscriptionManager.markPurchaseStarted(for: productID)

        let result = await storeManager.purchase(productID)

        switch result {
        case .success:
            await subscriptionManager.refreshStatus(force: true)
            dismiss()

        case .cancelled:
            // User cancelled - no action needed
            break

        case .pending:
            purchaseError = "Your purchase is pending approval."
            showError = true

        case .failed(let error):
            purchaseError = error.localizedDescription
            showError = true
        }
    }

    private func openAppleSubscriptionManagement() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }

        Task {
            try? await AppStore.showManageSubscriptions(in: windowScene)
            await subscriptionManager.refreshStatus(force: true)
        }
    }

    private func restorePurchases() async {
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }

        do {
            let transactions = try await storeManager.restorePurchases()

            if !transactions.isEmpty {
                await subscriptionManager.refreshStatus(force: true)
                restoreMessage = "Your subscription has been restored successfully."
                showRestoreSuccess = true
            } else {
                restoreMessage = "No previous purchases found to restore."
                showRestoreSuccess = true
            }
        } catch {
            purchaseError = "Failed to restore purchases: \(error.localizedDescription)"
            showError = true
        }
    }
}

#Preview {
    ManagePlanView()
}
