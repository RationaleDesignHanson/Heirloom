//
//  DemoSocialGate.swift
//  Heirloom
//
//  Unified gate for demo social features.
//  Combines Remote Config, expiration check, and local toggle.
//
//  Gate logic:
//    isEnabled = RemoteConfig.demo_social_enabled
//             && !RemoteConfig.isExpired
//             && !LocalSettings.demoSocialDisabled
//

import Foundation
import Combine

/// Unified gate controlling demo social feature availability
@MainActor
final class DemoSocialGate: ObservableObject {

    // MARK: - Singleton

    static let shared = DemoSocialGate()

    // MARK: - Published State

    /// Whether demo social features are currently enabled
    @Published private(set) var isEnabled: Bool = true

    // MARK: - Dependencies

    private let config: DemoSocialConfig
    private let userDefaults: UserDefaults

    // MARK: - Debug Status

    /// Returns a human-readable status explaining why the gate is enabled/disabled
    var debugStatus: String {
        if !config.isRemoteEnabled {
            return "disabled: remote config off"
        }
        if config.isExpired {
            if let expiry = config.expirationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                return "disabled: expired on \(formatter.string(from: expiry))"
            }
            return "disabled: expired"
        }
        if isLocallyDisabled {
            return "disabled: local toggle off"
        }
        return "enabled"
    }

    /// Whether demo mode is locally disabled by user
    var isLocallyDisabled: Bool {
        userDefaults.bool(forKey: UserDefaultsKeys.demoSocialModeDisabled)
    }

    /// Whether Remote Config allows demo mode (for UI to show/hide toggle)
    var isRemotelyAvailable: Bool {
        config.isRemoteEnabled && !config.isExpired
    }

    // MARK: - Initialization

    init(
        config: DemoSocialConfig = DemoSocialConfig(),
        userDefaults: UserDefaults = .standard
    ) {
        self.config = config
        self.userDefaults = userDefaults
        refresh()
    }

    // MARK: - Public Methods

    /// Refresh the gate status based on current config and settings
    func refresh() {
        isEnabled = config.isRemoteEnabled
                 && !config.isExpired
                 && !isLocallyDisabled
    }

    /// Toggle local demo mode on/off
    func setLocallyDisabled(_ disabled: Bool) {
        userDefaults.set(disabled, forKey: UserDefaultsKeys.demoSocialModeDisabled)
        refresh()
    }
}
