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

    // MARK: - Initialization

    init(logger: LoggingService, analytics: AnalyticsService) {
        self.logger = logger
        self.analytics = analytics

        logger.log("StoreManager initialized", category: .store, level: .info)

        // Start listening for transactions immediately
        startTransactionListener()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Product Loading

    /// Load products from App Store
    /// - Note: Call this on app launch and when entering store UI
    func loadProducts() async throws {
        isLoading = true
        currentError = nil

        logger.log("Loading products from App Store...", category: .store, level: .info)

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
                        level: .debug
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
                    level: .warning
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
                level: .error
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
        guard let product = products[productID] else {
            let error = StoreError.productNotFound(productID)
            currentError = error

            logger.log(
                "Purchase failed: product not found \(productID.rawValue)",
                category: .store,
                level: .error
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
            level: .info
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
                        level: .info
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
                        level: .error
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
                    level: .info
                )

                analytics.track(event: .purchaseCancelled, properties: [
                    "product": productID.rawValue
                ])

                return .cancelled

            case .pending:
                logger.log(
                    "Purchase pending approval (Ask to Buy)",
                    category: .store,
                    level: .info
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
                    level: .error
                )

                return .failed(error)
            }

        } catch {
            let storeError = StoreError.purchaseFailed(error.localizedDescription)
            currentError = storeError

            logger.log(
                "Purchase error: \(error.localizedDescription)",
                category: .store,
                level: .error
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
        logger.log("Restoring purchases...", category: .store, level: .info)

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
                        level: .debug
                    )
                }
            } catch {
                logger.log(
                    "Failed to verify restored transaction: \(error.localizedDescription)",
                    category: .store,
                    level: .warning
                )
            }
        }

        logger.log(
            "Restored \(restoredTransactions.count) purchases",
            category: .store,
            level: .info
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
                    level: .debug
                )

                return transaction

            } catch {
                logger.log(
                    "Failed to verify transaction: \(error.localizedDescription)",
                    category: .store,
                    level: .warning
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

                    await self.logger.log(
                        "Transaction updated: \(transaction.productID)",
                        category: .store,
                        level: .info
                    )

                    // Notify SubscriptionManager of change
                    NotificationCenter.default.post(
                        name: .subscriptionStatusChanged,
                        object: transaction
                    )

                    // Finish the transaction
                    await transaction.finish()

                } catch {
                    await self.logger.log(
                        "Transaction verification failed: \(error.localizedDescription)",
                        category: .store,
                        level: .error
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
}
