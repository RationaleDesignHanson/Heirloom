//
//  ProcessingMonitor.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/8/26.
//
//  Monitoring and observability utilities for video processing
//  Tracks cost, performance, errors, and usage analytics

import Foundation
import os.log

// MARK: - Processing Monitor

/// Centralized monitoring for video processing pipeline
/// Tracks cost, performance, errors, and provides analytics
@MainActor
class ProcessingMonitor {
    static let shared = ProcessingMonitor()

    // Loggers
    private let performanceLogger = Logger(subsystem: "com.rationaledesign.heirloom.videolab", category: "performance")
    private let costLogger = Logger(subsystem: "com.rationaledesign.heirloom.videolab", category: "cost")
    private let errorLogger = Logger(subsystem: "com.rationaledesign.heirloom.videolab", category: "error")

    // Session tracking
    private var currentSession: ProcessingSession?
    private var sessionsHistory: [ProcessingSession] = []

    private init() {}

    // MARK: - Session Management

    func startSession(videoURL: URL) -> String {
        let sessionID = UUID().uuidString
        let session = ProcessingSession(
            id: sessionID,
            videoURL: videoURL,
            startTime: Date()
        )

        currentSession = session
        performanceLogger.info("📹 Session started: \(sessionID)")

        return sessionID
    }

    func endSession(sessionID: String, result: ProcessingResult) {
        guard let session = currentSession, session.id == sessionID else {
            errorLogger.warning("⚠️ Session \(sessionID) not found or already ended")
            return
        }

        var completedSession = session
        completedSession.endTime = Date()
        completedSession.result = result

        sessionsHistory.append(completedSession)
        currentSession = nil

        logSessionSummary(completedSession)
    }

    // MARK: - Stage Tracking

    func startStage(_ stage: ProcessingStage) {
        guard var session = currentSession else { return }

        session.currentStage = stage
        session.stageStartTimes[stage] = Date()
        currentSession = session

        performanceLogger.debug("▶️ Stage started: \(stage.rawValue)")
    }

    func endStage(_ stage: ProcessingStage, success: Bool = true) {
        guard var session = currentSession else { return }
        guard let startTime = session.stageStartTimes[stage] else { return }

        let duration = Date().timeIntervalSince(startTime)
        session.stageDurations[stage] = duration
        currentSession = session

        if success {
            performanceLogger.info("✅ Stage completed: \(stage.rawValue) in \(String(format: "%.2f", duration))s")
        } else {
            performanceLogger.warning("❌ Stage failed: \(stage.rawValue) after \(String(format: "%.2f", duration))s")
        }

        // Check for performance issues
        if let threshold = stage.expectedDuration, duration > threshold * 1.5 {
            performanceLogger.warning("⚠️ Stage \(stage.rawValue) took \(String(format: "%.1f", duration / threshold))x longer than expected")
        }
    }

    // MARK: - Cost Tracking

    func recordCost(_ cost: Decimal, component: CostComponent, details: CostDetails? = nil) {
        guard var session = currentSession else { return }

        session.totalCost += cost
        session.costBreakdown[component] = (session.costBreakdown[component] ?? 0) + cost
        currentSession = session

        costLogger.info("💰 \(component.rawValue): $\(cost.formatted()) \(details?.description ?? "")")

        // Alert if cost exceeds threshold
        if session.totalCost > 0.10 {  // Alert if >10 cents
            costLogger.warning("⚠️ Session cost exceeds $0.10: $\(session.totalCost.formatted())")
        }
    }

    func recordTokenUsage(inputTokens: Int, outputTokens: Int, model: String) {
        let cost = calculateTokenCost(inputTokens: inputTokens, outputTokens: outputTokens, model: model)

        let details = CostDetails(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            model: model
        )

        recordCost(cost, component: .recipeStructuring, details: details)
    }

