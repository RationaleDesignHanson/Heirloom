//
//  UserCredits.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-03.
//

import Foundation
import SwiftData

/// Tracks user's PDF import credit balance and daily quota
/// - Daily quota: 25 free credits per day (resets at midnight)
/// - Purchased credits: Never expire, rollover indefinitely
/// - Deduction order: Uses daily quota first, then purchased credits
@Model
final class UserCredits {

    // MARK: - Properties

    var userId: String
    var creditsBalance: Int = 0          // Purchased credits (never expire)
    var dailyQuotaUsed: Int = 0          // How many free credits used today
    var dailyQuotaResetDate: Date = Date()
    var lastPurchaseDate: Date?
    var lifetimePurchasedCredits: Int = 0 // Analytics: total credits ever purchased

    // MARK: - Constants

    /// Daily free quota (25 credits = 5 scanned PDFs OR 25 text PDFs)
    static let dailyFreeQuota = 25

    // MARK: - Initialization

    init(userId: String) {
        self.userId = userId
        self.creditsBalance = 0
        self.dailyQuotaUsed = 0
        self.dailyQuotaResetDate = Date()
    }

    // MARK: - Computed Properties

    /// Total credits available today (quota + purchased)
    var availableToday: Int {
        resetDailyQuotaIfNeeded()
        let quotaRemaining = max(0, Self.dailyFreeQuota - dailyQuotaUsed)
        return quotaRemaining + creditsBalance
    }

    /// Remaining free quota for today
    var quotaRemaining: Int {
        resetDailyQuotaIfNeeded()
        return max(0, Self.dailyFreeQuota - dailyQuotaUsed)
    }

    /// When the daily quota will reset (next midnight)
    var quotaResetTime: Date {
        Calendar.current.startOfDay(for: Date().addingTimeInterval(24 * 60 * 60))
    }

    // MARK: - Credit Operations

    /// Check if user can afford a given credit cost
    func canAfford(credits: Int) -> Bool {
        return availableToday >= credits
    }

    /// Deduct credits from user's balance
    /// - Deducts from daily quota first, then from purchased credits
    /// - Throws error if insufficient credits
    func deductCredits(_ amount: Int) throws {
        resetDailyQuotaIfNeeded()

        guard canAfford(credits: amount) else {
            throw CreditError.insufficientCredits(
                needed: amount,
                available: availableToday
            )
        }

        // Deduct from daily quota first
        let fromQuota = min(amount, Self.dailyFreeQuota - dailyQuotaUsed)
        dailyQuotaUsed += fromQuota

        // Deduct remainder from purchased credits
        let remaining = amount - fromQuota
        if remaining > 0 {
            creditsBalance -= remaining
        }

        Log.info("Credits deducted", category: .general, metadata: [
            "amount": amount,
            "fromQuota": fromQuota,
            "fromPurchased": remaining,
            "remainingBalance": creditsBalance,
            "remainingQuota": quotaRemaining
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

    /// Reset daily quota if a new day has started
    @discardableResult
    func resetDailyQuotaIfNeeded() -> Bool {
        let calendar = Calendar.current
        if !calendar.isDateInToday(dailyQuotaResetDate) {
            Log.info("Daily quota reset", category: .general, metadata: [
                "previousUsed": dailyQuotaUsed,
                "newQuota": Self.dailyFreeQuota
            ])

            dailyQuotaUsed = 0
            dailyQuotaResetDate = Date()
            return true
        }
        return false
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
