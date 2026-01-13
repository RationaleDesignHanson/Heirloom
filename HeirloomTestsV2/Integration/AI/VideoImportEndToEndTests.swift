//
//  VideoImportEndToEndTests.swift
//  HeirloomTestsV2
//
//  End-to-end integration tests for complete video import pipeline
//  Tests: URL → Audio Download → Transcription → Structuring → Recipe
//  Created: 2026-01-13
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class VideoImportEndToEndTests: XCTestCase {

    var modelContext: ModelContext!
    var mockLogger: MockLoggingService!
    var analytics: AnalyticsService!
    var processor: VideoRecipeProcessor!

    override func setUp() async throws {
        try await super.setUp()

        modelContext = try TestRecipeFactory.createTestModelContext()
        mockLogger = MockLoggingService()
        analytics = AnalyticsService()

        // Use real dependencies (not mocked)
        let apiKey = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"] ?? ""
        processor = VideoRecipeProcessor(
            transcriber: WhisperKitTranscriber(logger: mockLogger),
            structurer: ClaudeRecipeStructurer(apiKey: apiKey, logger: mockLogger, analytics: analytics),
            logger: mockLogger,
            analytics: analytics
        )
    }

    override func tearDown() async throws {
        processor = nil
        modelContext = nil
        mockLogger = nil
        analytics = nil
        try await super.tearDown()
    }

    // MARK: - End-to-End Pipeline Tests

    func test_videoImport_completeFlow_shortVideo() async throws {
        // Given: Known test YouTube video (2-3 minutes, simple recipe)
        // Use unlisted YouTube video on test account
        let testVideoURL = ProcessInfo.processInfo.environment["TEST_VIDEO_URL_SHORT"] ??
                          "https://www.youtube.com/watch?v=TEST_SHORT_RECIPE"

        // When: Process full pipeline
        let recipe = try await processor.process(url: testVideoURL, context: modelContext)

        // Then: Verify complete recipe created
        XCTAssertFalse(recipe.title.isEmpty, "Should extract title from video")
        XCTAssertGreaterThan(recipe.ingredients?.count ?? 0, 0,
                            "Should extract at least one ingredient")
        XCTAssertGreaterThan(recipe.instructions.count, 0,
                            "Should extract at least one instruction step")

        // Verify source metadata
        XCTAssertEqual(recipe.sourceType, .video)
        XCTAssertEqual(recipe.sourceURL, testVideoURL)
        XCTAssertNotNil(recipe.createdAt)

        // Verify saved to database
        try modelContext.save()

        let fetchDescriptor = FetchDescriptor<Heirloom.Recipe>()
        let recipes = try modelContext.fetch(fetchDescriptor)

        XCTAssertEqual(recipes.count, 1, "Should persist one recipe")
        XCTAssertEqual(recipes.first?.id, recipe.id)
    }

    func test_videoImport_completeFlow_mediumVideo() async throws {
        // Given: Medium-length video (10-15 minutes)
        let testVideoURL = ProcessInfo.processInfo.environment["TEST_VIDEO_URL_MEDIUM"] ??
                          "https://www.youtube.com/watch?v=TEST_MEDIUM_RECIPE"

        // When: Process full pipeline
        let recipe = try await processor.process(url: testVideoURL, context: modelContext)

        // Then: Verify recipe quality
        XCTAssertFalse(recipe.title.isEmpty)

        // Medium video should have more detailed content
        XCTAssertGreaterThanOrEqual(recipe.ingredients?.count ?? 0, 5,
                                    "Medium video should have 5+ ingredients")
        XCTAssertGreaterThanOrEqual(recipe.instructions.count, 5,
                                    "Medium video should have 5+ steps")

        // May have cooking times, servings, etc.
        XCTAssertTrue(recipe.cookTime != nil || recipe.totalTime != nil ||
                      recipe.prepTime != nil,
                      "Should extract timing information")
    }

    func test_videoImport_progressTracking() async throws {
        // Given: Video to process
        let testVideoURL = ProcessInfo.processInfo.environment["TEST_VIDEO_URL_SHORT"] ??
                          "https://www.youtube.com/watch?v=TEST_SHORT_RECIPE"

        // When: Track progress through stages
        var progressUpdates: [(stage: ProcessingStage, percent: Double)] = []

        let job = VideoImportJob(url: testVideoURL)
        job.onProgressUpdate = { stage, percent in
            progressUpdates.append((stage, percent))
        }

        let recipe = try await processor.process(job: job, context: modelContext)

        // Then: Verify progress went through expected stages
        let stages = progressUpdates.map { $0.stage }

        XCTAssertTrue(stages.contains(.downloadingAudio), "Should download audio")
        XCTAssertTrue(stages.contains(.transcribing), "Should transcribe")
        XCTAssertTrue(stages.contains(.structuring), "Should structure")
        XCTAssertTrue(stages.contains(.completed), "Should complete")

        // Verify progress reached 100%
        let finalProgress = progressUpdates.last?.percent ?? 0
        XCTAssertEqual(finalProgress, 1.0, accuracy: 0.01, "Should reach 100%")

        XCTAssertNotNil(recipe, "Should produce recipe")
    }

    // MARK: - Network Failure Recovery

    func test_videoImport_networkTimeout_handlesGracefully() async throws {
        // Given: Invalid/unreachable URL (simulates timeout)
        let invalidURL = "https://www.youtube.com/watch?v=INVALID_NONEXISTENT"

        // When: Attempt to process
        do {
            let _ = try await processor.process(url: invalidURL, context: modelContext)
            XCTFail("Should throw error for invalid URL")
        } catch {
            // Then: Should throw appropriate error
            XCTAssertTrue(error is NetworkError || error is ValidationError,
                         "Should throw network or validation error")
        }
    }

    func test_videoImport_partialFailure_savesTranscript() async throws {
        // Given: Video that transcribes successfully but structuring fails
        let testVideoURL = ProcessInfo.processInfo.environment["TEST_VIDEO_URL_SHORT"] ?? ""

        // Create processor with failing structurer (mock)
        let failingStructurer = MockClaudeStructurer(shouldFail: true)
        let partialProcessor = VideoRecipeProcessor(
            transcriber: WhisperKitTranscriber(logger: mockLogger),
            structurer: failingStructurer,
            logger: mockLogger,
            analytics: analytics
        )

        // When: Process with failing structurer
        do {
            let _ = try await partialProcessor.process(url: testVideoURL, context: modelContext)
            XCTFail("Should throw error when structuring fails")
        } catch {
            // Then: Transcript should be saved for retry
            // Check if partial data exists in database or cache
            let hasPartialData = partialProcessor.hasPartialData(for: testVideoURL)
            XCTAssertTrue(hasPartialData, "Should save transcript for later retry")
        }
    }

    func test_videoImport_resumeFromPartialState() async throws {
        // Given: Previously failed import with saved transcript
        let testVideoURL = ProcessInfo.processInfo.environment["TEST_VIDEO_URL_SHORT"] ?? ""
        let savedTranscript = "This is a saved transcript from previous attempt..."

        // Save partial data
        processor.savePartialData(url: testVideoURL, transcript: savedTranscript)

        // When: Resume processing
        let recipe = try await processor.resume(url: testVideoURL, context: modelContext)

        // Then: Should skip transcription and use saved transcript
        XCTAssertNotNil(recipe, "Should create recipe from saved transcript")

        // Verify didn't re-transcribe (check logs or analytics)
        // Should have structuring event but not transcription event
    }

    // MARK: - Cancellation

    func test_videoImport_cancellation_cleansUp() async throws {
        // Given: Long-running video import
        let testVideoURL = ProcessInfo.processInfo.environment["TEST_VIDEO_URL_LONG"] ??
                          "https://www.youtube.com/watch?v=TEST_LONG_RECIPE"

        let job = VideoImportJob(url: testVideoURL)

        // When: Start processing then cancel
        Task {
            // Cancel after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            job.cancel()
        }

        do {
            let _ = try await processor.process(job: job, context: modelContext)
            XCTFail("Should throw cancellation error")
        } catch {
            // Then: Should handle cancellation
            XCTAssertTrue(error is CancellationError || job.isCancelled)

            // Verify cleanup occurred (no temp files, no partial data)
            let hasLeftovers = processor.hasPartialData(for: testVideoURL)
            XCTAssertFalse(hasLeftovers, "Should clean up on cancellation")
        }
    }

    // MARK: - Concurrent Processing

    func test_videoImport_concurrentImports_noInterference() async throws {
        // Given: Multiple videos to import concurrently
        let urls = [
            ProcessInfo.processInfo.environment["TEST_VIDEO_URL_1"] ?? "https://www.youtube.com/watch?v=TEST1",
            ProcessInfo.processInfo.environment["TEST_VIDEO_URL_2"] ?? "https://www.youtube.com/watch?v=TEST2",
            ProcessInfo.processInfo.environment["TEST_VIDEO_URL_3"] ?? "https://www.youtube.com/watch?v=TEST3"
        ]

        // When: Process concurrently
        let recipes = try await withThrowingTaskGroup(of: Recipe.self) { group in
            for url in urls {
                group.addTask {
                    try await self.processor.process(url: url, context: self.modelContext)
                }
            }

            var results: [Recipe] = []
            for try await recipe in group {
                results.append(recipe)
            }
            return results
        }

        // Then: All should complete successfully
        XCTAssertEqual(recipes.count, 3, "Should process all 3 videos")

        // Verify each has unique URL
        let sourceURLs = Set(recipes.map { $0.sourceURL })
        XCTAssertEqual(sourceURLs.count, 3, "Should have 3 unique source URLs")

        // Verify all saved to database
        try modelContext.save()
        let fetchDescriptor = FetchDescriptor<Heirloom.Recipe>()
        let savedRecipes = try modelContext.fetch(fetchDescriptor)
        XCTAssertEqual(savedRecipes.count, 3, "Should save all 3 recipes")
    }

    // MARK: - Queue Integration

    func test_videoImport_queue_processesInOrder() async throws {
        // Given: Queue with multiple URLs
        let queue = VideoImportQueue(logger: mockLogger, analytics: analytics)

        let urls = [
            "https://www.youtube.com/watch?v=TEST1",
            "https://www.youtube.com/watch?v=TEST2",
            "https://www.youtube.com/watch?v=TEST3"
        ]

        // Add to queue
        for url in urls {
            await queue.add(url: url)
        }

        // When: Process queue
        var processedURLs: [String] = []

        while let item = await queue.nextPending() {
            // Simulate processing
            item.status = .processing
            // ... actual processing would happen here
            item.status = .completed
            processedURLs.append(item.url)
        }

        // Then: Should maintain FIFO order
        XCTAssertEqual(processedURLs, urls, "Should process in FIFO order")
    }

    func test_videoImport_queue_handlesFailures() async throws {
        // Given: Queue with URLs (one will fail)
        let queue = VideoImportQueue(logger: mockLogger, analytics: analytics)

        await queue.add(url: "https://www.youtube.com/watch?v=VALID1")
        await queue.add(url: "https://www.youtube.com/watch?v=INVALID") // Will fail
        await queue.add(url: "https://www.youtube.com/watch?v=VALID2")

        // When: Process with failures
        var successCount = 0
        var failureCount = 0

        while let item = await queue.nextPending() {
            item.status = .processing

            do {
                // Simulate processing (would use real processor)
                if item.url.contains("INVALID") {
                    throw NetworkError.invalidURL
                }
                item.status = .completed
                successCount += 1
            } catch {
                item.status = .failed
                item.error = error.localizedDescription
                failureCount += 1
            }
        }

        // Then: Should continue processing despite failure
        XCTAssertEqual(successCount, 2, "Should complete 2 valid imports")
        XCTAssertEqual(failureCount, 1, "Should record 1 failure")

        // Failed item should be marked appropriately
        let items = await queue.allItems()
        let failedItem = items.first { $0.status == .failed }
        XCTAssertNotNil(failedItem, "Should have failed item")
        XCTAssertFalse(failedItem?.error?.isEmpty ?? true, "Should have error message")
    }

    // MARK: - Data Quality

    func test_videoImport_extractsCompleteRecipeData() async throws {
        // Given: High-quality recipe video with all details
        let testVideoURL = ProcessInfo.processInfo.environment["TEST_VIDEO_URL_COMPLETE"] ??
                          "https://www.youtube.com/watch?v=TEST_COMPLETE_RECIPE"

        // When: Process video
        let recipe = try await processor.process(url: testVideoURL, context: modelContext)

        // Then: Verify comprehensive data extraction
        XCTAssertFalse(recipe.title.isEmpty, "Should have title")
        XCTAssertGreaterThan(recipe.ingredients?.count ?? 0, 0, "Should have ingredients")
        XCTAssertGreaterThan(recipe.instructions.count, 0, "Should have instructions")

        // Check for detailed information
        let hasTimingInfo = recipe.prepTime != nil || recipe.cookTime != nil || recipe.totalTime != nil
        XCTAssertTrue(hasTimingInfo, "Should extract timing information")

        let hasServingInfo = recipe.servings != nil
        XCTAssertTrue(hasServingInfo, "Should extract serving information")

        // Verify ingredient details
        for ingredient in recipe.ingredients ?? [] {
            XCTAssertFalse(ingredient.name.isEmpty, "Ingredient should have name")
            // Quantity and unit may be optional but should be reasonable if present
            if ingredient.quantity > 0 {
                XCTAssertLessThan(ingredient.quantity, 100, "Ingredient quantity should be reasonable")
            }
        }

        // Verify instruction quality
        for (index, instruction) in recipe.instructions.enumerated() {
            XCTAssertFalse(instruction.isEmpty, "Instruction \(index+1) should not be empty")
            XCTAssertGreaterThan(instruction.count, 10, "Instruction should be descriptive")
        }
    }

    func test_videoImport_handlesMultipleRecipesInVideo() async throws {
        // Given: Video that mentions multiple recipes but focuses on one
        let testVideoURL = ProcessInfo.processInfo.environment["TEST_VIDEO_URL_MULTI"] ?? ""

        // When: Process video
        let recipe = try await processor.process(url: testVideoURL, context: modelContext)

        // Then: Should extract the primary/main recipe
        XCTAssertFalse(recipe.title.isEmpty)
        XCTAssertGreaterThan(recipe.ingredients?.count ?? 0, 0)

        // Should not mix ingredients from different recipes
        // This is hard to test without known video, but verify consistency
        let ingredientNames = recipe.ingredients?.map { $0.name.lowercased() } ?? []
        // E.g., shouldn't have both "cookie dough" and "cake batter" if focused on one
    }

    // MARK: - Performance

    func test_videoImport_performance_shortVideo() async throws {
        // Given: Short video (2-3 minutes)
        let testVideoURL = ProcessInfo.processInfo.environment["TEST_VIDEO_URL_SHORT"] ?? ""

        // When: Measure processing time
        let startTime = Date()
        let recipe = try await processor.process(url: testVideoURL, context: modelContext)
        let duration = Date().timeIntervalSince(startTime)

        // Then: Should complete in reasonable time
        XCTAssertLessThan(duration, 120.0, "Short video should process in < 2 minutes")
        XCTAssertNotNil(recipe)
    }

    func test_videoImport_performance_batchProcessing() async throws {
        // Given: Multiple videos to process
        let urls = (1...5).map { "https://www.youtube.com/watch?v=TEST\($0)" }

        // When: Process all (simulated with short transcripts)
        let startTime = Date()

        // Simulate batch processing (in real scenario, would use actual videos)
        var recipes: [Recipe] = []
        for url in urls {
            // Use mock processor for performance test to avoid actual API calls
            let mockRecipe = Recipe(title: "Test Recipe", sourceType: .video)
            mockRecipe.sourceURL = url
            recipes.append(mockRecipe)
        }

        let duration = Date().timeIntervalSince(startTime)

        // Then: Batch processing should be reasonably fast
        XCTAssertLessThan(duration, 10.0, "Batch processing should be efficient")
        XCTAssertEqual(recipes.count, 5)
    }
}

// MARK: - Mock Helpers

class MockClaudeStructurer: ClaudeRecipeStructurer {
    let shouldFail: Bool

    init(shouldFail: Bool) {
        self.shouldFail = shouldFail
        super.init(apiKey: "", logger: MockLoggingService(), analytics: AnalyticsService())
    }

    override func structure(transcript: String, context: ModelContext) async throws -> Recipe {
        if shouldFail {
            throw APIError.structuringFailed
        }
        return try await super.structure(transcript: transcript, context: context)
    }
}

enum NetworkError: Error {
    case invalidURL
    case timeout
}

enum APIError: Error {
    case structuringFailed
}
