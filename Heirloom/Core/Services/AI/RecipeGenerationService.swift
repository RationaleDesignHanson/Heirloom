//
//  RecipeGenerationService.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-02.
//

import Foundation
import SwiftData

/// Service managing recipe generation with progress tracking and retry logic
@MainActor
final class RecipeGenerationService: ObservableObject {
    // MARK: - Published State

    @Published private(set) var activeJob: RecipeGenerationJob?

    // MARK: - Dependencies

    private let aiGenerator: AIRecipeGeneratorProtocol
    private let imageGenerator: RecipeImageGeneratorProtocol
    internal var context: ModelContext?

    // MARK: - Initialization

    init(aiGenerator: AIRecipeGeneratorProtocol, imageGenerator: RecipeImageGeneratorProtocol) {
        self.aiGenerator = aiGenerator
        self.imageGenerator = imageGenerator
    }

    // MARK: - Public API

    /// Generate a recipe from dish name and optional ingredients
    func generateRecipe(
        dishName: String,
        ingredients: String?,
        context: ModelContext
    ) async throws {
        self.context = context

        // Create job
        let job = RecipeGenerationJob(dishName: dishName, ingredients: ingredients)
        context.insert(job)
        try context.save()

        // Set as active (triggers banner display)
        self.activeJob = job

        // Process in background
        Task.detached { @MainActor in
            await self.processJob(job)
        }
    }

    /// Generate a recipe from voice transcript
    func generateFromVoice(
        transcript: String,
        context: ModelContext
    ) async throws {
        self.context = context

        // Create job
        let job = RecipeGenerationJob(
            dishName: "Voice Recipe",
            transcript: transcript
        )
        context.insert(job)
        try context.save()

        self.activeJob = job

        Task.detached { @MainActor in
            await self.processVoiceJob(job)
        }
    }

    /// 🎲 Easter Egg: Generate a silly/random recipe for fun
    func generateSillyRecipe(context: ModelContext) async throws {
        self.context = context

        // Random silly recipe combos (name + absurd ingredients)
        let sillyRecipes: [(name: String, ingredients: String)] = [
            ("Jellied Rainbow Surprise", "lime jello, canned tuna, miniature marshmallows, cream cheese, maraschino cherries"),
            ("Spam & Banana Casserole", "canned spam, overripe bananas, mayonnaise, bread crumbs, brown sugar"),
            ("Pickle Juice Smoothie", "dill pickle juice, vanilla ice cream, cucumber, mint leaves, cottage cheese"),
            ("Tuna Jello Salad", "lemon jello, canned tuna, celery, pimentos, hard-boiled eggs"),
            ("Mayonnaise Cake Delight", "mayonnaise, chocolate cake mix, raisins, cream cheese frosting"),
            ("Hot Dog Jello Ring", "strawberry jello, sliced hot dogs, canned pineapple, whipped cream"),
            ("Cheese & Grape Aspic", "unflavored gelatin, cheddar cheese cubes, whole grapes, chicken broth"),
            ("Candied Olive Medley", "black olives, marshmallows, brown sugar, butter, cream cheese"),
            ("Liver Sausage Pineapple", "liver sausage, canned pineapple rings, cream cheese, pecans"),
            ("Tomato Aspic Tower", "tomato juice, unflavored gelatin, cottage cheese, canned shrimp, celery")
        ]

        let silly = sillyRecipes.randomElement() ?? (name: "Mystery Recipe", ingredients: "mystery ingredients")

        // Create job with silly flag and absurd ingredients
        let job = RecipeGenerationJob(dishName: silly.name, ingredients: silly.ingredients)
        job.isSillyRecipe = true  // Mark as silly for sharing restrictions
        context.insert(job)
        try context.save()

        self.activeJob = job

        Task.detached { @MainActor in
            await self.processJob(job)  // Process with absurd ingredients
        }
    }

    // MARK: - Job Processing

