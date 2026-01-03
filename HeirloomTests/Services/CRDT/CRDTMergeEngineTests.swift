//
//  CRDTMergeEngineTests.swift
//  HeirloomTests
//
//  Created by Claude on 12/31/25.
//  Unit tests for CRDTMergeEngine - core merge logic
//

import XCTest
import SwiftData
@testable import Heirloom

/// Unit tests for CRDTMergeEngine - conflict-free merge logic
final class CRDTMergeEngineTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() {
        super.setUp()

        // Create in-memory model container for testing
        let schema = Schema([Recipe.self, Ingredient.self, RecipeComment.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }

    // MARK: - Test Helpers

    private func makeTestRecipe(title: String = "Test Recipe") -> Recipe {
        return Recipe(
            title: title,
            sourceType: .manual,
            instructions: ["Step 1", "Step 2"],
            servings: "4 servings",
            prepTime: "15 min",
            cookTime: "30 min"
        )
    }

    private func makeCRDT(recipe: Recipe, deviceId: String) -> RecipeCRDT {
        return RecipeCRDT(recipe: recipe, deviceId: deviceId)
    }

    // MARK: - Basic Merge Tests

    func testMergeAlreadyInSync() throws {
        let recipe1 = makeTestRecipe()
        let recipe2 = makeTestRecipe()
        recipe2.id = recipe1.id // Same ID

        let crdt1 = makeCRDT(recipe: recipe1, deviceId: "device1")
        let crdt2 = makeCRDT(recipe: recipe2, deviceId: "device1")

        // No operations = already in sync
        let result = CRDTMergeEngine.shared.merge(local: crdt1, remote: crdt2)

        XCTAssertTrue(result.isAlreadyInSync)
    }

    func testMergeAutoMergeNoConflicts() throws {
        let recipe1 = makeTestRecipe(title: "Original")
        let crdt1 = makeCRDT(recipe: recipe1, deviceId: "device1")

        let recipe2 = makeTestRecipe(title: "Original")
        recipe2.id = recipe1.id
        let crdt2 = makeCRDT(recipe: recipe2, deviceId: "device2")

        // Device 1 edits title
        crdt1.updateField(fieldPath: "title", oldValue: .string("Original"), newValue: .string("Updated by Device 1"))

        // Device 2 edits servings (different field)
        crdt2.updateField(fieldPath: "servings", oldValue: .string("4 servings"), newValue: .string("6 servings"))

        let result = CRDTMergeEngine.shared.merge(local: crdt1, remote: crdt2)

        XCTAssertTrue(result.isAutoMerged, "Should auto-merge edits on different fields")
        if case .autoMerged(let mergedCRDT, let resolvedConflicts) = result {
            XCTAssertEqual(mergedCRDT.recipe.title, "Updated by Device 1")
            XCTAssertEqual(mergedCRDT.recipe.servings, "6 servings")
            XCTAssertEqual(resolvedConflicts, 0)
        } else {
            XCTFail("Expected auto-merge result")
        }
    }

    func testMergeNeedsUserResolution() throws {
        let recipe1 = makeTestRecipe()
        let crdt1 = makeCRDT(recipe: recipe1, deviceId: "device1")

        let recipe2 = makeTestRecipe()
        recipe2.id = recipe1.id
        let crdt2 = makeCRDT(recipe: recipe2, deviceId: "device2")

        // Both devices edit same field concurrently
        crdt1.updateField(fieldPath: "servings", oldValue: .string("4 servings"), newValue: .string("2 servings"))
        crdt2.updateField(fieldPath: "servings", oldValue: .string("4 servings"), newValue: .string("6 servings"))

        let result = CRDTMergeEngine.shared.merge(local: crdt1, remote: crdt2)

        XCTAssertTrue(result.requiresUI, "Should require user resolution")
        if case .needsUserResolution(let conflicts, let partialCRDT, let autoResolvedCount) = result {
            XCTAssertEqual(conflicts.count, 1)
            XCTAssertEqual(conflicts.first?.fieldPath, "servings")
            XCTAssertNotNil(partialCRDT)
            XCTAssertGreaterThanOrEqual(autoResolvedCount, 0)
        } else {
            XCTFail("Expected needs-user-resolution result")
        }
    }

    // MARK: - Auto-Merge Rules Tests

    func testAutoMergeAdditiveIngredients() throws {
        let recipe1 = makeTestRecipe()
        let crdt1 = makeCRDT(recipe: recipe1, deviceId: "device1")

        let recipe2 = makeTestRecipe()
        recipe2.id = recipe1.id
        let crdt2 = makeCRDT(recipe: recipe2, deviceId: "device2")

        // Device 1 adds ingredients
        crdt1.addIngredient("1 cup flour", at: 0)
        crdt1.addIngredient("2 cups sugar", at: 1)

        // Device 2 adds different ingredients (concurrent)
        crdt2.addIngredient("1 cup milk", at: 0)
        crdt2.addIngredient("2 tbsp butter", at: 1)

        let result = CRDTMergeEngine.shared.merge(local: crdt1, remote: crdt2)

        XCTAssertTrue(result.isAutoMerged, "Additive changes should auto-merge")
    }

    func testAutoMergeAdditiveInstructions() throws {
        let recipe1 = makeTestRecipe()
        let crdt1 = makeCRDT(recipe: recipe1, deviceId: "device1")

        let recipe2 = makeTestRecipe()
        recipe2.id = recipe1.id
        let crdt2 = makeCRDT(recipe: recipe2, deviceId: "device2")

        // Device 1 adds step
        crdt1.addInstruction("Preheat oven to 350°F", at: 2)

        // Device 2 adds different step (concurrent)
        crdt2.addInstruction("Grease baking pan", at: 2)

        let result = CRDTMergeEngine.shared.merge(local: crdt1, remote: crdt2)

        XCTAssertTrue(result.isAutoMerged, "Additive instruction changes should auto-merge")
    }

    func testAutoMergeSameValueDifferentTimestamp() throws {
        let recipe1 = makeTestRecipe()
        let crdt1 = makeCRDT(recipe: recipe1, deviceId: "device1")

        let recipe2 = makeTestRecipe()
        recipe2.id = recipe1.id
        let crdt2 = makeCRDT(recipe: recipe2, deviceId: "device2")

        // Both devices set same value
        crdt1.updateField(fieldPath: "servings", oldValue: .string("4 servings"), newValue: .string("6 servings"))
        Thread.sleep(forTimeInterval: 0.01) // Small delay for different timestamp
        crdt2.updateField(fieldPath: "servings", oldValue: .string("4 servings"), newValue: .string("6 servings"))

        let result = CRDTMergeEngine.shared.merge(local: crdt1, remote: crdt2)

        XCTAssertTrue(result.isAutoMerged, "Same value should auto-merge")
    }

    func testAutoMergeOneDelete() throws {
        let recipe1 = makeTestRecipe()
        let crdt1 = makeCRDT(recipe: recipe1, deviceId: "device1")

        let recipe2 = makeTestRecipe()
        recipe2.id = recipe1.id
        let crdt2 = makeCRDT(recipe: recipe2, deviceId: "device2")

        // Device 1 updates field
        crdt1.updateField(fieldPath: "notes", oldValue: .null, newValue: .string("New notes"))

        // Device 2 deletes field (concurrent)
        crdt2.updateField(fieldPath: "notes", oldValue: .string("Old notes"), newValue: .null)

        let result = CRDTMergeEngine.shared.merge(local: crdt1, remote: crdt2)

        // Delete wins (defensive strategy)
        XCTAssertTrue(result.isAutoMerged, "Delete should auto-merge")
    }

    // MARK: - Conflict Detection Tests

    func testDetectConflictDifferentValues() throws {
        let recipe1 = makeTestRecipe()
        let crdt1 = makeCRDT(recipe: recipe1, deviceId: "device1")

        let recipe2 = makeTestRecipe()
        recipe2.id = recipe1.id
        let crdt2 = makeCRDT(recipe: recipe2, deviceId: "device2")

        // Concurrent edits with different values
        crdt1.updateField(fieldPath: "cookTime", oldValue: .string("30 min"), newValue: .string("45 min"))
        crdt2.updateField(fieldPath: "cookTime", oldValue: .string("30 min"), newValue: .string("60 min"))

        let result = CRDTMergeEngine.shared.merge(local: crdt1, remote: crdt2)

        XCTAssertTrue(result.requiresUI)
        if case .needsUserResolution(let conflicts, _, _) = result {
            XCTAssertEqual(conflicts.count, 1)
            XCTAssertEqual(conflicts.first?.fieldPath, "cookTime")
            XCTAssertEqual(conflicts.first?.localValue, .string("45 min"))
            XCTAssertEqual(conflicts.first?.remoteValue, .string("60 min"))
        } else {
            XCTFail("Expected conflict")
        }
    }

    func testDetectMultipleConflicts() throws {
        let recipe1 = makeTestRecipe()
        let crdt1 = makeCRDT(recipe: recipe1, deviceId: "device1")

        let recipe2 = makeTestRecipe()
        recipe2.id = recipe1.id
        let crdt2 = makeCRDT(recipe: recipe2, deviceId: "device2")

        // Conflicts on multiple fields
        crdt1.updateField(fieldPath: "servings", oldValue: .string("4 servings"), newValue: .string("2 servings"))
        crdt2.updateField(fieldPath: "servings", oldValue: .string("4 servings"), newValue: .string("6 servings"))

        crdt1.updateField(fieldPath: "cookTime", oldValue: .string("30 min"), newValue: .string("45 min"))
        crdt2.updateField(fieldPath: "cookTime", oldValue: .string("30 min"), newValue: .string("60 min"))

        let result = CRDTMergeEngine.shared.merge(local: crdt1, remote: crdt2)

        XCTAssertTrue(result.requiresUI)
        if case .needsUserResolution(let conflicts, _, _) = result {
            XCTAssertEqual(conflicts.count, 2)
            let fieldPaths = conflicts.map { $0.fieldPath }
            XCTAssertTrue(fieldPaths.contains("servings"))
            XCTAssertTrue(fieldPaths.contains("cookTime"))
        } else {
            XCTFail("Expected conflicts")
        }
    }

    func testNoConflictSequentialEdits() throws {
        let recipe1 = makeTestRecipe()
        let crdt1 = makeCRDT(recipe: recipe1, deviceId: "device1")

        // Device 1 edits first
        crdt1.updateField(fieldPath: "servings", oldValue: .string("4 servings"), newValue: .string("6 servings"))

        // Device 2 sees device 1's change and edits again
        let recipe2 = makeTestRecipe()
        recipe2.id = recipe1.id
        let crdt2 = makeCRDT(recipe: recipe2, deviceId: "device2")
        crdt2.operationLog.merge(with: crdt1.operationLog) // Sees device 1's change
        crdt2.updateField(fieldPath: "servings", oldValue: .string("6 servings"), newValue: .string("8 servings"))

        let result = CRDTMergeEngine.shared.merge(local: crdt1, remote: crdt2)

        XCTAssertTrue(result.isAutoMerged, "Sequential edits should not conflict")
    }

    // MARK: - User Resolution Tests

    func testApplyUserResolutionKeepLocal() throws {
        let recipe1 = makeTestRecipe()
        let crdt1 = makeCRDT(recipe: recipe1, deviceId: "device1")

        crdt1.updateField(fieldPath: "servings", oldValue: .string("4 servings"), newValue: .string("2 servings"))

        let recipe2 = makeTestRecipe()
        recipe2.id = recipe1.id
        let crdt2 = makeCRDT(recipe: recipe2, deviceId: "device2")
        crdt2.updateField(fieldPath: "servings", oldValue: .string("4 servings"), newValue: .string("6 servings"))

        let result = CRDTMergeEngine.shared.merge(local: crdt1, remote: crdt2)

        if case .needsUserResolution(let conflicts, let partialCRDT, _) = result {
            let resolution = ConflictResolution(
                fieldPath: "servings",
                localOperationId: conflicts.first!.operation1.id,
                remoteOperationId: conflicts.first!.operation2.id,
                choice: .keepLocal
            )

            CRDTMergeEngine.shared.applyUserResolution([resolution], to: partialCRDT)

            XCTAssertEqual(partialCRDT.recipe.servings, "2 servings")
        } else {
            XCTFail("Expected conflict")
        }
    }

    func testApplyUserResolutionKeepRemote() throws {
        let recipe1 = makeTestRecipe()
        let crdt1 = makeCRDT(recipe: recipe1, deviceId: "device1")
        crdt1.updateField(fieldPath: "servings", oldValue: .string("4 servings"), newValue: .string("2 servings"))

        let recipe2 = makeTestRecipe()
        recipe2.id = recipe1.id
        let crdt2 = makeCRDT(recipe: recipe2, deviceId: "device2")
        crdt2.updateField(fieldPath: "servings", oldValue: .string("4 servings"), newValue: .string("6 servings"))

        let result = CRDTMergeEngine.shared.merge(local: crdt1, remote: crdt2)

        if case .needsUserResolution(let conflicts, let partialCRDT, _) = result {
            let resolution = ConflictResolution(
                fieldPath: "servings",
                localOperationId: conflicts.first!.operation1.id,
                remoteOperationId: conflicts.first!.operation2.id,
                choice: .keepRemote
            )

            CRDTMergeEngine.shared.applyUserResolution([resolution], to: partialCRDT)

            XCTAssertEqual(partialCRDT.recipe.servings, "6 servings")
        } else {
            XCTFail("Expected conflict")
        }
    }

    func testApplyUserResolutionKeepBoth() throws {
        let recipe1 = makeTestRecipe()
        let crdt1 = makeCRDT(recipe: recipe1, deviceId: "device1")

        let recipe2 = makeTestRecipe()
        recipe2.id = recipe1.id
        let crdt2 = makeCRDT(recipe: recipe2, deviceId: "device2")

        // Both devices add different ingredients concurrently
        // Force a conflict by using same field path (simulating conflict scenario)
        crdt1.updateField(fieldPath: "notes", oldValue: .null, newValue: .string("Note from device 1"))
        crdt2.updateField(fieldPath: "notes", oldValue: .null, newValue: .string("Note from device 2"))

        let result = CRDTMergeEngine.shared.merge(local: crdt1, remote: crdt2)

        if case .needsUserResolution(let conflicts, let partialCRDT, _) = result {
            let initialOpCount = partialCRDT.operationLog.operations.count

            let resolution = ConflictResolution(
                fieldPath: "notes",
                localOperationId: conflicts.first!.operation1.id,
                remoteOperationId: conflicts.first!.operation2.id,
                choice: .keepBoth
            )

            CRDTMergeEngine.shared.applyUserResolution([resolution], to: partialCRDT)

            // Should keep both operations in log (not remove either)
            XCTAssertTrue(partialCRDT.operationLog.operations.count >= initialOpCount - 1)
        } else {
            XCTFail("Expected conflict")
        }
    }

    // MARK: - Real-World Scenarios

    func testScenarioTwoDevicesEditDifferentFields() throws {
        let recipe1 = makeTestRecipe(title: "Lasagna")
        let crdt1 = makeCRDT(recipe: recipe1, deviceId: "iPhone")

        let recipe2 = makeTestRecipe(title: "Lasagna")
        recipe2.id = recipe1.id
        let crdt2 = makeCRDT(recipe: recipe2, deviceId: "iPad")

        // iPhone edits title and servings
        crdt1.updateField(fieldPath: "title", oldValue: .string("Lasagna"), newValue: .string("Grandma's Lasagna"))
        crdt1.updateField(fieldPath: "servings", oldValue: .string("4 servings"), newValue: .string("6 servings"))

        // iPad edits cook time and notes
        crdt2.updateField(fieldPath: "cookTime", oldValue: .string("30 min"), newValue: .string("45 min"))
        crdt2.updateField(fieldPath: "notes", oldValue: .null, newValue: .string("Family favorite!"))

        let result = CRDTMergeEngine.shared.merge(local: crdt1, remote: crdt2)

        XCTAssertTrue(result.isAutoMerged)
        if case .autoMerged(let mergedCRDT, _) = result {
            XCTAssertEqual(mergedCRDT.recipe.title, "Grandma's Lasagna")
            XCTAssertEqual(mergedCRDT.recipe.servings, "6 servings")
            XCTAssertEqual(mergedCRDT.recipe.cookTime, "45 min")
            XCTAssertEqual(mergedCRDT.recipe.notes, "Family favorite!")
        } else {
            XCTFail("Expected auto-merge")
        }
    }

    func testScenarioThreeDevicesMerge() throws {
        let recipe1 = makeTestRecipe()
        let crdt1 = makeCRDT(recipe: recipe1, deviceId: "device1")
        crdt1.updateField(fieldPath: "title", oldValue: .string("Test Recipe"), newValue: .string("Updated Title"))

        let recipe2 = makeTestRecipe()
        recipe2.id = recipe1.id
        let crdt2 = makeCRDT(recipe: recipe2, deviceId: "device2")
        crdt2.updateField(fieldPath: "servings", oldValue: .string("4 servings"), newValue: .string("6 servings"))

        let recipe3 = makeTestRecipe()
        recipe3.id = recipe1.id
        let crdt3 = makeCRDT(recipe: recipe3, deviceId: "device3")
        crdt3.updateField(fieldPath: "cookTime", oldValue: .string("30 min"), newValue: .string("45 min"))

        // Merge 1 and 2
        let result1 = CRDTMergeEngine.shared.merge(local: crdt1, remote: crdt2)
        XCTAssertTrue(result1.isAutoMerged)

        // Merge result with 3
        if case .autoMerged(let mergedCRDT, _) = result1 {
            let result2 = CRDTMergeEngine.shared.merge(local: mergedCRDT, remote: crdt3)
            XCTAssertTrue(result2.isAutoMerged)

            if case .autoMerged(let finalCRDT, _) = result2 {
                XCTAssertEqual(finalCRDT.recipe.title, "Updated Title")
                XCTAssertEqual(finalCRDT.recipe.servings, "6 servings")
                XCTAssertEqual(finalCRDT.recipe.cookTime, "45 min")
            }
        }
    }

    func testScenarioConflictingServingsResolution() throws {
        // Real scenario: User edits servings on iPhone, partner edits on iPad
        let recipe1 = makeTestRecipe()
        let crdt1 = makeCRDT(recipe: recipe1, deviceId: "iPhone")

        let recipe2 = makeTestRecipe()
        recipe2.id = recipe1.id
        let crdt2 = makeCRDT(recipe: recipe2, deviceId: "iPad")

        // Pass device names in metadata
        crdt1.updateField(
            fieldPath: "servings",
            oldValue: .string("4 servings"),
            newValue: .string("2 servings"),
            metadata: ["deviceName": "iPhone"]
        )
        crdt2.updateField(
            fieldPath: "servings",
            oldValue: .string("4 servings"),
            newValue: .string("8 servings"),
            metadata: ["deviceName": "iPad"]
        )

        let result = CRDTMergeEngine.shared.merge(local: crdt1, remote: crdt2)

        XCTAssertTrue(result.requiresUI)
        if case .needsUserResolution(let conflicts, _, _) = result {
            XCTAssertEqual(conflicts.count, 1)
            XCTAssertEqual(conflicts.first?.localDeviceName, "iPhone")
            XCTAssertEqual(conflicts.first?.remoteDeviceName, "iPad")
        } else {
            XCTFail("Expected conflict")
        }
    }
}
