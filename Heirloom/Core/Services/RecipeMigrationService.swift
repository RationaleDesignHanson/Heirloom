import Foundation
import SwiftData

/// Service for migrating existing recipes to support multi-version system
/// Run this once after deploying version support to existing users
@MainActor
final class RecipeMigrationService {
    static let shared = RecipeMigrationService()
    private init() {}

    // MARK: - Migration

    /// Migrate all recipes without base versions to have base versions
    /// This should be run once when users first upgrade to version support
    /// - Parameter context: SwiftData model context
    /// - Returns: Number of recipes migrated
    /// - Throws: SwiftData save errors
    func migrateRecipesToVersions(context: ModelContext) throws -> Int {
        // Fetch all recipes that don't have a base version
        let descriptor = FetchDescriptor<Recipe>()
        let allRecipes = try context.fetch(descriptor)

        var migratedCount = 0

        for recipe in allRecipes {
            // Skip if already has base version
            if recipe.baseVersion != nil {
                continue
            }

            // Create base version from recipe content
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
            baseVersion.notes = recipe.notes

            // Insert base version into context
            context.insert(baseVersion)

            // Initialize versions array if needed
            if recipe.versions == nil {
                recipe.versions = []
            }

            // Add base version to recipe
            recipe.versions?.append(baseVersion)

            // Set as selected version
            recipe.selectedVersionID = baseVersion.id

            // Set default sharing permission
            if recipe.sharingPermission == .heirloom {
                // Keep existing heirloom permission
            } else {
                // Default to regular for backward compatibility
                recipe.sharingPermission = .regular
            }

            migratedCount += 1
        }

        // Save all changes
        if migratedCount > 0 {
            try context.save()
        }

        return migratedCount
    }

    /// Check if migration is needed
    /// - Parameter context: SwiftData model context
    /// - Returns: True if there are recipes without base versions
    /// - Throws: SwiftData fetch errors
    func needsMigration(context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<Recipe>()
        let allRecipes = try context.fetch(descriptor)

        return allRecipes.contains { $0.baseVersion == nil }
    }

    /// Get migration statistics
    /// - Parameter context: SwiftData model context
    /// - Returns: Migration statistics
    /// - Throws: SwiftData fetch errors
    func getMigrationStats(context: ModelContext) throws -> MigrationStats {
        let descriptor = FetchDescriptor<Recipe>()
        let allRecipes = try context.fetch(descriptor)

        let totalRecipes = allRecipes.count
        let recipesWithVersions = allRecipes.filter { $0.baseVersion != nil }.count
        let recipesNeedingMigration = totalRecipes - recipesWithVersions

        return MigrationStats(
            totalRecipes: totalRecipes,
            recipesWithVersions: recipesWithVersions,
            recipesNeedingMigration: recipesNeedingMigration
        )
    }

    // MARK: - Sharing Permission Migration

    /// Migrate recipes with legacy sharing data to new permission system
    /// - Parameter context: SwiftData model context
    /// - Returns: Number of recipes updated
    /// - Throws: SwiftData save errors
    func migrateSharingPermissions(context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<Recipe>()
        let allRecipes = try context.fetch(descriptor)

        var migratedCount = 0

        for recipe in allRecipes {
            // If recipe has passedDown data, it should be heirloom
            if recipe.passedDownBy != nil || recipe.passedDownDate != nil {
                recipe.sharingPermission = .heirloom
                migratedCount += 1
            }
            // If recipe has high generation count, likely heirloom
            else if recipe.generationCount > 1 {
                recipe.sharingPermission = .heirloom
                migratedCount += 1
            }
            // Otherwise keep as regular
            else if recipe.sharingPermissionRaw.isEmpty {
                recipe.sharingPermission = .regular
                migratedCount += 1
            }
        }

        if migratedCount > 0 {
            try context.save()
        }

        return migratedCount
    }

    // MARK: - Validation