    private func processJob(_ job: RecipeGenerationJob) async {
        guard let context = context else {
            Log.error("ModelContext not available", category: .general)
            return
        }

        do {
            // Phase 1: Analyzing (20%)
            job.currentPhase = .analyzing
            try context.save()

            // Parse ingredients
            let ingredientList = parseIngredients(job.ingredients)

            // Phase 2: Extracting (50%)
            job.currentPhase = .extracting
            try context.save()

            // Generate recipe with retry logic
            let recipe = try await withRetry(maxAttempts: 3) {
                try await self.aiGenerator.generateRecipe(
                    dishName: job.dishName,
                    ingredients: ingredientList,
                    context: context
                )
            }

            // 🎲 Easter Egg: Add silly recipe disclaimers
            if job.isSillyRecipe {
                addSillyRecipeDisclaimers(to: recipe)
            }

            // Phase 3: Enriching (80%)
            job.currentPhase = .enriching
            try context.save()

            // Generate image (blocking, soft failure)
            // Wait for image generation to complete before marking recipe as done
            do {
                try await self.imageGenerator.generateAndSaveImage(for: recipe)
                Log.info("Recipe image generated successfully", category: .general)
            } catch {
                Log.error("Failed to generate image for recipe", category: .general, metadata: [
                    "error": error.localizedDescription
                ])
                // Continue without image
            }

            // Add to "Generated Recipes" collection
            await addToCollection(recipe, context: context)

            // Save
            try context.save()

            // Sync to Firebase (soft failure, non-blocking)
            Task {
                await syncToFirebase(recipe)
            }

            // Phase 4: Complete
            job.currentPhase = .complete
            job.status = .completed
            job.completedAt = Date()
            try context.save()

            // Auto-dismiss after 2 seconds
            try await Task.sleep(for: .seconds(2))
            self.activeJob = nil

        } catch {
            job.status = .failed
            job.error = error.localizedDescription
            try? context.save()

            Log.error("Recipe generation failed", category: .general, metadata: [
                "dishName": job.dishName,
                "error": error.localizedDescription
            ])
        }
    }

    private func processVoiceJob(_ job: RecipeGenerationJob) async {
        guard let context = context,
              let transcript = job.transcript else {
            Log.error("Missing context or transcript for voice job", category: .general)
            return
        }

        do {
            // Phase 1: Analyzing
            job.currentPhase = .analyzing
            try context.save()

            // TODO: Parse transcript to extract dish name and ingredients
            // For now, use transcript directly
            let dishName = extractDishName(from: transcript)
            job.dishName = dishName

            // Phase 2: Extracting
            job.currentPhase = .extracting
            try context.save()

            // Generate recipe with retry logic
            let recipe = try await withRetry(maxAttempts: 3) {
                try await self.aiGenerator.generateRecipe(
                    dishName: dishName,
                    ingredients: nil,
                    context: context
                )
            }

            // Phase 3: Enriching
            job.currentPhase = .enriching
            try context.save()

            // Generate image (blocking, soft failure)
            // Wait for image generation to complete before marking recipe as done
            do {
                try await self.imageGenerator.generateAndSaveImage(for: recipe)
                Log.info("Voice recipe image generated successfully", category: .general)
            } catch {
                Log.error("Failed to generate image", category: .general, metadata: [
                    "error": error.localizedDescription
                ])
                // Continue without image
            }

            // Add to collection
            await addToCollection(recipe, context: context)

            // Save
            try context.save()

            // Sync to Firebase (soft failure, non-blocking)
            Task {
                await syncToFirebase(recipe)
            }

            // Phase 4: Complete
            job.currentPhase = .complete
            job.status = .completed
            job.completedAt = Date()
            try context.save()

            // Auto-dismiss after 2 seconds
            try await Task.sleep(for: .seconds(2))
            self.activeJob = nil

        } catch {
            job.status = .failed
            job.error = error.localizedDescription
            try? context.save()

            Log.error("Voice recipe generation failed", category: .general, metadata: [
                "error": error.localizedDescription
            ])
        }
    }

    // MARK: - Retry Logic

