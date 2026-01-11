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

/// Main coordinator for ASMR video processing pipeline
@MainActor
class ASMRVideoProcessor: ObservableObject, ASMRProcessorProtocol {

    // MARK: - Published State

    @Published private(set) var state: ASMRProcessingState = .idle
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var currentPass: ASMRProcessingPass?

    /// Enhanced extraction with augmentation data (for review screen)
    @Published var enhancedExtraction: VideoRecipeExtraction.Enhanced?

    // MARK: - Dependencies

    private let soundAnalyzer: ASMRSoundAnalysisService
    private let frameExtractor: ASMRFrameExtractionService
    private let structurer: ASMRRecipeStructurer
    private let usageManager: ASMRUsageManager
    private let cacheService: ASMRCacheService
    private let aiService: AnthropicAIService?  // For watermark detection

    // MARK: - Cancellation

    private var processingTask: Task<ASMRRecipeExtraction, Error>?

    // MARK: - Initialization

    init(
        soundAnalyzer: ASMRSoundAnalysisService? = nil,
        frameExtractor: ASMRFrameExtractionService? = nil,
        structurer: ASMRRecipeStructurer? = nil,
        usageManager: ASMRUsageManager? = nil,
        cacheService: ASMRCacheService? = nil,
        aiService: AnthropicAIService? = nil
    ) {
        self.soundAnalyzer = soundAnalyzer ?? ASMRSoundAnalysisService()
        self.frameExtractor = frameExtractor ?? ASMRFrameExtractionService()
        self.structurer = structurer ?? ASMRRecipeStructurer()
        self.usageManager = usageManager ?? ASMRUsageManager.shared
        self.cacheService = cacheService ?? ASMRCacheService.shared
        self.aiService = aiService ?? ServiceContainer.shared.resolve(AnthropicAIService.self)
    }

    // MARK: - Public API

    func process(
        videoURL: URL,
        userCaption: String,
        videoHash: String?,
        skipSoundAnalysis: Bool = false
    ) async throws -> ASMRRecipeExtraction {

        // Check credit availability
        guard usageManager.canStartExtraction() else {
            throw ASMRUsageError.insufficientCredits(
                needed: 5,
                available: usageManager.creditsRemaining
            )
        }

        // Deduct credits upfront
        try usageManager.startExtraction()

        do {
            let result = try await processInternal(
                videoURL: videoURL,
                userCaption: userCaption,
                videoHash: videoHash,
                skipSoundAnalysis: skipSoundAnalysis
            )
            return result
        } catch {
            // Disable keep-alive on error
            await disableKeepAlive()
            // Refund credits on failure
            usageManager.refundExtraction()
            throw error
        }
    }

    func cancel() {
        processingTask?.cancel()
        state = .cancelled
        progress = 0.0
        currentPass = nil
    }

    // MARK: - Private Processing

    private func processInternal(
        videoURL: URL,
        userCaption: String,
        videoHash: String?,
        skipSoundAnalysis: Bool
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
        let soundAnalysis = try await soundAnalyzer.analyzeSuitability(
            videoURL: videoURL,
            skipAnalysis: skipSoundAnalysis
        )

        guard soundAnalysis.suitable else {
            throw ASMRProcessingError.unsuitable(reason: soundAnalysis.reasoning)
        }

        progress = 0.10

        // Step 3: Extract frames (20%)
        state = .extractingFrames(progress: 0.0)
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

        progress = 0.20

        // Step 4: 5-pass processing (20% → 95%)
        let extraction = try await structurer.structure(
            frames: frames,
            userCaption: userCaption,
            progressHandler: { [weak self] pass, findings in
                Task { @MainActor in
                    guard let self = self else { return }

                    self.currentPass = pass
                    self.state = .processingPass(pass, findings: findings)

                    // Calculate progress based on pass weights
                    let passProgress = ASMRProcessingPass.allCases
                        .prefix(pass.rawValue + 1)
                        .reduce(0.0) { $0 + $1.progressWeight }
                    self.progress = 0.20 + (passProgress * 0.75)
                }
            }
        )

        progress = 0.95

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
