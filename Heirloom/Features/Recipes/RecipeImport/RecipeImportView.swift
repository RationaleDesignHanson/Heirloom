import SwiftUI
import SwiftData

struct RecipeImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Optional URL passed from Share Extension
    let url: URL?

    @State private var urlText = ""
    @State private var isImporting = false
    @State private var importedRecipe: ImportedRecipe?
    @State private var importError: String?
    @State private var isSaving = false

    // Init for manual URL entry
    init() {
        self.url = nil
    }

    // Init for Share Extension (with pre-populated URL)
    init(url: URL) {
        self.url = url
    }

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
                        Button {
                            Task {
                                await saveRecipe()
                            }
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text("Save")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .onAppear {
                // If URL was passed from Share Extension, auto-populate and import
                if let shareURL = url {
                    urlText = shareURL.absoluteString
                    Task {
                        await importFromURL()
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
            // Try cloud import with automatic fallback to local parser
            let response = try await CloudRecipeImportService.shared.importWithFallback(from: urlText)

            await MainActor.run {
                if let recipe = response.toImportedRecipe() {
                    importedRecipe = recipe

                    // Log confidence and parser used
                    print("✅ Imported with \(String(format: "%.1f%%", response.confidence * 100)) confidence")
                    print("   Parser: \(response.metadata.parserUsed.rawValue)")
                    print("   Domain: \(response.metadata.domain)")
                    if let author = recipe.author {
                        print("   Author: \(author)")
                    }
                    if let imageURL = recipe.imageURL {
                        print("   Image URL: \(imageURL)")
                    } else {
                        print("   ⚠️ No image URL")
                    }
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

    private func saveRecipe() async {
        guard let imported = importedRecipe else { return }

        // Set saving state
        isSaving = true
        defer { isSaving = false }

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

        // Parse ingredients with AI (async batch parsing for efficiency)
        await parseAndSaveIngredients(recipe: recipe, ingredientTexts: imported.ingredients)
    }

    private func parseAndSaveIngredients(recipe: Recipe, ingredientTexts: [String]) async {
        // Use AI batch parsing for better efficiency
        let parsedIngredients: [(quantity: Double?, quantityMax: Double?, unit: String?, name: String)]

        do {
            parsedIngredients = try await AIIngredientParser.shared.parseBatch(ingredientTexts)
        } catch {
            // Fallback to regex parsing on error (already handled in AIIngredientParser)
            print("⚠️ Batch parsing encountered an error: \(error.localizedDescription)")
            parsedIngredients = ingredientTexts.map { IngredientParser.parse($0) }
        }

        // Create Ingredient objects
        var ingredients: [Ingredient] = []
        for (index, text) in ingredientTexts.enumerated() {
            let parsed = parsedIngredients[index]

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

        // Auto-detect recipe category for smart serving presets
        CategoryDetectionService.shared.detectAndApply(to: recipe)

        // Download and save image if available
        if let imageURLString = importedRecipe?.imageURL,
           let imageURL = URL(string: imageURLString) {
            await downloadAndSaveImage(from: imageURL, for: recipe)
        }

        // Save to database
        do {
            try modelContext.save()

            // Sync to Firebase if active
            if BackendConfig.shared.isFirebaseActive {
                do {
                    try await FirebaseSyncService.shared.uploadRecipe(recipe)

                    // Upload image if it was downloaded
                    if recipe.imageFileName != nil {
                        if let imageURL = try await FirebaseSyncService.shared.uploadImage(for: recipe) {
                            recipe.firebaseImageURL = imageURL
                            try? modelContext.save()
                        }
                    }

                    print("✅ Imported recipe synced to Firebase")
                } catch {
                    print("⚠️ Failed to sync imported recipe to Firebase: \(error.localizedDescription)")
                    // Don't fail - local save succeeded
                }
            }

            ToastManager.shared.success(
                title: "Recipe imported!",
                message: "Added '\(recipe.title)' to your collection"
            )

            AnalyticsService.shared.track(event: .recipeImported, properties: [
                "source": "url",
                "ingredient_count": ingredients.count,
                "has_image": importedRecipe?.imageURL != nil,
                "used_ai_parsing": AIConfiguration.shared.enableAIParsing
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
        print("🖼️ Downloading image from: \(url.absoluteString)")
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            print("✅ Downloaded image data: \(data.count) bytes")

            if let image = UIImage(data: data) {
                print("✅ Created UIImage from data")
                let fileName = try await ImageStorageService.shared.saveImage(image, recipeId: recipe.id)
                print("✅ Saved image as: \(fileName)")
                await MainActor.run {
                    recipe.imageFileName = fileName
                    print("✅ Set recipe.imageFileName = \(fileName)")
                    try? modelContext.save()
                    print("✅ Saved modelContext")
                }
            } else {
                print("⚠️ Failed to create UIImage from downloaded data")
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
