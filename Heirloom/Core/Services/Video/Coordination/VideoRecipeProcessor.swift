//
//  VideoRecipeProcessor.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/8/26.
//
//  Production coordinator for video-to-recipe processing pipeline
//  Orchestrates: Audio Extraction → Transcription → Frame Analysis → Recipe Structuring → Augmentation

import Foundation
import CryptoKit
import Combine
import SwiftData

@MainActor
class VideoRecipeProcessor: VideoRecipeProcessorProtocol, ObservableObject {
    @Published var state: ProcessingState = .idle
    @Published var progress: Double = 0.0
    @Published var canCancel: Bool = false
    @Published var enhancedExtraction: VideoRecipeExtraction.Enhanced? = nil  // NEW: Augmentation data
    @Published var subPhaseProgress: Double = 0.0

    private var processingTask: Task<Void, Error>?
    private let cache = VideoProcessingCache.shared
    private let progressInterpolator = ProgressInterpolator()

    // Services
    private let audioExtractor: AudioExtractionServiceProtocol
    private let transcriptionService: TranscriptionServiceProtocol
    private let frameAnalyzer: FrameAnalysisServiceProtocol
    private let recipeStructurer: RecipeStructurerProtocol

    // Augmentation services (Week 4)
    private let modelContext: ModelContext?
    private let aiService: AIServiceProtocol?

    // Configuration
    private let enableFrameAnalysis: Bool
    private let enableCaching: Bool
    private let enableAugmentation: Bool

    /// Estimated durations for standard video processing phases
    private enum PhaseDuration {
        static let extractingAudio: TimeInterval = 8       // 5-10s
        static let transcribing: TimeInterval = 90         // Default for 10min video
        static let analyzingFrames: TimeInterval = 20      // 15-30s
        static let structuringRecipe: TimeInterval = 12    // 5-15s
        static let augmenting: TimeInterval = 8            // 5-10s

        /// Calculate transcription duration based on video length
        /// WhisperKit processes at ~0.15x real-time speed
        static func transcription(videoDuration: TimeInterval) -> TimeInterval {
            return max(videoDuration * 0.15, 30)  // Minimum 30s
        }
    }

    init(
        audioExtractor: AudioExtractionServiceProtocol,
        transcriptionService: TranscriptionServiceProtocol,
        frameAnalyzer: FrameAnalysisServiceProtocol,
        recipeStructurer: RecipeStructurerProtocol,
        modelContext: ModelContext? = nil,
        aiService: AIServiceProtocol? = nil,
        enableFrameAnalysis: Bool = true,
        enableCaching: Bool = true,
        enableAugmentation: Bool = true
    ) {
        self.audioExtractor = audioExtractor
        self.transcriptionService = transcriptionService
        self.frameAnalyzer = frameAnalyzer
        self.recipeStructurer = recipeStructurer
        self.modelContext = modelContext
        self.aiService = aiService
        self.enableFrameAnalysis = enableFrameAnalysis
        self.enableCaching = enableCaching
        self.enableAugmentation = enableAugmentation
    }

