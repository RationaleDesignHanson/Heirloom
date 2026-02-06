//
//  StoreManager.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-08.
//

import Foundation
import StoreKit
import Observation

/// Product identifiers for Heirloom subscriptions
enum ProductIdentifier: String, CaseIterable {
    case monthly = "com.rationalestudio.heirloom.monthly"
    case annual = "com.rationalestudio.heirloom.annual"
    case lifetime = "com.rationalestudio.heirloom.lifetime"

    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        case .lifetime: return "Lifetime"
        }
    }

    var isSubscription: Bool {
        switch self {
        case .monthly, .annual: return true
        case .lifetime: return false
        }
    }
}

/// Errors that can occur during StoreKit operations
enum StoreError: LocalizedError {
    case productNotFound(ProductIdentifier)
    case purchaseFailed(String)
    case purchaseCancelled
    case verificationFailed
    case networkUnavailable
    case notImplemented(String)
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .productNotFound(let id):
            return "Product '\(id.displayName)' not found in App Store"
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
        }
    }
}

/// Purchase result with detailed status
enum PurchaseResult {
    case success(Transaction)
    case cancelled
    case pending
    case failed(StoreError)
}

@MainActor
@Observable
final class StoreManager {

    // MARK: - Published State

    /// Available products from App Store
    private(set) var products: [ProductIdentifier: Product] = [:]

    /// Loading state
    private(set) var isLoading = false

    /// Current error (for UI display)
    private(set) var currentError: StoreError?

    /// Active transaction listener task
    private var transactionListener: Task<Void, Never>?

    // MARK: - Dependencies

    private let logger: LoggingService
    private let analytics: AnalyticsService

    // MARK: - RevenueCat Integration Point
    // ============================================================================
    // **TO SWAP FROM STOREKIT TO REVENUECAT:**
    //
    // 1. Change this flag to `true`:
    /// Feature flag to enable/disable RevenueCat
    private var isRevenueCatEnabled: Bool {
        return false  // Change to `true` to enable RevenueCat
        // UserDefaults.standard.bool(forKey: "feature_revenuecat_enabled")
    }
    //
    // 2. Implement `purchaseViaRevenueCat()` method (line ~233)
    // 3. Add RevenueCat SDK configuration in HeirloomApp.swift init()
    // 4. See RevenueCatPurchaseService.swift for complete integration guide
    //
    // All purchase flows will automatically route through RevenueCat!
    // ============================================================================

    // ⭐ NEW: Fake Payments (DEBUG ONLY - Remove before production)
    // MARK: - Fake Payments (Temporary Debug Feature)
    // TODO: Remove this entire section when real payment system is ready

    /// Debug flag to enable fake payments (grants premium without StoreKit transactions)
    private let debugFakePaymentsKey = "debug_fake_payments_enabled"

    /// Check if fake payments are enabled (defaults to TRUE for easy testing)
    var isFakePaymentsEnabled: Bool {
        // If key has never been set, default to true for testing convenience
        if UserDefaults.standard.object(forKey: debugFakePaymentsKey) == nil {
            return true
        }
        // Otherwise respect user's toggle choice
        return UserDefaults.standard.bool(forKey: debugFakePaymentsKey)
    }

    // MARK: - Initialization

    init(logger: LoggingService, analytics: AnalyticsService) {
        self.logger = logger
        self.analytics = analytics

        logger.log("StoreManager initialized", category: .store, level: .info, metadata: nil)

        // Start listening for transactions immediately
        startTransactionListener()
    }

    deinit {
        // Task will be automatically cancelled when StoreManager is deallocated
    }

    // MARK: - Product Loading

