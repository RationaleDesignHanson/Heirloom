import Testing
import Foundation
import SwiftData

@testable import Heirloom

@Suite("CRDT Adversarial Tests - Conflict Resolution and Edge Cases")
struct CRDTAdversarialTests {

    // MARK: - Test Setup Helper

    func createTestContext() -> ModelContext {
        let schema = Schema([
            Heirloom.Recipe.self,
            Heirloom.Ingredient.self,
            Heirloom.Tag.self,
            Heirloom.RecipeCollection.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    // MARK: - Three-Way Concurrent Conflict Tests

    @Test("CRDT: Three-way concurrent conflict detection")
    func testCRDT_ThreeWayConflict_Detected() {
        // Arrange - Three devices edit the same field concurrently
        let deviceA = "device-A"
        let deviceB = "device-B"
        let deviceC = "device-C"

        // Create vector clocks for concurrent edits
        let clockA = VectorClock(clocks: [deviceA: 5, deviceB: 3, deviceC: 2])
        let clockB = VectorClock(clocks: [deviceA: 4, deviceB: 6, deviceC: 2])
        let clockC = VectorClock(clocks: [deviceA: 4, deviceB: 3, deviceC: 7])

        // Assert - All three clocks are concurrent with each other
        #expect(clockA.compare(with: clockB) == .concurrent)
        #expect(clockB.compare(with: clockC) == .concurrent)
        #expect(clockA.compare(with: clockC) == .concurrent)

        // This documents the behavior: concurrent 3-way conflicts can occur
        // The merge engine needs to handle this case
        // Current behavior: Last-write-wins based on timestamp
        // Potential issue: Data loss if all three had valuable changes
    }

    @Test("CRDT: Clock poisoning with future timestamp")
    func testCRDT_ClockPoisoning_FutureTimestamp() {
        // Arrange - Malicious device sets clock to future date
        let normalDevice = "device-normal"
        let maliciousDevice = "device-malicious"

        let normalClock = VectorClock(clocks: [normalDevice: 10])
        let poisonedClock = VectorClock(clocks: [maliciousDevice: 999999]) // Extremely high value

        // Act - Merge clocks
        normalClock.merge(with: poisonedClock)

        // Assert - EXPECTED TO DOCUMENT VULNERABILITY
        // The poisoned clock value is accepted
        #expect(normalClock.value(for: maliciousDevice) == 999999)

        // What this means:
        // A malicious device can set its clock arbitrarily high, causing it to
        // dominate all future merges (last-write-wins will always favor it)
        //
        // What we WANT:
        // - Clock value validation (reject unreasonably high values)
        // - Clock drift detection
        // - Ability to reset/ignore poisoned clocks
    }

    @Test("CRDT: Operation log with 10K entries - memory stress test")
    func testCRDT_OperationLog_LargeHistory() {
        // Arrange - Simulate a recipe edited 10,000 times
        let recipeId = UUID()
        let deviceId = "device-test"

        var operations: [RecipeOperation] = []
        let vectorClock = VectorClock(clocks: [deviceId: 1])

        // Act - Create 10K operations
        for i in 0..<10_000 {
            let operation = RecipeOperation(
                recipeId: recipeId,
                deviceId: deviceId,
                vectorClock: vectorClock,
                timestamp: Date().addingTimeInterval(Double(i)),
                operationType: .update,
                fieldPath: "title",
                oldValue: nil,
                newValue: nil
            )
            operations.append(operation)
            vectorClock.increment(deviceId: deviceId)
        }

        // Assert - Documents current behavior
        #expect(operations.count == 10_000)

        // Memory/Performance concerns:
        // - Each operation stores VectorClock (potentially large)
        // - No operation log pruning/compaction
        // - Merge with another 10K operation log = 20K operations
        // - UI rendering 10K operations would freeze
        //
        // What we WANT:
        // - Operation log compaction (merge sequential edits)
        // - Operation history limits (keep last 1000 operations)
        // - Snapshot system (snapshot every 100 operations, discard old ops)
    }

    // MARK: - Malformed Field Path Tests

    @Test("CRDT: Malformed field path with invalid array index")
    func testCRDT_MalformedFieldPath_InvalidArrayIndex() {
        // Arrange - Operation with non-numeric array index
        let recipeId = UUID()
        let malformedFieldPath = "ingredients[abc]" // Should be "ingredients[0]"

        // Act - Create operation with malformed path
        let operation = RecipeOperation(
            recipeId: recipeId,
            deviceId: "device-test",
            vectorClock: VectorClock(),
            operationType: .update,
            fieldPath: malformedFieldPath,
            oldValue: nil,
            newValue: nil
        )

        // Assert - EXPECTED TO FAIL when applied
        // The operation is created successfully (no validation at creation)
        #expect(operation.fieldPath == "ingredients[abc]")

        // Potential vulnerability:
        // CRDTMergeEngine.applyOperation (lines 283-299) parses array indices
        // If parsing fails, behavior is undefined
        // Could cause: crash, silent failure, or data corruption
        //
        // What we WANT:
        // - Field path validation at operation creation
        // - Graceful error handling in applyOperation
        // - Reject operations with invalid field paths
    }

    @Test("CRDT: Malformed field path with negative array index")
    func testCRDT_MalformedFieldPath_NegativeIndex() {
        // Arrange
        let recipeId = UUID()
        let malformedFieldPath = "ingredients[-1]" // Negative index

        // Act
        let operation = RecipeOperation(
            recipeId: recipeId,
            deviceId: "device-test",
            vectorClock: VectorClock(),
            operationType: .update,
            fieldPath: malformedFieldPath,
            oldValue: nil,
            newValue: nil
        )

        // Assert - EXPECTED TO DOCUMENT VULNERABILITY
        #expect(operation.fieldPath == "ingredients[-1]")

        // Negative indices could:
        // - Crash when parsing to Int
        // - Access wrong array elements (Swift allows negative subscripts)
        // - Cause out-of-bounds errors
        //
        // What we WANT:
        // - Validate array indices are >= 0
        // - Bounds checking before array access
    }

    @Test("CRDT: Malformed field path with special characters")
    func testCRDT_MalformedFieldPath_SpecialChars() {
        // Arrange - Test path traversal, injection attempts
        let maliciousPaths = [
            "../../../root",           // Path traversal
            "title'; DROP TABLE--",    // SQL injection pattern
            "ingredients[0]..<script>", // XSS attempt
            "notes\0hidden",            // Null byte injection
            "ingredients[9999999]"      // Out of bounds
        ]

        // Act & Assert - All paths accepted without validation
        for path in maliciousPaths {
            let operation = RecipeOperation(
                recipeId: UUID(),
                deviceId: "device-test",
                vectorClock: VectorClock(),
                operationType: .update,
                fieldPath: path,
                oldValue: nil,
                newValue: nil
            )

            #expect(operation.fieldPath == path)
        }

        // Documents: No field path sanitization or validation
        // These operations could be stored in Firebase and synced to all devices
        //
        // What we WANT:
        // - Whitelist of allowed field paths
        // - Reject operations with suspicious characters
        // - Field path format validation (regex match)
    }

    // MARK: - Empty/Edge Case Tests

    @Test("CRDT: Empty VectorClock merge")
    func testCRDT_EmptyVectorClock_Merge() {
        // Arrange
        let emptyClock = VectorClock(clocks: [:])
        let normalClock = VectorClock(clocks: ["device-A": 5])

        // Act
        emptyClock.merge(with: normalClock)

        // Assert - Empty clock adopts all values from normal clock
        #expect(emptyClock.value(for: "device-A") == 5)

        // Documents: Empty clocks are handled correctly
        // Edge case: What if both clocks are empty?
        let emptyA = VectorClock(clocks: [:])
        let emptyB = VectorClock(clocks: [:])
        emptyA.merge(with: emptyB)
        #expect(emptyA.clocks.isEmpty) // Both remain empty - OK
    }

    @Test("CRDT: Circular delete conflict - both devices delete same field")
    func testCRDT_CircularDelete_BothDevicesDelete() {
        // Arrange - Both devices attempt to delete the same field concurrently
        let deviceA = "device-A"
        let deviceB = "device-B"
        let recipeId = UUID()

        let clockA = VectorClock(clocks: [deviceA: 5, deviceB: 4])
        let clockB = VectorClock(clocks: [deviceA: 4, deviceB: 6])

        // Both operations delete "notes" field
        let opA = RecipeOperation(
            recipeId: recipeId,
            deviceId: deviceA,
            vectorClock: clockA,
            timestamp: Date(),
            operationType: .delete,
            fieldPath: "notes",
            oldValue: nil,
            newValue: nil // .null in OperationValue
        )

        let opB = RecipeOperation(
            recipeId: recipeId,
            deviceId: deviceB,
            vectorClock: clockB,
            timestamp: Date().addingTimeInterval(1), // Slightly later
            operationType: .delete,
            fieldPath: "notes",
            oldValue: nil,
            newValue: nil
        )

        // Assert - Both are concurrent (not causally related)
        #expect(clockA.compare(with: clockB) == .concurrent)

        // Both operations are delete operations
        #expect(opA.operationType == .delete)
        #expect(opB.operationType == .delete)

        // Documents: CRDTMergeEngine "delete wins" rule (lines 113-116)
        // When both are deletes, the conflict is trivially resolved (both want same outcome)
        // Edge case is correctly handled
        //
        // More complex case: What if one deletes field and other updates it?
        // Answer: Delete wins (line 143 of CRDTMergeEngine)
    }

    // MARK: - Concurrent Modification Tests

    @Test("CRDT: Concurrent array additions - order preservation")
    func testCRDT_ConcurrentArrayAdd_OrderPreservation() {
        // Arrange - Two devices add different ingredients concurrently
        let deviceA = "device-A"
        let deviceB = "device-B"
        let recipeId = UUID()

        let clockA = VectorClock(clocks: [deviceA: 10, deviceB: 5])
        let clockB = VectorClock(clocks: [deviceA: 9, deviceB: 12])

        // Device A adds "salt"
        let opA = RecipeOperation(
            recipeId: recipeId,
            deviceId: deviceA,
            vectorClock: clockA,
            timestamp: Date(timeIntervalSince1970: 1000),
            operationType: .addIngredient,
            fieldPath: "ingredients[5]",
            oldValue: nil,
            newValue: nil // Would contain ingredient data
        )

        // Device B adds "pepper" to same array index concurrently
        let opB = RecipeOperation(
            recipeId: recipeId,
            deviceId: deviceB,
            vectorClock: clockB,
            timestamp: Date(timeIntervalSince1970: 1001),
            operationType: .addIngredient,
            fieldPath: "ingredients[5]", // Same index!
            oldValue: nil,
            newValue: nil
        )

        // Assert - Operations are concurrent
        #expect(clockA.compare(with: clockB) == .concurrent)

        // Both target same array index
        #expect(opA.fieldPath == "ingredients[5]")
        #expect(opB.fieldPath == "ingredients[5]")

        // Documents: CRDTMergeEngine "both add" rule (lines 97-102)
        // Both ingredients should be kept, but what about array indices?
        // If both try to insert at index 5, which one goes to index 5 and which to index 6?
        //
        // Potential issue: Array indices could become inconsistent
        // What we WANT:
        // - Use timestamps to deterministically order concurrent adds
        // - Or use unique IDs instead of array indices
        // - Document the ordering behavior clearly
    }

    @Test("CRDT: VectorClock with 100+ devices - scalability test")
    func testCRDT_VectorClock_ManyDevices() {
        // Arrange - Simulate recipe edited by 100 different devices
        let clock = VectorClock()

        // Act - Add 100 devices
        for i in 0..<100 {
            clock.increment(deviceId: "device-\(i)")
        }

        // Assert - All 100 devices tracked
        #expect(clock.clocks.count == 100)

        // Performance concern:
        // - VectorClock comparison is O(n) where n = number of devices
        // - With 100 devices, each comparison checks 100 entries
        // - Merge operation logs with 1000 operations = 100K comparisons
        // - Memory: Each RecipeOperation stores a full VectorClock copy
        //
        // What we WANT:
        // - VectorClock size limits (warn after 50 devices)
        // - VectorClock compaction (remove devices with no recent activity)
        // - Performance testing with realistic device counts
    }

    // MARK: - Edge Cases

    @Test("CRDT: VectorClock with Int64 overflow potential")
    func testCRDT_VectorClock_Int64Overflow() {
        // Arrange - Simulate device with extremely high clock value
        let deviceId = "device-test"
        let clock = VectorClock(clocks: [deviceId: Int64.max - 10])

        // Act - Try to increment near overflow
        for _ in 0..<20 {
            clock.increment(deviceId: deviceId)
        }

        // Assert - EXPECTED TO FAIL or wrap around
        let finalValue = clock.value(for: deviceId)

        // Documents behavior: Does it crash, wrap around, or handle overflow?
        // Int64.max = 9,223,372,036,854,775,807
        // After 11 increments from (Int64.max - 10), we exceed Int64.max
        //
        // What happens?
        // Swift Int64 addition crashes on overflow in debug mode
        // In release mode, it wraps around to negative numbers
        //
        // What we WANT:
        // - Detect approaching overflow (> Int64.max - 1000)
        // - Reset clock or reject further increments
        // - Or use UInt64 (twice the range, no negatives)

        print("Final clock value after overflow attempt: \(finalValue)")
        // This test documents overflow behavior - may crash in debug builds
    }
}
