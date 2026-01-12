//
//  VideoProcessingJobManager.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-11.
//

import Foundation
import SwiftData
import UserNotifications
import Combine

/// Manages background video processing jobs with persistence and resume capability
@MainActor
final class VideoProcessingJobManager: ObservableObject {
    // MARK: - Published State

    @Published private(set) var activeJob: VideoProcessingJob?
    @Published private(set) var isProcessing = false
    @Published private(set) var queuedJobs: [VideoProcessingJob] = []

    // MARK: - Dependencies

    private var standardProcessor: VideoRecipeProcessor?
    private var asmrProcessor: ASMRVideoProcessor?
    private let usageManager: ASMRUsageManager

    // MARK: - Initialization

    init() {
        self.usageManager = ASMRUsageManager()
    }

    /// Lazily initialize standard processor when needed
    private func getStandardProcessor(context: ModelContext) async -> VideoRecipeProcessor {
        if let processor = standardProcessor {
            return processor
        }

        let transcriptionService = await WhisperKitTranscriptionService()
        let aiService = ServiceContainer.shared.resolve(AnthropicAIService.self)
        let recipeStructurer = ClaudeRecipeStructurer(aiService: aiService)
        let processor = VideoRecipeProcessor(
            transcriptionService: transcriptionService,
            recipeStructurer: recipeStructurer,
            modelContext: context,
            aiService: aiService,
            enableFrameAnalysis: true,
            enableCaching: true,
            enableAugmentation: true
        )
        self.standardProcessor = processor
        return processor
    }

    /// Lazily initialize ASMR processor when needed
    private func getASMRProcessor() -> ASMRVideoProcessor {
        if let processor = asmrProcessor {
            return processor
        }

        let processor = ASMRVideoProcessor()
        self.asmrProcessor = processor
        return processor
    }

    // MARK: - Job Creation

    /// Create a new video processing job
    func createJob(
        videoURL: URL,
        videoType: VideoType,
        userCaption: String?,
        videoDuration: TimeInterval?,
        sourceAttribution: VideoSourceAttribution?,
        context: ModelContext
    ) throws -> VideoProcessingJob {
        // Create the job
        let job = VideoProcessingJob(
            videoURL: videoURL.path,
            videoType: videoType,
            userCaption: userCaption,
            videoDuration: videoDuration,
            sourceURL: sourceAttribution?.sourceURL,
            sourceAttribution: sourceAttribution?.creatorName
        )

        // Create empty checkpoint
        let checkpoint = ProcessingCheckpoint()
        checkpoint.job = job
        job.checkpoint = checkpoint

        // Insert into context
        context.insert(job)
        context.insert(checkpoint)

        try context.save()

        // Refresh queue
        refreshQueue(context: context)

        // Auto-start if not already processing
        if !isProcessing {
            Task {
                try await startNextJob(context: context)
            }
        }

        return job
    }

    // MARK: - Queue Management

    /// Refresh the queued jobs list
    private func refreshQueue(context: ModelContext) {
        let descriptor = FetchDescriptor<VideoProcessingJob>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        do {
            let allJobs = try context.fetch(descriptor)
            queuedJobs = allJobs.filter { job in
                job.status == .pending || job.status == .processing
            }
        } catch {
            Log.error("Failed to fetch queued jobs", category: .video, metadata: ["error": error.localizedDescription])
        }
    }

    // MARK: - Job Processing

    /// Start processing the next pending job
    func startNextJob(context: ModelContext) async throws {
        guard !isProcessing else {
            Log.debug("Already processing a job, skipping", category: .video)
            return
        }

        // Find next pending job
        let descriptor = FetchDescriptor<VideoProcessingJob>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        let allJobs = try context.fetch(descriptor)
        let pendingJobs = allJobs.filter { $0.status == .pending }
        guard let job = pendingJobs.first else {
            Log.debug("No pending jobs to process", category: .video)
            return
        }

        // Start processing
        isProcessing = true
        activeJob = job

        do {
            try await processJob(job, context: context)
        } catch {
            Log.error("Job processing failed", category: .video, metadata: [
                "jobId": job.id.uuidString,
                "error": error.localizedDescription
            ])
            await handleJobFailure(job, error: error, context: context)
        }

        // Cleanup
        isProcessing = false
        activeJob = nil
        refreshQueue(context: context)

        // Process next job if available
        try await startNextJob(context: context)
    }