    private func calculateTokenCost(inputTokens: Int, outputTokens: Int, model: String) -> Decimal {
        // Claude 3.5 Sonnet pricing (as of Jan 2026)
        let inputCostPerMillion: Decimal = 3.00
        let outputCostPerMillion: Decimal = 15.00

        let inputCost = Decimal(inputTokens) * inputCostPerMillion / 1_000_000
        let outputCost = Decimal(outputTokens) * outputCostPerMillion / 1_000_000

        return inputCost + outputCost
    }

    // MARK: - Error Tracking

    func recordError(_ error: Error, stage: ProcessingStage, context: [String: String] = [:]) {
        guard var session = currentSession else { return }

        let errorEvent = ErrorEvent(
            error: error,
            stage: stage,
            timestamp: Date(),
            context: context
        )

        session.errors.append(errorEvent)
        currentSession = session

        errorLogger.error("❌ Error in \(stage.rawValue): \(error.localizedDescription)")

        // Log context if present
        if !context.isEmpty {
            errorLogger.debug("Context: \(context.debugDescription)")
        }
    }

    // MARK: - Performance Metrics

    func recordMetric(_ metric: PerformanceMetric, value: Double, unit: String = "") {
        guard var session = currentSession else { return }

        session.metrics[metric] = value
        currentSession = session

        performanceLogger.debug("📊 \(metric.rawValue): \(String(format: "%.2f", value))\(unit)")

        // Check thresholds
        if let threshold = metric.threshold, value > threshold {
            performanceLogger.warning("⚠️ \(metric.rawValue) exceeds threshold: \(String(format: "%.2f", value))\(unit) > \(threshold)\(unit)")
        }
    }

    // MARK: - Analytics

    func getSessionSummary() -> SessionSummary? {
        guard let session = currentSession else { return nil }

        return SessionSummary(
            sessionID: session.id,
            videoDuration: session.metrics[.videoDuration] ?? 0,
            processingTime: session.endTime?.timeIntervalSince(session.startTime) ?? Date().timeIntervalSince(session.startTime),
            totalCost: session.totalCost,
            costBreakdown: session.costBreakdown,
            stageDurations: session.stageDurations,
            errors: session.errors,
            success: session.result?.success ?? false
        )
    }

    func getAggregateStats() -> AggregateStats {
        let completedSessions = sessionsHistory.filter { $0.result?.success == true }

        let totalCost = completedSessions.reduce(Decimal(0)) { $0 + $1.totalCost }
        let totalProcessingTime = completedSessions.reduce(0.0) { $0 + ($1.endTime?.timeIntervalSince($1.startTime) ?? 0) }
        let avgCost = completedSessions.isEmpty ? Decimal(0) : totalCost / Decimal(completedSessions.count)
        let avgTime = completedSessions.isEmpty ? 0.0 : totalProcessingTime / Double(completedSessions.count)

        return AggregateStats(
            totalVideosProcessed: completedSessions.count,
            totalCost: totalCost,
            averageCost: avgCost,
            averageProcessingTime: avgTime,
            successRate: Double(completedSessions.count) / Double(max(sessionsHistory.count, 1))
        )
    }

    // MARK: - Logging

    private func logSessionSummary(_ session: ProcessingSession) {
        guard let result = session.result,
              let endTime = session.endTime else { return }

        let duration = endTime.timeIntervalSince(session.startTime)

        performanceLogger.info("""
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        📊 Session Summary: \(session.id)
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        Status:          \(result.success ? "✅ Success" : "❌ Failed")
        Total Time:      \(String(format: "%.1f", duration))s
        Total Cost:      $\(session.totalCost.formatted())

        Stage Durations:
        \(self.formatStageDurations(session.stageDurations))

        Cost Breakdown:
        \(self.formatCostBreakdown(session.costBreakdown))

        Errors:          \(session.errors.count)
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """)

        // Log aggregate stats
        let stats = getAggregateStats()
        costLogger.info("📈 Aggregate: \(stats.totalVideosProcessed) videos processed, avg cost: $\(stats.averageCost.formatted())")
    }

    private func formatStageDurations(_ durations: [ProcessingStage: TimeInterval]) -> String {
        durations.sorted(by: { $0.value > $1.value })
            .map { "  • \($0.key.rawValue): \(String(format: "%.1f", $0.value))s" }
            .joined(separator: "\n")
    }

