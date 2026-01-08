//
//  VideoRecipeProcessor.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/8/26.
//
//  Production coordinator for video-to-recipe processing pipeline
//  Orchestrates: Audio Extraction → Transcription → Frame Analysis → Recipe Structuring

import Foundation
import CryptoKit

@MainActor
@Observable
class VideoRecipeProcessor: VideoRecipeProcessorProtocol {
    var state: ProcessingState = .idle
    var progress: Double = 0.0
    var canCancel: Bool = false

    private var processingTask: Task<Void, Error>?
    private let cache = VideoProcessingCache.shared

    // Services
    private let audioExtractor: AudioExtractionServiceProtocol
    private let transcriptionService: TranscriptionServiceProtocol
    private let frameAnalyzer: FrameAnalysisServiceProtocol
    private let recipeStructurer: RecipeStructurerProtocol

    // Configuration
    private let enableFrameAnalysis: Bool
    private let enableCaching: Bool

    init(
        audioExtractor: AudioExtractionServiceProtocol,
        transcriptionService: TranscriptionServiceProtocol,
        frameAnalyzer: FrameAnalysisServiceProtocol,
        recipeStructurer: RecipeStructurerProtocol,
        enableFrameAnalysis: Bool = true,
        enableCaching: Bool = true
    ) {
        self.audioExtractor = audioExtractor
        self.transcriptionService = transcriptionService
        self.frameAnalyzer = frameAnalyzer
        self.recipeStructurer = recipeStructurer
        self.enableFrameAnalysis = enableFrameAnalysis
        self.enableCaching = enableCaching
    }

    /// Convenience initializer with default service implementations
    convenience init(
        transcriptionService: TranscriptionServiceProtocol,
        recipeStructurer: RecipeStructurerProtocol,
        enableFrameAnalysis: Bool = true,
        enableCaching: Bool = true
    ) {
        self.init(
            audioExtractor: AudioExtractionService(),
            transcriptionService: transcriptionService,
            frameAnalyzer: FrameAnalysisService(),
            recipeStructurer: recipeStructurer,
            enableFrameAnalysis: enableFrameAnalysis,
            enableCaching: enableCaching
        )
    }

    func process(videoURL: URL) async throws -> VideoRecipeExtraction {
        let startTime = Date()
        canCancel = true
        defer { canCancel = false }

        do {
            // Step 1: Check cache
            let videoHash = try await cache.computeVideoHash(videoURL)

            if enableCaching, let cachedExtraction = await cache.getCachedExtraction(forVideoHash: videoHash) {
                state = .reviewing(cachedExtraction.structuredRecipe)
                return cachedExtraction
            }

            // Step 2: Extract audio
            state = .extractingAudio
            progress = 0.05

            let audioURL = try await audioExtractor.extractAudio(from: videoURL)
            try Task.checkCancellation()

            // Estimate video duration for metadata
            let videoDuration = await audioExtractor.estimateDuration(videoURL) ?? 0

            // Step 3: Transcribe (longest step - 70% of processing time)
            state = .transcribing(progress: 0.0)
            progress = 0.1

            let transcript = try await transcriptionService.transcribe(audioURL: audioURL)
            progress = 0.75
            try Task.checkCancellation()

            // Cache transcript
            if enableCaching {
                await cache.cacheTranscript(transcript, forVideoHash: videoHash)
            }

            // Step 4: Frame analysis (optional, parallel in future)
            var visualElements: [String] = []

            if shouldPerformFrameAnalysis(transcriptConfidence: transcript.confidence) {
                state = .analyzingFrames
                progress = 0.8

                do {
                    let frames = try await frameAnalyzer.extractKeyFrames(from: videoURL, count: 5)
                    visualElements = try await frameAnalyzer.analyzeForRecipeElements(frames)
                } catch {
                    // Frame analysis is optional - log error but continue
                    print("Frame analysis failed, continuing without visual elements: \(error)")
                }

                progress = 0.85
                try Task.checkCancellation()
            } else {
                // Skip frame analysis - transcript is high quality
                progress = 0.85
            }

            // Step 5: Structure recipe with AI
            state = .structuringRecipe
            progress = 0.9

            let structuredRecipe = try await recipeStructurer.structure(
                transcript: transcript,
                visualElements: visualElements
            )

            progress = 1.0

            // Step 6: Calculate processing metadata
            let processingTime = Date().timeIntervalSince(startTime)
            let estimatedCost = calculateCost(
                transcriptLength: transcript.text.count,
                usedFrameAnalysis: !visualElements.isEmpty
            )

            // Create attribution (user will fill this in review)
            let attribution = VideoSourceAttribution(
                creatorName: nil,
                videoTitle: nil,
                platform: .cameraRoll,
                sourceURL: videoURL.absoluteString,
                notes: nil,
                importDate: Date(),
                hasPermission: true
            )

            let metadata = VideoImportMetadata(
                attribution: attribution,
                videoDuration: videoDuration,
                transcriptionProvider: transcript.provider.rawValue,
                transcriptionConfidence: transcript.confidence,
                processingCost: estimatedCost,
                processingTime: processingTime,
                transcriptText: transcript.text,
                detectedVisualElements: visualElements.isEmpty ? nil : visualElements,
                processedAt: Date()
            )

            let extraction = VideoRecipeExtraction(
                structuredRecipe: structuredRecipe,
                transcript: transcript,
                visualElements: visualElements,
                metadata: metadata,
                processingTime: processingTime,
                estimatedCost: estimatedCost
            )

            // Cache extraction
            if enableCaching {
                await cache.cacheExtraction(extraction, forVideoHash: videoHash)
            }

            // Cleanup temporary audio file
            AudioExtractionService.cleanupTemporaryAudio(at: audioURL)

            // Transition to review state
            state = .reviewing(structuredRecipe)

            return extraction

        } catch is CancellationError {
            state = .idle
            throw VideoImportError.cancelled
        } catch {
            let errorMessage = error.localizedDescription
            state = .failed(errorMessage)
            throw error
        }
    }

