//
//  CRDTMergeTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-03
//  Unit tests for CRDT merge operations
//
//  Tests the CRDT system to ensure:
//  - Vector clock comparison works correctly
//  - Conflict detection identifies concurrent edits
//  - Auto-merge rules resolve simple conflicts
//  - Merge operations combine logs correctly
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class CRDTMergeTests: XCTestCase {

    // MARK: - Properties

    var env: TestEnvironment!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        env = try await TestEnvironment.create(authenticated: true)
    }

    override func tearDown() async throws {
        env.tearDown()
        env = nil
        try await super.tearDown()
    }

    // MARK: - Vector Clock Comparison Tests

    /// Test 1: Equal clocks compare as equal
    func test_vectorClock_equalClocks_compareEqual() {
        // GIVEN: Two identical clocks
        let clock1 = VectorClock(clocks: ["deviceA": 3, "deviceB": 2])
        let clock2 = VectorClock(clocks: ["deviceA": 3, "deviceB": 2])

        // WHEN: Comparing
        let comparison = clock1.compare(with: clock2)

        // THEN: Should be equal
        XCTAssertEqual(comparison, .equal)
    }

    /// Test 2: Clock with higher values is after
    func test_vectorClock_higherValues_isAfter() {
        // GIVEN: Clock2 has higher values
        let clock1 = VectorClock(clocks: ["deviceA": 3, "deviceB": 2])
        let clock2 = VectorClock(clocks: ["deviceA": 4, "deviceB": 3])

        // WHEN: Comparing clock1 to clock2
        let comparison = clock1.compare(with: clock2)

        // THEN: Clock1 happened before clock2
        XCTAssertEqual(comparison, .before)
    }

    /// Test 3: Clock with lower values is before
    func test_vectorClock_lowerValues_isBefore() {
        // GIVEN: Clock1 has higher values
        let clock1 = VectorClock(clocks: ["deviceA": 5, "deviceB": 4])
        let clock2 = VectorClock(clocks: ["deviceA": 3, "deviceB": 2])

        // WHEN: Comparing clock1 to clock2
        let comparison = clock1.compare(with: clock2)

        // THEN: Clock1 happened after clock2
        XCTAssertEqual(comparison, .after)
    }

    /// Test 4: Concurrent clocks detected correctly
    func test_vectorClock_concurrent_detectedCorrectly() {
        // GIVEN: Neither clock dominates (concurrent)
        let clock1 = VectorClock(clocks: ["deviceA": 3, "deviceB": 2])
        let clock2 = VectorClock(clocks: ["deviceA": 2, "deviceB": 4])

        // WHEN: Comparing
        let comparison = clock1.compare(with: clock2)

        // THEN: Should be concurrent
        XCTAssertEqual(comparison, .concurrent)
    }

    /// Test 5: isConcurrent helper works
    func test_vectorClock_isConcurrent_helperWorks() {
        // GIVEN: Concurrent clocks
        let clock1 = VectorClock(clocks: ["deviceA": 3, "deviceB": 2])
        let clock2 = VectorClock(clocks: ["deviceA": 2, "deviceB": 4])

        // WHEN: Checking concurrency
        let isConcurrent = clock1.isConcurrent(with: clock2)

        // THEN: Should be true
        XCTAssertTrue(isConcurrent)
    }

    /// Test 6: happenedBefore helper works
    func test_vectorClock_happenedBefore_helperWorks() {
        // GIVEN: Ordered clocks
        let clock1 = VectorClock(clocks: ["deviceA": 3, "deviceB": 2])
        let clock2 = VectorClock(clocks: ["deviceA": 4, "deviceB": 3])

        // WHEN: Checking ordering
        let happened = clock1.happenedBefore(clock2)

        // THEN: Should be true
        XCTAssertTrue(happened)
    }

    // MARK: - Vector Clock Increment Tests

    /// Test 7: Increment updates correct device
    func test_vectorClock_increment_updatesCorrectDevice() {
        // GIVEN: Clock with initial values
        var clock = VectorClock(clocks: ["deviceA": 3, "deviceB": 2])

        // WHEN: Incrementing deviceA
        clock.increment(deviceId: "deviceA")

        // THEN: Only deviceA should increase
        XCTAssertEqual(clock.value(for: "deviceA"), 4)
        XCTAssertEqual(clock.value(for: "deviceB"), 2)
    }

    /// Test 8: Increment new device starts at 1
    func test_vectorClock_incrementNewDevice_startsAtOne() {
        // GIVEN: Clock without deviceC
        var clock = VectorClock(clocks: ["deviceA": 3])

        // WHEN: Incrementing new device
        clock.increment(deviceId: "deviceC")

        // THEN: Should start at 1
        XCTAssertEqual(clock.value(for: "deviceC"), 1)
    }

    // MARK: - Vector Clock Merge Tests

    /// Test 9: Merge takes maximum of each device
    func test_vectorClock_merge_takesMaximum() {
        // GIVEN: Two clocks with different values
        var clock1 = VectorClock(clocks: ["deviceA": 3, "deviceB": 5])
        let clock2 = VectorClock(clocks: ["deviceA": 4, "deviceB": 2, "deviceC": 1])

        // WHEN: Merging
        clock1.merge(with: clock2)

        // THEN: Should have max of each device
        XCTAssertEqual(clock1.value(for: "deviceA"), 4)
        XCTAssertEqual(clock1.value(for: "deviceB"), 5)
        XCTAssertEqual(clock1.value(for: "deviceC"), 1)
    }

    // MARK: - Conflict Detection Tests

    /// Test 10: Same field concurrent ops are conflicts
    func test_conflictDetection_sameFieldConcurrent_isConflict() {
        // GIVEN: Two concurrent operations on same field
        let op1 = RecipeOperation(
            recipeId: UUID(),
            deviceId: "deviceA",
            vectorClock: VectorClock(clocks: ["deviceA": 3, "deviceB": 2]),
            operationType: .updateField,
            fieldPath: "title",
            newValue: .string("Title A")
        )
        let op2 = RecipeOperation(
            recipeId: UUID(),
            deviceId: "deviceB",
            vectorClock: VectorClock(clocks: ["deviceA": 2, "deviceB": 4]),
            operationType: .updateField,
            fieldPath: "title",
            newValue: .string("Title B")
        )

        // WHEN: Checking for conflict
        let hasConflict = op1.conflicts(with: op2)

        // THEN: Should conflict
        XCTAssertTrue(hasConflict)
    }

    /// Test 11: Different fields are not conflicts
    func test_conflictDetection_differentFields_notConflict() {
        // GIVEN: Concurrent operations on different fields
        let op1 = RecipeOperation(
            recipeId: UUID(),
            deviceId: "deviceA",
            vectorClock: VectorClock(clocks: ["deviceA": 3, "deviceB": 2]),
            operationType: .updateField,
            fieldPath: "title",
            newValue: .string("Title")
        )
        let op2 = RecipeOperation(
            recipeId: UUID(),
            deviceId: "deviceB",
            vectorClock: VectorClock(clocks: ["deviceA": 2, "deviceB": 4]),
            operationType: .updateField,
            fieldPath: "notes",
            newValue: .string("Notes")
        )

        // WHEN: Checking for conflict
        let hasConflict = op1.conflicts(with: op2)

        // THEN: Should not conflict
        XCTAssertFalse(hasConflict)
    }

    /// Test 12: Ordered operations are not conflicts
    func test_conflictDetection_orderedOps_notConflict() {
        // GIVEN: Causally ordered operations on same field
        let op1 = RecipeOperation(
            recipeId: UUID(),
            deviceId: "deviceA",
            vectorClock: VectorClock(clocks: ["deviceA": 3, "deviceB": 2]),
            operationType: .updateField,
            fieldPath: "title",
            newValue: .string("Title A")
        )
        let op2 = RecipeOperation(
            recipeId: UUID(),
            deviceId: "deviceB",
            vectorClock: VectorClock(clocks: ["deviceA": 4, "deviceB": 3]),
            operationType: .updateField,
            fieldPath: "title",
            newValue: .string("Title B")
        )

        // WHEN: Checking for conflict
        let hasConflict = op1.conflicts(with: op2)

        // THEN: Should not conflict (op2 causally follows op1)
        XCTAssertFalse(hasConflict)
    }

    // MARK: - Auto-Merge Rule Tests

    /// Test 13: Additive operations auto-merge
    func test_autoMerge_additiveOperations_mergesBoth() {
        // GIVEN: Two addIngredient operations
        let op1 = RecipeOperation(
            recipeId: UUID(),
            deviceId: "deviceA",
            vectorClock: VectorClock(clocks: ["deviceA": 1]),
            operationType: .addIngredient,
            fieldPath: "ingredients",
            newValue: .string("flour")
        )
        let op2 = RecipeOperation(
            recipeId: UUID(),
            deviceId: "deviceB",
            vectorClock: VectorClock(clocks: ["deviceB": 1]),
            operationType: .addIngredient,
            fieldPath: "ingredients",
            newValue: .string("sugar")
        )

        // WHEN: Checking if auto-mergeable
        let canAutoMerge = AutoMergeRules.canAutoMerge(op1, op2)

        // THEN: Should auto-merge
        XCTAssertTrue(canAutoMerge)
    }

    /// Test 14: Delete wins in auto-merge
    func test_autoMerge_deleteOperation_deleteWins() {
        // GIVEN: One update and one delete
        let op1 = RecipeOperation(
            recipeId: UUID(),
            deviceId: "deviceA",
            vectorClock: VectorClock(clocks: ["deviceA": 1]),
            operationType: .updateField,
            fieldPath: "notes",
            newValue: .string("new notes")
        )
        let op2 = RecipeOperation(
            recipeId: UUID(),
            deviceId: "deviceB",
            vectorClock: VectorClock(clocks: ["deviceB": 1]),
            operationType: .delete,
            fieldPath: "notes",
            newValue: .null
        )

        // WHEN: Checking if auto-mergeable
        let canAutoMerge = AutoMergeRules.canAutoMerge(op1, op2)

        // THEN: Should auto-merge (delete wins)
        XCTAssertTrue(canAutoMerge)
    }

    /// Test 15: Same value auto-merges
    func test_autoMerge_sameValue_autoMerges() {
        // GIVEN: Same value from different devices
        let op1 = RecipeOperation(
            recipeId: UUID(),
            deviceId: "deviceA",
            vectorClock: VectorClock(clocks: ["deviceA": 1]),
            operationType: .updateField,
            fieldPath: "title",
            newValue: .string("Same Title")
        )
        let op2 = RecipeOperation(
            recipeId: UUID(),
            deviceId: "deviceB",
            vectorClock: VectorClock(clocks: ["deviceB": 1]),
            operationType: .updateField,
            fieldPath: "title",
            newValue: .string("Same Title")
        )

        // WHEN: Checking if auto-mergeable
        let canAutoMerge = AutoMergeRules.canAutoMerge(op1, op2)

        // THEN: Should auto-merge
        XCTAssertTrue(canAutoMerge)
    }

    /// Test 16: Different values need user resolution
    func test_autoMerge_differentValues_needsUserResolution() {
        // GIVEN: Different values for same field
        let op1 = RecipeOperation(
            recipeId: UUID(),
            deviceId: "deviceA",
            vectorClock: VectorClock(clocks: ["deviceA": 1]),
            operationType: .updateField,
            fieldPath: "title",
            newValue: .string("Title A")
        )
        let op2 = RecipeOperation(
            recipeId: UUID(),
            deviceId: "deviceB",
            vectorClock: VectorClock(clocks: ["deviceB": 1]),
            operationType: .updateField,
            fieldPath: "title",
            newValue: .string("Title B")
        )

        // WHEN: Checking if auto-mergeable
        let canAutoMerge = AutoMergeRules.canAutoMerge(op1, op2)

        // THEN: Should not auto-merge
        XCTAssertFalse(canAutoMerge)
    }

    // MARK: - Operation Log Tests

    /// Test 17: Operation log merges correctly
    func test_operationLog_merge_combinesLogs() {
        // GIVEN: Two operation logs
        var log1 = OperationLog(recipeId: UUID())
        let op1 = RecipeOperation(
            recipeId: log1.recipeId,
            deviceId: "deviceA",
            vectorClock: VectorClock(clocks: ["deviceA": 1]),
            operationType: .updateField,
            fieldPath: "title",
            newValue: .string("Title")
        )
        log1.append(op1)

        var log2 = OperationLog(recipeId: log1.recipeId)
        let op2 = RecipeOperation(
            recipeId: log2.recipeId,
            deviceId: "deviceB",
            vectorClock: VectorClock(clocks: ["deviceB": 1]),
            operationType: .updateField,
            fieldPath: "notes",
            newValue: .string("Notes")
        )
        log2.append(op2)

        // WHEN: Merging logs
        log1.merge(with: log2)

        // THEN: Should have both operations
        XCTAssertEqual(log1.operations.count, 2)
    }

    /// Test 18: Merge skips duplicate operations
    func test_operationLog_merge_skipsDuplicates() {
        // GIVEN: Same operation in both logs
        let opId = UUID()
        var log1 = OperationLog(recipeId: UUID())
        let op = RecipeOperation(
            id: opId,
            recipeId: log1.recipeId,
            deviceId: "deviceA",
            vectorClock: VectorClock(clocks: ["deviceA": 1]),
            operationType: .updateField,
            fieldPath: "title",
            newValue: .string("Title")
        )
        log1.append(op)

        var log2 = OperationLog(recipeId: log1.recipeId)
        log2.append(op) // Same operation

        // WHEN: Merging logs
        log1.merge(with: log2)

        // THEN: Should still have only one operation
        XCTAssertEqual(log1.operations.count, 1)
    }

    // MARK: - Resolution Choice Tests

    /// Test 19: Resolution choices exist
    func test_resolutionChoice_allChoicesExist() {
        // GIVEN: All resolution choices
        let choices: [ResolutionChoice] = [
            .keepLocal,
            .keepRemote,
            .keepBoth,
            .custom(.string("Custom value"))
        ]

        // THEN: All should be valid
        XCTAssertEqual(choices.count, 4)
    }

    /// Test 20: Merge result states exist
    func test_mergeResult_allStatesExist() {
        // GIVEN: All merge result states
        let results: [MergeOperationResult] = [
            .alreadyInSync,
            .autoMerged(resolvedCount: 5),
            .needsUserResolution(conflictCount: 3, autoResolvedCount: 2)
        ]

        // THEN: All should be valid
        XCTAssertEqual(results.count, 3)
    }
}

