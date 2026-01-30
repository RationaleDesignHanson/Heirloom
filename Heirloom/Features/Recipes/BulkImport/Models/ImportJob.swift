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

    /// Cookbook cover image path (from first PDF page)
    var cookbookCoverImagePath: String?

    /// Collection type for auto-categorization (stored as raw value)
    var collectionTypeRawValue: String?

    // MARK: - Relationships
    @Relationship(deleteRule: .cascade, inverse: \ImportItem.job)
    var items: [ImportItem]?

    /// Checkpoint for resumable imports
    @Relationship(deleteRule: .cascade)
    var checkpoint: PDFImportCheckpoint?

    // MARK: - Resume Detection
    /// Original PDF URL for resume (if applicable)
    var pdfURL: String?

    /// Flag indicating this job was interrupted (not manually paused)
    var wasInterrupted: Bool = false

    /// Timestamp when interruption occurred
    var interruptedAt: Date?

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

    /// Computed property for collection type enum
    var collectionType: CollectionType? {
        get {
            guard let rawValue = collectionTypeRawValue else { return nil }
            return CollectionType(rawValue: rawValue)
        }
        set {
            collectionTypeRawValue = newValue?.rawValue
        }
    }

    /// Whether this job can be resumed from checkpoint
    /// Note: wasInterrupted is set during app launch detection for force-quit scenarios
    var canResume: Bool {
        // Must be marked as interrupted (set during detection or background)
        guard wasInterrupted else { return false }

        // Must be in processing status (interrupted mid-import)
        guard status == .processing else { return false }

        guard let checkpoint = checkpoint else { return false }

        // Check if we've made progress (either analyzed pages or extracted recipes)
        let hasProgress = checkpoint.analyzedPageNumbers.count > 0 ||
                          checkpoint.lastExtractedItemIndex != nil
        guard hasProgress else { return false }

        // Check if not expired (7 days)
        if let interruptedAt = interruptedAt ?? checkpoint.interruptedAt {
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            if interruptedAt <= sevenDaysAgo {
                return false
            }
        }

        return true
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

// MARK: - PDFImportCheckpoint

/// Checkpoint model for tracking PDF import progress at page and recipe level
/// Enables resuming interrupted imports from where they left off
@Model
final class PDFImportCheckpoint {
    // MARK: - Identity

    var id: UUID
    var createdAt: Date
    var lastUpdated: Date

    // MARK: - Page-Level Progress

    /// Last page number that completed analysis
    var lastAnalyzedPageNumber: Int?

    /// All page numbers that have been successfully analyzed
    /// Stored as array for efficient Set conversion during resume
    var analyzedPageNumbers: [Int]

    // MARK: - Recipe Extraction Progress

    /// Last ImportItem index that completed extraction
    /// Index in job.items array
    var lastExtractedItemIndex: Int?

    // MARK: - Multi-Page Recipe State

    /// Serialized RecipePageGroup if interrupted mid-group
    /// Allows resuming multi-page recipe analysis without losing context
    var pendingRecipeGroupJSON: Data?

    // MARK: - Interruption Detection

    /// True if process was killed/interrupted, false if user manually paused
    var wasInterrupted: Bool

    /// Timestamp when interruption occurred
    var interruptedAt: Date?

    /// Which phase was interrupted (analysis, extraction, etc.)
    var interruptedPhase: ImportPhase?

    // MARK: - Relationship

    /// Parent import job
    var job: ImportJob?

    // MARK: - Initialization

    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.analyzedPageNumbers = []
        self.wasInterrupted = false
    }

    // MARK: - Computed Properties

    /// Whether this checkpoint can be resumed
    var canResume: Bool {
        guard wasInterrupted else { return false }

        // Check expiration (7 days)
        if let interruptedAt = interruptedAt {
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            guard interruptedAt > sevenDaysAgo else { return false }
        }

        // Must have made some progress
        return analyzedPageNumbers.count > 0 || lastExtractedItemIndex != nil
    }

    /// Which phase to resume from
    var resumePhase: ImportPhase {
        // If we haven't extracted any recipes yet, resume analysis
        if lastExtractedItemIndex == nil && analyzedPageNumbers.isEmpty {
            return .analysis
        }

        // Otherwise resume extraction
        return .extraction
    }

    /// Estimated progress percentage (0.0 to 1.0)
    var progressEstimate: Double {
        guard let job = job else { return 0.0 }

        // If we've started extracting recipes
        if let lastIndex = lastExtractedItemIndex {
            // Analysis = 40%, Extraction = 60%
            let extractionProgress = Double(lastIndex + 1) / Double(max(job.totalItems, 1))
            return 0.4 + (0.6 * extractionProgress)
        }

        // If we're still analyzing pages
        if !analyzedPageNumbers.isEmpty {
            // Rough estimate: 10% validation + 30% analysis
            // We don't know total pages here, so estimate conservatively
            let analysisProgress = Double(analyzedPageNumbers.count) / Double(max(analyzedPageNumbers.count, 1))
            return 0.1 + (0.3 * analysisProgress)
        }

        return 0.0
    }
}

// MARK: - PDFImportCheckpoint Helper Methods

extension PDFImportCheckpoint {
    /// Get completed pages as a Set for O(1) lookup during resume
    func completedPagesSet() -> Set<Int> {
        return Set(analyzedPageNumbers)
    }

    /// Add a completed page to the checkpoint
    func addCompletedPage(_ pageNumber: Int) {
        if !analyzedPageNumbers.contains(pageNumber) {
            analyzedPageNumbers.append(pageNumber)
            lastAnalyzedPageNumber = pageNumber
            lastUpdated = Date()
        }
    }

    /// Update extraction progress
    func updateExtractionProgress(itemIndex: Int) {
        lastExtractedItemIndex = itemIndex
        lastUpdated = Date()
    }

    /// Mark as interrupted
    func markInterrupted(phase: ImportPhase) {
        wasInterrupted = true
        interruptedAt = Date()
        interruptedPhase = phase
        lastUpdated = Date()
    }

    /// Clear interrupted flag (when resuming or manually starting)
    func clearInterruptedFlag() {
        wasInterrupted = false
        interruptedAt = nil
    }
}
