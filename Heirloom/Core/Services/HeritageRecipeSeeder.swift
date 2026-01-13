import Foundation
import SwiftData
import UIKit

/// Service for seeding heritage collections on first launch
/// Implements progressive unlock system - all 100 recipes seeded as locked
@MainActor
class HeritageRecipeSeeder {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Seed Data Models

    struct HeritageRecipeData: Codable {
        let version: String
        let description: String
        let recipes: [HeritageRecipeJSON]
    }

    struct HeritageRecipeJSON: Codable {
        let id: String
        let title: String
        let heritageCollectionId: String
        let servings: String?
        let prepTime: String?
        let cookTime: String?
        let ingredients: [String]
        let instructions: [String]
        let historicalText: String?
        let historicalContext: String?
        let sourceAttribution: String?
        let sourceDate: String?
        let sourceURL: String?
        let imageURL: String?  // Optional image URL to download
        let tags: [String]?
    }

    // MARK: - Public API

    /// Check if heritage recipes have already been seeded
    func isSeeded() -> Bool {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isHeritageRecipe == true }
        )

        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        return count > 0
    }

    /// Seed all 100 heritage recipes as locked for progressive unlock system
    /// Returns number of recipes seeded
    func seedHeritageRecipes() async throws -> Int {
        // Don't seed if already seeded
        guard !isSeeded() else {
            Log.info("Heritage recipes already seeded", category: .storage)
            return 0
        }

        // Load JSON from bundle
        guard let url = Bundle.main.url(forResource: "heritage-recipes", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            Log.error("Failed to load heritage recipes JSON", category: .storage)
            throw HeritageSeederError.jsonNotFound
        }

        // Parse JSON
        let decoder = JSONDecoder()
        let heritageData = try decoder.decode(HeritageRecipeData.self, from: data)

        Log.info("Loaded heritage recipes", category: .storage, metadata: [
            "version": heritageData.version,
            "totalRecipes": heritageData.recipes.count
        ])

        // Ensure heritage collections exist
        RecipeCollection.createHeritageCollections(context: modelContext)

        // Seed ALL 100 recipes (not random selection)
        let selectedRecipes = heritageData.recipes

        Log.info("Seeding all heritage recipes for progressive unlock", category: .storage, metadata: [
            "count": selectedRecipes.count
        ])

        // Fetch heritage collections
        let collectionsDescriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { $0.heritageCollectionId != nil }
        )
        let collections = try modelContext.fetch(collectionsDescriptor)
        let collectionsMap: [String: RecipeCollection] = Dictionary(uniqueKeysWithValues: collections.compactMap { collection -> (String, RecipeCollection)? in
            guard let heritageId = collection.heritageCollectionId else { return nil }
            return (heritageId, collection)
        })

        // Create Recipe objects
        var seededCount = 0
        for recipeJSON in selectedRecipes {
            let recipe = Recipe(
                title: recipeJSON.title,
                sourceType: .heritage,
                instructions: recipeJSON.instructions,
                servings: recipeJSON.servings,
                prepTime: recipeJSON.prepTime,
                cookTime: recipeJSON.cookTime
            )

            // Set heritage fields
            recipe.isHeritageRecipe = true
            recipe.heritageCollectionId = recipeJSON.heritageCollectionId
            recipe.historicalText = recipeJSON.historicalText
            recipe.historicalContext = recipeJSON.historicalContext
            recipe.sourceStory = recipeJSON.historicalContext

            // Set provenance
            recipe.provenance = ProvenanceMetadata(
                sourceType: .imported,
                sourceURL: recipeJSON.sourceURL,
                sourceAttribution: recipeJSON.sourceAttribution,
                generation: 0,
                createdAt: parseSourceDate(recipeJSON.sourceDate)
            )

            // Add to collection
            if let collection = collectionsMap[recipeJSON.heritageCollectionId] {
                recipe.collections = [collection]
            }

            // Create ingredients with proper parsing for scaling support
            var ingredients: [Ingredient] = []
            for (index, ingredientText) in recipeJSON.ingredients.enumerated() {
                // Parse ingredient to extract quantity, unit, and name
                let parsed = IngredientParser.parse(ingredientText)

                let ingredient = Ingredient(
                    originalText: ingredientText,
                    name: parsed.name.isEmpty ? ingredientText : parsed.name,
                    quantity: parsed.quantity,
                    unit: parsed.unit,
                    category: .other,
                    orderIndex: index
                )
                ingredient.quantityMax = parsed.quantityMax
                ingredient.recipe = recipe
                ingredients.append(ingredient)
            }
            recipe.ingredients = ingredients

            // Download and save image if URL provided (synchronously before inserting)
            if let imageURL = recipeJSON.imageURL {
                do {
                    let imageService = ServiceContainer.shared.resolve(ImageStorageService.self)
                    let fileName = try await imageService.downloadAndSaveImage(from: imageURL, recipeId: recipe.id)
                    recipe.imageFileName = fileName
                    Log.debug("Downloaded heritage recipe image", category: .storage, metadata: [
                        "title": recipe.title,
                        "fileName": fileName
                    ])
                } catch {
                    Log.warning("Failed to download heritage recipe image", category: .storage, metadata: [
                        "title": recipe.title,
                        "url": imageURL,
                        "error": error.localizedDescription
                    ])
                    // Continue without image - not critical
                }
            }

            // Create card back with heritage information
            let cardBack = RecipeCardBack(recipe: recipe)
            cardBack.configureForHeritageRecipe()
            cardBack.isComplete = true
            recipe.cardBack = cardBack
            modelContext.insert(cardBack)

            Log.debug("Created heritage card back", category: .storage, metadata: [
                "title": recipe.title,
                "hasHistoricalText": recipe.historicalText != nil
            ])

            // Insert into context
            modelContext.insert(recipe)
            seededCount += 1

            Log.debug("Created heritage recipe", category: .storage, metadata: [
                "title": recipe.title,
                "collection": recipeJSON.heritageCollectionId
            ])
        }

        // Save context
        try modelContext.save()

        // Track seeding in UserDefaults
        UserDefaults.standard.set(true, forKey: "HeritageRecipesSeeded")
        UserDefaults.standard.set(Date(), forKey: "HeritageRecipesSeedDate")

        Log.info("Heritage recipes seeded successfully - all 100 recipes available for progressive unlock", category: .storage, metadata: [
            "count": seededCount
        ])

        return seededCount
    }

    /// Parse source date string to Date (best effort)
    private func parseSourceDate(_ dateString: String?) -> Date {
        guard let dateString = dateString else { return Date() }

        // Try to extract year
        let components = dateString.components(separatedBy: CharacterSet.decimalDigits.inverted)
        let years = components.compactMap { Int($0) }.filter { $0 > 1000 && $0 < 2100 }

        if let year = years.first {
            var dateComponents = DateComponents()
            dateComponents.year = year
            dateComponents.month = 1
            dateComponents.day = 1
            if let date = Calendar.current.date(from: dateComponents) {
                return date
            }
        }

        return Date()
    }

    // MARK: - Migration & Repair

    /// Re-parse ingredients for existing heritage recipes that were seeded before parser was added
    /// This ensures all heritage recipes have proper quantities and units for scaling
    func migrateHeritageIngredients() async throws {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isHeritageRecipe == true }
        )

        let heritageRecipes = try modelContext.fetch(descriptor)
        var migratedCount = 0

        Log.info("Starting heritage ingredient migration", category: .storage, metadata: [
            "totalRecipes": heritageRecipes.count
        ])

        for recipe in heritageRecipes {
            guard let ingredients = recipe.ingredients else { continue }

            for ingredient in ingredients {
                // Only migrate if missing quantity/unit
                if ingredient.quantity == nil && ingredient.unit == nil && !ingredient.originalText.isEmpty {
                    let parsed = IngredientParser.parse(ingredient.originalText)

                    // Update ingredient with parsed values
                    ingredient.name = parsed.name.isEmpty ? ingredient.originalText : parsed.name
                    ingredient.quantity = parsed.quantity
                    ingredient.quantityMax = parsed.quantityMax
                    ingredient.unit = parsed.unit

                    migratedCount += 1

                    Log.debug("Migrated heritage ingredient", category: .storage, metadata: [
                        "recipe": recipe.title,
                        "originalText": ingredient.originalText,
                        "quantity": parsed.quantity ?? 0,
                        "unit": parsed.unit ?? "none"
                    ])
                }
            }
        }

        try modelContext.save()

        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: "HeritageIngredientsMigrated")
        UserDefaults.standard.set(Date(), forKey: "HeritageIngredientsMigrationDate")

        Log.info("Heritage ingredient migration completed", category: .storage, metadata: [
            "migratedCount": migratedCount
        ])
    }

    /// Ensure all heritage recipes have card backs configured
    /// Call this to repair existing installations where card backs were added later
    func ensureHeritageCardBacks() {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { recipe in
                recipe.isHeritageRecipe == true
            }
        )

        do {
            let heritageRecipes = try modelContext.fetch(descriptor)

            var created = 0
            var configured = 0

            for recipe in heritageRecipes {
                if recipe.cardBack == nil {
                    // Create missing card back
                    let cardBack = RecipeCardBack(recipe: recipe)
                    cardBack.configureForHeritageRecipe()
                    cardBack.isComplete = true
                    recipe.cardBack = cardBack
                    modelContext.insert(cardBack)
                    created += 1

                    Log.info("Created missing heritage card back", category: .storage, metadata: [
                        "title": recipe.title,
                        "recipeId": recipe.id.uuidString
                    ])
                } else if let cardBack = recipe.cardBack {
                    // Ensure existing card back is properly configured
                    cardBack.configureForHeritageRecipe()
                    configured += 1
                }
            }

            try modelContext.save()

            Log.info("Heritage card back migration completed", category: .storage, metadata: [
                "total": heritageRecipes.count,
                "created": created,
                "configured": configured
            ])
        } catch {
            Log.error("Failed to migrate heritage card backs", category: .storage, metadata: ["error": error.localizedDescription])
        }
    }
}

// MARK: - Errors

enum HeritageSeederError: LocalizedError {
    case jsonNotFound
    case parseFailed
    case collectionNotFound(String)

    var errorDescription: String? {
        switch self {
        case .jsonNotFound:
            return "Heritage recipes JSON file not found in app bundle"
        case .parseFailed:
            return "Failed to parse heritage recipes JSON"
        case .collectionNotFound(let id):
            return "Heritage collection not found: \(id)"
        }
    }
}
