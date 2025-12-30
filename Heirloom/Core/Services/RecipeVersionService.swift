import Foundation
import SwiftData
import CloudKit

/// Service for managing recipe versions with change tracking and attribution
/// Follows the singleton pattern established in Heirloom services
@MainActor
final class RecipeVersionService {
    static let shared = RecipeVersionService()
    private init() {}

    // MARK: - Version Creation

    /// Create a new version for the current user
    /// - Parameters:
    ///   - recipe: The recipe to create a version for
    ///   - context: SwiftData model context
    /// - Returns: The newly created version
    /// - Throws: SwiftData save errors
    func createVersion(
        for recipe: Recipe,
        context: ModelContext
    ) throws -> RecipeVersion {
        let userID = getCurrentUserID()
        let displayName = getCurrentUserDisplayName()
        let year = String(Calendar.current.component(.year, from: Date()))

        let version = RecipeVersion(
            creatorUserID: userID,
            creatorDisplayName: displayName,
            creationYear: year,
            isBaseVersion: false
        )

        // Initialize with current recipe state
        version.title = recipe.title
        version.ingredients = recipe.ingredients?.map { $0.originalText } ?? []
        version.instructions = recipe.instructions
        version.servings = recipe.servings
        version.prepTime = recipe.prepTime
        version.cookTime = recipe.cookTime

        // Add version to recipe
        if recipe.versions == nil {
            recipe.versions = []
        }
        recipe.versions?.append(version)

        try context.save()
        return version
    }

    /// Create a base version from existing recipe data
    /// Used during migration or when enabling version tracking on existing recipe
    /// - Parameters:
    ///   - recipe: The recipe to create base version for
    ///   - context: SwiftData model context
    /// - Returns: The base version
    /// - Throws: SwiftData save errors
    func createBaseVersion(
        for recipe: Recipe,
        context: ModelContext
    ) throws -> RecipeVersion {
        // Check if base version already exists
        if recipe.baseVersion != nil {
            throw RecipeVersionError.baseVersionAlreadyExists
        }

        let baseVersion = RecipeVersion(
            creatorUserID: "original",
            creatorDisplayName: "Original",
            creationYear: String(Calendar.current.component(.year, from: recipe.dateAdded)),
            isBaseVersion: true
        )

        // Copy recipe content to base version
        baseVersion.title = recipe.title
        baseVersion.ingredients = recipe.ingredients?.map { $0.originalText } ?? []
        baseVersion.instructions = recipe.instructions
        baseVersion.servings = recipe.servings
        baseVersion.prepTime = recipe.prepTime
        baseVersion.cookTime = recipe.cookTime

        // Add to recipe
        if recipe.versions == nil {
            recipe.versions = []
        }
        recipe.versions?.append(baseVersion)

        // Set as selected version if none selected
        if recipe.selectedVersionID == nil {
            recipe.selectedVersionID = baseVersion.id
        }

        try context.save()
        return baseVersion
    }

    // MARK: - Version Selection

    /// Set which version to use when cooking/displaying
    /// - Parameters:
    ///   - version: The version to select
    ///   - recipe: The recipe containing the version
    ///   - context: SwiftData model context
    /// - Throws: SwiftData save errors or validation errors
    func selectVersion(
        _ version: RecipeVersion,
        for recipe: Recipe,
        context: ModelContext
    ) throws {
        // Validate version belongs to recipe
        guard recipe.versions?.contains(where: { $0.id == version.id }) == true else {
            throw RecipeVersionError.versionNotFoundInRecipe
        }

        recipe.selectedVersionID = version.id
        try context.save()
    }

    /// Get the version to display/cook (selected or base)
    /// - Parameter recipe: The recipe to get active version for
    /// - Returns: The active version, or nil if no versions exist
    func getActiveVersion(for recipe: Recipe) -> RecipeVersion? {
        return recipe.activeVersion
    }

    // MARK: - Change Tracking

    /// Record a field change in a specific version
    /// - Parameters:
    ///   - version: The version to record change in
    ///   - field: Field identifier (e.g., "ingredient-2", "title", "instruction-0")
    ///   - oldValue: Original value before change
    ///   - newValue: New value after change
    ///   - context: SwiftData model context
    /// - Throws: SwiftData save errors
    func recordChange(
        in version: RecipeVersion,
        field: String,
        from oldValue: String,
        to newValue: String,
        context: ModelContext
    ) throws {
        version.recordChange(field: field, from: oldValue, to: newValue)
        try context.save()
    }

