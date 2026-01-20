import Foundation

/// Result of video analysis - determines if extraction can proceed or needs premium
enum VideoImportAnalysisResult {
    /// Can proceed with free tier (audio or OCR)
    case canProceedFree(mode: ExtractionMode, transcript: String?, onScreenText: String?)

    /// Requires premium for visual extraction
    case requiresPremium(audioReasoning: String, ocrReasoning: String)

    /// Analysis failed
    case failed(Error)
}
