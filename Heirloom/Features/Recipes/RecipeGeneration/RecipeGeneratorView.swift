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
                        Task {
                            await generateRecipe()
                        }
                    } label: {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Text("Generate")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(dishName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                }
            }
            .navigationDestination(item: $generatedRecipe) { recipe in
                GeneratedRecipePreviewView(
                    recipe: recipe,
                    onSave: {
                        dismiss()
                    },
                    onRegenerate: {
                        generatedRecipe = nil
                    }
                )
            }
        }
    }

    // MARK: - Generation

    @MainActor
    private func generateRecipe() async {
        errorMessage = nil
        isGenerating = true

        defer {
            isGenerating = false
        }

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
                Log.error("Failed to generate image for recipe", category: .ai, metadata: [
                    "error": error.localizedDescription
                ])
                // Continue without image - user can add one later
            }

            // Show preview
            generatedRecipe = recipe

        } catch let error as ImageGenerationError {
            errorMessage = error.errorDescription
        } catch AIError.notConfigured(let provider) {
            errorMessage = "API key not configured for \(provider). Please add your API key in Settings."
        } catch AIError.quotaExceeded(let provider, let limit, _) {
            errorMessage = "Daily limit of \(limit) requests exceeded for \(provider). Please try again tomorrow or add your own API key in Settings."
        } catch {
            errorMessage = "Failed to generate recipe: \(error.localizedDescription)"
        }
    }
}
