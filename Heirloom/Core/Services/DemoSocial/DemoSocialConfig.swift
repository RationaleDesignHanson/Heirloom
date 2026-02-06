//
//  DemoSocialConfig.swift
//  Heirloom
//
//  Remote Config wrapper for demo social feature flags.
//  Demo mode defaults ON in all builds - use Remote Config to disable globally.
//

import Foundation
import FirebaseCore
import FirebaseRemoteConfig

/// Protocol for demo social configuration (enables testing)
@MainActor
protocol DemoSocialConfigProtocol {
    var isRemoteEnabled: Bool { get }
    var expirationDate: Date? { get }
    var isExpired: Bool { get }
}

/// Configuration for demo social features from Remote Config
@MainActor
final class DemoSocialConfig: ObservableObject, DemoSocialConfigProtocol {

    // MARK: - Remote Config Keys

    static let demoSocialEnabledKey = "demo_social_enabled"
    static let demoSocialExpirationKey = "demo_social_expiration"

    // MARK: - Properties

    private let remoteConfig: RemoteConfig?

    /// Whether demo social is enabled in Remote Config (defaults to true)
    var isRemoteEnabled: Bool {
        guard let remoteConfig = remoteConfig else {
            return true  // Default to enabled when Firebase not configured (tests)
        }

        let configValue = remoteConfig.configValue(forKey: Self.demoSocialEnabledKey)

        // If never fetched or static default, return true (demo ON by default)
        if configValue.source == .static {
            return true
        }

        return configValue.boolValue
    }

    /// Optional expiration date from Remote Config (ISO8601 format)
    var expirationDate: Date? {
        guard let remoteConfig = remoteConfig else {
            return nil  // No expiration when Firebase not configured
        }

        let configValue = remoteConfig.configValue(forKey: Self.demoSocialExpirationKey)

        // If no value or empty string, no expiration
        guard configValue.source != .static else { return nil }

        let dateString = configValue.stringValue
        guard !dateString.isEmpty else { return nil }

        // Parse ISO8601 date
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }

    /// Whether the demo social feature has expired based on kill-switch date
    var isExpired: Bool {
        guard let expiration = expirationDate else {
            return false // No expiration set
        }
        return Date() > expiration
    }

    // MARK: - Initialization

    init(remoteConfig: RemoteConfig? = nil) {
        // Only initialize RemoteConfig if Firebase is configured
        if FirebaseApp.app() != nil {
            self.remoteConfig = remoteConfig ?? RemoteConfig.remoteConfig()
            setDefaultValues()
        } else {
            self.remoteConfig = remoteConfig
        }
    }

    // MARK: - Private Methods

    /// Set default values for demo social config (demo ON by default)
    private func setDefaultValues() {
        guard let remoteConfig = remoteConfig else { return }
        let defaults: [String: NSObject] = [
            Self.demoSocialEnabledKey: NSNumber(value: true),
            Self.demoSocialExpirationKey: "" as NSString  // Empty = no expiry
        ]
        remoteConfig.setDefaults(defaults)
    }
}
