//
//  JobCleanupService.swift
//  Heirloom
//
//  Service for cleaning up old jobs and orphaned files
//

import Foundation
import SwiftData

/// Service responsible for cleaning up stale job data and orphaned files
/// This helps prevent storage bloat from accumulated video processing and import jobs
@MainActor
class JobCleanupService {

    // MARK: - Configuration

    /// Age threshold for deleting cancelled/failed jobs (7 days)
    static let failedJobRetentionDays: Int = 7

    /// Age threshold for deleting completed/saved jobs (90 days)
    static let completedJobRetentionDays: Int = 90

    /// Age threshold for cleaning App Group temp files (30 days)
    static let appGroupTempFileRetentionDays: Int = 30

    // MARK: - Main Cleanup Entry Point

    /// Perform comprehensive cleanup of stale jobs and orphaned files
    /// Should be called periodically (e.g., on app launch or via background task)
    func performDailyCleanup(context: ModelContext) async {
        Log.info("Starting daily cleanup", category: .general)
        DeviceLogger.shared.log("🧹 [Cleanup] Starting daily cleanup")

        // Track cleanup metrics
        var deletedVideoJobs = 0
        var deletedImportJobs = 0
        var deletedVideoFiles = 0
        var deletedAppGroupFiles = 0
        var deletedOrphanedImages = 0

        // 1. Clean up old VideoProcessingJobs
        let videoResult = await cleanupVideoProcessingJobs(context: context)
        deletedVideoJobs = videoResult.jobsDeleted
        deletedVideoFiles = videoResult.filesDeleted

        // 2. Clean up old ImportJobs
        deletedImportJobs = await cleanupImportJobs(context: context)

        // 3. Clean up App Group shared container temp files
        deletedAppGroupFiles = await cleanupAppGroupTempFiles()

        // 4. Clean up orphaned recipe images
        deletedOrphanedImages = await cleanupOrphanedImages(context: context)

        // Log summary
        Log.info("Daily cleanup completed", category: .general, metadata: [
            "deletedVideoJobs": deletedVideoJobs,
            "deletedImportJobs": deletedImportJobs,
            "deletedVideoFiles": deletedVideoFiles,
            "deletedAppGroupFiles": deletedAppGroupFiles,
            "deletedOrphanedImages": deletedOrphanedImages
        ])
        DeviceLogger.shared.log("✅ [Cleanup] Complete: \(deletedVideoJobs) video jobs, \(deletedImportJobs) import jobs, \(deletedVideoFiles) video files, \(deletedAppGroupFiles) temp files, \(deletedOrphanedImages) orphaned images deleted")
    }

    // MARK: - Video Processing Job Cleanup

