//
//  SyncJob.swift
//  Heirloom
//
//  Lightweight SwiftData model for tracking cloud restore progress.
//  Only created during initial sync (lastSyncDate == nil), not periodic syncs.
//

import Foundation
import SwiftData

@Model
final class SyncJob {
    var id: UUID
    var status: SyncJobStatus
    var totalRecipes: Int
    var downloadedRecipes: Int
    var phase: SyncJobPhase
    var createdAt: Date

    init() {
        self.id = UUID()
        self.status = .processing
        self.totalRecipes = 0
        self.downloadedRecipes = 0
        self.phase = .collections
        self.createdAt = Date()
    }
}

// MARK: - SyncJobStatus

enum SyncJobStatus: String, Codable {
    case processing
    case completed
    case failed
}

// MARK: - SyncJobPhase

enum SyncJobPhase: String, Codable {
    case collections
    case recipes
    case relinking

    var displayText: String {
        switch self {
        case .collections:
            return "Downloading collections"
        case .recipes:
            return "Downloading recipes"
        case .relinking:
            return "Linking recipes to collections"
        }
    }
}
