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

    /// Whether subscription will renew (false = cancelled but still active)
    private(set) var willRenew: Bool = true

    /// Is status currently being refreshed?
    private(set) var isRefreshing = false

    /// Timestamp of last purchase notification - used to prevent race conditions
    /// where a slow refresh overwrites a just-completed purchase
    private var lastPurchaseNotificationTime: Date?

    /// How long to protect status after a purchase notification (seconds)
    /// Extended to 5 minutes to ensure demo account purchases aren't overridden
    private let purchaseProtectionWindow: TimeInterval = 300

    /// Computed: does user have premium access?
    /// Returns true if actual premium OR Auto Premium is enabled (debug)
    var isPremium: Bool {
        return status.isPremium || isAutoPremiumEnabled
    }

    /// Computed: is user in trial?
    var isInTrial: Bool {
        // Check if status is trial AND not expired
        guard status == .trial else { return false }

        // If we have an expiry date, check it
        if let expiryDate = trialExpiryDate {
            return Date() <= expiryDate
        }

        // No expiry date but status is trial - assume in trial
        return true
    }

    /// Computed: is trial expired?
    var isTrialExpired: Bool {
        guard let expiryDate = trialExpiryDate else { return false }
        return Date() > expiryDate
    }

    /// Current product ID (monthly, annual, or lifetime)
    var currentProductID: ProductIdentifier? {
        guard let productIDString = UserDefaults.standard.string(forKey: Keys.cachedProductID),
              let productID = ProductIdentifier(rawValue: productIDString) else {
            return nil
        }
        return productID
    }

    /// Current plan display name
    var currentPlanName: String? {
        guard let productID = currentProductID else { return nil }
        return productID.displayName
    }

    /// Full status display text including cancellation info
    /// e.g., "Premium (Monthly)" or "Cancelled - 5 days left on Monthly"
    var statusDisplayText: String {
        // Demo account: always show "Expired" unless actively premium
        // This ensures Apple reviewers see the paywall for App Store Review
        if isDemoAccountConfigured && !isPremium {
            return "Expired"
        }

        // Not a subscription type? Return basic display name
        guard status.isSubscription else {
            return status.displayName
        }

        // Subscription is cancelled but still active
        if !willRenew, let expiryDate = subscriptionExpiryDate, expiryDate > Date() {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
            let planName = currentPlanName ?? status.displayName
            if days == 0 {
                return "Cancelled - expires today"
            } else if days == 1 {
                return "Cancelled - 1 day left on \(planName)"
            } else {
                return "Cancelled - \(days) days left on \(planName)"
            }
        }

        // Active subscription
        return status.displayName
    }

    /// Can user upgrade to a better plan?
    var canUpgrade: Bool {
        guard let currentID = currentProductID else { return false }
        // Monthly can upgrade to Annual, Annual can upgrade to Lifetime
        return currentID == .monthly || currentID == .annual
    }

    /// Can user upgrade specifically to Lifetime? (for Annual users)
    var canUpgradeToLifetime: Bool {
        guard let currentID = currentProductID else { return false }
        return currentID == .annual // Annual can upgrade to Lifetime
    }

    /// Can user upgrade from Monthly to Annual?
    var canUpgradeToAnnual: Bool {
        guard let currentID = currentProductID else { return false }
        return currentID == .monthly
    }

    /// Can user downgrade to a cheaper plan?
    /// Note: We don't encourage downgrades in the UI - users should go to App Store
    var canDowngrade: Bool {
        guard let currentID = currentProductID else { return false }
        return currentID == .annual // Annual could downgrade to Monthly via App Store
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
        static let autoPremiumEnabled = "debug_auto_premium_enabled"
        static let demoAccountConfigured = "demo_account_configured_for_review"
        static let deletionTestAccountConfigured = "deletion_test_account_configured"
    }

    // MARK: - Auto Premium (Debug Feature)

    /// Enable "Auto Premium" mode for testing
    /// When enabled: User sees paywalls but they don't block access
    /// When disabled: Paywalls block access like production
    /// Defaults: ON in DEBUG builds, OFF in production
    var isAutoPremiumEnabled: Bool {
        get {
            #if DEBUG
            // Default to true in debug builds if not set
            if UserDefaults.standard.object(forKey: Keys.autoPremiumEnabled) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.autoPremiumEnabled)
            #else
            return false // Always false in production
            #endif
        }
        set {
            #if DEBUG
            UserDefaults.standard.set(newValue, forKey: Keys.autoPremiumEnabled)
            logger.log("Auto Premium \(newValue ? "enabled" : "disabled")", category: .store, level: .info, metadata: nil)
            #endif
        }
    }

    /// Actual premium status (ignores Auto Premium)
    /// Use this in paywall trigger checks to see if paywall should show
    var isPremiumActual: Bool {
        return status.isPremium
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

        // Listen for sign-out to reset state
        setupSignOutObserver()

        // NOTE: Local trial initialization removed - trials are now managed by Apple/RevenueCat
        // Users must subscribe (with 14-day free trial) during onboarding
    }

    /// Listen for sign-out notification to reset all subscription state
    private func setupSignOutObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ResetSubscriptionStateNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.resetAllState()
            }
        }
    }

    /// Reset all subscription state (called on sign-out)
    /// CRITICAL: Must clear BOTH in-memory AND UserDefaults to prevent stale data on next sign-in
    private func resetAllState() {
        logger.log("Resetting all subscription state for sign-out", category: .store, level: .info, metadata: nil)

        // Clear in-memory state
        status = .none
        trialExpiryDate = nil
        subscriptionExpiryDate = nil
        daysRemaining = nil
        willRenew = false
        isRefreshing = false
        demoAccountHasPurchased = false

        // CRITICAL: Also clear UserDefaults cache to prevent stale data on next sign-in
        // Without this, sandbox users who cleared purchases would still see old subscription status
        clearCache()

        logger.log("Subscription state reset complete (including UserDefaults cache)", category: .store, level: .info, metadata: nil)
    }

    // MARK: - Status Management

    /// Refresh subscription status from RevenueCat (or StoreKit/fake payments)
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

        // CRITICAL: Reload trial expiry date from UserDefaults (for debug UI)
        if force {
            trialExpiryDate = UserDefaults.standard.object(forKey: Keys.trialExpiryDate) as? Date
            subscriptionExpiryDate = UserDefaults.standard.object(forKey: Keys.subscriptionExpiryDate) as? Date
        }

        logger.log("Refreshing subscription status...", category: .store, level: .info, metadata: nil)

        // Check for fake payments first (DEBUG ONLY)
        if storeManager.isFakePaymentsEnabled {
            // Read subscription status directly from UserDefaults
            if let statusRaw = UserDefaults.standard.string(forKey: Keys.subscriptionStatus),
               let fakeStatus = HeirloomSubscriptionStatus(rawValue: statusRaw),
               fakeStatus.isPremium {

                logger.log("🎭 Using fake subscription status: \(fakeStatus.displayName)", category: .store, level: .info, metadata: nil)

                // Update to fake status
                updateStatus(fakeStatus)

                // Load expiry date if subscription
                if fakeStatus == .monthly || fakeStatus == .annual {
                    subscriptionExpiryDate = UserDefaults.standard.object(forKey: Keys.subscriptionExpiryDate) as? Date
                    calculateDaysRemaining()
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
                    "is_premium": isPremium,
                    "fake_subscription": true
                ])

                return
            }
        }

        // Demo account check: Force expired status for App Store Review
        // UNLESS the user has purchased this session
        // This allows Apple to see the paywall, but honors purchases when made
        if isDemoAccountConfigured {
            // CRITICAL: During active purchase window, prefer pendingPurchaseProductID
            // This prevents race conditions where stale cache returns the OLD product
            // while the new purchase is being processed
            let effectiveProduct: ProductIdentifier?
            if isInActivePurchaseWindow, let pending = pendingPurchaseProductID {
                effectiveProduct = pending
                logger.log("Demo account in active purchase - using pending product: \(pending.displayName)", category: .store, level: .info, metadata: nil)
            } else {
                effectiveProduct = currentProductID
            }

            // Primary check: if we have a product ID, the user has purchased
            // This is more reliable than the flag since it's set directly during purchase
            if let cachedProduct = effectiveProduct {
                let cachedStatus: HeirloomSubscriptionStatus
                switch cachedProduct {
                case .monthly: cachedStatus = .monthly
                case .annual: cachedStatus = .annual
                case .lifetime: cachedStatus = .lifetime
                }
                logger.log("Demo account has purchased - using product: \(cachedProduct.displayName)", category: .store, level: .info, metadata: nil)
                DeviceLogger.shared.log("🍎 [Demo] Using product: \(cachedProduct.displayName)", level: .info)

                // Ensure flag is set for consistency
                if !demoAccountHasPurchased {
                    demoAccountHasPurchased = true
                }

                // Still fetch willRenew and expiryDate from RevenueCat for cancelled status display
                // We trust our cached product ID for status, but need the renewal info
                if let subscriptionInfo = await storeManager.getSubscriptionInfo(forceRefresh: force, isDemoAccount: true) {
                    subscriptionExpiryDate = subscriptionInfo.expiryDate
                    willRenew = subscriptionInfo.willRenew
                    logger.log("Demo account subscription info: willRenew=\(subscriptionInfo.willRenew), expiry=\(subscriptionInfo.expiryDate?.description ?? "nil")", category: .store, level: .info, metadata: nil)
                }

                updateStatus(cachedStatus)
                calculateDaysRemaining()
                isRefreshing = false
                return
            }

            // Secondary check: flag was set but no cached product (shouldn't happen but handle gracefully)
            if demoAccountHasPurchased {
                logger.log("Demo account has purchased flag but no cached product - checking RevenueCat", category: .store, level: .info, metadata: nil)
                // Fall through to RevenueCat check below
            } else {
                // No purchase this session - force expired for demo account
                logger.log("Demo account configured - forcing expired status for paywall", category: .store, level: .info, metadata: nil)
                DeviceLogger.shared.log("🍎 [Demo] No purchase detected - showing expired", level: .info)
                updateStatus(.expired)
                isRefreshing = false
                return
            }
        }

        // Deletion test account: Force Monthly subscription with 7 days remaining
        // This allows Apple to test account deletion with a "premium" user
        if isDeletionTestAccountConfigured {
            logger.log("Deletion test account configured - forcing Monthly status", category: .store, level: .info, metadata: nil)
            DeviceLogger.shared.log("🧪 [DeletionTest] Forcing Monthly status with 7 days", level: .info)

            // Set Monthly status with expiry 7 days from now
            let expiryDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            subscriptionExpiryDate = expiryDate
            UserDefaults.standard.set(expiryDate, forKey: Keys.subscriptionExpiryDate)
            UserDefaults.standard.set(ProductIdentifier.monthly.rawValue, forKey: Keys.cachedProductID)

            willRenew = false  // Show as cancelled
            daysRemaining = 7

            updateStatus(.monthly)
            isRefreshing = false
            return
        }

        // Try RevenueCat first (preferred method)
        // Note: Tester accounts (tester01-05@) are treated as normal users - no special handling
        // Pass force to invalidate RevenueCat cache when needed (e.g., after manage subscription)
        // For demo accounts, pass isDemoAccount to prefer session purchase over stale sandbox data
        if let subscriptionInfo = await storeManager.getSubscriptionInfo(forceRefresh: force, isDemoAccount: isDemoAccountConfigured) {
            logger.log("RevenueCat subscription info: \(subscriptionInfo.status.displayName), willRenew: \(subscriptionInfo.willRenew)", category: .store, level: .info, metadata: nil)

            // CRITICAL: Don't let a slow refresh overwrite a recent purchase
            // This prevents race conditions where a refresh started before purchase
            // returns stale data after the purchase has already set the correct status
            // EXCEPTION: If RevenueCat detects a TRIAL, always use that - it's more accurate
            // than the product-based status we set from the purchase notification
            if let purchaseTime = lastPurchaseNotificationTime,
               Date().timeIntervalSince(purchaseTime) < purchaseProtectionWindow,
               status.isPremium,
               subscriptionInfo.status != .trial {  // Allow trial status to update
                logger.log("Skipping status update - recent purchase notification takes precedence", category: .store, level: .info, metadata: nil)
                isRefreshing = false
                return
            }

            // Update status from RevenueCat
            updateStatus(subscriptionInfo.status)
            subscriptionExpiryDate = subscriptionInfo.expiryDate
            willRenew = subscriptionInfo.willRenew

            // CRITICAL: For Apple-managed trials, set trialExpiryDate from RevenueCat
            // This ensures the trial countdown displays correctly in Settings
            if subscriptionInfo.status == .trial, let expiryDate = subscriptionInfo.expiryDate {
                trialExpiryDate = expiryDate
                UserDefaults.standard.set(expiryDate, forKey: Keys.trialExpiryDate)
                logger.log("Apple trial expiry set from RevenueCat: \(expiryDate)", category: .store, level: .info, metadata: nil)
            }

            // Cache the product ID based on status
            let productID: ProductIdentifier?
            switch subscriptionInfo.status {
            case .monthly:
                productID = .monthly
            case .annual:
                productID = .annual
            case .lifetime:
                productID = .lifetime
            default:
                productID = nil
            }

            if let productID = productID {
                UserDefaults.standard.set(productID.rawValue, forKey: Keys.cachedProductID)
            }

            // If we have a valid premium status from RevenueCat, we're done
            if subscriptionInfo.status.isPremium {
                calculateDaysRemaining()

                // Update cache timestamp
                UserDefaults.standard.set(Date(), forKey: Keys.lastStatusRefresh)

                isRefreshing = false

                logger.log(
                    "Subscription status (RevenueCat): \(status.displayName)",
                    category: .store,
                    level: .info,
                    metadata: nil
                )

                analytics.track(event: .subscriptionStatusChecked, properties: [
                    "status": status.rawValue,
                    "is_premium": isPremium,
                    "provider": "revenuecat"
                ])

                return
            }
        }

        // Fallback: Check for lifetime purchase via StoreKit
        let hasLifetime = await storeManager.hasLifetimePurchase()
        if hasLifetime {
            updateStatus(.lifetime)
            isRefreshing = false
            return
        }

        // Fallback: Check for active subscription via StoreKit
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

        // Store current product ID for plan management
        UserDefaults.standard.set(productID.rawValue, forKey: Keys.cachedProductID)

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

    /// Handle status when no active subscription found
    /// With Apple-managed trials, if user hasn't subscribed, they're on the free tier
    private func handleTrialStatus() {
        // No active subscription from RevenueCat - user is on free tier
        // NOTE: Local trial system removed. Trial status now only comes from RevenueCat
        // when user has subscribed with Apple's introductory offer (14-day free trial)
        logger.log("No active subscription - user is on free tier", category: .store, level: .info, metadata: nil)
        updateStatus(.none)
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

        // Post notification if user just became premium (trial completed with purchase or direct purchase)
        let wasPremium = oldStatus.isPremium
        let isPremiumNow = newStatus.isPremium

        if !wasPremium && isPremiumNow {
            logger.log(
                "User became premium - posting heritage unlock notification",
                category: .store,
                level: .info,
                metadata: nil
            )

            NotificationCenter.default.post(name: .userBecamePremium, object: nil)
        }

        // Post notification for credit tier updates
        // Include old/new status so listener can handle credit carry-over
        NotificationCenter.default.post(
            name: .creditTierShouldUpdate,
            object: nil,
            userInfo: [
                "oldStatus": oldStatus.rawValue,
                "newStatus": newStatus.rawValue
            ]
        )
    }

    // MARK: - Trial Management (DEPRECATED - Now Apple/RevenueCat Managed)
    //
    // NOTE: Local trial system has been removed. Trials are now managed by Apple via
    // introductory offers configured in App Store Connect. RevenueCat reads trial status
    // from Apple and reports it via customerInfo.entitlements["premium"].periodType == .trial
    //
    // Users must subscribe (with 14-day free trial) during onboarding. The trial is tied
    // to their Apple ID and cannot be reset by reinstalling or restoring backups.

    /// DEPRECATED: Local trial initialization removed
    /// Trials are now started via Apple introductory offers when user subscribes
    func initializeTrialOnBlindBoxReveal() {
        logger.log("initializeTrialOnBlindBoxReveal() called but local trials are disabled - use Apple trial via subscription", category: .store, level: .warning, metadata: nil)
        // No-op: Trials are managed by Apple/RevenueCat
    }

    /// DEPRECATED: Local trial initialization removed
    private func initializeTrialIfNeeded() {
        // No-op: Trials are managed by Apple/RevenueCat
    }

    /// DEPRECATED: Local trial after restore removed
    /// After restore, user's subscription status comes from RevenueCat (tied to Apple ID)
    func ensureTrialAfterRestore() {
        logger.log("ensureTrialAfterRestore() called - refreshing status from RevenueCat instead", category: .store, level: .info, metadata: nil)
        // Refresh from RevenueCat to get actual subscription/trial status
        Task {
            await refreshStatus(force: true)
        }
    }

    /// DEPRECATED: Local trial adjustment removed
    /// Apple trials are fixed duration (14 days) set in App Store Connect
    func adjustTrialForPlan(_ productID: ProductIdentifier) {
        // No-op: Apple trial duration is fixed in App Store Connect
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
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self = self else { return }

                // Check if notification includes the purchased product ID
                // This indicates a user-initiated purchase (should always be honored)
                if let userInfo = notification.userInfo,
                   let productIDString = userInfo["purchasedProductID"] as? String,
                   let productID = ProductIdentifier(rawValue: productIDString) {

                    self.logger.log("Subscription notification with purchased product: \(productID.displayName)", category: .store, level: .info, metadata: nil)

                    // CRITICAL: Check demo account BEFORE caching to prevent background transactions
                    // from polluting demo account state with stale sandbox data
                    if self.isDemoAccountConfigured {
                        // Must be in active purchase window AND match the product being purchased
                        let isExpectedProduct = self.pendingPurchaseProductID == nil || self.pendingPurchaseProductID == productID
                        if self.isInActivePurchaseWindow && isExpectedProduct {
                            self.demoAccountHasPurchased = true
                            self.logger.log("Demo account user-initiated purchase - will honor premium status", category: .store, level: .info, metadata: nil)
                        } else {
                            // Background transaction OR different product - ignore for demo account
                            // DO NOT cache the product ID - this is stale sandbox data
                            if !self.isInActivePurchaseWindow {
                                self.logger.log("Demo account background transaction ignored - not in active purchase window", category: .store, level: .info, metadata: nil)
                            } else {
                                self.logger.log("Demo account transaction ignored - product mismatch (expected \(self.pendingPurchaseProductID?.rawValue ?? "none"), got \(productID.rawValue))", category: .store, level: .info, metadata: nil)
                            }
                            return
                        }
                    }

                    // Track when we received this purchase notification to prevent race conditions
                    self.lastPurchaseNotificationTime = Date()

                    // Cache the product ID (only after demo account check passes)
                    UserDefaults.standard.set(productID.rawValue, forKey: Keys.cachedProductID)

                    // CRITICAL: Check RevenueCat for trial period BEFORE setting status
                    // The product ID alone doesn't tell us if user is in free trial
                    if let subscriptionInfo = await self.storeManager.getSubscriptionInfo(forceRefresh: true, isDemoAccount: self.isDemoAccountConfigured) {
                        // Use RevenueCat's actual status (which includes trial detection)
                        self.updateStatus(subscriptionInfo.status)

                        // Set expiry dates
                        if subscriptionInfo.status == .trial, let expiryDate = subscriptionInfo.expiryDate {
                            self.trialExpiryDate = expiryDate
                            UserDefaults.standard.set(expiryDate, forKey: Keys.trialExpiryDate)
                        } else if let expiryDate = subscriptionInfo.expiryDate {
                            self.subscriptionExpiryDate = expiryDate
                            UserDefaults.standard.set(expiryDate, forKey: Keys.subscriptionExpiryDate)
                        }

                        self.willRenew = subscriptionInfo.willRenew
                        self.logger.log("Subscription updated from RevenueCat after purchase: \(subscriptionInfo.status.displayName)", category: .store, level: .info, metadata: nil)
                    } else {
                        // Fallback: set status from product ID (no trial detection)
                        let newStatus: HeirloomSubscriptionStatus
                        switch productID {
                        case .monthly: newStatus = .monthly
                        case .annual: newStatus = .annual
                        case .lifetime: newStatus = .lifetime
                        }
                        self.updateStatus(newStatus)
                        self.logger.log("Subscription updated from product ID (fallback): \(newStatus.displayName)", category: .store, level: .info, metadata: nil)
                    }
                } else {
                    // No product ID in notification - this is a background transaction update
                    // For demo accounts, ignore background updates to maintain "expired" status
                    if self.isDemoAccountConfigured {
                        self.logger.log("Ignoring background subscription notification - demo account configured", category: .store, level: .info, metadata: nil)
                        return
                    }

                    // Fallback: refresh from RevenueCat
                    await self.refreshStatus(force: true)
                }
            }
        }
    }

    // MARK: - App Store Review Support

    /// Demo account email for App Store Review
    private let demoAccountEmail = "demo@heirloomrecipebox.app"

    /// Deletion test account email for App Store Review
    private let deletionTestEmail = "deletetest@heirloomrecipebox.app"

    /// Tester account email for App Store Review (fresh user flow)
    private let testerAccountEmail = "tester01@heirloomrecipebox.app"

    /// Key for tracking if demo account has purchased this session
    private static let demoAccountPurchasedKey = "demo_account_purchased_this_session"

    /// Timestamp of when a user-initiated purchase started (to distinguish from background transactions)
    private var activePurchaseStartTime: Date?

    /// The product ID being purchased (to match against incoming transactions)
    private var pendingPurchaseProductID: ProductIdentifier?

    /// How long after starting a purchase we consider notifications to be user-initiated
    private let activePurchaseWindow: TimeInterval = 60 // 60 seconds

    /// Check if demo account has purchased this session (should be treated as premium)
    /// When true, the demo account should honor RevenueCat status instead of forcing expired
    var demoAccountHasPurchased: Bool {
        get { UserDefaults.standard.bool(forKey: Self.demoAccountPurchasedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.demoAccountPurchasedKey) }
    }

    /// Call this when user initiates a purchase (before calling StoreManager.purchase)
    /// Pass the product ID so we can verify incoming transactions match what the user purchased
    func markPurchaseStarted(for productID: ProductIdentifier? = nil) {
        activePurchaseStartTime = Date()
        pendingPurchaseProductID = productID
        logger.log("User-initiated purchase started", category: .store, level: .info, metadata: productID.map { ["productID": $0.rawValue] })
    }

    /// Check if we're in an active user-initiated purchase window
    private var isInActivePurchaseWindow: Bool {
        guard let startTime = activePurchaseStartTime else { return false }
        return Date().timeIntervalSince(startTime) < activePurchaseWindow
    }

    /// Check if an email is the deletion test account
    func isDeletionTestAccount(email: String?) -> Bool {
        guard let email = email else { return false }
        return email.lowercased() == deletionTestEmail.lowercased()
    }

    /// Check if an email is the tester account (fresh user flow)
    func isTesterAccount(email: String?) -> Bool {
        guard let email = email else { return false }
        return email.lowercased() == testerAccountEmail.lowercased()
    }

    /// Key for tester account configuration
    private static let testerAccountConfiguredKey = "tester_account_configured_for_review"

    /// Check if tester account is currently configured
    var isTesterAccountConfigured: Bool {
        return UserDefaults.standard.bool(forKey: Self.testerAccountConfiguredKey)
    }

    /// Configure subscription status for tester account (fresh user experience)
    /// - Forces trial status so tester01@ appears as a free/trial user
    /// - Ignores any sandbox subscription data from shared Apple ID
    /// - Allows purchases to work normally when user chooses to subscribe
    func configureForTesterAccount() {
        logger.log("Configuring subscription for tester account (fresh user)", category: .store, level: .info, metadata: nil)
        DeviceLogger.shared.log("🧪 [Tester] Configuring for fresh user experience", level: .info)

        // Set flag to identify tester account
        UserDefaults.standard.set(true, forKey: Self.testerAccountConfiguredKey)

        // Clear any demo account flags
        UserDefaults.standard.removeObject(forKey: Keys.demoAccountConfigured)
        UserDefaults.standard.removeObject(forKey: Self.demoAccountPurchasedKey)

        // Clear cached product ID so we don't show stale subscription
        UserDefaults.standard.removeObject(forKey: Keys.cachedProductID)

        // Force trial status (not expired, not premium)
        updateStatus(.trial)

        // Set trial dates for fresh user
        let now = Date()
        UserDefaults.standard.set(now, forKey: Keys.firstLaunchDate)

        // Calculate trial expiry (14 days from now for annual-equivalent trial)
        let trialExpiry = Calendar.current.date(byAdding: .day, value: 14, to: now) ?? now
        UserDefaults.standard.set(trialExpiry, forKey: Keys.trialExpiryDate)
        trialExpiryDate = trialExpiry
        daysRemaining = 14

        logger.log("Tester account configured: trial status, 14 days remaining", category: .store, level: .info, metadata: nil)
        DeviceLogger.shared.log("🧪 [Tester] Status set to trial - 14 days remaining", level: .info)
    }

    /// Clear tester account configuration
    func clearTesterAccountConfiguration() {
        UserDefaults.standard.removeObject(forKey: Self.testerAccountConfiguredKey)
        logger.log("Tester account configuration cleared", category: .store, level: .info, metadata: nil)
    }

    /// Configure subscription status for App Store Review demo account
    /// - Expires any active trial so Apple can see the paywall
    /// - Called when demo account signs in
    func configureForAppStoreReview() {
        // CRITICAL: Don't reconfigure if user has already purchased this session
        // This prevents auth state changes from wiping purchase state
        if currentProductID != nil && demoAccountHasPurchased {
            logger.log("Skipping demo configuration - user has already purchased", category: .store, level: .info, metadata: nil)
            DeviceLogger.shared.log("🍎 [AppStoreReview] Skipping config - purchase already made", level: .info)
            return
        }

        logger.log("Configuring subscription for App Store Review demo account", category: .store, level: .info, metadata: nil)
        DeviceLogger.shared.log("🍎 [AppStoreReview] Configuring subscription for demo account", level: .info)

        // Set flag FIRST to prevent trial re-initialization
        // This persists across app restarts and SubscriptionManager re-creation
        UserDefaults.standard.set(true, forKey: Keys.demoAccountConfigured)

        // Clear any existing trial and subscription state
        UserDefaults.standard.removeObject(forKey: Keys.firstLaunchDate)
        UserDefaults.standard.removeObject(forKey: Keys.trialExpiryDate)
        UserDefaults.standard.removeObject(forKey: Keys.subscriptionExpiryDate)
        UserDefaults.standard.removeObject(forKey: Keys.lastStatusRefresh)
        UserDefaults.standard.removeObject(forKey: Keys.cachedProductID)

        // Clear RevenueCat purchase cache to prevent stale sandbox data from interfering
        // This ensures fresh sign-in starts with clean state
        storeManager.clearPurchaseCache()

        // Set status to expired (not trial, not premium)
        trialExpiryDate = nil
        subscriptionExpiryDate = nil
        daysRemaining = nil
        updateStatus(.expired)

        logger.log("Trial cleared for App Store Review - user will see paywall", category: .store, level: .info, metadata: nil)
        DeviceLogger.shared.log("🍎 [AppStoreReview] Status set to expired - paywall will show", level: .info)
    }

    /// Check if an email is the demo account
    func isDemoAccount(email: String?) -> Bool {
        guard let email = email else { return false }
        return email.lowercased() == demoAccountEmail.lowercased()
    }

    /// Clear the demo account configuration flag
    /// Call this when a non-demo user signs in to restore normal trial behavior
    func clearDemoAccountConfiguration() {
        UserDefaults.standard.removeObject(forKey: Keys.demoAccountConfigured)
        UserDefaults.standard.removeObject(forKey: Self.demoAccountPurchasedKey)
        logger.log("Demo account configuration cleared", category: .store, level: .info, metadata: nil)
    }

    /// Reset the demo account purchase flag
    /// Call this on every demo account sign-in to ensure fresh state for testing purchases
    func resetDemoAccountPurchaseFlag() {
        demoAccountHasPurchased = false
        logger.log("Demo account purchase flag reset - ready for fresh purchase testing", category: .store, level: .info, metadata: nil)
    }

    /// Check if demo account is currently configured
    var isDemoAccountConfigured: Bool {
        return UserDefaults.standard.bool(forKey: Keys.demoAccountConfigured)
    }

    /// Check if deletion test account is currently configured
    var isDeletionTestAccountConfigured: Bool {
        return UserDefaults.standard.bool(forKey: Keys.deletionTestAccountConfigured)
    }

    /// Configure subscription status for deletion test account
    /// - Shows as Monthly subscription with 7 days remaining
    /// - Allows Apple to test account deletion with a "premium" user
    func configureForDeletionTestAccount() {
        logger.log("Configuring subscription for deletion test account", category: .store, level: .info, metadata: nil)
        DeviceLogger.shared.log("🧪 [DeletionTest] Configuring subscription - Monthly with 7 days left", level: .info)

        // Set flag to prevent re-initialization
        UserDefaults.standard.set(true, forKey: Keys.deletionTestAccountConfigured)

        // Clear any existing state
        UserDefaults.standard.removeObject(forKey: Keys.firstLaunchDate)
        UserDefaults.standard.removeObject(forKey: Keys.trialExpiryDate)

        // Set as Monthly subscription expiring in 7 days
        let expiryDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        subscriptionExpiryDate = expiryDate
        UserDefaults.standard.set(expiryDate, forKey: Keys.subscriptionExpiryDate)

        // Set product ID to monthly
        UserDefaults.standard.set(ProductIdentifier.monthly.rawValue, forKey: Keys.cachedProductID)

        // Set days remaining
        daysRemaining = 7

        // Set as active but not renewing (cancelled state - shows "Cancelled - 7 days left")
        willRenew = false

        // Update status to monthly
        updateStatus(.monthly)

        logger.log("Deletion test account configured: Monthly subscription, 7 days remaining, cancelled", category: .store, level: .info, metadata: nil)
        DeviceLogger.shared.log("🧪 [DeletionTest] Status set to Monthly (cancelled) - 7 days left", level: .info)
    }

    /// Clear the deletion test account configuration flag
    func clearDeletionTestAccountConfiguration() {
        UserDefaults.standard.removeObject(forKey: Keys.deletionTestAccountConfigured)
        logger.log("Deletion test account configuration cleared", category: .store, level: .info, metadata: nil)
    }

    // MARK: - Debug

    func printTrialStatus() {
        print("=== TRIAL STATUS DEBUG ===")
        if let firstLaunch = UserDefaults.standard.object(forKey: Keys.firstLaunchDate) as? Date {
            print("First Launch Date: \(firstLaunch.description)")
        } else {
            print("First Launch Date: Not set")
        }
        print("Trial Expiry Date: \(trialExpiryDate?.description ?? "Not set")")
        print("Days Remaining: \(daysRemaining ?? 0)")
        print("Is In Trial: \(isInTrial)")
        print("Is Trial Expired: \(isTrialExpired)")
        print("Is Premium: \(isPremium)")
        print("Subscription Status: \(status.rawValue)")
        print("========================")
    }
}
