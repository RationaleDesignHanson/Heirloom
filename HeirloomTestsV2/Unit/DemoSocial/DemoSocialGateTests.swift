//
//  DemoSocialGateTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-05
//  Unit tests for DemoSocialGate gating logic
//
//  Tests the demo social gating system to ensure:
//  - Gate defaults to enabled
//  - Local toggle can disable gate
//  - Remote config can disable gate
//  - Expiration dates are respected
//  - Debug status messages are accurate
//

import XCTest
@testable import Heirloom

@MainActor
final class DemoSocialGateTests: XCTestCase {

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        // Clear demo social UserDefaults key
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.demoSocialModeDisabled)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.demoSocialModeDisabled)
        try await super.tearDown()
    }

    // MARK: - Default State Tests

    /// Test 1: Gate defaults to enabled when no settings have been changed
    func test_gate_defaultsToEnabled() {
        let mockConfig = MockDemoSocialConfig(isRemoteEnabled: true, isExpired: false)
        let gate = DemoSocialGate(config: mockConfig, userDefaults: .standard)

        XCTAssertTrue(gate.isEnabled, "Gate should default to enabled")
    }

    /// Test 2: Gate is enabled when all conditions are met
    func test_gate_enabledWhenAllConditionsMet() {
        let mockConfig = MockDemoSocialConfig(isRemoteEnabled: true, isExpired: false)
        UserDefaults.standard.set(false, forKey: UserDefaultsKeys.demoSocialModeDisabled)

        let gate = DemoSocialGate(config: mockConfig, userDefaults: .standard)

        XCTAssertTrue(gate.isEnabled)
        XCTAssertEqual(gate.debugStatus, "enabled")
    }

    // MARK: - Local Toggle Tests

    /// Test 3: Gate disabled when local toggle is off
    func test_gate_disabledWhenLocalToggleOff() {
        let mockConfig = MockDemoSocialConfig(isRemoteEnabled: true, isExpired: false)
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.demoSocialModeDisabled)

        let gate = DemoSocialGate(config: mockConfig, userDefaults: .standard)

        XCTAssertFalse(gate.isEnabled)
        XCTAssertEqual(gate.debugStatus, "disabled: local toggle off")
    }

    /// Test 4: Local toggle can be changed programmatically
    func test_gate_localToggleCanBeChanged() {
        let mockConfig = MockDemoSocialConfig(isRemoteEnabled: true, isExpired: false)
        let gate = DemoSocialGate(config: mockConfig, userDefaults: .standard)

        XCTAssertTrue(gate.isEnabled, "Should start enabled")

        gate.setLocallyDisabled(true)

        XCTAssertFalse(gate.isEnabled, "Should be disabled after toggle")
        XCTAssertTrue(gate.isLocallyDisabled)
    }

    /// Test 5: Re-enabling local toggle re-enables gate
    func test_gate_reEnablingLocalToggleReEnablesGate() {
        let mockConfig = MockDemoSocialConfig(isRemoteEnabled: true, isExpired: false)
        let gate = DemoSocialGate(config: mockConfig, userDefaults: .standard)

        gate.setLocallyDisabled(true)
        XCTAssertFalse(gate.isEnabled)

        gate.setLocallyDisabled(false)
        XCTAssertTrue(gate.isEnabled)
    }

    // MARK: - Remote Config Tests

    /// Test 6: Gate disabled when remote config is off
    func test_gate_disabledWhenRemoteConfigOff() {
        let mockConfig = MockDemoSocialConfig(isRemoteEnabled: false, isExpired: false)

        let gate = DemoSocialGate(config: mockConfig, userDefaults: .standard)

        XCTAssertFalse(gate.isEnabled)
        XCTAssertEqual(gate.debugStatus, "disabled: remote config off")
    }

    /// Test 7: Remote availability flag reflects config state
    func test_gate_remoteAvailabilityReflectsConfig() {
        let enabledConfig = MockDemoSocialConfig(isRemoteEnabled: true, isExpired: false)
        let disabledConfig = MockDemoSocialConfig(isRemoteEnabled: false, isExpired: false)

        let enabledGate = DemoSocialGate(config: enabledConfig, userDefaults: .standard)
        let disabledGate = DemoSocialGate(config: disabledConfig, userDefaults: .standard)

        XCTAssertTrue(enabledGate.isRemotelyAvailable)
        XCTAssertFalse(disabledGate.isRemotelyAvailable)
    }

    // MARK: - Expiration Tests

    /// Test 8: Gate disabled when feature has expired
    func test_gate_disabledWhenExpired() {
        let mockConfig = MockDemoSocialConfig(isRemoteEnabled: true, isExpired: true)

        let gate = DemoSocialGate(config: mockConfig, userDefaults: .standard)

        XCTAssertFalse(gate.isEnabled)
        XCTAssertTrue(gate.debugStatus.contains("expired"))
    }

    /// Test 9: Expiration takes precedence over local toggle
    func test_gate_expirationTakesPrecedence() {
        let mockConfig = MockDemoSocialConfig(isRemoteEnabled: true, isExpired: true)
        UserDefaults.standard.set(false, forKey: UserDefaultsKeys.demoSocialModeDisabled)

        let gate = DemoSocialGate(config: mockConfig, userDefaults: .standard)

        // Even though local toggle is ON (disabled=false), expiration should disable
        XCTAssertFalse(gate.isEnabled)
    }

    /// Test 10: Remote disabled takes precedence over local toggle
    func test_gate_remoteDisabledTakesPrecedence() {
        let mockConfig = MockDemoSocialConfig(isRemoteEnabled: false, isExpired: false)
        UserDefaults.standard.set(false, forKey: UserDefaultsKeys.demoSocialModeDisabled)

        let gate = DemoSocialGate(config: mockConfig, userDefaults: .standard)

        // Even though local toggle is ON, remote being off should disable
        XCTAssertFalse(gate.isEnabled)
        XCTAssertEqual(gate.debugStatus, "disabled: remote config off")
    }

    // MARK: - Refresh Tests

    /// Test 11: Refresh updates gate state
    func test_gate_refreshUpdatesState() {
        let mockConfig = MockDemoSocialConfig(isRemoteEnabled: true, isExpired: false)
        let gate = DemoSocialGate(config: mockConfig, userDefaults: .standard)

        XCTAssertTrue(gate.isEnabled)

        // Simulate external change to UserDefaults
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.demoSocialModeDisabled)
        gate.refresh()

        XCTAssertFalse(gate.isEnabled)
    }

    // MARK: - Debug Status Tests

    /// Test 12: Debug status shows correct message for enabled state
    func test_debugStatus_showsEnabledCorrectly() {
        let mockConfig = MockDemoSocialConfig(isRemoteEnabled: true, isExpired: false)
        let gate = DemoSocialGate(config: mockConfig, userDefaults: .standard)

        XCTAssertEqual(gate.debugStatus, "enabled")
    }

    /// Test 13: Debug status prioritizes remote config message
    func test_debugStatus_prioritizesRemoteConfig() {
        let mockConfig = MockDemoSocialConfig(isRemoteEnabled: false, isExpired: false)
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.demoSocialModeDisabled)

        let gate = DemoSocialGate(config: mockConfig, userDefaults: .standard)

        // Remote config off should be reported first, even if local is also off
        XCTAssertEqual(gate.debugStatus, "disabled: remote config off")
    }

    /// Test 14: Debug status prioritizes expiration over local toggle
    func test_debugStatus_prioritizesExpiration() {
        let mockConfig = MockDemoSocialConfig(isRemoteEnabled: true, isExpired: true)
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.demoSocialModeDisabled)

        let gate = DemoSocialGate(config: mockConfig, userDefaults: .standard)

        // Expiration should be reported, even if local is also off
        XCTAssertTrue(gate.debugStatus.contains("expired"))
    }
}

// MARK: - Mock DemoSocialConfig

/// Mock config for testing gate logic without Firebase dependency
/// Implements DemoSocialConfigProtocol instead of subclassing final class
@MainActor
final class MockDemoSocialConfig: DemoSocialConfigProtocol {
    let isRemoteEnabled: Bool
    let isExpired: Bool
    let expirationDate: Date?

    init(isRemoteEnabled: Bool, isExpired: Bool, expirationDate: Date? = nil) {
        self.isRemoteEnabled = isRemoteEnabled
        self.isExpired = isExpired
        self.expirationDate = expirationDate
    }
}
