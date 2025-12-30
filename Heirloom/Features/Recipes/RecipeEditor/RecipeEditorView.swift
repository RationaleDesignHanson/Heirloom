import SwiftUI
import SwiftData
import PhotosUI

struct RecipeEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var recipe: Recipe
    @State private var isNewRecipe: Bool
    @State private var isSaving = false

    // Form fields
    @State private var title = ""
    @State private var sourceType: RecipeSourceType = .manual
    @State private var sourceURL = ""
    @State private var servings = ""
    @State private var prepTime = ""
    @State private var cookTime = ""
    @State private var notes = ""
    @State private var instructions: [String] = [""]
    @State private var ingredientInputs: [String] = [""]

    // Image handling
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var recipeImage: UIImage?

    // Focus management for auto-focusing new ingredient fields
    @FocusState private var focusedIngredientIndex: Int?

    init(
        recipe: Recipe? = nil,
        initialImage: UIImage? = nil,
        initialIngredients: [String]? = nil,
        initialInstructions: [String]? = nil
    ) {
        let editingRecipe = recipe ?? Recipe()
        _recipe = State(initialValue: editingRecipe)
        _isNewRecipe = State(initialValue: recipe == nil)

        // Initialize form fields from recipe
        if let recipe = recipe {
            _title = State(initialValue: recipe.title)
            _sourceType = State(initialValue: recipe.sourceType ?? .manual)
            _sourceURL = State(initialValue: recipe.sourceURL ?? "")
            _servings = State(initialValue: recipe.servings ?? "")
            _prepTime = State(initialValue: recipe.prepTime ?? "")
            _cookTime = State(initialValue: recipe.cookTime ?? "")
            _notes = State(initialValue: recipe.notes ?? "")
            _instructions = State(initialValue: recipe.instructions.isEmpty ? [""] : recipe.instructions)

            if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                _ingredientInputs = State(initialValue: ingredients.map { $0.originalText })
            }
        } else {
            // Initialize from OCR/scanner if provided
            if let image = initialImage {
                _recipeImage = State(initialValue: image)
                _sourceType = State(initialValue: .cookbook)
            }

            if let ingredients = initialIngredients, !ingredients.isEmpty {
                _ingredientInputs = State(initialValue: ingredients)
            }

            if let instructions = initialInstructions, !instructions.isEmpty {
                _instructions = State(initialValue: instructions)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic Info Section
                Section("Recipe Details") {
                    TextField("Recipe Title", text: $title)
                        .font(HeirloomFonts.body)

                    Picker("Source", selection: $sourceType) {
                        ForEach(RecipeSourceType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .font(HeirloomFonts.body)

                    if sourceType == .url {
                        TextField("Recipe URL (optional)", text: $sourceURL)
                            .font(HeirloomFonts.body)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                    }
                }

                // Image Section
                Section("Photo") {
                    if let image = recipeImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                            .clipped()
                    }

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(
                            recipeImage == nil ? "Add Photo" : "Change Photo",
                            systemImage: "photo"
                        )
                        .font(HeirloomFonts.body)
                    }
                    .onChange(of: selectedPhoto) { _, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                recipeImage = image
                            }
                        }
                    }
                }

                // Metadata Section
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

                // Ingredients Section
                Section {
                    ForEach(ingredientInputs.indices, id: \.self) { index in
                        HStack {
                            TextField("Ingredient", text: $ingredientInputs[index])
                                .font(HeirloomFonts.body)
                                .focused($focusedIngredientIndex, equals: index)
                                .onSubmit {
                                    // Add new ingredient field when user presses Enter on last field
                                    if index == ingredientInputs.count - 1 {
                                        ingredientInputs.append("")
                                        // Auto-focus the new field
                                        focusedIngredientIndex = ingredientInputs.count - 1
                                    }
                                }

                            if ingredientInputs.count > 1 {
                                Button {
                                    ingredientInputs.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
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

                // Instructions Section
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

                            if instructions.count > 1 {
                                Button {
                                    instructions.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
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

                // Notes Section
                Section("Notes") {
                    TextField("Add any notes or tips...", text: $notes, axis: .vertical)
                        .font(HeirloomFonts.body)
                        .lineLimit(3...10)
                }
            }
            .navigationTitle(isNewRecipe ? "New Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveRecipe()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(HeirloomColors.tomato)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
        }
    }

    // MARK: - Actions
    private func saveRecipe() {
        isSaving = true

        Task {
            // Update recipe properties
            recipe.title = title
            recipe.sourceType = sourceType
            recipe.sourceURL = sourceURL.isEmpty ? nil : sourceURL
            recipe.servings = servings.isEmpty ? nil : servings
            recipe.prepTime = prepTime.isEmpty ? nil : prepTime
            recipe.cookTime = cookTime.isEmpty ? nil : cookTime
            recipe.notes = notes.isEmpty ? nil : notes
            recipe.instructions = instructions.filter { !$0.isEmpty }
            recipe.lastModified = Date()

            // Create ingredients
            let filteredIngredients = ingredientInputs.filter { !$0.isEmpty }
            var newIngredients: [Ingredient] = []

            for (index, ingredientText) in filteredIngredients.enumerated() {
                let ingredient = Ingredient(
                    originalText: ingredientText,
                    orderIndex: index
                )
                ingredient.recipe = recipe
                newIngredients.append(ingredient)
                modelContext.insert(ingredient)
            }

            recipe.ingredients = newIngredients.isEmpty ? nil : newIngredients

            // Auto-detect recipe category for smart serving presets
            CategoryDetectionService.shared.detectAndApply(to: recipe)

            // Save image if provided
            if let image = recipeImage {
                do {
                    try await recipe.saveImage(image)
                } catch {
                    print("⚠️ Failed to save recipe image: \(error)")
                }
            }

            // Insert new recipe if needed
            if isNewRecipe {
                recipe.dateAdded = Date()

                // Initialize provenance metadata for new recipes
                if recipe.provenance == nil {
                    let provenanceSourceType: ProvenanceMetadata.SourceType

                    // Map RecipeSourceType to ProvenanceMetadata.SourceType
                    switch sourceType {
                    case .manual:
                        provenanceSourceType = .userCreated
                    case .url:
                        provenanceSourceType = .imported
                    case .cookbook:
                        provenanceSourceType = .userCreated
                    case .family:
                        provenanceSourceType = .shared
                    case .scan:
                        provenanceSourceType = .scanned
                    }

                    recipe.provenance = ProvenanceMetadata(
                        sourceType: provenanceSourceType,
                        sourceURL: sourceURL.isEmpty ? nil : sourceURL,
                        sourceAttribution: nil,
                        generation: 0
                    )
                }

                modelContext.insert(recipe)

                // Track analytics
                AnalyticsService.shared.trackRecipeCreated(recipe: recipe)
            } else {
                // Track analytics
                AnalyticsService.shared.trackRecipeEdited(recipe: recipe)
            }

            // Save context
            do {
                try modelContext.save()

                await MainActor.run {
                    isSaving = false

                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)

                    ToastManager.shared.success(
                        title: isNewRecipe ? "Recipe created!" : "Recipe updated!"
                    )
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false

                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)

                    ToastManager.shared.error(
                        title: "Failed to save recipe",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

}

// MARK: - Preview
#Preview {
    RecipeEditorView()
        .modelContainer(for: Recipe.self, inMemory: true)
        .toastContainer()
}

#Preview("Editing") {
    RecipeEditorView(recipe: .example)
        .modelContainer(for: Recipe.self, inMemory: true)
        .toastContainer()
}
