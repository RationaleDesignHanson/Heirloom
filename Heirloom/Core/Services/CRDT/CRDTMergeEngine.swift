//
//  CRDTMergeEngine.swift
//  Heirloom
//
//  Created by Claude on 12/31/25.
//

import Foundation
import SwiftData

/// Core engine for merging Recipe CRDTs with conflict detection
class CRDTMergeEngine {
    // MARK: - Singleton

    static let shared = CRDTMergeEngine()

    private init() {}

    // MARK: - Merge Operations

    /// Merge two RecipeCRDTs and return the result
    /// - Parameters:
    ///   - local: The local CRDT (current device)
    ///   - remote: The remote CRDT (from Firebase/other device)
    /// - Returns: Merged CRDT and resolution status
    func merge(local: RecipeCRDT, remote: RecipeCRDT) -> MergeOperationResult {
        print("🔄 [CRDT] Merging recipes: \(local.recipe.title)")
        print("   Local vector clock: \(local.operationLog.vectorClock)")
        print("   Remote vector clock: \(remote.operationLog.vectorClock)")

        // Check if already in sync
        if local.isSynced(with: remote) {
            print("✅ [CRDT] Recipes already in sync")
            return .alreadyInSync
        }

        // Merge operation logs
        let mergedCRDT = local
        mergedCRDT.operationLog.merge(with: remote.operationLog)

        // Detect conflicts
        let conflicts = mergedCRDT.currentConflicts()

        if conflicts.isEmpty {
            print("✅ [CRDT] Merge completed without conflicts")

            // Apply all operations to recipe
            applyOperationsToRecipe(mergedCRDT)

            return .autoMerged(result: mergedCRDT)
        } else {
            print("⚠️ [CRDT] Merge detected \(conflicts.count) conflict(s)")

            // Try auto-merge strategy
            let autoMergeableConflicts = conflicts.filter { canAutoMerge($0) }
            let userResolutionNeeded = conflicts.filter { !canAutoMerge($0) }

            if userResolutionNeeded.isEmpty {
                print("✅ [CRDT] All conflicts auto-mergeable")

                // Auto-resolve conflicts
                for conflict in autoMergeableConflicts {
                    autoResolveConflict(conflict, in: mergedCRDT)
                }

                applyOperationsToRecipe(mergedCRDT)

                return .autoMerged(result: mergedCRDT, resolvedConflicts: autoMergeableConflicts.count)
            } else {
                print("⚠️ [CRDT] \(userResolutionNeeded.count) conflict(s) require user resolution")

                // Build detailed conflict info for UI
                let detailedConflicts = userResolutionNeeded.map { conflict in
                    buildDetailedConflict(from: conflict, in: mergedCRDT)
                }

                return .needsUserResolution(
                    conflicts: detailedConflicts,
                    partialCRDT: mergedCRDT,
                    autoResolvedCount: autoMergeableConflicts.count
                )
            }
        }
    }

    // MARK: - Conflict Detection & Resolution

    /// Check if a conflict can be automatically resolved
    private func canAutoMerge(_ conflict: FieldConflict) -> Bool {
        // Auto-merge rules:
        // 1. Both operations added to array (ingredients, instructions) = merge both
        // 2. One operation is delete, other is no-op = use delete
        // 3. Same value with different timestamps = use latest

        let op1 = conflict.operation1
        let op2 = conflict.operation2

        // Rule 1: Both are additive operations (add ingredient/instruction)
        if op1.operationType == .addIngredient && op2.operationType == .addIngredient {
            // Check if values are different (not duplicate adds)
            if op1.newValue != op2.newValue {
                return true  // Can merge both
            }
        }

        if op1.operationType == .addInstruction && op2.operationType == .addInstruction {
            if op1.newValue != op2.newValue {
                return true  // Can merge both
            }
        }

        // Rule 2: One is delete (either .delete operation type or .null value)
        let op1IsDelete = op1.operationType == .delete || op1.newValue == .null
        let op2IsDelete = op2.operationType == .delete || op2.newValue == .null

        if op1IsDelete || op2IsDelete {
            return true  // Delete wins
        }

        // Rule 3: Same value, different timestamps
        if op1.newValue == op2.newValue {
            return true  // Values agree, just use latest timestamp
        }

        // Otherwise, needs user resolution
        return false
    }

