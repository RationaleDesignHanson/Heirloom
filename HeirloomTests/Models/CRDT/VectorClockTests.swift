//
//  VectorClockTests.swift
//  HeirloomTests
//
//  Created by Claude on 12/31/25.
//  Unit tests for VectorClock CRDT component
//

import XCTest
@testable import Heirloom

/// Unit tests for VectorClock - causal relationship tracking
final class VectorClockTests: XCTestCase {

    // MARK: - Initialization Tests

    func testVectorClockDefaultInit() throws {
        let clock = VectorClock()

        XCTAssertTrue(clock.clocks.isEmpty, "New clock should be empty")
        XCTAssertNotNil(clock.lastUpdated)
    }

    func testVectorClockCopy() throws {
        var original = VectorClock()
        original.increment(deviceId: "device1")
        original.increment(deviceId: "device2")

        let copy = original.copy()

        XCTAssertEqual(copy.clocks, original.clocks)
        XCTAssertEqual(copy.clocks["device1"], 1)
        XCTAssertEqual(copy.clocks["device2"], 1)
    }

    // MARK: - Increment Tests

    func testIncrementNewDevice() throws {
        var clock = VectorClock()

        clock.increment(deviceId: "device1")

        XCTAssertEqual(clock.clocks["device1"], 1)
        XCTAssertEqual(clock.clocks.count, 1)
    }

    func testIncrementExistingDevice() throws {
        var clock = VectorClock()

        clock.increment(deviceId: "device1")
        clock.increment(deviceId: "device1")
        clock.increment(deviceId: "device1")

        XCTAssertEqual(clock.clocks["device1"], 3)
    }

    func testIncrementMultipleDevices() throws {
        var clock = VectorClock()

        clock.increment(deviceId: "device1")
        clock.increment(deviceId: "device2")
        clock.increment(deviceId: "device1")
        clock.increment(deviceId: "device3")

        XCTAssertEqual(clock.clocks["device1"], 2)
        XCTAssertEqual(clock.clocks["device2"], 1)
        XCTAssertEqual(clock.clocks["device3"], 1)
        XCTAssertEqual(clock.clocks.count, 3)
    }

    func testIncrementUpdatesLastUpdated() throws {
        var clock = VectorClock()
        let initialDate = clock.lastUpdated

        // Wait a tiny bit to ensure timestamp difference
        Thread.sleep(forTimeInterval: 0.01)

        clock.increment(deviceId: "device1")

        XCTAssertGreaterThan(clock.lastUpdated, initialDate)
    }

    // MARK: - Merge Tests

    func testMergeWithEmpty() throws {
        var clock1 = VectorClock()
        clock1.increment(deviceId: "device1")
        clock1.increment(deviceId: "device1")

        let clock2 = VectorClock()

        clock1.merge(with: clock2)

        XCTAssertEqual(clock1.clocks["device1"], 2)
        XCTAssertEqual(clock1.clocks.count, 1)
    }

    func testMergeEmptyWithNonEmpty() throws {
        var clock1 = VectorClock()

        var clock2 = VectorClock()
        clock2.increment(deviceId: "device2")
        clock2.increment(deviceId: "device2")

        clock1.merge(with: clock2)

        XCTAssertEqual(clock1.clocks["device2"], 2)
        XCTAssertEqual(clock1.clocks.count, 1)
    }

    func testMergeDisjointDevices() throws {
        var clock1 = VectorClock()
        clock1.increment(deviceId: "device1")
        clock1.increment(deviceId: "device1")

        var clock2 = VectorClock()
        clock2.increment(deviceId: "device2")
        clock2.increment(deviceId: "device2")
        clock2.increment(deviceId: "device2")

        clock1.merge(with: clock2)

        XCTAssertEqual(clock1.clocks["device1"], 2)
        XCTAssertEqual(clock1.clocks["device2"], 3)
        XCTAssertEqual(clock1.clocks.count, 2)
    }

    func testMergeOverlappingDevices() throws {
        var clock1 = VectorClock()
        clock1.increment(deviceId: "device1")
        clock1.increment(deviceId: "device2")

        var clock2 = VectorClock()
        clock2.increment(deviceId: "device2")
        clock2.increment(deviceId: "device2")
        clock2.increment(deviceId: "device3")

        clock1.merge(with: clock2)

        XCTAssertEqual(clock1.clocks["device1"], 1)
        XCTAssertEqual(clock1.clocks["device2"], 2, "Should take max value")
        XCTAssertEqual(clock1.clocks["device3"], 1)
        XCTAssertEqual(clock1.clocks.count, 3)
    }

