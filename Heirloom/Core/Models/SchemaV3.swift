//
//  SchemaV3.swift
//  Heirloom
//
//  Version 3.0.0 — Source Attribution Registry
//  Adds KnownSource model and Recipe.knownSource relationship.
//
//  Changes from V2:
//  - NEW: KnownSource model (local source attribution registry)
//  - Recipe: Added optional knownSource relationship
//  - All new fields are optional for backward compatibility
//

import Foundation
import SwiftData

enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

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
            QueuedPDFImport.self,
            KnownSource.self
        ]
    }

    static var schema: Schema {
        Schema(models)
    }
}
