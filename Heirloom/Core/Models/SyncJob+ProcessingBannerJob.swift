//
//  SyncJob+ProcessingBannerJob.swift
//  Heirloom
//
//  Makes SyncJob conform to ProcessingBannerJob for unified banner display
//

import SwiftUI

extension SyncJob: ProcessingBannerJob {

    var bannerTitle: String {
        switch status {
        case .processing:
            return "Restoring from Cloud"
        case .completed:
            return "Restore complete"
        case .failed:
            return "Restore failed"
        }
    }

    var bannerSubtitle: String {
        switch phase {
        case .collections:
            return "Downloading collections"
        case .recipes:
            if totalRecipes > 0 {
                return "Downloading recipes — \(downloadedRecipes) of \(totalRecipes)"
            }
            return "Downloading recipes"
        case .relinking:
            return "Linking recipes to collections"
        }
    }

    var phaseIconName: String {
        "icloud.and.arrow.down.fill"
    }

    var accentColor: Color {
        HeirloomColors.familyGreen
    }

    var overallProgress: Double {
        guard totalRecipes > 0 else { return 0.1 }
        return Double(downloadedRecipes) / Double(totalRecipes)
    }

    var totalItems: Int {
        totalRecipes
    }

    var bannerStatus: ProcessingBannerStatus {
        switch status {
        case .processing:
            return .processing
        case .completed:
            return .completed
        case .failed:
            return .failed(canRetry: false)
        }
    }

    var shouldShowInBanner: Bool {
        switch status {
        case .processing:
            return true
        case .completed, .failed:
            return false
        }
    }
}
