//
//  UserCredits.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-03.
//

import Foundation
import SwiftData

/// Tracks user's credit balance based on subscription tier
/// - Trial users: 50 credits for the entire trial period (no reset)
/// - Premium users: 100 credits per month (resets monthly)
/// - Purchased credits: Never expire, rollover indefinitely
/// - Deduction order: Uses tier credits first, then purchased credits
@Model
final class UserCredits {

    // MARK: - Properties

    var userId: String
    var creditsBalance: Int = 0              // Purchased credits (never expire)
    var tierCreditsUsed: Int = 0             // Credits used in current tier period
    var tierCreditResetDate: Date = Date()   // When tier credits were last reset
    var tierType: String = "trial"           // "trial", "premium", "expired", "none"
    var lastPurchaseDate: Date?
    var lifetimePurchasedCredits: Int = 0    // Analytics: total credits ever purchased

    // MARK: - Constants

    /// Trial credits (50 for entire trial period)
    static let trialCredits = 50

    /// Premium monthly credits (100 per month)
    static let premiumMonthlyCredits = 100

    // MARK: - Tier Types

    enum TierType: String {
        case trial = "trial"
        case premium = "premium"
        case expired = "expired"
        case none = "none"

        var creditAllocation: Int {
            switch self {
            case .trial: return UserCredits.trialCredits
            case .premium: return UserCredits.premiumMonthlyCredits
            case .expired, .none: return 0
            }
        }
    }

    /// Current tier type as enum
    var currentTierType: TierType {
        TierType(rawValue: tierType) ?? .none
    }

    // MARK: - Initialization

    init(userId: String) {
        self.userId = userId
        self.creditsBalance = 0
        self.tierCreditsUsed = 0
        self.tierCreditResetDate = Date()
        self.tierType = TierType.trial.rawValue
    }

    // MARK: - Computed Properties

    /// Total credits available (tier credits + purchased)
    var availableCredits: Int {
        resetTierCreditsIfNeeded()
        let tierRemaining = max(0, currentTierType.creditAllocation - tierCreditsUsed)
        return tierRemaining + creditsBalance
    }

    /// Remaining tier credits for current period
    var tierCreditsRemaining: Int {
        resetTierCreditsIfNeeded()
        return max(0, currentTierType.creditAllocation - tierCreditsUsed)
    }

    /// When the tier credits will reset (for premium: next month; for trial: never)
    var tierResetTime: Date? {
        guard currentTierType == .premium else { return nil }
        // Next month from the reset date
        return Calendar.current.date(byAdding: .month, value: 1, to: tierCreditResetDate)
    }

    /// Whether credits reset periodically (only premium resets monthly)
    var hasPeriodicReset: Bool {
        currentTierType == .premium
    }

    // MARK: - Legacy Compatibility

    /// Alias for availableCredits (backwards compatibility)
    var availableToday: Int { availableCredits }

    /// Alias for tierCreditsRemaining (backwards compatibility)
    var quotaRemaining: Int { tierCreditsRemaining }

    /// Alias for tierResetTime (backwards compatibility)
    var quotaResetTime: Date {
        tierResetTime ?? Calendar.current.startOfDay(for: Date().addingTimeInterval(24 * 60 * 60))
    }

    /// Legacy constant for backwards compatibility
    static var dailyFreeQuota: Int { trialCredits }

    // MARK: - Credit Operations

    /// Check if user can afford a given credit cost
    func canAfford(credits: Int) -> Bool {
        return availableCredits >= credits
    }