    func testMergeTakesMaxValue() throws {
        var clock1 = VectorClock()
        clock1.clocks["device1"] = 5
        clock1.clocks["device2"] = 3

        var clock2 = VectorClock()
        clock2.clocks["device1"] = 2
        clock2.clocks["device2"] = 8

        clock1.merge(with: clock2)

        XCTAssertEqual(clock1.clocks["device1"], 5, "Should keep higher value (5 > 2)")
        XCTAssertEqual(clock1.clocks["device2"], 8, "Should take higher value (8 > 3)")
    }

    // MARK: - Comparison Tests

    func testCompareEqual() throws {
        var clock1 = VectorClock()
        clock1.increment(deviceId: "device1")
        clock1.increment(deviceId: "device2")

        var clock2 = VectorClock()
        clock2.increment(deviceId: "device1")
        clock2.increment(deviceId: "device2")

        let result = clock1.compare(with: clock2)

        XCTAssertEqual(result, .equal)
    }

    func testCompareEqualEmpty() throws {
        let clock1 = VectorClock()
        let clock2 = VectorClock()

        let result = clock1.compare(with: clock2)

        XCTAssertEqual(result, .equal)
    }

    func testCompareBefore() throws {
        var clock1 = VectorClock()
        clock1.increment(deviceId: "device1")

        var clock2 = VectorClock()
        clock2.increment(deviceId: "device1")
        clock2.increment(deviceId: "device1")

        let result = clock1.compare(with: clock2)

        XCTAssertEqual(result, .before, "clock1 happened before clock2")
    }

    func testCompareAfter() throws {
        var clock1 = VectorClock()
        clock1.increment(deviceId: "device1")
        clock1.increment(deviceId: "device1")
        clock1.increment(deviceId: "device2")

        var clock2 = VectorClock()
        clock2.increment(deviceId: "device1")
        clock2.increment(deviceId: "device1")

        let result = clock1.compare(with: clock2)

        XCTAssertEqual(result, .after, "clock1 happened after clock2")
    }

    func testCompareConcurrent() throws {
        var clock1 = VectorClock()
        clock1.increment(deviceId: "device1")
        clock1.increment(deviceId: "device1")

        var clock2 = VectorClock()
        clock2.increment(deviceId: "device2")
        clock2.increment(deviceId: "device2")

        let result = clock1.compare(with: clock2)

        XCTAssertEqual(result, .concurrent, "Edits on different devices are concurrent")
    }

    func testCompareConcurrentPartialOverlap() throws {
        var clock1 = VectorClock()
        clock1.clocks["device1"] = 5
        clock1.clocks["device2"] = 2

        var clock2 = VectorClock()
        clock2.clocks["device1"] = 3
        clock2.clocks["device2"] = 4

        let result = clock1.compare(with: clock2)

        XCTAssertEqual(result, .concurrent, "Neither dominates the other")
    }

    // MARK: - Helper Methods Tests

    func testIsConcurrent() throws {
        var clock1 = VectorClock()
        clock1.increment(deviceId: "device1")

        var clock2 = VectorClock()
        clock2.increment(deviceId: "device2")

        XCTAssertTrue(clock1.isConcurrent(with: clock2))
    }

    func testIsNotConcurrentWhenBefore() throws {
        var clock1 = VectorClock()
        clock1.increment(deviceId: "device1")

        var clock2 = VectorClock()
        clock2.increment(deviceId: "device1")
        clock2.increment(deviceId: "device1")

        XCTAssertFalse(clock1.isConcurrent(with: clock2))
    }

    func testIsNotConcurrentWhenAfter() throws {
        var clock1 = VectorClock()
        clock1.increment(deviceId: "device1")
        clock1.increment(deviceId: "device1")

        var clock2 = VectorClock()
        clock2.increment(deviceId: "device1")

        XCTAssertFalse(clock1.isConcurrent(with: clock2))
    }

    func testIsNotConcurrentWhenEqual() throws {
        var clock1 = VectorClock()
        clock1.increment(deviceId: "device1")

        var clock2 = VectorClock()
        clock2.increment(deviceId: "device1")

        XCTAssertFalse(clock1.isConcurrent(with: clock2))
    }