    /// Auto-resolve a conflict using merge strategy
    private func autoResolveConflict(_ conflict: FieldConflict, in crdt: RecipeCRDT) {
        let op1 = conflict.operation1
        let op2 = conflict.operation2

        print("🔧 [CRDT] Auto-resolving conflict on: \(conflict.fieldPath)")

        // Apply resolution based on type
        if op1.operationType == .addIngredient && op2.operationType == .addIngredient {
            // Both added ingredients - keep both
            print("   → Keeping both added ingredients")
            // Operations already in log, will be applied together
        } else if op1.operationType == .addInstruction && op2.operationType == .addInstruction {
            // Both added instructions - keep both
            print("   → Keeping both added instructions")
        } else if op1.operationType == .delete || op2.operationType == .delete || op1.newValue == .null || op2.newValue == .null {
            // Delete wins (either explicit delete operation or null value)
            print("   → Delete operation wins")
            // Apply delete operation (the one with .null or .delete)
        } else if op1.newValue == op2.newValue {
            // Same value - use latest timestamp
            let winner = op1.timestamp > op2.timestamp ? op1 : op2
            print("   → Using operation with latest timestamp: \(winner.timestamp)")
        }
    }

    /// Build detailed conflict information for UI
    private func buildDetailedConflict(from conflict: FieldConflict, in crdt: RecipeCRDT) -> DetailedConflict {
        let op1 = conflict.operation1
        let op2 = conflict.operation2

        let device1Name = op1.metadata["deviceName"] ?? "Device 1"
        let device2Name = op2.metadata["deviceName"] ?? "Device 2"
        let userName1 = op1.metadata["userName"]
        let userName2 = op2.metadata["userName"]

        return DetailedConflict(
            fieldPath: conflict.fieldPath,
            fieldDisplayName: conflict.fieldDisplayName,
            localValue: op1.newValue,
            remoteValue: op2.newValue,
            localDeviceName: device1Name,
            remoteDeviceName: device2Name,
            localUserName: userName1,
            remoteUserName: userName2,
            localTimestamp: op1.timestamp,
            remoteTimestamp: op2.timestamp,
            operation1: op1,
            operation2: op2
        )
    }

    // MARK: - Operation Application

    /// Apply all operations in the log to the recipe object
    private func applyOperationsToRecipe(_ crdt: RecipeCRDT) {
        print("📝 [CRDT] Applying \(crdt.operationLog.operations.count) operations to recipe")

        let recipe = crdt.recipe

        // Sort operations by timestamp (chronological order)
        let sortedOps = crdt.operationLog.operations.sorted { $0.timestamp < $1.timestamp }

        for operation in sortedOps {
            applyOperation(operation, to: recipe)
        }

        // Update recipe metadata
        recipe.modifiedAt = Date()
        recipe.lastModifiedByDevice = crdt.deviceId
    }

    /// Apply a single operation to a recipe
    private func applyOperation(_ operation: RecipeOperation, to recipe: Recipe) {
        switch operation.operationType {
        case .update:
            applyUpdate(operation, to: recipe)
        case .addIngredient:
            applyAddIngredient(operation, to: recipe)
        case .addInstruction:
            applyAddInstruction(operation, to: recipe)
        case .delete:
            applyDelete(operation, to: recipe)
        case .create:
            // Create operations don't modify the recipe, just mark creation
            break
        }
    }

    private func applyUpdate(_ operation: RecipeOperation, to recipe: Recipe) {
        guard let newValue = operation.newValue else { return }

        switch operation.fieldPath {
        case "title":
            if let value = newValue.stringValue {
                recipe.title = value
            }
        case "notes":
            if let value = newValue.stringValue {
                recipe.notes = value
            } else if case .null = newValue {
                recipe.notes = nil
            }
        case "prepTime":
            if let value = newValue.stringValue {
                recipe.prepTime = value
            } else if case .null = newValue {
                recipe.prepTime = nil
            }
        case "cookTime":
            if let value = newValue.stringValue {
                recipe.cookTime = value
            } else if case .null = newValue {
                recipe.cookTime = nil
            }
        case "servings":
            if let value = newValue.stringValue {
                recipe.servings = value
            } else if case .null = newValue {
                recipe.servings = nil
            }
        default:
            print("⚠️ [CRDT] Unknown field path for update: \(operation.fieldPath)")
        }
    }