    /// Load products from App Store
    /// - Note: Call this on app launch and when entering store UI
    func loadProducts() async throws {
        isLoading = true
        currentError = nil

        logger.log("Loading products from App Store...", category: .store, level: .info, metadata: nil)

        do {
            let productIDs = ProductIdentifier.allCases.map(\.rawValue)
            let storeProducts = try await Product.products(for: productIDs)

            // Map products by identifier for easy lookup
            var productMap: [ProductIdentifier: Product] = [:]
            for product in storeProducts {
                if let identifier = ProductIdentifier(rawValue: product.id) {
                    productMap[identifier] = product
                    logger.log(
                        "Loaded product: \(product.displayName) - \(product.displayPrice)",
                        category: .store,
                        level: .debug,
                        metadata: nil
                    )
                }
            }

            self.products = productMap

            // Verify all products loaded
            let missing = ProductIdentifier.allCases.filter { productMap[$0] == nil }
            if !missing.isEmpty {
                let missingNames = missing.map(\.displayName).joined(separator: ", ")
                logger.log(
                    "Missing products: \(missingNames)",
                    category: .store,
                    level: .warning,
                    metadata: nil
                )
            }

            analytics.track(event: .storeProductsLoaded, properties: [
                "product_count": storeProducts.count,
                "missing_count": missing.count
            ])

            isLoading = false

        } catch {
            isLoading = false
            let storeError = StoreError.unknownError(error)
            currentError = storeError

            logger.log(
                "Failed to load products: \(error.localizedDescription)",
                category: .store,
                level: .error,
                metadata: nil
            )

            analytics.track(event: .storeLoadFailed, properties: [
                "error": error.localizedDescription
            ])

            throw storeError
        }
    }

    // MARK: - Purchase Flow

    /// Purchase a product
    /// - Parameter productID: Product to purchase
    /// - Returns: Purchase result with transaction details
    func purchase(_ productID: ProductIdentifier) async -> PurchaseResult {
        // ⭐ NEW: Check if fake payments are enabled (DEBUG ONLY)
        if isFakePaymentsEnabled {
            return await purchaseViaFake(productID)
        }

        // Check if RevenueCat is enabled
        if isRevenueCatEnabled {
            return await purchaseViaRevenueCat(productID)
        }

        // Otherwise use StoreKit 2
        return await purchaseViaStoreKit(productID)
    }

    /// RevenueCat purchase stub (not yet implemented)
    /// - Parameter productID: Product to purchase
    /// - Returns: Purchase result
    private func purchaseViaRevenueCat(_ productID: ProductIdentifier) async -> PurchaseResult {
        let error = StoreError.notImplemented("RevenueCat purchase flow")
        currentError = error

        logger.log(
            "RevenueCat purchase attempted but not implemented",
            category: .store,
            level: .warning,
            metadata: ["product": productID.rawValue]
        )

        analytics.track(event: .purchaseFailed, properties: [
            "product": productID.rawValue,
            "reason": "revenuecat_not_implemented"
        ])

        return .failed(error)
    }

    // ⭐ NEW: Fake purchase handler (DEBUG ONLY)
    /// Simulate a purchase without StoreKit transaction
    /// - Parameter productID: Product to "purchase"
    /// - Returns: Always succeeds with fake transaction
    private func purchaseViaFake(_ productID: ProductIdentifier) async -> PurchaseResult {
        logger.log("🎭 FAKE PURCHASE: \(productID.rawValue)", category: .store, level: .info, metadata: nil)

        // Simulate realistic purchase delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Update subscription status directly in UserDefaults
        let status: HeirloomSubscriptionStatus = switch productID {
        case .monthly: .monthly
        case .annual: .annual
        case .lifetime: .lifetime
        }

        // Persist fake subscription state
        UserDefaults.standard.set(status.rawValue, forKey: "subscription_status")
        UserDefaults.standard.set(productID.rawValue, forKey: "cached_product_id")

        // Set expiry dates for subscriptions (1 year from now for testing)
        if productID.isSubscription {
            let expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
            UserDefaults.standard.set(expiryDate, forKey: "subscription_expiry_date")
        }

        // Clear trial dates (now premium)
        UserDefaults.standard.removeObject(forKey: "trial_expiry_date")

        UserDefaults.standard.synchronize()

        // Post notification to trigger UI updates
        NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)

        // Track fake purchase in analytics
        analytics.track(event: .purchaseSuccess, properties: [
            "product_id": productID.rawValue,
            "fake_purchase": true,
            "price": 0
        ])

