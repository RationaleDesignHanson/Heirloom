//
//  HeirloomSubscriptionStatus.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-08.
//

import Foundation

/// Heirloom subscription status
/// Renamed to avoid conflict with StoreKit's Product.SubscriptionInfo.Status
enum HeirloomSubscriptionStatus: String, Codable {
    case none           // No subscription
    case trial          // In trial period
    case monthly        // Active monthly subscription
    case annual         // Active annual subscription
    case lifetime       // Lifetime purchase
    case expired        // Subscription expired
    case grace          // Grace period after payment issue

    var displayName: String {
        switch self {
        case .none: return "Free"
        case .trial: return "Premium Trial"
        case .monthly: return "Premium (Monthly)"
        case .annual: return "Premium (Annual)"
        case .lifetime: return "Premium (Lifetime)"
        case .expired: return "Expired"
        case .grace: return "Grace Period"
        }
    }

    /// Whether this status grants premium features
    var isPremium: Bool {
        switch self {
        case .trial, .monthly, .annual, .lifetime, .grace:
            return true
        case .none, .expired:
            return false
        }
    }

    /// Whether this is an active subscription (not lifetime)
    var isSubscription: Bool {
        switch self {
        case .monthly, .annual:
            return true
        case .none, .trial, .lifetime, .expired, .grace:
            return false
        }
    }

    /// Whether user is in trial
    var isTrial: Bool {
        return self == .trial
    }
}