    /// Clean up old VideoProcessingJobs based on their status
    /// - Returns: Tuple of (jobs deleted, video files deleted)
    private func cleanupVideoProcessingJobs(context: ModelContext) async -> (jobsDeleted: Int, filesDeleted: Int) {
        var jobsDeleted = 0
        var filesDeleted = 0

        let now = Date()
        let failedCutoff = Calendar.current.date(byAdding: .day, value: -Self.failedJobRetentionDays, to: now) ?? now
        let completedCutoff = Calendar.current.date(byAdding: .day, value: -Self.completedJobRetentionDays, to: now) ?? now

        let descriptor = FetchDescriptor<VideoProcessingJob>()

        do {
            let allJobs = try context.fetch(descriptor)

            for job in allJobs {
                var shouldDelete = false
                let completedAt = job.completedAt ?? job.createdAt

                switch job.status {
                case .cancelled, .failed:
                    // Delete cancelled/failed jobs older than 7 days
                    shouldDelete = completedAt < failedCutoff

                case .completed, .saved:
                    // Delete completed/saved jobs older than 90 days
                    shouldDelete = completedAt < completedCutoff

                case .pending, .analyzing, .awaitingConfirmation, .processing, .paused:
                    // Don't delete active jobs or jobs waiting for user action
                    shouldDelete = false
                }

                if shouldDelete {
                    // Delete the video file first
                    let videoURL = URL(fileURLWithPath: job.videoURL)
                    if FileManager.default.fileExists(atPath: videoURL.path) {
                        do {
                            try FileManager.default.removeItem(at: videoURL)
                            filesDeleted += 1
                            Log.debug("Deleted video file during cleanup", category: .general, metadata: [
                                "jobId": job.id.uuidString,
                                "path": job.videoURL
                            ])
                        } catch {
                            Log.warning("Failed to delete video file during cleanup", category: .general, metadata: [
                                "error": error.localizedDescription
                            ])
                        }
                    }

                    // Delete the job
                    context.delete(job)
                    jobsDeleted += 1

                    Log.debug("Deleted stale video job", category: .general, metadata: [
                        "jobId": job.id.uuidString,
                        "status": job.status.rawValue,
                        "age": Int(now.timeIntervalSince(completedAt) / 86400)
                    ])
                }
            }

            if jobsDeleted > 0 {
                try context.save()
            }

        } catch {
            Log.error("Failed to cleanup video processing jobs", category: .general, metadata: [
                "error": error.localizedDescription
            ])
        }

        return (jobsDeleted, filesDeleted)
    }

    // MARK: - Import Job Cleanup

    /// Clean up old ImportJobs based on their status
    private func cleanupImportJobs(context: ModelContext) async -> Int {
        var jobsDeleted = 0

        let now = Date()
        let failedCutoff = Calendar.current.date(byAdding: .day, value: -Self.failedJobRetentionDays, to: now) ?? now
        let completedCutoff = Calendar.current.date(byAdding: .day, value: -Self.completedJobRetentionDays, to: now) ?? now

        let descriptor = FetchDescriptor<ImportJob>()

        do {
            let allJobs = try context.fetch(descriptor)

            for job in allJobs {
                var shouldDelete = false
                let completedAt = job.completedAt ?? job.createdAt

                switch job.status {
                case .failed:
                    // Delete failed jobs older than 7 days
                    shouldDelete = completedAt < failedCutoff

                case .completed:
                    // Delete completed jobs older than 90 days
                    shouldDelete = completedAt < completedCutoff

                case .pending, .processing, .paused:
                    // Don't delete active or paused jobs
                    shouldDelete = false
                }

                if shouldDelete {
                    context.delete(job)
                    jobsDeleted += 1

                    Log.debug("Deleted stale import job", category: .general, metadata: [
                        "jobId": job.id.uuidString,
                        "status": job.status.rawValue,
                        "age": Int(now.timeIntervalSince(completedAt) / 86400)
                    ])
                }
            }

            if jobsDeleted > 0 {
                try context.save()
            }

        } catch {
            Log.error("Failed to cleanup import jobs", category: .general, metadata: [
                "error": error.localizedDescription
            ])
        }

        return jobsDeleted
    }

    // MARK: - App Group Temp File Cleanup

    /// Clean up old temp files from App Group shared container
    /// This includes SharedVideos/ directory used by Share Extension
    private func cleanupAppGroupTempFiles() async -> Int {
        var filesDeleted = 0

        guard let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedConstants.appGroupIdentifier
        ) else {
            Log.warning("Cannot access App Group container for cleanup", category: .general)
            return 0
        }

