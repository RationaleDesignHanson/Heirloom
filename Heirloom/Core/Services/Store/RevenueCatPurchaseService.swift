//
//  RevenueCatPurchaseService.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//  RevenueCat implementation of purchase service
//

import Foundation
import StoreKit
import RevenueCat

/// RevenueCat implementation of purchase service
/// Handles all subscription and purchase logic through RevenueCat SDK
@MainActor
final class RevenueCatPurchaseService: PurchaseServiceProtocol {

    // MARK: - Dependencies

    private let logger: LoggingService
    private let analytics: AnalyticsService

    // MARK: - State

    private var currentOffering: Offering?
    private var customerInfo: CustomerInfo?

    /// Timestamp of last purchase - used to prefer cached customerInfo over fresh API call
    /// This prevents race conditions where RevenueCat backend hasn't processed the upgrade yet
    private var lastPurchaseTimestamp: Date?

    /// The product ID from the most recent purchase
    /// Used to override stale entitlement data from RevenueCat after upgrades
    private(set) var lastPurchasedProductID: ProductIdentifier?

    /// How long to prefer cached customerInfo after a purchase (seconds)
    private let purchaseCacheWindow: TimeInterval = 30

    // MARK: - Entitlement Constants

    /// The entitlement identifier configured in RevenueCat dashboard
    private let premiumEntitlementID = "premium"

    // MARK: - Initialization

    init(logger: LoggingService, analytics: AnalyticsService) {
        self.logger = logger
        self.analytics = analytics

        logger.log("RevenueCatPurchaseService initialized", category: .store, level: .info, metadata: nil)

        // Refresh customer info on init
        Task {
            await refreshCustomerInfo()
        }
    }

    // MARK: - PurchaseServiceProtocol Implementation

    func loadProducts() async throws -> [ProductIdentifier: Product] {
        logger.log("RevenueCat: Loading products...", category: .store, level: .info, metadata: nil)

        do {
            let offerings = try await Purchases.shared.offerings()

            guard let current = offerings.current else {
                logger.log("RevenueCat: No current offering found", category: .store, level: .warning, metadata: nil)
                throw StoreError.productNotFound(.annual)
            }

            self.currentOffering = current

            // Map RevenueCat packages to StoreKit Products
            var loadedProducts: [ProductIdentifier: Product] = [:]

            if let monthly = current.monthly?.storeProduct.sk2Product {
                loadedProducts[.monthly] = monthly
                logger.log("RevenueCat: Loaded monthly - \(monthly.displayPrice)", category: .store, level: .debug, metadata: nil)
            }

            if let annual = current.annual?.storeProduct.sk2Product {
                loadedProducts[.annual] = annual
                logger.log("RevenueCat: Loaded annual - \(annual.displayPrice)", category: .store, level: .debug, metadata: nil)
            }

            if let lifetime = current.lifetime?.storeProduct.sk2Product {
                loadedProducts[.lifetime] = lifetime
                logger.log("RevenueCat: Loaded lifetime - \(lifetime.displayPrice)", category: .store, level: .debug, metadata: nil)
            }

            logger.log("RevenueCat: Loaded \(loadedProducts.count) products", category: .store, level: .info, metadata: nil)

            analytics.track(event: .storeProductsLoaded, properties: [
                "product_count": loadedProducts.count,
                "provider": "revenuecat"
            ])

            return loadedProducts

        } catch {
            logger.log("RevenueCat: Failed to load products - \(error.localizedDescription)", category: .store, level: .error, metadata: nil)
            throw StoreError.unknownError(error)
        }
    }