    /// Process a single job
    private func processJob(_ job: VideoProcessingJob, context: ModelContext) async throws {
        Log.info("Starting job processing", category: .video, metadata: ["jobId": job.id.uuidString])

        // Update status
        job.status = .processing
        job.startedAt = Date()
        try context.save()

        // Charge credits for ASMR
        if job.videoType == .asmr && job.creditsCharged == 0 {
            try chargeCredits(job, context: context)
        }

        // Load checkpoint to determine resume point
        let checkpoint = job.checkpoint ?? ProcessingCheckpoint()
        let resumePhase = checkpoint.resumePhase

        Log.debug("Resuming from phase: \(resumePhase.displayName)", category: .video, metadata: [
            "jobId": job.id.uuidString,
            "phase": resumePhase.rawValue
        ])

        // Get video URL
        guard let videoURL = URL(string: job.videoURL) else {
            throw VideoProcessingError.invalidVideoURL
        }

        // Process based on video type
        let extraction: VideoRecipeExtraction

        if job.videoType == .standard {
            extraction = try await processStandardVideo(
                videoURL: videoURL,
                job: job,
                checkpoint: checkpoint,
                resumePhase: resumePhase,
                context: context
            )
        } else {
            extraction = try await processASMRVideo(
                videoURL: videoURL,
                job: job,
                checkpoint: checkpoint,
                resumePhase: resumePhase,
                context: context
            )
        }

        // Save extraction result
        let extractionData = try JSONEncoder().encode(extraction)
        job.extractionJSON = extractionData
        job.status = .completed
        job.completedAt = Date()
        job.progress = 1.0
        job.currentPhase = .complete

        try context.save()

        // Schedule completion notification
        scheduleCompletionNotification(job)

        Log.info("Job completed successfully", category: .video, metadata: ["jobId": job.id.uuidString])
    }

    // MARK: - Standard Video Processing

    private func processStandardVideo(
        videoURL: URL,
        job: VideoProcessingJob,
        checkpoint: ProcessingCheckpoint,
        resumePhase: ProcessingPhase,
        context: ModelContext
    ) async throws -> VideoRecipeExtraction {
        // Get processor instance
        let processor = await getStandardProcessor(context: context)

        // Delegate to existing processor and monitor progress
        let cancellable = processor.$progress.sink { progress in
            Task { @MainActor in
                job.progress = progress
                try? context.save()
            }
        }

        let cancellable2 = processor.$state.sink { state in
            Task { @MainActor in
                switch state {
                case .extractingAudio:
                    job.currentPhase = .extractingAudio
                case .transcribing:
                    job.currentPhase = .transcribing
                case .analyzingFrames:
                    job.currentPhase = .analyzingFrames
                case .structuringRecipe:
                    job.currentPhase = .structuringRecipe
                case .augmentingWithSimilarRecipes:
                    job.currentPhase = .augmenting
                case .completed:
                    job.currentPhase = .complete
                default:
                    break
                }
                try? context.save()
            }
        }

        defer {
            cancellable.cancel()
            cancellable2.cancel()
        }

        // Process video through existing pipeline
        let extraction = try await processor.process(videoURL: videoURL)

        return extraction
    }

    // MARK: - ASMR Video Processing

    private func processASMRVideo(
        videoURL: URL,
        job: VideoProcessingJob,
        checkpoint: ProcessingCheckpoint,
        resumePhase: ProcessingPhase,
        context: ModelContext
    ) async throws -> VideoRecipeExtraction {
        // Get processor instance
        let processor = getASMRProcessor()

        // Monitor progress
        let cancellable = processor.$progress.sink { progress in
            Task { @MainActor in
                job.progress = progress
                try? context.save()
            }
        }

        defer {
            cancellable.cancel()
        }

        job.currentPhase = .transcribing
        try context.save()

        // Process through ASMR pipeline
        let extraction = try await processor.process(
            videoURL: videoURL,
            userCaption: job.userCaption ?? "",
            videoHash: nil
        )

        return extraction
    }

    // MARK: - Error Handling

    private func handleJobFailure(
        _ job: VideoProcessingJob,
        error: Error,
        context: ModelContext
    ) async {
        job.status = .failed
        job.errorMessage = error.localizedDescription
        job.completedAt = Date()

        // Refund credits if applicable
        if job.shouldRefundCredits {
            do {
                try refundCredits(job, context: context)
            } catch {
                Log.error("Failed to refund credits", category: .video, metadata: [
                    "jobId": job.id.uuidString,
                    "error": error.localizedDescription
                ])
            }
        }

        try? context.save()

        // Schedule failure notification
        scheduleFailureNotification(job)
    }

    // MARK: - Credit Management

    private func chargeCredits(_ job: VideoProcessingJob, context: ModelContext) throws {
        guard job.videoType == .asmr else { return }
        guard job.creditsCharged == 0 else { return }

        try usageManager.startExtraction()
        job.creditsCharged = 5

        try context.save()

        Log.info("Charged 5 credits for ASMR processing", category: .video, metadata: [
            "jobId": job.id.uuidString
        ])
    }

