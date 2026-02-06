//
//  ImportJob+ProcessingBannerJob.swift
//  Heirloom
//
//  Makes ImportJob conform to ProcessingBannerJob for unified banner display
//

import SwiftUI

extension ImportJob: ProcessingBannerJob {

    var bannerTitle: String {
        switch status {
        case .completed:
            // For single-recipe imports, would need recipe title from context
            // Fall back to showing cookbook name or generic message
            if let cookbookName = cookbookName, !cookbookName.isEmpty {
                return "Added to \(cookbookName)"
            }
            return "Import complete"

        case .paused:
            return "Import Paused"

        case .failed:
            if canResume {
                return "Import Interrupted"
            }
            return "Import Failed"

        case .pending:
            return "Import Queued"

        case .processing:
            return phase.displayName
        }
    }

    var bannerSubtitle: String {
        switch status {
        case .completed:
            let successCount = successfulItems
            let failCount = failedItems

            if let collectionName = cookbookName, !collectionName.isEmpty {
                if failCount > 0 {
                    return "\(successCount) added to \(collectionName), \(failCount) failed"
                }
                return "Saved to \(collectionName)"
            } else {
                if failCount > 0 {
                    return "\(successCount) recipes added, \(failCount) failed"
                }
                return "\(successCount) recipes added"
            }

        case .paused:
            return "Tap to resume \u{2022} \(completedItems) of \(totalItems) complete"

        case .failed:
            if canResume {
                return "Tap to retry from last checkpoint"
            }
            return "\(failedItems) recipe\(failedItems == 1 ? "" : "s") failed"

        case .pending:
            return "Waiting to start..."

        case .processing:
            if totalItems > 1 {
                return "\(phase.displayName) \u{2022} \(completedItems) of \(totalItems)"
            }
            if let cookbookName = cookbookName, !cookbookName.isEmpty {
                return "Saving to \(cookbookName)"
            }
            return "Processing your recipe"
        }
    }

    var phaseIconName: String {
        phase.iconName
    }

    var accentColor: Color {
        HeirloomColors.tomato
    }

    var bannerStatus: ProcessingBannerStatus {
        switch status {
        case .pending:
            return .pending
        case .processing:
            return .processing
        case .paused:
            return .paused
        case .completed:
            return .completed
        case .failed:
            return .failed(canRetry: canResume)
        }
    }

    var shouldShowInBanner: Bool {
        switch status {
        case .processing, .paused, .completed:
            return true
        case .failed:
            return canResume
        case .pending:
            return false
        }
    }
}