    /// Update the content of a version and track changes
    /// - Parameters:
    ///   - version: The version to update
    ///   - updates: Dictionary of field updates
    ///   - context: SwiftData model context
    /// - Throws: SwiftData save errors
    func updateVersion(
        _ version: RecipeVersion,
        with updates: VersionUpdates,
        context: ModelContext
    ) throws {
        // Track changes before updating
        if let newTitle = updates.title, newTitle != version.title {
            let oldTitle = version.title ?? ""
            version.recordChange(field: "title", from: oldTitle, to: newTitle)
            version.title = newTitle
        }

        if let newIngredients = updates.ingredients {
            let oldIngredients = version.ingredients ?? []
            // Track changes for each ingredient that changed
            for (index, newValue) in newIngredients.enumerated() {
                let oldValue = oldIngredients.indices.contains(index) ? oldIngredients[index] : ""
                if oldValue != newValue {
                    version.recordChange(field: "ingredient-\(index)", from: oldValue, to: newValue)
                }
            }
            version.ingredients = newIngredients
        }

        if let newInstructions = updates.instructions {
            let oldInstructions = version.instructions ?? []
            // Track changes for each instruction that changed
            for (index, newValue) in newInstructions.enumerated() {
                let oldValue = oldInstructions.indices.contains(index) ? oldInstructions[index] : ""
                if oldValue != newValue {
                    version.recordChange(field: "instruction-\(index)", from: oldValue, to: newValue)
                }
            }
            version.instructions = newInstructions
        }

        if let newServings = updates.servings {
            version.servings = newServings
        }

        if let newPrepTime = updates.prepTime {
            version.prepTime = newPrepTime
        }

        if let newCookTime = updates.cookTime {
            version.cookTime = newCookTime
        }

        if let newNotes = updates.notes {
            version.notes = newNotes
        }

        version.lastModified = Date()
        try context.save()
    }

    // MARK: - Version Queries

    /// Get all versions for a recipe, sorted by creation date
    /// - Parameter recipe: The recipe to get versions for
    /// - Returns: Array of versions sorted oldest to newest
    func getVersions(for recipe: Recipe) -> [RecipeVersion] {
        return recipe.sortedVersions
    }

    /// Get a specific user's version
    /// - Parameters:
    ///   - recipe: The recipe to search
    ///   - userID: CloudKit user ID
    /// - Returns: The user's version, or nil if not found
    func getVersion(for recipe: Recipe, userID: String) -> RecipeVersion? {
        return recipe.versions?.first { $0.creatorUserID == userID }
    }

    /// Get all active contributor versions (excluding base)
    /// - Parameter recipe: The recipe to get contributor versions for
    /// - Returns: Array of active contributor versions
    func getContributorVersions(for recipe: Recipe) -> [RecipeVersion] {
        return recipe.contributorVersions
    }

    // MARK: - Version Management

    /// Deactivate a version (soft delete)
    /// - Parameters:
    ///   - version: The version to deactivate
    ///   - context: SwiftData model context
    /// - Throws: SwiftData save errors
    func deactivateVersion(
        _ version: RecipeVersion,
        context: ModelContext
    ) throws {
        guard !version.isBaseVersion else {
            throw RecipeVersionError.cannotDeactivateBaseVersion
        }

        version.isActive = false
        try context.save()
    }

    /// Reactivate a previously deactivated version
    /// - Parameters:
    ///   - version: The version to reactivate
    ///   - context: SwiftData model context
    /// - Throws: SwiftData save errors
    func reactivateVersion(
        _ version: RecipeVersion,
        context: ModelContext
    ) throws {
        version.isActive = true
        try context.save()
    }

    /// Delete a version permanently
    /// - Parameters:
    ///   - version: The version to delete
    ///   - recipe: The recipe containing the version
    ///   - context: SwiftData model context
    /// - Throws: SwiftData save errors or validation errors
    func deleteVersion(
        _ version: RecipeVersion,
        from recipe: Recipe,
        context: ModelContext
    ) throws {
        guard !version.isBaseVersion else {
            throw RecipeVersionError.cannotDeleteBaseVersion
        }

        // If this was the selected version, switch to base
        if recipe.selectedVersionID == version.id {
            recipe.selectedVersionID = recipe.baseVersion?.id
        }

        // Remove from versions array
        recipe.versions?.removeAll { $0.id == version.id }

        // Delete the version
        context.delete(version)

        try context.save()
    }