    private func refundCredits(_ job: VideoProcessingJob, context: ModelContext) throws {
        guard job.creditsCharged > 0 else { return }
        guard !job.creditsRefunded else { return }

        usageManager.refundExtraction()
        job.creditsRefunded = true

        try context.save()

        Log.info("Refunded \(job.creditsCharged) credits", category: .video, metadata: [
            "jobId": job.id.uuidString
        ])
    }

    // MARK: - Job Control

    /// Pause the active job
    func pauseJob(_ job: VideoProcessingJob, context: ModelContext) throws {
        guard job.status == .processing else { return }

        job.status = .paused
        try context.save()

        isProcessing = false
        activeJob = nil

        Log.info("Job paused", category: .video, metadata: ["jobId": job.id.uuidString])
    }

    /// Resume a paused job
    func resumeJob(_ job: VideoProcessingJob, context: ModelContext) async throws {
        guard job.status == .paused else { return }

        job.status = .pending
        try context.save()

        refreshQueue(context: context)

        try await startNextJob(context: context)
    }

    /// Cancel a job
    func cancelJob(_ job: VideoProcessingJob, context: ModelContext) throws {
        guard job.canCancel else { return }

        job.status = .cancelled
        job.completedAt = Date()
        try context.save()

        if activeJob?.id == job.id {
            isProcessing = false
            activeJob = nil
        }

        refreshQueue(context: context)

        Log.info("Job cancelled", category: .video, metadata: ["jobId": job.id.uuidString])
    }

    /// Retry a failed job
    func retryJob(_ job: VideoProcessingJob, context: ModelContext) async throws {
        guard job.canRetry else {
            throw VideoProcessingError.maxRetriesExceeded
        }

        job.retryCount += 1
        job.status = .pending
        job.errorMessage = nil
        job.progress = 0.0

        // Keep checkpoint for resume capability
        // Reset phase based on checkpoint
        if let checkpoint = job.checkpoint {
            job.currentPhase = checkpoint.resumePhase
            job.progress = checkpoint.estimatedProgress
        } else {
            job.currentPhase = .queued
        }

        try context.save()

        refreshQueue(context: context)

        Log.info("Job retry initiated", category: .video, metadata: [
            "jobId": job.id.uuidString,
            "retryCount": job.retryCount
        ])

        try await startNextJob(context: context)
    }

    // MARK: - Auto-Resume

    /// Resume pending jobs on app launch
    func resumePendingJobs(context: ModelContext) async {
        Log.info("Checking for pending jobs to resume", category: .video)

        // Find all processing or pending jobs
        let descriptor = FetchDescriptor<VideoProcessingJob>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        do {
            let allJobs = try context.fetch(descriptor)
            let jobs = allJobs.filter { $0.status == .processing || $0.status == .pending }

            // Mark crashed jobs as pending for retry
            for job in jobs where job.status == .processing {
                Log.info("Found crashed job, marking as pending", category: .video, metadata: [
                    "jobId": job.id.uuidString,
                    "phase": job.currentPhase.displayName
                ])
                job.status = .pending
            }

            try context.save()

            refreshQueue(context: context)

            // Auto-start after 1 second delay
            if !jobs.isEmpty {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                try await startNextJob(context: context)
            }
        } catch {
            Log.error("Failed to resume pending jobs", category: .video, metadata: [
                "error": error.localizedDescription
            ])
        }
    }

    // MARK: - Notifications

    private func scheduleCompletionNotification(_ job: VideoProcessingJob) {
        let content = UNMutableNotificationContent()
        content.title = "Your recipe is ready!"
        content.body = "Tap to review and save your extracted recipe."
        content.sound = .default
        content.categoryIdentifier = "VIDEO_PROCESSING_COMPLETE"
        content.userInfo = ["jobId": job.id.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "video_job_\(job.id.uuidString)_complete",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Log.error("Failed to schedule notification", category: .video, metadata: [
                    "error": error.localizedDescription
                ])
            }
        }
    }

    private func scheduleFailureNotification(_ job: VideoProcessingJob) {
        let content = UNMutableNotificationContent()
        content.title = "Video processing failed"
        content.body = job.canRetry ? "Tap to retry or view error details." : "Tap to view error details."
        content.sound = .default
        content.categoryIdentifier = "VIDEO_PROCESSING_FAILED"
        content.userInfo = ["jobId": job.id.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "video_job_\(job.id.uuidString)_failed",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Log.error("Failed to schedule notification", category: .video, metadata: [
                    "error": error.localizedDescription
                ])
            }
        }
    }
}

// MARK: - Errors

enum VideoProcessingError: LocalizedError {
    case invalidVideoURL
    case maxRetriesExceeded
    case jobNotFound
    case processingInProgress

    var errorDescription: String? {
        switch self {
        case .invalidVideoURL:
            return "Invalid video URL"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        case .jobNotFound:
            return "Job not found"
        case .processingInProgress:
            return "Processing already in progress"
        }
    }
}
