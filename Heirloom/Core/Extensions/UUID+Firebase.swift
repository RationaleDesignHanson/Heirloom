//
//  UUID+Firebase.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-19.
//  Provides consistent lowercase UUID strings for Firebase storage
//

import Foundation

extension UUID {
    /// Returns the UUID string in lowercase format for Firebase storage.
    /// This ensures consistent UUID comparison across Swift (which generates uppercase)
    /// and external systems (which may use lowercase).
    ///
    /// Example:
    /// ```
    /// let id = UUID()
    /// id.uuidString           // "A1B2C3D4-E5F6-..."  (uppercase)
    /// id.firebaseString       // "a1b2c3d4-e5f6-..."  (lowercase)
    /// ```
    var firebaseString: String {
        uuidString.lowercased()
    }
}