    /// Deduct credits from user's balance
    /// - Deducts from tier credits first, then from purchased credits
    /// - Throws error if insufficient credits
    func deductCredits(_ amount: Int) throws {
        // Snapshot state BEFORE any changes for debugging
        let snapshotBefore = CreditSnapshot(
            tierType: tierType,
            tierAllocation: currentTierType.creditAllocation,
            tierCreditsUsed: tierCreditsUsed,
            purchasedCredits: creditsBalance,
            totalAvailable: availableCredits
        )

        resetTierCreditsIfNeeded()

        guard canAfford(credits: amount) else {
            // Log detailed state when deduction fails
            DeviceLogger.shared.log("💳 [Credits] INSUFFICIENT - needed: \(amount), available: \(availableCredits), tier: \(tierType), tierUsed: \(tierCreditsUsed)/\(currentTierType.creditAllocation), purchased: \(creditsBalance)", level: .error)
            throw CreditError.insufficientCredits(
                needed: amount,
                available: availableCredits
            )
        }

        // Deduct from tier credits first
        let tierAllocation = currentTierType.creditAllocation
        let tierRemaining = tierAllocation - tierCreditsUsed
        let fromTier = min(amount, tierRemaining)
        tierCreditsUsed += fromTier

        // Deduct remainder from purchased credits
        let fromPurchased = amount - fromTier
        if fromPurchased > 0 {
            creditsBalance -= fromPurchased
        }

        // Snapshot state AFTER changes
        let snapshotAfter = CreditSnapshot(
            tierType: tierType,
            tierAllocation: currentTierType.creditAllocation,
            tierCreditsUsed: tierCreditsUsed,
            purchasedCredits: creditsBalance,
            totalAvailable: availableCredits
        )

        // SAFEGUARD: Verify deduction math is correct
        let expectedTotalAfter = snapshotBefore.totalAvailable - amount
        if snapshotAfter.totalAvailable != expectedTotalAfter {
            DeviceLogger.shared.log("💳 [Credits] ⚠️ MATH ERROR - expected \(expectedTotalAfter) after deducting \(amount) from \(snapshotBefore.totalAvailable), but got \(snapshotAfter.totalAvailable)", level: .error)
            DeviceLogger.shared.log("💳 [Credits] BEFORE: \(snapshotBefore)", level: .error)
            DeviceLogger.shared.log("💳 [Credits] AFTER: \(snapshotAfter)", level: .error)
        }

        // SAFEGUARD: Verify credits never go negative
        if creditsBalance < 0 {
            DeviceLogger.shared.log("💳 [Credits] ⚠️ NEGATIVE BALANCE - purchased credits went negative: \(creditsBalance)", level: .error)
            creditsBalance = 0 // Auto-correct to prevent further issues
        }

        if tierCreditsUsed > tierAllocation {
            DeviceLogger.shared.log("💳 [Credits] ⚠️ TIER OVERUSE - tierCreditsUsed (\(tierCreditsUsed)) > allocation (\(tierAllocation))", level: .error)
            tierCreditsUsed = tierAllocation // Auto-correct
        }

        // Log successful deduction with full details
        DeviceLogger.shared.log("💳 [Credits] DEDUCTED \(amount) = \(fromTier) tier + \(fromPurchased) purchased | Remaining: \(availableCredits) total (\(tierCreditsRemaining) tier + \(creditsBalance) purchased)", level: .info)

        Log.info("Credits deducted", category: .general, metadata: [
            "amount": amount,
            "fromTier": fromTier,
            "fromPurchased": fromPurchased,
            "remainingBalance": creditsBalance,
            "remainingTierCredits": tierCreditsRemaining,
            "tierType": tierType
        ])

        // Warn when credits are getting low
        if availableCredits <= 5 && availableCredits > 0 {
            DeviceLogger.shared.log("💳 [Credits] ⚠️ LOW CREDITS WARNING - only \(availableCredits) credits remaining", level: .warning)
        } else if availableCredits == 0 {
            DeviceLogger.shared.log("💳 [Credits] 🚨 OUT OF CREDITS - user has 0 credits remaining", level: .warning)
        }
    }

    /// Add purchased credits to user's balance
    func addPurchasedCredits(_ amount: Int) {
        let previousBalance = creditsBalance
        creditsBalance += amount
        lifetimePurchasedCredits += amount
        lastPurchaseDate = Date()

        DeviceLogger.shared.log("💳 [Credits] PURCHASED +\(amount) | Balance: \(previousBalance) → \(creditsBalance) | Total available: \(availableCredits)", level: .info)

        Log.info("Credits purchased", category: .general, metadata: [
            "amount": amount,
            "newBalance": creditsBalance,
            "lifetimeTotal": lifetimePurchasedCredits
        ])
    }

    /// Refund credits to user's balance (e.g., when a processing job fails)
    /// - Reduces tierCreditsUsed first, then adds to purchased balance
    func refundCredits(_ amount: Int) {
        guard amount > 0 else { return }

        let previousState = debugDescription

        // First, reduce tierCreditsUsed (reverse of deduction order)
        let tierRefund = min(amount, tierCreditsUsed)
        tierCreditsUsed -= tierRefund

        // Any remainder goes to purchased credits as a bonus
        let remainderToBalance = amount - tierRefund
        if remainderToBalance > 0 {
            creditsBalance += remainderToBalance
        }

        DeviceLogger.shared.log("💳 [Credits] REFUNDED +\(amount) = \(tierRefund) to tier + \(remainderToBalance) to balance | Before: \(previousState) | After: \(debugDescription)", level: .info)

        Log.info("Credits refunded", category: .general, metadata: [
            "amount": amount,
            "toTier": tierRefund,
            "toBalance": remainderToBalance,
            "newTierUsed": tierCreditsUsed,
            "newBalance": creditsBalance
        ])
    }

    // MARK: - Tier Management

    /// Update tier type and optionally reset credits
    /// - Parameters:
    ///   - newTier: The new tier type
    ///   - resetCredits: Whether to reset tier credits (true for new subscription period)
    ///   - carryOverCredits: Credits to carry over from previous tier (e.g., trial → premium)
    func updateTier(_ newTier: TierType, resetCredits: Bool = true, carryOverCredits: Int = 0) {
        let oldTier = tierType
        let oldAllocation = currentTierType.creditAllocation
        let oldUsed = tierCreditsUsed

        tierType = newTier.rawValue

        if resetCredits {
            tierCreditsUsed = 0
            tierCreditResetDate = Date()
        }

        // Add carry-over credits to purchased balance (they become "bonus" credits)
        if carryOverCredits > 0 {
            creditsBalance += carryOverCredits
            Log.info("Credits carried over from previous tier", category: .general, metadata: [
                "carryOver": carryOverCredits,
                "newBalance": creditsBalance
            ])
        }

        DeviceLogger.shared.log("💳 [Credits] TIER CHANGE: \(oldTier) → \(newTier.rawValue) | Old allocation: \(oldAllocation) (used \(oldUsed)) | New allocation: \(newTier.creditAllocation) | Purchased: \(creditsBalance) | Total available: \(availableCredits)", level: .info)

        Log.info("Tier updated", category: .general, metadata: [
            "oldTier": oldTier,
            "newTier": newTier.rawValue,
            "resetCredits": resetCredits,
            "carryOverCredits": carryOverCredits
        ])
    }

