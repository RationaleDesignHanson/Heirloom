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
        Log.info("🕐 TaskTimeout.withTimeout CALLED with \(seconds)s timeout", category: .network, metadata: nil)

        return try await withThrowingTaskGroup(of: TaskTimeoutResult<T>.self) { group in
            Log.debug("🕐 Creating task group", category: .network, metadata: nil)

            // Start the actual operation
            group.addTask {
                Log.debug("🕐 Operation task STARTED", category: .network, metadata: nil)
                do {
                    let result = try await operation()
                    Log.debug("🕐 Operation task COMPLETED successfully", category: .network, metadata: nil)
                    return .success(result)
                } catch {
                    Log.error("🕐 Operation task FAILED with error: \(error.localizedDescription)", category: .network, metadata: nil)
                    return .failure(error)
                }
            }

            // Start the timeout task
            group.addTask {
                Log.debug("🕐 Timeout task STARTED (will wait \(seconds)s)", category: .network, metadata: nil)
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                Log.warning("⏰ TIMEOUT REACHED after \(seconds)s - throwing timeout error", category: .network, metadata: nil)
                return .timeout
            }

            // Wait for first result
            Log.debug("🕐 Waiting for first task to complete...", category: .network, metadata: nil)
            guard let firstResult = try await group.next() else {
                Log.error("🕐 Task group returned nil - should never happen", category: .network, metadata: nil)
                throw TaskTimeoutError.timedOut
            }

            Log.debug("🕐 First task completed, result type: \(String(describing: firstResult))", category: .network, metadata: nil)

            // Cancel remaining tasks
            group.cancelAll()
            Log.debug("🕐 Cancelled remaining tasks", category: .network, metadata: nil)

            // Handle result
            switch firstResult {
            case .success(let value):
                Log.info("✅ TaskTimeout.withTimeout completed successfully", category: .network, metadata: nil)
                return value
            case .failure(let error):
                Log.error("❌ TaskTimeout.withTimeout failed with error: \(error.localizedDescription)", category: .network, metadata: nil)
                throw error
            case .timeout:
                Log.error("⏰ TaskTimeout.withTimeout TIMED OUT after \(seconds)s", category: .network, metadata: nil)
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
