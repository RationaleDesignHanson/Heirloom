//
//  VideoCostAnalyzer.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-03.
//

import Foundation

/// Analyzes videos to determine extraction mode and credit cost
/// Used to show users the cost BEFORE processing begins
///
/// # Usage
/// ```swift
/// let analyzer = await VideoCostAnalyzer.makeDefault()
/// let result = try await analyzer.analyze(videoAt: videoURL)
///
/// switch result {
/// case .regular(let reasoning):
///     // 1 credit - audio/OCR will work
/// case .asmr(let reasoning):
///     // 5 credits - needs vision analysis
/// case .failed(let error):
///     // Analysis failed
/// }
/// ```
@MainActor
final class VideoCostAnalyzer {

    // MARK: - Types

    enum AnalysisResult {
        /// Regular mode available (audio transcription or OCR)
        case regular(reasoning: String)

        /// ASMR mode required (vision analysis)
        case asmr(audioReasoning: String, ocrReasoning: String)

        /// Analysis failed
        case failed(Error)

        /// Credit cost for this result
        var creditCost: Int {
            switch self {
            case .regular: return UserCredits.VideoCreditCost.regular.rawValue
            case .asmr: return UserCredits.VideoCreditCost.asmr.rawValue
            case .failed: return 0
            }
        }

        /// Display name for the extraction mode
        var modeName: String {
            switch self {
            case .regular: return "Audio"
            case .asmr: return "ASMR"
            case .failed: return "Unknown"
            }
        }

        /// Human-readable reasoning
        var reasoning: String {
            switch self {
            case .regular(let reasoning):
                return reasoning
            case .asmr(let audioReasoning, let ocrReasoning):
                return "Audio: \(audioReasoning). Text: \(ocrReasoning)"
            case .failed(let error):
                return "Analysis failed: \(error.localizedDescription)"
            }
        }

        /// Whether this result allows processing
        var canProceed: Bool {
            switch self {
            case .regular, .asmr: return true
            case .failed: return false
            }
        }
    }

    // MARK: - Dependencies

    private let audioAnalyzer: AudioAnalyzer
    private let onScreenTextDetector: OnScreenTextDetector

    // MARK: - Initialization

    init(audioAnalyzer: AudioAnalyzer, onScreenTextDetector: OnScreenTextDetector) {
        self.audioAnalyzer = audioAnalyzer
        self.onScreenTextDetector = onScreenTextDetector
    }

    /// Create default analyzer with standard services
    static func makeDefault() async -> VideoCostAnalyzer {
        let audioAnalyzer = await AudioAnalyzer.makeDefault()
        let onScreenTextDetector = OnScreenTextDetector()
        return VideoCostAnalyzer(
            audioAnalyzer: audioAnalyzer,
            onScreenTextDetector: onScreenTextDetector
        )
    }

    // MARK: - Analysis

    /// Analyze a video to determine extraction mode and credit cost
    /// - Parameter videoURL: URL to the video file
    /// - Returns: Analysis result with mode and cost
    func analyze(videoAt videoURL: URL) async -> AnalysisResult {
        Log.info("Starting video cost analysis", category: .video, metadata: [
            "file": videoURL.lastPathComponent
        ])

        do {
            // TIER 1: Audio Analysis
            let audioResult = try await audioAnalyzer.analyze(videoAt: videoURL)

            if audioResult.recommendedMode == .audioTranscript {
                // Audio is good - regular mode (1 credit)
                Log.info("Video analysis: Regular mode (audio)", category: .video, metadata: [
                    "reasoning": audioResult.reasoning
                ])
                return .regular(reasoning: audioResult.reasoning)
            }

            // TIER 2: On-Screen Text Detection
            let ocrResult = try await onScreenTextDetector.detect(in: videoURL)

            if ocrResult.hasRecipeText {
                // OCR found recipe text - regular mode (1 credit)
                Log.info("Video analysis: Regular mode (OCR)", category: .video, metadata: [
                    "reasoning": ocrResult.reasoning
                ])
                return .regular(reasoning: ocrResult.reasoning)
            }

            // TIER 3: Neither worked - ASMR mode required (5 credits)
            Log.info("Video analysis: ASMR mode required", category: .video, metadata: [
                "audio_reasoning": audioResult.reasoning,
                "ocr_reasoning": ocrResult.reasoning
            ])
            return .asmr(
                audioReasoning: audioResult.reasoning,
                ocrReasoning: ocrResult.reasoning
            )

        } catch {
            Log.error("Video analysis failed", category: .video, metadata: [
                "error": error.localizedDescription
            ])
            return .failed(error)
        }
    }

    /// Quick check if a video likely needs ASMR mode (for UI hints)
    /// This is faster than full analysis - just checks audio
    func quickAudioCheck(videoAt videoURL: URL) async -> Bool {
        do {
            let audioResult = try await audioAnalyzer.analyze(videoAt: videoURL)
            return audioResult.recommendedMode != .audioTranscript
        } catch {
            return true // Assume ASMR if check fails
        }
    }
}

// MARK: - Convenience Extensions

extension VideoCostAnalyzer.AnalysisResult {
    /// Update a PendingVideoImport with analysis results
    func apply(to import_: inout PendingVideoImport) {
        import_.estimatedCreditCost = creditCost
        import_.analysisMode = modeName
        import_.analysisReasoning = reasoning
    }
}
