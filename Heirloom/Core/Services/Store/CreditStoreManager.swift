//
//  CreditStoreManager.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-03.
//

import Foundation
import StoreKit
import Observation
import SwiftData

/// Product identifiers for Heirloom credit purchases
enum CreditProductIdentifier: String, CaseIterable {
    case credits25 = "com.rationaledesign.heirloom.credits.small.v2"
    case credits100 = "com.rationaledesign.heirloom.credits.large.v2"

    var displayName: String {
        switch self {
        case .credits25: return "25 Credits"
        case .credits100: return "100 Credits"
        }
    }

    var displayPrice: String {
        switch self {
        case .credits25: return "$5"
        case .credits100: return "$15"
        }
    }

    var creditAmount: Int {
        switch self {
        case .credits25: return 25
        case .credits100: return 100
        }
    }

    var isPopular: Bool {
        switch self {
        case .credits25: return true  // Most popular tier
        case .credits100: return false
        }
    }
}

/// Errors that can occur during credit purchases
enum CreditStoreError: LocalizedError {
    case productNotFound(CreditProductIdentifier)
    case purchaseFailed(String)
    case purchaseCancelled
    case verificationFailed
    case networkUnavailable
    case notImplemented(String)
    case unknownError(Error)
    case userCreditsNotFound

    var errorDescription: String? {
        switch self {
        case .productNotFound(let id):
            return "Credit pack '\(id.displayName)' not found"
        case .purchaseFailed(let reason):
            return "Purchase failed: \(reason)"
        case .purchaseCancelled:
            return "Purchase was cancelled"
        case .verificationFailed:
            return "Could not verify purchase"
        case .networkUnavailable:
            return "Network connection required"
        case .notImplemented(let feature):
            return "\(feature) is not yet implemented"
        case .unknownError(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        case .userCreditsNotFound:
            return "Could not find your credit account"
        }
    }
}

/// Purchase result for credit purchases
enum CreditPurchaseResult {
    case success(creditsAdded: Int, transaction: Transaction?)
    case cancelled
    case pending
    case failed(CreditStoreError)
}

@MainActor
@Observable
final class CreditStoreManager {

    // MARK: - Published State

    /// Available products from App Store
    private(set) var products: [CreditProductIdentifier: Product] = [:]

    /// Loading state
    private(set) var isLoading = false

    /// Current error (for UI display)
    private(set) var currentError: CreditStoreError?

    /// Active transaction listener task
    private var transactionListener: Task<Void, Never>?

    // MARK: - Dependencies

    private let logger: LoggingService
    private let analytics: AnalyticsService
    private let modelContext: ModelContext
    private let userId: String

    // MARK: - RevenueCat Integration

    /// Feature flag to enable/disable RevenueCat
    /// Set to true to use RevenueCat, false to use StoreKit directly
    private var isRevenueCatEnabled: Bool {
        return false  // TODO: Enable when RevenueCat is fully configured
        // UserDefaults.standard.bool(forKey: "feature_revenuecat_credits_enabled")
    }

    // MARK: - Debug Fake Purchases

    /// Debug flag to enable fake purchases (grants credits without payment)
    private let debugFakePurchasesKey = "debug_fake_credit_purchases_enabled"

    /// Check if fake purchases are enabled (defaults to TRUE for easy testing)
    var isFakePurchasesEnabled: Bool {
        if UserDefaults.standard.object(forKey: debugFakePurchasesKey) == nil {
            return true  // Default to true for development
        }
        return UserDefaults.standard.bool(forKey: debugFakePurchasesKey)
    }

    // MARK: - Initialization

    init(
        logger: LoggingService,
        analytics: AnalyticsService,
        modelContext: ModelContext,
        userId: String
    ) {
        self.logger = logger
        self.analytics = analytics
        self.modelContext = modelContext
        self.userId = userId

        logger.log("CreditStoreManager initialized", category: .store, level: .info, metadata: [
            "userId": userId
        ])

        // Start listening for transactions immediately
        startTransactionListener()
    }

    deinit {
        // Task will be automatically cancelled when CreditStoreManager is deallocated
    }

    // MARK: - Product Loading

