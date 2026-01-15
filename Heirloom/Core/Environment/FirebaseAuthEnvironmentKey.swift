//
//  FirebaseAuthEnvironmentKey.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-14.
//

import SwiftUI
import Foundation

/// Environment key for Firebase authentication service
struct FirebaseAuthEnvironmentKey: EnvironmentKey {
    static let defaultValue: FirebaseAuthService = ServiceContainer.shared.resolve(FirebaseAuthService.self)
}

extension EnvironmentValues {
    var firebaseAuth: FirebaseAuthService {
        get { self[FirebaseAuthEnvironmentKey.self] }
        set { self[FirebaseAuthEnvironmentKey.self] = newValue }
    }
}
