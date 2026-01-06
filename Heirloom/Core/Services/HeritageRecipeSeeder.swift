import Foundation
import SwiftData
import UIKit

/// Service for seeding heritage collections on first launch
/// Implements personalized distribution (8-12 recipes per user from pool)
@MainActor
class HeritageRecipeSeeder {
    private let modelContext: ModelContext

    // MARK: - Configuration

    /// Number of recipes each user receives (randomized within range)
    private let recipesPerUser = (min: 8, max: 12)

    /// Minimum recipes per collection to ensure variety
    private let minRecipesPerCollection = 2

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

    /// Seed personalized heritage recipes for this user
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

        // Randomly select recipes for this user
        let selectedRecipes = selectRandomRecipes(from: heritageData.recipes)

        Log.info("Selected personalized recipes", category: .storage, metadata: [
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

            // Create ingredients
            var ingredients: [Ingredient] = []
            for (index, ingredientText) in recipeJSON.ingredients.enumerated() {
                let ingredient = Ingredient(
                    originalText: ingredientText,
                    name: ingredientText,
                    quantity: nil,
                    unit: nil,
                    category: .other,
                    orderIndex: index
                )
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
        UserDefaults.standard.set(selectedRecipes.map { $0.id }, forKey: "HeritageRecipesSelected")

        Log.info("Heritage recipes seeded successfully", category: .storage, metadata: [
            "count": seededCount
        ])

        return seededCount
    }

    // MARK: - Random Selection

    /// Select random recipes ensuring variety across collections
    private func selectRandomRecipes(from allRecipes: [HeritageRecipeJSON]) -> [HeritageRecipeJSON] {
        // Group recipes by collection
        let recipesByCollection = Dictionary(grouping: allRecipes) { $0.heritageCollectionId }

        // Determine how many recipes to select
        let totalToSelect = Int.random(in: recipesPerUser.min...recipesPerUser.max)

        var selected: [HeritageRecipeJSON] = []
        var remaining = allRecipes.shuffled()

        // First pass: Ensure minimum recipes per collection
        for (_, recipes) in recipesByCollection {
            let collectionRecipes = recipes.shuffled().prefix(minRecipesPerCollection)
            selected.append(contentsOf: collectionRecipes)

            // Remove selected from remaining
            let selectedIds = Set(collectionRecipes.map { $0.id })
            remaining.removeAll { selectedIds.contains($0.id) }
        }

        // Second pass: Fill remaining slots randomly
        let remainingSlots = totalToSelect - selected.count
        if remainingSlots > 0 {
            let additionalRecipes = remaining.prefix(remainingSlots)
            selected.append(contentsOf: additionalRecipes)
        }

        Log.info("Recipe selection complete", category: .storage, metadata: [
            "total": selected.count,
            "perCollection": selected.reduce(into: [String: Int]()) { counts, recipe in
                counts[recipe.heritageCollectionId, default: 0] += 1
            }
        ])

        return selected.shuffled() // Shuffle final list
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
