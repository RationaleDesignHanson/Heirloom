//
//  MockStoreManager.swift
//  HeirloomTestsV2
//
//  Mock implementation of StoreManager for testing subscription flows
//  Created: 2026-01-13
//

import Foundation
import StoreKit
@testable import Heirloom

/// Mock purchase result (simplified for testing)
enum MockPurchaseResult {
    case success
    case cancelled
    case pending
    case failed(StoreError)
}

/// Mock StoreManager for testing subscription and purchase flows
@MainActor
final class MockStoreManager {

    // MARK: - Published State

    var products: [ProductIdentifier: Product] = [:]
    var isLoading = false
    var currentError: StoreError?

    // MARK: - Mock Configuration

    var shouldFailPurchase = false
    var shouldCancelPurchase = false
    var shouldPendPurchase = false
    var purchaseDelay: TimeInterval = 0
    var productsToLoad: [ProductIdentifier] = ProductIdentifier.allCases

    // MARK: - Test Inspection

    private(set) var loadProductsCallCount = 0
    private(set) var purchaseCallCount = 0
    private(set) var restoreCallCount = 0
    private(set) var lastPurchasedProduct: ProductIdentifier?
    private(set) var mockTransactionHistory: [MockTransaction] = []
    private(set) var activePurchases: Set<ProductIdentifier> = []

    // MARK: - Mock Dependencies

    private let logger: LoggingService
    private let analytics: AnalyticsService

    // MARK: - Initialization

    init(
        logger: LoggingService =
MockLoggingService(),
        analytics: AnalyticsService = MockAnalyticsService()
    ) {
        self.logger = logger
        self.analytics = analytics
    }

    // MARK: - Product Loading

    /// Mock product loading
    func loadProducts() async throws {
        loadProductsCallCount += 1
        isLoading = true

        // Simulate network delay
        if purchaseDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(purchaseDelay * 1_000_000_000))
        }

        // Mock products (can't create real Product instances, so use empty dict)
        // In real tests, we'll check loadProductsCallCount instead
        products = [:]

        isLoading = false
        logger.log("Mock: Loaded products", category: .store, level: .debug)
    }

    // MARK: - Purchase Flow

    /// Mock purchase
    /// Note: Returns MockPurchaseResult (not PurchaseResult) to avoid StoreKit Transaction dependency
    /// Tests should use simulateSuccessfulPurchase() or check activePurchases set
    func purchase(_ productID: ProductIdentifier) async -> MockPurchaseResult {
        purchaseCallCount += 1
        lastPurchasedProduct = productID

        logger.log("Mock: Purchasing \(productID.displayName)", category: .store, level: .debug)

        // Simulate delay
        if purchaseDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(purchaseDelay * 1_000_000_000))
        }

        // Simulate different outcomes
        if shouldCancelPurchase {
            logger.log("Mock: Purchase cancelled", category: .store, level: .debug)
            return .cancelled
        }

        if shouldPendPurchase {
            logger.log("Mock: Purchase pending", category: .store, level: .debug)
            return .pending
        }

        if shouldFailPurchase {
            let error = StoreError.purchaseFailed("Mock purchase failure")
            logger.log("Mock: Purchase failed", category: .store, level: .error)
            return .failed(error)
        }

        // Success: Record purchase
        let mockTransaction = MockTransaction(productID: productID)
        mockTransactionHistory.append(mockTransaction)
        activePurchases.insert(productID)

        logger.log("Mock: Purchase succeeded", category: .store, level: .debug)
        return .success
    }

    /// Mock restore purchases
    func restorePurchases() async throws {
        restoreCallCount += 1
        logger.log("Mock: Restored purchases", category: .store, level: .debug)

        // Mock: Return existing transaction history
        // In real tests, this would sync with StoreKit
    }

    /// Mock current entitlements
    func currentEntitlements() async -> Set<ProductIdentifier> {
        logger.log("Mock: Current entitlements: \(activePurchases)", category: .store, level: .debug)
        return activePurchases
    }

    // MARK: - Test Helpers

    /// Simulate a successful purchase without going through purchase flow
    /// Use this in tests to set up subscription state
    func simulateSuccessfulPurchase(_ productID: ProductIdentifier) {
        let transaction = MockTransaction(productID: productID)
        mockTransactionHistory.append(transaction)
        activePurchases.insert(productID)
        logger.log("Mock: Simulated purchase of \(productID.displayName)", category: .store, level: .debug)
    }

    /// Clear all mock state for test isolation
    func reset() {
        loadProductsCallCount = 0
        purchaseCallCount = 0
        restoreCallCount = 0
        lastPurchasedProduct = nil
        mockTransactionHistory.removeAll()
        activePurchases.removeAll()
        products.removeAll()
        isLoading = false
        currentError = nil
        shouldFailPurchase = false
        shouldCancelPurchase = false
        shouldPendPurchase = false
        purchaseDelay = 0
    }
}

// MARK: - Mock Transaction

/// Mock StoreKit Transaction for testing
/// Note: Simplified version that doesn't conform to StoreKit.Transaction
/// Real tests will use StoreKit's test environment for actual transaction testing
struct MockTransaction {
    let productID: String
    let id: UInt64
    let purchaseDate: Date

    init(
        productID: ProductIdentifier,
        id: UInt64 = UInt64.random(in: 1...1_000_000),
        purchaseDate: Date = Date()
    ) {
        self.productID = productID.rawValue
        self.id = id
        self.purchaseDate = purchaseDate
    }
}