    func purchase(_ productID: ProductIdentifier) async -> PurchaseResult {
        logger.log("RevenueCat: Starting purchase for \(productID.rawValue)", category: .store, level: .info, metadata: nil)

        analytics.track(event: .purchaseStarted, properties: [
            "product": productID.rawValue,
            "provider": "revenuecat"
        ])

        // Get the package from current offering
        // Try to fetch offerings if not already loaded
        if self.currentOffering == nil {
            do {
                let offerings = try await Purchases.shared.offerings()
                self.currentOffering = offerings.current
            } catch {
                logger.log("RevenueCat: Failed to fetch offerings - \(error.localizedDescription)", category: .store, level: .error, metadata: nil)
                return .failed(.unknownError(error))
            }
        }

        guard let offering = self.currentOffering else {
            logger.log("RevenueCat: No current offering available", category: .store, level: .error, metadata: nil)
            return .failed(.productNotFound(productID))
        }

        let package: Package?
        switch productID {
        case .monthly:
            package = offering.monthly
        case .annual:
            package = offering.annual
        case .lifetime:
            package = offering.lifetime
        }

        guard let package = package else {
            logger.log("RevenueCat: Package not found for \(productID.rawValue)", category: .store, level: .error, metadata: nil)
            return .failed(.productNotFound(productID))
        }

        do {
            let result = try await Purchases.shared.purchase(package: package)

            // Update cached customer info AND timestamp
            // This ensures getSubscriptionInfo() uses this fresh data instead of making
            // a new API call that might return stale data during upgrade processing
            self.customerInfo = result.customerInfo
            self.lastPurchaseTimestamp = Date()

            if result.userCancelled {
                logger.log("RevenueCat: Purchase cancelled by user", category: .store, level: .info, metadata: nil)
                analytics.track(event: .purchaseCancelled, properties: [
                    "product": productID.rawValue
                ])
                return .cancelled
            }

            // Check if premium entitlement is now active
            if result.customerInfo.entitlements[premiumEntitlementID]?.isActive == true {
                logger.log("RevenueCat: Purchase successful - premium active", category: .store, level: .info, metadata: nil)

                analytics.track(event: .purchaseSuccess, properties: [
                    "product": productID.rawValue,
                    "provider": "revenuecat"
                ])

                // Store the just-purchased product ID for SubscriptionManager to use
                // This bypasses RevenueCat's entitlement which may have stale productIdentifier
                self.lastPurchasedProductID = productID

                // Post notification for SubscriptionManager with the purchased product
                NotificationCenter.default.post(
                    name: .subscriptionStatusChanged,
                    object: nil,
                    userInfo: ["purchasedProductID": productID.rawValue]
                )

                // Return success with StoreKit transaction if available
                if let transaction = result.transaction,
                   let sk2Transaction = transaction.sk2Transaction {
                    return .success(sk2Transaction)
                }

                // For sandbox/testing where transaction might not be available
                return .pending
            }

            logger.log("RevenueCat: Purchase completed but premium not active", category: .store, level: .warning, metadata: nil)
            return .pending

        } catch let error as RevenueCat.ErrorCode {
            logger.log("RevenueCat: Purchase error - \(error.localizedDescription)", category: .store, level: .error, metadata: nil)

            if error == .purchaseCancelledError {
                return .cancelled
            }

            analytics.track(event: .purchaseFailed, properties: [
                "product": productID.rawValue,
                "error": error.localizedDescription
            ])

            return .failed(.purchaseFailed(error.localizedDescription))

        } catch {
            logger.log("RevenueCat: Purchase failed - \(error.localizedDescription)", category: .store, level: .error, metadata: nil)

            analytics.track(event: .purchaseFailed, properties: [
                "product": productID.rawValue,
                "error": error.localizedDescription
            ])

            return .failed(.unknownError(error))
        }
    }