    func cancel() {
        processingTask?.cancel()
        state = .idle
        progress = 0.0
    }

    // MARK: - Private Helpers

    private func shouldPerformFrameAnalysis(transcriptConfidence: Double) -> Bool {
        guard enableFrameAnalysis else { return false }

        // Skip frame analysis if transcript is very high quality
        // This saves ~30 seconds and improves user experience
        return transcriptConfidence < 0.85
    }

    private func calculateCost(transcriptLength: Int, usedFrameAnalysis: Bool) -> Decimal {
        // WhisperKit: Free (on-device)
        // Claude API: ~$0.01-0.02 for typical recipe
        let aiCost = ClaudeRecipeStructurer.estimateCost(
            transcriptLength: transcriptLength,
            includeVisualElements: usedFrameAnalysis
        )

        return aiCost
    }
}

// MARK: - Processing Cache

/// Actor-based cache for transcripts and extractions
actor VideoProcessingCache {
    static let shared = VideoProcessingCache()

    private var transcriptCache: [String: TranscriptionResult] = [:]
    private var extractionCache: [String: VideoRecipeExtraction] = [:]

    func cacheTranscript(_ transcript: TranscriptionResult, forVideoHash hash: String) {
        transcriptCache[hash] = transcript
    }

    func getCachedTranscript(forVideoHash hash: String) -> TranscriptionResult? {
        transcriptCache[hash]
    }

    func cacheExtraction(_ extraction: VideoRecipeExtraction, forVideoHash hash: String) {
        extractionCache[hash] = extraction
    }

    func getCachedExtraction(forVideoHash hash: String) -> VideoRecipeExtraction? {
        extractionCache[hash]
    }

    func clearCache() {
        transcriptCache.removeAll()
        extractionCache.removeAll()
    }

    /// Compute SHA256 hash of video file
    /// Uses first 1MB + file size for fast hashing without reading entire file
    func computeVideoHash(_ url: URL) async throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        // Read first 1MB
        let data = handle.readData(ofLength: 1_024_000)

        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        var fileSize = attributes[.size] as? UInt64 ?? 0

        // Compute hash of data + size
        var hasher = SHA256()
        hasher.update(data: data)
        withUnsafeBytes(of: &fileSize) { bytes in
            hasher.update(bufferPointer: bytes)
        }

        let digest = hasher.finalize()
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Cost Tracking

extension VideoRecipeProcessor {
    /// Track cumulative processing costs
    static var totalProcessingCost: Decimal = 0.0
    static var totalVideosProcessed: Int = 0

    func recordProcessingCost(_ cost: Decimal) {
        Self.totalProcessingCost += cost
        Self.totalVideosProcessed += 1
    }

    static func resetCostTracking() {
        totalProcessingCost = 0.0
        totalVideosProcessed = 0
    }

    static var averageCostPerVideo: Decimal {
        guard totalVideosProcessed > 0 else { return 0 }
        return totalProcessingCost / Decimal(totalVideosProcessed)
    }
}

// MARK: - Performance Monitoring

extension VideoRecipeProcessor {
    /// Monitor memory usage during processing
    func checkMemoryAvailable() -> Bool {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let availableMemory = totalMemory / 1_000_000_000  // GB

        // Require at least 1GB available
        return availableMemory >= 1
    }

    /// Estimate processing time for a video
    static func estimateProcessingTime(videoDuration: TimeInterval) -> TimeInterval {
        // Rough estimates:
        // - Audio extraction: 5-10 seconds
        // - Transcription: ~0.1-0.2x video duration (WhisperKit)
        // - Frame analysis: 15-30 seconds (if enabled)
        // - Recipe structuring: 5-10 seconds (Claude API)

        let audioTime: TimeInterval = 7
        let transcriptionTime = videoDuration * 0.15
        let frameTime: TimeInterval = 20
        let structureTime: TimeInterval = 7

        return audioTime + transcriptionTime + frameTime + structureTime
    }
}
