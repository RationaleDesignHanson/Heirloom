import Foundation
import SwiftUI

/// Service for managing user privacy consents and preferences
/// Implements two-tier consent model: Sharing + Analytics
@MainActor
final class PrivacyConsentService: ObservableObject {

    // MARK: - Singleton

    static let shared = PrivacyConsentService()

    // MARK: - Published State

    @Published var hasSharingConsent: Bool {
        didSet {
            UserDefaults.standard.set(hasSharingConsent, forKey: Keys.sharingConsent)
            consentDate = hasSharingConsent ? Date() : consentDate
            if hasSharingConsent && consentDate == nil {
                consentDate = Date()
            }
        }
    }

    @Published var hasAnalyticsConsent: Bool {
        didSet {
            UserDefaults.standard.set(hasAnalyticsConsent, forKey: Keys.analyticsConsent)
            if hasAnalyticsConsent {
                AnalyticsService.shared.initialize()
            }
        }
    }

    @Published var hasSeenConsentDialog: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenConsentDialog, forKey: Keys.hasSeenConsent)
        }
    }

    @Published var consentDate: Date? {
        didSet {
            if let date = consentDate {
                UserDefaults.standard.set(date, forKey: Keys.consentDate)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.consentDate)
            }
        }
    }

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let sharingConsent = "privacy.consent.sharing"
        static let analyticsConsent = "privacy.consent.analytics"
        static let hasSeenConsent = "privacy.hasSeenConsentDialog"
        static let consentDate = "privacy.consentDate"
        static let privacyPolicyVersion = "privacy.policyVersion"
        static let lastPrivacyCheck = "privacy.lastCheck"
    }

    // MARK: - Constants

    private let currentPolicyVersion = "2024-12-19"

    // MARK: - Initialization

    private init() {
        // Load consent state from UserDefaults
        self.hasSharingConsent = UserDefaults.standard.bool(forKey: Keys.sharingConsent)
        self.hasAnalyticsConsent = UserDefaults.standard.bool(forKey: Keys.analyticsConsent)
        self.hasSeenConsentDialog = UserDefaults.standard.bool(forKey: Keys.hasSeenConsent)
        self.consentDate = UserDefaults.standard.object(forKey: Keys.consentDate) as? Date

        // Initialize analytics if consent was previously granted
        if hasAnalyticsConsent {
            AnalyticsService.shared.initialize()
        }
    }

    // MARK: - Consent Management

    /// Check if user needs to see consent dialog
    func needsConsentDialog() -> Bool {
        // Show if user hasn't seen it yet
        if !hasSeenConsentDialog {
            return true
        }

        // Show if privacy policy has been updated and user hasn't acknowledged
        let savedVersion = UserDefaults.standard.string(forKey: Keys.privacyPolicyVersion)
        if savedVersion != currentPolicyVersion {
            return true
        }

        return false
    }

    /// Mark consent dialog as seen
    func markConsentDialogSeen() {
        hasSeenConsentDialog = true
        UserDefaults.standard.set(currentPolicyVersion, forKey: Keys.privacyPolicyVersion)
        UserDefaults.standard.set(Date(), forKey: Keys.lastPrivacyCheck)
    }

    /// Grant sharing consent
    func grantSharingConsent() {
        hasSharingConsent = true
        consentDate = Date()

        // Track analytics event (if analytics consent is also granted)
        if hasAnalyticsConsent {
            AnalyticsService.shared.track(event: .settingChanged, properties: [
                "setting": "sharing_consent",
                "value": true
            ])
        }
    }

    /// Revoke sharing consent
    func revokeSharingConsent() {
        hasSharingConsent = false

        // Track analytics event (if analytics consent is granted)
        if hasAnalyticsConsent {
            AnalyticsService.shared.track(event: .settingChanged, properties: [
                "setting": "sharing_consent",
                "value": false
            ])
        }
    }

    /// Grant analytics consent
    func grantAnalyticsConsent() {
        hasAnalyticsConsent = true

        // Initialize analytics
        AnalyticsService.shared.initialize()

        // Track the consent grant
        AnalyticsService.shared.track(event: .settingChanged, properties: [
            "setting": "analytics_consent",
            "value": true
        ])
    }

    /// Revoke analytics consent
    func revokeAnalyticsConsent() {
        // Track before revoking
        if hasAnalyticsConsent {
            AnalyticsService.shared.track(event: .settingChanged, properties: [
                "setting": "analytics_consent",
                "value": false
            ])
        }

        hasAnalyticsConsent = false
    }

    /// Reset all consents (for testing or user request)
    func resetAllConsents() {
        hasSharingConsent = false
        hasAnalyticsConsent = false
        hasSeenConsentDialog = false
        consentDate = nil

        UserDefaults.standard.removeObject(forKey: Keys.sharingConsent)
        UserDefaults.standard.removeObject(forKey: Keys.analyticsConsent)
        UserDefaults.standard.removeObject(forKey: Keys.hasSeenConsent)
        UserDefaults.standard.removeObject(forKey: Keys.consentDate)
        UserDefaults.standard.removeObject(forKey: Keys.privacyPolicyVersion)
    }

    // MARK: - Consent Status

    /// Get consent status summary
    func getConsentStatus() -> ConsentStatus {
        ConsentStatus(
            hasSharing: hasSharingConsent,
            hasAnalytics: hasAnalyticsConsent,
            consentDate: consentDate,
            policyVersion: currentPolicyVersion,
            hasSeenDialog: hasSeenConsentDialog
        )
    }

    /// Whether user can access sharing features
    func canUseSharing() -> Bool {
        hasSharingConsent
    }

    /// Whether analytics tracking is enabled
    func canTrackAnalytics() -> Bool {
        hasAnalyticsConsent
    }

    // MARK: - Privacy Policy

    /// Get current privacy policy version
    func getCurrentPolicyVersion() -> String {
        currentPolicyVersion
    }

    /// Check if user has acknowledged latest policy
    func hasAcknowledgedLatestPolicy() -> Bool {
        let savedVersion = UserDefaults.standard.string(forKey: Keys.privacyPolicyVersion)
        return savedVersion == currentPolicyVersion
    }

    /// Mark latest policy as acknowledged
    func acknowledgeLatestPolicy() {
        UserDefaults.standard.set(currentPolicyVersion, forKey: Keys.privacyPolicyVersion)
        UserDefaults.standard.set(Date(), forKey: Keys.lastPrivacyCheck)
    }
}

