//
//  MockClaudeAPI.swift
//  HeirloomTestsV2
//
//  Created: 2026-01-06
//

import Foundation
@testable import Heirloom

/// Mock implementation of Claude API for testing language detection and translation
/// Provides configurable responses for all supported languages
class MockClaudeAPI: MockTracking, MockErrorInjection, MockStateSimulation {

    // MARK: - MockTracking
    var callLog: [String] = []

    // MARK: - MockErrorInjection
    var shouldFail = false
    var injectedError: Error?

    // MARK: - Configurable Responses
    var mockLanguageResponse: LanguageDetectionResponse?
    var mockTranslationResponse: String?
    var mockBatchTranslations: [String]?

    // MARK: - Behavior Configuration
    var detectionDelay: TimeInterval = 0
    var translationDelay: TimeInterval = 0
    var simulateTimeout = false
    var simulateRateLimit = false

    // MARK: - Test Inspection
    private(set) var detectionRequests: [(text: String, url: String?, domain: String?)] = []
    private(set) var translationRequests: [(text: String, from: String, to: String, context: TranslationContext)] = []
    private(set) var batchTranslationRequests: [(texts: [String], from: String, to: String, context: TranslationContext)] = []

    // MARK: - Language Detection

    func detectLanguage(
        text: String,
        url: String? = nil,
        domain: String? = nil
    ) async throws -> LanguageDetectionResponse {
        recordCall("detectLanguage")
        detectionRequests.append((text, url, domain))

        if detectionDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(detectionDelay * 1_000_000_000))
        }

        if simulateTimeout {
            throw ClaudeAPIError.timeout
        }

        if simulateRateLimit {
            throw ClaudeAPIError.rateLimitExceeded
        }

        if shouldFail {
            throw injectedError ?? ClaudeAPIError.detectionFailed
        }

        if let response = mockLanguageResponse {
            return response
        }

        // Auto-detect from common patterns if no mock response
        return autoDetectLanguage(text: text, domain: domain)
    }

    // MARK: - Translation

    func translateText(
        _ text: String,
        from sourceLanguage: String,
        to targetLanguage: String,
        context: TranslationContext = .general
    ) async throws -> String {
        recordCall("translateText")
        translationRequests.append((text, sourceLanguage, targetLanguage, context))

        if translationDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(translationDelay * 1_000_000_000))
        }

        if simulateTimeout {
            throw ClaudeAPIError.timeout
        }

        if simulateRateLimit {
            throw ClaudeAPIError.rateLimitExceeded
        }

        if shouldFail {
            throw injectedError ?? ClaudeAPIError.translationFailed
        }

        if let response = mockTranslationResponse {
            return response
        }

        // If translating to English and source is English, return as-is
        if sourceLanguage == "en" && targetLanguage == "en" {
            return text
        }

        // Default: return prefixed text
        return "[Translated] \(text)"
    }

    // MARK: - Batch Translation

    func translateBatch(
        _ texts: [String],
        from sourceLanguage: String,
        to targetLanguage: String,
        context: TranslationContext = .general
    ) async throws -> [String] {
        recordCall("translateBatch")
        batchTranslationRequests.append((texts, sourceLanguage, targetLanguage, context))

        if translationDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(translationDelay * 1_000_000_000))
        }

        if simulateTimeout {
            throw ClaudeAPIError.timeout
        }

        if simulateRateLimit {
            throw ClaudeAPIError.rateLimitExceeded
        }

        if shouldFail {
            throw injectedError ?? ClaudeAPIError.translationFailed
        }

        if let responses = mockBatchTranslations {
            return responses
        }

        // Default: translate each text individually
        return try await texts.asyncMap { text in
            try await self.translateText(text, from: sourceLanguage, to: targetLanguage, context: context)
        }
    }

    // MARK: - MockStateSimulation

    func reset() {
        callLog.removeAll()
        shouldFail = false
        injectedError = nil
        mockLanguageResponse = nil
        mockTranslationResponse = nil
        mockBatchTranslations = nil
        detectionDelay = 0
        translationDelay = 0
        simulateTimeout = false
        simulateRateLimit = false
        detectionRequests.removeAll()
        translationRequests.removeAll()
        batchTranslationRequests.removeAll()
    }

    // MARK: - Test Helpers

    /// Configure mock to detect specific language
    func configureFrenchDetection(confidence: Double = 0.95) {
        mockLanguageResponse = LanguageDetectionResponse(
            language: "fr",
            confidence: confidence,
            languageName: "French",
            detectedUnitSystem: "metric",
            needsTranslation: true
        )
    }

    func configureJapaneseDetection(confidence: Double = 0.95) {
        mockLanguageResponse = LanguageDetectionResponse(
            language: "ja",
            confidence: confidence,
            languageName: "Japanese",
            detectedUnitSystem: "metric",
            needsTranslation: true
        )
    }

    func configureKoreanDetection(confidence: Double = 0.95) {
        mockLanguageResponse = LanguageDetectionResponse(
            language: "ko",
            confidence: confidence,
            languageName: "Korean",
            detectedUnitSystem: "metric",
            needsTranslation: true
        )
    }

    func configureEnglishDetection() {
        mockLanguageResponse = LanguageDetectionResponse(
            language: "en",
            confidence: 1.0,
            languageName: "English",
            detectedUnitSystem: "imperial",
            needsTranslation: false
        )
    }

    /// Auto-detect language from text patterns (simple heuristic for testing)
    private func autoDetectLanguage(text: String, domain: String?) -> LanguageDetectionResponse {
        let lowerText = text.lowercased()

        // French patterns
        if lowerText.contains("de ") || lowerText.contains("tasse") || lowerText.contains("cuillère") {
            return LanguageDetectionResponse(
                language: "fr",
                confidence: 0.9,
                languageName: "French",
                detectedUnitSystem: "metric",
                needsTranslation: true
            )
        }

        // Japanese patterns (check for hiragana/katakana/kanji)
        if text.range(of: "[ぁ-んァ-ヶ一-龯]", options: .regularExpression) != nil {
            return LanguageDetectionResponse(
                language: "ja",
                confidence: 0.95,
                languageName: "Japanese",
                detectedUnitSystem: "metric",
                needsTranslation: true
            )
        }

        // Korean patterns (check for Hangul)
        if text.range(of: "[가-힣]", options: .regularExpression) != nil {
            return LanguageDetectionResponse(
                language: "ko",
                confidence: 0.95,
                languageName: "Korean",
                detectedUnitSystem: "metric",
                needsTranslation: true
            )
        }

        // Spanish patterns
        if lowerText.contains("taza") || lowerText.contains("cucharada") {
            return LanguageDetectionResponse(
                language: "es",
                confidence: 0.9,
                languageName: "Spanish",
                detectedUnitSystem: "metric",
                needsTranslation: true
            )
        }

        // Default to English
        return LanguageDetectionResponse(
            language: "en",
            confidence: 1.0,
            languageName: "English",
            detectedUnitSystem: "imperial",
            needsTranslation: false
        )
    }
}

// MARK: - Supporting Types

struct LanguageDetectionResponse: Codable, Equatable {
    let language: String
    let confidence: Double
    let languageName: String
    let detectedUnitSystem: String
    let needsTranslation: Bool
}

enum TranslationContext: String, Codable {
    case general
    case title
    case ingredient
    case instruction
    case note
}

enum ClaudeAPIError: Error, Equatable {
    case detectionFailed
    case translationFailed
    case timeout
    case rateLimitExceeded
    case invalidAPIKey
    case networkError

    var localizedDescription: String {
        switch self {
        case .detectionFailed: return "Language detection failed"
        case .translationFailed: return "Translation failed"
        case .timeout: return "Request timed out"
        case .rateLimitExceeded: return "Rate limit exceeded"
        case .invalidAPIKey: return "Invalid API key"
        case .networkError: return "Network error"
        }
    }
}

// MARK: - Array Async Map Extension

extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var results: [T] = []
        for element in self {
            try await results.append(transform(element))
        }
        return results
    }
}
