//
//  VideoProcessingJobManager.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-11.
//

import Foundation
import SwiftData
import UserNotifications
import BackgroundTasks
import Combine
import CryptoKit
import AVFoundation
import UIKit

/// Manages background video processing jobs with persistence and resume capability
@MainActor
final class VideoProcessingJobManager: ObservableObject {
    // MARK: - Published State

    @Published private(set) var activeJob: VideoProcessingJob?
    @Published private(set) var isProcessing = false
    @Published private(set) var queuedJobs: [VideoProcessingJob] = []

    /// Immediately signals UI when a new job is created (bypasses @Query latency)
    /// Set synchronously during job creation, cleared after UI has time to observe
    @Published private(set) var pendingJobId: UUID?

    // MARK: - Dependencies

    private var standardProcessor: VideoRecipeProcessor?
    private var asmrProcessor: ASMRVideoProcessor?
    private let usageManager: ASMRUsageManager
    private var modelContext: ModelContext?

    // MARK: - Initialization

    init() {
        self.usageManager = ASMRUsageManager()
        setupBackgroundHandling()
    }

    /// Set the ModelContext for saving job state
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Background Task Handling

    private func setupBackgroundHandling() {
        // Observe app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func appWillEnterBackground() {
        guard isProcessing, let job = activeJob else { return }

        Log.info("App backgrounding during video processing", category: .video, metadata: [
            "job_id": job.id.uuidString,
            "phase": job.currentPhase.rawValue,
            "progress": job.progress
        ])

        // Mark as potentially interrupted
        job.wasInterrupted = true
        job.interruptedAt = Date()

        // Save immediately
        if let context = modelContext {
            try? context.save()
        }

        Log.info("Marked video job as interrupted on background", category: .video)
    }

    @objc private func appDidBecomeActive() {
        guard isProcessing else { return }

        Log.info("App foregrounding during video processing", category: .video)

        // Clear interrupted flag if processing continues
        if let job = activeJob {
            job.wasInterrupted = false
            job.interruptedAt = nil

            if let context = modelContext {
                try? context.save()
            }
        }
    }

