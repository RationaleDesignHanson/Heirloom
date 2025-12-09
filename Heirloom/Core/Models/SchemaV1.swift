import Foundation
import SwiftData

/// Version 1.0.0 of the Heirloom data schema
/// This enables future migrations without breaking existing installations
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Recipe.self,
            Ingredient.self,
            CardStyle.self,
            Sticker.self,
            Annotation.self,
            Substitution.self
            // DinnerParty and SharedRecipeCard will be added in Phase 3
        ]
    }

    static var schema: Schema {
        Schema(models)
    }
}

// MARK: - Migration Plan for Future Versions

/**
 Migration Strategy:

 V1 → V2 (when adding card customization in Phase 2):
 - Add CardStyle, Sticker, Annotation models
 - Lightweight migration (no data transformation needed)

 V2 → V3 (when adding social features in Phase 3):
 - Add DinnerParty, SharedRecipeCard models
 - Lightweight migration

 V3 → V4 (if we need to change Recipe structure):
 - Custom migration plan with MigrationPlan
 - Example: If we need to split instructions into InstructionStep model
 */
