//
//  RecipeGenerationJob+ProcessingBannerJob.swift
//  Heirloom
//
//  Makes RecipeGenerationJob conform to ProcessingBannerJob for unified banner display
//

import SwiftUI

extension RecipeGenerationJob: ProcessingBannerJob {

    var bannerTitle: String {
        switch status {
        case .pending:
            return "Queued"
        case .processing:
            return currentPhase.displayText
        case .completed:
            return "Recipe Generated"
        case .failed:
            return "Generation Failed"
        case .dismissed:
            return "Dismissed"
        }
    }

    var bannerSubtitle: String {
        dishName
    }

    var phaseIconName: String {
        currentPhase.iconName
    }

    var accentColor: Color {
        HeirloomColors.amber
    }

    var overallProgress: Double {
        switch currentPhase {
        case .analyzing:
            return 0.25
        case .extracting:
            return 0.50
        case .enriching:
            return 0.75
        case .complete:
            return 1.0
        }
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
        case .completed, .dismissed:
            return .completed
        case .failed:
            return .failed(canRetry: true)
        }
    }

    var shouldShowInBanner: Bool {
        switch status {
        case .pending, .processing, .failed, .completed:
            return true
        case .dismissed:
            return false
        }
    }
}
