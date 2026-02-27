import SnapshotTesting
import SwiftUI
import SwiftData
import XCTest
@testable import Heirloom

@MainActor
final class ProcessingQueueSnapshotTests: SnapshotTestCase {

    // MARK: - Empty State

    func testProcessingQueue_empty() {
        let view = UnifiedProcessingQueueView()

        assertBothDevices(view, named: "processingQueue_empty")
    }

    // MARK: - Active Import Job

    func testProcessingQueue_activeImport() throws {
        _ = createTestImportJob(
            name: "Cooking With Julia",
            status: .processing,
            itemCount: 12
        )
        try saveContext()

        let view = UnifiedProcessingQueueView()

        assertBothDevices(view, named: "processingQueue_activeImport")
    }

    // MARK: - Completed Job

    func testProcessingQueue_completedJob() throws {
        _ = createTestImportJob(
            name: "Family Favorites",
            status: .completed,
            itemCount: 5
        )
        try saveContext()

        let view = UnifiedProcessingQueueView()

        assertBothDevices(view, named: "processingQueue_completed")
    }

    // MARK: - Failed Job

    func testProcessingQueue_failedJob() throws {
        _ = createTestImportJob(
            name: "Web Import Batch",
            status: .failed,
            itemCount: 3
        )
        try saveContext()

        let view = UnifiedProcessingQueueView()

        assertBothDevices(view, named: "processingQueue_failed")
    }
}
