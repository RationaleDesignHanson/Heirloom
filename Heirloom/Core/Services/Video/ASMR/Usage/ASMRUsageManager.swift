//
//  ASMRUsageManager.swift
//  Heirloom
//
//  Created by Claude on 1/10/26.
//

import Foundation
import Combine

/// Manages ASMR extraction credits and usage limits
@MainActor
class ASMRUsageManager: ObservableObject {
    static let shared = ASMRUsageManager()

    // MARK: - Published State

    @Published private(set) var creditsUsedThisMonth: Int = 0
    @Published private(set) var creditsRemaining: Int = 0
    @Published private(set) var resetDate: Date = Date()

    // MARK: - Constants

    private let creditsPerExtraction = 5
    private let freeMonthlyLimit = 5      // 1 extraction for free users (5 credits)
    private let proMonthlyLimit = 20      // 4 extractions for pro users (20 credits)

    // MARK: - Dependencies

    private let subscriptionManager: SubscriptionManager
    private let userDefaults: UserDefaults

    // MARK: - UserDefaults Keys

    private let creditsUsedKey = "asmr_credits_used_this_month"
    private let resetDateKey = "asmr_credit_reset_date"

    // MARK: - Initialization

    init(
        subscriptionManager: SubscriptionManager? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.subscriptionManager = subscriptionManager ?? ServiceContainer.shared.resolve(SubscriptionManager.self)
        self.userDefaults = userDefaults

        loadUsage()
        checkMonthlyReset()
    }

    // MARK: - Public API

    /// Check if user can start a new ASMR extraction
    func canStartExtraction() -> Bool {
        checkMonthlyReset()
        return creditsRemaining >= creditsPerExtraction
    }

    /// Deduct credits when starting extraction
    func startExtraction() throws {
        guard canStartExtraction() else {
            throw ASMRUsageError.insufficientCredits(
                needed: creditsPerExtraction,
                available: creditsRemaining
            )
        }

        creditsUsedThisMonth += creditsPerExtraction
        saveUsage()
        updateRemainingCredits()
    }

    /// Refund credits if extraction fails
    func refundExtraction() {
        creditsUsedThisMonth = max(0, creditsUsedThisMonth - creditsPerExtraction)
        saveUsage()
        updateRemainingCredits()
    }

    /// Get current usage summary
    func getUsageSummary() -> UsageSummary {
        checkMonthlyReset()

        let monthlyLimit = subscriptionManager.isPremium ? proMonthlyLimit : freeMonthlyLimit
        let extractionsUsed = creditsUsedThisMonth / creditsPerExtraction
        let extractionsRemaining = creditsRemaining / creditsPerExtraction
        let extractionsTotal = monthlyLimit / creditsPerExtraction

        return UsageSummary(
            extractionsUsed: extractionsUsed,
            extractionsRemaining: extractionsRemaining,
            extractionsTotal: extractionsTotal,
            creditsUsed: creditsUsedThisMonth,
            creditsRemaining: creditsRemaining,
            resetDate: resetDate,
            isProUser: subscriptionManager.isPremium
        )
    }

    // MARK: - Private Methods

    private func loadUsage() {
        creditsUsedThisMonth = userDefaults.integer(forKey: creditsUsedKey)

        if let savedDate = userDefaults.object(forKey: resetDateKey) as? Date {
            resetDate = savedDate
        } else {
            resetDate = nextMonthStart()
            userDefaults.set(resetDate, forKey: resetDateKey)
        }

        updateRemainingCredits()
    }

    private func saveUsage() {
        userDefaults.set(creditsUsedThisMonth, forKey: creditsUsedKey)
        userDefaults.set(resetDate, forKey: resetDateKey)
    }

    private func updateRemainingCredits() {
        let monthlyLimit = subscriptionManager.isPremium ? proMonthlyLimit : freeMonthlyLimit
        creditsRemaining = max(0, monthlyLimit - creditsUsedThisMonth)
    }

    private func checkMonthlyReset() {
        if Date() >= resetDate {
            creditsUsedThisMonth = 0
            resetDate = nextMonthStart()
            saveUsage()
            updateRemainingCredits()
        }
    }

    private func nextMonthStart() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)

        if let firstOfMonth = calendar.date(from: components),
           let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth) {
            return nextMonth
        }

        // Fallback: 30 days from now
        return calendar.date(byAdding: .day, value: 30, to: now) ?? now
    }
}

// MARK: - Supporting Types

/// Usage error types
enum ASMRUsageError: LocalizedError {
    case insufficientCredits(needed: Int, available: Int)

    var errorDescription: String? {
        switch self {
        case .insufficientCredits(let needed, let available):
            return "Need \(needed) credits but only \(available) available"
        }
    }
}

/// Summary of current usage status
struct UsageSummary {
    let extractionsUsed: Int
    let extractionsRemaining: Int
    let extractionsTotal: Int
    let creditsUsed: Int
    let creditsRemaining: Int
    let resetDate: Date
    let isProUser: Bool
}
