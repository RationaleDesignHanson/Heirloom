//
//  PurchaseServiceProtocol.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-23.
//  Protocol abstraction for purchase services (StoreKit, RevenueCat, etc.)
//

import Foundation
import StoreKit

// MARK: - Shared Types

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

// MARK: - Protocol

/// Protocol defining the purchase service interface
/// Allows swapping between StoreKit 2 and RevenueCat implementations
@MainActor
protocol PurchaseServiceProtocol {

    // MARK: - Product Loading

    /// Load available products from the store
    /// - Returns: Dictionary of product identifiers to products
    func loadProducts() async throws -> [ProductIdentifier: Product]

    // MARK: - Purchasing

    /// Purchase a product
    /// - Parameter productID: The product to purchase
    /// - Returns: Purchase result with transaction details
    func purchase(_ productID: ProductIdentifier) async -> PurchaseResult

    /// Restore previous purchases
    /// - Returns: Array of restored transactions
    func restorePurchases() async throws -> [Transaction]

    // MARK: - Subscription Status

    /// Get the current active subscription transaction
    /// - Returns: Active subscription transaction, or nil if no active subscription
    func getCurrentSubscription() async -> Transaction?

    /// Check if user has purchased lifetime access
    /// - Returns: True if lifetime purchase exists
    func hasLifetimePurchase() async -> Bool

    // MARK: - Transaction Monitoring

    /// Start listening for transaction updates
    /// - Parameter handler: Closure called when transactions update
    func startTransactionListener(handler: @escaping (Transaction) async -> Void) -> Task<Void, Never>
}

/// Configuration for purchase service providers
enum PurchaseServiceProvider {
    case storeKit
    case revenueCat

    var displayName: String {
        switch self {
        case .storeKit: return "StoreKit 2"
        case .revenueCat: return "RevenueCat"
        }
    }
}
