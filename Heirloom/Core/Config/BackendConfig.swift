//
//  BackendConfig.swift
//  Heirloom
//
//  Created during Firebase Migration - Phase 1
//  Manages backend switching between CloudKit and Firebase
//

import Foundation

/// Backend types available for data sync
enum BackendType: String {
    case cloudKit = "CloudKit"
    case firebase = "Firebase"
    case dualWrite = "DualWrite" // Write to both, read from CloudKit
}

/// Global backend configuration
/// Controls which backend is used for data synchronization
class BackendConfig {
    static let shared = BackendConfig()

    // MARK: - Configuration

    /// Current active backend
    /// During migration: CloudKit -> DualWrite -> Firebase
    private(set) var activeBackend: BackendType

    /// Feature flag key for persistence
    private let backendKey = "heirloom.backend.type"

    // MARK: - Initialization

    private init() {
        // Load from UserDefaults, default to CloudKit
        if let savedBackend = UserDefaults.standard.string(forKey: backendKey),
           let backend = BackendType(rawValue: savedBackend) {
            self.activeBackend = backend
        } else {
            // Default: CloudKit (current production backend)
            self.activeBackend = .cloudKit
        }

        print("🔧 [BackendConfig] Active backend: \(activeBackend.rawValue)")
    }

    // MARK: - Backend Switching

    /// Switch to a different backend
    /// - Parameter backend: The new backend to use
    func setBackend(_ backend: BackendType) {
        activeBackend = backend
        UserDefaults.standard.set(backend.rawValue, forKey: backendKey)
        print("✅ [BackendConfig] Switched to backend: \(backend.rawValue)")
    }

    // MARK: - Backend Checks

    var isCloudKitActive: Bool {
        activeBackend == .cloudKit || activeBackend == .dualWrite
    }

    var isFirebaseActive: Bool {
        activeBackend == .firebase || activeBackend == .dualWrite
    }

    var isDualWriteMode: Bool {
        activeBackend == .dualWrite
    }
}
