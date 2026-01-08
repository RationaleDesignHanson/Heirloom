//
//  MockTracking.swift
//  HeirloomTestsV2
//
//  Created: 2026-01-06
//

import Foundation

/// Base protocol for all mock implementations
/// Provides call tracking and verification capabilities
protocol MockTracking {
    /// Log of all method calls made to this mock
    var callLog: [String] { get set }

    /// Record a method call for verification in tests
    /// - Parameter functionName: Name of the function that was called
    func recordCall(_ functionName: String)

    /// Clear all recorded calls (useful in setUp/tearDown)
    mutating func resetCallLog()

    /// Check if a specific function was called
    /// - Parameter functionName: Name of the function to check
    /// - Returns: True if the function was called at least once
    func wasCalled(_ functionName: String) -> Bool

    /// Get the number of times a function was called
    /// - Parameter functionName: Name of the function to count
    /// - Returns: Number of times the function was called
    func callCount(for functionName: String) -> Int
}

// MARK: - Default Implementations

extension MockTracking {
    func recordCall(_ functionName: String) {
        var mutableSelf = self
        mutableSelf.callLog.append(functionName)
    }

    mutating func resetCallLog() {
        callLog.removeAll()
    }

    func wasCalled(_ functionName: String) -> Bool {
        callLog.contains(functionName)
    }

    func callCount(for functionName: String) -> Int {
        callLog.filter { $0 == functionName }.count
    }
}

/// Error injection capability for mocks
protocol MockErrorInjection {
    /// Set to true to make the next operation fail
    var shouldFail: Bool { get set }

    /// Error to throw when shouldFail is true
    var injectedError: Error? { get set }
}

/// State simulation capability for mocks
protocol MockStateSimulation {
    /// Reset mock to initial state
    mutating func reset()
}