        let sharedVideosURL = appGroupURL.appendingPathComponent("SharedVideos", isDirectory: true)
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -Self.appGroupTempFileRetentionDays,
            to: Date()
        ) ?? Date()

        do {
            let fileManager = FileManager.default

            // Check if directory exists
            guard fileManager.fileExists(atPath: sharedVideosURL.path) else {
                return 0
            }

            let files = try fileManager.contentsOfDirectory(
                at: sharedVideosURL,
                includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey]
            )

            for fileURL in files {
                // Get file creation/modification date
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                let fileDate = (attributes[.modificationDate] as? Date) ??
                               (attributes[.creationDate] as? Date) ??
                               Date()

                // Delete if older than cutoff
                if fileDate < cutoffDate {
                    try fileManager.removeItem(at: fileURL)
                    filesDeleted += 1

                    Log.debug("Deleted old shared video file", category: .general, metadata: [
                        "file": fileURL.lastPathComponent,
                        "age": Int(Date().timeIntervalSince(fileDate) / 86400)
                    ])
                }
            }

        } catch {
            Log.warning("Error cleaning up App Group temp files", category: .general, metadata: [
                "error": error.localizedDescription
            ])
        }

        return filesDeleted
    }

    // MARK: - Orphaned Video File Cleanup

    /// Find and delete video files that don't have corresponding jobs
    /// Call this occasionally for comprehensive cleanup
    func cleanupOrphanedVideoFiles(context: ModelContext) async -> Int {
        var deletedCount = 0

        // Get documents directory videos folder
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDir = documentsURL.appendingPathComponent("Videos", isDirectory: true)

        guard FileManager.default.fileExists(atPath: videosDir.path) else {
            return 0
        }

        // Get all video file paths from jobs
        let descriptor = FetchDescriptor<VideoProcessingJob>()

        do {
            let allJobs = try context.fetch(descriptor)
            let jobVideoPaths = Set(allJobs.map { $0.videoURL })

            // List all files in Videos directory
            let videoFiles = try FileManager.default.contentsOfDirectory(at: videosDir, includingPropertiesForKeys: nil)

            for fileURL in videoFiles {
                // Check if this file belongs to a job
                if !jobVideoPaths.contains(fileURL.path) {
                    // Orphaned file - delete it
                    do {
                        try FileManager.default.removeItem(at: fileURL)
                        deletedCount += 1
                        Log.debug("Deleted orphaned video file", category: .general, metadata: [
                            "path": fileURL.path
                        ])
                    } catch {
                        Log.warning("Failed to delete orphaned video file", category: .general, metadata: [
                            "path": fileURL.path,
                            "error": error.localizedDescription
                        ])
                    }
                }
            }

        } catch {
            Log.error("Failed to cleanup orphaned video files", category: .general, metadata: [
                "error": error.localizedDescription
            ])
        }

        if deletedCount > 0 {
            Log.info("Cleaned up orphaned video files", category: .general, metadata: [
                "count": deletedCount
            ])
        }

        return deletedCount
    }

    // MARK: - Orphaned Image Cleanup

    /// Clean up orphaned recipe images (images without corresponding recipes)
    private func cleanupOrphanedImages(context: ModelContext) async -> Int {
        // Collect all valid image filenames from recipes
        let descriptor = FetchDescriptor<Recipe>()

        do {
            let allRecipes = try context.fetch(descriptor)
            var validImageFileNames = Set<String>()

            for recipe in allRecipes {
                // Add main image filename
                if let imageFileName = recipe.imageFileName {
                    validImageFileNames.insert(imageFileName)
                }

                // Add image variant filenames (for heritage/theme recipes)
                if let variants = recipe.imageVariants {
                    for fileName in variants.values {
                        validImageFileNames.insert(fileName)
                    }
                }
            }

            Log.debug("Collected valid image references", category: .general, metadata: [
                "count": validImageFileNames.count
            ])

            // Call ImageStorageService to clean up orphaned files
            let imageStorageService = ServiceContainer.shared.resolve(ImageStorageService.self)
            let deletedCount = await imageStorageService.cleanupOrphanedImages(validImageFileNames: validImageFileNames)

            return deletedCount

        } catch {
            Log.error("Failed to collect recipe image references for cleanup", category: .general, metadata: [
                "error": error.localizedDescription
            ])
            return 0
        }
    }
}