    /// Convenience initializer with default service implementations
    convenience init(
        transcriptionService: TranscriptionServiceProtocol,
        recipeStructurer: RecipeStructurerProtocol,
        modelContext: ModelContext? = nil,
        aiService: AIServiceProtocol? = nil,
        enableFrameAnalysis: Bool = true,
        enableCaching: Bool = true,
        enableAugmentation: Bool = true
    ) {
        self.init(
            audioExtractor: AudioExtractionService(),
            transcriptionService: transcriptionService,
            frameAnalyzer: FrameAnalysisService(),
            recipeStructurer: recipeStructurer,
            modelContext: modelContext,
            aiService: aiService,
            enableFrameAnalysis: enableFrameAnalysis,
            enableCaching: enableCaching,
            enableAugmentation: enableAugmentation
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
            subPhaseProgress = 0.0
            progressInterpolator.start(from: 0.05, to: 0.10, duration: PhaseDuration.extractingAudio)

            let audioURL = try await audioExtractor.extractAudio(from: videoURL)
            try Task.checkCancellation()

            progressInterpolator.snap(to: 0.10)
            progress = 0.10
            subPhaseProgress = 1.0

            // Estimate video duration for metadata
            let videoDuration = await audioExtractor.estimateDuration(videoURL) ?? 0

            // Step 3: Transcribe (longest step - 70% of processing time)
            let transcriptionDuration = PhaseDuration.transcription(videoDuration: videoDuration)

            state = .transcribing(progress: 0.0)
            progress = 0.10
            subPhaseProgress = 0.0
            progressInterpolator.start(from: 0.10, to: 0.75, duration: transcriptionDuration)

            // Subscribe to interpolator for smooth updates
            let interpolatorCancellable = progressInterpolator.$interpolatedProgress.sink { [weak self] interpolated in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.progress = interpolated
                    // Calculate sub-phase progress (0.0-1.0 within transcription)
                    self.subPhaseProgress = (interpolated - 0.10) / (0.75 - 0.10)
                }
            }

            let transcript = try await transcriptionService.transcribe(audioURL: audioURL)

            interpolatorCancellable.cancel()
            progressInterpolator.snap(to: 0.75)
            progress = 0.75
            subPhaseProgress = 1.0
            try Task.checkCancellation()

            // Cache transcript
            if enableCaching {
                await cache.cacheTranscript(transcript, forVideoHash: videoHash)
            }

            // Step 4: Frame analysis (optional, parallel in future)
            var visualElements: [String] = []
            var detectedWatermark: WatermarkDetectionResult? = nil

            if shouldPerformFrameAnalysis(transcriptConfidence: transcript.confidence) {
                state = .analyzingFrames
                progress = 0.75
                subPhaseProgress = 0.0
                progressInterpolator.start(from: 0.75, to: 0.80, duration: PhaseDuration.analyzingFrames)

                do {
                    let frames = try await frameAnalyzer.extractKeyFrames(from: videoURL, count: 5)
                    visualElements = try await frameAnalyzer.analyzeForRecipeElements(frames)

                    // Step 4.5: Detect watermarks (NEW - Week 5)
                    if let aiService = aiService as? AnthropicAIService {
                        print("\n🔍 WATERMARK DETECTION:")
                        let watermarkService = WatermarkDetectionService(aiService: aiService)
                        detectedWatermark = try await watermarkService.detectWatermark(from: frames)

                        if let watermark = detectedWatermark {
                            print("   ✅ Detected: \(watermark.creatorHandle ?? "unknown")")
                            print("   Platform: \(watermark.platform?.displayName ?? "unknown")")
                            print("   Confidence: \(String(format: "%.0f", watermark.confidence * 100))%")
                        } else {
                            print("   ❌ No watermark detected")
                        }
                    }
                } catch {
                    // Frame analysis is optional - log error but continue
                    print("Frame analysis failed, continuing without visual elements: \(error)")
                }

                progressInterpolator.snap(to: 0.80)
                progress = 0.80
                subPhaseProgress = 1.0
                try Task.checkCancellation()
            } else {
                // Skip frame analysis - transcript is high quality
                progressInterpolator.snap(to: 0.80)
                progress = 0.80
                subPhaseProgress = 1.0
            }

            // Step 5: Structure recipe with AI
            state = .structuringRecipe
            progress = 0.80
            subPhaseProgress = 0.0
            progressInterpolator.start(from: 0.80, to: 0.90, duration: PhaseDuration.structuringRecipe)

            let structuredRecipe = try await recipeStructurer.structure(
                transcript: transcript,
                visualElements: visualElements
            )

            progressInterpolator.snap(to: 0.90)
            progress = 0.90
            subPhaseProgress = 1.0

            // Step 5.5: Augment with similar recipes (NEW - Week 4)
            var augmentedRecipe: AugmentedRecipe? = nil
            var similarRecipes: [SimilarRecipeMatch] = []
            var webRecipes: [WebRecipeResult] = []

            print("\n🤔 AUGMENTATION CHECK:")
            print("   enableAugmentation: \(enableAugmentation)")
            print("   modelContext: \(modelContext != nil ? "✅ present" : "❌ nil")")
            print("   aiService: \(aiService != nil ? "✅ present" : "❌ nil")")
            let lowConfidenceCount = structuredRecipe.ingredients.filter {
                $0.confidence == .approximate || $0.confidence == .unknown || $0.quantity == nil
            }.count
            print("   Low confidence ingredients: \(lowConfidenceCount) / \(structuredRecipe.ingredients.count)")
            print("   Should augment: \(shouldPerformAugmentation(structuredRecipe: structuredRecipe))\n")

            if shouldPerformAugmentation(structuredRecipe: structuredRecipe) {
                print("✅ Starting augmentation pipeline...")
                state = .augmentingWithSimilarRecipes
                progress = 0.90
                subPhaseProgress = 0.0
                progressInterpolator.start(from: 0.90, to: 0.95, duration: PhaseDuration.augmenting)

                do {
                    // Find similar recipes locally
                    if let context = modelContext {
                        let similarityService = LocalRecipeSimilarityService(modelContext: context)
                        similarRecipes = try await similarityService.findSimilarRecipes(
                            to: structuredRecipe,
                            limit: 5
                        )
                        print("🔍 Found \(similarRecipes.count) similar local recipes")
                    }

                    // Search web for similar recipes (if local results < 3)
                    if similarRecipes.count < 3 {
                        let webSearchService = WebRecipeSearchService()
                        webRecipes = try await webSearchService.searchSimilarRecipes(
                            for: structuredRecipe
                        )
                        print("🌐 Found \(webRecipes.count) similar web recipes")
                    }

                    // Augment recipe with AI (always run if AI service available)
                    if let aiSvc = aiService {
                        let augmentationService = RecipeAugmentationService(aiService: aiSvc)
                        augmentedRecipe = try await augmentationService.augment(
                            structuredRecipe,
                            similarRecipes: similarRecipes,
                            webRecipes: webRecipes
                        )
                        print("✨ Augmentation complete: \(augmentedRecipe?.augmentedIngredients.count ?? 0) ingredients enhanced")
                    } else {
                        print("⚠️ AI service not available - skipping augmentation")
                    }
                } catch let augmentError as AugmentationError {
                    // Handle augmentation errors specifically
                    switch augmentError {
                    case .noWebRecipesForEmptyExtraction(let title):
                        // CRITICAL: This is a hard failure - we have no content and no fallback
                        print("❌ CRITICAL: Empty extraction with no web fallback")
                        print("   Recipe title: \"\(title)\"")
                        print("   Audio transcription: insufficient")
                        print("   Web search: no matches found")
                        print("💡 User should try ASMR mode for vision-based extraction")

                        // Re-throw the augmentation error directly
                        throw augmentError

                    default:
                        // Other augmentation errors are optional - log but continue
                        print("⚠️ Augmentation failed, continuing without: \(augmentError.localizedDescription ?? "Unknown error")")
                    }
                } catch {
                    // Non-augmentation errors - log but continue (augmentation is optional)
                    print("⚠️ Augmentation failed, continuing without: \(error.localizedDescription)")
                }

                progressInterpolator.snap(to: 0.95)
                progress = 0.95
                subPhaseProgress = 1.0
                try Task.checkCancellation()
            } else {
                print("❌ SKIPPING AUGMENTATION")
                if !enableAugmentation {
                    print("   Reason: augmentation disabled")
                } else if modelContext == nil {
                    print("   Reason: modelContext is nil")
                } else if aiService == nil {
                    print("   Reason: aiService is nil")
                } else {
                    print("   Reason: < 2 low-confidence ingredients")
                }
            }

            progress = 1.0

            // Step 6: Calculate processing metadata
            let processingTime = Date().timeIntervalSince(startTime)
            let estimatedCost = calculateCost(
                transcriptLength: transcript.text.count,
                usedFrameAnalysis: !visualElements.isEmpty
            )

            // Create attribution (pre-fill with detected watermark if found)
            let attribution = VideoSourceAttribution(
                creatorName: detectedWatermark?.creatorHandle,  // Auto-populate if watermark detected
                videoTitle: nil,
                platform: detectedWatermark?.platform ?? .cameraRoll,  // Use detected platform
                sourceURL: videoURL.absoluteString,
                notes: detectedWatermark != nil ? "(detected from video)" : nil,  // Add note if auto-detected
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

            // Create enhanced extraction with augmentation data
            let enhanced = VideoRecipeExtraction.Enhanced(
                original: extraction,
                augmentedRecipe: augmentedRecipe,
                similarRecipes: similarRecipes,
                webRecipes: webRecipes
            )

            // Store enhanced extraction for UI access
            self.enhancedExtraction = enhanced

            // Cache extraction
            if enableCaching {
                await cache.cacheExtraction(extraction, forVideoHash: videoHash)
            }

            // Cleanup temporary audio file
            AudioExtractionService.cleanupTemporaryAudio(at: audioURL)

            // Transition to review state (use augmented recipe if available)
            state = .reviewing(enhanced.finalRecipe)

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
        progressInterpolator.stop()
        processingTask?.cancel()
        state = .idle
        progress = 0.0
        subPhaseProgress = 0.0
    }

    // MARK: - Private Helpers

    private func shouldPerformFrameAnalysis(transcriptConfidence: Double) -> Bool {
        guard enableFrameAnalysis else { return false }

        // Skip frame analysis if transcript is very high quality
        // This saves ~30 seconds and improves user experience
        return transcriptConfidence < 0.85
    }

    private func shouldPerformAugmentation(structuredRecipe: StructuredRecipe) -> Bool {
        guard enableAugmentation else { return false }

        // Augmentation requires ModelContext and AI service
        guard modelContext != nil, aiService != nil else {
            return false
        }

        // CRITICAL: Run augmentation if recipe has NO ingredients or steps
        // This triggers web search fallback to find the recipe by name
        let hasNoContent = structuredRecipe.ingredients.isEmpty && structuredRecipe.steps.isEmpty
        if hasNoContent {
            print("🔍 Recipe has no content - MUST augment via web search")
            return true
        }

        // Also augment if there are low-confidence ingredients
        let lowConfidenceIngredients = structuredRecipe.ingredients.filter { ingredient in
            ingredient.confidence == .approximate ||
            ingredient.confidence == .unknown ||
            ingredient.quantity == nil
        }

        // Run augmentation if ANY ingredient needs help (lowered from 2)
        return lowConfidenceIngredients.count >= 1
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