    private func applyAddIngredient(_ operation: RecipeOperation, to recipe: Recipe) {
        guard let ingredientText = operation.newValue?.stringValue else { return }

        // Parse ingredient and create Ingredient object
        let parsed = IngredientParser.parse(ingredientText)

        let ingredient = Ingredient(
            originalText: ingredientText,
            name: parsed.name,
            quantity: parsed.quantity,
            unit: parsed.unit,
            orderIndex: recipe.ingredients?.count ?? 0
        )
        ingredient.recipe = recipe

        if recipe.ingredients == nil {
            recipe.ingredients = []
        }
        recipe.ingredients?.append(ingredient)
    }

    private func applyAddInstruction(_ operation: RecipeOperation, to recipe: Recipe) {
        guard let instructionText = operation.newValue?.stringValue else { return }

        recipe.instructions.append(instructionText)
    }

    private func applyDelete(_ operation: RecipeOperation, to recipe: Recipe) {
        // Handle deletion based on field path
        if operation.fieldPath.starts(with: "ingredients[") {
            // Extract index from field path
            if let indexString = operation.fieldPath.split(separator: "[").last?.split(separator: "]").first,
               let index = Int(indexString),
               let ingredients = recipe.ingredients,
               index < ingredients.count {
                recipe.ingredients?.remove(at: index)
            }
        } else if operation.fieldPath.starts(with: "instructions[") {
            if let indexString = operation.fieldPath.split(separator: "[").last?.split(separator: "]").first,
               let index = Int(indexString),
               index < recipe.instructions.count {
                recipe.instructions.remove(at: index)
            }
        }
    }

    // MARK: - User Conflict Resolution

    /// Apply user's conflict resolution choices
    func applyUserResolution(
        _ resolutions: [ConflictResolution],
        to crdt: RecipeCRDT
    ) {
        print("👤 [CRDT] Applying user conflict resolutions: \(resolutions.count)")

        for resolution in resolutions {
            switch resolution.choice {
            case .keepLocal:
                // Remove remote operation from log
                crdt.operationLog.operations.removeAll { $0.id == resolution.remoteOperationId }
            case .keepRemote:
                // Remove local operation from log
                crdt.operationLog.operations.removeAll { $0.id == resolution.localOperationId }
            case .keepBoth:
                // Keep both operations (for additive changes)
                break
            case .custom(let value):
                // Create new operation with custom value
                let newOp = RecipeOperation(
                    recipeId: crdt.recipe.id,
                    deviceId: crdt.deviceId,
                    vectorClock: crdt.operationLog.vectorClock,
                    timestamp: Date(),
                    operationType: .update,
                    fieldPath: resolution.fieldPath,
                    oldValue: nil,
                    newValue: value,
                    metadata: crdt.currentDeviceMetadata()
                )
                crdt.operationLog.append(newOp)
            }
        }

        // Apply all operations after resolution
        applyOperationsToRecipe(crdt)

        // Clear conflict flag
        crdt.recipe.hasPendingConflicts = false
        crdt.recipe.showConflictBadge = false
    }
}

// MARK: - Merge Result Types

enum MergeOperationResult {
    case alreadyInSync
    case autoMerged(result: RecipeCRDT, resolvedConflicts: Int = 0)
    case needsUserResolution(conflicts: [DetailedConflict], partialCRDT: RecipeCRDT, autoResolvedCount: Int)

    var requiresUI: Bool {
        if case .needsUserResolution = self {
            return true
        }
        return false
    }

    var isAlreadyInSync: Bool {
        if case .alreadyInSync = self {
            return true
        }
        return false
    }

    var isAutoMerged: Bool {
        if case .autoMerged = self {
            return true
        }
        return false
    }
}

// MARK: - Detailed Conflict (for UI)

struct DetailedConflict {
    let fieldPath: String
    let fieldDisplayName: String
    let localValue: OperationValue?
    let remoteValue: OperationValue?
    let localDeviceName: String
    let remoteDeviceName: String
    let localUserName: String?
    let remoteUserName: String?
    let localTimestamp: Date
    let remoteTimestamp: Date
    let operation1: RecipeOperation
    let operation2: RecipeOperation
}

// MARK: - Conflict Resolution (user choice)

struct ConflictResolution {
    let fieldPath: String
    let localOperationId: UUID
    let remoteOperationId: UUID
    let choice: ResolutionChoice

    enum ResolutionChoice {
        case keepLocal
        case keepRemote
        case keepBoth  // For additive changes
        case custom(OperationValue)  // User typed custom value
    }
}
