//
//  CreditAnalytics.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-22.
//

import Foundation

/// Types of credit-consuming operations for analytics tracking
enum CreditOperationType: String {
    // PDF Import
    case pdfTextRich = "pdf_text_rich"
    case pdfMixed = "pdf_mixed"
    case pdfScanned = "pdf_scanned"
    
    // Video Import
    case videoRegular = "video_regular"
    case videoASMR = "video_asmr"
    
    // AI Generation
    case aiImage = "ai_image"
    case aiBackground = "ai_background"
    
    var displayName: String {
        switch self {
        case .pdfTextRich: return "PDF (Text-Rich)"
        case .pdfMixed: return "PDF (Mixed)"
        case .pdfScanned: return "PDF (Scanned)"
        case .videoRegular: return "Video (Audio)"
        case .videoASMR: return "Video (ASMR)"
        case .aiImage: return "AI Image"
        case .aiBackground: return "AI Background"
        }
    }
    
    var creditCost: Int {
        switch self {
        case .pdfTextRich: return 1
        case .pdfMixed: return 3
        case .pdfScanned: return 5
        case .videoRegular: return 1
        case .videoASMR: return 5
        case .aiImage: return 1
        case .aiBackground: return 1
        }
    }
}

/// Helper functions for tracking credit-related analytics events
@MainActor
enum CreditAnalytics {
    
    /// Track a credit deduction event
    /// - Parameters:
    ///   - analytics: AnalyticsService instance
    ///   - userCredits: Current UserCredits state (after deduction)
    ///   - operationType: The type of operation that consumed credits
    ///   - amount: Number of credits deducted
    ///   - subscriptionManager: SubscriptionManager for tier info
    static func trackDeduction(
        analytics: AnalyticsServiceProtocol,
        userCredits: UserCredits,
        operationType: CreditOperationType,
        amount: Int,
        subscriptionManager: SubscriptionManager
    ) {
        let properties: [String: Any] = [
            "operation_type": operationType.rawValue,
            "operation_name": operationType.displayName,
            "credits_amount": amount,
            "tier_type": userCredits.tierType,
            "subscription_plan": subscriptionManager.status.rawValue,
            "is_premium": subscriptionManager.isPremium,
            "credits_remaining_total": userCredits.availableCredits,
            "credits_remaining_tier": userCredits.tierCreditsRemaining,
            "credits_remaining_purchased": userCredits.creditsBalance
        ]
        
        analytics.track(event: .creditDeducted, properties: properties)
        
        Log.info("Credit deduction tracked", category: .general, metadata: [
            "operation": operationType.rawValue,
            "amount": amount,
            "remaining": userCredits.availableCredits
        ])
    }
    
    /// Track a credit refund event
    /// - Parameters:
    ///   - analytics: AnalyticsService instance
    ///   - userCredits: Current UserCredits state (after refund)
    ///   - operationType: The type of operation that was refunded
    ///   - amount: Number of credits refunded
    ///   - reason: Reason for the refund
    ///   - subscriptionManager: SubscriptionManager for tier info
    static func trackRefund(
        analytics: AnalyticsServiceProtocol,
        userCredits: UserCredits,
        operationType: CreditOperationType,
        amount: Int,
        reason: String,
        subscriptionManager: SubscriptionManager
    ) {
        let properties: [String: Any] = [
            "operation_type": operationType.rawValue,
            "operation_name": operationType.displayName,
            "credits_amount": amount,
            "refund_reason": reason,
            "tier_type": userCredits.tierType,
            "subscription_plan": subscriptionManager.status.rawValue,
            "is_premium": subscriptionManager.isPremium,
            "credits_remaining_total": userCredits.availableCredits,
            "credits_remaining_tier": userCredits.tierCreditsRemaining,
            "credits_remaining_purchased": userCredits.creditsBalance
        ]
        
        analytics.track(event: .creditRefunded, properties: properties)
        
        Log.info("Credit refund tracked", category: .general, metadata: [
            "operation": operationType.rawValue,
            "amount": amount,
            "reason": reason,
            "remaining": userCredits.availableCredits
        ])
    }
}
