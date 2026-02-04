//
//  RecipeLineageTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-03
//  Unit tests for recipe lineage tracking
//
//  Tests the lineage system to ensure:
//  - Generation tracking across shares
//  - Modification records are captured
//  - Contributor attribution is preserved
//  - Lineage relationships are correct
//

import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class RecipeLineageTests: XCTestCase {

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

    // MARK: - Root Lineage Tests

    /// Test 1: Root lineage has generation zero
    func test_rootLineage_hasGenerationZero() throws {
        // GIVEN: Root recipe
        let recipeId = UUID()
        let ownerId = "user123"

        // WHEN: Creating root lineage
        let lineage = RecipeLineage(
            rootRecipeId: recipeId,
            currentRecipeId: recipeId,
            ownerId: ownerId,
            rootOwnerId: ownerId,
            generation: 0
        )

        // THEN: Should be generation 0
        XCTAssertEqual(lineage.generation, 0)
        XCTAssertTrue(lineage.isRoot)
    }

    /// Test 2: Root lineage has same root and current recipe
    func test_rootLineage_rootEqualsCurrentRecipe() throws {
        // GIVEN: Root recipe
        let recipeId = UUID()

        // WHEN: Creating root lineage
        let lineage = RecipeLineage(
            rootRecipeId: recipeId,
            currentRecipeId: recipeId,
            ownerId: "owner",
            rootOwnerId: "owner",
            generation: 0
        )

        // THEN: Root and current should be same
        XCTAssertEqual(lineage.rootRecipeId, lineage.currentRecipeId)
        XCTAssertNil(lineage.parentRecipeId)
    }

    /// Test 3: Root lineage has no parent
    func test_rootLineage_hasNoParent() throws {
        // GIVEN: Root lineage
        let lineage = RecipeLineage(
            rootRecipeId: UUID(),
            currentRecipeId: UUID(),
            ownerId: "owner",
            rootOwnerId: "owner",
            generation: 0
        )

        // THEN: Should have no parent
        XCTAssertNil(lineage.parentRecipeId)
    }

    // MARK: - Descendant Lineage Tests

    /// Test 4: First share has generation 1
    func test_firstShare_hasGenerationOne() throws {
        // GIVEN: Original recipe shared once
        let rootId = UUID()
        let currentId = UUID()

        // WHEN: Creating first-generation lineage
        let lineage = RecipeLineage(
            rootRecipeId: rootId,
            parentRecipeId: rootId,
            currentRecipeId: currentId,
            ownerId: "receiver",
            rootOwnerId: "original",
            generation: 1,
            sharedByName: "Original Owner"
        )

        // THEN: Should be generation 1
        XCTAssertEqual(lineage.generation, 1)
        XCTAssertFalse(lineage.isRoot)
    }

    /// Test 5: Second share has generation 2
    func test_secondShare_hasGenerationTwo() throws {
        // GIVEN: Recipe shared twice
        let rootId = UUID()
        let parentId = UUID()
        let currentId = UUID()

        // WHEN: Creating second-generation lineage
        let lineage = RecipeLineage(
            rootRecipeId: rootId,
            parentRecipeId: parentId,
            currentRecipeId: currentId,
            ownerId: "third_owner",
            rootOwnerId: "original",
            generation: 2,
            sharedByName: "Second Owner"
        )

        // THEN: Should be generation 2
        XCTAssertEqual(lineage.generation, 2)
        XCTAssertNotNil(lineage.parentRecipeId)
    }

    /// Test 6: Descendant lineage has parent reference
    func test_descendantLineage_hasParentReference() throws {
        // GIVEN: Shared recipe
        let rootId = UUID()
        let parentId = UUID()
        let currentId = UUID()

        // WHEN: Creating descendant lineage
        let lineage = RecipeLineage(
            rootRecipeId: rootId,
            parentRecipeId: parentId,
            currentRecipeId: currentId,
            ownerId: "receiver",
            rootOwnerId: "original",
            generation: 1
        )

        // THEN: Parent should be set
        XCTAssertEqual(lineage.parentRecipeId, parentId)
    }

    // MARK: - Generation Label Tests

    /// Test 7: Generation 0 label is "Original"
    func test_generationLabel_zero_isOriginal() throws {
        let lineage = RecipeLineage(
            rootRecipeId: UUID(),
            currentRecipeId: UUID(),
            ownerId: "owner",
            rootOwnerId: "owner",
            generation: 0
        )

        XCTAssertEqual(lineage.generationLabel, "Original")
    }

    /// Test 8: Generation 1 label is "1st Generation"
    func test_generationLabel_one_isFirstGeneration() throws {
        let lineage = RecipeLineage(
            rootRecipeId: UUID(),
            currentRecipeId: UUID(),
            ownerId: "owner",
            rootOwnerId: "root",
            generation: 1
        )

        XCTAssertEqual(lineage.generationLabel, "1st Generation")
    }

    /// Test 9: Generation 2 label is "2nd Generation"
    func test_generationLabel_two_isSecondGeneration() throws {
        let lineage = RecipeLineage(
            rootRecipeId: UUID(),
            currentRecipeId: UUID(),
            ownerId: "owner",
            rootOwnerId: "root",
            generation: 2
        )

        XCTAssertEqual(lineage.generationLabel, "2nd Generation")
    }

    /// Test 10: Generation 3 label is "3rd Generation"
    func test_generationLabel_three_isThirdGeneration() throws {
        let lineage = RecipeLineage(
            rootRecipeId: UUID(),
            currentRecipeId: UUID(),
            ownerId: "owner",
            rootOwnerId: "root",
            generation: 3
        )

        XCTAssertEqual(lineage.generationLabel, "3rd Generation")
    }

    /// Test 11: Generation 4+ uses "th" suffix
    func test_generationLabel_fourPlus_usesThSuffix() throws {
        let lineage = RecipeLineage(
            rootRecipeId: UUID(),
            currentRecipeId: UUID(),
            ownerId: "owner",
            rootOwnerId: "root",
            generation: 4
        )

        XCTAssertEqual(lineage.generationLabel, "4th Generation")
    }

    // MARK: - Owner Tracking Tests

    /// Test 12: Lineage tracks current owner
    func test_lineage_tracksCurrentOwner() throws {
        let lineage = RecipeLineage(
            rootRecipeId: UUID(),
            currentRecipeId: UUID(),
            ownerId: "current_owner",
            rootOwnerId: "original_owner",
            generation: 1
        )

        XCTAssertEqual(lineage.ownerId, "current_owner")
    }

    /// Test 13: Lineage tracks root owner
    func test_lineage_tracksRootOwner() throws {
        let lineage = RecipeLineage(
            rootRecipeId: UUID(),
            currentRecipeId: UUID(),
            ownerId: "current_owner",
            rootOwnerId: "original_owner",
            generation: 1
        )

        XCTAssertEqual(lineage.rootOwnerId, "original_owner")
    }

    /// Test 14: Root lineage has same owner and root owner
    func test_rootLineage_ownerEqualsRootOwner() throws {
        let lineage = RecipeLineage(
            rootRecipeId: UUID(),
            currentRecipeId: UUID(),
            ownerId: "original",
            rootOwnerId: "original",
            generation: 0
        )

        XCTAssertEqual(lineage.ownerId, lineage.rootOwnerId)
    }

    // MARK: - Modification Record Tests

    /// Test 15: Modification count starts at zero
    func test_modificationCount_startsAtZero() {
        let lineage = RecipeLineage(
            rootRecipeId: UUID(),
            currentRecipeId: UUID(),
            ownerId: "owner",
            rootOwnerId: "owner",
            generation: 0
        )

        XCTAssertEqual(lineage.modificationCount, 0)
    }

    /// Test 16: Modification record stores change type
    func test_modificationRecord_storesChangeType() {
        let record = ModificationRecord(
            modifiedBy: "user123",
            modifiedByName: "Chef Bob",
            changeType: .ingredientAdded,
            changeDescription: "Added garlic",
            fieldChanged: "ingredients"
        )

        XCTAssertEqual(record.changeType, .ingredientAdded)
        XCTAssertEqual(record.changeDescription, "Added garlic")
    }

    /// Test 17: Modification record tracks modifier
    func test_modificationRecord_tracksModifier() {
        let record = ModificationRecord(
            modifiedBy: "user456",
            modifiedByName: "Home Cook",
            changeType: .titleChanged,
            changeDescription: "Updated recipe title",
            fieldChanged: "title"
        )

        XCTAssertEqual(record.modifiedBy, "user456")
        XCTAssertEqual(record.modifiedByName, "Home Cook")
    }

    // MARK: - Change Type Tests

    /// Test 18: All change types exist
    func test_changeTypes_allExist() {
        let types: [ModificationRecord.ChangeType] = [
            .created,
            .modified,
            .ingredientAdded,
            .ingredientRemoved,
            .ingredientModified,
            .instructionAdded,
            .instructionRemoved,
            .instructionModified,
            .imageChanged,
            .titleChanged,
            .notesChanged
        ]

        for type in types {
            XCTAssertFalse(type.rawValue.isEmpty)
        }
    }

    /// Test 19: Change type raw values are snake_case
    func test_changeType_hasSnakeCaseRawValues() {
        let ingredientChange = ModificationRecord.ChangeType.ingredientAdded
        let titleChange = ModificationRecord.ChangeType.titleChanged
        let instructionChange = ModificationRecord.ChangeType.instructionModified

        XCTAssertEqual(ingredientChange.rawValue, "ingredient_added")
        XCTAssertEqual(titleChange.rawValue, "title_changed")
        XCTAssertEqual(instructionChange.rawValue, "instruction_modified")
    }

    /// Test 20: Shared by name is stored
    func test_lineage_storesSharedByName() {
        let lineage = RecipeLineage(
            rootRecipeId: UUID(),
            currentRecipeId: UUID(),
            ownerId: "receiver",
            rootOwnerId: "original",
            generation: 1,
            sharedByName: "Mom's Kitchen"
        )

        XCTAssertEqual(lineage.sharedByName, "Mom's Kitchen")
    }
}

// Note: Uses production RecipeLineage, ModificationRecord, and ModificationRecord.ChangeType from Heirloom module