        logger.log(
            "🎭 Fake purchase completed: \(productID.displayName)",
            category: .store,
            level: .info,
            metadata: nil
        )

        // Return success (no actual transaction object, but that's okay for fake flow)
        return .pending // Using .pending as success indicator without transaction
    }

    /// StoreKit 2 purchase implementation
    /// - Parameter productID: Product to purchase
    /// - Returns: Purchase result with transaction details
    private func purchaseViaStoreKit(_ productID: ProductIdentifier) async -> PurchaseResult {
        guard let product = products[productID] else {
            let error = StoreError.productNotFound(productID)
            currentError = error

            logger.log(
                "Purchase failed: product not found \(productID.rawValue)",
                category: .store,
                level: .error,
                metadata: nil
            )

            analytics.track(event: .purchaseFailed, properties: [
                "product": productID.rawValue,
                "reason": "product_not_found"
            ])

            return .failed(error)
        }

        logger.log(
            "Starting purchase: \(product.displayName)",
            category: .store,
            level: .info,
            metadata: nil
        )

        analytics.track(event: .purchaseStarted, properties: [
            "product": productID.rawValue,
            "price": product.price
        ])

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Verify the transaction
                do {
                    let transaction = try checkVerified(verification)

                    // Finish the transaction
                    await transaction.finish()

                    logger.log(
                        "Purchase successful: \(product.displayName)",
                        category: .store,
                        level: .info,
                        metadata: nil
                    )

                    analytics.track(event: .purchaseSuccess, properties: [
                        "product": productID.rawValue,
                        "transaction_id": transaction.id,
                        "revenue": product.price
                    ])

                    return .success(transaction)

                } catch {
                    let storeError = StoreError.verificationFailed
                    currentError = storeError

                    logger.log(
                        "Purchase verification failed: \(error.localizedDescription)",
                        category: .store,
                        level: .error,
                        metadata: nil
                    )

                    analytics.track(event: .purchaseFailed, properties: [
                        "product": productID.rawValue,
                        "reason": "verification_failed"
                    ])

                    return .failed(storeError)
                }

            case .userCancelled:
                logger.log(
                    "Purchase cancelled by user",
                    category: .store,
                    level: .info,
                    metadata: nil
                )

                analytics.track(event: .purchaseCancelled, properties: [
                    "product": productID.rawValue
                ])

                return .cancelled

            case .pending:
                logger.log(
                    "Purchase pending approval (Ask to Buy)",
                    category: .store,
                    level: .info,
                    metadata: nil
                )

                analytics.track(event: .purchasePending, properties: [
                    "product": productID.rawValue
                ])

                return .pending

            @unknown default:
                let error = StoreError.unknownError(NSError(domain: "StoreKit", code: -1))
                currentError = error

                logger.log(
                    "Unknown purchase result",
                    category: .store,
                    level: .error,
                    metadata: nil
                )

                return .failed(error)
            }

        } catch {
            let storeError = StoreError.purchaseFailed(error.localizedDescription)
            currentError = storeError

            logger.log(
                "Purchase error: \(error.localizedDescription)",
                category: .store,
                level: .error,
                metadata: nil
            )

            analytics.track(event: .purchaseFailed, properties: [
                "product": productID.rawValue,
                "error": error.localizedDescription
            ])

            return .failed(storeError)
        }
    }

    // MARK: - Restore Purchases

    /// Restore previous purchases
    /// - Returns: Array of restored transactions
    func restorePurchases() async throws -> [Transaction] {
        // ⭐ NEW: Handle fake restore (DEBUG ONLY)
        if isFakePaymentsEnabled {
            logger.log("🎭 FAKE RESTORE: Checking fake subscription status", category: .store, level: .info, metadata: nil)

            // Check if user has fake subscription active
            if let statusRaw = UserDefaults.standard.string(forKey: "subscription_status"),
               let status = HeirloomSubscriptionStatus(rawValue: statusRaw),
               status.isPremium {

                // Post notification to trigger refresh (fake subscription already in UserDefaults)
                NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)

                logger.log("🎭 Fake restore: Found active subscription", category: .store, level: .info, metadata: nil)
            } else {
                logger.log("🎭 Fake restore: No active subscription", category: .store, level: .info, metadata: nil)
            }

            // Return empty array (no real transactions)
            return []
        }

        logger.log("Restoring purchases...", category: .store, level: .info, metadata: nil)

        analytics.track(event: .restoreStarted)

        var restoredTransactions: [Transaction] = []

        // Iterate through all transactions for the user
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Only add active transactions
                if transaction.revocationDate == nil && !transaction.isUpgraded {
                    restoredTransactions.append(transaction)

                    logger.log(
                        "Restored: \(transaction.productID)",
                        category: .store,
                        level: .debug,
                        metadata: nil
                    )
                }
            } catch {
                logger.log(
                    "Failed to verify restored transaction: \(error.localizedDescription)",
                    category: .store,
                    level: .warning,
                    metadata: nil
                )
            }
        }

        logger.log(
            "Restored \(restoredTransactions.count) purchases",
            category: .store,
            level: .info,
            metadata: nil
        )

        analytics.track(event: .restoreCompleted, properties: [
            "restored_count": restoredTransactions.count
        ])

        return restoredTransactions
    }

    // MARK: - Subscription Status

    /// Get current subscription status from StoreKit
    /// - Returns: Active transaction for highest-tier subscription, or nil
    func getCurrentSubscription() async -> Transaction? {
        // Check all current entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Filter for Heirloom products
                guard ProductIdentifier(rawValue: transaction.productID) != nil else {
                    continue
                }

                // Check if not revoked or upgraded
                guard transaction.revocationDate == nil && !transaction.isUpgraded else {
                    continue
                }

                logger.log(
                    "Found active subscription: \(transaction.productID)",
                    category: .store,
                    level: .debug,
                    metadata: nil
                )

                return transaction

            } catch {
                logger.log(
                    "Failed to verify transaction: \(error.localizedDescription)",
                    category: .store,
                    level: .warning,
                    metadata: nil
                )
            }
        }

        return nil
    }

    /// Check if user has lifetime purchase
    func hasLifetimePurchase() async -> Bool {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                if transaction.productID == ProductIdentifier.lifetime.rawValue,
                   transaction.revocationDate == nil {
                    return true
                }
            } catch {
                continue
            }
        }

        return false
    }

    // MARK: - Transaction Listener

    /// Start listening for transaction updates (renewals, cancellations, etc.)
    private func startTransactionListener() {
        transactionListener = Task(priority: .background) { [weak self] in
            guard let self = self else { return }

            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    self.logger.log(
                        "Transaction updated: \(transaction.productID)",
                        category: .store,
                        level: .info,
                        metadata: nil
                    )

                    // Notify SubscriptionManager of change
                    NotificationCenter.default.post(
                        name: .subscriptionStatusChanged,
                        object: transaction
                    )

                    // Finish the transaction
                    await transaction.finish()

                } catch {
                    self.logger.log(
                        "Transaction verification failed: \(error.localizedDescription)",
                        category: .store,
                        level: .error,
                        metadata: nil
                    )
                }
            }
        }
    }

    // MARK: - Verification

    /// Verify a transaction using StoreKit 2's built-in verification
    /// - Parameter result: Verification result from StoreKit
    /// - Returns: Verified transaction
    /// - Throws: Verification error
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            // Transaction failed verification
            throw StoreError.verificationFailed
        case .verified(let safe):
            // Transaction passed verification
            return safe
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let subscriptionStatusChanged = Notification.Name("subscriptionStatusChanged")
    static let userBecamePremium = Notification.Name("userBecamePremium")
    static let userProfileDidUpdate = Notification.Name("userProfileDidUpdate")
    static let navigateToRecipe = Notification.Name("navigateToRecipe")
    static let creditTierShouldUpdate = Notification.Name("creditTierShouldUpdate")
}