    private func formatCostBreakdown(_ breakdown: [CostComponent: Decimal]) -> String {
        breakdown.sorted(by: { $0.value > $1.value })
            .map { "  • \($0.key.rawValue): $\($0.value.formatted())" }
            .joined(separator: "\n")
    }

    // MARK: - Export

    func exportSessionData(sessionID: String) -> Data? {
        guard let session = sessionsHistory.first(where: { $0.id == sessionID }) else {
            return nil
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        return try? encoder.encode(session)
    }

    func exportAggregateStats() -> Data? {
        let stats = getAggregateStats()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        return try? encoder.encode(stats)
    }
}

// MARK: - Data Models

struct ProcessingSession: Codable {
    let id: String
    let videoURL: URL
    let startTime: Date
    var endTime: Date?
    var currentStage: ProcessingStage?

    var totalCost: Decimal = 0
    var costBreakdown: [CostComponent: Decimal] = [:]

    var stageStartTimes: [ProcessingStage: Date] = [:]
    var stageDurations: [ProcessingStage: TimeInterval] = [:]

    var metrics: [PerformanceMetric: Double] = [:]
    var errors: [ErrorEvent] = []

    var result: ProcessingResult?
}

struct ProcessingResult: Codable {
    let success: Bool
    let recipeTitle: String?
    let confidence: Double?
    let ingredientsCount: Int?
    let stepsCount: Int?
}

enum ProcessingStage: String, Codable {
    case audioExtraction = "Audio Extraction"
    case transcription = "Transcription"
    case frameAnalysis = "Frame Analysis"
    case recipeStructuring = "Recipe Structuring"

    var expectedDuration: TimeInterval? {
        switch self {
        case .audioExtraction: return 10.0      // 10 seconds
        case .transcription: return 120.0       // 2 minutes
        case .frameAnalysis: return 20.0        // 20 seconds
        case .recipeStructuring: return 10.0    // 10 seconds
        }
    }
}

enum CostComponent: String, Codable {
    case audioExtraction = "Audio Extraction"
    case transcription = "Transcription"
    case frameAnalysis = "Frame Analysis"
    case recipeStructuring = "Recipe Structuring"
}

struct CostDetails: CustomStringConvertible {
    let inputTokens: Int?
    let outputTokens: Int?
    let model: String?

    var description: String {
        if let input = inputTokens, let output = outputTokens {
            return "(\(input) in, \(output) out)"
        }
        return ""
    }
}

struct ErrorEvent: Codable {
    let error: String
    let stage: ProcessingStage
    let timestamp: Date
    let context: [String: String]

    init(error: Error, stage: ProcessingStage, timestamp: Date, context: [String: String]) {
        self.error = error.localizedDescription
        self.stage = stage
        self.timestamp = timestamp
        self.context = context
    }
}

enum PerformanceMetric: String, Codable {
    case videoDuration = "Video Duration"
    case audioFileSize = "Audio File Size"
    case transcriptLength = "Transcript Length"
    case frameCount = "Frame Count"
    case peakMemoryUsage = "Peak Memory (MB)"

    var threshold: Double? {
        switch self {
        case .peakMemoryUsage: return 500.0  // 500MB
        default: return nil
        }
    }
}

struct SessionSummary: Codable {
    let sessionID: String
    let videoDuration: TimeInterval
    let processingTime: TimeInterval
    let totalCost: Decimal
    let costBreakdown: [CostComponent: Decimal]
    let stageDurations: [ProcessingStage: TimeInterval]
    let errors: [ErrorEvent]
    let success: Bool

    var costPerMinute: Decimal {
        guard videoDuration > 0 else { return 0 }
        return totalCost / Decimal(videoDuration / 60.0)
    }

    var processingRatio: Double {
        guard videoDuration > 0 else { return 0 }
        return processingTime / videoDuration
    }
}

struct AggregateStats: Codable {
    let totalVideosProcessed: Int
    let totalCost: Decimal
    let averageCost: Decimal
    let averageProcessingTime: TimeInterval
    let successRate: Double