    // MARK: - Cooking Tracking

    /// Increment times cooked for a specific version
    /// - Parameters:
    ///   - version: The version that was cooked
    ///   - context: SwiftData model context
    /// - Throws: SwiftData save errors
    func markAsCooked(
        _ version: RecipeVersion,
        context: ModelContext
    ) throws {
        version.timesCooked += 1
        version.lastCooked = Date()
        try context.save()
    }

    // MARK: - User Info (CloudKit Integration)

    /// Get current CloudKit user ID
    /// - Returns: User record name or placeholder
    private func getCurrentUserID() -> String {
        // TODO: Fetch from CloudKit CKCurrentUserDefaultName
        // For now, return placeholder that can be replaced
        return "user-\(UUID().uuidString)"
    }

    /// Get current user's display name
    /// - Returns: User display name or "Current User"
    private func getCurrentUserDisplayName() -> String {
        // TODO: Fetch from CloudKit user record
        // This should query CKContainer.default().fetchUserRecordID()
        // then fetch the user record to get givenName/familyName
        return "Current User"
    }

    // MARK: - Heirloom Sharing Setup

    /// Prepare recipe for heirloom sharing (creates base version if needed)
    /// - Parameters:
    ///   - recipe: The recipe to prepare
    ///   - context: SwiftData model context
    /// - Throws: SwiftData save errors
    func prepareForHeirloomSharing(
        _ recipe: Recipe,
        context: ModelContext
    ) throws {
        // Set sharing permission to heirloom
        recipe.sharingPermission = .heirloom

        // Create base version if doesn't exist
        if recipe.baseVersion == nil {
            _ = try createBaseVersion(for: recipe, context: context)
        }
    }

    /// Handle receiving a shared heirloom recipe
    /// Creates a new version for the recipient
    /// - Parameters:
    ///   - recipe: The received recipe
    ///   - context: SwiftData model context
    /// - Returns: The new version created for recipient
    /// - Throws: SwiftData save errors
    func handleReceivedHeirloomShare(
        _ recipe: Recipe,
        context: ModelContext
    ) throws -> RecipeVersion {
        // Create base version if doesn't exist
        if recipe.baseVersion == nil {
            _ = try createBaseVersion(for: recipe, context: context)
        }

        // Create new version for current user
        let userVersion = try createVersion(for: recipe, context: context)

        // Select the user's new version
        try selectVersion(userVersion, for: recipe, context: context)

        return userVersion
    }
}

// MARK: - Supporting Types

/// Represents updates to apply to a version
struct VersionUpdates {
    var title: String?
    var ingredients: [String]?
    var instructions: [String]?
    var servings: String?
    var prepTime: String?
    var cookTime: String?
    var notes: String?
}

/// Errors specific to recipe version operations
enum RecipeVersionError: LocalizedError {
    case baseVersionAlreadyExists
    case versionNotFoundInRecipe
    case cannotDeactivateBaseVersion
    case cannotDeleteBaseVersion

    var errorDescription: String? {
        switch self {
        case .baseVersionAlreadyExists:
            return "Recipe already has a base version"
        case .versionNotFoundInRecipe:
            return "Version does not belong to this recipe"
        case .cannotDeactivateBaseVersion:
            return "Cannot deactivate the base version"
        case .cannotDeleteBaseVersion:
            return "Cannot delete the base version"
        }
    }
}

// MARK: - Sample Usage

#if DEBUG
extension RecipeVersionService {
    /// Create sample versions for testing
    func createSampleVersions(for recipe: Recipe, context: ModelContext) throws {
        // Create base version
        let base = try createBaseVersion(for: recipe, context: context)

        // Create Mom's version with changes
        let momVersion = RecipeVersion(
            creatorUserID: "user-mom",
            creatorDisplayName: "Mom",
            creationYear: "2015"
        )
        momVersion.title = recipe.title
        momVersion.ingredients = base.ingredients
        momVersion.instructions = base.instructions
        momVersion.notes = "I always double the honey!"

        recipe.versions?.append(momVersion)

        // Create your version with changes
        let yourVersion = RecipeVersion(
            creatorUserID: "user-you",
            creatorDisplayName: "You",
            creationYear: "2025"
        )
        yourVersion.title = recipe.title
        yourVersion.ingredients = base.ingredients
        yourVersion.instructions = base.instructions
        yourVersion.notes = "Made it vegan with oat milk"

        recipe.versions?.append(yourVersion)

        try context.save()
    }
}
#endif
