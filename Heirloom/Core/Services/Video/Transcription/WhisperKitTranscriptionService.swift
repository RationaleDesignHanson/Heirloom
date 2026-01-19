//
//  WhisperKitTranscriptionService.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/8/26.
//
//  On-device transcription using WhisperKit

import Foundation
import WhisperKit

// MARK: - Transcription Errors

enum TranscriptionError: LocalizedError {
    case modelLoadFailed
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed:
            return "Failed to load Whisper model"
        case .transcriptionFailed:
            return "Transcription failed"
        }
    }
}

// MARK: - WhisperKit Transcription Service

@MainActor
class WhisperKitTranscriptionService: TranscriptionServiceProtocol {
    let provider: TranscriptionProvider = .whisperKit

    // Shared WhisperKit instance (lazy loaded) to prevent race conditions
    private static var sharedWhisperKit: WhisperKit?
    private static var loadTask: Task<WhisperKit?, Never>?

    private let modelName: String

    /// Get or create shared WhisperKit instance
    /// Ensures only one download/initialization happens even with concurrent calls
    private static func getOrCreateWhisperKit(model: String) async -> WhisperKit? {
        // If already loaded, return it
        if let existing = sharedWhisperKit {
            return existing
        }

        // If currently loading, wait for that task to complete
        if let existingTask = loadTask {
            return await existingTask.value
        }

        // Start new load task
        let task = Task { @MainActor () -> WhisperKit? in
            do {
                Log.info("Loading WhisperKit model", category: .video, metadata: ["model": model])
                let whisper = try await WhisperKit(model: model)
                sharedWhisperKit = whisper
                Log.info("WhisperKit model loaded successfully", category: .video)
                return whisper
            } catch {
                Log.error("Failed to load WhisperKit model", category: .video, metadata: [
                    "error": error.localizedDescription
                ])
                return nil
            }
        }

        loadTask = task
        let result = await task.value
        loadTask = nil  // Clear task after completion
        return result
    }

    /// Initialize with device-appropriate model
    init() async {
        let model = Self.selectOptimalModel()
        self.modelName = model

        // Use shared instance instead of creating new one
        // This will wait if another load is in progress (e.g., preloadModel at app launch)
        let result = await Self.getOrCreateWhisperKit(model: model)

        if result == nil {
            Log.error("WhisperKit model failed to load - transcription will be unavailable", category: .video, metadata: [
                "model": model,
                "error_hint": "This may happen on simulator or if model download failed"
            ])
        }
    }

    var isAvailable: Bool {
        Self.sharedWhisperKit != nil
    }

    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        guard let whisper = Self.sharedWhisperKit else {
            Log.error("Transcription attempted but WhisperKit model not available", category: .video, metadata: [
                "audio_url": audioURL.lastPathComponent
            ])
            throw VideoImportError.transcriptionUnavailable
        }

        // Transcribe audio file - WhisperKit returns array of results
        let results = try await whisper.transcribe(audioPath: audioURL.path)

        guard let result = results.first else {
            throw VideoImportError.transcriptionFailed(
                underlying: TranscriptionError.transcriptionFailed
            )
        }

        // Convert WhisperKit result to our format
        let segments = result.segments.map { segment in
            TranscriptSegment(
                text: segment.text,
                startTime: TimeInterval(segment.start),
                endTime: TimeInterval(segment.end)
            )
        }

        // Get transcript text
        let text = result.text

        // Estimate confidence based on result quality
        // WhisperKit doesn't provide direct confidence, use heuristics
        let confidence = estimateConfidence(fromText: text, segments: segments)

        return TranscriptionResult(
            text: text,
            segments: segments,
            confidence: confidence,
            provider: .whisperKit,
            language: result.language
        )
    }

    // MARK: - Confidence Estimation

    /// Estimate transcription confidence from result quality
    private func estimateConfidence(fromText text: String, segments: [TranscriptSegment]) -> Double {
        // WhisperKit doesn't provide confidence scores
        // Use text length and segment count as proxy for quality
        let hasContent = !text.isEmpty && text.count > 10
        let hasSegments = !segments.isEmpty

        if hasContent && hasSegments {
            return 0.8  // Good confidence
        } else if hasContent {
            return 0.6  // Moderate confidence
        } else {
            return 0.4  // Low confidence
        }
    }

    // MARK: - Model Selection

    /// Select optimal Whisper model based on device capability
    static func selectOptimalModel() -> String {
        let memory = ProcessInfo.processInfo.physicalMemory
        let availableMemory = memory / 1_000_000_000  // GB

        // Model sizes and memory requirements:
        // tiny.en: 39MB, ~1GB RAM, fastest but least accurate
        // base.en: 74MB, ~2GB RAM, good balance
        // small.en: 244MB, ~4GB RAM, better accuracy
        // medium.en: 769MB, ~6GB RAM, high accuracy
        // large: 1.5GB, ~10GB RAM, best accuracy (too large for most devices)

        if availableMemory >= 6 {
            return "small.en"  // Best quality for devices with sufficient RAM
        } else if availableMemory >= 4 {
            return "base.en"   // Good balance for most devices
        } else {
            return "tiny.en"   // Fastest for low-memory devices
        }
    }

    /// Get model info for display
    static func modelInfo(for modelName: String) -> (size: String, quality: String) {
        switch modelName {
        case "tiny.en":
            return ("39MB", "Fast, lower accuracy")
        case "base.en":
            return ("74MB", "Balanced")
        case "small.en":
            return ("244MB", "High accuracy")
        case "medium.en":
            return ("769MB", "Very high accuracy")
        default:
            return ("Unknown", "Unknown")
        }
    }

    /// Preload WhisperKit model in the background on app launch
    /// Call this from app initialization to download model before user needs it
    static func preloadModel() {
        Task { @MainActor in
            let model = selectOptimalModel()
            let (size, quality) = modelInfo(for: model)

            Log.info("Preloading WhisperKit model", category: .video, metadata: [
                "model": model,
                "size": size,
                "quality": quality
            ])

            // Use shared instance getter - this handles concurrent calls gracefully
            _ = await getOrCreateWhisperKit(model: model)
        }
    }


    // MARK: - Memory Monitoring

    /// Check available memory before transcription
    static func checkMemoryAvailable() -> Bool {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let availableMemory = totalMemory / 1_000_000_000  // GB

        // Require at least 2GB available
        return availableMemory >= 2
    }
}

