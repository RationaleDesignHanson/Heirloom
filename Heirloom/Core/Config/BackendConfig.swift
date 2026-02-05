//
//  BackendConfig.swift
//  Heirloom
//
//  Firebase-only backend configuration
//

import Foundation

/// Global backend configuration
/// Firebase is the only backend for data synchronization
class BackendConfig {
    init() {
        Log.info("BackendConfig initialized", category: .firebase, metadata: ["backend": "Firebase"])
    }

    // MARK: - Backend Checks

    /// Firebase is always active in production
    /// Can be overridden in tests via MockBackendConfig
    private(set) var isFirebaseActive: Bool = true

    /// For testing only - allows overriding isFirebaseActive
    #if DEBUG
    func setFirebaseActive(_ active: Bool) {
        isFirebaseActive = active
    }
    #endif
}
