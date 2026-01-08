//
//  SubscriptionStatus.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-08.
//

import Foundation

/// Represents the user's current subscription state
enum SubscriptionStatus: String, Codable {
    /// No subscription, never had one
    case none

    /// In active trial period (monthly or annual)
    case trial

    /// Active monthly subscription
    case monthly

    /// Active annual subscription
    case annual

    /// One-time lifetime purchase (Founding Member)
    case lifetime

    /// Subscription expired (was active, now lapsed)
    case expired

    /// Grace period (billing issue, still has access)
    case grace

    /// Computed property: does user have premium access?
    var isPremium: Bool {
        switch self {
        case .trial, .monthly, .annual, .lifetime, .grace:
            return true
        case .none, .expired:
            return false
        }
    }

    /// Is this an active subscription (not lifetime or none)?
    var isActiveSubscription: Bool {
        switch self {
        case .monthly, .annual:
            return true
        case .none, .trial, .lifetime, .expired, .grace:
            return false
        }
    }

    /// Display name for UI
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

    /// Short display name for compact UI
    var shortDisplayName: String {
        switch self {
        case .none: return "Free"
        case .trial: return "Trial"
        case .monthly: return "Monthly"
        case .annual: return "Annual"
        case .lifetime: return "Lifetime"
        case .expired: return "Expired"
        case .grace: return "Grace"
        }
    }

    /// Icon for UI (SF Symbol name)
    var icon: String {
        switch self {
        case .none: return "person"
        case .trial: return "clock.badge.checkmark"
        case .monthly: return "star.fill"
        case .annual: return "star.circle.fill"
        case .lifetime: return "crown.fill"
        case .expired: return "clock.badge.xmark"
        case .grace: return "exclamationmark.circle"
        }
    }
}
