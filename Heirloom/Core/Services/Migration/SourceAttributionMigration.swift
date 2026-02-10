//
//  SourceAttributionMigration.swift
//  Heirloom
//
//  Seeds the KnownSource registry from existing recipe data.
//  Follows the CommunityRecipeIngredientMigration pattern.
//

import Foundation
import SwiftData

@MainActor
class SourceAttributionMigration {

    /// Current migration version — increment to force re-run on all users
    static let currentVersion = 2

    /// Run the migration to seed KnownSource entries from existing recipes.
    /// - Parameters:
    ///   - context: The model context to use
    ///   - attributionService: The attribution service for registering sources
    /// - Returns: Number of known sources created
    @discardableResult
    static func run(context: ModelContext, attributionService: SourceAttributionService) throws -> Int {
        let lastRunVersion = UserDefaults.standard.integer(forKey: UserDefaultsKeys.sourceAttributionMigrationVersion)
        if lastRunVersion >= currentVersion {
            Log.debug("Source attribution migration already at version \(currentVersion), skipping", category: .migration)
            return 0
        }

        Log.info("Starting source attribution migration v\(currentVersion)", category: .migration, metadata: [
            "previousVersion": lastRunVersion
        ])

        // V2: Clear generic "Theme Collection" source so backfill re-creates per-theme sources
        if lastRunVersion < 2 {
            let predicate = #Predicate<KnownSource> { $0.name == "Theme Collection" }
            let genericSources = (try? context.fetch(FetchDescriptor<KnownSource>(predicate: predicate))) ?? []
            for source in genericSources {
                // Unlink recipes so they become orphans for re-backfill
                for recipe in source.recipes ?? [] {
                    recipe.knownSource = nil
                }
                context.delete(source)
                Log.info("Removed generic 'Theme Collection' source for re-backfill", category: .migration)
            }
        }

        // Use the service's backfill which handles all source types
        let seededCount = attributionService.backfillAttribution()

        // Mark migration as complete
        UserDefaults.standard.set(currentVersion, forKey: UserDefaultsKeys.sourceAttributionMigrationVersion)

        Log.info("Source attribution migration v\(currentVersion) complete", category: .migration, metadata: [
            "sourcesSeeded": seededCount
        ])

        return seededCount
    }
}
