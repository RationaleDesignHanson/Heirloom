import Foundation
import AVFoundation

@MainActor
class AudioAnalyzer {

    // IMPORTANT: Use existing WhisperKitTranscriptionService
    private let transcriptionService: WhisperKitTranscriptionService

    init(transcriptionService: WhisperKitTranscriptionService) {
        self.transcriptionService = transcriptionService
    }

    /// Convenience initializer with new instance
    static func makeDefault() async -> AudioAnalyzer {
        let service = await WhisperKitTranscriptionService()
        return AudioAnalyzer(transcriptionService: service)
    }

    /// Analyze video audio to determine optimal extraction mode
    func analyze(videoAt url: URL) async throws -> AudioAnalysisResult {
        // 1. Check for audio track
        let hasAudioTrack = try await checkForAudioTrack(in: url)
        guard hasAudioTrack else {
            return AudioAnalysisResult(
                hasUsefulAudio: false,
                recommendedMode: .onScreenText,
                reasoning: "No audio track found - trying OCR"
            )
        }

        // 2. Extract audio to temporary file
        let audioURL = try await extractAudio(from: url)
        defer {
            // Clean up temporary audio file
            try? FileManager.default.removeItem(at: audioURL)
        }

        // 3. Check if transcription is available
        guard transcriptionService.isAvailable else {
            return AudioAnalysisResult(
                hasUsefulAudio: false,
                recommendedMode: .onScreenText,
                reasoning: "Transcription service unavailable - trying OCR"
            )
        }

        // 4. Transcribe using existing WhisperKitTranscriptionService
        let transcriptionResult = try await transcriptionService.transcribe(audioURL: audioURL)
        let transcript = transcriptionResult.text
        let confidence = Float(transcriptionResult.confidence)

        // 5. Analyze transcript quality
        let wordCount = transcript.split(separator: " ").count
        let videoDuration = try await getVideoDuration(url)
        let wordsPerMinute = videoDuration > 0 ? Float(wordCount) / Float(videoDuration / 60.0) : 0

        // 6. Check recipe relevance
        let relevanceScore = RecipeKeywords.relevanceScore(for: transcript)

        // 7. Determine mode
        let (mode, reasoning) = determineMode(
            wordCount: wordCount,
            wordsPerMinute: wordsPerMinute,
            confidence: confidence,
            relevanceScore: relevanceScore
        )

        return AudioAnalysisResult(
            hasUsefulAudio: mode == .audioTranscript,
            transcript: mode == .audioTranscript ? transcript : nil,
            wordCount: wordCount,
            speechConfidence: confidence,
            recipeRelevanceScore: relevanceScore,
            recommendedMode: mode,
            reasoning: reasoning
        )
    }

    private func determineMode(
        wordCount: Int,
        wordsPerMinute: Float,
        confidence: Float,
        relevanceScore: Float
    ) -> (ExtractionMode, String) {

        // Too few words overall
        if wordCount < 30 {
            return (.onScreenText, "Insufficient speech (\(wordCount) words) - trying OCR")
        }

        // Speaking too slowly/infrequently (likely background music)
        if wordsPerMinute < 20 {
            return (.onScreenText, "Sparse speech (\(Int(wordsPerMinute)) words/min) - trying OCR")
        }

        // Low speech recognition confidence
        if confidence < 0.4 {
            return (.onScreenText, "Low speech clarity (\(Int(confidence * 100))%) - trying OCR")
        }

        // Not talking about cooking
        if relevanceScore < 0.15 {
            return (.onScreenText, "Low recipe relevance (\(Int(relevanceScore * 100))%) - trying OCR")
        }

        // All checks passed - use audio transcript
        return (.audioTranscript,
                "Good audio: \(wordCount) words, \(Int(confidence * 100))% clarity, \(Int(relevanceScore * 100))% relevance")
    }

    private func checkForAudioTrack(in url: URL) async throws -> Bool {
        let asset = AVAsset(url: url)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        return !audioTracks.isEmpty
    }

    private func getVideoDuration(_ url: URL) async throws -> TimeInterval {
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        return duration.seconds
    }

    /// Extract audio from video to temporary file
    private func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVAsset(url: videoURL)

        // Create temporary audio file
        let tempDir = FileManager.default.temporaryDirectory
        let audioFileName = "audio_\(UUID().uuidString).m4a"
        let audioURL = tempDir.appendingPathComponent(audioFileName)

        // Remove if exists
        try? FileManager.default.removeItem(at: audioURL)

        // Create export session
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioAnalysisError.exportFailed
        }

        exportSession.outputURL = audioURL
        exportSession.outputFileType = .m4a

        // Export
        await exportSession.export()

        guard exportSession.status == .completed else {
            throw AudioAnalysisError.exportFailed
        }

        return audioURL
    }
}

// MARK: - Errors

enum AudioAnalysisError: LocalizedError {
    case exportFailed
    case noAudioTrack

    var errorDescription: String? {
        switch self {
        case .exportFailed: return "Failed to extract audio from video"
        case .noAudioTrack: return "Video has no audio track"
        }
    }
}
