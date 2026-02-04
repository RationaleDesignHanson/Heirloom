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
    @State private var errorMessage: String?

    private var generationService: RecipeGenerationService {
        ServiceContainer.shared.resolve(RecipeGenerationService.self)
    }
    private var toastManager: ToastManager {
        ServiceContainer.shared.resolve(ToastManager.self)
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
                    // Easter egg: Button looks inactive when fields are empty, but tapping
                    // it still works and generates a random "silly" recipe.
                    // Once text is entered, button becomes visually active.
                    let hasInput = !dishName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                   !ingredients.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                    Button {
                        startBackgroundGeneration()
                    } label: {
                        Text("Done")
                            .fontWeight(.semibold)
                            .foregroundStyle(hasInput ? HeirloomColors.familyGreen : HeirloomColors.secondaryText.opacity(0.5))
                    }
                    // Never actually disabled - easter egg always works
                }
            }
        }
    }

    // MARK: - Generation

    private func startBackgroundGeneration() {
        let recipeDishName = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        let recipeIngredients = ingredients.trimmingCharacters(in: .whitespacesAndNewlines)

        // Dismiss immediately (cookbook scan pattern)
        dismiss()

        Task { @MainActor in
            do {
                // Easter egg: Generate silly recipe if both fields empty
                if recipeDishName.isEmpty && recipeIngredients.isEmpty {
                    try await generationService.generateSillyRecipe(context: modelContext)
                } else {
                    // Normal generation
                    try await generationService.generateRecipe(
                        dishName: recipeDishName,
                        ingredients: recipeIngredients.isEmpty ? nil : recipeIngredients,
                        context: modelContext
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
