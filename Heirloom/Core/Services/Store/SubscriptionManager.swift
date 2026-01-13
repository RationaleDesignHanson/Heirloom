//
//  SubscriptionManager.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-08.
//

import Foundation
import StoreKit
import Observation

@MainActor
@Observable
final class SubscriptionManager {

    // MARK: - Published State

    /// Current subscription status
    private(set) var status: HeirloomSubscriptionStatus = .none

    /// Trial expiry date (if in trial)
    private(set) var trialExpiryDate: Date?

    /// Subscription expiry date (if subscribed)
    private(set) var subscriptionExpiryDate: Date?

    /// Days remaining in trial or subscription
    private(set) var daysRemaining: Int?

    /// Is status currently being refreshed?
    private(set) var isRefreshing = false

    /// Computed: does user have premium access?
    var isPremium: Bool {
        status.isPremium
    }

    /// Computed: is user in trial?
    var isInTrial: Bool {
        status == .trial
    }

    /// Computed: is trial expired?
    var isTrialExpired: Bool {
        guard let expiryDate = trialExpiryDate else { return false }
        return Date() > expiryDate
    }

    // MARK: - Dependencies

    private let storeManager: StoreManager
    private let logger: LoggingService
    private let analytics: AnalyticsService

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let subscriptionStatus = "subscription_status"
        static let firstLaunchDate = "first_launch_date"
        static let trialExpiryDate = "trial_expiry_date"
        static let subscriptionExpiryDate = "subscription_expiry_date"
        static let lastStatusRefresh = "last_subscription_status_refresh"
        static let cachedProductID = "cached_product_id"
    }

    // MARK: - Constants

    private let trialDaysMonthly = 7
    private let trialDaysAnnual = 14
    private let statusCacheTTL: TimeInterval = 24 * 60 * 60 // 24 hours

    // MARK: - Initialization

    init(storeManager: StoreManager, logger: LoggingService, analytics: AnalyticsService) {
        self.storeManager = storeManager
        self.logger = logger
        self.analytics = analytics

        logger.log("SubscriptionManager initialized", category: .store, level: .info, metadata: nil)

        // Load cached status
        loadCachedStatus()

        // Listen for transaction updates
        setupTransactionObserver()

        // Initialize trial if first launch
        initializeTrialIfNeeded()
    }

    // MARK: - Status Management

    /// Refresh subscription status from StoreKit
    /// - Parameter force: Force refresh even if cache is valid
    func refreshStatus(force: Bool = false) async {
        // Check cache validity
        if !force && isCacheValid() {
            logger.log(
                "Using cached subscription status",
                category: .store,
                level: .debug,
                metadata: nil
            )
            return
        }

        isRefreshing = true

        logger.log("Refreshing subscription status...", category: .store, level: .info, metadata: nil)

        // Check for lifetime purchase first
        let hasLifetime = await storeManager.hasLifetimePurchase()
        if hasLifetime {
            updateStatus(.lifetime)
            isRefreshing = false
            return
        }

        // Check for active subscription
        if let transaction = await storeManager.getCurrentSubscription() {
            await handleActiveSubscription(transaction)
        } else {
            // No active purchase - check trial status
            handleTrialStatus()
        }

        // Update cache timestamp
        UserDefaults.standard.set(Date(), forKey: Keys.lastStatusRefresh)

        isRefreshing = false

        logger.log(
            "Subscription status: \(status.displayName)",
            category: .store,
            level: .info,
            metadata: nil
        )

        analytics.track(event: .subscriptionStatusChecked, properties: [
            "status": status.rawValue,
            "is_premium": isPremium
        ])
    }

    /// Handle active subscription transaction
    private func handleActiveSubscription(_ transaction: Transaction) async {
        guard let productID = ProductIdentifier(rawValue: transaction.productID) else {
            return
        }

        // Check expiration date for subscriptions
        if productID.isSubscription {
            if let expirationDate = transaction.expirationDate {
                subscriptionExpiryDate = expirationDate

                // Check if subscription is still valid
                if Date() < expirationDate {
                    // Active subscription
                    let status: HeirloomSubscriptionStatus = productID == .monthly ? .monthly : .annual
                    updateStatus(status)

                    // Calculate days remaining
                    calculateDaysRemaining()

                    // Note: Grace period is handled by StoreKit 2 automatically
                    // Transactions in grace period still appear as active
                } else {
                    // Expired subscription
                    updateStatus(.expired)
                }
            } else {
                // No expiration date - treat as active
                let status: HeirloomSubscriptionStatus = productID == .monthly ? .monthly : .annual
                updateStatus(status)
            }
        } else {
            // Lifetime purchase
            updateStatus(.lifetime)
        }
    }

    /// Handle trial status (no active purchase)
    private func handleTrialStatus() {
        guard UserDefaults.standard.object(forKey: Keys.firstLaunchDate) as? Date != nil else {
            // No first launch date - not in trial
            updateStatus(.none)
            return
        }

        guard let trialExpiry = trialExpiryDate else {
            // No trial expiry - not in trial
            updateStatus(.none)
            return
        }

        if Date() < trialExpiry {
            // In trial
            updateStatus(.trial)
            calculateDaysRemaining()
        } else {
            // Trial expired
            updateStatus(.expired)
        }
    }

    /// Update subscription status
    private func updateStatus(_ newStatus: HeirloomSubscriptionStatus) {
        guard newStatus != status else { return }

        let oldStatus = status
        status = newStatus

        // Persist to UserDefaults
        UserDefaults.standard.set(newStatus.rawValue, forKey: Keys.subscriptionStatus)

        logger.log(
            "Subscription status changed: \(oldStatus.rawValue) → \(newStatus.rawValue)",
            category: .store,
            level: .info,
            metadata: nil
        )

        analytics.track(event: .subscriptionStatusChanged, properties: [
            "old_status": oldStatus.rawValue,
            "new_status": newStatus.rawValue
        ])
    }

    // MARK: - Trial Management

    /// Initialize trial on first launch
    private func initializeTrialIfNeeded() {
        // Skip trial initialization if in debug non-premium mode
        let debugForceNonPremium = UserDefaults.standard.object(forKey: "debug_force_non_premium") as? Bool ?? true
        if debugForceNonPremium {
            return
        }

        // Check if already initialized
        if UserDefaults.standard.object(forKey: Keys.firstLaunchDate) != nil {
            return
        }

        // First launch - start trial
        let now = Date()
        UserDefaults.standard.set(now, forKey: Keys.firstLaunchDate)

        // Default to annual trial (14 days) - user can choose monthly later
        let trialExpiry = Calendar.current.date(byAdding: .day, value: trialDaysAnnual, to: now)!
        UserDefaults.standard.set(trialExpiry, forKey: Keys.trialExpiryDate)

        trialExpiryDate = trialExpiry
        updateStatus(.trial)

        logger.log(
            "Trial started: \(trialDaysAnnual) days",
            category: .store,
            level: .info,
            metadata: nil
        )

        analytics.track(event: .trialStarted, properties: [
            "trial_days": trialDaysAnnual,
            "expiry_date": trialExpiry.ISO8601Format()
        ])
    }

    /// Adjust trial period when user selects a plan
    /// Call this when user interacts with paywall and selects monthly vs annual
    func adjustTrialForPlan(_ productID: ProductIdentifier) {
        // Only adjust if in trial
        guard status == .trial else { return }

        // Only adjust if not already purchased
        let trialDays = productID == .monthly ? trialDaysMonthly : trialDaysAnnual

        guard let firstLaunch = UserDefaults.standard.object(forKey: Keys.firstLaunchDate) as? Date else {
            return
        }

        let newExpiry = Calendar.current.date(byAdding: .day, value: trialDays, to: firstLaunch)!

        // Only update if different
        guard newExpiry != trialExpiryDate else { return }

        trialExpiryDate = newExpiry
        UserDefaults.standard.set(newExpiry, forKey: Keys.trialExpiryDate)

        logger.log(
            "Trial adjusted: \(trialDays) days for \(productID.displayName)",
            category: .store,
            level: .info,
            metadata: nil
        )

        analytics.track(event: .trialAdjusted, properties: [
            "plan": productID.rawValue,
            "trial_days": trialDays
        ])
    }

    // MARK: - Days Remaining

    /// Calculate days remaining in current period
    private func calculateDaysRemaining() {
        let now = Date()
        let targetDate: Date?

        if status == .trial {
            targetDate = trialExpiryDate
        } else if status == .monthly || status == .annual {
            targetDate = subscriptionExpiryDate
        } else {
            targetDate = nil
        }

        guard let target = targetDate else {
            daysRemaining = nil
            return
        }

        let components = Calendar.current.dateComponents([.day], from: now, to: target)
        daysRemaining = max(0, components.day ?? 0)
    }

    // MARK: - Cache Management

    /// Load cached status from UserDefaults
    private func loadCachedStatus() {
        // Load status
        if let statusRaw = UserDefaults.standard.string(forKey: Keys.subscriptionStatus),
           let cachedStatus = HeirloomSubscriptionStatus(rawValue: statusRaw) {
            status = cachedStatus
        }

        // Load dates
        trialExpiryDate = UserDefaults.standard.object(forKey: Keys.trialExpiryDate) as? Date
        subscriptionExpiryDate = UserDefaults.standard.object(forKey: Keys.subscriptionExpiryDate) as? Date

        // Calculate days remaining
        calculateDaysRemaining()

        logger.log(
            "Loaded cached subscription status: \(status.displayName)",
            category: .store,
            level: .debug,
            metadata: nil
        )
    }

    /// Check if cached status is still valid
    private func isCacheValid() -> Bool {
        guard let lastRefresh = UserDefaults.standard.object(forKey: Keys.lastStatusRefresh) as? Date else {
            return false
        }

        let timeSinceRefresh = Date().timeIntervalSince(lastRefresh)
        return timeSinceRefresh < statusCacheTTL
    }

    /// Clear cached status (for testing)
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: Keys.subscriptionStatus)
        UserDefaults.standard.removeObject(forKey: Keys.trialExpiryDate)
        UserDefaults.standard.removeObject(forKey: Keys.subscriptionExpiryDate)
        UserDefaults.standard.removeObject(forKey: Keys.lastStatusRefresh)
        UserDefaults.standard.removeObject(forKey: Keys.cachedProductID)

        status = .none
        trialExpiryDate = nil
        subscriptionExpiryDate = nil
        daysRemaining = nil

        logger.log("Subscription cache cleared", category: .store, level: .info, metadata: nil)
    }

    // MARK: - Transaction Observer

    /// Setup observer for transaction updates
    private func setupTransactionObserver() {
        NotificationCenter.default.addObserver(
            forName: .subscriptionStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshStatus(force: true)
            }
        }
    }
}
