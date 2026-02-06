//
//  RecipeGenerationService.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-02.
//

import Foundation
import SwiftData
import UIKit

/// Service managing recipe generation with progress tracking and retry logic
/// Uses placeholder pattern for unified UX - recipes appear in list immediately
@MainActor
final class RecipeGenerationService: ObservableObject {
    // MARK: - Published State

    @Published private(set) var activeJob: RecipeGenerationJob?

    // MARK: - Dependencies

    private let aiGenerator: AIRecipeGeneratorProtocol
    private let imageGenerator: RecipeImageGeneratorProtocol
    private let aiService: AIServiceProtocol
    private let aiConfiguration: AIConfigurationProtocol
    internal var context: ModelContext?

    // MARK: - Initialization

    init(
        aiGenerator: AIRecipeGeneratorProtocol,
        imageGenerator: RecipeImageGeneratorProtocol,
        aiService: AIServiceProtocol,
        aiConfiguration: AIConfigurationProtocol
    ) {
        self.aiGenerator = aiGenerator
        self.imageGenerator = imageGenerator
        self.aiService = aiService
        self.aiConfiguration = aiConfiguration
    }

    // MARK: - Public API

    /// Generate a recipe from dish name and optional ingredients
    /// Creates placeholder immediately for unified UX (appears in recipe list)
    func generateRecipe(
        dishName: String,
        ingredients: String?,
        context: ModelContext,
        targetCollection: RecipeCollection? = nil
    ) async throws {
        self.context = context

        // Create job with target collection ID if provided
        let job = RecipeGenerationJob(
            dishName: dishName,
            ingredients: ingredients,
            targetCollectionId: targetCollection?.id
        )
        context.insert(job)

        // UNIFIED UX: Create placeholder recipe immediately (appears in recipe list)
        let placeholder = Recipe.createGenerationPlaceholder(
            jobId: job.id,
            dishName: dishName,
            isVoiceDictation: false,
            isSillyRecipe: false
        )
        context.insert(placeholder)
        job.placeholderRecipeId = placeholder.id

        // Add placeholder to target collection immediately
        if let collection = targetCollection {
            if collection.recipes == nil { collection.recipes = [] }
            collection.recipes?.append(placeholder)
        }

        try context.save()

        // Set as active (for any remaining banner display during transition)
        self.activeJob = job

        // Process in background
        Task.detached { @MainActor in
            await self.processJob(job, placeholder: placeholder)
        }
    }

    /// Generate a recipe from voice transcript
    /// Creates placeholder immediately for unified UX
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

        // UNIFIED UX: Create placeholder immediately
        let placeholder = Recipe.createGenerationPlaceholder(
            jobId: job.id,
            dishName: "Voice Recipe",
            isVoiceDictation: true,
            isSillyRecipe: false
        )
        context.insert(placeholder)
        job.placeholderRecipeId = placeholder.id

        try context.save()

        self.activeJob = job

