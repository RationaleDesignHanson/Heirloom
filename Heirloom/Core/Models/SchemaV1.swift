import Foundation
import SwiftData

/// Version 1.0.0 of the Heirloom data schema
/// This enables future migrations without breaking existing installations
///
/// Heritage Collections (Cold Start):
/// - Recipe: Added isHeritageRecipe, heritageCollectionId, blurhash, imageVariants, historicalText, historicalContext
/// - RecipeCollection: Added heritageCollectionId for founding collections
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Recipe.self,
            RecipeVersion.self,  // ADDED: Multi-version recipe support with attribution
            RecipeLineage.self,  // ADDED: Heirloom sharing lineage tracking for family recipe trees
            Ingredient.self,
            Tag.self,
            RecipeCollection.self,  // UPDATED: Added heritageCollectionId for founding collections
            RecipeCardStyle.self,
            RecipeSticker.self,
            RecipeAnnotation.self,
            Substitution.self,
            DinnerParty.self,
            DinnerPartyRecipe.self,
            ShoppingCartRecipe.self,  // ADDED: Required for shopping list functionality
            RecipeComment.self,  // ADDED: Social comments feature with AI sentiment analysis
            RecipeCardBack.self,  // ADDED: Card back customization with personal notes & comments
            ImportJob.self,  // ADDED: Bulk import job tracking
            ImportItem.self  // ADDED: Individual import item tracking
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
