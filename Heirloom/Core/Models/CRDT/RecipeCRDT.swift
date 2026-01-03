//
//  RecipeCRDT.swift
//  Heirloom
//
//  Created by Claude on 12/31/25.
//

import Foundation
import SwiftData
#if os(iOS)
import UIKit
#endif

/// CRDT wrapper around Recipe with conflict-free merge logic
/// Tracks operations and vector clocks for distributed editing
@Model
final class RecipeCRDT {
    // MARK: - Properties

    /// The underlying recipe data
    var recipe: Recipe

    /// Operation log for this recipe (append-only)
    var operationLog: OperationLog

    /// Current device ID (for tracking local operations)
    var deviceId: String

    /// When this CRDT was last modified
    var lastModified: Date

    // MARK: - Initialization

    init(recipe: Recipe, deviceId: String) {
        self.recipe = recipe
        self.deviceId = deviceId
        self.operationLog = OperationLog(recipeId: recipe.id)
        self.lastModified = Date()
    }

    // MARK: - CRDT Operations

    /// Record an update operation to a field
    func updateField(
        fieldPath: String,
        oldValue: OperationValue?,
        newValue: OperationValue?,
        metadata: [String: String] = [:]
    ) {
        // Increment vector clock for this device
        operationLog.vectorClock.increment(deviceId: deviceId)

        // Create operation
        let operation = RecipeOperation(
            recipeId: recipe.id,
            deviceId: deviceId,
            vectorClock: operationLog.vectorClock.copy(),
            operationType: .update,
            fieldPath: fieldPath,
            oldValue: oldValue,
            newValue: newValue,
            metadata: metadata
        )

        // Append to log
        operationLog.append(operation)
        lastModified = Date()
    }

    /// Record an add ingredient operation
    func addIngredient(
        _ ingredientText: String,
        at index: Int,
        metadata: [String: String] = [:]
    ) {
        operationLog.vectorClock.increment(deviceId: deviceId)

        let operation = RecipeOperation(
            recipeId: recipe.id,
            deviceId: deviceId,
            vectorClock: operationLog.vectorClock.copy(),
            operationType: .addIngredient,
            fieldPath: "ingredients[\(index)]",
            oldValue: nil,
            newValue: .string(ingredientText),
            metadata: metadata
        )

        operationLog.append(operation)
        lastModified = Date()
    }

    /// Record an add instruction operation
    func addInstruction(
        _ instructionText: String,
        at index: Int,
        metadata: [String: String] = [:]
    ) {
        operationLog.vectorClock.increment(deviceId: deviceId)

        let operation = RecipeOperation(
            recipeId: recipe.id,
            deviceId: deviceId,
            vectorClock: operationLog.vectorClock.copy(),
            operationType: .addInstruction,
            fieldPath: "instructions[\(index)]",
            oldValue: nil,
            newValue: .string(instructionText),
            metadata: metadata
        )

        operationLog.append(operation)
        lastModified = Date()
    }

    /// Record recipe creation
    func recordCreation(metadata: [String: String] = [:]) {
        operationLog.vectorClock.increment(deviceId: deviceId)

        let operation = RecipeOperation(
            recipeId: recipe.id,
            deviceId: deviceId,
            vectorClock: operationLog.vectorClock.copy(),
            operationType: .create,
            fieldPath: "recipe",
            oldValue: nil,
            newValue: nil,
            metadata: metadata
        )

        operationLog.append(operation)
        lastModified = Date()
    }

    // MARK: - Merge Logic

    /// Merge with another RecipeCRDT (CRDT merge)
    /// Returns the merge result indicating if conflicts were found
    func merge(with other: RecipeCRDT) -> MergeResult {
        // Merge operation logs
        operationLog.merge(with: other.operationLog)

        // Find any conflicts
        let conflicts = operationLog.findConflicts()

        if conflicts.isEmpty {
            // No conflicts - apply all operations
            return .success(conflictsResolved: 0)
        } else {
            // Conflicts found - need user resolution
            return .needsResolution(conflicts: conflicts)
        }
    }

    /// Apply operations from another CRDT (for incremental sync)
    func applyOperations(from other: RecipeCRDT, after clock: VectorClock) {
        let newOperations = other.operationLog.operationsAfter(clock)
        operationLog.appendBatch(newOperations)
        lastModified = Date()
    }

    /// Get operations that the other CRDT hasn't seen yet
    func operationsNotSeenBy(_ other: RecipeCRDT) -> [RecipeOperation] {
        return operationLog.operationsAfter(other.operationLog.vectorClock)
    }

    // MARK: - Conflict Detection

    /// Check if this CRDT has conflicts with another
    func hasConflicts(with other: RecipeCRDT) -> Bool {
        // Merge logs temporarily to detect conflicts
        let tempLog = operationLog.copy()
        tempLog.merge(with: other.operationLog)
        return !tempLog.findConflicts().isEmpty
    }

    /// Get all current conflicts in this CRDT
    func currentConflicts() -> [FieldConflict] {
        return operationLog.findConflicts()
    }

    // MARK: - State Queries