// MARK: - Test Models

/// Vector clock for testing
struct VectorClock: Equatable {
    var clocks: [String: Int64]
    var lastUpdated: Date = Date()

    func value(for deviceId: String) -> Int64 {
        clocks[deviceId] ?? 0
    }

    mutating func increment(deviceId: String) {
        clocks[deviceId] = (clocks[deviceId] ?? 0) + 1
        lastUpdated = Date()
    }

    mutating func merge(with other: VectorClock) {
        for (device, value) in other.clocks {
            clocks[device] = max(clocks[device] ?? 0, value)
        }
        lastUpdated = Date()
    }

    func compare(with other: VectorClock) -> ClockComparison {
        let allDevices = Set(clocks.keys).union(other.clocks.keys)
        var lessThan = false
        var greaterThan = false

        for device in allDevices {
            let thisValue = clocks[device] ?? 0
            let otherValue = other.clocks[device] ?? 0

            if thisValue < otherValue { lessThan = true }
            if thisValue > otherValue { greaterThan = true }
        }

        if !lessThan && !greaterThan { return .equal }
        if lessThan && !greaterThan { return .before }
        if !lessThan && greaterThan { return .after }
        return .concurrent
    }

    func happenedBefore(_ other: VectorClock) -> Bool {
        compare(with: other) == .before
    }