// MARK: - Supporting Types

/// Consent status summary
struct ConsentStatus {
    let hasSharing: Bool
    let hasAnalytics: Bool
    let consentDate: Date?
    let policyVersion: String
    let hasSeenDialog: Bool

    /// User-friendly description
    var description: String {
        var parts: [String] = []

        if hasSharing {
            parts.append("Recipe Sharing")
        }
        if hasAnalytics {
            parts.append("Anonymous Analytics")
        }

        if parts.isEmpty {
            return "No consents granted"
        }

        return "Granted: " + parts.joined(separator: ", ")
    }

    /// Whether any consent is granted
    var hasAnyConsent: Bool {
        hasSharing || hasAnalytics
    }

    /// Whether all consents are granted
    var hasAllConsents: Bool {
        hasSharing && hasAnalytics
    }

    /// Formatted consent date
    var formattedConsentDate: String? {
        guard let date = consentDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - AppStorage Property Wrappers

/// Convenient property wrapper for sharing consent
@propertyWrapper
struct SharingConsentRequired: DynamicProperty {
    @ObservedObject private var service = PrivacyConsentService.shared

    var wrappedValue: Bool {
        service.hasSharingConsent
    }

    var projectedValue: Binding<Bool> {
        Binding(
            get: { service.hasSharingConsent },
            set: { newValue in
                if newValue {
                    service.grantSharingConsent()
                } else {
                    service.revokeSharingConsent()
                }
            }
        )
    }
}

/// Convenient property wrapper for analytics consent
@propertyWrapper
struct AnalyticsConsentRequired: DynamicProperty {
    @ObservedObject private var service = PrivacyConsentService.shared

    var wrappedValue: Bool {
        service.hasAnalyticsConsent
    }

    var projectedValue: Binding<Bool> {
        Binding(
            get: { service.hasAnalyticsConsent },
            set: { newValue in
                if newValue {
                    service.grantAnalyticsConsent()
                } else {
                    service.revokeAnalyticsConsent()
                }
            }
        )
    }
}
