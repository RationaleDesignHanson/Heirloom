import SwiftUI
import SwiftData

/// View for selecting which recipes to import when multiple are detected in an image
struct RecipeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let recipes: [AIRecipeExtractor.ExtractedRecipe]
    let sourceImage: UIImage?

    @State private var selectedRecipes: Set<Int> = []
    @State private var expandedRecipes: Set<Int> = []
    @State private var isSaving = false

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
                Image(systemName: "checkmark.circle.badge.questionmark")
                    .font(.title3)
                    .foregroundColor(HeirloomColors.primaryText)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Found \(recipes.count) Recipes")
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

                Button {
                    importSelected()
                } label: {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Import Selected")
                            .font(HeirloomFonts.bodyBold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(HeirloomColors.tomato)
                .disabled(selectedRecipes.isEmpty || isSaving)
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

        Task {
            do {
                let selectedRecipeObjects = selectedRecipes.sorted().map { recipes[$0] }

                for extractedRecipe in selectedRecipeObjects {
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
                        let fileName = try await ImageStorageService.shared.saveImage(sourceImage, recipeId: recipe.id)
                        recipe.imageFileName = fileName
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
                }

                // Save all at once
                try modelContext.save()

                // Success feedback
                ToastManager.shared.success(
                    title: "Recipes Imported",
                    message: "Successfully imported \(selectedRecipes.count) recipe\(selectedRecipes.count == 1 ? "" : "s")"
                )

                // Track analytics
                AnalyticsService.shared.track(event: .recipeCreated, properties: [
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

                ToastManager.shared.error(
                    title: "Import Failed",
                    message: error.localizedDescription
                )

                print("❌ Failed to import recipes: \(error)")
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

                // Expand/collapse button
                Button(action: onToggleExpansion) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(HeirloomColors.secondaryText)
                }
                .buttonStyle(.plain)
            }

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
                    VStack(alignment: .leading, spacing: 4) {
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
                    VStack(alignment: .leading, spacing: 4) {
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

        HStack(spacing: 4) {
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
        HStack(spacing: 4) {
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
                ingredients: [
                    "1 cup grated American cheese",
                    "1 cup flour",
                    "1 teaspoon Royal Baking Powder",
                    "1/4 teaspoon salt",
                    "1/8 teaspoon cayenne pepper"
                ],
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
                ingredients: [
                    "2 cups flour",
                    "4 teaspoons Royal Baking Powder",
                    "1 teaspoon salt",
                    "1/2 cup sugar",
                    "1/3 cup peanut butter"
                ],
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
                ingredients: [
                    "3 oranges",
                    "1 cup batter",
                    "Powdered sugar"
                ],
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
