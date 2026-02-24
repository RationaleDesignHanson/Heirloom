//
//  ASMRVideoProcessor.swift
//  Heirloom
//
//  Created by Claude on 1/10/26.
//

import Foundation
import AVFoundation
import Combine
import UIKit
import SwiftData

/// Main coordinator for ASMR video processing pipeline
@MainActor
class ASMRVideoProcessor: ObservableObject, ASMRProcessorProtocol {

    // MARK: - Published State

    @Published private(set) var state: ASMRProcessingState = .idle
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var currentPass: ASMRProcessingPass?
    @Published var subPhaseProgress: Double = 0.0

    /// Enhanced extraction with augmentation data (for review screen)
    @Published var enhancedExtraction: VideoRecipeExtraction.Enhanced?

    // MARK: - Dependencies

    private let soundAnalyzer: ASMRSoundAnalysisService
    private let frameExtractor: ASMRFrameExtractionService
    private let structurer: ASMRRecipeStructurer
    private let cacheService: ASMRCacheService
    private let aiService: (any AIServiceProtocol)?  // For watermark detection

    // MARK: - Cancellation

    private var processingTask: Task<ASMRRecipeExtraction, Error>?
    private let progressInterpolator = ProgressInterpolator()

    /// Estimated durations for ASMR processing passes
    private enum PassDuration {
        static let soundAnalysis: TimeInterval = 10
        static let frameExtraction: TimeInterval = 15
        static let identifying: TimeInterval = 20    // Pass 1: 15%
        static let detecting: TimeInterval = 30      // Pass 2: 25%
        static let inferring: TimeInterval = 30      // Pass 3: 25%
        static let analyzing: TimeInterval = 25      // Pass 4: 20%
        static let validating: TimeInterval = 20     // Pass 5: 15%

        static func forPass(_ pass: ASMRProcessingPass) -> TimeInterval {
            switch pass {
            case .identifying: return identifying
            case .detecting: return detecting
            case .inferring: return inferring
            case .analyzing: return analyzing
            case .validating: return validating
            }
        }
    }

    // MARK: - Initialization

    init(
        soundAnalyzer: ASMRSoundAnalysisService? = nil,
        frameExtractor: ASMRFrameExtractionService? = nil,
        structurer: ASMRRecipeStructurer? = nil,
        cacheService: ASMRCacheService? = nil,
        aiService: (any AIServiceProtocol)? = nil,
        modelContext: ModelContext? = nil
    ) {
        self.soundAnalyzer = soundAnalyzer ?? ASMRSoundAnalysisService()
        self.frameExtractor = frameExtractor ?? ASMRFrameExtractionService()
        self.structurer = structurer ?? ASMRRecipeStructurer(modelContext: modelContext)
        self.cacheService = cacheService ?? ASMRCacheService.shared
        self.aiService = aiService ?? ServiceContainer.shared.resolve((any AIServiceProtocol).self)
    }

    // MARK: - Public API

    /// Process ASMR video to extract recipe
    /// Note: Credit handling is done by callers (VideoProcessingJobManager), not here
    func process(
        videoURL: URL,
        userCaption: String,
        videoHash: String?,
        skipSoundAnalysis: Bool = false,
        dishNameHint: String? = nil
    ) async throws -> ASMRRecipeExtraction {
        do {
            let result = try await processInternal(
                videoURL: videoURL,
                userCaption: userCaption,
                videoHash: videoHash,
                skipSoundAnalysis: skipSoundAnalysis,
                dishNameHint: dishNameHint
            )
            return result
        } catch {
            // Disable keep-alive on error
            await disableKeepAlive()
            throw error
        }
    }

    func cancel() {
        progressInterpolator.stop()
        processingTask?.cancel()
        state = .cancelled
        progress = 0.0
        subPhaseProgress = 0.0
        currentPass = nil
    }

    // MARK: - Private Processing