    /// Load credit products from App Store
    func loadProducts() async {
        guard !isLoading else { return }

        isLoading = true
        currentError = nil

        do {
            logger.log("Loading credit products", category: .store, level: .info, metadata: nil)

            // Load products from StoreKit
            let identifiers = CreditProductIdentifier.allCases.map { $0.rawValue }
            let storeProducts = try await Product.products(for: Set(identifiers))

            // Map to dictionary
            var productMap: [CreditProductIdentifier: Product] = [:]
            for product in storeProducts {
                if let identifier = CreditProductIdentifier(rawValue: product.id) {
                    productMap[identifier] = product
                }
            }

            products = productMap

            logger.log("Loaded \(productMap.count) credit products", category: .store, level: .info, metadata: [
                "count": productMap.count
            ])

        } catch {
            logger.log("Failed to load credit products", category: .store, level: .error, metadata: [
                "error": error.localizedDescription
            ])
            currentError = .unknownError(error)
        }

        isLoading = false
    }

    // MARK: - Purchase Flow

    /// Purchase credits
    /// - Parameter productID: The credit pack to purchase
    /// - Returns: Purchase result with credits added
    func purchase(_ productID: CreditProductIdentifier) async -> CreditPurchaseResult {

        // DEBUG: Fake purchases for testing
        if isFakePurchasesEnabled {
            return await performFakePurchase(productID)
        }

        guard let product = products[productID] else {
            logger.log("Product not found", category: .store, level: .error, metadata: [
                "productID": productID.rawValue
            ])
            return .failed(.productNotFound(productID))
        }

        analytics.track(event: .purchaseStarted, properties: [
            "product": productID.rawValue,
            "credits": productID.creditAmount,
            "provider": isRevenueCatEnabled ? "revenuecat" : "storekit"
        ])

        if isRevenueCatEnabled {
            return await purchaseViaRevenueCat(productID, product: product)
        } else {
            return await purchaseViaStoreKit(product: product, productID: productID)
        }
    }

    /// Purchase via StoreKit (direct)
    private func purchaseViaStoreKit(product: Product, productID: CreditProductIdentifier) async -> CreditPurchaseResult {
        do {
            logger.log("Starting StoreKit purchase", category: .store, level: .info, metadata: [
                "product": productID.rawValue
            ])

            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Verify transaction
                guard let transaction = try? verification.payloadValue else {
                    logger.log("Transaction verification failed", category: .store, level: .error, metadata: nil)
                    return .failed(.verificationFailed)
                }

                // Add credits to user account
                let creditsAdded = try await addCreditsToAccount(
                    amount: productID.creditAmount,
                    transaction: transaction
                )

                // Finish transaction
                await transaction.finish()

                analytics.track(event: .purchaseSuccess, properties: [
                    "product": productID.rawValue,
                    "credits": creditsAdded,
                    "transactionId": transaction.id
                ])

                logger.log("Purchase successful", category: .store, level: .info, metadata: [
                    "credits": creditsAdded,
                    "transactionId": transaction.id
                ])

                return .success(creditsAdded: creditsAdded, transaction: transaction)

            case .userCancelled:
                logger.log("Purchase cancelled by user", category: .store, level: .info, metadata: nil)
                return .cancelled

            case .pending:
                logger.log("Purchase pending", category: .store, level: .info, metadata: nil)
                return .pending

            @unknown default:
                logger.log("Unknown purchase result", category: .store, level: .error, metadata: nil)
                return .failed(.unknownError(NSError(domain: "CreditStore", code: -1)))
            }

        } catch {
            logger.log("Purchase failed", category: .store, level: .error, metadata: [
                "error": error.localizedDescription
            ])
            return .failed(.unknownError(error))
        }
    }

    /// Purchase via RevenueCat (TODO: Implement when RevenueCat is configured)
    private func purchaseViaRevenueCat(_ productID: CreditProductIdentifier, product: Product) async -> CreditPurchaseResult {
        logger.log("RevenueCat purchase not yet implemented", category: .store, level: .warning, metadata: nil)

        // TODO: Implement RevenueCat purchase flow
        // 1. Get RevenueCat package for product
        // 2. Call Purchases.shared.purchase(package:)
        // 3. On success, add credits to user account
        // 4. Track analytics

        return .failed(.notImplemented("RevenueCat purchase flow"))
    }