    /// Get a summary of changes by device
    func changesSummary() -> [String: [RecipeOperation]] {
        return operationLog.changesSummary()
    }

    /// Get the latest modification time for a specific field
    func lastModifiedTime(for fieldPath: String) -> Date? {
        return operationLog.latestOperation(for: fieldPath)?.timestamp
    }

    /// Get all devices that have edited this recipe
    func contributingDevices() -> Set<String> {
        return Set(operationLog.operations.map { $0.deviceId })
    }

    /// Check if this CRDT is ahead of another (has operations the other hasn't seen)
    func isAhead(of other: RecipeCRDT) -> Bool {
        return !operationsNotSeenBy(other).isEmpty
    }

    /// Check if this CRDT is behind another (other has operations this hasn't seen)
    func isBehind(_ other: RecipeCRDT) -> Bool {
        return !other.operationsNotSeenBy(self).isEmpty
    }

    /// Check if CRDTs are in sync (same vector clock)
    func isSynced(with other: RecipeCRDT) -> Bool {
        // If both vector clocks are empty (no CRDT operations yet),
        // compare modifiedAt timestamps to determine if in sync
        if operationLog.vectorClock.clocks.isEmpty && other.operationLog.vectorClock.clocks.isEmpty {
            return recipe.modifiedAt == other.recipe.modifiedAt
        }

        return operationLog.vectorClock == other.operationLog.vectorClock
    }
}

// MARK: - Merge Result

enum MergeResult {
    case success(conflictsResolved: Int)
    case needsResolution(conflicts: [FieldConflict])

    var requiresUserResolution: Bool {
        if case .needsResolution = self {
            return true
        }
        return false
    }

    var conflicts: [FieldConflict] {
        if case .needsResolution(let conflicts) = self {
            return conflicts
        }
        return []
    }
}

// MARK: - Firestore Serialization

extension RecipeCRDT {
    /// Convert to Firestore-compatible dictionary
    func toFirestoreData() -> [String: Any] {
        // Note: Recipe serialization handled separately in FirebaseSyncService
        return [
            "operationLog": operationLog.toFirestoreData(),
            "deviceId": deviceId,
            "lastModified": lastModified
        ]
    }

    /// Create from Firestore dictionary (recipe loaded separately)
    static func from(firestoreData: [String: Any], recipe: Recipe) -> RecipeCRDT? {
        guard let operationLogData = firestoreData["operationLog"] as? [String: Any],
              let operationLog = OperationLog.from(firestoreData: operationLogData),
              let deviceId = firestoreData["deviceId"] as? String,
              let lastModified = firestoreData["lastModified"] as? Date else {
            return nil
        }

        let crdt = RecipeCRDT(recipe: recipe, deviceId: deviceId)
        crdt.operationLog = operationLog
        crdt.lastModified = lastModified
        return crdt
    }
}

// MARK: - Convenience Helpers

extension RecipeCRDT {
    /// Get metadata for current device (for operation recording)
    func currentDeviceMetadata() -> [String: String] {
        var metadata: [String: String] = [:]
        metadata["deviceId"] = deviceId

        // Try to get user-friendly device name
        #if os(iOS)
        metadata["deviceName"] = UIDevice.current.name
        #elseif os(macOS)
        metadata["deviceName"] = Host.current().localizedName ?? "Mac"
        #else
        metadata["deviceName"] = "Unknown Device"
        #endif

        return metadata
    }

    /// Record a title change
    func updateTitle(from old: String?, to new: String) {
        updateField(
            fieldPath: "title",
            oldValue: old.map { .string($0) },
            newValue: .string(new),
            metadata: currentDeviceMetadata()
        )
    }

    /// Record a notes change
    func updateNotes(from old: String?, to new: String?) {
        updateField(
            fieldPath: "notes",
            oldValue: old.map { .string($0) },
            newValue: new.map { .string($0) } ?? .null,
            metadata: currentDeviceMetadata()
        )
    }

    /// Record a prep time change
    func updatePrepTime(from old: String?, to new: String?) {
        updateField(
            fieldPath: "prepTime",
            oldValue: old.map { .string($0) },
            newValue: new.map { .string($0) } ?? .null,
            metadata: currentDeviceMetadata()
        )
    }

    /// Record a cook time change
    func updateCookTime(from old: String?, to new: String?) {
        updateField(
            fieldPath: "cookTime",
            oldValue: old.map { .string($0) },
            newValue: new.map { .string($0) } ?? .null,
            metadata: currentDeviceMetadata()
        )
    }

    /// Record a servings change
    func updateServings(from old: String?, to new: String?) {
        updateField(
            fieldPath: "servings",
            oldValue: old.map { .string($0) },
            newValue: new.map { .string($0) } ?? .null,
            metadata: currentDeviceMetadata()
        )
    }
}

// MARK: - CustomStringConvertible

extension RecipeCRDT: CustomStringConvertible {
    var description: String {
        return "RecipeCRDT(recipe: \(recipe.title), operations: \(operationLog.operations.count), vectorClock: \(operationLog.vectorClock))"
    }
}