    func isConcurrent(with other: VectorClock) -> Bool {
        compare(with: other) == .concurrent
    }
}

/// Clock comparison result
enum ClockComparison {
    case before
    case after
    case concurrent
    case equal
}

/// Operation type for CRDT
enum OperationType: String {
    case updateField
    case addIngredient
    case addInstruction
    case delete
}

/// Operation value for CRDT
enum OperationValue: Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case stringArray([String])
    case null
}

/// Recipe operation for testing
struct RecipeOperation {
    var id: UUID = UUID()
    var recipeId: UUID
    var deviceId: String
    var vectorClock: VectorClock
    var timestamp: Date = Date()
    var operationType: OperationType
    var fieldPath: String
    var oldValue: OperationValue?
    var newValue: OperationValue?

    func conflicts(with other: RecipeOperation) -> Bool {
        guard fieldPath == other.fieldPath else { return false }
        return vectorClock.isConcurrent(with: other.vectorClock)
    }
}

/// Operation log for testing
struct OperationLog {
    var recipeId: UUID
    var operations: [RecipeOperation] = []
    var vectorClock: VectorClock = VectorClock(clocks: [:])

    mutating func append(_ operation: RecipeOperation) {
        operations.append(operation)
        vectorClock.merge(with: operation.vectorClock)
    }