    private func processInternal(
        videoURL: URL,
        userCaption: String,
        videoHash: String?,
        skipSoundAnalysis: Bool,
        dishNameHint: String? = nil
    ) async throws -> ASMRRecipeExtraction {

        // Enable keep-alive to prevent screen sleep during processing
        await enableKeepAlive()

        let hash: String
        if let videoHash = videoHash {
            hash = videoHash
        } else {
            hash = try await cacheService.computeHash(for: videoURL)
        }

        // Step 1: Check cache (5%)
        progress = 0.05
        state = .preparingVideo(progress: progress)

        if let cached = try? await cacheService.getCachedASMRExtraction(hash: hash) {
            state = .completed(cached)
            progress = 1.0
            await disableKeepAlive()
            return cached
        }

        // Step 2: Verify suitability (10% or instant if skipped)
        state = .analyzingSounds(progress: 0.0)
        subPhaseProgress = 0.0
        progressInterpolator.start(from: 0.05, to: 0.10, duration: PassDuration.soundAnalysis)

        let soundAnalysis = try await soundAnalyzer.analyzeSuitability(
            videoURL: videoURL,
            skipAnalysis: skipSoundAnalysis
        )

        guard soundAnalysis.suitable else {
            throw ASMRProcessingError.unsuitable(reason: soundAnalysis.reasoning)
        }

        progressInterpolator.snap(to: 0.10)
        progress = 0.10
        subPhaseProgress = 1.0

        // Step 3: Extract frames (20%)
        state = .extractingFrames(progress: 0.0)
        subPhaseProgress = 0.0
        progressInterpolator.start(from: 0.10, to: 0.20, duration: PassDuration.frameExtraction)

        let frames = try await frameExtractor.extractFrames(from: videoURL)

        guard frames.totalFrames >= 15 else {
            throw ASMRProcessingError.insufficientFrames
        }

        // Step 3.5: Detect creator watermark (optional, non-blocking)
        var detectedWatermark: WatermarkDetectionResult? = nil
        if let aiService = aiService {
            let watermarkService = WatermarkDetectionService(aiService: aiService)

            // Use first 3 frames like regular video flow
            let framesToAnalyze = Array(frames.allFrames.prefix(3).map { $0.image })

            do {
                detectedWatermark = try await watermarkService.detectWatermark(from: framesToAnalyze)

                if let watermark = detectedWatermark {
                    Log.info("Detected watermark in ASMR video", category: .general, metadata: [
                        "creator": watermark.creatorHandle ?? "unknown",
                        "platform": watermark.platform?.rawValue ?? "unknown",
                        "confidence": watermark.confidence
                    ])
                }
            } catch {
                // Non-critical - continue without watermark
                Log.warning("Failed to detect watermark", category: .general, metadata: ["error": error.localizedDescription])
            }
        }

        progressInterpolator.snap(to: 0.20)
        progress = 0.20
        subPhaseProgress = 1.0

        // Step 4: 5-pass processing (20% → 95%)
        var passCancellables: [AnyCancellable] = []

        let extraction = try await structurer.structure(
            frames: frames,
            userCaption: userCaption,
            dishNameHint: dishNameHint,
            progressHandler: { [weak self] pass, findings in
                Task { @MainActor in
                    guard let self = self else { return }

                    self.currentPass = pass
                    self.state = .processingPass(pass, findings: findings)

                    // Calculate progress range for this pass
                    let baseProgress = ASMRProcessingPass.allCases
                        .prefix(pass.rawValue)
                        .reduce(0.0) { $0 + $1.progressWeight }
                    let passStartProgress = 0.20 + baseProgress * 0.75
                    let passEndProgress = passStartProgress + (pass.progressWeight * 0.75)

                    // Start interpolation for this pass
                    self.subPhaseProgress = 0.0
                    self.progressInterpolator.start(
                        from: passStartProgress,
                        to: passEndProgress,
                        duration: PassDuration.forPass(pass)
                    )

                    // Subscribe to interpolator updates
                    let cancellable = self.progressInterpolator.$interpolatedProgress
                        .sink { interpolated in
                            Task { @MainActor in
                                self.progress = interpolated
                                // Calculate sub-phase progress within this pass
                                let passRange = passEndProgress - passStartProgress
                                self.subPhaseProgress = (interpolated - passStartProgress) / passRange
                            }
                        }
                    passCancellables.append(cancellable)
                }
            }
        )

        // Clean up pass cancellables
        passCancellables.forEach { $0.cancel() }
        progressInterpolator.snap(to: 0.95)
        progress = 0.95
        subPhaseProgress = 1.0

        // Step 5: Finalize & update metadata (100%)
        // Add sound analysis results to metadata notes
        var metadata = extraction.metadata
        var notes = metadata.attribution.notes ?? ""
        notes += "\nSound: \(soundAnalysis.hasSpeech ? "Speech detected" : "No speech")"
        if soundAnalysis.hasMusic { notes += ", Music present" }

        // Add detected watermark info
        if let watermark = detectedWatermark {
            metadata.attribution.creatorName = watermark.creatorHandle
            metadata.attribution.platform = watermark.platform

            if let creator = watermark.creatorHandle {
                notes += "\nCreator detected from video: \(creator)"
            }
        }

        metadata.attribution.notes = notes

        // Update metadata with actual video duration
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration).seconds
        var updatedMetadata = metadata
        updatedMetadata.videoDuration = duration

