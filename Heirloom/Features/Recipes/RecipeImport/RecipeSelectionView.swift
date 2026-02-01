import SwiftUI
import SwiftData

/// View for selecting which recipes to import when multiple are detected in an image
struct RecipeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.firebaseSync) private var firebaseSync

    // Using concrete type for image storage
    private var imageStorageService: ImageStorageService { ServiceContainer.shared.resolve(ImageStorageService.self) }
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }
    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }
    private var backendConfig: BackendConfig { ServiceContainer.shared.resolve(BackendConfig.self) }

    let recipes: [AIRecipeExtractor.ExtractedRecipe]
    let sourceImage: UIImage?

    @State private var selectedRecipes: Set<Int> = []
    @State private var expandedRecipes: Set<Int> = []
    @State private var isSaving = false
    @State private var importProgress: Double = 0.0
    @State private var currentImportStep: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header info
                headerBanner

                // Recipe list
                ScrollView {
                    LazyVStack(spacing: HeirloomSpacing.md) {
                        ForEach(Array(recipes.enumerated()), id: \.offset) { index, recipe in
                            RecipeSelectionCard(
                                recipe: recipe,
                                index: index,
                                isSelected: selectedRecipes.contains(index),
                                isExpanded: expandedRecipes.contains(index),
                                onToggleSelection: {
                                    toggleSelection(index)
                                },
                                onToggleExpansion: {
                                    toggleExpansion(index)
                                }
                            )
                        }
                    }
                    .padding(HeirloomSpacing.md)
                }
                .background(HeirloomColors.appBackground)

                // Bottom toolbar
                bottomToolbar
            }
            .navigationTitle("Select Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Select all by default
            selectedRecipes = Set(recipes.indices)
        }
    }

    // MARK: - Header Banner

    private var headerBanner: some View {
        VStack(spacing: HeirloomSpacing.xs) {
            HStack {
                // Success icon for multiple recipes
                ZStack {
                    Circle()
                        .fill(HeirloomColors.familyGreen.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "doc.on.doc.fill")
                        .font(HeirloomFonts.title2)
                        .foregroundColor(HeirloomColors.familyGreen)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Detected \(recipes.count) Recipes!")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundColor(HeirloomColors.primaryText)

                    Text("Select which ones to import")
                        .font(HeirloomFonts.caption1)
                        .foregroundColor(HeirloomColors.secondaryText)
                }

                Spacer()

                // Select All / Deselect All
                Button {
                    if selectedRecipes.count == recipes.count {
                        selectedRecipes.removeAll()
                    } else {
                        selectedRecipes = Set(recipes.indices)
                    }
                } label: {
                    Text(selectedRecipes.count == recipes.count ? "Deselect All" : "Select All")
                        .font(HeirloomFonts.caption1)
                        .foregroundColor(HeirloomColors.tomato)
                }
            }
            .padding(HeirloomSpacing.md)
        }
        .background(HeirloomColors.cardBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(HeirloomColors.secondaryText.opacity(0.2)),
            alignment: .bottom
        )
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(HeirloomColors.secondaryText.opacity(0.2))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedRecipes.count) Selected")
                        .font(HeirloomFonts.body)
                        .foregroundColor(HeirloomColors.primaryText)

                    if selectedRecipes.isEmpty {
                        Text("Select at least one recipe")
                            .font(HeirloomFonts.caption2)
                            .foregroundColor(HeirloomColors.tomato)
                    }
                }

                Spacer()

                if isSaving {
                    // Show progress during import
                    VStack(alignment: .trailing, spacing: HeirloomSpacing.xs) {
                        HStack(spacing: HeirloomSpacing.sm) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)

                            Text(currentImportStep)
                                .font(HeirloomFonts.caption1)
                                .foregroundColor(HeirloomColors.secondaryText)
                        }

                        ProgressView(value: importProgress)
                            .progressViewStyle(.linear)
                            .tint(HeirloomColors.tomato)
                            .frame(width: 150)
                    }
                } else {
                    Button {
                        importSelected()
                    } label: {
                        Text("Import Selected")
                            .font(HeirloomFonts.bodyBold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(HeirloomColors.tomato)
                    .disabled(selectedRecipes.isEmpty)
                }
            }
            .padding(HeirloomSpacing.md)
        }
        .background(HeirloomColors.cardBackground)
    }

    // MARK: - Actions

    private func toggleSelection(_ index: Int) {
        if selectedRecipes.contains(index) {
            selectedRecipes.remove(index)
        } else {
            selectedRecipes.insert(index)
        }
    }

    private func toggleExpansion(_ index: Int) {
        if expandedRecipes.contains(index) {
            expandedRecipes.remove(index)
        } else {
            expandedRecipes.insert(index)
        }
    }

    private func importSelected() {
        guard !selectedRecipes.isEmpty else { return }

        isSaving = true
        importProgress = 0.0

        Task {
            do {
                let selectedRecipeObjects = selectedRecipes.sorted().map { recipes[$0] }
                var createdRecipes: [Recipe] = []
                let totalRecipes = selectedRecipeObjects.count

                for (index, extractedRecipe) in selectedRecipeObjects.enumerated() {
                    // Update progress
                    await MainActor.run {
                        currentImportStep = "Importing \(index + 1)/\(totalRecipes)..."
                        importProgress = Double(index) / Double(totalRecipes)
                    }
                    // Create recipe
                    let recipe = Recipe(
                        title: extractedRecipe.title,
                        sourceType: .scan
                    )

                    // Set metadata
                    recipe.servings = extractedRecipe.servings
                    recipe.prepTime = extractedRecipe.prepTime
                    recipe.cookTime = extractedRecipe.cookTime
                    recipe.notes = extractedRecipe.notes
                    recipe.instructions = extractedRecipe.instructions

                    // Insert recipe first so it gets an ID
                    modelContext.insert(recipe)

                    // Save source image if available (needs recipe.id to be set)
                    if let sourceImage = sourceImage {
                        do {
                            let fileName = try await imageStorageService.saveImage(sourceImage, recipeId: recipe.id)
                            await MainActor.run {
                                recipe.imageFileName = fileName
                                Log.info("Saved recipe image from multi-recipe scan", category: .storage, metadata: ["title": recipe.title, "fileName": fileName])
                            }
                        } catch {
                            Log.warning("Failed to save image for multi-recipe scan", category: .storage, metadata: ["title": recipe.title, "error": error.localizedDescription])
                        }
                    }

                    // Create and insert ingredients
                    for (index, ingredientText) in extractedRecipe.ingredients.enumerated() {
                        let parsed = IngredientParser.parse(ingredientText)
                        let ingredient = Ingredient(
                            originalText: ingredientText,
                            name: parsed.name,
                            quantity: parsed.quantity,
                            unit: parsed.unit,
                            category: GroceryCategory.categorize(parsed.name),
                            orderIndex: index
                        )
                        ingredient.quantityMax = parsed.quantityMax
                        ingredient.recipe = recipe
                        modelContext.insert(ingredient)
                    }

                    createdRecipes.append(recipe)
                }

                // Update progress
                await MainActor.run {
                    currentImportStep = "Saving recipes..."
                    importProgress = 0.9
                }

                // Save all at once
                try modelContext.save()

                // Sync to Firebase if active
                if backendConfig.isFirebaseActive {
                    for recipe in createdRecipes {
                        do {
                            try await firebaseSync.uploadRecipe(recipe)

                            // Upload scanned image if exists
                            if recipe.imageFileName != nil {
                                if let imageURL = try await firebaseSync.uploadImage(for: recipe) {
                                    recipe.firebaseImageURL = imageURL
                                    try? modelContext.save()
                                }
                            }

                            Log.info("Scanned recipe synced to Firebase", category: .firebase, metadata: ["title": recipe.title])
                        } catch {
                            Log.warning("Failed to sync scanned recipe to Firebase", category: .firebase, metadata: ["title": recipe.title, "error": error.localizedDescription])
                            // Don't fail - local save succeeded
                        }
                    }
                }

                // Success feedback
                toastManager.success(
                    title: "Recipes Imported",
                    message: "Successfully imported \(selectedRecipes.count) recipe\(selectedRecipes.count == 1 ? "" : "s")"
                )

                // Track analytics
                analytics.track(event: .recipeCreated, properties: [
                    "source": "ocr_multi",
                    "recipe_count": selectedRecipes.count,
                    "total_detected": recipes.count
                ])

                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                // Dismiss
                dismiss()

            } catch {
                isSaving = false

                toastManager.error(
                    title: "Import Failed",
                    message: error.localizedDescription
                )

                Log.error("Failed to import recipes from scan", category: .database, metadata: ["error": error.localizedDescription])
            }
        }
    }
}