    /// Lazily initialize standard processor when needed
    private func getStandardProcessor(context: ModelContext) async -> VideoRecipeProcessor {
        if let processor = standardProcessor {
            return processor
        }

        let transcriptionService = await WhisperKitTranscriptionService()
        let aiService = ServiceContainer.shared.resolve((any AIServiceProtocol).self)
        let recipeStructurer = ClaudeRecipeStructurer(aiService: aiService)
        let processor = VideoRecipeProcessor(
            transcriptionService: transcriptionService,
            recipeStructurer: recipeStructurer,
            modelContext: context,
            aiService: aiService,
            enableFrameAnalysis: true,
            enableCaching: true,
            enableAugmentation: true  // Re-enabled - AppGroup issue fixed
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
        context: ModelContext,
        dishNameHint: String? = nil
    ) throws -> VideoProcessingJob {
        // STEP 1: Compute video hash for duplicate detection
        let videoData = try Data(contentsOf: videoURL)
        let videoHashData = SHA256.hash(data: videoData)
        let videoHash = videoHashData.compactMap { String(format: "%02x", $0) }.joined()

        // STEP 2: Check for existing jobs with same hash
        let descriptor = FetchDescriptor<VideoProcessingJob>()
        let allJobs = try context.fetch(descriptor)

        // Filter for matching hash and active statuses
        if let existingJob = allJobs.first(where: { job in
            job.videoHash == videoHash &&
            (job.status == .pending || job.status == .processing || job.status == .completed)
        }) {
            Log.info("Duplicate video detected, returning existing job", category: .video, metadata: [
                "existingJobId": existingJob.id.uuidString,
                "status": existingJob.status.rawValue
            ])
            return existingJob  // Don't create duplicate
        }

        // STEP 3: No duplicate found, proceed with job creation
        // Copy video to persistent location in app documents directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDir = documentsURL.appendingPathComponent("Videos", isDirectory: true)

        // Create Videos directory if needed
        try? FileManager.default.createDirectory(at: videosDir, withIntermediateDirectories: true)

        // Copy video with unique name
        let destinationURL = videosDir.appendingPathComponent("\(UUID().uuidString).mov")
        try FileManager.default.copyItem(at: videoURL, to: destinationURL)

        Log.info("Video copied to persistent location", category: .video, metadata: [
            "from": videoURL.path,
            "to": destinationURL.path,
            "hash": videoHash
        ])

        // Create the job with persistent URL and hash
        let job = VideoProcessingJob(
            videoURL: destinationURL.path,
            videoType: videoType,
            userCaption: userCaption,
            videoDuration: videoDuration,
            videoHash: videoHash,
            sourceURL: sourceAttribution?.sourceURL,
            sourceAttribution: sourceAttribution?.creatorName,
            dishNameHint: dishNameHint
        )

        // Generate thumbnail asynchronously (don't block job creation)
        // Will also update placeholder recipe with the thumbnail
        Task {
            let thumbnailData = await generateThumbnail(from: destinationURL)
            await MainActor.run {
                job.thumbnailData = thumbnailData

                // Also save thumbnail to placeholder recipe
                if let thumbnailData = thumbnailData,
                   let placeholderRecipeId = job.placeholderRecipeID,
                   let image = UIImage(data: thumbnailData) {
                    // Find placeholder recipe and update its image
                    let descriptor = FetchDescriptor<Recipe>(predicate: #Predicate { $0.id == placeholderRecipeId })
                    if let placeholder = try? context.fetch(descriptor).first {
                        Task {
                            let imageService = ServiceContainer.shared.resolve(ImageStorageService.self)
                            if let fileName = try? await imageService.saveImage(image, recipeId: placeholderRecipeId) {
                                await MainActor.run {
                                    placeholder.imageFileName = fileName
                                    try? context.save()
                                }
                            }
                        }
                    }
                }

                try? context.save()
            }
        }

        // Create empty checkpoint
        let checkpoint = ProcessingCheckpoint()
        checkpoint.job = job
        job.checkpoint = checkpoint

        // Create placeholder recipe for immediate display in recipe list
        let placeholderRecipe = Recipe.createVideoProcessingPlaceholder(
            jobId: job.id,
            thumbnailData: nil, // Will be set later when thumbnail is generated
            sourceURL: sourceAttribution?.sourceURL
        )
        job.placeholderRecipeID = placeholderRecipe.id

        // Insert into context
        context.insert(job)
        context.insert(checkpoint)
        context.insert(placeholderRecipe)

        Log.info("Created placeholder recipe for video processing", category: .video, metadata: [
            "jobId": job.id.uuidString,
            "placeholderRecipeId": placeholderRecipe.id.uuidString
        ])

        // Signal UI immediately (bypasses @Query latency)
        self.pendingJobId = job.id

        try context.save()

        // Clear pendingJobId after delay to let UI observe it
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                if self.pendingJobId == job.id {
                    self.pendingJobId = nil
                }
            }
        }

        // Refresh queue
        refreshQueue(context: context)

        // Auto-start if not already processing
        if !isProcessing {
            Task {
                try await startNextJob(context: context)
            }
        }

        // Schedule background task for processing when app is backgrounded
        scheduleBackgroundProcessingTask()

        return job
    }

    // MARK: - Background Task Scheduling

