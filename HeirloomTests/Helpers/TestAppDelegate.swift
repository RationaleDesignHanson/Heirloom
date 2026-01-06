//
//  TestAppDelegate.swift
//  HeirloomTests
//
//  Test-specific app delegate that prevents Firebase initialization during tests
//

import UIKit
@testable import Heirloom

/// Test app delegate that skips all production initialization
/// This prevents Firebase crashes during test execution
@objc(TestAppDelegate)
class TestAppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("🧪 [TestAppDelegate] Test environment detected - skipping production initialization")

        // Initialize ServiceContainer with test services
        // This happens BEFORE any tests run, setting up the container for .shared accessors
        ServiceContainer.shared.registerTestServices()

        print("✅ [TestAppDelegate] Test services registered successfully")

        return true
    }
}
