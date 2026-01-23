//
//  FeatureFlagManager.swift
//  Heirloom
//
//  Manages feature flags with precedence: Compile-time > Local override > Remote > Default
//  Created: 2026-01-13
//

import Foundation
import Observation

/// Manages feature flags for the Heirloom app
/// Supports compile-time, local development, and remote (Firebase) feature flags
@MainActor
@Observable
final class FeatureFlagManager {

    // MARK: - Singleton

    @MainActor
    static let shared = FeatureFlagManager()

    // MARK: - Dependencies

    private let localProvider: LocalFeatureFlagProvider
    private var remoteProvider: RemoteFeatureFlagProvider?

    // MARK: - State

    /// Tracks which features are currently enabled (for UI updates)
    private var enabledFeatures: Set<Feature> = []

    // MARK: - Initialization

    private init(
        localProvider: LocalFeatureFlagProvider? = nil,
        remoteProvider: RemoteFeatureFlagProvider? = nil
    ) {
        self.localProvider = localProvider ?? LocalFeatureFlagProvider()
        self.remoteProvider = remoteProvider

        // Initialize enabled features set
        refreshEnabledFeatures()
    }

    // MARK: - Feature Flag Checking

    /// Check if a feature is enabled
    /// Precedence: Compile-time > Local override > Remote > Default (true)
    func isEnabled(_ feature: Feature) -> Bool {
        // 1. Compile-time flags (highest precedence)
        #if FEATURE_ALL_DISABLED
        return false
        #endif

        // 2. Local development override
        if let localOverride = localProvider.override(for: feature) {
            return localOverride
        }

        // 3. Remote flag (Firebase Remote Config) - Phase 3
        if let remoteProvider = remoteProvider,
           let remoteValue = remoteProvider.value(for: feature) {
            return remoteValue
        }

        // 4. Default: All features enabled by default
        return true
    }

    /// Check if a feature is available for the current user
    /// Considers subscription status for premium features
    func isAvailable(_ feature: Feature, subscriptionManager: SubscriptionManager) -> Bool {
        // First check if feature is enabled
        guard isEnabled(feature) else {
            return false
        }

        // Check if feature requires premium
        if feature.requiresPremium {
            return subscriptionManager.isPremium
        }

        return true
    }

    // MARK: - Local Overrides

    /// Set a local override for a feature (debug menu)
    func setLocalOverride(_ feature: Feature, enabled: Bool) {
        localProvider.setOverride(feature, enabled: enabled)
        refreshEnabledFeatures()
    }

    /// Clear a specific local override
    func clearLocalOverride(_ feature: Feature) {
        localProvider.clearOverride(feature)
        refreshEnabledFeatures()
    }

    /// Clear all local overrides
    func clearAllLocalOverrides() {
        localProvider.clearAllOverrides()
        refreshEnabledFeatures()
    }

    /// Get the current local override for a feature (if any)
    func localOverride(for feature: Feature) -> Bool? {
        return localProvider.override(for: feature)
    }

    // MARK: - Remote Config (Phase 3)

    /// Set remote provider (will be implemented in Phase 3)
    func setRemoteProvider(_ provider: RemoteFeatureFlagProvider) {
        self.remoteProvider = provider
        refreshEnabledFeatures()
    }

    /// Fetch remote feature flags (Phase 3)
    func fetchRemoteFlags() async {
        guard let remoteProvider = remoteProvider else { return }
        await remoteProvider.fetch()
        refreshEnabledFeatures()
    }

    // MARK: - Private Helpers

    /// Refresh the set of enabled features (for UI observation)
    private func refreshEnabledFeatures() {
        enabledFeatures = Set(Feature.allCases.filter { isEnabled($0) })
    }
}

// MARK: - Feature Flag Provider Protocol

/// Protocol for feature flag providers (local, remote, etc.)
@MainActor
protocol FeatureFlagProvider {
    func value(for feature: Feature) -> Bool?
}

// MARK: - Local Feature Flag Provider

/// Manages local feature flag overrides via UserDefaults
@MainActor
final class LocalFeatureFlagProvider: FeatureFlagProvider {

    private let userDefaults: UserDefaults
    private let keyPrefix = "feature_flag_override_"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Get local override for a feature
    func override(for feature: Feature) -> Bool? {
        let key = keyPrefix + feature.rawValue
        guard userDefaults.object(forKey: key) != nil else {
            return nil
        }
        return userDefaults.bool(forKey: key)
    }

    /// Get value (same as override for local provider)
    func value(for feature: Feature) -> Bool? {
        return override(for: feature)
    }

    /// Set local override
    func setOverride(_ feature: Feature, enabled: Bool) {
        let key = keyPrefix + feature.rawValue
        userDefaults.set(enabled, forKey: key)
    }

    /// Clear specific override
    func clearOverride(_ feature: Feature) {
        let key = keyPrefix + feature.rawValue
        userDefaults.removeObject(forKey: key)
    }

    /// Clear all overrides
    func clearAllOverrides() {
        for feature in Feature.allCases {
            clearOverride(feature)
        }
    }
}

// MARK: - Remote Feature Flag Provider (Phase 3)

/// Protocol for remote feature flag providers (Firebase Remote Config)
/// Will be implemented in Phase 3
@MainActor
protocol RemoteFeatureFlagProvider: FeatureFlagProvider {
    func fetch() async
    func activateFetched() async
}