// MARK: - Recipe Selection Card

struct RecipeSelectionCard: View {
    let recipe: AIRecipeExtractor.ExtractedRecipe
    let index: Int
    let isSelected: Bool
    let isExpanded: Bool
    let onToggleSelection: () -> Void
    let onToggleExpansion: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Header with checkbox and title
            HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
                // Checkbox
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? HeirloomColors.tomato : HeirloomColors.secondaryText)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    // Title
                    Text(recipe.title)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundColor(HeirloomColors.primaryText)

                    // Meta info
                    HStack(spacing: HeirloomSpacing.sm) {
                        Label("\(recipe.ingredients.count)", systemImage: "list.bullet")
                        Label("\(recipe.instructions.count) steps", systemImage: "list.number")

                        if let confidence = recipe.confidence {
                            confidenceBadge(confidence)
                        }
                    }
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(HeirloomColors.secondaryText)
                }

                Spacer()
            }

            // Expand/Collapse button - full width for easy tapping
            Button(action: onToggleExpansion) {
                HStack {
                    Text(isExpanded ? "Hide Details" : "Show Details")
                        .font(HeirloomFonts.caption1)
                        .foregroundColor(HeirloomColors.tomato)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .font(HeirloomFonts.title2)
                        .foregroundColor(HeirloomColors.tomato)
                }
                .padding(.top, HeirloomSpacing.xs)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Divider()

                    // Metadata
                    if recipe.servings != nil || recipe.prepTime != nil || recipe.cookTime != nil {
                        HStack(spacing: HeirloomSpacing.md) {
                            if let servings = recipe.servings {
                                metadataChip(icon: "person.2", text: servings)
                            }
                            if let prepTime = recipe.prepTime {
                                metadataChip(icon: "clock", text: prepTime)
                            }
                            if let cookTime = recipe.cookTime {
                                metadataChip(icon: "flame", text: cookTime)
                            }
                        }
                    }

                    // Ingredients preview
                    VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                        Text("Ingredients")
                            .font(HeirloomFonts.caption1)
                            .foregroundColor(HeirloomColors.secondaryText)
                            .textCase(.uppercase)

                        ForEach(recipe.ingredients.prefix(3), id: \.self) { ingredient in
                            Text("• \(ingredient)")
                                .font(HeirloomFonts.caption1)
                                .foregroundColor(HeirloomColors.primaryText)
                        }

                        if recipe.ingredients.count > 3 {
                            Text("+ \(recipe.ingredients.count - 3) more")
                                .font(HeirloomFonts.caption2)
                                .foregroundColor(HeirloomColors.secondaryText)
                        }
                    }

                    // Instructions preview
                    VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                        Text("Instructions")
                            .font(HeirloomFonts.caption1)
                            .foregroundColor(HeirloomColors.secondaryText)
                            .textCase(.uppercase)

                        ForEach(Array(recipe.instructions.prefix(2).enumerated()), id: \.offset) { index, instruction in
                            Text("\(index + 1). \(instruction)")
                                .font(HeirloomFonts.caption1)
                                .foregroundColor(HeirloomColors.primaryText)
                                .lineLimit(2)
                        }

                        if recipe.instructions.count > 2 {
                            Text("+ \(recipe.instructions.count - 2) more steps")
                                .font(HeirloomFonts.caption2)
                                .foregroundColor(HeirloomColors.secondaryText)
                        }
                    }
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(HeirloomSpacing.cardCornerRadius)
        .shadow(
            color: HeirloomShadows.card.color,
            radius: HeirloomShadows.card.radius,
            x: HeirloomShadows.card.x,
            y: HeirloomShadows.card.y
        )
        .overlay(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .stroke(isSelected ? HeirloomColors.tomato : Color.clear, lineWidth: 2)
        )
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func confidenceBadge(_ confidence: Double) -> some View {
        let (label, color) = confidenceInfo(confidence)

        HStack(spacing: HeirloomSpacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }

    private func confidenceInfo(_ confidence: Double) -> (String, Color) {
        switch confidence {
        case 0.9...1.0:
            return ("High", HeirloomColors.familyGreen)
        case 0.7..<0.9:
            return ("Medium", HeirloomColors.amber)
        default:
            return ("Low", HeirloomColors.tomato)
        }
    }

    @ViewBuilder
    private func metadataChip(icon: String, text: String) -> some View {
        HStack(spacing: HeirloomSpacing.xs) {
            Image(systemName: icon)
            Text(text)
        }
        .font(HeirloomFonts.caption2)
        .foregroundColor(HeirloomColors.secondaryText)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(HeirloomColors.secondaryText.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Previews

#Preview {
    RecipeSelectionView(
        recipes: [
            AIRecipeExtractor.ExtractedRecipe(
                title: "Cheese Straws",
                servings: "30 straws",
                prepTime: nil,
                cookTime: "10 minutes",
                ingredientStructure: .flat([
                    "1 cup grated American cheese",
                    "1 cup flour",
                    "1 teaspoon Royal Baking Powder",
                    "1/4 teaspoon salt",
                    "1/8 teaspoon cayenne pepper"
                ]),
                instructions: [
                    "Mix together cheese, flour, baking powder, salt, cayenne pepper and paprika",
                    "Add beaten egg; mix well",
                    "Bake in hot oven at 450°F for ten minutes"
                ],
                notes: nil,
                confidence: 0.95
            ),
            AIRecipeExtractor.ExtractedRecipe(
                title: "Peanut Butter Bread",
                servings: "1 large loaf",
                prepTime: nil,
                cookTime: "1 hour",
                ingredientStructure: .flat([
                    "2 cups flour",
                    "4 teaspoons Royal Baking Powder",
                    "1 teaspoon salt",
                    "1/2 cup sugar",
                    "1/3 cup peanut butter"
                ]),
                instructions: [
                    "Sift flour, Royal Baking Powder, salt and sugar together",
                    "Add peanut butter and mix",
                    "Bake in moderate oven at 350°F"
                ],
                notes: nil,
                confidence: 0.85
            ),
            AIRecipeExtractor.ExtractedRecipe(
                title: "Orange Fritters",
                servings: nil,
                prepTime: nil,
                cookTime: nil,
                ingredientStructure: .flat([
                    "3 oranges",
                    "1 cup batter",
                    "Powdered sugar"
                ]),
                instructions: [
                    "Peel three oranges and separate into sections",
                    "Dip each section into the batter",
                    "Drop into deep hot fat"
                ],
                notes: nil,
                confidence: 0.65
            )
        ],
        sourceImage: nil
    )
    .modelContainer(for: [Recipe.self, Ingredient.self], inMemory: true)
}
