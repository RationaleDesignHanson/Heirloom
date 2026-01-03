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
    static let shared = BackendConfig()

    private init() {
        print("🔧 [BackendConfig] Active backend: Firebase")
    }

    // MARK: - Backend Checks

    /// Firebase is always active
    var isFirebaseActive: Bool {
        return true
    }
}
