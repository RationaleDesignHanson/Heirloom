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
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to iCloud in Settings"
        case .networkUnavailable:
            return "No internet connection. Changes will sync when online."
        case .quotaExceeded:
            return "iCloud storage is full. Please free up space."
        case .recordNotFound:
            return "The requested data was not found."
        case .conflictDetected:
            return "Data conflict detected. Retrying..."
        case .unknownError(let error):
            return "CloudKit error: \(error.localizedDescription)"
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
        default:
            return .unknownError(error)
        }
    }
}

