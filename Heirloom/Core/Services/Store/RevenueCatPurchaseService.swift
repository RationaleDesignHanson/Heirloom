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
/// Handles subscriptions and purchases through RevenueCat SDK
@MainActor
final class RevenueCatPurchaseService: PurchaseServiceProtocol {

    // MARK: - Dependencies

    private let logger: LoggingService
    private let analytics: AnalyticsService

    // MARK: - State

    private var currentOffering: Offering?
    private var customerInfo: CustomerInfo?

    // MARK: - Constants

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
                logger.log("RevenueCat: No current offering available", category: .store, level: .warning, metadata: nil)
                throw StoreError.notImplemented("No offerings configured in RevenueCat")
            }

            self.currentOffering = current

            // Map RevenueCat packages to our ProductIdentifier system
            var products: [ProductIdentifier: Product] = [:]

            // Try to find packages by identifier or package type
            for package in current.availablePackages {
                let productID = package.storeProduct.productIdentifier

                if let identifier = ProductIdentifier(rawValue: productID) {
                    // Get the underlying StoreKit product
                    if let skProduct = try? await Product.products(for: [productID]).first {
                        products[identifier] = skProduct
                        logger.log(
                            "RevenueCat: Loaded product \(identifier.displayName) - \(package.storeProduct.localizedPriceString)",
                            category: .store,
                            level: .debug,
                            metadata: nil
                        )
                    }
                }
            }

            logger.log(
                "RevenueCat: Loaded \(products.count) products",
                category: .store,
                level: .info,
                metadata: nil
            )

            return products

        } catch {
            logger.log(
                "RevenueCat: Failed to load products - \(error.localizedDescription)",
                category: .store,
                level: .error,
                metadata: nil
            )
            throw StoreError.unknownError(error)
        }
    }

    func purchase(_ productID: ProductIdentifier) async -> PurchaseResult {
        logger.log("RevenueCat: Starting purchase for \(productID.rawValue)", category: .store, level: .info, metadata: nil)

        analytics.track(event: .purchaseStarted, properties: [
            "product": productID.rawValue,
            "provider": "revenuecat"
        ])

        // Find the package for this product
        guard let offering = currentOffering else {
            // Try to load offerings first
            do {
                _ = try await loadProducts()
            } catch {
                return .failed(.unknownError(error))
            }

            guard let offering = currentOffering else {
                return .failed(.notImplemented("No offerings available"))
            }

            return await purchaseFromOffering(offering, productID: productID)
        }

        return await purchaseFromOffering(offering, productID: productID)
    }

    private func purchaseFromOffering(_ offering: Offering, productID: ProductIdentifier) async -> PurchaseResult {
        // Find the package matching our product ID
        guard let package = offering.availablePackages.first(where: {
            $0.storeProduct.productIdentifier == productID.rawValue
        }) else {
            logger.log(
                "RevenueCat: Product \(productID.rawValue) not found in offering",
                category: .store,
                level: .error,
                metadata: nil
            )
            return .failed(.productNotFound(productID))
        }

        do {
            let result = try await Purchases.shared.purchase(package: package)

            if result.userCancelled {
                logger.log("RevenueCat: Purchase cancelled by user", category: .store, level: .info, metadata: nil)
                analytics.track(event: .purchaseCancelled, properties: ["product": productID.rawValue])
                return .cancelled
            }

            // Update cached customer info
            self.customerInfo = result.customerInfo

            // Check if premium entitlement is now active
            if result.customerInfo.entitlements[premiumEntitlementID]?.isActive == true {
                logger.log(
                    "RevenueCat: Purchase successful - premium entitlement active",
                    category: .store,
                    level: .info,
                    metadata: nil
                )

                analytics.track(event: .purchaseSuccess, properties: [
                    "product": productID.rawValue,
                    "provider": "revenuecat"
                ])

                // Notify app of subscription change
                NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)

                // Return pending since we don't have a StoreKit Transaction object
                // The subscription status will be verified via customerInfo
                return .pending
            } else {
                logger.log(
                    "RevenueCat: Purchase completed but entitlement not active",
                    category: .store,
                    level: .warning,
                    metadata: nil
                )
                return .pending
            }

        } catch let error as ErrorCode {
            return handleRevenueCatError(error, productID: productID)
        } catch {
            logger.log(
                "RevenueCat: Purchase failed - \(error.localizedDescription)",
                category: .store,
                level: .error,
                metadata: nil
            )
            analytics.track(event: .purchaseFailed, properties: [
                "product": productID.rawValue,
                "error": error.localizedDescription
            ])
            return .failed(.unknownError(error))
        }
    }

    private func handleRevenueCatError(_ error: ErrorCode, productID: ProductIdentifier) -> PurchaseResult {
        let storeError: StoreError

        switch error {
        case .purchaseCancelledError:
            analytics.track(event: .purchaseCancelled, properties: ["product": productID.rawValue])
            return .cancelled

        case .purchaseNotAllowedError:
            storeError = .purchaseFailed("Purchases not allowed on this device")

        case .purchaseInvalidError:
            storeError = .purchaseFailed("Invalid purchase")

        case .productNotAvailableForPurchaseError:
            storeError = .productNotFound(productID)

        case .networkError:
            storeError = .networkUnavailable

        default:
            storeError = .purchaseFailed(error.localizedDescription)
        }

        logger.log(
            "RevenueCat: Purchase error - \(storeError.localizedDescription ?? "Unknown")",
            category: .store,
            level: .error,
            metadata: nil
        )

        analytics.track(event: .purchaseFailed, properties: [
            "product": productID.rawValue,
            "error_code": String(describing: error)
        ])

        return .failed(storeError)
    }

    func restorePurchases() async throws -> [Transaction] {
        logger.log("RevenueCat: Restoring purchases...", category: .store, level: .info, metadata: nil)

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo

            logger.log(
                "RevenueCat: Restore completed - active entitlements: \(customerInfo.entitlements.active.keys.joined(separator: ", "))",
                category: .store,
                level: .info,
                metadata: nil
            )

            // Notify app of potential subscription change
            NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)

            // RevenueCat doesn't return StoreKit transactions, so we return empty array
            // The subscription status is managed through customerInfo
            return []

        } catch {
            logger.log(
                "RevenueCat: Restore failed - \(error.localizedDescription)",
                category: .store,
                level: .error,
                metadata: nil
            )
            throw StoreError.unknownError(error)
        }
    }

    func getCurrentSubscription() async -> Transaction? {
        logger.log("RevenueCat: Checking current subscription...", category: .store, level: .debug, metadata: nil)

        // Refresh customer info to get latest status
        await refreshCustomerInfo()

        // Check if premium entitlement is active
        if customerInfo?.entitlements[premiumEntitlementID]?.isActive == true {
            logger.log("RevenueCat: Premium entitlement is active", category: .store, level: .debug, metadata: nil)
            // Note: We don't have access to the actual StoreKit Transaction
            // Subscription status should be checked via isPremium() or customerInfo
        }

        // Return nil - RevenueCat manages subscription state differently
        // Use isPremium() method instead for subscription checks
        return nil
    }

    func hasLifetimePurchase() async -> Bool {
        logger.log("RevenueCat: Checking lifetime purchase...", category: .store, level: .debug, metadata: nil)

        await refreshCustomerInfo()

        guard let customerInfo = customerInfo,
              let premiumEntitlement = customerInfo.entitlements[premiumEntitlementID],
              premiumEntitlement.isActive else {
            return false
        }

        // Check if it's a lifetime (non-renewing) purchase
        // Lifetime purchases won't have an expiration date or will have a very far future date
        if premiumEntitlement.expirationDate == nil {
            // No expiration = lifetime
            return true
        }

        // Check if the product is our lifetime product
        if premiumEntitlement.productIdentifier == ProductIdentifier.lifetime.rawValue {
            return true
        }

        return false
    }

    func startTransactionListener(handler: @escaping (Transaction) async -> Void) -> Task<Void, Never> {
        logger.log("RevenueCat: Setting up customer info listener", category: .store, level: .info, metadata: nil)

        // RevenueCat uses a delegate pattern, but we can also use async updates
        // For now, we'll set up a simple polling mechanism or rely on purchase callbacks

        return Task {
            // RevenueCat handles transaction listening internally
            // The SDK automatically updates customerInfo on subscription changes
            // We can periodically refresh or rely on purchase/restore callbacks

            logger.log(
                "RevenueCat: Transaction listener active (managed by RevenueCat SDK)",
                category: .store,
                level: .debug,
                metadata: nil
            )
        }
    }

    // MARK: - Helper Methods

    /// Check if user currently has premium access
    func isPremium() async -> Bool {
        await refreshCustomerInfo()
        return customerInfo?.entitlements[premiumEntitlementID]?.isActive == true
    }

    /// Refresh customer info from RevenueCat
    private func refreshCustomerInfo() async {
        do {
            customerInfo = try await Purchases.shared.customerInfo()
            logger.log(
                "RevenueCat: Customer info refreshed - premium: \(customerInfo?.entitlements[premiumEntitlementID]?.isActive ?? false)",
                category: .store,
                level: .debug,
                metadata: nil
            )
        } catch {
            logger.log(
                "RevenueCat: Failed to refresh customer info - \(error.localizedDescription)",
                category: .store,
                level: .warning,
                metadata: nil
            )
        }
    }

    /// Get the current customer info (cached)
    func getCustomerInfo() -> CustomerInfo? {
        return customerInfo
    }
}
