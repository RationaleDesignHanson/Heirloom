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

    // MARK: - Phase Tracking (NEW: for unified progress UX)
    /// Current phase of the import process
    var phase: ImportPhase = ImportPhase.validation

    /// Progress within the current phase (0.0 to 1.0)
    var phaseProgress: Double = 0.0

    // MARK: - Configuration
    /// User-provided name for this import (optional)
    var jobName: String?

    /// Whether to continue processing if failures occur
    var continueOnError: Bool = true

    /// Cookbook name for auto-categorization (optional)
    var cookbookName: String?

    // MARK: - Relationships
    @Relationship(deleteRule: .cascade, inverse: \ImportItem.job)
    var items: [ImportItem]?

    // MARK: - Computed Properties
    var progress: Double {
        guard totalItems > 0 else { return 0 }
        return Double(completedItems) / Double(totalItems)
    }

    /// Overall progress across all phases (0.0 to 1.0)
    /// Takes into account validation, analysis, and extraction phases
    var overallProgress: Double {
        let phaseWeights: [ImportPhase: Double] = [
            .validation: 0.1,   // 10% of total time
            .analysis: 0.3,     // 30% of total time
            .extraction: 0.6,   // 60% of total time
            .completed: 1.0     // 100% complete
        ]

        // Calculate weight of completed phases
        let completedPhases = ImportPhase.allCases.filter { $0.sortOrder < phase.sortOrder }
        let completedWeight = completedPhases.reduce(0.0) { sum, phase in
            sum + (phaseWeights[phase] ?? 0.0)
        }

        // Add progress within current phase
        let currentPhaseWeight = phaseWeights[phase] ?? 0.0
        let currentPhaseContribution = currentPhaseWeight * phaseProgress

        return min(completedWeight + currentPhaseContribution, 1.0)
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

// MARK: - ImportPhase

/// Phases of the import process for unified progress tracking
enum ImportPhase: String, Codable, CaseIterable {
    case validation   // Validating PDF files
    case analysis     // Detecting page boundaries and extracting images
    case extraction   // Extracting recipe details via AI
    case completed    // All done

    /// Sort order for phase comparison
    var sortOrder: Int {
        switch self {
        case .validation: return 0
        case .analysis: return 1
        case .extraction: return 2
        case .completed: return 3
        }
    }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .validation: return "Validating PDFs..."
        case .analysis: return "Analyzing pages..."
        case .extraction: return "Extracting recipes..."
        case .completed: return "Import complete"
        }
    }

    /// Icon name for UI
    var iconName: String {
        switch self {
        case .validation: return "doc.text.magnifyingglass"
        case .analysis: return "doc.text.image"
        case .extraction: return "text.badge.checkmark"
        case .completed: return "checkmark.circle.fill"
        }
    }
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

        // Update phase progress based on completion ratio
        if totalItems > 0 {
            phaseProgress = Double(completedItems) / Double(totalItems)
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
