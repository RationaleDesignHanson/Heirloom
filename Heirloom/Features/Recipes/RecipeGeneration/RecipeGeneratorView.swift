//
//  RecipeGeneratorView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//

import SwiftUI
import SwiftData

/// Simple input form for AI recipe generation
struct RecipeGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var dishName: String = ""
    @State private var ingredients: String = ""
    @State private var isGenerating: Bool = false
    @State private var generatedRecipe: Recipe?
    @State private var errorMessage: String?

    private let generator: AIRecipeGeneratorProtocol
    private let imageGenerator: RecipeImageGeneratorProtocol
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }

    init(generator: AIRecipeGeneratorProtocol, imageGenerator: RecipeImageGeneratorProtocol) {
        self.generator = generator
        self.imageGenerator = imageGenerator
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Dish name (e.g., Chicken Parmesan)", text: $dishName)
                        .textContentType(.none)
                        .autocapitalization(.words)
                } header: {
                    Text("What would you like to make?")
                } footer: {
                    Text("Enter the name of a dish you want to create")
                }

                Section {
                    TextEditor(text: $ingredients)
                        .frame(minHeight: 100)
                        .autocapitalization(.none)
                        .textContentType(.none)
                } header: {
                    Text("Key Ingredients (Optional)")
                } footer: {
                    Text("List any specific ingredients you'd like to use, separated by commas")
                }

                if let errorMessage = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .font(HeirloomFonts.body)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Generate Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        startBackgroundGeneration()
                    } label: {
                        Text("Generate")
                            .fontWeight(.semibold)
                    }
                    .disabled(dishName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - Helpers

    private func findOrCreateGeneratedRecipesCollection() -> RecipeCollection {
        // Try to find existing "Generated Recipes" collection
        let descriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { $0.name == "Generated Recipes" }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        // Create new collection
        let collection = RecipeCollection(
            name: "Generated Recipes",
            iconName: "wand.and.stars",
            collectionType: .userCreated
        )
        modelContext.insert(collection)
        return collection
    }

    // MARK: - Generation

    private func startBackgroundGeneration() {
        // Capture current input values
        let recipeDishName = dishName
        let recipeIngredients = ingredients

        // Show toast and dismiss immediately
        toastManager.show(type: .info, title: "Generating \(recipeDishName)...")
        dismiss()

        // Generate in background
        Task.detached { @MainActor in
            await self.generateRecipeInBackground(
                dishName: recipeDishName,
                ingredients: recipeIngredients
            )
        }
    }

    @MainActor
    private func generateRecipeInBackground(dishName: String, ingredients: String) async {
        do {
            // Parse ingredients if provided
            let ingredientList: [String]?
            if ingredients.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ingredientList = nil
            } else {
                ingredientList = ingredients
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }

            // Generate recipe
            let recipe = try await generator.generateRecipe(
                dishName: dishName,
                ingredients: ingredientList,
                context: modelContext
            )

            // Generate image (non-blocking if fails)
            do {
                try await imageGenerator.generateAndSaveImage(for: recipe)
            } catch {
                Log.error("Failed to generate image for recipe", category: .general, metadata: [
                    "error": error.localizedDescription
                ])
                // Continue without image - user can add one later
            }

            // Find or create "Generated Recipes" collection
            let collection = findOrCreateGeneratedRecipesCollection()

            // Add recipe to collection
            if collection.recipes == nil {
                collection.recipes = []
            }
            if !collection.recipes!.contains(where: { $0.id == recipe.id }) {
                collection.recipes!.append(recipe)
            }

            // Save context
            try modelContext.save()

            // Sync to Firebase if active
            if ServiceContainer.shared.resolve(BackendConfig.self).isFirebaseActive {
                do {
                    let firebaseSync = ServiceContainer.shared.resolve(FirebaseRecipeSyncProtocol.self)
                    try await firebaseSync.uploadRecipe(recipe)
                    Log.info("AI-generated recipe synced to Firebase", category: .firebase, metadata: ["title": recipe.title])
                } catch {
                    Log.warning("Failed to sync AI-generated recipe to Firebase", category: .firebase, metadata: ["error": error.localizedDescription])
                    // Don't fail the entire operation if sync fails
                }
            }

            // Show success toast
            toastManager.show(type: .success, title: "✨ \(recipe.title) is ready!")

        } catch let error as ImageGenerationError {
            toastManager.show(type: .error, title: error.errorDescription ?? "Image generation failed")
        } catch AIError.notConfigured(let provider) {
            toastManager.show(type: .error, title: "API key not configured for \(provider)")
        } catch AIError.quotaExceeded(_, let limit, _) {
            toastManager.show(type: .error, title: "Daily limit of \(String(describing: limit)) requests exceeded")
        } catch {
            toastManager.show(type: .error, title: "Failed to generate recipe")
        }
    }
}
