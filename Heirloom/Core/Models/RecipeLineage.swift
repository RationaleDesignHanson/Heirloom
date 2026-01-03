//
//  RecipeLineage.swift
//  Heirloom
//
//  Created during Firebase Migration - Heirloom Sharing System
//  Tracks family tree and modification history for heirloom recipes
//

import Foundation
import SwiftData

/// Tracks the lineage and modification history of heirloom recipes
/// Enables multi-generational tracking (A→B→C) where original creator can see all descendant modifications
@Model
final class RecipeLineage {

    // MARK: - Identity

    /// Unique identifier for this lineage record
    @Attribute(.unique) var id: UUID

    /// Firebase document ID for syncing
    var firebaseId: String?

    // MARK: - Family Tree

    /// The original recipe in the family tree (generation 0)
    var rootRecipeId: UUID

    /// The immediate predecessor recipe (who shared it with you)
    var parentRecipeId: UUID?

    /// The current recipe ID (local copy)
    var currentRecipeId: UUID

    /// Firebase UID of the current owner
    var ownerId: String

    /// Firebase UID of the root creator
    var rootOwnerId: String

    /// Generation level (0 = root, 1 = first share, 2 = second share, etc.)
    var generation: Int

    // MARK: - Timestamps

    /// When this lineage record was created
    var createdAt: Date

    /// When the recipe was last modified
    var lastModified: Date

    /// When this lineage record was last synced to Firebase
    var lastSynced: Date?

    // MARK: - Modifications

    /// Array of modification records tracking changes to this recipe
    var modifications: [ModificationRecord]?

    // MARK: - Metadata

    /// Whether this is a heirloom share (vs generic)
    var isHeirloom: Bool

    /// Whether this recipe has been modified since receiving it
    var hasLocalModifications: Bool

    /// Display name of the person who shared this recipe
    var sharedByName: String?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        firebaseId: String? = nil,
        rootRecipeId: UUID,
        parentRecipeId: UUID? = nil,
        currentRecipeId: UUID,
        ownerId: String,
        rootOwnerId: String,
        generation: Int,
        createdAt: Date = Date(),
        lastModified: Date = Date(),
        lastSynced: Date? = nil,
        modifications: [ModificationRecord]? = nil,
        isHeirloom: Bool = true,
        hasLocalModifications: Bool = false,
        sharedByName: String? = nil
    ) {
        self.id = id
        self.firebaseId = firebaseId
        self.rootRecipeId = rootRecipeId
        self.parentRecipeId = parentRecipeId
        self.currentRecipeId = currentRecipeId
        self.ownerId = ownerId
        self.rootOwnerId = rootOwnerId
        self.generation = generation
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.lastSynced = lastSynced
        self.modifications = modifications
        self.isHeirloom = isHeirloom
        self.hasLocalModifications = hasLocalModifications
        self.sharedByName = sharedByName
    }
}

// MARK: - Modification Record

/// Records a single modification to a recipe
struct ModificationRecord: Codable, Hashable, Identifiable {
    let id: UUID
    let timestamp: Date
    let modifiedBy: String // Firebase UID
    let modifiedByName: String? // Display name
    let changeType: ChangeType
    let changeDescription: String
    let fieldChanged: String? // e.g., "title", "ingredients", "instructions"

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        modifiedBy: String,
        modifiedByName: String? = nil,
        changeType: ChangeType,
        changeDescription: String,
        fieldChanged: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.modifiedBy = modifiedBy
        self.modifiedByName = modifiedByName
        self.changeType = changeType
        self.changeDescription = changeDescription
        self.fieldChanged = fieldChanged
    }

    enum ChangeType: String, Codable {
        case created = "created"
        case modified = "modified"
        case ingredientAdded = "ingredient_added"
        case ingredientRemoved = "ingredient_removed"
        case ingredientModified = "ingredient_modified"
        case instructionAdded = "instruction_added"
        case instructionRemoved = "instruction_removed"
        case instructionModified = "instruction_modified"
        case imageChanged = "image_changed"
        case titleChanged = "title_changed"
        case notesChanged = "notes_changed"
    }
}

// MARK: - Computed Properties

extension RecipeLineage {
    /// Human-readable generation label
    var generationLabel: String {
        switch generation {
        case 0: return "Original"
        case 1: return "1st Generation"
        case 2: return "2nd Generation"
        case 3: return "3rd Generation"
        default: return "\(generation)th Generation"
        }
    }

    /// Whether this is the root recipe
    var isRoot: Bool {
        generation == 0
    }

    /// Total number of modifications
    var modificationCount: Int {
        modifications?.count ?? 0
    }

    /// Most recent modification
    var latestModification: ModificationRecord? {
        modifications?.sorted(by: { $0.timestamp > $1.timestamp }).first
    }
}

// MARK: - Helper Methods

extension RecipeLineage {
    /// Add a modification record
    func addModification(_ modification: ModificationRecord) {
        if modifications == nil {
            modifications = []
        }
        modifications?.append(modification)
        lastModified = modification.timestamp
        hasLocalModifications = true
    }

    /// Get all modifications sorted by timestamp
    func sortedModifications() -> [ModificationRecord] {
        modifications?.sorted(by: { $0.timestamp > $1.timestamp }) ?? []
    }

    /// Get modifications by a specific user
    func modifications(by userId: String) -> [ModificationRecord] {
        modifications?.filter { $0.modifiedBy == userId } ?? []
    }
}

// MARK: - Factory Methods

extension RecipeLineage {
    /// Create a root lineage record (generation 0)
    static func createRoot(
        recipeId: UUID,
        ownerId: String
    ) -> RecipeLineage {
        RecipeLineage(
            rootRecipeId: recipeId,
            parentRecipeId: nil,
            currentRecipeId: recipeId,
            ownerId: ownerId,
            rootOwnerId: ownerId,
            generation: 0,
            isHeirloom: true
        )
    }

    /// Create a descendant lineage record (generation > 0)
    static func createDescendant(
        rootRecipeId: UUID,
        parentRecipeId: UUID,
        currentRecipeId: UUID,
        ownerId: String,
        rootOwnerId: String,
        generation: Int,
        sharedByName: String?
    ) -> RecipeLineage {
        RecipeLineage(
            rootRecipeId: rootRecipeId,
            parentRecipeId: parentRecipeId,
            currentRecipeId: currentRecipeId,
            ownerId: ownerId,
            rootOwnerId: rootOwnerId,
            generation: generation,
            isHeirloom: true,
            sharedByName: sharedByName
        )
    }
}
