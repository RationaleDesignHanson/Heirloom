//
//  CloudKitError.swift
//  Heirloom
//
//  CloudKit-specific errors for better error handling
//

import Foundation
import CloudKit

/// Comprehensive error type for CloudKit sync operations
enum CloudKitSyncError: LocalizedError {
    case notAuthenticated
    case networkUnavailable
    case quotaExceeded
    case recordNotFound
    case conflictDetected
    case permissionDenied
    case serviceUnavailable
    case rateLimited
    case badRequest
    case internalError
    case zoneBusy
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to iCloud in Settings to continue"
        case .networkUnavailable:
            return "No internet connection. Changes will sync when you're back online."
        case .quotaExceeded:
            return "iCloud storage is full. Please free up space in Settings > iCloud."
        case .recordNotFound:
            return "The requested recipe was not found. It may have been deleted."
        case .conflictDetected:
            return "Data conflict detected. Your changes will be merged automatically."
        case .permissionDenied:
            return "You don't have permission to access this shared recipe."
        case .serviceUnavailable:
            return "iCloud services are temporarily unavailable. Please try again later."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .badRequest:
            return "Invalid request. Please try refreshing the app."
        case .internalError:
            return "An internal error occurred. Please try again."
        case .zoneBusy:
            return "iCloud is busy processing your data. Please try again in a moment."
        case .unknownError(let error):
            return "CloudKit error: \(error.localizedDescription)"
        }
    }

    /// User-facing message with suggested action
    var userMessage: String {
        switch self {
        case .notAuthenticated:
            return "Sign in to iCloud to share recipes.\n\nGo to Settings > [Your Name] > iCloud"
        case .networkUnavailable:
            return "Check your internet connection and try again."
        case .quotaExceeded:
            return "Free up iCloud storage space to continue.\n\nGo to Settings > [Your Name] > iCloud > Manage Storage"
        case .recordNotFound:
            return "This recipe may have been deleted by the owner."
        case .conflictDetected:
            return "Resolving data conflict automatically..."
        case .permissionDenied:
            return "Contact the recipe owner to request access."
        case .serviceUnavailable:
            return "iCloud is temporarily unavailable. Try again in a few minutes."
        case .rateLimited:
            return "Please wait 30 seconds and try again."
        case .badRequest:
            return "Try closing and reopening the app."
        case .internalError, .zoneBusy:
            return "Please try again in a few moments."
        case .unknownError:
            return "An unexpected error occurred. Please try again."
        }
    }

    /// Whether this error is retryable (transient)
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .serviceUnavailable, .rateLimited, .zoneBusy, .conflictDetected, .internalError:
            return true
        case .notAuthenticated, .permissionDenied, .quotaExceeded, .badRequest, .recordNotFound:
            return false
        case .unknownError:
            return false // Conservative default
        }
    }

    /// Suggested retry delay in seconds (for retryable errors)
    var retryDelay: TimeInterval {
        switch self {
        case .rateLimited:
            return 30.0 // Rate limit requires longer wait
        case .zoneBusy:
            return 10.0
        case .serviceUnavailable:
            return 15.0
        case .conflictDetected:
            return 1.0 // Quick retry for conflicts
        case .networkUnavailable, .internalError:
            return 5.0
        default:
            return 3.0
        }
    }

    /// Error severity for logging/UI
    var severity: ErrorSeverity {
        switch self {
        case .notAuthenticated, .permissionDenied, .quotaExceeded:
            return .critical // User must take action
        case .networkUnavailable, .serviceUnavailable, .rateLimited:
            return .warning // Transient, will resolve
        case .conflictDetected, .zoneBusy:
            return .info // Handled automatically
        case .recordNotFound, .badRequest, .internalError, .unknownError:
            return .error // Something went wrong
        }
    }

    /// Convert CKError to our custom error type
    static func from(_ error: Error) -> CloudKitSyncError {
        guard let ckError = error as? CKError else {
            return .unknownError(error)
        }

        switch ckError.code {
        case .notAuthenticated:
            return .notAuthenticated
        case .networkUnavailable, .networkFailure:
            return .networkUnavailable
        case .quotaExceeded:
            return .quotaExceeded
        case .unknownItem:
            return .recordNotFound
        case .serverRecordChanged:
            return .conflictDetected
        case .permissionFailure:
            return .permissionDenied
        case .serviceUnavailable:
            return .serviceUnavailable
        case .requestRateLimited:
            return .rateLimited
        case .badContainer, .badDatabase, .incompatibleVersion, .constraintViolation:
            return .badRequest
        case .internalError:
            return .internalError
        case .zoneBusy:
            return .zoneBusy
        default:
            return .unknownError(error)
        }
    }
}

/// Error severity levels for logging and UI presentation
enum ErrorSeverity {
    case info       // Informational, handled automatically
    case warning    // User should be aware, but not blocking
    case error      // Something failed, user action may help
    case critical   // User must take action to proceed

    var icon: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        case .critical:
            return "exclamationmark.octagon.fill"
        }
    }

    var color: String {
        switch self {
        case .info:
            return "blue"
        case .warning:
            return "orange"
        case .error:
            return "red"
        case .critical:
            return "red"
        }
    }
}

// MARK: - Retry Utility

/// Utility for retrying operations with automatic backoff
struct CloudKitRetryHelper {
    /// Execute an operation with automatic retry for transient errors
    /// - Parameters:
    ///   - maxAttempts: Maximum number of attempts (default: 3)
    ///   - operation: The async operation to retry
    /// - Returns: Result of the operation
    /// - Throws: The last error if all attempts fail
    static func withRetry<T>(
        maxAttempts: Int = 3,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var attempt = 0

        while attempt < maxAttempts {
            do {
                let result = try await operation()

                // Success! Log if this wasn't the first attempt
                if attempt > 0 {
                    print("✅ Operation succeeded on attempt \(attempt + 1)/\(maxAttempts)")
                }

                return result
            } catch {
                lastError = error
                attempt += 1

                // Convert to CloudKitSyncError to check if retryable
                let ckError = CloudKitSyncError.from(error)

                // If not retryable or last attempt, throw immediately
                guard ckError.isRetryable && attempt < maxAttempts else {
                    print("❌ Operation failed (non-retryable or final attempt): \(ckError.errorDescription ?? "unknown error")")
                    throw error
                }

                // Log retry attempt
                let delay = ckError.retryDelay
                print("⚠️ Attempt \(attempt)/\(maxAttempts) failed: \(ckError.errorDescription ?? "unknown error")")
                print("⏳ Retrying in \(delay)s... (\(ckError.severity) error)")

                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        // All attempts exhausted, throw last error
        throw lastError ?? CloudKitSyncError.unknownError(NSError(domain: "CloudKit", code: -1))
    }

    /// Execute an operation with automatic retry, returning nil on failure instead of throwing
    /// Useful for optional operations where failure is acceptable
    static func withRetryOptional<T>(
        maxAttempts: Int = 3,
        operation: () async throws -> T
    ) async -> T? {
        do {
            return try await withRetry(maxAttempts: maxAttempts, operation: operation)
        } catch {
            let ckError = CloudKitSyncError.from(error)
            print("⚠️ Optional operation failed after \(maxAttempts) attempts: \(ckError.userMessage)")
            return nil
        }
    }
}


