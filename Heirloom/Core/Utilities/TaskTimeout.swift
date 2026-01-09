//
//  TaskTimeout.swift
//  Heirloom
//
//  Created during Firebase Migration - timeout handling for network operations
//

import Foundation
import os.log

/// Timeout error for async operations
enum TaskTimeoutError: Error {
    case timedOut

    var localizedDescription: String {
        switch self {
        case .timedOut:
            return "The operation took too long to complete. Please check your internet connection and try again."
        }
    }
}

/// Internal result type for task timeout operations
private enum TaskTimeoutResult<T> {
    case success(T)
    case failure(Error)
    case timeout
}

/// Utility for adding timeout to async operations
actor TaskTimeout {
    /// Execute an async operation with a timeout
    /// - Parameters:
    ///   - seconds: Timeout in seconds
    ///   - operation: The async operation to execute
    /// - Returns: Result of the operation
    /// - Throws: TaskTimeoutError.timedOut if the operation exceeds the timeout, or the operation's error
    static func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        // Note: Verbose logging removed to avoid Swift 6 concurrency warnings
        // Log calls require MainActor isolation

        return try await withThrowingTaskGroup(of: TaskTimeoutResult<T>.self) { group in
            // Start the actual operation
            group.addTask {
                do {
                    let result = try await operation()
                    return .success(result)
                } catch {
                    return .failure(error)
                }
            }

            // Start the timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return .timeout
            }

            // Wait for first result
            guard let firstResult = try await group.next() else {
                throw TaskTimeoutError.timedOut
            }

            // Cancel remaining tasks
            group.cancelAll()

            // Handle result
            switch firstResult {
            case .success(let value):
                return value
            case .failure(let error):
                throw error
            case .timeout:
                throw TaskTimeoutError.timedOut
            }
        }
    }

    /// Execute an async operation with a timeout, returning nil on timeout instead of throwing
    /// - Parameters:
    ///   - seconds: Timeout in seconds
    ///   - operation: The async operation to execute
    /// - Returns: Result of the operation, or nil if timed out
    static func withTimeoutOptional<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async -> T? {
        do {
            return try await withTimeout(seconds: seconds, operation: operation)
        } catch is TaskTimeoutError {
            return nil
        } catch {
            return nil
        }
    }
}

// MARK: - Convenience Extensions

extension TaskTimeout {
    /// Standard timeout for Firebase operations (30 seconds)
    static let firebaseStandard: TimeInterval = 30.0

    /// Long timeout for image uploads (60 seconds)
    static let firebaseLong: TimeInterval = 60.0

    /// Short timeout for quick operations (10 seconds)
    static let firebaseShort: TimeInterval = 10.0
}