    /// Validate all recipes have proper version setup
    /// - Parameter context: SwiftData model context
    /// - Returns: Validation result with any issues found
    /// - Throws: SwiftData fetch errors
    func validateMigration(context: ModelContext) throws -> ValidationResult {
        let descriptor = FetchDescriptor<Recipe>()
        let allRecipes = try context.fetch(descriptor)

        var issues: [String] = []

        for recipe in allRecipes {
            // Check for base version
            if recipe.baseVersion == nil {
                issues.append("Recipe '\(recipe.title)' missing base version")
            }

            // Check for selected version
            if recipe.selectedVersionID == nil && recipe.versions?.isEmpty == false {
                issues.append("Recipe '\(recipe.title)' has versions but no selected version")
            }

            // Check version integrity
            if let versions = recipe.versions {
                let baseVersionCount = versions.filter { $0.isBaseVersion }.count
                if baseVersionCount == 0 {
                    issues.append("Recipe '\(recipe.title)' has versions but no base version")
                } else if baseVersionCount > 1 {
                    issues.append("Recipe '\(recipe.title)' has multiple base versions")
                }
            }
        }

        return ValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            recipesChecked: allRecipes.count
        )
    }

    // MARK: - Rollback

    /// Rollback migration (emergency use only)
    /// Removes all base versions and resets to pre-migration state
    /// - Parameter context: SwiftData model context
    /// - Returns: Number of recipes rolled back
    /// - Throws: SwiftData errors
    func rollbackMigration(context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<Recipe>()
        let allRecipes = try context.fetch(descriptor)

        var rolledBackCount = 0

        for recipe in allRecipes {
            // Remove all versions
            if let versions = recipe.versions {
                for version in versions {
                    context.delete(version)
                }
                recipe.versions = nil
            }

            // Clear selected version
            recipe.selectedVersionID = nil

            rolledBackCount += 1
        }

        if rolledBackCount > 0 {
            try context.save()
        }

        return rolledBackCount
    }
}

// MARK: - Supporting Types

/// Statistics about migration status
struct MigrationStats {
    var totalRecipes: Int
    var recipesWithVersions: Int
    var recipesNeedingMigration: Int

    var migrationProgress: Double {
        guard totalRecipes > 0 else { return 0.0 }
        return Double(recipesWithVersions) / Double(totalRecipes)
    }

    var isComplete: Bool {
        recipesNeedingMigration == 0
    }
}

/// Result of migration validation
struct ValidationResult {
    var isValid: Bool
    var issues: [String]
    var recipesChecked: Int

    var summary: String {
        if isValid {
            return "✓ All \(recipesChecked) recipes validated successfully"
        } else {
            return "✗ Found \(issues.count) issues in \(recipesChecked) recipes"
        }
    }
}

// MARK: - Migration UI Helper

#if DEBUG
extension RecipeMigrationService {
    /// Test migration with sample data
    func testMigration(context: ModelContext) throws {
        // Create sample recipes without versions
        let recipe1 = Recipe(title: "Test Recipe 1")
        recipe1.instructions = ["Step 1", "Step 2"]
        context.insert(recipe1)

        let recipe2 = Recipe(title: "Test Recipe 2")
        recipe2.instructions = ["Step A", "Step B"]
        recipe2.passedDownBy = "Grandma"
        context.insert(recipe2)

        try context.save()

        // Check migration needed
        let needsMigration = try needsMigration(context: context)
        Log.debug("Migration check complete", category: .database, metadata: ["needsMigration": needsMigration])

        // Get stats before
        let statsBefore = try getMigrationStats(context: context)
        Log.debug("Pre-migration stats", category: .database, metadata: ["recipesNeedingMigration": statsBefore.recipesNeedingMigration])

        // Run migration
        let migratedCount = try migrateRecipesToVersions(context: context)
        Log.info("Recipe migration complete", category: .database, metadata: ["migratedCount": migratedCount])

        // Migrate permissions
        let permissionsMigrated = try migrateSharingPermissions(context: context)
        Log.info("Sharing permissions migration complete", category: .database, metadata: ["permissionsMigrated": permissionsMigrated])

        // Get stats after
        let statsAfter = try getMigrationStats(context: context)
        Log.debug("Post-migration stats", category: .database, metadata: ["recipesNeedingMigration": statsAfter.recipesNeedingMigration])

        // Validate
        let validation = try validateMigration(context: context)
        Log.info("Migration validation result", category: .database, metadata: ["summary": validation.summary])

        if !validation.isValid {
            for issue in validation.issues {
                Log.warning("Migration validation issue", category: .database, metadata: ["issue": issue])
            }
        }
    }
}
#endif