    /// Reset to trial state (for first-time user reset)
    func resetToTrial() {
        let previousState = debugDescription

        tierCreditsUsed = 0
        tierCreditResetDate = Date()
        tierType = TierType.trial.rawValue
        creditsBalance = 0  // Wipe purchased credits on full reset

        DeviceLogger.shared.log("💳 [Credits] RESET TO TRIAL | Before: \(previousState) | After: \(debugDescription)", level: .warning)

        Log.info("Credits reset to trial state", category: .general, metadata: [
            "tierCredits": Self.trialCredits
        ])
    }

    // MARK: - Debug Helpers

    /// Debug description of current credit state
    var debugDescription: String {
        "tier=\(tierType) alloc=\(currentTierType.creditAllocation) used=\(tierCreditsUsed) remaining=\(tierCreditsRemaining) purchased=\(creditsBalance) total=\(availableCredits)"
    }

    /// Log current credit state (call this to diagnose issues)
    func logCurrentState(context: String = "STATE CHECK") {
        DeviceLogger.shared.log("💳 [Credits] \(context) | \(debugDescription)", level: .info)
    }

    /// Reset tier credits if a new period has started (premium only - monthly reset)
    @discardableResult
    func resetTierCreditsIfNeeded() -> Bool {
        // Only premium tier resets monthly
        guard currentTierType == .premium else { return false }

        let calendar = Calendar.current
        let monthsSinceReset = calendar.dateComponents([.month], from: tierCreditResetDate, to: Date()).month ?? 0

        if monthsSinceReset >= 1 {
            let previousUsed = tierCreditsUsed

            DeviceLogger.shared.log("💳 [Credits] MONTHLY RESET - tier credits restored | Previously used: \(previousUsed)/\(Self.premiumMonthlyCredits) → Now: 0/\(Self.premiumMonthlyCredits)", level: .info)

            Log.info("Monthly tier credits reset", category: .general, metadata: [
                "previousUsed": tierCreditsUsed,
                "newAllocation": Self.premiumMonthlyCredits
            ])

            tierCreditsUsed = 0
            tierCreditResetDate = Date()
            return true
        }
        return false
    }

    // MARK: - Legacy Method

    /// Legacy method for backwards compatibility
    @discardableResult
    func resetDailyQuotaIfNeeded() -> Bool {
        return resetTierCreditsIfNeeded()
    }
}

// MARK: - CreditSnapshot (for debugging)

/// Snapshot of credit state for debugging deduction issues
struct CreditSnapshot: CustomStringConvertible {
    let tierType: String
    let tierAllocation: Int
    let tierCreditsUsed: Int
    let purchasedCredits: Int
    let totalAvailable: Int

    var tierRemaining: Int {
        max(0, tierAllocation - tierCreditsUsed)
    }

    var description: String {
        "tier=\(tierType) alloc=\(tierAllocation) used=\(tierCreditsUsed) remaining=\(tierRemaining) purchased=\(purchasedCredits) total=\(totalAvailable)"
    }
}

// MARK: - CreditError

enum CreditError: LocalizedError {
    case insufficientCredits(needed: Int, available: Int)

    var errorDescription: String? {
        switch self {
        case .insufficientCredits(let needed, let available):
            return "Not enough credits. You need \(needed) credits but only have \(available) available."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .insufficientCredits(let needed, let available):
            let shortfall = needed - available
            return "Purchase \(shortfall) more credits or queue this import for tomorrow."
        }
    }
}

// MARK: - Credit Cost Constants

extension UserCredits {
    /// Credit costs for different PDF types
    enum PDFCreditCost: Int {
        case textRich = 1    // Nearly free to process (text extraction + batch analysis)
        case mixed = 3       // Average cost (some text, some Vision API)
        case scanned = 5     // Expensive (full Vision API pipeline)
    }

    /// Credit costs for different video extraction modes
    enum VideoCreditCost: Int {
        case regular = 1     // Audio transcription or OCR mode (on-device processing)
        case asmr = 5        // ASMR/Vision mode (Claude Vision API, expensive)

        var displayName: String {
            switch self {
            case .regular: return "Audio"
            case .asmr: return "ASMR"
            }
        }

        var description: String {
            switch self {
            case .regular: return "Uses audio transcription or on-screen text"
            case .asmr: return "Uses AI vision analysis (for silent/music videos)"
            }
        }
    }
}
