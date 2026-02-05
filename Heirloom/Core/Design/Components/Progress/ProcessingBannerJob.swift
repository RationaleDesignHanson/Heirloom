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
}

/// Protocol that all job types must conform to for unified banner display
protocol ProcessingBannerJob: AnyObject, Identifiable where ID == UUID {

    /// Unique identifier for the job
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
