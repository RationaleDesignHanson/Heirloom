//
//  RecipeGeneratorView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//

import SwiftUI
import SwiftData

/// Input form for AI recipe generation or manual recipe entry
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

    // Manual entry fields
    @State private var servings: String = ""
    @State private var prepTime: String = ""
    @State private var cookTime: String = ""
    @State private var ingredientInputs: [String] = [""]
    @State private var instructions: [String] = [""]
    @State private var notes: String = ""

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
                            Text(useManualEntry ? "Enter your recipe details below" : "AI will generate a complete recipe")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        }
                    }
                    .tint(HeirloomColors.tomato)
                }

                // Title section
                Section {
                    TextField("Dish name (e.g., Chicken Parmesan)", text: $dishName)
                        .textContentType(.none)
                        .autocapitalization(.words)
                } header: {
                    Text(useManualEntry ? "Recipe Title" : "What would you like to make?")
                } footer: {
                    if !useManualEntry {
                        Text("Enter the name of a dish you want to create")
                    }
                }

                if useManualEntry {
                    manualEntryFields
                } else {
                    // AI generation: optional ingredients hint
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
                    let hasInput = !dishName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                   !ingredients.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                    Button {
                        if useManualEntry {
                            createManualRecipe()
                        } else {
                            startBackgroundGeneration()
                        }
                    } label: {
                        Text(useManualEntry ? "Create" : "Done")
                            .fontWeight(.semibold)
                            .foregroundStyle(hasInput || !useManualEntry ? HeirloomColors.familyGreen : HeirloomColors.secondaryText.opacity(0.5))
                    }
                    .disabled(useManualEntry && dishName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - Manual Entry Fields

    @ViewBuilder
    private var manualEntryFields: some View {
        // Cooking info
        Section("Cooking Info") {
            HStack {
                Text("Servings")
                    .font(HeirloomFonts.body)
                Spacer()
                TextField("4", text: $servings)
                    .font(HeirloomFonts.body)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .frame(width: 100)
            }

            HStack {
                Text("Prep Time")
                    .font(HeirloomFonts.body)
                Spacer()
                TextField("15 min", text: $prepTime)
                    .font(HeirloomFonts.body)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }

            HStack {
                Text("Cook Time")
                    .font(HeirloomFonts.body)
                Spacer()
                TextField("30 min", text: $cookTime)
                    .font(HeirloomFonts.body)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }
        }

        // Ingredients
        Section {
            ForEach(ingredientInputs.indices, id: \.self) { index in
                TextField("e.g., 2 cups flour", text: $ingredientInputs[index])
                    .font(HeirloomFonts.body)
                    .autocapitalization(.none)
                    .onSubmit {
                        if index == ingredientInputs.count - 1 {
                            ingredientInputs.append("")
                        }
                    }
            }
            .onDelete { indexSet in
                guard ingredientInputs.count > 1 else { return }
                ingredientInputs.remove(atOffsets: indexSet)
            }

            Button {
                ingredientInputs.append("")
            } label: {
                Label("Add Ingredient", systemImage: "plus.circle.fill")
                    .font(HeirloomFonts.body)
            }
        } header: {
            Text("Ingredients")
        }

        // Instructions
        Section {
            ForEach(instructions.indices, id: \.self) { index in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))
                        .frame(width: 25, alignment: .leading)

                    TextField("Step description", text: $instructions[index], axis: .vertical)
                        .font(HeirloomFonts.body)
                        .lineLimit(3...10)
                        .onSubmit {
                            if index == instructions.count - 1 {
                                instructions.append("")
                            }
                        }
                }
            }
            .onDelete { indexSet in
                guard instructions.count > 1 else { return }
                instructions.remove(atOffsets: indexSet)
            }

            Button {
                instructions.append("")
            } label: {
                Label("Add Step", systemImage: "plus.circle.fill")
                    .font(HeirloomFonts.body)
            }
        } header: {
            Text("Instructions")
        }

        // Notes
        Section("Notes") {
            TextField("Add any notes or tips...", text: $notes, axis: .vertical)
                .font(HeirloomFonts.body)
                .lineLimit(3...10)
        }
    }

    // MARK: - Manual Entry

    private func createManualRecipe() {
        let recipeDishName = dishName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Filter empty entries
        let filteredInstructions = instructions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let filteredIngredientTexts = ingredientInputs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Create recipe with all fields
        let recipe = Recipe(
            title: recipeDishName.isEmpty ? "New Recipe" : recipeDishName,
            sourceType: .manual,
            instructions: filteredInstructions
        )

        // Set optional fields
        let trimmedServings = servings.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedServings.isEmpty { recipe.servings = trimmedServings }

        let trimmedPrep = prepTime.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPrep.isEmpty { recipe.prepTime = trimmedPrep }

        let trimmedCook = cookTime.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCook.isEmpty { recipe.cookTime = trimmedCook }

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty { recipe.setNotes(trimmedNotes) }

        // Parse ingredients
        if !filteredIngredientTexts.isEmpty {
            var parsedIngredients: [Ingredient] = []
            for (index, text) in filteredIngredientTexts.enumerated() {
                let parsed = IngredientParser.parse(text)
                let ingredient = Ingredient(
                    originalText: text,
                    name: parsed.name,
                    quantity: parsed.quantity,
                    unit: parsed.unit,
                    orderIndex: index
                )
                ingredient.quantityMax = parsed.quantityMax
                parsedIngredients.append(ingredient)
            }
            recipe.ingredients = parsedIngredients
        }

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
            let hasContent = !filteredIngredientTexts.isEmpty || !filteredInstructions.isEmpty
            toastManager.success(
                title: "Recipe created",
                message: hasContent ? nil : "Tap to add more details"
            )
        } catch {
            toastManager.error(title: "Failed to create recipe")
            Log.error("Failed to create manual recipe", category: .general, error: error)
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