    private func scheduleBackgroundProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: "com.rationaledesign.heirloom.video-processing")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false // Allow on battery
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30) // Try in 30 seconds

        do {
            try BGTaskScheduler.shared.submit(request)
            Log.info("Scheduled background processing task", category: .video)
        } catch {
            Log.error("Failed to schedule background task", category: .video, metadata: ["error": error.localizedDescription])
        }
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

        // Get video URL from stored path
        let videoURL = URL(fileURLWithPath: job.videoURL)

        // Verify file exists
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            Log.error("Video file missing when resuming job", category: .video, metadata: [
                "jobId": job.id.uuidString,
                "videoPath": job.videoURL,
                "wasInterrupted": job.wasInterrupted,
                "currentPhase": job.currentPhase.rawValue,
                "checkpoint_resumePhase": job.checkpoint?.resumePhase.rawValue ?? "none"
            ])
            throw VideoProcessingError.videoFileNotFound
        }

        // Process based on video type
        let enhanced: VideoRecipeExtraction.Enhanced

        if job.videoType == .standard {
            enhanced = try await processStandardVideo(
                videoURL: videoURL,
                job: job,
                checkpoint: checkpoint,
                resumePhase: resumePhase,
                context: context
            )
        } else {
            enhanced = try await processASMRVideo(
                videoURL: videoURL,
                job: job,
                checkpoint: checkpoint,
                resumePhase: resumePhase,
                context: context
            )
        }

        // Save enhanced extraction result (includes augmentation data)
        let extractionData = try JSONEncoder().encode(enhanced)
        job.extractionJSON = extractionData
        job.status = .completed
        job.completedAt = Date()
        job.progress = 1.0
        job.currentPhase = .complete

        // Finalize placeholder recipe with extracted data
        finalizePlaceholderRecipe(job: job, extraction: enhanced.original, context: context)

        try context.save()

        // Schedule completion notification
        scheduleCompletionNotification(job, context: context)

        Log.info("Job completed successfully", category: .video, metadata: ["jobId": job.id.uuidString])
    }

    // MARK: - Standard Video Processing

    private func processStandardVideo(
        videoURL: URL,
        job: VideoProcessingJob,
        checkpoint: ProcessingCheckpoint,
        resumePhase: ProcessingPhase,
        context: ModelContext
    ) async throws -> VideoRecipeExtraction.Enhanced {
        // Show loading message if model not yet loaded (first video after app launch)
        if standardProcessor == nil {
            job.currentPhase = .loadingModel
            job.progress = 0.02
            try context.save()
            Log.info("Loading speech recognition model", category: .video, metadata: ["jobId": job.id.uuidString])
        }

        // Get processor instance (will load WhisperKit if needed)
        let processor = await getStandardProcessor(context: context)

        // Model loaded - transition to extracting audio phase
        job.currentPhase = .extractingAudio
        job.progress = 0.05
        try context.save()
        Log.info("Model loaded, starting audio extraction", category: .video, metadata: ["jobId": job.id.uuidString])

        // Delegate to existing processor and monitor progress
        let cancellable = processor.$progress.sink { [weak self] progress in
            Task { @MainActor in
                job.progress = progress
                self?.updatePlaceholderProgress(job: job, progress: progress, context: context)
                try? context.save()
            }
        }

        let subPhaseCancellable = processor.$subPhaseProgress.sink { subProgress in
            Task { @MainActor in
                job.subPhaseProgress = subProgress
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
            subPhaseCancellable.cancel()
            cancellable2.cancel()
        }

        // Process video through existing pipeline (with checkpoint for resume)
        let extraction = try await processor.process(videoURL: videoURL, checkpoint: checkpoint)

        // Return enhanced extraction with augmentation data
        // processor.enhancedExtraction is populated during process() call
        if let enhanced = processor.enhancedExtraction {
            return enhanced
        } else {
            // Fallback: create Enhanced without augmentation
            return VideoRecipeExtraction.Enhanced(
                original: extraction,
                augmentedRecipe: nil,
                similarRecipes: [],
                webRecipes: []
            )
        }
    }

    // MARK: - ASMR Video Processing

    private func processASMRVideo(
        videoURL: URL,
        job: VideoProcessingJob,
        checkpoint: ProcessingCheckpoint,
        resumePhase: ProcessingPhase,
        context: ModelContext
    ) async throws -> VideoRecipeExtraction.Enhanced {
        // Show loading message if model not yet loaded (first video after app launch)
        if asmrProcessor == nil {
            job.currentPhase = .loadingModel
            job.progress = 0.02
            try context.save()
            Log.info("Loading speech recognition model", category: .video, metadata: ["jobId": job.id.uuidString])
        }

        // Get processor instance
        let processor = getASMRProcessor()

        // Model loaded - transition to extracting audio phase
        job.currentPhase = .extractingAudio
        job.progress = 0.05
        try context.save()
        Log.info("Model loaded, starting audio extraction", category: .video, metadata: ["jobId": job.id.uuidString])

        // Monitor progress
        let cancellable = processor.$progress.sink { [weak self] progress in
            Task { @MainActor in
                job.progress = progress
                self?.updatePlaceholderProgress(job: job, progress: progress, context: context)
                try? context.save()
            }
        }

        let subPhaseCancellable = processor.$subPhaseProgress.sink { subProgress in
            Task { @MainActor in
                job.subPhaseProgress = subProgress
                try? context.save()
            }
        }

        // Monitor ASMR processing state and map to job phases
        let stateCancellable = processor.$state.sink { state in
            Task { @MainActor in
                switch state {
                case .idle:
                    break
                case .preparingVideo:
                    job.currentPhase = .extractingAudio
                case .analyzingSounds:
                    job.currentPhase = .transcribing
                case .extractingFrames:
                    job.currentPhase = .analyzingFrames
                case .processingPass:
                    job.currentPhase = .structuringRecipe
                case .completed, .failed, .cancelled:
                    break
                }
                try? context.save()
            }
        }

        defer {
            cancellable.cancel()
            subPhaseCancellable.cancel()
            stateCancellable.cancel()
        }

        job.currentPhase = .extractingAudio
        try context.save()

        // Process through ASMR pipeline
        let extraction = try await processor.process(
            videoURL: videoURL,
            userCaption: job.userCaption ?? "",
            videoHash: nil,
            dishNameHint: job.dishNameHint
        )

        // Return enhanced extraction with augmentation data
        // ASMR processor also populates enhancedExtraction during process()
        if let enhanced = processor.enhancedExtraction {
            return enhanced
        } else {
            // Fallback: create Enhanced without augmentation
            return VideoRecipeExtraction.Enhanced(
                original: extraction,
                augmentedRecipe: nil,
                similarRecipes: [],
                webRecipes: []
            )
        }
    }

    // MARK: - Error Handling

    private func handleJobFailure(
        _ job: VideoProcessingJob,
        error: Error,
        context: ModelContext
    ) async {
        // Classify error type for smart recovery
        let errorType = classifyError(error)

        // Set error info on job
        job.status = .failed
        job.errorType = errorType
        job.errorMessage = getErrorMessage(for: errorType, baseError: error)
        job.completedAt = Date()

        // Mark placeholder recipe as failed
        let errorMessage = job.errorMessage ?? "Processing failed"
        markPlaceholderFailed(job: job, errorMessage: errorMessage, context: context)

        Log.error("Job processing failed", category: .video, metadata: [
            "jobId": job.id.uuidString,
            "errorType": errorType.rawValue,
            "errorMessage": job.errorMessage ?? "unknown"
        ])

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
        scheduleFailureNotification(job, context: context)
    }

    /// Classify error type for contextual recovery options
    private func classifyError(_ error: Error) -> ProcessingErrorType {
        let description = error.localizedDescription.lowercased()

        // Check for JSON/AI parsing errors FIRST - these should NOT trigger ASMR recommendation
        // These are backend failures, not audio issues
        if description.contains("decode json") ||
           description.contains("json decoding") ||
           description.contains("parsing failed") ||
           description.contains("invalid json") ||
           description.contains("couldn't be read") ||
           description.contains("data is missing") {
            return .other
        }

        // Check for file not found errors
        if description.contains("not found") ||
           description.contains("no such file") ||
           description.contains("file does not exist") ||
           error is VideoProcessingError && error as? VideoProcessingError == .videoFileNotFound {
            return .fileNotFound
        }

        // Check for permission errors
        if description.contains("permission") ||
           description.contains("not authorized") ||
           description.contains("access denied") {
            return .permissionDenied
        }

        // Check for audio/transcription errors - only after ruling out JSON/parsing errors
        // These indicate the video lacks clear narration and ASMR might help
        if description.contains("no audio") ||
           description.contains("transcription failed") ||
           description.contains("insufficient audio") ||
           description.contains("silent") ||
           description.contains("no speech") ||
           description.contains("narration") ||
           description.contains("unclear speech") ||
           description.contains("too short") {
            return .insufficientAudioData
        }

        // Default to generic error
        return .other
    }

    /// Generate user-friendly error message based on error type
    private func getErrorMessage(for errorType: ProcessingErrorType, baseError: Error) -> String {
        switch errorType {
        case .insufficientAudioData:
            return "Could not extract audio from video. This video appears to be silent or have unclear narration."

        case .fileNotFound:
            return "Video file could not be accessed. It may be stored in iCloud and not downloaded."

        case .permissionDenied:
            return "Permission denied accessing video. Please check app permissions in Settings."

        case .other:
            return baseError.localizedDescription
        }
    }

    /// Handle recovery action from JobRecoverySheet
    func handleRecoveryAction(for job: VideoProcessingJob, action: RecoveryAction, context: ModelContext) async throws {
        switch action {
        case .tryASMRMode(let dishName):
            // Verify error type is audio-related
            guard job.errorType == .insufficientAudioData else {
                throw RecoveryError.invalidRecoveryAction
            }

            // Check ASMR credits
            guard usageManager.canStartExtraction() else {
                throw RecoveryError.insufficientCredits
            }

            // Get video URL
            let videoURL = URL(fileURLWithPath: job.videoURL)

            // Re-queue as ASMR job
            let attribution = VideoSourceAttribution(
                sourceURL: job.sourceURL,
                captionText: job.userCaption
            )

            _ = try createJob(
                videoURL: videoURL,
                videoType: .asmr,
                userCaption: dishName,
                videoDuration: job.videoDuration,
                sourceAttribution: attribution,
                context: context
            )

            // Delete old failed job
            context.delete(job)
            try context.save()

            // Show success toast
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            toastManager.info(
                title: "Retrying with ASMR Mode",
                message: "Using vision-based analysis (5 credits)"
            )

            Log.info("Job converted to ASMR mode", category: .video, metadata: [
                "originalJobId": job.id.uuidString
            ])

        case .retry:
            // Reset job status and retry with same mode
            job.status = .pending
            job.errorMessage = nil
            job.errorType = nil
            job.progress = 0.0
            job.currentPhase = .queued
            try context.save()

            refreshQueue(context: context)

            // Re-process job
            try await startNextJob(context: context)

            Log.info("Job retry initiated from recovery", category: .video, metadata: [
                "jobId": job.id.uuidString
            ])

        case .cancel:
            // Delete job and its video file
            try deleteJob(job, context: context)

            Log.info("User cancelled failed job", category: .video, metadata: [
                "jobId": job.id.uuidString
            ])

        case .startOver:
            // Delete failed job and video file so user can re-import
            try deleteJob(job, context: context)

            // Show helpful message
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            toastManager.info(
                title: "Job Cleared",
                message: "You can now re-import your video"
            )

            Log.info("User cleared failed job to start over", category: .video, metadata: [
                "jobId": job.id.uuidString
            ])
        }
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

    /// Resume a paused or interrupted job
    func resumeJob(_ job: VideoProcessingJob, context: ModelContext) async throws {
        // Handle paused jobs
        if job.status == .paused {
            job.status = .pending
            try context.save()
            refreshQueue(context: context)
            try await startNextJob(context: context)
            return
        }

        // Handle interrupted jobs (force-quit resume)
        if job.wasInterrupted && (job.status == .pending || job.status == .processing) {
            Log.info("Resuming interrupted job from checkpoint", category: .video, metadata: [
                "job_id": job.id.uuidString,
                "status": job.status.rawValue,
                "has_checkpoint": job.checkpoint != nil
            ])

            // Clear interrupted flag
            job.wasInterrupted = false
            job.interruptedAt = nil

            // Ensure status is pending so it gets picked up by queue
            job.status = .pending
            try context.save()

            refreshQueue(context: context)

            // Start processing
            try await startNextJob(context: context)
            return
        }

        // Job is not in a resumable state
        Log.warning("Cannot resume job - not paused or interrupted", category: .video, metadata: [
            "job_id": job.id.uuidString,
            "status": job.status.rawValue,
            "was_interrupted": job.wasInterrupted
        ])
    }

    /// Cancel a job
    func cancelJob(_ job: VideoProcessingJob, context: ModelContext) throws {
        guard job.canCancel else { return }

        // Delete the video file to free up storage
        deleteVideoFile(for: job)

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

    /// Delete a job completely (including video file)
    func deleteJob(_ job: VideoProcessingJob, context: ModelContext) throws {
        // Delete the video file first
        deleteVideoFile(for: job)

        // If this is the active job, stop processing
        if activeJob?.id == job.id {
            isProcessing = false
            activeJob = nil
        }

        // Delete from SwiftData
        context.delete(job)
        try context.save()

        refreshQueue(context: context)

        Log.info("Job deleted with video file cleanup", category: .video, metadata: ["jobId": job.id.uuidString])
    }

    /// Delete the video file associated with a job
    private func deleteVideoFile(for job: VideoProcessingJob) {
        let videoURL = URL(fileURLWithPath: job.videoURL)

        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            Log.debug("Video file already deleted or doesn't exist", category: .video, metadata: [
                "jobId": job.id.uuidString,
                "path": job.videoURL
            ])
            return
        }

        do {
            try FileManager.default.removeItem(at: videoURL)
            Log.info("Deleted video file for job", category: .video, metadata: [
                "jobId": job.id.uuidString,
                "path": job.videoURL
            ])
        } catch {
            Log.warning("Failed to delete video file", category: .video, metadata: [
                "jobId": job.id.uuidString,
                "path": job.videoURL,
                "error": error.localizedDescription
            ])
        }
    }

    /// Retry a failed job
    func retryJob(_ job: VideoProcessingJob, context: ModelContext) async throws {
        guard job.canRetry else {
            throw VideoProcessingError.maxRetriesExceeded
        }

        // Verify video file still exists before retrying
        let videoURL = URL(fileURLWithPath: job.videoURL)
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            throw VideoProcessingError.videoFileNotFound
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

    /// Save recipe from completed job
    /// Uses the placeholder recipe created at job start (progressive enhancement)
    func saveRecipeFromJob(_ job: VideoProcessingJob, context: ModelContext) throws -> Recipe {
        // STEP 1: Verify job is completed
        guard job.status == .completed else {
            throw VideoProcessingError.invalidJobState
        }

        // STEP 2: Deserialize extraction JSON
        guard let jsonData = job.extractionJSON else {
            throw VideoProcessingError.noExtractionData
        }

        // Try to decode as Enhanced first (new format), fall back to base extraction (old format)
        let recipeToSave: StructuredRecipe
        let extraction: VideoRecipeExtraction

        if let enhanced = try? JSONDecoder().decode(VideoRecipeExtraction.Enhanced.self, from: jsonData) {
            // Use finalRecipe which merges augmented quantities/units into the recipe
            recipeToSave = enhanced.finalRecipe
            extraction = enhanced.original
        } else {
            // Fall back to base extraction
            extraction = try JSONDecoder().decode(VideoRecipeExtraction.self, from: jsonData)
            recipeToSave = extraction.structuredRecipe
        }

        // STEP 3: Find or create recipe
        // With progressive enhancement, we already have a placeholder recipe
        let recipe: Recipe
        if let placeholderRecipeId = job.placeholderRecipeID,
           let placeholder = try? context.fetch(FetchDescriptor<Recipe>(
               predicate: #Predicate { $0.id == placeholderRecipeId }
           )).first {
            // Use existing placeholder recipe
            recipe = placeholder
            Log.info("Using existing placeholder recipe for save", category: .video, metadata: [
                "placeholderRecipeId": placeholderRecipeId.uuidString
            ])
        } else {
            // Fallback: Create new recipe if no placeholder (shouldn't happen normally)
            recipe = Recipe(
                title: recipeToSave.title,
                sourceType: .video,
                instructions: recipeToSave.steps.map { $0.instruction },
                servings: recipeToSave.servings
            )
            context.insert(recipe)
            Log.warning("No placeholder recipe found, created new recipe", category: .video, metadata: [
                "jobId": job.id.uuidString
            ])
        }

        // STEP 4: Update recipe with final data (may include user edits from review screen)
        recipe.title = recipeToSave.title
        recipe.instructions = recipeToSave.steps.map { $0.instruction }
        recipe.servings = recipeToSave.servings
        recipe.processingStatus = .ready
        recipe.processingProgress = 1.0
        recipe.linkedProcessingJobId = nil
        recipe.linkedProcessingJobType = nil

        // STEP 5: Set provenance metadata
        recipe.provenance = ProvenanceMetadata(
            sourceType: .video,
            sourceURL: job.sourceURL,
            sourceAttribution: job.sourceAttribution ?? extraction.metadata.attribution.creatorName,
            generation: 0,
            sharedByName: nil,
            createdAt: Date()
        )

        // STEP 6: Update ingredients (remove old ones first, then add new)
        // Clear existing ingredients
        if let existingIngredients = recipe.ingredients {
            for ing in existingIngredients {
                context.delete(ing)
            }
        }
        recipe.ingredients = []

        // Add ingredients from extraction/review
        for (index, ingredient) in recipeToSave.ingredients.enumerated() {
            let quantityDouble = parseQuantityString(ingredient.quantity)

            let ing = Ingredient(
                originalText: ingredient.originalText,
                name: ingredient.item,
                quantity: quantityDouble,
                unit: ingredient.unit,
                orderIndex: index
            )
            ing.recipe = recipe
            context.insert(ing)
        }

        // Create snapshot for edit tracking
        recipe.createSnapshot()

        try context.save()

        Log.info("Recipe saved from job", category: .video, metadata: [
            "jobId": job.id.uuidString,
            "recipeId": recipe.id.uuidString,
            "recipeTitle": recipe.title
        ])

        // STEP 7: Route to "From Videos" collection
        let router = CollectionRouter(modelContext: context)
        router.routeVideoImport(recipe)

        // STEP 8: Update job status
        job.status = .saved
        job.recipeID = recipe.id
        try context.save()

        // STEP 9: Delete video file to free up storage (no longer needed after saving)
        deleteVideoFile(for: job)

        // STEP 10: Refresh queue to remove from active list
        refreshQueue(context: context)

        // STEP 11: Show toast confirmation
        let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
        toastManager.success(
            title: "Recipe Saved",
            message: recipe.title
        )

        return recipe
    }

    /// Parse string quantity to Double, handling fractions like "1/4", "1 1/2", "¼"
    private func parseQuantityString(_ quantityString: String?) -> Double? {
        guard let quantityString = quantityString?.trimmingCharacters(in: .whitespaces),
              !quantityString.isEmpty else {
            return nil
        }

        // Use IngredientParser to parse a fake ingredient text with just the quantity
        // This leverages existing fraction parsing logic
        let fakeIngredient = "\(quantityString) item"
        let parsed = IngredientParser.parse(fakeIngredient)
        return parsed.quantity
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
            // Only mark as crashed if job started more than 5 minutes ago (prevents race condition)
            let crashThreshold: TimeInterval = 300 // 5 minutes
            for job in jobs where job.status == .processing {
                let timeSinceStart = Date().timeIntervalSince(job.startedAt ?? job.createdAt)
                if timeSinceStart > crashThreshold {
                    Log.info("Found crashed job, marking as pending", category: .video, metadata: [
                        "jobId": job.id.uuidString,
                        "phase": job.currentPhase.displayName,
                        "timeSinceStart": "\(Int(timeSinceStart))s"
                    ])
                    job.status = .pending
                } else {
                    Log.debug("Job recently started, not marking as crashed", category: .video, metadata: [
                        "jobId": job.id.uuidString,
                        "timeSinceStart": "\(Int(timeSinceStart))s"
                    ])
                }
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

    // MARK: - Badge Management

    /// Get count of jobs that need user attention (completed or failed)
    private func getJobsNeedingAttentionCount(context: ModelContext) -> Int {
        // Fetch all jobs and filter in code (Predicate macro doesn't support enum comparisons well)
        let descriptor = FetchDescriptor<VideoProcessingJob>()

        do {
            let allJobs = try context.fetch(descriptor)

            // Filter for jobs needing attention
            let jobsNeedingAttention = allJobs.filter { job in
                job.status == .completed || job.status == .failed
            }

            return jobsNeedingAttention.count
        } catch {
            Log.error("Failed to fetch jobs for badge count", category: .video, metadata: [
                "error": error.localizedDescription
            ])
            return 0
        }
    }

    // MARK: - Notifications

    private func scheduleCompletionNotification(_ job: VideoProcessingJob, context: ModelContext) {
        let content = UNMutableNotificationContent()
        content.title = "Your recipe is ready!"
        content.body = "Tap to review and save your extracted recipe."
        content.sound = .default
        content.categoryIdentifier = "VIDEO_PROCESSING_COMPLETE"
        content.userInfo = ["jobId": job.id.uuidString]

        // Update app badge with count of jobs ready to review
        content.badge = NSNumber(value: getJobsNeedingAttentionCount(context: context))

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

    private func scheduleFailureNotification(_ job: VideoProcessingJob, context: ModelContext) {
        let content = UNMutableNotificationContent()
        content.title = "Video processing failed"
        content.body = job.canRetry ? "Tap to retry or view error details." : "Tap to view error details."
        content.sound = .default
        content.categoryIdentifier = "VIDEO_PROCESSING_FAILED"
        content.userInfo = ["jobId": job.id.uuidString]

        // Update app badge with count of jobs needing attention
        content.badge = NSNumber(value: getJobsNeedingAttentionCount(context: context))

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

    // MARK: - Placeholder Recipe Updates

    /// Update the placeholder recipe's progress during processing
    private func updatePlaceholderProgress(
        job: VideoProcessingJob,
        progress: Double,
        context: ModelContext
    ) {
        guard let placeholderRecipeId = job.placeholderRecipeID else { return }

        let descriptor = FetchDescriptor<Recipe>(predicate: #Predicate { $0.id == placeholderRecipeId })
        guard let placeholder = try? context.fetch(descriptor).first else { return }

        placeholder.processingProgress = progress

        // Update title based on phase
        switch job.currentPhase {
        case .queued:
            placeholder.title = "Waiting to process..."
        case .loadingModel:
            placeholder.title = "Loading AI model..."
        case .extractingAudio:
            placeholder.title = "Extracting audio..."
        case .transcribing:
            placeholder.title = "Transcribing recipe..."
        case .analyzingFrames:
            placeholder.title = "Analyzing video..."
        case .structuringRecipe:
            placeholder.title = "Creating recipe..."
        case .augmenting:
            placeholder.title = "Enhancing recipe..."
        case .complete:
            break // Will be updated with actual title
        }
    }

    /// Finalize placeholder recipe with extracted data
    private func finalizePlaceholderRecipe(
        job: VideoProcessingJob,
        extraction: VideoRecipeExtraction,
        context: ModelContext
    ) {
        guard let placeholderRecipeId = job.placeholderRecipeID else { return }

        let descriptor = FetchDescriptor<Recipe>(predicate: #Predicate { $0.id == placeholderRecipeId })
        guard let placeholder = try? context.fetch(descriptor).first else { return }

        let recipe = extraction.structuredRecipe

        // Convert steps to instructions array
        let instructions = recipe.steps.map { $0.instruction }

        // Update with extracted data
        placeholder.updateFromProcessingResult(
            title: recipe.title,
            instructions: instructions,
            servings: recipe.servings,
            prepTime: recipe.prepTime,
            cookTime: recipe.cookTime,
            notes: recipe.description
        )

        // Add ingredients
        placeholder.ingredients = recipe.ingredients.map { ingredient in
            // Parse quantity string to Double if possible
            let quantityDouble: Double?
            if let quantityStr = ingredient.quantity {
                quantityDouble = Double(quantityStr)
            } else {
                quantityDouble = nil
            }

            let parsedIngredient = Ingredient(
                originalText: ingredient.originalText,
                name: ingredient.item,
                quantity: quantityDouble,
                unit: ingredient.unit
            )
            parsedIngredient.recipe = placeholder
            return parsedIngredient
        }

        Log.info("Finalized placeholder recipe from video extraction", category: .video, metadata: [
            "jobId": job.id.uuidString,
            "title": recipe.title
        ])
    }

    /// Mark placeholder recipe as failed
    private func markPlaceholderFailed(
        job: VideoProcessingJob,
        errorMessage: String,
        context: ModelContext
    ) {
        guard let placeholderRecipeId = job.placeholderRecipeID else { return }

        let descriptor = FetchDescriptor<Recipe>(predicate: #Predicate { $0.id == placeholderRecipeId })
        guard let placeholder = try? context.fetch(descriptor).first else { return }

        placeholder.markProcessingFailed(errorMessage: errorMessage)
    }

    // MARK: - Thumbnail Generation

    /// Generate a thumbnail from a video file
    private func generateThumbnail(from url: URL) async -> Data? {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 600, height: 600)

        do {
            // Generate thumbnail at 1 second into the video
            let time = CMTime(seconds: 1.0, preferredTimescale: 600)
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)

            // Convert to JPEG data
            return uiImage.jpegData(compressionQuality: 0.8)
        } catch {
            Log.warning("Failed to generate thumbnail", category: .video, metadata: [
                "url": url.path,
                "error": error.localizedDescription
            ])
            return nil
        }
    }
}

// MARK: - Errors

enum VideoProcessingError: LocalizedError {
    case invalidVideoURL
    case videoFileNotFound
    case maxRetriesExceeded
    case jobNotFound
    case processingInProgress
    case invalidJobState
    case noExtractionData

    var errorDescription: String? {
        switch self {
        case .invalidVideoURL:
            return "Invalid video URL"
        case .videoFileNotFound:
            return "Video file not found"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        case .jobNotFound:
            return "Job not found"
        case .processingInProgress:
            return "Processing already in progress"
        case .invalidJobState:
            return "Job is not in completed state"
        case .noExtractionData:
            return "No extraction data available for this job"
        }
    }
}

enum RecoveryAction {
    case tryASMRMode(dishName: String)
    case retry
    case cancel
    case startOver  // Delete failed job and let user re-import
}

enum RecoveryError: LocalizedError {
    case insufficientCredits
    case invalidRecoveryAction

    var errorDescription: String? {
        switch self {
        case .insufficientCredits:
            return "You need 5 credits to use ASMR mode."
        case .invalidRecoveryAction:
            return "This recovery action is not available for this error type."
        }
    }
}
