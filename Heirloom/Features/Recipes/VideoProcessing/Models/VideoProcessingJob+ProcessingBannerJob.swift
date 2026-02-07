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
        case .analyzing:
            return "Analyzing Video"
        case .awaitingConfirmation:
            return "Confirm Import"
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
            // If recipeID is nil, this was auto-dismissed but not actually saved
            // Show "Ready to Review" instead of "Saved"
            if recipeID == nil {
                return "Ready to Review"
            }
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
        case .analyzing:
            return .processing  // Show as processing during analysis
        case .awaitingConfirmation:
            return .paused  // Treat as paused (needs user action)
        case .processing:
            return .processing
        case .paused:
            return .paused
        case .completed:
            return .completed
        case .saved:
            // If recipeID is nil, this was auto-dismissed but not actually reviewed/saved
            // Treat it as needing review (completed status)
            if recipeID == nil {
                return .completed
            }
            return .completed
        case .failed:
            return .failed(canRetry: canRetry)
        case .cancelled:
            return .completed
        }
    }

    var shouldShowInBanner: Bool {
        // Show analyzing, awaiting confirmation, processing, paused, completed (needs review), or failed (can retry)
        if status == .analyzing || status == .awaitingConfirmation {
            return true
        }
        if status == .processing || status == .paused || status == .completed {
            return true
        }
        if status == .failed && canRetry {
            return true
        }
        // Also show "saved" jobs that were auto-dismissed but not actually finalized
        // (recipeID is nil means no recipe was saved yet - needs review)
        if status == .saved && recipeID == nil {
            return true
        }
        return false
    }
}