    private func withRetry<T>(
        maxAttempts: Int = 3,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                Log.info("Recipe generation attempt \(attempt) of \(maxAttempts)",
                    category: .general)
                return try await operation()
            } catch let error as AIError {
                lastError = error

                Log.warning("Generation attempt \(attempt) failed with AIError",
                    category: .general,
                    metadata: [
                        "error": error.localizedDescription,
                        "isRetryable": error.isRetryable
                    ]
                )

                // Check if error is retryable
                if !error.isRetryable {
                    Log.error("Error is not retryable, failing immediately", category: .general)
                    throw error
                }

                // Don't retry quota exceeded
                if case .quotaExceeded = error {
                    Log.error("Quota exceeded, failing immediately", category: .general)
                    throw error
                }

                // Retry with backoff
                if attempt < maxAttempts {
                    let delay = error.retryDelay(attempt: attempt)
                    Log.warning("Retrying in \(delay)s (attempt \(attempt+1) of \(maxAttempts))",
                        category: .general,
                        metadata: ["error": error.localizedDescription]
                    )
                    try await Task.sleep(for: .seconds(delay))
                } else {
                    Log.error("All \(maxAttempts) retry attempts exhausted", category: .general)
                }
            } catch {
                // Non-AIError, don't retry
                Log.error("Non-retryable error encountered",
                    category: .general,
                    metadata: ["error": error.localizedDescription]
                )
                throw error
            }
        }

        throw lastError ?? NSError(
            domain: "RecipeGeneration",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "All retry attempts failed"]
        )
    }

    // MARK: - Helper Methods

    private func parseIngredients(_ ingredientsString: String?) -> [String]? {
        guard let ingredients = ingredientsString,
              !ingredients.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return ingredients
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func extractDishName(from transcript: String) -> String {
        // Simple extraction - look for patterns like "make me a [dish]"
        // TODO: Could use AI to extract more intelligently
        let lowercased = transcript.lowercased()

        // Common patterns
        let patterns = [
            "recipe for ",
            "make me a ",
            "make me ",
            "make a ",
            "how to make ",
            "i want to make "
        ]

        for pattern in patterns {
            if let range = lowercased.range(of: pattern) {
                let afterPattern = String(transcript[range.upperBound...])
                // Take up to the first period or end
                if let endRange = afterPattern.range(of: ".") {
                    return String(afterPattern[..<endRange.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .capitalized
                }
                return afterPattern
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .capitalized
            }
        }

        // Fallback: use first few words
        let words = transcript.components(separatedBy: .whitespaces)
        return words.prefix(3).joined(separator: " ").capitalized
    }

    private func addToCollection(_ recipe: Recipe, context: ModelContext) async {
        do {
            // Try to find existing "Generated Recipes" collection
            let descriptor = FetchDescriptor<RecipeCollection>(
                predicate: #Predicate { $0.name == "Generated Recipes" }
            )

            let collection: RecipeCollection
            if let existing = try context.fetch(descriptor).first {
                collection = existing
            } else {
                // Create new collection
                collection = RecipeCollection(
                    name: "Generated Recipes",
                    iconName: "wand.and.stars",
                    collectionType: .userCreated
                )
                context.insert(collection)
            }

            // Add recipe to collection
            if collection.recipes == nil {
                collection.recipes = []
            }
            if !collection.recipes!.contains(where: { $0.id == recipe.id }) {
                collection.recipes!.append(recipe)
            }

            try context.save()

        } catch {
            Log.error("Failed to add recipe to collection", category: .general, metadata: [
                "error": error.localizedDescription
            ])
        }
    }

    private func syncToFirebase(_ recipe: Recipe) async {
        // Only sync if Firebase is active
        guard ServiceContainer.shared.resolve(BackendConfig.self).isFirebaseActive else {
            return
        }

        do {
            let firebaseSync = ServiceContainer.shared.resolve((any FirebaseRecipeSyncProtocol).self)
            try await firebaseSync.uploadRecipe(recipe)
            Log.info("AI-generated recipe synced to Firebase", category: .firebase, metadata: [
                "title": recipe.title
            ])
        } catch {
            Log.warning("Failed to sync AI-generated recipe to Firebase", category: .firebase, metadata: [
                "error": error.localizedDescription
            ])
            // Don't fail the entire operation if sync fails
        }
    }

    // MARK: - Silly Recipe Helpers

    /// 🎲 Add disclaimers and warnings to silly Easter egg recipes
    private func addSillyRecipeDisclaimers(to recipe: Recipe) {
        // Add disclaimer to beginning of instructions
        let disclaimer = "⚠️ DISCLAIMER: This is a silly, randomly-generated recipe for entertainment purposes only. We do NOT recommend actually cooking or eating this!"

        if recipe.instructions.isEmpty {
            recipe.instructions.append(disclaimer)
        } else {
            recipe.instructions.insert(disclaimer, at: 0)
        }

        // Add warning note to back of card
        let warningNote = "🎲 This recipe was randomly generated as a fun Easter egg. It may contain unusual or bizarre ingredient combinations inspired by vintage recipe trends. Please don't actually make this!"
        recipe.notes = (recipe.notes?.isEmpty ?? true) ? warningNote : "\(warningNote)\n\n\(recipe.notes!)"

        Log.info("Added silly recipe disclaimers", category: .general, metadata: [
            "title": recipe.title
        ])
    }
}
