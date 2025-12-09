import SwiftUI
import SwiftData

struct RecipeImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var urlText = ""
    @State private var isImporting = false
    @State private var importedRecipe: ImportedRecipe?
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                if let recipe = importedRecipe {
                    importPreviewView(recipe)
                } else {
                    urlInputView
                }
            }
            .navigationTitle("Import Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if importedRecipe != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Save") {
                            saveRecipe()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - URL Input View

    private var urlInputView: some View {
        VStack(spacing: HeirloomSpacing.xl) {
            // Icon
            Image(systemName: "link.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(HeirloomColors.tomato)
                .padding(.top, HeirloomSpacing.xxl)

            VStack(spacing: HeirloomSpacing.sm) {
                Text("Import from URL")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("Paste a recipe URL from your favorite cooking website")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, HeirloomSpacing.lg)
            }

            // URL Input Field
            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                TextField("https://example.com/recipe", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(.horizontal, HeirloomSpacing.lg)

                if let error = importError {
                    HStack(spacing: HeirloomSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)

                        Text(error)
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal, HeirloomSpacing.lg)
                }
            }

            // Import Button
            Button {
                Task {
                    await importFromURL()
                }
            } label: {
                HStack {
                    if isImporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Import Recipe")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(urlText.isEmpty || isImporting ? HeirloomColors.warmGray : HeirloomColors.tomato)
                .foregroundStyle(.white)
                .font(HeirloomFonts.bodyBold)
                .cornerRadius(12)
            }
            .disabled(urlText.isEmpty || isImporting)
            .padding(.horizontal, HeirloomSpacing.lg)

            // Supported Sites
            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                Text("Supported Sites")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .textCase(.uppercase)

                Text("Most recipe websites are supported, including AllRecipes, Food Network, Bon Appétit, NYT Cooking, and more.")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
            .padding(.horizontal, HeirloomSpacing.lg)

            Spacer()
        }
        .background(HeirloomColors.appBackground)
    }

    // MARK: - Import Preview View

    private func importPreviewView(_ imported: ImportedRecipe) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
                // Success Message
                HStack(spacing: HeirloomSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(HeirloomColors.familyGreen)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recipe Imported")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)

                        Text("Review and tap Save to add to your collection")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }
                .padding(HeirloomSpacing.md)
                .background(HeirloomColors.familyGreen.opacity(0.1))
                .cornerRadius(12)

                // Recipe Preview
                VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                    // Image
                    if let imageURL = imported.imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                SkeletonView()
                                    .frame(height: 200)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 200)
                                    .clipped()
                            case .failure:
                                Rectangle()
                                    .fill(HeirloomColors.warmGray.opacity(0.2))
                                    .frame(height: 200)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .foregroundStyle(HeirloomColors.warmGray)
                                    }
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .cornerRadius(12)
                    }

                    // Title
                    Text(imported.title)
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(HeirloomColors.primaryText)

                    // Metadata
                    HStack(spacing: HeirloomSpacing.lg) {
                        if let servings = imported.servings {
                            MetadataItem(icon: "person.2", text: servings)
                        }
                        if let prepTime = imported.prepTime {
                            MetadataItem(icon: "clock", text: prepTime)
                        }
                        if let cookTime = imported.cookTime {
                            MetadataItem(icon: "flame", text: cookTime)
                        }
                    }

                    // Description
                    if let description = imported.description {
                        Text(description)
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    Divider()

                    // Ingredients
                    VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                        Text("Ingredients (\(imported.ingredients.count))")
                            .font(HeirloomFonts.title3)
                            .foregroundStyle(HeirloomColors.primaryText)

                        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                            ForEach(Array(imported.ingredients.enumerated()), id: \.offset) { _, ingredient in
                                HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 6))
                                        .foregroundStyle(HeirloomColors.tomato)
                                        .padding(.top, 6)

                                    Text(ingredient)
                                        .font(HeirloomFonts.body)
                                        .foregroundStyle(HeirloomColors.primaryText)
                                }
                            }
                        }
                    }

                    Divider()

                    // Instructions
                    VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                        Text("Instructions")
                            .font(HeirloomFonts.title3)
                            .foregroundStyle(HeirloomColors.primaryText)

                        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                            ForEach(Array(imported.instructions.enumerated()), id: \.offset) { index, instruction in
                                HStack(alignment: .top, spacing: HeirloomSpacing.md) {
                                    Text("\(index + 1)")
                                        .font(HeirloomFonts.bodyBold)
                                        .foregroundStyle(.white)
                                        .frame(width: 28, height: 28)
                                        .background(HeirloomColors.tomato)
                                        .cornerRadius(14)

                                    Text(instruction)
                                        .font(HeirloomFonts.body)
                                        .foregroundStyle(HeirloomColors.primaryText)
                                }
                            }
                        }
                    }
                }
            }
            .padding(HeirloomSpacing.lg)
        }
        .background(HeirloomColors.appBackground)
    }

    // MARK: - Actions

    private func importFromURL() async {
        importError = nil
        isImporting = true

        do {
            let recipe = try await RecipeImportService.shared.importRecipe(from: urlText)

            await MainActor.run {
                if recipe.isValid {
                    importedRecipe = recipe
                } else {
                    importError = "The recipe is incomplete. Please try a different URL."
                }
                isImporting = false
            }
        } catch {
            await MainActor.run {
                importError = error.localizedDescription
                isImporting = false
            }
        }
    }

    private func saveRecipe() {
        guard let imported = importedRecipe else { return }

        // Create Recipe object
        let recipe = Recipe(
            title: imported.title,
            sourceType: .url,
            instructions: imported.instructions,
            servings: imported.servings,
            prepTime: imported.prepTime,
            cookTime: imported.cookTime
        )
        recipe.sourceURL = imported.sourceURL
        recipe.notes = imported.description

        // Insert recipe first
        modelContext.insert(recipe)

        // Create and parse ingredients
        var ingredients: [Ingredient] = []
        for (index, text) in imported.ingredients.enumerated() {
            let parsed = IngredientParser.parse(text)

            let ingredient = Ingredient(
                originalText: text,
                name: parsed.name,
                quantity: parsed.quantity,
                unit: parsed.unit,
                orderIndex: index
            )
            ingredient.quantityMax = parsed.quantityMax
            ingredient.recipe = recipe
            modelContext.insert(ingredient)
            ingredients.append(ingredient)
        }

        recipe.ingredients = ingredients

        // Download and save image if available
        if let imageURLString = imported.imageURL,
           let imageURL = URL(string: imageURLString) {
            Task {
                await downloadAndSaveImage(from: imageURL, for: recipe)
            }
        }

        do {
            try modelContext.save()

            ToastManager.shared.success(
                title: "Recipe imported!",
                message: "Added '\(recipe.title)' to your collection"
            )

            AnalyticsService.shared.track(event: .recipeImported, properties: [
                "source": "url",
                "ingredient_count": ingredients.count,
                "has_image": imported.imageURL != nil
            ])

            dismiss()
        } catch {
            ToastManager.shared.error(
                title: "Failed to save recipe",
                message: error.localizedDescription
            )
        }
    }

    private func downloadAndSaveImage(from url: URL, for recipe: Recipe) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            if let image = UIImage(data: data) {
                let fileName = try await ImageStorageService.shared.saveImage(image, recipeId: recipe.id)
                await MainActor.run {
                    recipe.imageFileName = fileName
                    try? modelContext.save()
                }
            }
        } catch {
            print("⚠️ Failed to download recipe image: \(error)")
        }
    }
}

// MARK: - Metadata Item Component

struct MetadataItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(HeirloomColors.secondaryText)
            Text(text)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }
}

#Preview {
    RecipeImportView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