    /// DEBUG ONLY: Perform fake purchase for testing
    private func performFakePurchase(_ productID: CreditProductIdentifier) async -> CreditPurchaseResult {
        logger.log("⚠️ DEBUG: Performing fake credit purchase", category: .store, level: .warning, metadata: [
            "product": productID.rawValue,
            "credits": productID.creditAmount
        ])

        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        do {
            // Add credits directly (no real transaction)
            let creditsAdded = try await addCreditsToAccount(
                amount: productID.creditAmount,
                transaction: nil // No real transaction
            )

            analytics.track(event: .purchaseSuccess, properties: [
                "product": productID.rawValue,
                "credits": creditsAdded,
                "fake": true
            ])

            logger.log("⚠️ DEBUG: Fake purchase successful", category: .store, level: .warning, metadata: [
                "credits": creditsAdded
            ])

            // Return success without transaction (fake purchase)
            return .success(creditsAdded: creditsAdded, transaction: nil)

        } catch {
            return .failed(.unknownError(error))
        }
    }

    // MARK: - Credit Management

    /// Add credits to user's account
    /// - Parameters:
    ///   - amount: Number of credits to add
    ///   - transaction: Optional transaction (for receipt validation)
    /// - Returns: Number of credits added
    private func addCreditsToAccount(amount: Int, transaction: Transaction?) async throws -> Int {

        // Fetch user credits
        var descriptor = FetchDescriptor<UserCredits>()
        descriptor.predicate = #Predicate<UserCredits> { credits in
            credits.userId == userId
        }

        let userCredits = try modelContext.fetch(descriptor).first

        guard let userCredits = userCredits else {
            // Create new UserCredits if doesn't exist
            let newUserCredits = UserCredits(userId: userId)
            modelContext.insert(newUserCredits)
            newUserCredits.addPurchasedCredits(amount)
            try modelContext.save()
            return amount
        }

        // Add credits
        userCredits.addPurchasedCredits(amount)
        try modelContext.save()

        logger.log("Credits added to account", category: .store, level: .info, metadata: [
            "amount": amount,
            "newBalance": userCredits.creditsBalance,
            "totalAvailable": userCredits.availableCredits,
            "transactionId": transaction?.id ?? "none"
        ])

        return amount
    }

    /// Get current credit balance
    func getCurrentBalance() async -> Int {
        do {
            var descriptor = FetchDescriptor<UserCredits>()
            descriptor.predicate = #Predicate<UserCredits> { credits in
                credits.userId == userId
            }

            let userCredits = try modelContext.fetch(descriptor).first
            return userCredits?.availableToday ?? 0

        } catch {
            logger.log("Failed to fetch credit balance", category: .store, level: .error, metadata: [
                "error": error.localizedDescription
            ])
            return 0
        }
    }

    // MARK: - Transaction Listener

    /// Start listening for transaction updates (auto-renewal, refunds, etc.)
    private func startTransactionListener() {
        transactionListener = Task(priority: .background) { [weak self] in
            guard let self = self else { return }

            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else {
                    self.logger.log("Unverified transaction received", category: .store, level: .warning, metadata: nil)
                    continue
                }

                self.logger.log("Transaction update received", category: .store, level: .info, metadata: [
                    "transactionId": transaction.id,
                    "productId": transaction.productID
                ])

                // Handle transaction (e.g., credit purchase completed in background)
                await self.handleTransactionUpdate(transaction)

                // Finish transaction
                await transaction.finish()
            }
        }
    }

    /// Handle transaction updates from StoreKit
    private func handleTransactionUpdate(_ transaction: Transaction) async {
        // Determine product and add credits if needed
        guard let productID = CreditProductIdentifier(rawValue: transaction.productID) else {
            logger.log("Unknown product in transaction", category: .store, level: .warning, metadata: [
                "productId": transaction.productID
            ])
            return
        }

        do {
            _ = try await addCreditsToAccount(
                amount: productID.creditAmount,
                transaction: transaction
            )
        } catch {
            logger.log("Failed to add credits from transaction update", category: .store, level: .error, metadata: [
                "error": error.localizedDescription
            ])
        }
    }
}
