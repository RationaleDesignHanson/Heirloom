//
//  OperationLog.swift
//  Heirloom
//
//  Created by Claude on 12/31/25.
//

import Foundation
import SwiftData

/// Append-only log of all operations performed on a recipe
/// Used for CRDT merge and conflict resolution
@Model
final class OperationLog: Codable {
    // MARK: - Properties

    /// Recipe this log belongs to
    var recipeId: UUID

    /// All operations in chronological order (append-only)
    var operations: [RecipeOperation]

    /// Current vector clock (maximum of all operation vector clocks)
    var vectorClock: VectorClock

    /// When this log was last updated
    var lastUpdated: Date

    // MARK: - Initialization

    init(recipeId: UUID, operations: [RecipeOperation] = [], vectorClock: VectorClock? = nil) {
        self.recipeId = recipeId
        self.operations = operations
        self.vectorClock = vectorClock ?? VectorClock()
        self.lastUpdated = Date()
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case recipeId
        case operations
        case vectorClock
        case lastUpdated
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.recipeId = try container.decode(UUID.self, forKey: .recipeId)
        self.operations = try container.decode([RecipeOperation].self, forKey: .operations)
        self.vectorClock = try container.decode(VectorClock.self, forKey: .vectorClock)
        self.lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recipeId, forKey: .recipeId)
        try container.encode(operations, forKey: .operations)
        try container.encode(vectorClock, forKey: .vectorClock)
        try container.encode(lastUpdated, forKey: .lastUpdated)
    }

    // MARK: - Operation Management

    /// Append a new operation to the log
    func append(_ operation: RecipeOperation) {
        operations.append(operation)
        vectorClock.merge(with: operation.vectorClock)
        lastUpdated = Date()
    }

    /// Append multiple operations at once
    func appendBatch(_ newOperations: [RecipeOperation]) {
        operations.append(contentsOf: newOperations)
        for operation in newOperations {
            vectorClock.merge(with: operation.vectorClock)
        }
        lastUpdated = Date()
    }

    /// Get operations after a specific vector clock (for incremental sync)
    func operationsAfter(_ clock: VectorClock) -> [RecipeOperation] {
        return operations.filter { operation in
            !operation.vectorClock.happenedBefore(clock) && operation.vectorClock != clock
        }
    }

    /// Get operations by a specific device
    func operations(by deviceId: String) -> [RecipeOperation] {
        return operations.filter { $0.deviceId == deviceId }
    }

    /// Get operations for a specific field
    func operations(for fieldPath: String) -> [RecipeOperation] {
        return operations.filter { $0.fieldPath == fieldPath }
    }

    /// Get the most recent operation for a field
    func latestOperation(for fieldPath: String) -> RecipeOperation? {
        return operations(for: fieldPath).sorted { $0.timestamp > $1.timestamp }.first
    }

    /// Find conflicting operations (concurrent operations on same field)
    func findConflicts() -> [FieldConflict] {
        var conflicts: [FieldConflict] = []
        var processedPairs = Set<String>()

        // Group operations by field
        let fieldOperations = Dictionary(grouping: operations, by: { $0.fieldPath })

        for (fieldPath, ops) in fieldOperations {
            // Check each pair of operations for this field
            for i in 0..<ops.count {
                for j in (i+1)..<ops.count {
                    let op1 = ops[i]
                    let op2 = ops[j]

                    // Create unique key for this pair
                    let pairKey = [op1.id.uuidString, op2.id.uuidString].sorted().joined(separator: "-")

                    // Skip if already processed
                    if processedPairs.contains(pairKey) {
                        continue
                    }

                    // Check if operations conflict (concurrent + same field)
                    if op1.conflicts(with: op2) {
                        conflicts.append(FieldConflict(
                            fieldPath: fieldPath,
                            operation1: op1,
                            operation2: op2
                        ))
                        processedPairs.insert(pairKey)
                    }
                }
            }
        }

        return conflicts
    }

    /// Get a summary of changes grouped by device
    func changesSummary() -> [String: [RecipeOperation]] {
        return Dictionary(grouping: operations, by: { $0.deviceId })
    }

    /// Create a copy of this operation log
    func copy() -> OperationLog {
        return OperationLog(
            recipeId: recipeId,
            operations: operations,
            vectorClock: vectorClock.copy()
        )
    }

    // MARK: - Merge with Another Log

    /// Merge operations from another log (for CRDT merge)
    func merge(with other: OperationLog) {
        // Add operations that don't already exist (by operation ID)
        let existingIds = Set(operations.map { $0.id })
        let newOperations = other.operations.filter { !existingIds.contains($0.id) }

        appendBatch(newOperations)

        // Sort operations by timestamp to maintain chronological order
        operations.sort { $0.timestamp < $1.timestamp }
    }
}

// MARK: - Field Conflict

/// Represents a conflict between two concurrent operations on the same field
struct FieldConflict {
    let fieldPath: String
    let operation1: RecipeOperation
    let operation2: RecipeOperation

    /// User-friendly description of the conflict
    var displayDescription: String {
        let device1 = operation1.metadata["deviceName"] ?? "Device 1"
        let device2 = operation2.metadata["deviceName"] ?? "Device 2"
        return "Conflict on \(fieldDisplayName): \(device1) vs \(device2)"
    }

    /// User-friendly field name
    var fieldDisplayName: String {
        if fieldPath.starts(with: "ingredients") {
            return "ingredient"
        } else if fieldPath.starts(with: "instructions") {
            return "instruction"
        } else if fieldPath == "title" {
            return "title"
        } else if fieldPath == "notes" {
            return "notes"
        } else if fieldPath == "prepTime" {
            return "prep time"
        } else if fieldPath == "cookTime" {
            return "cook time"
        } else {
            return fieldPath
        }
    }
}

// MARK: - Firestore Serialization

extension OperationLog {
    /// Convert to Firestore-compatible dictionary
    func toFirestoreData() -> [String: Any] {
        return [
            "recipeId": recipeId.uuidString,
            "operations": operations.map { $0.toFirestoreData() },
            "vectorClock": vectorClock.toFirestoreData(),
            "lastUpdated": lastUpdated
        ]
    }

    /// Create from Firestore dictionary
    static func from(firestoreData: [String: Any]) -> OperationLog? {
        guard let recipeIdString = firestoreData["recipeId"] as? String,
              let recipeId = UUID(uuidString: recipeIdString),
              let operationsData = firestoreData["operations"] as? [[String: Any]],
              let vectorClockData = firestoreData["vectorClock"] as? [String: Any],
              let vectorClock = VectorClock.from(firestoreData: vectorClockData),
              let lastUpdated = firestoreData["lastUpdated"] as? Date else {
            return nil
        }

        let operations = operationsData.compactMap { RecipeOperation.from(firestoreData: $0) }

        let log = OperationLog(recipeId: recipeId, operations: operations, vectorClock: vectorClock)
        log.lastUpdated = lastUpdated
        return log
    }
}

// MARK: - CustomStringConvertible

extension OperationLog: CustomStringConvertible {
    var description: String {
        return "OperationLog(recipeId: \(recipeId), operations: \(operations.count), vectorClock: \(vectorClock))"
    }
}
