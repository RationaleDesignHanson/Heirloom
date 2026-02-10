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

// MARK: - Shared Types
// Note: ProductIdentifier, StoreError, and PurchaseResult are defined in StoreManager.swift
// They are re-used here via the protocol's type references.

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
