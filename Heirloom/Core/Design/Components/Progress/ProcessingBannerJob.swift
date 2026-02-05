//
//  ProcessingBannerJob.swift
//  Heirloom
//
//  Protocol for displaying any processing job in a unified bottom banner
//

import SwiftUI

/// Status for processing banner display logic
enum ProcessingBannerStatus: Equatable {
    case pending
    case processing
    case paused
    case completed
    case failed(canRetry: Bool)

    static func == (lhs: ProcessingBannerStatus, rhs: ProcessingBannerStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending),
             (.processing, .processing),
             (.paused, .paused),
             (.completed, .completed):
            return true
        case let (.failed(lhsRetry), .failed(rhsRetry)):
            return lhsRetry == rhsRetry
        default:
            return false
        }
    }

    /// Priority for sorting jobs in the queue (higher = more urgent)
    /// Used to determine which job appears first in the unified banner
    var priority: Int {
        switch self {
        case .processing:
            return 100  // Highest priority - actively processing
        case .failed:
            return 80   // High priority - needs attention
        case .paused:
            return 60   // Medium priority - user action paused
        case .pending:
            return 40   // Lower priority - waiting in queue
        case .completed:
            return 20   // Lowest priority - already done
        }
    }
}

/// Protocol that all job types must conform to for unified banner display
/// Note: Don't inherit from Identifiable here - SwiftData @Model types already conform,
/// and re-declaring causes duplicate symbol errors
protocol ProcessingBannerJob: AnyObject {

    /// Unique identifier for the job (satisfies Identifiable.id for @Model types)
    var id: UUID { get }

    /// Display title for the banner (e.g., "Extracting recipes...", "Processing video...")
    var bannerTitle: String { get }

    /// Subtitle text (e.g., "5 of 10 complete", "Transcribing audio")
    var bannerSubtitle: String { get }

    /// Progress value 0.0 to 1.0
    var overallProgress: Double { get }

    /// SF Symbol name for current phase icon
    var phaseIconName: String { get }

    /// Accent color for progress bar and icon
    var accentColor: Color { get }

    /// Current status for determining banner behavior
    var bannerStatus: ProcessingBannerStatus { get }

    /// Total number of items being processed (for badge display)
    var totalItems: Int { get }

    /// Whether this job should be shown in the banner
    var shouldShowInBanner: Bool { get }
}

// MARK: - Default Implementations

extension ProcessingBannerJob {

    /// Default: show banner for processing, paused, or resumable failed jobs
    var shouldShowInBanner: Bool {
        switch bannerStatus {
        case .processing, .paused:
            return true
        case .failed(let canRetry):
            return canRetry
        case .pending, .completed:
            return false
        }
    }
}

// MARK: - Processing Job Type

/// Type of processing job for visual differentiation
enum ProcessingJobType {
    case video
    case importJob
    case generation

    var typeBadgeIcon: String {
        switch self {
        case .video:
            return "video.fill"
        case .importJob:
            return "doc.fill"
        case .generation:
            return "sparkles"
        }
    }

    var typeBadgeLabel: String {
        switch self {
        case .video:
            return "Video"
        case .importJob:
            return "Import"
        case .generation:
            return "Generate"
        }
    }
}

// MARK: - Type-Erased Wrapper

/// Type-erased wrapper for ProcessingBannerJob to use in SwiftUI views
struct AnyProcessingJob: Identifiable {
    let id: UUID
    let bannerTitle: String
    let bannerSubtitle: String
    let overallProgress: Double
    let phaseIconName: String
    let accentColor: Color
    let bannerStatus: ProcessingBannerStatus
    let totalItems: Int
    let shouldShowInBanner: Bool
    let jobType: ProcessingJobType

    init<T: ProcessingBannerJob>(_ job: T, type: ProcessingJobType) {
        self.id = job.id
        self.bannerTitle = job.bannerTitle
        self.bannerSubtitle = job.bannerSubtitle
        self.overallProgress = job.overallProgress
        self.phaseIconName = job.phaseIconName
        self.accentColor = job.accentColor
        self.bannerStatus = job.bannerStatus
        self.totalItems = job.totalItems
        self.shouldShowInBanner = job.shouldShowInBanner
        self.jobType = type
    }

    /// Convenience initializer for previews and testing
    init(
        id: UUID,
        bannerTitle: String,
        bannerSubtitle: String,
        overallProgress: Double,
        phaseIconName: String,
        accentColor: Color,
        bannerStatus: ProcessingBannerStatus,
        totalItems: Int,
        shouldShowInBanner: Bool,
        jobType: ProcessingJobType
    ) {
        self.id = id
        self.bannerTitle = bannerTitle
        self.bannerSubtitle = bannerSubtitle
        self.overallProgress = overallProgress
        self.phaseIconName = phaseIconName
        self.accentColor = accentColor
        self.bannerStatus = bannerStatus
        self.totalItems = totalItems
        self.shouldShowInBanner = shouldShowInBanner
        self.jobType = jobType
    }
}