        let finalExtraction = VideoRecipeExtraction(
            structuredRecipe: extraction.structuredRecipe,
            transcript: extraction.transcript,
            visualElements: extraction.visualElements,
            metadata: updatedMetadata,
            processingTime: extraction.processingTime,
            estimatedCost: extraction.estimatedCost
        )

        // Create enhanced extraction with augmentation data
        let enhanced = VideoRecipeExtraction.Enhanced(
            original: finalExtraction,
            augmentedRecipe: structurer.lastAugmentedRecipe,
            similarRecipes: [],  // ASMR doesn't use similar recipes
            webRecipes: []       // ASMR doesn't use web recipes
        )

        // Store enhanced extraction for review screen access
        self.enhancedExtraction = enhanced

        // Cache result
        try? await cacheService.cacheASMRExtraction(finalExtraction, hash: hash)

        state = .completed(finalExtraction)
        progress = 1.0

        // Disable screen sleep prevention if it was enabled
        await disableKeepAlive()

        return finalExtraction
    }

    // MARK: - Foreground Processing with Keep-Alive

    /// Enable keep-alive to prevent screen sleep during processing
    private func enableKeepAlive() async {
        await MainActor.run {
            UIApplication.shared.isIdleTimerDisabled = true
        }

        // Set up notification if app enters background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleCompletionNotification()
        }
    }

    /// Disable keep-alive after processing completes
    private func disableKeepAlive() async {
        await MainActor.run {
            UIApplication.shared.isIdleTimerDisabled = false
        }

        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    /// Schedule local notification if processing completes while backgrounded
    nonisolated private func scheduleCompletionNotification() {
        // TODO: Implement local notification
        // Would use UNUserNotificationCenter to notify user when done
        // "Recipe extraction complete! Tap to review."
    }
}

// MARK: - ASMR Cache Service

/// Simple cache service for ASMR extraction results
@MainActor
class ASMRCacheService {
    static let shared = ASMRCacheService()

    init() {}

    /// Compute hash for video file
    func computeHash(for videoURL: URL) async throws -> String {
        // Use file path and modification date for hash
        let attributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
        let modificationDate = attributes[.modificationDate] as? Date ?? Date()
        let hashString = "\(videoURL.lastPathComponent)_\(modificationDate.timeIntervalSince1970)"

        // Create SHA256-like hash from string
        return hashString.data(using: .utf8)?.base64EncodedString() ?? hashString
    }

    /// Cache ASMR extraction result to disk
    func cacheASMRExtraction(_ extraction: ASMRRecipeExtraction, hash: String) async throws {
        let cacheDir = try getCacheDirectory()
        let fileURL = cacheDir.appendingPathComponent("\(hash).json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(extraction)

        try data.write(to: fileURL, options: .atomic)
    }

    /// Retrieve cached ASMR extraction from disk
    func getCachedASMRExtraction(hash: String) async throws -> ASMRRecipeExtraction? {
        let cacheDir = try getCacheDirectory()
        let fileURL = cacheDir.appendingPathComponent("\(hash).json")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ASMRRecipeExtraction.self, from: data)
    }

    /// Clear all cached extractions
    func clearCache() throws {
        let cacheDir = try getCacheDirectory()
        let contents = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)

        for fileURL in contents {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Private Helpers

    private func getCacheDirectory() throws -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let asmrDir = cacheDir.appendingPathComponent("ASMR")

        if !FileManager.default.fileExists(atPath: asmrDir.path) {
            try FileManager.default.createDirectory(at: asmrDir, withIntermediateDirectories: true)
        }

        return asmrDir
    }
}
