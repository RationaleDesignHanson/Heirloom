//
//  OperationLogTests.swift
//  HeirloomTests
//
//  Created by Claude on 12/31/25.
//  Unit tests for OperationLog CRDT component
//

import XCTest
@testable import Heirloom

/// Unit tests for OperationLog - append-only operation history
final class OperationLogTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeTestRecipeId() -> UUID {
        return UUID()
    }

    private func makeTestOperation(
        recipeId: UUID,
        deviceId: String,
        fieldPath: String,
        oldValue: OperationValue? = nil,
        newValue: OperationValue? = nil,
        operationType: OperationType = .update
    ) -> RecipeOperation {
        let clock = VectorClock()
        clock.increment(deviceId: deviceId)

        return RecipeOperation(
            recipeId: recipeId,
            deviceId: deviceId,
            vectorClock: clock,
            operationType: operationType,
            fieldPath: fieldPath,
            oldValue: oldValue,
            newValue: newValue
        )
    }

    // MARK: - Initialization Tests

    func testOperationLogDefaultInit() throws {
        let recipeId = makeTestRecipeId()
        let log = OperationLog(recipeId: recipeId)

        XCTAssertEqual(log.recipeId, recipeId)
        XCTAssertTrue(log.operations.isEmpty)
        XCTAssertNotNil(log.vectorClock)
        XCTAssertNotNil(log.lastUpdated)
    }

    func testOperationLogInitWithOperations() throws {
        let recipeId = makeTestRecipeId()
        let operation1 = makeTestOperation(recipeId: recipeId, deviceId: "device1", fieldPath: "title")
        let operation2 = makeTestOperation(recipeId: recipeId, deviceId: "device2", fieldPath: "servings")

        let log = OperationLog(recipeId: recipeId, operations: [operation1, operation2])

        XCTAssertEqual(log.operations.count, 2)
        XCTAssertEqual(log.operations[0].id, operation1.id)
        XCTAssertEqual(log.operations[1].id, operation2.id)
    }

    // MARK: - Append Tests

    func testAppendOperation() throws {
        let recipeId = makeTestRecipeId()
        let log = OperationLog(recipeId: recipeId)

        let operation = makeTestOperation(recipeId: recipeId, deviceId: "device1", fieldPath: "title")

        log.append(operation)

        XCTAssertEqual(log.operations.count, 1)
        XCTAssertEqual(log.operations.first?.id, operation.id)
    }

    func testAppendMultipleOperations() throws {
        let recipeId = makeTestRecipeId()
        let log = OperationLog(recipeId: recipeId)

        let operation1 = makeTestOperation(recipeId: recipeId, deviceId: "device1", fieldPath: "title")
        let operation2 = makeTestOperation(recipeId: recipeId, deviceId: "device1", fieldPath: "servings")
        let operation3 = makeTestOperation(recipeId: recipeId, deviceId: "device2", fieldPath: "cookTime")

        log.append(operation1)
        log.append(operation2)
        log.append(operation3)

        XCTAssertEqual(log.operations.count, 3)
    }

    func testAppendUpdatesVectorClock() throws {
        let recipeId = makeTestRecipeId()
        let log = OperationLog(recipeId: recipeId)

        let clock = VectorClock()
        clock.increment(deviceId: "device1")
        clock.increment(deviceId: "device1")

        let operation = RecipeOperation(
            recipeId: recipeId,
            deviceId: "device1",
            vectorClock: clock,
            operationType: .update,
            fieldPath: "title"
        )

        log.append(operation)

        XCTAssertEqual(log.vectorClock.clocks["device1"], 2)
    }

    func testAppendBatch() throws {
        let recipeId = makeTestRecipeId()
        let log = OperationLog(recipeId: recipeId)

        let operations = [
            makeTestOperation(recipeId: recipeId, deviceId: "device1", fieldPath: "title"),
            makeTestOperation(recipeId: recipeId, deviceId: "device2", fieldPath: "servings"),
            makeTestOperation(recipeId: recipeId, deviceId: "device3", fieldPath: "cookTime")
        ]

        log.appendBatch(operations)

        XCTAssertEqual(log.operations.count, 3)
    }

    func testAppendBatchEmptyArray() throws {
        let recipeId = makeTestRecipeId()
        let log = OperationLog(recipeId: recipeId)

        log.appendBatch([])

        XCTAssertTrue(log.operations.isEmpty)
    }

    // MARK: - Merge Tests

    func testMergeWithEmptyLog() throws {
        let recipeId = makeTestRecipeId()
        let log1 = OperationLog(recipeId: recipeId)
        log1.append(makeTestOperation(recipeId: recipeId, deviceId: "device1", fieldPath: "title"))

        let log2 = OperationLog(recipeId: recipeId)

        log1.merge(with: log2)

        XCTAssertEqual(log1.operations.count, 1)
    }

    func testMergeEmptyWithNonEmpty() throws {
        let recipeId = makeTestRecipeId()
        let log1 = OperationLog(recipeId: recipeId)

        let log2 = OperationLog(recipeId: recipeId)
        log2.append(makeTestOperation(recipeId: recipeId, deviceId: "device2", fieldPath: "servings"))

        log1.merge(with: log2)

        XCTAssertEqual(log1.operations.count, 1)
    }

    func testMergeDisjointOperations() throws {
        let recipeId = makeTestRecipeId()
        let log1 = OperationLog(recipeId: recipeId)
        log1.append(makeTestOperation(recipeId: recipeId, deviceId: "device1", fieldPath: "title"))

        let log2 = OperationLog(recipeId: recipeId)
        log2.append(makeTestOperation(recipeId: recipeId, deviceId: "device2", fieldPath: "servings"))
        log2.append(makeTestOperation(recipeId: recipeId, deviceId: "device2", fieldPath: "cookTime"))

        log1.merge(with: log2)

        XCTAssertEqual(log1.operations.count, 3, "Should have all operations from both logs")
    }

    func testMergeDeduplicatesOperations() throws {
        let recipeId = makeTestRecipeId()
        let sharedOperation = makeTestOperation(recipeId: recipeId, deviceId: "device1", fieldPath: "title")

        let log1 = OperationLog(recipeId: recipeId)
        log1.append(sharedOperation)

        let log2 = OperationLog(recipeId: recipeId)
        log2.append(sharedOperation)

        log1.merge(with: log2)

        XCTAssertEqual(log1.operations.count, 1, "Should deduplicate operations by ID")
    }

    func testMergeSortsOperationsByTimestamp() throws {
        let recipeId = makeTestRecipeId()

        // Create operations with different timestamps
        let operation1 = makeTestOperation(recipeId: recipeId, deviceId: "device1", fieldPath: "title")
        operation1.timestamp = Date(timeIntervalSince1970: 1000)

        let operation2 = makeTestOperation(recipeId: recipeId, deviceId: "device2", fieldPath: "servings")
        operation2.timestamp = Date(timeIntervalSince1970: 500)

        let operation3 = makeTestOperation(recipeId: recipeId, deviceId: "device3", fieldPath: "cookTime")
        operation3.timestamp = Date(timeIntervalSince1970: 750)

        let log1 = OperationLog(recipeId: recipeId)
        log1.append(operation1)

        let log2 = OperationLog(recipeId: recipeId)
        log2.append(operation2)
        log2.append(operation3)

        log1.merge(with: log2)

        // Check chronological order
        XCTAssertEqual(log1.operations[0].timestamp, Date(timeIntervalSince1970: 500))
        XCTAssertEqual(log1.operations[1].timestamp, Date(timeIntervalSince1970: 750))
        XCTAssertEqual(log1.operations[2].timestamp, Date(timeIntervalSince1970: 1000))
    }

    // MARK: - Conflict Detection Tests

    func testFindConflictsNone() throws {
        let recipeId = makeTestRecipeId()
        let log = OperationLog(recipeId: recipeId)

        // Sequential edits on different fields - no conflicts
        log.append(makeTestOperation(recipeId: recipeId, deviceId: "device1", fieldPath: "title"))
        log.append(makeTestOperation(recipeId: recipeId, deviceId: "device1", fieldPath: "servings"))

        let conflicts = log.findConflicts()

        XCTAssertTrue(conflicts.isEmpty, "Sequential edits on different fields should not conflict")
    }

    func testFindConflictsConcurrentSameField() throws {
        let recipeId = makeTestRecipeId()
        let log = OperationLog(recipeId: recipeId)

        // Concurrent edits on same field
        let clock1 = VectorClock()
        clock1.increment(deviceId: "device1")

        let clock2 = VectorClock()
        clock2.increment(deviceId: "device2")

        let operation1 = RecipeOperation(
            recipeId: recipeId,
            deviceId: "device1",
            vectorClock: clock1,
            operationType: .update,
            fieldPath: "servings",
            newValue: .string("4 servings")
        )

        let operation2 = RecipeOperation(
            recipeId: recipeId,
            deviceId: "device2",
            vectorClock: clock2,
            operationType: .update,
            fieldPath: "servings",
            newValue: .string("6 servings")
        )

        log.append(operation1)
        log.append(operation2)

        let conflicts = log.findConflicts()

        XCTAssertEqual(conflicts.count, 1, "Should detect one conflict")
        XCTAssertEqual(conflicts.first?.fieldPath, "servings")
        XCTAssertNotNil(conflicts.first?.operation1)
        XCTAssertNotNil(conflicts.first?.operation2)
    }

    func testFindConflictsMultipleFields() throws {
        let recipeId = makeTestRecipeId()
        let log = OperationLog(recipeId: recipeId)

        // Conflicts on two different fields
        let clock1 = VectorClock()
        clock1.increment(deviceId: "device1")

        let clock2 = VectorClock()
        clock2.increment(deviceId: "device2")

        log.append(RecipeOperation(
            recipeId: recipeId,
            deviceId: "device1",
            vectorClock: clock1,
            operationType: .update,
            fieldPath: "servings"
        ))

        log.append(RecipeOperation(
            recipeId: recipeId,
            deviceId: "device2",
            vectorClock: clock2,
            operationType: .update,
            fieldPath: "servings"
        ))

        log.append(RecipeOperation(
            recipeId: recipeId,
            deviceId: "device1",
            vectorClock: clock1.copy(),
            operationType: .update,
            fieldPath: "cookTime"
        ))

        log.append(RecipeOperation(
            recipeId: recipeId,
            deviceId: "device2",
            vectorClock: clock2.copy(),
            operationType: .update,
            fieldPath: "cookTime"
        ))

        let conflicts = log.findConflicts()

        XCTAssertEqual(conflicts.count, 2, "Should detect conflicts on both fields")
    }

    func testFindConflictsIgnoresSequentialEdits() throws {
        let recipeId = makeTestRecipeId()
        let log = OperationLog(recipeId: recipeId)

        // Sequential edits (device2 saw device1's change)
        let clock1 = VectorClock()
        clock1.increment(deviceId: "device1")

        let clock2 = clock1.copy()
        clock2.increment(deviceId: "device2")

        log.append(RecipeOperation(
            recipeId: recipeId,
            deviceId: "device1",
            vectorClock: clock1,
            operationType: .update,
            fieldPath: "servings"
        ))

        log.append(RecipeOperation(
            recipeId: recipeId,
            deviceId: "device2",
            vectorClock: clock2,
            operationType: .update,
            fieldPath: "servings"
        ))

        let conflicts = log.findConflicts()

        XCTAssertTrue(conflicts.isEmpty, "Sequential edits should not conflict")
    }

    // MARK: - Codable Tests

    func testOperationLogCodable() throws {
        let recipeId = makeTestRecipeId()
        let log = OperationLog(recipeId: recipeId)

        log.append(makeTestOperation(recipeId: recipeId, deviceId: "device1", fieldPath: "title"))
        log.append(makeTestOperation(recipeId: recipeId, deviceId: "device2", fieldPath: "servings"))

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(log)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OperationLog.self, from: data)

        XCTAssertEqual(decoded.recipeId, log.recipeId)
        XCTAssertEqual(decoded.operations.count, 2)
    }

    // MARK: - Real-World Scenarios

    func testScenarioOfflineEditsSync() throws {
        let recipeId = makeTestRecipeId()

        // Device 1 offline edits
        let log1 = OperationLog(recipeId: recipeId)
        log1.append(makeTestOperation(recipeId: recipeId, deviceId: "device1", fieldPath: "title"))
        log1.append(makeTestOperation(recipeId: recipeId, deviceId: "device1", fieldPath: "servings"))

        // Device 2 offline edits
        let log2 = OperationLog(recipeId: recipeId)
        log2.append(makeTestOperation(recipeId: recipeId, deviceId: "device2", fieldPath: "cookTime"))
        log2.append(makeTestOperation(recipeId: recipeId, deviceId: "device2", fieldPath: "prepTime"))

        // Merge when back online
        log1.merge(with: log2)

        XCTAssertEqual(log1.operations.count, 4, "Should have all operations from both devices")
    }

    func testScenarioThreeWayMerge() throws {
        let recipeId = makeTestRecipeId()

        // Three devices edit simultaneously
        let log1 = OperationLog(recipeId: recipeId)
        log1.append(makeTestOperation(recipeId: recipeId, deviceId: "device1", fieldPath: "title"))

        let log2 = OperationLog(recipeId: recipeId)
        log2.append(makeTestOperation(recipeId: recipeId, deviceId: "device2", fieldPath: "servings"))

        let log3 = OperationLog(recipeId: recipeId)
        log3.append(makeTestOperation(recipeId: recipeId, deviceId: "device3", fieldPath: "cookTime"))

        // Merge all
        log1.merge(with: log2)
        log1.merge(with: log3)

        XCTAssertEqual(log1.operations.count, 3)
    }

    func testScenarioConflictingEditsDetected() throws {
        let recipeId = makeTestRecipeId()
        let log = OperationLog(recipeId: recipeId)

        // Two devices edit same field concurrently
        let clock1 = VectorClock()
        clock1.increment(deviceId: "device1")

        let clock2 = VectorClock()
        clock2.increment(deviceId: "device2")

        log.append(RecipeOperation(
            recipeId: recipeId,
            deviceId: "device1",
            vectorClock: clock1,
            operationType: .update,
            fieldPath: "servings",
            newValue: .string("4 servings")
        ))

        log.append(RecipeOperation(
            recipeId: recipeId,
            deviceId: "device2",
            vectorClock: clock2,
            operationType: .update,
            fieldPath: "servings",
            newValue: .string("6 servings")
        ))

        let conflicts = log.findConflicts()

        XCTAssertEqual(conflicts.count, 1)
        let conflict = conflicts.first
        XCTAssertTrue(conflict?.operation1.deviceId == "device1" || conflict?.operation2.deviceId == "device1")
        XCTAssertTrue(conflict?.operation1.deviceId == "device2" || conflict?.operation2.deviceId == "device2")
    }
}