// MARK: - iOS 26 SpeechAnalyzer Service (Future)

@MainActor
class SpeechAnalyzerTranscriptionService: TranscriptionServiceProtocol {
    let provider: TranscriptionProvider = .speechAnalyzer

    var isAvailable: Bool {
        if #available(iOS 26.0, *) {
            // Check if SpeechAnalyzer is available
            // This will be implemented when iOS 26 SDK is released
            return false  // Not yet available
        }
        return false
    }

    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        guard #available(iOS 26.0, *) else {
            throw VideoImportError.transcriptionUnavailable
        }

        // TODO: Implement iOS 26 SpeechAnalyzer when SDK available
        // Expected benefits:
        // - Much faster than WhisperKit
        // - Better accuracy (trained on more data)
        // - Lower battery usage
        // - Free (no cost)
        // - Native integration with iOS

        throw VideoImportError.transcriptionUnavailable
    }
}

// MARK: - Adaptive Transcription Service

@MainActor
class AdaptiveTranscriptionService: TranscriptionServiceProtocol {
    private let speechAnalyzer = SpeechAnalyzerTranscriptionService()
    private let whisperKit: WhisperKitTranscriptionService?

    var provider: TranscriptionProvider {
        if speechAnalyzer.isAvailable {
            return .speechAnalyzer
        }
        return .whisperKit
    }

    var isAvailable: Bool {
        speechAnalyzer.isAvailable || (whisperKit?.isAvailable ?? false)
    }

    init() async {
        // Initialize WhisperKit as fallback
        if !speechAnalyzer.isAvailable {
            self.whisperKit = await WhisperKitTranscriptionService()
        } else {
            self.whisperKit = nil
        }
    }

    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        // Prefer iOS 26 SpeechAnalyzer if available
        if speechAnalyzer.isAvailable {
            do {
                return try await speechAnalyzer.transcribe(audioURL: audioURL)
            } catch {
                print("SpeechAnalyzer failed, falling back to WhisperKit: \(error)")
                // Fall through to WhisperKit
            }
        }

        // Use WhisperKit as fallback
        guard let whisper = whisperKit, whisper.isAvailable else {
            throw VideoImportError.transcriptionUnavailable
        }

        return try await whisper.transcribe(audioURL: audioURL)
    }
}

// MARK: - Transcription Progress (Future Enhancement)

/// Protocol for transcription progress updates
@MainActor
protocol TranscriptionProgressDelegate: AnyObject {
    func transcriptionDidUpdateProgress(_ progress: Double)
    func transcriptionDidComplete(_ result: TranscriptionResult)
    func transcriptionDidFail(_ error: Error)
}

/// Enhanced transcription service with progress reporting
@MainActor
class ProgressiveTranscriptionService: TranscriptionServiceProtocol {
    let provider: TranscriptionProvider
    weak var progressDelegate: TranscriptionProgressDelegate?

    private let underlyingService: TranscriptionServiceProtocol

    init(service: TranscriptionServiceProtocol) {
        self.underlyingService = service
        self.provider = service.provider
    }

    var isAvailable: Bool {
        underlyingService.isAvailable
    }

    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        // Report initial progress
        progressDelegate?.transcriptionDidUpdateProgress(0.0)

        do {
            // WhisperKit processes in chunks, we could hook into that for progress
            // For now, we'll just report start and end
            let result = try await underlyingService.transcribe(audioURL: audioURL)

            progressDelegate?.transcriptionDidUpdateProgress(1.0)
            progressDelegate?.transcriptionDidComplete(result)

            return result
        } catch {
            progressDelegate?.transcriptionDidFail(error)
            throw error
        }
    }
}
