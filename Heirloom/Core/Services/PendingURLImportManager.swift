//
//  PendingURLImportManager.swift
//  Heirloom
//
//  Manages pending single-recipe URL imports that were interrupted
//  Persists import URL to UserDefaults for retry on app launch
//

import Foundation

/// Manages pending URL imports for single recipe imports
/// When an import is started, the URL is persisted to UserDefaults
/// If the app is terminated, the pending import can be resumed on next launch
@MainActor
class PendingURLImportManager {

    // MARK: - Singleton

    static let shared = PendingURLImportManager()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let pendingImportURL = "pendingRecipeImportURL"
        static let pendingImportTimestamp = "pendingRecipeImportTimestamp"
    }

    // MARK: - Configuration

    /// Maximum age for a pending import (24 hours)
    private let maxPendingAge: TimeInterval = 24 * 60 * 60

    // MARK: - Public API

    /// Record that an import has started
    /// Call this before beginning the import operation
    func recordImportStarted(url: String) {
        UserDefaults.standard.set(url, forKey: Keys.pendingImportURL)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.pendingImportTimestamp)

        Log.info("Recorded pending URL import", category: .general, metadata: ["url": url])
    }

    /// Record that an import completed (success or failure handled)
    /// Call this after the import operation finishes
    func recordImportCompleted() {
        UserDefaults.standard.removeObject(forKey: Keys.pendingImportURL)
        UserDefaults.standard.removeObject(forKey: Keys.pendingImportTimestamp)

        Log.info("Cleared pending URL import", category: .general)
    }

    /// Check if there's a pending import that was interrupted
    /// Returns the URL if there's a valid pending import, nil otherwise
    func checkForPendingImport() -> String? {
        guard let url = UserDefaults.standard.string(forKey: Keys.pendingImportURL) else {
            return nil
        }

        // Check if pending import is still valid (not too old)
        let timestamp = UserDefaults.standard.double(forKey: Keys.pendingImportTimestamp)
        let importDate = Date(timeIntervalSince1970: timestamp)
        let age = Date().timeIntervalSince(importDate)

        if age > maxPendingAge {
            // Pending import is too old, clear it
            Log.info("Pending URL import expired", category: .general, metadata: [
                "url": url,
                "ageHours": Int(age / 3600)
            ])
            recordImportCompleted()
            return nil
        }

        Log.info("Found pending URL import", category: .general, metadata: [
            "url": url,
            "ageMinutes": Int(age / 60)
        ])

        return url
    }

    /// Dismiss a pending import without retrying
    func dismissPendingImport() {
        if let url = UserDefaults.standard.string(forKey: Keys.pendingImportURL) {
            Log.info("Dismissed pending URL import", category: .general, metadata: ["url": url])
        }
        recordImportCompleted()
    }
}