        Task.detached { @MainActor in
            await self.processVoiceJob(job, placeholder: placeholder)
        }
    }

    /// 🎲 Easter Egg: Generate a silly/random recipe for fun
    /// Creates placeholder immediately for unified UX
    func generateSillyRecipe(
        context: ModelContext,
        targetCollection: RecipeCollection? = nil
    ) async throws {
        self.context = context

        // Random silly recipe combos (name + absurd ingredients)
        // Expanded to 100 recipes for maximum variety and minimal duplicates
        let sillyRecipes: [(name: String, ingredients: String)] = [
            // Original classics
            ("Jellied Rainbow Surprise", "lime jello, canned tuna, miniature marshmallows, cream cheese, maraschino cherries"),
            ("Spam & Banana Casserole", "canned spam, overripe bananas, mayonnaise, bread crumbs, brown sugar"),
            ("Pickle Juice Smoothie", "dill pickle juice, vanilla ice cream, cucumber, mint leaves, cottage cheese"),
            ("Tuna Jello Salad", "lemon jello, canned tuna, celery, pimentos, hard-boiled eggs"),
            ("Mayonnaise Cake Delight", "mayonnaise, chocolate cake mix, raisins, cream cheese frosting"),
            ("Hot Dog Jello Ring", "strawberry jello, sliced hot dogs, canned pineapple, whipped cream"),
            ("Cheese & Grape Aspic", "unflavored gelatin, cheddar cheese cubes, whole grapes, chicken broth"),
            ("Candied Olive Medley", "black olives, marshmallows, brown sugar, butter, cream cheese"),
            ("Liver Sausage Pineapple", "liver sausage, canned pineapple rings, cream cheese, pecans"),
            ("Tomato Aspic Tower", "tomato juice, unflavored gelatin, cottage cheese, canned shrimp, celery"),

            // Jello/Gelatin disasters
            ("Orange Jello Frankfurter Mold", "orange jello, vienna sausages, celery seed, vinegar, stuffed olives"),
            ("Perfection Salad Supreme", "lemon jello, shredded cabbage, canned peas, pimentos, celery"),
            ("Shrimp & Lime Aspic", "lime jello, canned shrimp, onion, worcestershire sauce, hard-boiled eggs"),
            ("Strawberry Bologna Ring", "strawberry jello, bologna slices, cream cheese, green olives, walnuts"),
            ("Cherry Cola Aspic", "cherry jello, cola, canned fruit cocktail, mini marshmallows, pecans"),
            ("Salmon Mousse Ring", "lemon jello, canned salmon, sour cream, dill pickles, capers"),
            ("Avocado Lime Mold", "lime jello, canned tuna, avocado, mayonnaise, lemon juice"),
            ("Cottage Cheese Crown", "lemon jello, cottage cheese, canned pears, mayonnaise, crushed pineapple"),
            ("Triple Decker Aspic", "three layers: tomato, lemon, lime jello with spam, eggs, and tuna"),
            ("Beet & Horseradish Mold", "raspberry jello, canned beets, horseradish, vinegar, celery"),

            // Canned meat abominations
            ("Deviled Ham Cloud", "deviled ham, cool whip, cream cheese, pimentos, crackers"),
            ("Vienna Sausage Surprise", "vienna sausages, grape jelly, yellow mustard, sauerkraut, rye bread"),
            ("Spam Upside-Down Cake", "spam, brown sugar, pineapple rings, maraschino cherries, cake batter"),
            ("Corned Beef Candy", "canned corned beef, brown sugar, cloves, pineapple juice, ginger ale"),
            ("Potted Meat Frosting", "potted meat, cream cheese, green food coloring, onion powder, crackers"),
            ("Sardine Surprise Pie", "canned sardines, graham cracker crust, mayonnaise, dill pickles, lemon"),
            ("Treet & Marshmallow Bake", "treet luncheon meat, marshmallow fluff, bread crumbs, brown sugar"),
            ("Canned Chicken Candy Canes", "canned chicken, peppermint extract, red food coloring, cream cheese"),
            ("Anchovy Fudge Squares", "anchovies, chocolate chips, condensed milk, walnuts, vanilla"),
            ("Deviled Ham Donuts", "deviled ham, donut batter, sugar glaze, pickle relish, mustard powder"),

            // Unexpected mayonnaise usage
            ("Mayo-Banana Cream Pie", "mayonnaise, bananas, vanilla pudding, graham cracker crust, whipped cream"),
            ("Mayonnaise Fudge", "mayonnaise, cocoa powder, powdered sugar, vanilla extract, walnuts"),
            ("Mayo Ice Cream Float", "mayonnaise, root beer, vanilla ice cream, whipped cream, cherry"),
            ("Miracle Whip Meringue", "miracle whip, egg whites, sugar, vanilla, lemon zest"),
            ("Mayo Peanut Butter Cups", "mayonnaise, peanut butter, chocolate chips, powdered sugar, butter"),
            ("Salad Dressing Cookies", "mayonnaise, chocolate cake mix, chocolate chips, powdered sugar glaze"),
            ("Mayo & Jelly Parfait", "mayonnaise, strawberry jelly, graham crackers, whipped cream, nuts"),
            ("Thousand Island Trifle", "thousand island dressing, angel food cake, canned fruit, cool whip"),
            ("Ranch Cheesecake", "ranch dressing, cream cheese, bacon bits, graham cracker crust, chives"),
            ("Caesar Custard", "caesar dressing, eggs, milk, parmesan, anchovy paste"),

            // Aspic/savory jello
            ("Beef Consommé Mold", "beef consommé gelatin, hard-boiled eggs, peas, carrots, worcestershire"),
            ("Chicken Bouillon Ring", "chicken bouillon gelatin, celery, pimentos, mayonnaise, walnuts"),
            ("Clam Juice Aspic", "clam juice, unflavored gelatin, tabasco, lemon, canned clams"),
            ("V8 Vegetable Tower", "v8 juice, unflavored gelatin, celery, olives, cottage cheese"),
            ("Bloody Mary Aspic", "tomato juice, vodka, unflavored gelatin, celery, hot sauce"),
            ("French Onion Soup Mold", "french onion soup, unflavored gelatin, swiss cheese cubes, croutons"),
            ("Cream of Mushroom Ring", "cream of mushroom soup, gelatin, canned mushrooms, sour cream"),
            ("Beef Tongue Aspic", "beef tongue, beef broth, gelatin, pickled onions, mustard"),
            ("Pork & Beans Mold", "pork and beans, tomato juice, gelatin, bacon bits, brown sugar"),
            ("Minestrone Gelatin Loaf", "minestrone soup, unflavored gelatin, pasta, parmesan cheese"),

            // Sweet & savory combos
            ("Peanut Butter Sardine Surprise", "peanut butter, canned sardines, honey, crackers, pickles"),
            ("Chocolate-Covered Spam", "spam, chocolate chips, coconut flakes, crushed peanuts, butter"),
            ("Maple Bacon Jello", "maple syrup, bacon bits, unflavored gelatin, cinnamon, brown sugar"),
            ("Butterscotch Liver Pâté", "chicken livers, butterscotch chips, cream cheese, brandy, crackers"),
            ("Caramel Onion Rings", "caramel sauce, fried onion rings, powdered sugar, vanilla ice cream"),
            ("Marshmallow Tuna Casserole", "marshmallows, canned tuna, cream of celery soup, potato chips"),
            ("Honey Glazed Anchovies", "anchovies, honey, soy sauce, garlic, sesame seeds"),
            ("Cotton Candy Meatloaf", "ground beef, cotton candy, ketchup, bread crumbs, eggs"),
            ("Fudge & Fish Sticks", "fish sticks, chocolate fudge sauce, tartar sauce, cornflakes"),
            ("Gumdrops & Ground Beef", "ground beef, gumdrops, worcestershire sauce, onion, bread crumbs"),

            // Loaf/ring molds
            ("Rainbow Sandwich Loaf", "white bread, tuna salad, egg salad, ham salad, cream cheese frosting"),
            ("Potato Chip Casserole", "potato chips, canned tuna, cream of mushroom soup, cheese sauce"),
            ("Prune Whip Surprise Mold", "prunes, whipped cream, gelatin, walnuts, shredded carrots"),
            ("Braunschweiger Crown", "braunschweiger, unflavored gelatin, pickle relish, onion, crackers"),
            ("Seven Layer Salad Ring", "lettuce, peas, bacon, cheese, mayo, eggs, onions in jello mold"),
            ("Meat & Fruit Tower", "ground ham, crushed pineapple, brown sugar, cloves, gelatin"),
            ("Frosted Ribbon Loaf", "alternating bread, ham salad, cheese spread, cream cheese frosting"),
            ("Crown Roast of Frankfurters", "hot dogs, mashed potatoes, ketchup, mustard, pineapple rings"),
            ("Savory Cheesecake Ring", "cream cheese, blue cheese, gelatin, walnuts, crackers"),
            ("Stuffed Pickle Loaf", "whole dill pickles, ground meat, cream cheese, gelatin, breadcrumbs"),

            // Vintage casseroles
            ("Baked Bean & Banana Bake", "baked beans, bananas, bacon, brown sugar, mustard powder"),
            ("Pea & Peanut Butter Casserole", "frozen peas, peanut butter, cream of mushroom soup, french fried onions"),
            ("Kidney Bean Cake", "kidney beans, chocolate cake mix, eggs, oil, frosting"),
            ("Sauerkraut Dessert", "sauerkraut, cocoa powder, sugar, flour, eggs"),
            ("Grape-Nuts Ice Cream Loaf", "grape-nuts cereal, vanilla ice cream, marshmallow sauce, cherries"),
            ("Ketchup & Cornflakes Surprise", "ketchup, cornflakes, ground beef, brown sugar, vinegar"),
            ("Ritz Cracker Pie", "ritz crackers, egg whites, sugar, cream of tartar, cool whip"),
            ("Cream Cheese & Olive Bake", "cream cheese, green olives, ham, crescent rolls, paprika"),
            ("Tater Tot Hot Dish Jello", "tater tots, cream of mushroom soup, ground beef, jello topping"),
            ("Noodle Ring with Mystery Center", "egg noodles, cheese sauce, canned fruit cocktail, whipped cream"),

            // Bizarre desserts
            ("Tomato Soup Cake", "tomato soup, cake flour, raisins, cloves, cream cheese frosting"),
            ("Spaghetti Ice Cream", "spaghetti, strawberry sauce, coconut flakes, whipped cream, parmesan"),
            ("Bacon Brittle", "bacon, sugar, corn syrup, baking soda, vanilla extract"),
            ("Pickle Pie", "dill pickles, sugar, cinnamon, pie crust, whipped cream"),
            ("Ramen Candy Bark", "ramen noodles, white chocolate, sprinkles, crushed candy canes"),
            ("Vienna Sausage Truffles", "vienna sausages, cream cheese, chocolate coating, coconut"),
            ("Salmon Gelato", "canned salmon, heavy cream, sugar, vanilla, dill"),
            ("Beet & Chocolate Brownies", "canned beets, brownie mix, cream cheese swirl, powdered sugar"),
            ("Onion Ring Donuts", "onion rings, cinnamon sugar, chocolate glaze, sprinkles"),
            ("Cheese Whiz Fudge", "cheese whiz, powdered sugar, vanilla, cocoa powder, butter"),

            // Processed cheese creations
            ("Velveeta Fudge Fantasy", "velveeta cheese, powdered sugar, cocoa powder, vanilla, pecans"),
            ("Cheese Slice Candy", "american cheese slices, fruit roll-ups, peanut butter, chocolate chips"),
            ("Spray Cheese Soufflé", "spray cheese, eggs, milk, bread cubes, worcestershire sauce"),
            ("Cheese Ball Ice Cream", "cream cheese, powdered sugar, vanilla, pecans, chocolate sauce"),
            ("String Cheese Taffy", "string cheese, marshmallow fluff, butter, vanilla, food coloring"),
            ("Cottage Cheese Candy Salad", "cottage cheese, cool whip, mandarin oranges, candy bars, coconut"),
            ("Nacho Cheese Flan", "nacho cheese sauce, eggs, condensed milk, vanilla, caramel"),
            ("Laughing Cow Lava Cake", "laughing cow cheese, chocolate cake mix, eggs, powdered sugar"),
            ("Babybel Bonbons", "babybel cheese, white chocolate, graham cracker crumbs, sprinkles"),
            ("Government Cheese Pudding", "government cheese, cornstarch, milk, sugar, vanilla"),

            // Fruit + meat combos
            ("Watermelon Ham Steak", "watermelon, ham steak, cloves, brown sugar, pineapple juice"),
            ("Cantaloupe Meat Cups", "cantaloupe halves, tuna salad, cottage cheese, maraschino cherries"),
            ("Prune & Bacon Delight", "prunes, bacon, cream cheese, powdered sugar, toothpicks"),
            ("Peach & Braunschweiger Melts", "canned peaches, braunschweiger, white bread, butter, cinnamon sugar")
        ]

        let silly = sillyRecipes.randomElement() ?? (name: "Mystery Recipe", ingredients: "mystery ingredients")

        // Create job with silly flag and absurd ingredients, include target collection if specified
        let job = RecipeGenerationJob(
            dishName: silly.name,
            ingredients: silly.ingredients,
            targetCollectionId: targetCollection?.id
        )
        job.isSillyRecipe = true  // Mark as silly for sharing restrictions
        context.insert(job)

        // UNIFIED UX: Create placeholder immediately
        let placeholder = Recipe.createGenerationPlaceholder(
            jobId: job.id,
            dishName: silly.name,
            isVoiceDictation: false,
            isSillyRecipe: true
        )
        context.insert(placeholder)
        job.placeholderRecipeId = placeholder.id

        // Add placeholder to target collection immediately
        if let collection = targetCollection {
            if collection.recipes == nil { collection.recipes = [] }
            collection.recipes?.append(placeholder)
        }

        try context.save()

        self.activeJob = job

        Task.detached { @MainActor in
            await self.processJob(job, placeholder: placeholder)  // Process with absurd ingredients
        }
    }

    // MARK: - Job Processing

    private func processJob(_ job: RecipeGenerationJob, placeholder: Recipe) async {
        guard let context = context else {
            Log.error("ModelContext not available", category: .general)
            placeholder.markProcessingFailed(errorMessage: "ModelContext not available")
            self.activeJob = nil
            return
        }

        do {
            // Transition from pending to processing
            job.status = .processing

            // Phase 1: Analyzing (20%)
            job.currentPhase = .analyzing
            placeholder.processingProgress = 0.2
            try context.save()

            // Parse ingredients
            let ingredientList = parseIngredients(job.ingredients)

            // Phase 2: Extracting (50%)
            job.currentPhase = .extracting
            placeholder.processingProgress = 0.5
            try context.save()

            // Generate recipe with retry logic
            let generatedRecipe = try await withRetry(maxAttempts: 3) {
                try await self.aiGenerator.generateRecipe(
                    dishName: job.dishName,
                    ingredients: ingredientList,
                    context: context
                )
            }

            // 🎲 Easter Egg: Add silly recipe disclaimers
            if job.isSillyRecipe {
                addSillyRecipeDisclaimers(to: generatedRecipe)
            }

            // Phase 3: Enriching (80%)
            job.currentPhase = .enriching
            placeholder.processingProgress = 0.8
            try context.save()

            // Copy ingredients from generated recipe to placeholder BEFORE image generation
            // This ensures the image prompt has access to ingredients (important for silly recipes!)
            if let generatedIngredients = generatedRecipe.ingredients {
                placeholder.ingredients = []
                for ingredient in generatedIngredients {
                    let newIngredient = Ingredient()
                    newIngredient.name = ingredient.name
                    newIngredient.quantity = ingredient.quantity
                    newIngredient.unit = ingredient.unit
                    newIngredient.preparation = ingredient.preparation
                    newIngredient.originalText = ingredient.originalText
                    newIngredient.recipe = placeholder
                    placeholder.ingredients?.append(newIngredient)
                }
            }

            // Generate image for placeholder (blocking, soft failure)
            // Now has access to ingredients for better image prompts
            do {
                try await self.imageGenerator.generateAndSaveImage(for: placeholder)
                Log.info("Recipe image generated successfully", category: .general)
            } catch {
                Log.error("Failed to generate image for recipe", category: .general, metadata: [
                    "error": error.localizedDescription
                ])
                // Continue without image
            }

            // UNIFIED UX: Update placeholder with generated recipe data
            placeholder.updateFromProcessingResult(
                title: generatedRecipe.title,
                instructions: generatedRecipe.instructions,
                servings: generatedRecipe.servings,
                prepTime: generatedRecipe.prepTime,
                cookTime: generatedRecipe.cookTime,
                notes: generatedRecipe.notes,
                imageFileName: placeholder.imageFileName  // Keep the generated image
            )

            // Mark as AI generated
            placeholder.aiGenerated = true

            // Add to target collection if not already added, or default "Generated Recipes"
            await addToCollection(placeholder, context: context, targetCollectionId: job.targetCollectionId)

            // Delete the temporary generated recipe (we only need the placeholder)
            context.delete(generatedRecipe)

            // Save
            try context.save()

            // Sync placeholder to Firebase (soft failure, non-blocking)
            Task {
                await syncToFirebase(placeholder)
            }

            // Phase 4: Complete
            job.currentPhase = .complete
            job.status = .completed
            job.completedAt = Date()
            try context.save()

            // Clear active job (no need for auto-dismiss delay with placeholder pattern)
            self.activeJob = nil

        } catch {
            // UNIFIED UX: Mark placeholder as failed
            placeholder.markProcessingFailed(errorMessage: error.localizedDescription)
            job.status = .failed
            job.error = error.localizedDescription
            try? context.save()

            Log.error("Recipe generation failed", category: .general, metadata: [
                "dishName": job.dishName,
                "error": error.localizedDescription
            ])

            self.activeJob = nil
        }
    }

    private func processVoiceJob(_ job: RecipeGenerationJob, placeholder: Recipe) async {
        guard let context = context,
              let transcript = job.transcript else {
            Log.error("Missing context or transcript for voice job", category: .general)
            placeholder.markProcessingFailed(errorMessage: "Missing transcript")
            self.activeJob = nil
            return
        }

        do {
            // Transition from pending to processing
            job.status = .processing

            // Phase 1: Analyzing — AI-powered transcript analysis with naive fallback
            job.currentPhase = .analyzing
            placeholder.processingProgress = 0.2
            try context.save()

            let transcriptCtx = await analyzeTranscript(transcript)

            let dishName: String
            let ingredientList: [String]?
            let usableContext: VoiceTranscriptContext?

            if let ctx = transcriptCtx, ctx.confidence >= 0.3 {
                dishName = ctx.dishName
                ingredientList = ctx.ingredients
                usableContext = ctx
                Log.info("Using AI transcript analysis", category: .general, metadata: [
                    "dishName": dishName,
                    "confidence": ctx.confidence
                ])
            } else {
                // Fallback to naive extraction
                dishName = extractDishName(from: transcript)
                ingredientList = nil
                usableContext = nil
                Log.info("Falling back to naive dish name extraction", category: .general, metadata: [
                    "dishName": dishName
                ])
            }

            job.dishName = dishName

            // Update placeholder title from generic "Voice Recipe" to actual dish name
            placeholder.title = dishName

            // Phase 2: Extracting
            job.currentPhase = .extracting
            placeholder.processingProgress = 0.5
            try context.save()

            // Generate recipe with retry logic, passing transcript context
            let generatedRecipe = try await withRetry(maxAttempts: 3) {
                try await self.aiGenerator.generateRecipe(
                    dishName: dishName,
                    ingredients: ingredientList,
                    context: context,
                    transcriptContext: usableContext
                )
            }

            // Phase 3: Enriching
            job.currentPhase = .enriching
            placeholder.processingProgress = 0.8
            try context.save()

            // Copy ingredients BEFORE image generation for better prompts
            if let generatedIngredients = generatedRecipe.ingredients {
                placeholder.ingredients = []
                for ingredient in generatedIngredients {
                    let newIngredient = Ingredient()
                    newIngredient.name = ingredient.name
                    newIngredient.quantity = ingredient.quantity
                    newIngredient.unit = ingredient.unit
                    newIngredient.preparation = ingredient.preparation
                    newIngredient.originalText = ingredient.originalText
                    newIngredient.recipe = placeholder
                    placeholder.ingredients?.append(newIngredient)
                }
            }

            // Generate image for placeholder (blocking, soft failure)
            // Now has access to ingredients for better image prompts
            do {
                try await self.imageGenerator.generateAndSaveImage(for: placeholder)
                Log.info("Voice recipe image generated successfully", category: .general)
            } catch {
                Log.error("Failed to generate image", category: .general, metadata: [
                    "error": error.localizedDescription
                ])
                // Continue without image
            }

            // UNIFIED UX: Update placeholder with generated recipe data
            placeholder.updateFromProcessingResult(
                title: generatedRecipe.title,
                instructions: generatedRecipe.instructions,
                servings: generatedRecipe.servings,
                prepTime: generatedRecipe.prepTime,
                cookTime: generatedRecipe.cookTime,
                notes: generatedRecipe.notes,
                imageFileName: placeholder.imageFileName
            )

            // Mark as voice dictated
            placeholder.aiGenerated = true
            placeholder.voiceDictated = true

            // Add to "Generated Recipes" collection
            await addToCollection(placeholder, context: context)

            // Delete temporary generated recipe
            context.delete(generatedRecipe)

            // Save
            try context.save()

            // Sync to Firebase (soft failure, non-blocking)
            Task {
                await syncToFirebase(placeholder)
            }

            // Phase 4: Complete
            job.currentPhase = .complete
            job.status = .completed
            job.completedAt = Date()
            try context.save()

            // Clear active job
            self.activeJob = nil

        } catch {
            // UNIFIED UX: Mark placeholder as failed
            placeholder.markProcessingFailed(errorMessage: error.localizedDescription)
            job.status = .failed
            job.error = error.localizedDescription
            try? context.save()

            Log.error("Voice recipe generation failed", category: .general, metadata: [
                "error": error.localizedDescription
            ])

            self.activeJob = nil
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

    /// Analyze a voice transcript using AI to extract structured recipe context.
    /// Returns nil on failure so callers can fall back to naive extraction.
    private func analyzeTranscript(_ transcript: String) async -> VoiceTranscriptContext? {
        let prompt = """
        Analyze this voice transcript from someone describing a recipe they want to make.
        Extract structured information about the dish they're describing.

        Transcript: "\(transcript)"

        Return JSON with:
        - dishName (string): The primary dish name
        - ingredients (array of strings, optional): Specific ingredients mentioned
        - cuisineHints (array of strings, optional): Cuisine or regional style hints (e.g., "Southern", "Italian")
        - descriptions (array of strings, optional): Descriptive qualities (e.g., "creamy", "crispy", "light")
        - techniquePreferences (array of strings, optional): Cooking techniques mentioned (e.g., "slow-cooked", "grilled")
        - servingSize (string, optional): Serving size if mentioned (e.g., "6 people")
        - additionalContext (string, optional): Any other relevant context
        - confidence (number 0.0-1.0): How confident you are in the extraction
        """

        let options = AICompletionOptions(
            model: aiConfiguration.model(for: .parsing),
            temperature: 0.3,
            maxTokens: 512,
            systemMessage: """
            You are a precise transcript parser. Extract structured recipe information from voice transcripts.
            Return ONLY valid JSON matching the exact schema. Do not wrap in markdown code blocks.
            If the transcript is unclear or garbled, set confidence low and extract what you can.
            """
        )

        do {
            let result: VoiceTranscriptContext = try await aiService.completeStructured(
                prompt: prompt,
                schema: VoiceTranscriptContext.self,
                options: options
            )
            Log.info("Transcript analysis complete", category: .general, metadata: [
                "dishName": result.dishName,
                "confidence": result.confidence,
                "hasIngredients": result.ingredients != nil,
                "hasCuisineHints": result.cuisineHints != nil
            ])
            return result
        } catch {
            Log.warning("Transcript analysis failed, will fall back to naive extraction", category: .general, metadata: [
                "error": error.localizedDescription
            ])
            return nil
        }
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

    private func addToCollection(_ recipe: Recipe, context: ModelContext, targetCollectionId: UUID? = nil) async {
        do {
            let collection: RecipeCollection

            // If target collection specified, use it; otherwise use "Generated Recipes"
            if let targetId = targetCollectionId {
                let targetDescriptor = FetchDescriptor<RecipeCollection>(
                    predicate: #Predicate { $0.id == targetId }
                )
                if let targetCollection = try context.fetch(targetDescriptor).first {
                    collection = targetCollection
                    Log.info("Adding generated recipe to target collection", category: .general, metadata: [
                        "collection": collection.name
                    ])
                } else {
                    // Fallback to "Generated Recipes" if target not found
                    collection = try findOrCreateGeneratedRecipesCollection(context: context)
                }
            } else {
                // Default: use "Generated Recipes" collection
                collection = try findOrCreateGeneratedRecipesCollection(context: context)
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

    private func findOrCreateGeneratedRecipesCollection(context: ModelContext) throws -> RecipeCollection {
        let descriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { $0.name == "Generated Recipes" }
        )

        if let existing = try context.fetch(descriptor).first {
            // Ensure preset background is set (migration for existing collections)
            if existing.customBackgroundImagePath == nil && UIImage(named: "generated-recipes-bg") != nil {
                existing.customBackgroundImagePath = "preset-generated-recipes-bg"
                existing.useCustomBackground = true
                Log.info("Updated Generated Recipes collection with preset background", category: .general)
            }
            return existing
        } else {
            // Create new collection with preset background
            let collection = RecipeCollection(
                name: "Generated Recipes",
                description: "AI-created recipes",
                iconName: "wand.and.stars",
                color: "#9B59B6", // Purple for AI/magic theme
                isSystemCollection: false,
                isAllRecipes: false,
                collectionType: .userCreated
            )
            // Set preset background if available
            if UIImage(named: "generated-recipes-bg") != nil {
                collection.customBackgroundImagePath = "preset-generated-recipes-bg"
                collection.useCustomBackground = true
            }
            context.insert(collection)
            Log.info("Created Generated Recipes collection", category: .general)
            return collection
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
