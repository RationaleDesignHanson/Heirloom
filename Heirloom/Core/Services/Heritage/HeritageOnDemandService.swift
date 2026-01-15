//
//  HeritageOnDemandService.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-14.
//

import Foundation
import SwiftData
import FirebaseFirestore

/// Service for on-demand heritage recipe downloads
/// Fetches recipes from Firestore and inserts into SwiftData as they unlock
@MainActor
class HeritageOnDemandService {
    private let modelContext: ModelContext
    private let firebaseAuth: FirebaseAuthService

    init(modelContext: ModelContext, firebaseAuth: FirebaseAuthService) {
        self.modelContext = modelContext
        self.firebaseAuth = firebaseAuth
    }

    // MARK: - Schedule Management

    /// Get or assign unlock schedule for current user
    func getUserSchedule() async throws -> HeritageUnlockSchedule {
        guard let userId = firebaseAuth.currentUser?.uid else {
            throw HeritageOnDemandError.notAuthenticated
        }

        let db = Firestore.firestore()

        // Check if user already has assigned schedule
        let stateRef = db.collection("users").document(userId).collection("heritageState").document("current")
        let stateDoc = try await stateRef.getDocument()

        if stateDoc.exists,
           let assignedScheduleId = stateDoc.data()?["assignedScheduleId"] as? String {
            // Fetch assigned schedule
            return try await fetchSchedule(scheduleId: assignedScheduleId)
        } else {
            // Assign new schedule based on user ID hash
            let scheduleId = assignScheduleForUser(userId: userId)
            let schedule = try await fetchSchedule(scheduleId: scheduleId)

            // Save assignment to user state
            try await stateRef.setData([
                "assignedScheduleId": scheduleId,
                "downloadedRecipeIds": [],
                "currentDay": 0,
                "lastUnlockDate": NSNull(),
                "trialEndsAt": NSNull(),
                "createdAt": FieldValue.serverTimestamp()
            ], merge: true)

            Log.info("Assigned schedule to user", category: .firebase, metadata: [
                "userId": userId,
                "scheduleId": scheduleId
            ])

            return schedule
        }
    }

    /// Assign a schedule ID deterministically based on user ID
    private func assignScheduleForUser(userId: String) -> String {
        // Hash user ID to get consistent schedule assignment
        var hasher = Hasher()
        hasher.combine(userId)
        let hash = abs(hasher.finalize())

        // Map to schedule 1-100
        let scheduleNum = (hash % 100) + 1
        return String(format: "schedule-%03d", scheduleNum)
    }

    /// Fetch unlock schedule from Firestore
    private func fetchSchedule(scheduleId: String) async throws -> HeritageUnlockSchedule {
        let db = Firestore.firestore()
        let scheduleRef = db.collection("heritage_schedules").document(scheduleId)

        let document = try await scheduleRef.getDocument()

        guard document.exists, let data = document.data() else {
            throw HeritageOnDemandError.scheduleNotFound(scheduleId)
        }

        // Parse schedule
        guard let scheduleId = data["scheduleId"] as? String,
              let version = data["version"] as? String,
              let revealedCollections = data["revealedCollections"] as? [String],
              let unlockPlanData = data["unlockPlan"] as? [[String: Any]] else {
            throw HeritageOnDemandError.invalidScheduleFormat
        }

        let unlockPlan = try unlockPlanData.map { dayData -> DayUnlockPlan in
            guard let day = dayData["day"] as? Int,
                  let recipes = dayData["recipes"] as? [String] else {
                throw HeritageOnDemandError.invalidScheduleFormat
            }
            return DayUnlockPlan(day: day, recipes: recipes)
        }

        return HeritageUnlockSchedule(
            scheduleId: scheduleId,
            version: version,
            revealedCollections: revealedCollections,
            unlockPlan: unlockPlan
        )
    }

    // MARK: - Recipe Downloads

    /// Download and insert recipes for a specific day
    func downloadRecipesForDay(day: Int, schedule: HeritageUnlockSchedule) async throws -> [Recipe] {
        guard let dayPlan = schedule.unlockPlan.first(where: { $0.day == day }) else {
            Log.warning("No unlock plan for day", category: .heritage, metadata: ["day": day])
            return []
        }

        Log.info("Downloading recipes for day", category: .heritage, metadata: [
            "day": day,
            "recipeCount": dayPlan.recipes.count,
            "recipeIds": dayPlan.recipes.joined(separator: ", ")
        ])

        var downloadedRecipes: [Recipe] = []

        for recipeId in dayPlan.recipes {
            do {
                let recipe = try await downloadRecipe(recipeId: recipeId)
                downloadedRecipes.append(recipe)
            } catch {
                Log.error("Failed to download recipe", category: .heritage, metadata: [
                    "recipeId": recipeId,
                    "error": error.localizedDescription
                ])
                // Continue with other recipes
            }
        }

        // Save context after all recipes downloaded
        try modelContext.save()

        Log.info("Downloaded and saved recipes for day", category: .heritage, metadata: [
            "day": day,
            "successCount": downloadedRecipes.count,
            "expectedCount": dayPlan.recipes.count
        ])

        return downloadedRecipes
    }

