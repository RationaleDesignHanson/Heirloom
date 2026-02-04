import Foundation
import SwiftData

/// Version 2.0.0 of the Heirloom data schema
/// Adds multilingual recipe import support with optional language fields
///
/// Changes from V1:
/// - Recipe: Added multilingual fields (sourceLanguage, originalTitle, translatedTitle, etc.)
/// - Ingredient: Added translation/conversion fields (originalLanguageName, convertedQuantity, etc.)
/// - All new fields are optional (nullable) for backward compatibility
/// - Existing recipes default to English (sourceLanguage = "en", confidence = 1.0)
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Recipe.self,
            RecipeVersion.self,
            RecipeLineage.self,
            Ingredient.self,
            Tag.self,
            RecipeCollection.self,
            DeletedCollectionRecord.self,
            RecipeTheme.self,
            RecipeCardStyle.self,
            RecipeSticker.self,
            RecipeAnnotation.self,
            Substitution.self,
            DinnerParty.self,
            DinnerPartyRecipe.self,
            ShoppingCartRecipe.self,
            RecipeComment.self,
            RecipeCardBack.self,
            ImportJob.self,
            ImportItem.self,
            PDFImportCheckpoint.self,
            VideoProcessingJob.self,
            ProcessingCheckpoint.self,
            RecipeGenerationJob.self,
            UserCredits.self,
            QueuedPDFImport.self
        ]
    }

    static var schema: Schema {
        Schema(models)
    }
}

// MARK: - Migration Plan Definition

/// Heirloom's schema migration plan from V1 to V2
enum HeirloomSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// Migration from SchemaV1 to SchemaV2
    /// Adds optional multilingual fields without breaking existing data
    /// Uses lightweight migration since all V2 fields are optional
    static var migrateV1toV2: MigrationStage {
        return MigrationStage.lightweight(
            fromVersion: SchemaV1.self,
            toVersion: SchemaV2.self
        )
    }
}

// MARK: - Future Migration Notes

/**
 Migration Strategy Going Forward:

 V2 → V3 (future enhancements):
 - Additional language support fields
 - Translation quality metrics
 - Regional unit conversion tables

 Key Principles:
 1. All new fields must be optional (nullable)
 2. Provide sensible defaults for existing data
 3. Never remove fields (deprecate instead)
 4. Test migration with 10,000+ recipes before release
 5. Log migration progress for monitoring

 Testing Checklist:
 - [ ] Migration completes in < 5 seconds for 10K recipes
 - [ ] Zero data loss (all V1 fields preserved)
 - [ ] English regression tests pass 100%
 - [ ] Performance unchanged (query/save speed)
 - [ ] Rollback works correctly on failure
 */
