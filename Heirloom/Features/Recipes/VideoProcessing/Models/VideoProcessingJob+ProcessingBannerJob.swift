//
//  VideoProcessingJob+ProcessingBannerJob.swift
//  Heirloom
//
//  Makes VideoProcessingJob conform to ProcessingBannerJob for unified banner display
//

import SwiftUI

extension VideoProcessingJob: ProcessingBannerJob {

    var bannerTitle: String {
        switch status {
        case .processing:
            return processingPhase.displayName
        case .completed:
            return "Ready to Review"
        case .failed:
            return "Processing Failed"
        case .paused:
            return "Processing Paused"
        case .pending:
            return "Queued"
        case .saved:
            return "Saved"
        case .cancelled:
            return "Cancelled"
        }
    }

    var bannerSubtitle: String {
        userCaption ?? "Video recipe"
    }

    /// Computed phase for banner display, handles the currentPhase property
    var processingPhase: ProcessingPhase {
        currentPhase
    }

    var phaseIconName: String {
        switch currentPhase {
        case .queued:
            return "clock"
        case .loadingModel:
            return "arrow.down.circle"
        case .extractingAudio:
            return "waveform"
        case .transcribing:
            return "text.bubble"
        case .analyzingFrames:
            return "photo.on.rectangle"
        case .structuringRecipe:
            return "text.badge.checkmark"
        case .augmenting:
            return "sparkles"
        case .complete:
            return "checkmark.circle.fill"
        }
    }

    var accentColor: Color {
        HeirloomColors.tomato
    }

    var overallProgress: Double {
        progress
    }

    var totalItems: Int {
        1
    }

    var bannerStatus: ProcessingBannerStatus {
        switch status {
        case .pending:
            return .pending
        case .processing:
            return .processing
        case .paused:
            return .paused
        case .completed, .saved:
            return .completed
        case .failed:
            return .failed(canRetry: canRetry)
        case .cancelled:
            return .completed
        }
    }

    var shouldShowInBanner: Bool {
        status == .processing || status == .paused ||
        (status == .failed && canRetry) ||
        status == .completed
    }
}