    /// Download and insert a single recipe from Firestore
    private func downloadRecipe(recipeId: String) async throws -> Recipe {
        // Check if recipe already exists locally
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.heritageRecipeId == recipeId }
        )

        if let existingRecipe = try modelContext.fetch(descriptor).first {
            Log.debug("Recipe already exists locally", category: .heritage, metadata: [
                "recipeId": recipeId,
                "title": existingRecipe.title
            ])
            return existingRecipe
        }

        // Fetch from Firestore
        let db = Firestore.firestore()
        let recipeRef = db.collection("heritage_recipes").document(recipeId)

        let document = try await recipeRef.getDocument()

        guard document.exists, let data = document.data() else {
            throw HeritageOnDemandError.recipeNotFound(recipeId)
        }

        // Parse recipe data
        guard let title = data["title"] as? String,
              let heritageCollectionId = data["heritageCollectionId"] as? String,
              let ingredientsData = data["ingredients"] as? [String],
              let instructionsData = data["instructions"] as? [String] else {
            throw HeritageOnDemandError.invalidRecipeFormat(recipeId)
        }

        // Create Recipe object
        let recipe = Recipe(
            title: title,
            sourceType: .heritage,
            instructions: instructionsData,
            servings: data["servings"] as? String,
            prepTime: data["prepTime"] as? String,
            cookTime: data["cookTime"] as? String
        )

        // Set heritage fields
        recipe.isHeritageRecipe = true
        recipe.heritageRecipeId = recipeId
        recipe.heritageCollectionId = heritageCollectionId
        recipe.historicalText = data["historicalText"] as? String
        recipe.historicalContext = data["historicalContext"] as? String
        recipe.sourceStory = data["historicalContext"] as? String

        // Set provenance
        recipe.provenance = ProvenanceMetadata(
            sourceType: .imported,
            sourceURL: data["sourceURL"] as? String,
            sourceAttribution: data["sourceAttribution"] as? String,
            generation: 0,
            createdAt: parseSourceDate(data["sourceDate"] as? String)
        )

        // Add to collection - set relationship from BOTH sides to ensure SwiftData updates
        if let collection = try fetchHeritageCollection(collectionId: heritageCollectionId) {
            recipe.collections = [collection]

            // CRITICAL: Also add recipe to collection's recipes array
            // This ensures SwiftData propagates the change to already-loaded collection objects
            if collection.recipes == nil {
                collection.recipes = [recipe]
            } else {
                collection.recipes?.append(recipe)
            }
        }

        // Create ingredients with parsing
        var ingredients: [Ingredient] = []
        for (index, ingredientText) in ingredientsData.enumerated() {
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

        // Download and save image if URL provided
        if let imageURLString = data["imageURL"] as? String {
            do {
                let imageService = ServiceContainer.shared.resolve(ImageStorageService.self)
                let fileName = try await imageService.downloadAndSaveImage(from: imageURLString, recipeId: recipe.id)
                recipe.imageFileName = fileName
                Log.debug("Downloaded heritage recipe image", category: .heritage, metadata: [
                    "recipeId": recipeId,
                    "fileName": fileName
                ])
            } catch {
                Log.warning("Failed to download recipe image", category: .heritage, metadata: [
                    "recipeId": recipeId,
                    "error": error.localizedDescription
                ])
                // Continue without image - not critical
            }
        }

        // Create card back
        let cardBack = RecipeCardBack(recipe: recipe)
        cardBack.configureForHeritageRecipe()
        cardBack.isComplete = true
        recipe.cardBack = cardBack
        modelContext.insert(cardBack)

        // Insert recipe into context
        modelContext.insert(recipe)

        Log.info("Downloaded and created heritage recipe", category: .heritage, metadata: [
            "recipeId": recipeId,
            "title": title,
            "collection": heritageCollectionId
        ])

        return recipe
    }

    /// Fetch heritage collection from local database
    private func fetchHeritageCollection(collectionId: String) throws -> RecipeCollection? {
        let descriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { $0.heritageCollectionId == collectionId }
        )
        return try modelContext.fetch(descriptor).first
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

// MARK: - Data Models

struct HeritageUnlockSchedule: Codable {
    let scheduleId: String
    let version: String
    let revealedCollections: [String]  // e.g., ["literary-kitchen", "presidential-pantry"]
    let unlockPlan: [DayUnlockPlan]
}

struct DayUnlockPlan: Codable {
    let day: Int
    let recipes: [String]  // Recipe IDs to unlock on this day
}

// MARK: - Errors

enum HeritageOnDemandError: LocalizedError {
    case notAuthenticated
    case scheduleNotFound(String)
    case invalidScheduleFormat
    case recipeNotFound(String)
    case invalidRecipeFormat(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User must be authenticated to download heritage recipes"
        case .scheduleNotFound(let scheduleId):
            return "Unlock schedule not found: \(scheduleId)"
        case .invalidScheduleFormat:
            return "Invalid unlock schedule format"
        case .recipeNotFound(let recipeId):
            return "Heritage recipe not found: \(recipeId)"
        case .invalidRecipeFormat(let recipeId):
            return "Invalid recipe format: \(recipeId)"
        }
    }
}

// MARK: - Global Accessor

extension HeritageOnDemandService {
    /// Global accessor via ServiceContainer for DI
    nonisolated(unsafe) static var shared: HeritageOnDemandService {
        MainActor.assumeIsolated {
            ServiceContainer.shared.resolve(HeritageOnDemandService.self)
        }
    }
}
