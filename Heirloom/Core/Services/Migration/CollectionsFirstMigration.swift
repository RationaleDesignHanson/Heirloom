import Foundation
import SwiftData

/// Migration handler for Collections-First Architecture (v1.10.0)
/// Ensures smooth transition for existing users when upgrading from recipes-first to collections-first interface
@MainActor
final class CollectionsFirstMigration {

    // MARK: - Migration Version

    private static let migrationKey = "CollectionsFirstMigration_v1.10.0_completed"

    // MARK: - Public API

    /// Run collections-first migration if needed
    /// - Parameter context: SwiftData model context
    /// - Returns: True if migration was performed, false if already completed
    static func runIfNeeded(context: ModelContext) -> Bool {
        // Check if migration already completed
        if UserDefaults.standard.bool(forKey: migrationKey) {
            Log.debug("Collections-First migration already completed", category: .general)
            return false
        }

        Log.info("Running Collections-First migration", category: .general)

        // Perform migration steps
        performMigration(context: context)

        // Mark as completed
        UserDefaults.standard.set(true, forKey: migrationKey)

        Log.info("Collections-First migration completed successfully", category: .general)
        return true
    }

    // MARK: - Migration Steps

    private static func performMigration(context: ModelContext) {
        // Step 1: Ensure "All Recipes" system collection exists
        ensureAllRecipesCollection(context: context)

        // Step 2: Reset any cached tab selection to Collections (tab 0)
        resetTabSelection()

        // Step 3: Clear any stale navigation state
        clearNavigationState()
    }

    /// Ensure "All Recipes" collection exists
    /// This is idempotent - createSystemCollections() checks before creating
    private static func ensureAllRecipesCollection(context: ModelContext) {
        Log.debug("Ensuring All Recipes collection exists", category: .general)

        // Check if "All Recipes" already exists
        var descriptor = FetchDescriptor<RecipeCollection>()
        descriptor.predicate = #Predicate<RecipeCollection> { collection in
            collection.isAllRecipes == true
        }

        let allRecipesExists = (try? context.fetch(descriptor))?.isEmpty == false

        if !allRecipesExists {
            Log.info("Creating All Recipes collection for existing user", category: .general)

            // Create All Recipes collection
            let allRecipes = RecipeCollection(
                name: "All Recipes",
                description: "All recipes in your library",
                iconName: "book.closed.fill",
                color: "#FF6B6B",
                isSystemCollection: true,
                isAllRecipes: true
            )
            context.insert(allRecipes)

            try? context.save()

            Log.info("All Recipes collection created successfully", category: .general)
        } else {
            Log.debug("All Recipes collection already exists", category: .general)
        }
    }

    /// Reset tab selection to Collections (tab 0)
    private static func resetTabSelection() {
        // Clear any persisted tab selection preference
        // The app will default to Collections (tab 0)
        UserDefaults.standard.removeObject(forKey: "selectedTab")
        UserDefaults.standard.removeObject(forKey: "lastSelectedTab")

        Log.debug("Tab selection reset to default (Collections)", category: .general)
    }

    /// Clear stale navigation state
    private static func clearNavigationState() {
        // Clear any navigation paths that reference the old recipes tab
        UserDefaults.standard.removeObject(forKey: "navigationPath")
        UserDefaults.standard.removeObject(forKey: "pendingNavigation")

        Log.debug("Navigation state cleared", category: .general)
    }

    // MARK: - Testing Support

    /// Reset migration state (for testing only)
    static func resetMigrationState() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
        Log.warning("Migration state reset (testing only)", category: .general)
    }
}