    var formattedStats: String {
        """
        Total Videos: \(totalVideosProcessed)
        Total Cost: $\(totalCost.formatted())
        Avg Cost/Video: $\(averageCost.formatted())
        Avg Processing Time: \(String(format: "%.1f", averageProcessingTime))s
        Success Rate: \(String(format: "%.1f", successRate * 100))%
        """
    }
}

// MARK: - Decimal Extensions

extension Decimal {
    func formatted() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return formatter.string(from: self as NSDecimalNumber) ?? "0.00"
    }
}

// MARK: - Integration with VideoRecipeProcessor
// TODO: Re-enable after making VideoRecipeProcessor properties accessible
/*
extension VideoRecipeProcessor {
    /// Wrap processing with monitoring
    func processWithMonitoring(videoURL: URL) async throws -> VideoRecipeExtraction {
        let monitor = ProcessingMonitor.shared
        let sessionID = monitor.startSession(videoURL: videoURL)

        do {
            // Audio extraction
            monitor.startStage(.audioExtraction)
            let audioURL = try await audioExtractor.extractAudio(from: videoURL)
            monitor.endStage(.audioExtraction, success: true)

            // Record metrics
            let videoDuration = await audioExtractor.estimateDuration(videoURL) ?? 0
            monitor.recordMetric(.videoDuration, value: videoDuration)

            // Transcription
            monitor.startStage(.transcription)
            let transcript = try await transcriptionService.transcribe(audioURL: audioURL)
            monitor.endStage(.transcription, success: true)
            monitor.recordMetric(.transcriptLength, value: Double(transcript.text.count))

            // Frame analysis (optional)
            var visualElements: [String] = []
            if shouldPerformFrameAnalysis(transcriptConfidence: transcript.confidence) {
                monitor.startStage(.frameAnalysis)
                do {
                    let frames = try await frameAnalyzer.extractKeyFrames(from: videoURL, count: 5)
                    visualElements = try await frameAnalyzer.analyzeForRecipeElements(frames)
                    monitor.endStage(.frameAnalysis, success: true)
                    monitor.recordMetric(.frameCount, value: Double(frames.count))
                } catch {
                    monitor.endStage(.frameAnalysis, success: false)
                    monitor.recordError(error, stage: .frameAnalysis)
                }
            }

            // Recipe structuring
            monitor.startStage(.recipeStructuring)
            let structuredRecipe = try await recipeStructurer.structure(
                transcript: transcript,
                visualElements: visualElements
            )
            monitor.endStage(.recipeStructuring, success: true)

            // Calculate cost
            let cost = calculateCost(transcriptLength: transcript.text.count, usedFrameAnalysis: !visualElements.isEmpty)
            monitor.recordCost(cost, component: .recipeStructuring)

            // Record memory if available
            let memoryUsage = getMemoryUsage()
            monitor.recordMetric(.peakMemoryUsage, value: memoryUsage)

            // Create extraction (same as before)
            let extraction = VideoRecipeExtraction(/* ... */)

            // End session
            let result = ProcessingResult(
                success: true,
                recipeTitle: structuredRecipe.title,
                confidence: structuredRecipe.overallConfidence,
                ingredientsCount: structuredRecipe.ingredients.count,
                stepsCount: structuredRecipe.steps.count
            )
            monitor.endSession(sessionID: sessionID, result: result)

            return extraction

        } catch {
            // Record error and end session
            if let stage = monitor.getSessionSummary()?.stageDurations.keys.last {
                monitor.recordError(error, stage: stage ?? .audioExtraction)
            }

            let result = ProcessingResult(
                success: false,
                recipeTitle: nil,
                confidence: nil,
                ingredientsCount: nil,
                stepsCount: nil
            )
            monitor.endSession(sessionID: sessionID, result: result)

            throw error
        }
    }

    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / 1024.0 / 1024.0  // Convert to MB
    }
}
*/
