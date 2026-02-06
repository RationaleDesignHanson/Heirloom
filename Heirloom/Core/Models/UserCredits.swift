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
        resetTierCreditsIfNeeded()

        guard canAfford(credits: amount) else {
            throw CreditError.insufficientCredits(
                needed: amount,
                available: availableCredits
            )
        }

        // Deduct from tier credits first
        let tierAllocation = currentTierType.creditAllocation
        let fromTier = min(amount, tierAllocation - tierCreditsUsed)
        tierCreditsUsed += fromTier

        // Deduct remainder from purchased credits
        let remaining = amount - fromTier
        if remaining > 0 {
            creditsBalance -= remaining
        }

        Log.info("Credits deducted", category: .general, metadata: [
            "amount": amount,
            "fromTier": fromTier,
            "fromPurchased": remaining,
            "remainingBalance": creditsBalance,
            "remainingTierCredits": tierCreditsRemaining,
            "tierType": tierType
        ])
    }

    /// Add purchased credits to user's balance
    func addPurchasedCredits(_ amount: Int) {
        creditsBalance += amount
        lifetimePurchasedCredits += amount
        lastPurchaseDate = Date()

        Log.info("Credits purchased", category: .general, metadata: [
            "amount": amount,
            "newBalance": creditsBalance,
            "lifetimeTotal": lifetimePurchasedCredits
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

        Log.info("Tier updated", category: .general, metadata: [
            "oldTier": oldTier,
            "newTier": newTier.rawValue,
            "resetCredits": resetCredits,
            "carryOverCredits": carryOverCredits
        ])
    }

    /// Reset to trial state (for first-time user reset)
    func resetToTrial() {
        tierCreditsUsed = 0
        tierCreditResetDate = Date()
        tierType = TierType.trial.rawValue
        creditsBalance = 0  // Wipe purchased credits on full reset

        Log.info("Credits reset to trial state", category: .general, metadata: [
            "tierCredits": Self.trialCredits
        ])
    }

    /// Reset tier credits if a new period has started (premium only - monthly reset)
    @discardableResult
    func resetTierCreditsIfNeeded() -> Bool {
        // Only premium tier resets monthly
        guard currentTierType == .premium else { return false }

        let calendar = Calendar.current
        let monthsSinceReset = calendar.dateComponents([.month], from: tierCreditResetDate, to: Date()).month ?? 0

        if monthsSinceReset >= 1 {
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
