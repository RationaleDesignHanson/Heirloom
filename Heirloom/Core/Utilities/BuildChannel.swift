//
//  BuildChannel.swift
//  Heirloom
//
//  Detects the build channel for analytics and debugging.
//  Note: Not used for gating - demo mode defaults ON in all builds.
//

import Foundation

/// Represents the distribution channel for the current build
enum BuildChannel: String, Sendable {
    case debug = "debug"
    case testFlight = "testflight"
    case appStore = "appstore"

    /// The current build channel based on receipt URL
    static var current: BuildChannel {
        #if DEBUG
        return .debug
        #else
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            return .appStore
        }
        return receiptURL.lastPathComponent == "sandboxReceipt" ? .testFlight : .appStore
        #endif
    }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .debug:
            return "Debug"
        case .testFlight:
            return "TestFlight"
        case .appStore:
            return "App Store"
        }
    }

    /// Whether this is a development/testing build
    var isTestBuild: Bool {
        self == .debug || self == .testFlight
    }
}
