import Foundation
import SwiftData

/// Represents a bulk import job containing multiple URLs to process
/// Persisted to track progress across app sessions
@Model
final class ImportJob {
    // MARK: - Identity
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var completedAt: Date?

    // MARK: - Status
    var status: ImportJobStatus = ImportJobStatus.pending
    var totalItems: Int = 0
    var completedItems: Int = 0
    var successfulItems: Int = 0
    var failedItems: Int = 0

    // MARK: - Configuration
    /// User-provided name for this import (optional)
    var jobName: String?

    /// Whether to continue processing if failures occur
    var continueOnError: Bool = true

    // MARK: - Relationships
    @Relationship(deleteRule: .cascade, inverse: \ImportItem.job)
    var items: [ImportItem]?

    // MARK: - Computed Properties
    var progress: Double {
        guard totalItems > 0 else { return 0 }
        return Double(completedItems) / Double(totalItems)
    }

    var isComplete: Bool {
        status == .completed || status == .failed
    }

    var canRetry: Bool {
        status == .failed || status == .paused
    }

    // MARK: - Initialization
    init(jobName: String? = nil, continueOnError: Bool = true) {
        self.jobName = jobName
        self.continueOnError = continueOnError
    }
}

// MARK: - ImportJobStatus

enum ImportJobStatus: String, Codable {
    case pending      // Not yet started
    case processing   // Currently importing items
    case paused       // Paused by user
    case completed    // All items processed
    case failed       // Job failed critically
}

// MARK: - Convenience Extensions

extension ImportJob {
    /// Updates progress counters when an item completes
    func updateProgress(success: Bool) {
        completedItems += 1
        if success {
            successfulItems += 1
        } else {
            failedItems += 1
        }
    }

    /// Checks if job should continue processing based on status
    var shouldContinueProcessing: Bool {
        switch status {
        case .processing:
            return true
        case .pending, .paused, .completed, .failed:
            return false
        }
    }
}