    // MARK: - Codable Tests

    func testVectorClockCodable() throws {
        var clock = VectorClock()
        clock.increment(deviceId: "device1")
        clock.increment(deviceId: "device2")
        clock.increment(deviceId: "device1")

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(clock)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VectorClock.self, from: data)

        XCTAssertEqual(decoded.clocks["device1"], 2)
        XCTAssertEqual(decoded.clocks["device2"], 1)
        XCTAssertEqual(decoded.clocks.count, 2)
    }

    // MARK: - Edge Cases

    func testIncrementWithEmptyDeviceId() throws {
        var clock = VectorClock()

        clock.increment(deviceId: "")

        XCTAssertEqual(clock.clocks[""], 1)
    }

    func testMergeWithSelf() throws {
        var clock1 = VectorClock()
        clock1.increment(deviceId: "device1")

        let clock2 = clock1.copy()

        clock1.merge(with: clock2)

        XCTAssertEqual(clock1.clocks["device1"], 1, "Merging with self should be idempotent")
    }

    func testCompareSymmetry() throws {
        var clock1 = VectorClock()
        clock1.increment(deviceId: "device1")

        var clock2 = VectorClock()
        clock2.increment(deviceId: "device1")
        clock2.increment(deviceId: "device1")

        let result1 = clock1.compare(with: clock2)
        let result2 = clock2.compare(with: clock1)

        XCTAssertEqual(result1, .before)
        XCTAssertEqual(result2, .after)
    }

    func testLargeCounterValues() throws {
        var clock = VectorClock()

        // Simulate many operations
        for _ in 0..<10000 {
            clock.increment(deviceId: "device1")
        }

        XCTAssertEqual(clock.clocks["device1"], 10000)
    }

    // MARK: - Real-World Scenarios

    func testScenarioSequentialEdits() throws {
        // Device 1 edits, then Device 2 edits
        var clock1 = VectorClock()
        clock1.increment(deviceId: "device1")

        var clock2 = clock1.copy()
        clock2.increment(deviceId: "device2")

        let result = clock1.compare(with: clock2)

        XCTAssertEqual(result, .before, "Sequential edits should be ordered")
    }

    func testScenarioParallelEdits() throws {
        // Device 1 and Device 2 edit independently (offline)
        var clock1 = VectorClock()
        clock1.increment(deviceId: "device1")
        clock1.increment(deviceId: "device1")

        var clock2 = VectorClock()
        clock2.increment(deviceId: "device2")

        let result = clock1.compare(with: clock2)

        XCTAssertEqual(result, .concurrent, "Parallel offline edits are concurrent")
    }

    func testScenarioThreeWayMerge() throws {
        // Device 1, 2, and 3 all edit independently
        var clock1 = VectorClock()
        clock1.increment(deviceId: "device1")

        var clock2 = VectorClock()
        clock2.increment(deviceId: "device2")

        var clock3 = VectorClock()
        clock3.increment(deviceId: "device3")

        // Merge all together
        clock1.merge(with: clock2)
        clock1.merge(with: clock3)

        XCTAssertEqual(clock1.clocks["device1"], 1)
        XCTAssertEqual(clock1.clocks["device2"], 1)
        XCTAssertEqual(clock1.clocks["device3"], 1)
        XCTAssertEqual(clock1.clocks.count, 3)
    }

    func testScenarioMergeAfterIncrement() throws {
        var clock1 = VectorClock()
        clock1.increment(deviceId: "device1")

        var clock2 = clock1.copy()
        clock2.increment(deviceId: "device2")

        var clock3 = clock1.copy()
        clock3.increment(deviceId: "device3")

        // Merge clock2 and clock3 into clock1
        clock1.merge(with: clock2)
        clock1.merge(with: clock3)

        XCTAssertEqual(clock1.clocks["device1"], 1)
        XCTAssertEqual(clock1.clocks["device2"], 1)
        XCTAssertEqual(clock1.clocks["device3"], 1)

        // All should see each other's changes
        let result1 = clock1.compare(with: clock2)
        let result2 = clock1.compare(with: clock3)

        XCTAssertEqual(result1, .after)
        XCTAssertEqual(result2, .after)
    }
}
