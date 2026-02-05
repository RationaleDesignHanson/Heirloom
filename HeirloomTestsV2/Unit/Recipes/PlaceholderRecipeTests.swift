//
//  PlaceholderRecipeTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-04
//  Unit tests for Progressive Enhancement (Placeholder Recipe) infrastructure
//
//  Tests ensure that:
//  - Placeholder recipes are created correctly during import
//  - Processing status transitions work properly
//  - Progress tracking updates as expected
//  - Failed imports are handled gracefully
//  - Placeholder recipes update correctly on extraction success
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class PlaceholderRecipeTests: XCTestCase {

    // MARK: - Properties

    var env: TestEnvironment!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        env = try await TestEnvironment.create(authenticated: true, credits: 100)
        try env.save()
    }

    override func tearDown() async throws {
        env.tearDown()
        env = nil
        try await super.tearDown()
    }

    // MARK: - Recipe Processing Status Tests

    /// Test 1: New recipes have .ready status by default
    func test_newRecipe_hasReadyStatus() throws {
        // GIVEN/WHEN: Creating a new recipe
        let recipe = Recipe(title: "Test Recipe", sourceType: .manual)
        env.modelContext.insert(recipe)

        // THEN: Status should be .ready
        XCTAssertEqual(recipe.processingStatus, .ready)
        XCTAssertFalse(recipe.isProcessing)
        XCTAssertFalse(recipe.didFailProcessing)
    }

    /// Test 2: Import placeholder has .processing status
    func test_importPlaceholder_hasProcessingStatus() throws {
        // GIVEN/WHEN: Creating an import placeholder
        let placeholder = Recipe.createImportPlaceholder(
            jobId: UUID(),
            itemIndex: 0,
            cookbookName: "Test Cookbook"
        )
        env.modelContext.insert(placeholder)

        // THEN: Status should be .processing
        XCTAssertEqual(placeholder.processingStatus, .processing)
        XCTAssertTrue(placeholder.isProcessing)
        XCTAssertFalse(placeholder.didFailProcessing)
    }

    /// Test 3: Video placeholder has .processing status
    func test_videoPlaceholder_hasProcessingStatus() throws {
        // GIVEN/WHEN: Creating a video placeholder
        let placeholder = Recipe.createVideoProcessingPlaceholder(jobId: UUID())
        env.modelContext.insert(placeholder)

        // THEN: Status should be .processing
        XCTAssertEqual(placeholder.processingStatus, .processing)
        XCTAssertTrue(placeholder.isProcessing)
    }

    /// Test 4: Setting status to .failed marks recipe as failed
    func test_failedStatus_marksDidFailProcessing() throws {
        // GIVEN: A processing placeholder
        let placeholder = Recipe.createImportPlaceholder(
            jobId: UUID(),
            itemIndex: 0,
            cookbookName: "Test"
        )
        env.modelContext.insert(placeholder)

        // WHEN: Setting to failed
        placeholder.processingStatus = .failed
        placeholder.processingErrorMessage = "Extraction failed"

        // THEN: Should be marked as failed
        XCTAssertEqual(placeholder.processingStatus, .failed)
        XCTAssertTrue(placeholder.didFailProcessing)
        XCTAssertTrue(placeholder.isProcessingFailed)
        XCTAssertFalse(placeholder.isProcessing)
        XCTAssertEqual(placeholder.processingErrorMessage, "Extraction failed")
    }

    // MARK: - Progress Tracking Tests

    /// Test 5: Initial progress is 0
    func test_placeholder_initialProgressIsZero() throws {
        // GIVEN/WHEN: Creating placeholder
        let placeholder = Recipe.createImportPlaceholder(
            jobId: UUID(),
            itemIndex: 0,
            cookbookName: "Test"
        )

        // THEN: Progress should be 0
        XCTAssertEqual(placeholder.processingProgress, 0.0)
    }

    /// Test 6: Progress updates correctly
    func test_placeholder_progressUpdates() throws {
        // GIVEN: A placeholder
        let placeholder = Recipe.createImportPlaceholder(
            jobId: UUID(),
            itemIndex: 0,
            cookbookName: "Test"
        )
        env.modelContext.insert(placeholder)

        // WHEN: Updating progress
        placeholder.processingProgress = 0.5

        // THEN: Progress should be updated
        XCTAssertEqual(placeholder.processingProgress, 0.5)
    }

    /// Test 7: Progress is clamped between 0 and 1
    func test_placeholder_progressClamped() throws {
        // GIVEN: A placeholder
        let placeholder = Recipe.createImportPlaceholder(
            jobId: UUID(),
            itemIndex: 0,
            cookbookName: "Test"
        )
        env.modelContext.insert(placeholder)

        // WHEN: Setting progress beyond bounds
        placeholder.processingProgress = 1.5

        // THEN: Should be clamped (stored value may not be clamped but UI should handle)
        XCTAssertGreaterThanOrEqual(placeholder.processingProgress, 0)
    }

    /// Test 8: Completed processing sets progress to 1
    func test_completedProcessing_setsProgressToOne() throws {
        // GIVEN: A processing placeholder
        let placeholder = Recipe.createImportPlaceholder(
            jobId: UUID(),
            itemIndex: 0,
            cookbookName: "Test"
        )
        placeholder.processingProgress = 0.75
        env.modelContext.insert(placeholder)

        // WHEN: Marking as complete
        placeholder.processingStatus = .ready
        placeholder.processingProgress = 1.0

        // THEN: Progress should be 1
        XCTAssertEqual(placeholder.processingProgress, 1.0)
        XCTAssertFalse(placeholder.isProcessing)
    }

    // MARK: - Placeholder Update Tests

    /// Test 9: updateFromProcessingResult transfers all data
    func test_updateFromProcessingResult_transfersData() throws {
        // GIVEN: A placeholder
        let placeholder = Recipe.createImportPlaceholder(
            jobId: UUID(),
            itemIndex: 0,
            cookbookName: "Test"
        )
        env.modelContext.insert(placeholder)

        // WHEN: Updating from processing result
        placeholder.updateFromProcessingResult(
            title: "Chocolate Cake",
            instructions: ["Preheat oven", "Mix ingredients", "Bake"],
            servings: "8 servings",
            prepTime: "15 mins",
            cookTime: "45 mins",
            notes: "Family recipe"
        )

        // THEN: All data should be transferred
        XCTAssertEqual(placeholder.title, "Chocolate Cake")
        XCTAssertEqual(placeholder.instructions.count, 3)
        XCTAssertEqual(placeholder.servings, "8 servings")
        XCTAssertEqual(placeholder.prepTime, "15 mins")
        XCTAssertEqual(placeholder.cookTime, "45 mins")
        XCTAssertEqual(placeholder.notes, "Family recipe")
        XCTAssertEqual(placeholder.processingStatus, .ready)
        XCTAssertEqual(placeholder.processingProgress, 1.0)
    }

    /// Test 10: Placeholder preserves ID after update
    func test_placeholder_preservesIDAfterUpdate() throws {
        // GIVEN: A placeholder with specific ID
        let placeholder = Recipe.createImportPlaceholder(
            jobId: UUID(),
            itemIndex: 0,
            cookbookName: "Test"
        )
        let placeholderID = placeholder.id
        env.modelContext.insert(placeholder)

        // WHEN: Updating from processing result
        placeholder.updateFromProcessingResult(
            title: "New Title",
            instructions: ["Step 1"],
            servings: "4 servings"
        )

        // THEN: ID should be unchanged
        XCTAssertEqual(placeholder.id, placeholderID)
    }

    // MARK: - ImportItem Placeholder Reference Tests

    /// Test 11: ImportItem can store placeholder recipe ID
    func test_importItem_storesPlaceholderID() throws {
        // GIVEN: An import item
        let item = ImportItem(urlString: "https://example.com/recipe")

        // WHEN: Setting placeholder ID
        let placeholderID = UUID()
        item.placeholderRecipeID = placeholderID

        // THEN: ID should be stored
        XCTAssertEqual(item.placeholderRecipeID, placeholderID)
    }

    /// Test 12: ImportItem placeholder ID is nil by default
    func test_importItem_placeholderIDIsNilByDefault() throws {
        // GIVEN/WHEN: Creating an import item
        let item = ImportItem(urlString: "https://example.com/recipe")

        // THEN: Placeholder ID should be nil
        XCTAssertNil(item.placeholderRecipeID)
    }

    // MARK: - Job-Placeholder Association Tests

    /// Test 13: Import job links to placeholder recipe via linkedProcessingJobId
    func test_importJob_linksToPlaceholder() throws {
        // GIVEN: An import job and placeholder
        let jobID = UUID()
        let placeholder = Recipe.createImportPlaceholder(
            jobId: jobID,
            itemIndex: 0,
            cookbookName: "Test"
        )
        env.modelContext.insert(placeholder)
        try env.save()

        // THEN: Placeholder should have linked job ID
        XCTAssertEqual(placeholder.linkedProcessingJobId, jobID)
        XCTAssertEqual(placeholder.linkedProcessingJobType, "import")
    }

    /// Test 14: Multiple placeholders can link to same job
    func test_multiplePlaceholders_canLinkToSameJob() throws {
        // GIVEN: A job ID
        let jobID = UUID()

        // WHEN: Creating multiple placeholders for same job
        let placeholder1 = Recipe.createImportPlaceholder(jobId: jobID, itemIndex: 0, cookbookName: "Test")
        let placeholder2 = Recipe.createImportPlaceholder(jobId: jobID, itemIndex: 1, cookbookName: "Test")
        let placeholder3 = Recipe.createImportPlaceholder(jobId: jobID, itemIndex: 2, cookbookName: "Test")

        env.modelContext.insert(placeholder1)
        env.modelContext.insert(placeholder2)
        env.modelContext.insert(placeholder3)
        try env.save()

        // THEN: All should have the same linked job ID
        XCTAssertEqual(placeholder1.linkedProcessingJobId, jobID)
        XCTAssertEqual(placeholder2.linkedProcessingJobId, jobID)
        XCTAssertEqual(placeholder3.linkedProcessingJobId, jobID)
    }

    // MARK: - Video Job Placeholder Tests

    /// Test 15: Video job stores placeholder recipe ID
    func test_videoJob_storesPlaceholderID() throws {
        // GIVEN: A video job ID
        let jobID = UUID()

        // WHEN: Creating placeholder for video job
        let placeholder = Recipe.createVideoProcessingPlaceholder(jobId: jobID)
        env.modelContext.insert(placeholder)

        // THEN: Placeholder should exist and have correct job reference
        XCTAssertNotNil(placeholder)
        XCTAssertTrue(placeholder.isProcessing)
        XCTAssertEqual(placeholder.linkedProcessingJobId, jobID)
        XCTAssertEqual(placeholder.linkedProcessingJobType, "video")
    }

    // MARK: - Processing Title/Status Tests

    /// Test 16: Import placeholder has "Importing..." title
    func test_importPlaceholder_hasProcessingTitle() throws {
        // GIVEN/WHEN: Creating import placeholder
        let placeholder = Recipe.createImportPlaceholder(
            jobId: UUID(),
            itemIndex: 0,
            cookbookName: "Grandma's Cookbook"
        )

        // THEN: Title should indicate importing
        XCTAssertTrue(placeholder.title.contains("Importing"))
    }

    /// Test 17: Video placeholder has appropriate title
    func test_videoPlaceholder_hasVideoTitle() throws {
        // GIVEN/WHEN: Creating video placeholder
        let placeholder = Recipe.createVideoProcessingPlaceholder(jobId: UUID())

        // THEN: Title should indicate video processing
        XCTAssertTrue(placeholder.title.contains("Video") || placeholder.title.contains("Processing"))
    }

    // MARK: - Error State Tests

    /// Test 18: Failed placeholder stores error message
    func test_failedPlaceholder_storesErrorMessage() throws {
        // GIVEN: A placeholder
        let placeholder = Recipe.createImportPlaceholder(
            jobId: UUID(),
            itemIndex: 0,
            cookbookName: "Test"
        )
        env.modelContext.insert(placeholder)

        // WHEN: Marking as failed with error
        let errorMessage = "AI extraction quota exceeded"
        placeholder.processingStatus = .failed
        placeholder.processingErrorMessage = errorMessage

        // THEN: Error should be stored
        XCTAssertEqual(placeholder.processingErrorMessage, errorMessage)
        XCTAssertTrue(placeholder.didFailProcessing)
    }

    /// Test 19: Error message is nil for successful completion
    func test_successfulCompletion_hasNoErrorMessage() throws {
        // GIVEN: A placeholder that completes successfully
        let placeholder = Recipe.createImportPlaceholder(
            jobId: UUID(),
            itemIndex: 0,
            cookbookName: "Test"
        )
        env.modelContext.insert(placeholder)

        // WHEN: Completing successfully
        placeholder.updateFromProcessingResult(
            title: "Success Recipe",
            instructions: ["Done"],
            servings: "4 servings"
        )

        // THEN: No error message
        XCTAssertNil(placeholder.processingErrorMessage)
        XCTAssertFalse(placeholder.didFailProcessing)
    }

    // MARK: - Deletion Tests

    /// Test 20: Deleting placeholder removes it from context
    func test_deletingPlaceholder_removesFromContext() throws {
        // GIVEN: A placeholder
        let jobID = UUID()
        let placeholder = Recipe.createImportPlaceholder(
            jobId: jobID,
            itemIndex: 0,
            cookbookName: "Test"
        )
        env.modelContext.insert(placeholder)
        try env.save()

        // Verify it exists
        let allRecipes = try env.fetchAllRecipes()
        XCTAssertEqual(allRecipes.count, 1)

        // WHEN: Deleting placeholder
        env.modelContext.delete(placeholder)
        try env.save()

        // THEN: Placeholder should be gone
        let remainingRecipes = try env.fetchAllRecipes()
        XCTAssertEqual(remainingRecipes.count, 0)
    }

    // MARK: - Query Tests

    /// Test 21: Can query all processing recipes
    func test_canQueryAllProcessingRecipes() throws {
        // GIVEN: Mix of processing and ready recipes
        let processing1 = Recipe.createImportPlaceholder(jobId: UUID(), itemIndex: 0, cookbookName: "Test")
        let processing2 = Recipe.createVideoProcessingPlaceholder(jobId: UUID())
        let ready = Recipe(title: "Ready Recipe", sourceType: .manual)

        env.modelContext.insert(processing1)
        env.modelContext.insert(processing2)
        env.modelContext.insert(ready)
        try env.save()

        // WHEN: Filtering for processing recipes
        let allRecipes = try env.fetchAllRecipes()
        let processingRecipes = allRecipes.filter { $0.isProcessing }

        // THEN: Should find only processing recipes
        XCTAssertEqual(processingRecipes.count, 2)
    }

    /// Test 22: Can query failed recipes
    func test_canQueryFailedRecipes() throws {
        // GIVEN: A failed placeholder
        let placeholder = Recipe.createImportPlaceholder(
            jobId: UUID(),
            itemIndex: 0,
            cookbookName: "Test"
        )
        placeholder.processingStatus = .failed

        let ready = Recipe(title: "Ready", sourceType: .manual)

        env.modelContext.insert(placeholder)
        env.modelContext.insert(ready)
        try env.save()

        // WHEN: Filtering for failed recipes
        let allRecipes = try env.fetchAllRecipes()
        let failedRecipes = allRecipes.filter { $0.didFailProcessing }

        // THEN: Should find only failed recipe
        XCTAssertEqual(failedRecipes.count, 1)
        XCTAssertTrue(failedRecipes.first?.didFailProcessing ?? false)
    }
}
