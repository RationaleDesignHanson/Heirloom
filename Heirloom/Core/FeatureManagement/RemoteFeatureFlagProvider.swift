//
//  RemoteFeatureFlagProvider.swift
//  Heirloom
//
//  Firebase Remote Config provider for feature flags
//  Created: 2026-01-13
//

import Foundation
import FirebaseRemoteConfig

/// Firebase Remote Config provider for feature flags
/// Fetches feature flags from Firebase with 12-hour cache TTL
@MainActor
final class FirebaseFeatureFlagProvider: RemoteFeatureFlagProvider {

    // MARK: - Properties

    private let remoteConfig: RemoteConfig
    private let logger: LoggingService
    private let cacheDuration: TimeInterval = 12 * 60 * 60 // 12 hours

    // MARK: - Initialization

    init(
        remoteConfig: RemoteConfig = RemoteConfig.remoteConfig(),
        logger: LoggingService
    ) {
        self.remoteConfig = remoteConfig
        self.logger = logger

        // Configure Remote Config settings
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = cacheDuration
        self.remoteConfig.configSettings = settings

        // Set default values (all features enabled)
        setDefaultValues()
    }

    // MARK: - FeatureFlagProvider

    func value(for feature: Feature) -> Bool? {
        let key = feature.rawValue
        let configValue = remoteConfig.configValue(forKey: key)

        // Return nil if never fetched (allows local/default fallback)
        guard configValue.source != .static else {
            return nil
        }

        return configValue.boolValue
    }

    // MARK: - RemoteFeatureFlagProvider

    func fetch() async {
        do {
            let status = try await remoteConfig.fetch(withExpirationDuration: cacheDuration)

            logger.log(
                "Remote Config fetch completed with status: \(status.rawValue)",
                category: .general,
                level: .info,
                metadata: nil
            )

            // Activate fetched values
            await activateFetched()

        } catch {
            logger.error(
                "Failed to fetch Remote Config",
                category: .general,
                error: error,
                metadata: nil
            )
        }
    }

    func activateFetched() async {
        do {
            let activated = try await remoteConfig.activate()

            logger.log(
                "Remote Config activated: \(activated)",
                category: .general,
                level: .info,
                metadata: nil
            )

        } catch {
            logger.error(
                "Failed to activate Remote Config",
                category: .general,
                error: error,
                metadata: nil
            )
        }
    }

    // MARK: - Default Values

    /// Set default values for all features (all enabled by default)
    private func setDefaultValues() {
        var defaults: [String: NSObject] = [:]

        for feature in Feature.allCases {
            defaults[feature.rawValue] = NSNumber(value: true)
        }

        remoteConfig.setDefaults(defaults)

        logger.log(
            "Set default values for \(defaults.count) features",
            category: .general,
            level: .debug,
            metadata: nil
        )
    }
}