    func restorePurchases() async throws -> [Transaction] {
        logger.log("RevenueCat: Restoring purchases...", category: .store, level: .info, metadata: nil)

        analytics.track(event: .restoreStarted)

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo

            logger.log("RevenueCat: Restore completed", category: .store, level: .info, metadata: nil)

            // Check if premium is now active
            if customerInfo.entitlements[premiumEntitlementID]?.isActive == true {
                logger.log("RevenueCat: Premium restored successfully", category: .store, level: .info, metadata: nil)

                // Post notification for SubscriptionManager
                NotificationCenter.default.post(
                    name: .subscriptionStatusChanged,
                    object: nil
                )
            }

            analytics.track(event: .restoreCompleted, properties: [
                "has_premium": customerInfo.entitlements[premiumEntitlementID]?.isActive == true
            ])

            // RevenueCat doesn't return raw StoreKit transactions on restore
            // The subscription status is handled via customerInfo
            return []

        } catch {
            logger.log("RevenueCat: Restore failed - \(error.localizedDescription)", category: .store, level: .error, metadata: nil)
            throw StoreError.unknownError(error)
        }
    }

    func getCurrentSubscription() async -> Transaction? {
        logger.log("RevenueCat: Checking current subscription...", category: .store, level: .debug, metadata: nil)

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            self.customerInfo = customerInfo

            // Check for active premium entitlement
            guard let entitlement = customerInfo.entitlements[premiumEntitlementID],
                  entitlement.isActive else {
                logger.log("RevenueCat: No active premium entitlement", category: .store, level: .debug, metadata: nil)
                return nil
            }

            logger.log("RevenueCat: Found active entitlement - \(entitlement.productIdentifier)", category: .store, level: .debug, metadata: nil)

            // RevenueCat manages subscriptions - we return nil here
            // but the subscription status should be checked via getSubscriptionInfo()
            return nil

        } catch {
            logger.log("RevenueCat: Failed to get customer info - \(error.localizedDescription)", category: .store, level: .error, metadata: nil)
            return nil
        }
    }

    func hasLifetimePurchase() async -> Bool {
        logger.log("RevenueCat: Checking for lifetime purchase...", category: .store, level: .debug, metadata: nil)

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            self.customerInfo = customerInfo

            // Check if entitlement is active and from lifetime product
            guard let entitlement = customerInfo.entitlements[premiumEntitlementID],
                  entitlement.isActive else {
                return false
            }

            // Check if product ID contains "lifetime"
            let isLifetime = entitlement.productIdentifier.contains("lifetime")

            logger.log("RevenueCat: Lifetime check - \(isLifetime)", category: .store, level: .debug, metadata: nil)

            return isLifetime

        } catch {
            logger.log("RevenueCat: Failed to check lifetime - \(error.localizedDescription)", category: .store, level: .error, metadata: nil)
            return false
        }
    }

    func startTransactionListener(handler: @escaping (Transaction) async -> Void) -> Task<Void, Never> {
        logger.log("RevenueCat: Starting customer info listener", category: .store, level: .info, metadata: nil)

        // RevenueCat uses delegate pattern, but we still need to listen for StoreKit transactions
        // for compatibility with the rest of the system
        return Task {
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await handler(transaction)
                } catch {
                    self.logger.log("RevenueCat: Transaction verification failed - \(error.localizedDescription)", category: .store, level: .error, metadata: nil)
                }
            }
        }
    }

    // MARK: - RevenueCat-Specific Methods

    /// Get subscription status from RevenueCat
    /// - Parameter forceRefresh: If true, invalidates RevenueCat cache first to get fresh data from server
    /// - Parameter isDemoAccount: If true, ignores RevenueCat's activeSubscriptions (may have stale sandbox data)
    /// - Returns: Tuple of (status, expiryDate, willRenew) or nil if error
    func getSubscriptionInfo(forceRefresh: Bool = false, isDemoAccount: Bool = false) async -> (status: HeirloomSubscriptionStatus, expiryDate: Date?, willRenew: Bool)? {
        do {
            // Force refresh invalidates cache to get fresh data (e.g., after manage subscription)
            if forceRefresh {
                logger.log("RevenueCat: Invalidating customer info cache for fresh fetch", category: .store, level: .info, metadata: nil)
                Purchases.shared.invalidateCustomerInfoCache()
            }

            // CRITICAL: If we just made a purchase, use the purchased product ID directly
            // RevenueCat's entitlement.productIdentifier may still show the OLD product after an upgrade
            // For demo accounts, ALWAYS use session purchase ID to avoid stale sandbox subscription data
            if let purchasedProduct = lastPurchasedProductID,
               let purchaseTime = lastPurchaseTimestamp {

                // For demo accounts: always use last purchased product (ignore stale sandbox data)
                // For regular users: only use within the cache window (and not if forceRefresh)
                let useCache = isDemoAccount || (!forceRefresh && Date().timeIntervalSince(purchaseTime) < purchaseCacheWindow)

                if useCache {
                    logger.log("RevenueCat: Using purchased product ID directly - \(purchasedProduct.rawValue) (isDemoAccount: \(isDemoAccount), forceRefresh: \(forceRefresh))", category: .store, level: .info, metadata: nil)

                    let status: HeirloomSubscriptionStatus
                    switch purchasedProduct {
                    case .monthly: status = .monthly
                    case .annual: status = .annual
                    case .lifetime: status = .lifetime
                    }

                    // If forceRefresh, fetch fresh customerInfo to get updated willRenew (e.g., after cancellation)
                    // Otherwise use cached data
                    let customerInfoToUse: CustomerInfo?
                    if forceRefresh {
                        customerInfoToUse = try? await Purchases.shared.customerInfo()
                        if let fresh = customerInfoToUse {
                            self.customerInfo = fresh
                        }
                    } else {
                        customerInfoToUse = self.customerInfo
                    }

                    let entitlement = customerInfoToUse?.entitlements[premiumEntitlementID]
                    let expiryDate = entitlement?.expirationDate
                    let willRenew = entitlement?.willRenew ?? true  // Assume will renew for recently purchased

                    return (status, expiryDate, willRenew)
                }
            }

            // Normal path: fetch fresh customerInfo from RevenueCat
            let customerInfo = try await Purchases.shared.customerInfo()
            self.customerInfo = customerInfo

            // Check if entitlement exists
            guard let entitlement = customerInfo.entitlements[premiumEntitlementID] else {
                // No entitlement at all - truly free user
                return (.none, nil, false)
            }

            // Entitlement exists but not active = expired
            guard entitlement.isActive else {
                logger.log("RevenueCat: Entitlement exists but not active - subscription expired", category: .store, level: .debug, metadata: nil)
                return (.expired, entitlement.expirationDate, false)
            }

            // CRITICAL: Check if user is in Apple-managed free trial period
            // periodType == .trial indicates the user started a subscription with a free trial
            // and hasn't been charged yet. This takes precedence over product type.
            if entitlement.periodType == .trial {
                logger.log("RevenueCat: User is in Apple-managed free trial period", category: .store, level: .info, metadata: [
                    "product": entitlement.productIdentifier,
                    "expirationDate": entitlement.expirationDate?.description ?? "nil"
                ])
                return (.trial, entitlement.expirationDate, entitlement.willRenew)
            }

            // CRITICAL FIX: Check activeSubscriptions to find the highest-tier subscription
            // When user upgrades from monthly to annual then restores, entitlement.productIdentifier
            // may incorrectly return the old (monthly) product instead of the upgraded (annual) product.
            // We prioritize: lifetime > annual > monthly
            let activeSubscriptions = customerInfo.activeSubscriptions

            logger.log("RevenueCat: Active subscriptions: \(activeSubscriptions.joined(separator: ", "))", category: .store, level: .debug, metadata: nil)

            let status: HeirloomSubscriptionStatus

            // Check for lifetime first (highest priority)
            if activeSubscriptions.contains(where: { $0.contains("lifetime") }) {
                status = .lifetime
                logger.log("RevenueCat: Found lifetime in activeSubscriptions", category: .store, level: .debug, metadata: nil)
            }
            // Check for annual (higher priority than monthly)
            else if activeSubscriptions.contains(where: { $0.contains("annual") }) {
                status = .annual
                logger.log("RevenueCat: Found annual in activeSubscriptions", category: .store, level: .debug, metadata: nil)
            }
            // Check for monthly
            else if activeSubscriptions.contains(where: { $0.contains("monthly") }) {
                status = .monthly
                logger.log("RevenueCat: Found monthly in activeSubscriptions", category: .store, level: .debug, metadata: nil)
            }
            // Fallback: use entitlement's productIdentifier (may be stale after upgrades)
            else {
                let productId = entitlement.productIdentifier
                if productId.contains("lifetime") {
                    status = .lifetime
                } else if productId.contains("annual") {
                    status = .annual
                } else if productId.contains("monthly") {
                    status = .monthly
                } else {
                    // Unknown product - assume premium
                    status = .monthly
                }
                logger.log("RevenueCat: Using entitlement productIdentifier fallback - \(productId)", category: .store, level: .debug, metadata: nil)
            }

            // Check if subscription will renew
            let willRenew = entitlement.willRenew

            logger.log("RevenueCat: Subscription status determined - \(status.displayName), willRenew: \(willRenew)", category: .store, level: .debug, metadata: nil)

            return (status, entitlement.expirationDate, willRenew)

        } catch {
            logger.log("RevenueCat: Failed to get subscription info - \(error.localizedDescription)", category: .store, level: .error, metadata: nil)
            return nil
        }
    }

    /// Clear the cached purchase info (call after cache window expires or on app restart)
    func clearPurchaseCache() {
        lastPurchasedProductID = nil
        lastPurchaseTimestamp = nil
    }

    /// Update the purchase cache when a transaction is received
    /// Call this when StoreKit notifies of a subscription transaction (e.g., external upgrade via Apple)
    func updatePurchaseCache(for productID: ProductIdentifier) {
        // Only update if different from current cache (this is an upgrade/change)
        if lastPurchasedProductID != productID {
            logger.log("RevenueCat: Updating purchase cache for external transaction - \(productID.rawValue)", category: .store, level: .info, metadata: nil)
            lastPurchasedProductID = productID
            lastPurchaseTimestamp = Date()
        }
    }

    /// Check if user currently has premium access
    func checkPremiumStatus() async -> Bool {
        guard let customerInfo = try? await Purchases.shared.customerInfo() else {
            return false
        }
        self.customerInfo = customerInfo
        return customerInfo.entitlements[premiumEntitlementID]?.isActive == true
    }

    // MARK: - Private Helpers

    private func refreshCustomerInfo() async {
        do {
            self.customerInfo = try await Purchases.shared.customerInfo()
            logger.log("RevenueCat: Customer info refreshed", category: .store, level: .debug, metadata: nil)
        } catch {
            logger.log("RevenueCat: Failed to refresh customer info - \(error.localizedDescription)", category: .store, level: .warning, metadata: nil)
        }
    }

    private func checkVerified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - User Identity

    /// Link RevenueCat to Firebase user ID
    /// CRITICAL: Must be called when user signs into Firebase to preserve subscription across sessions
    func logIn(userId: String) async {
        do {
            let (customerInfo, created) = try await Purchases.shared.logIn(userId)
            self.customerInfo = customerInfo
            logger.log("RevenueCat: Logged in user", category: .store, level: .info, metadata: [
                "userId": userId,
                "created": created,
                "hasPremium": customerInfo.entitlements[premiumEntitlementID]?.isActive == true
            ])
        } catch {
            logger.log("RevenueCat: Failed to log in user - \(error.localizedDescription)", category: .store, level: .error, metadata: nil)
        }
    }

    /// Unlink RevenueCat user on sign out
    /// Returns to anonymous user ID
    func logOut() async {
        do {
            let customerInfo = try await Purchases.shared.logOut()
            self.customerInfo = customerInfo
            logger.log("RevenueCat: Logged out user, now anonymous", category: .store, level: .info, metadata: nil)
        } catch {
            logger.log("RevenueCat: Failed to log out - \(error.localizedDescription)", category: .store, level: .warning, metadata: nil)
        }
    }
}
