//
//  AsyncTestHelpers.swift
//  HeirloomTestsV2
//
//  Created: 2026-01-06
//

import Foundation
import XCTest

/// Helpers for testing async code
enum AsyncTestHelpers {

    // MARK: - Async Expectations

    /// Wait for an async condition to become true
    /// - Parameters:
    ///   - timeout: Maximum time to wait (default: 5 seconds)
    ///   - pollInterval: How often to check the condition (default: 0.1 seconds)
    ///   - condition: Closure that returns true when condition is met
    static func waitFor(
        timeout: TimeInterval = 5.0,
        pollInterval: TimeInterval = 0.1,
        condition: @escaping () async -> Bool
    ) async throws {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            if await condition() {
                return
            }
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }

        throw AsyncTestError.timeout
    }

    /// Wait for a value to be produced by an async operation
    /// - Parameters:
    ///   - timeout: Maximum time to wait (default: 5 seconds)
    ///   - operation: Async operation that produces a value
    /// - Returns: The value produced by the operation
    static func waitForValue<T>(
        timeout: TimeInterval = 5.0,
        operation: @escaping () async throws -> T?
    ) async throws -> T {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            if let value = try await operation() {
                return value
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }

        throw AsyncTestError.timeout
    }

    // MARK: - Task Testing

    /// Run multiple async operations concurrently and collect results
    /// - Parameter operations: Array of async operations
    /// - Returns: Array of results in original order
    static func runConcurrently<T>(
        _ operations: [() async throws -> T]
    ) async throws -> [T] {
        try await withThrowingTaskGroup(of: (Int, T).self) { group in
            for (index, operation) in operations.enumerated() {
                group.addTask {
                    let result = try await operation()
                    return (index, result)
                }
            }

            var results: [(Int, T)] = []
            for try await result in group {
                results.append(result)
            }

            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    /// Measure execution time of async operation
    /// - Parameter operation: Async operation to measure
    /// - Returns: Tuple of (result, duration in seconds)
    static func measure<T>(
        _ operation: @escaping () async throws -> T
    ) async throws -> (result: T, duration: TimeInterval) {
        let startTime = Date()
        let result = try await operation()
        let duration = Date().timeIntervalSince(startTime)
        return (result, duration)
    }

    // MARK: - Timeout Testing

    /// Assert that an async operation completes within a time limit
    /// - Parameters:
    ///   - timeout: Maximum allowed time
    ///   - operation: Async operation to execute
    static func assertCompletes<T>(
        within timeout: TimeInterval,
        _ operation: @escaping () async throws -> T
    ) async throws -> T {
        let task = Task {
            try await operation()
        }

        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            task.cancel()
        }

        do {
            let result = try await task.value
            timeoutTask.cancel()
            return result
        } catch is CancellationError {
            throw AsyncTestError.timeout
        }
    }

    /// Assert that an async operation does NOT complete within a time limit
    /// - Parameters:
    ///   - timeout: Time to wait before considering test successful
    ///   - operation: Async operation that should not complete
    static func assertDoesNotComplete(
        for duration: TimeInterval,
        _ operation: @escaping () async throws -> Void
    ) async throws {
        let task = Task {
            try await operation()
        }

        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

        if !task.isCancelled {
            task.cancel()
            throw AsyncTestError.unexpectedCompletion
        }
    }
}

// MARK: - AsyncTestError

enum AsyncTestError: Error, LocalizedError {
    case timeout
    case unexpectedCompletion
    case conditionNotMet

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Async operation timed out"
        case .unexpectedCompletion:
            return "Async operation completed when it shouldn't have"
        case .conditionNotMet:
            return "Async condition was not met"
        }
    }
}

// MARK: - XCTest Extensions for Async

extension XCTestCase {
    /// Assert that an async expression throws a specific error
    func XCTAssertThrowsErrorAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (_ error: Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error to be thrown", file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }

    /// Assert that an async expression does not throw
    func XCTAssertNoThrowAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> T? {
        do {
            return try await expression()
        } catch {
            XCTFail("Unexpected error thrown: \(error)", file: file, line: line)
            return nil
        }
    }

    /// Assert that an async operation eventually becomes true
    func XCTAssertEventually(
        timeout: TimeInterval = 5.0,
        _ condition: @escaping () async -> Bool,
        _ message: @autoclosure () -> String = "Condition was not met",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await AsyncTestHelpers.waitFor(timeout: timeout, condition: condition)
        } catch {
            XCTFail(message(), file: file, line: line)
        }
    }
}
