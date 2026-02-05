//
//  ProcessingQueueManager.swift
//  Heirloom
//
//  Orchestration service for unified processing queue
//  Aggregates state across all job types for banner display
//

import Foundation
import SwiftUI
import SwiftData
import Observation

/// Manages the unified processing queue state for all job types
/// Observable for real-time UI updates
@MainActor
@Observable
class ProcessingQueueManager {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Initialization

    init() {}

    /// Configure with model context for data access
    func configure(with context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Aggregated State

    /// All active jobs across all types
    func allActiveJobs() -> [AnyProcessingJob] {
        guard let context = modelContext else { return [] }

        var jobs: [AnyProcessingJob] = []

        // Fetch video jobs
        let videoDescriptor = FetchDescriptor<VideoProcessingJob>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        if let videoJobs = try? context.fetch(videoDescriptor) {
            for job in videoJobs where job.shouldShowInBanner {
                jobs.append(AnyProcessingJob(job, type: .video))
            }
        }

        // Fetch import jobs
        let importDescriptor = FetchDescriptor<ImportJob>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        if let importJobs = try? context.fetch(importDescriptor) {
            for job in importJobs where job.shouldShowInBanner {
                jobs.append(AnyProcessingJob(job, type: .importJob))
            }
        }

        // Fetch generation jobs
        let genDescriptor = FetchDescriptor<RecipeGenerationJob>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        if let genJobs = try? context.fetch(genDescriptor) {
            for job in genJobs where job.shouldShowInBanner {
                jobs.append(AnyProcessingJob(job, type: .generation))
            }
        }

        return jobs
    }

    /// Total aggregated progress across all processing jobs (0.0 to 1.0)
    func totalProgress() -> Double {
        guard let context = modelContext else { return 0 }

        var totalProgress: Double = 0
        var count = 0

        // Video jobs
        let videoDescriptor = FetchDescriptor<VideoProcessingJob>()
        if let videoJobs = try? context.fetch(videoDescriptor) {
            for job in videoJobs where job.status == .processing {
                totalProgress += job.progress
                count += 1
            }
        }

        // Import jobs
        let importDescriptor = FetchDescriptor<ImportJob>()
        if let importJobs = try? context.fetch(importDescriptor) {
            for job in importJobs where job.status == .processing {
                totalProgress += job.overallProgress
                count += 1
            }
        }

        // Generation jobs
        let genDescriptor = FetchDescriptor<RecipeGenerationJob>()
        if let genJobs = try? context.fetch(genDescriptor) {
            for job in genJobs where job.status == .processing {
                // Estimate progress based on phase
                let progress: Double
                switch job.currentPhase {
                case .analyzing: progress = 0.25
                case .extracting: progress = 0.50
                case .enriching: progress = 0.75
                case .complete: progress = 1.0
                }
                totalProgress += progress
                count += 1
            }
        }

        guard count > 0 else { return 0 }
        return totalProgress / Double(count)
    }

    /// Whether there are any active jobs
    func hasActiveJobs() -> Bool {
        !allActiveJobs().isEmpty
    }

    /// The highest priority job for banner display
    func priorityJob() -> AnyProcessingJob? {
        allActiveJobs()
            .sorted { $0.bannerStatus.priority > $1.bannerStatus.priority }
            .first
    }

    // MARK: - Queue Counts

    /// Number of jobs currently processing
    func processingCount() -> Int {
        guard let context = modelContext else { return 0 }

        var count = 0

        let videoDescriptor = FetchDescriptor<VideoProcessingJob>()
        if let videoJobs = try? context.fetch(videoDescriptor) {
            count += videoJobs.filter { $0.status == .processing }.count
        }

        let importDescriptor = FetchDescriptor<ImportJob>()
        if let importJobs = try? context.fetch(importDescriptor) {
            count += importJobs.filter { $0.status == .processing }.count
        }

        let genDescriptor = FetchDescriptor<RecipeGenerationJob>()
        if let genJobs = try? context.fetch(genDescriptor) {
            count += genJobs.filter { $0.status == .processing }.count
        }

        return count
    }

    /// Number of jobs queued (pending)
    func queuedCount() -> Int {
        guard let context = modelContext else { return 0 }

        var count = 0

        let videoDescriptor = FetchDescriptor<VideoProcessingJob>()
        if let videoJobs = try? context.fetch(videoDescriptor) {
            count += videoJobs.filter { $0.status == .pending }.count
        }

        let importDescriptor = FetchDescriptor<ImportJob>()
        if let importJobs = try? context.fetch(importDescriptor) {
            count += importJobs.filter { $0.status == .pending }.count
        }

        return count
    }

    /// Number of failed jobs
    func failedCount() -> Int {
        guard let context = modelContext else { return 0 }

        var count = 0

        let videoDescriptor = FetchDescriptor<VideoProcessingJob>()
        if let videoJobs = try? context.fetch(videoDescriptor) {
            count += videoJobs.filter { $0.status == .failed }.count
        }

        let importDescriptor = FetchDescriptor<ImportJob>()
        if let importJobs = try? context.fetch(importDescriptor) {
            count += importJobs.filter { $0.status == .failed }.count
        }

        let genDescriptor = FetchDescriptor<RecipeGenerationJob>()
        if let genJobs = try? context.fetch(genDescriptor) {
            count += genJobs.filter { $0.status == .failed }.count
        }

        return count
    }

    /// Number of completed jobs awaiting review
    func completedCount() -> Int {
        guard let context = modelContext else { return 0 }

        var count = 0

        let videoDescriptor = FetchDescriptor<VideoProcessingJob>()
        if let videoJobs = try? context.fetch(videoDescriptor) {
            count += videoJobs.filter { $0.status == .completed }.count
        }

        let importDescriptor = FetchDescriptor<ImportJob>()
        if let importJobs = try? context.fetch(importDescriptor) {
            count += importJobs.filter { $0.status == .completed }.count
        }

        let genDescriptor = FetchDescriptor<RecipeGenerationJob>()
        if let genJobs = try? context.fetch(genDescriptor) {
            count += genJobs.filter { $0.status == .completed }.count
        }

        return count
    }

    // MARK: - Job Type Helpers

    /// Get all video jobs
    func videoJobs() -> [VideoProcessingJob] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<VideoProcessingJob>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Get all import jobs
    func importJobs() -> [ImportJob] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<ImportJob>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Get all generation jobs
    func generationJobs() -> [RecipeGenerationJob] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<RecipeGenerationJob>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