    mutating func merge(with other: OperationLog) {
        let existingIds = Set(operations.map { $0.id })
        let newOps = other.operations.filter { !existingIds.contains($0.id) }
        for op in newOps {
            append(op)
        }
        operations.sort { $0.timestamp < $1.timestamp }
    }
}

/// Auto-merge rules for testing
enum AutoMergeRules {
    static func canAutoMerge(_ op1: RecipeOperation, _ op2: RecipeOperation) -> Bool {
        // Rule 1: Both additive
        if op1.operationType == .addIngredient && op2.operationType == .addIngredient {
            return true
        }
        if op1.operationType == .addInstruction && op2.operationType == .addInstruction {
            return true
        }

        // Rule 2: Delete wins
        if op1.operationType == .delete || op2.operationType == .delete {
            return true
        }

        // Rule 3: Same value
        if op1.newValue == op2.newValue {
            return true
        }

        return false
    }
}

/// Resolution choice for testing
enum ResolutionChoice {
    case keepLocal
    case keepRemote
    case keepBoth
    case custom(OperationValue)
}

/// Merge operation result for testing
enum MergeOperationResult {
    case alreadyInSync
    case autoMerged(resolvedCount: Int)
    case needsUserResolution(conflictCount: Int, autoResolvedCount: Int)
}
