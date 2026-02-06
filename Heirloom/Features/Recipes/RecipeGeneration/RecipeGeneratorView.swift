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

    /// Target collection to add generated recipe to (overrides default routing when user initiates from a specific collection)
    let targetCollection: RecipeCollection?

    init(targetCollection: RecipeCollection? = nil) {
        self.targetCollection = targetCollection
    }

    @State private var dishName: String = ""
    @State private var ingredients: String = ""
    @State private var errorMessage: String?
    @State private var useManualEntry: Bool = false

    private var generationService: RecipeGenerationService {
        ServiceContainer.shared.resolve(RecipeGenerationService.self)
    }
    private var toastManager: ToastManager {
        ServiceContainer.shared.resolve(ToastManager.self)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Mode toggle
                Section {
                    Toggle(isOn: $useManualEntry) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Manual Entry")
                                .font(HeirloomFonts.body)
                            Text(useManualEntry ? "Create a blank recipe to fill in yourself" : "AI will generate a complete recipe")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        }
                    }
                    .tint(HeirloomColors.tomato)
                }

                Section {
                    TextField("Dish name (e.g., Chicken Parmesan)", text: $dishName)
                        .textContentType(.none)
                        .autocapitalization(.words)
                } header: {
                    Text("What would you like to make?")
                } footer: {
                    Text(useManualEntry ? "This will be the title of your recipe" : "Enter the name of a dish you want to create")
                }

                if !useManualEntry {
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
            .navigationTitle(useManualEntry ? "New Recipe" : "Generate Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    // For manual entry: require dish name
                    // For AI generation: Easter egg - button looks inactive when fields are empty,
                    // but tapping it still works and generates a random "silly" recipe.
                    let hasInput = !dishName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                   !ingredients.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                    Button {
                        if useManualEntry {
                            createBlankRecipe()
                        } else {
                            startBackgroundGeneration()
                        }
                    } label: {
                        Text(useManualEntry ? "Create" : "Done")
                            .fontWeight(.semibold)
                            .foregroundStyle(hasInput || !useManualEntry ? HeirloomColors.familyGreen : HeirloomColors.secondaryText.opacity(0.5))
                    }
                    // For manual entry, disabled without dish name
                    // For AI generation, never actually disabled - easter egg always works
                    .disabled(useManualEntry && dishName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - Manual Entry

    private func createBlankRecipe() {
        let recipeDishName = dishName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Create a blank recipe with just the title
        let recipe = Recipe(
            title: recipeDishName.isEmpty ? "New Recipe" : recipeDishName,
            sourceType: .manual,
            instructions: []
        )

        // Insert into context
        modelContext.insert(recipe)

        // Route to collection
        let router = CollectionRouter(modelContext: modelContext)
        if let collection = targetCollection {
            router.routeToSpecificCollection(recipe, collection: collection)
        }

        // Save
        do {
            try modelContext.save()
            toastManager.success(
                title: "Recipe created",
                message: "Tap to add ingredients and instructions"
            )
        } catch {
            toastManager.error(title: "Failed to create recipe")
            Log.error("Failed to create blank recipe", category: .general, error: error)
        }

        dismiss()
    }

    // MARK: - AI Generation

    private func startBackgroundGeneration() {
        let recipeDishName = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        let recipeIngredients = ingredients.trimmingCharacters(in: .whitespacesAndNewlines)

        // Dismiss immediately (cookbook scan pattern)
        dismiss()

        Task { @MainActor in
            do {
                // Easter egg: Generate silly recipe if both fields empty
                if recipeDishName.isEmpty && recipeIngredients.isEmpty {
                    try await generationService.generateSillyRecipe(
                        context: modelContext,
                        targetCollection: targetCollection
                    )
                } else {
                    // Normal generation
                    try await generationService.generateRecipe(
                        dishName: recipeDishName,
                        ingredients: recipeIngredients.isEmpty ? nil : recipeIngredients,
                        context: modelContext,
                        targetCollection: targetCollection
                    )
                }

                // Progress UI shows automatically via bottom banner

            } catch {
                toastManager.error(title: "Failed to start generation")
                Log.error("Failed to create generation job", category: .general, error: error)
            }
        }
    }
}
