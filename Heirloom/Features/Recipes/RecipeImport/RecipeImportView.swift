import SwiftUI
import SwiftData

struct RecipeImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.firebaseSync) private var firebaseSync
    @EnvironmentObject private var tabCoordinator: TabNavigationCoordinator

    // Using concrete type for now since view calls implementation-specific methods
    private var aiIngredientParser: AIIngredientParser { ServiceContainer.shared.resolve(AIIngredientParser.self) }
    private var imageStorageService: ImageStorageService { ServiceContainer.shared.resolve(ImageStorageService.self) }

    // Using concrete type for toast notifications
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }
    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }
    private var cloudImportService: CloudRecipeImportService { ServiceContainer.shared.resolve(CloudRecipeImportService.self) }
    private var backendConfig: BackendConfig { ServiceContainer.shared.resolve(BackendConfig.self) }
    private var aiConfig: AIConfiguration { ServiceContainer.shared.resolve(AIConfiguration.self) }
    private var subscriptionManager: SubscriptionManager { ServiceContainer.shared.resolve(SubscriptionManager.self) }

    // Optional URL passed from Share Extension
    let url: URL?

    @State private var urlText = ""
    @State private var isImporting = false
    @State private var importedRecipe: ImportedRecipe?
    @State private var importError: String?
    @State private var isSaving = false
    @State private var showSoftWall = false

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
                        // Clear coordinator context on cancel
                        tabCoordinator.didCancelCreation()
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
                                    .tint(HeirloomColors.buttonTextLight)
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
                    // Check premium before auto-importing
                    if subscriptionManager.isPremium {
                        Task {
                            await importFromURL()
                        }
                    } else {
                        showSoftWall = true
                    }
                }
            }
            .sheet(isPresented: $showSoftWall) {
                SoftWallView(trigger: .urlImport)
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
                Text("Recipe Website Link")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("Paste a URL from recipe websites like AllRecipes, NYT Cooking, or food blogs. Not for video links.")
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
                            .font(HeirloomFonts.caption1)

                        Text(error)
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal, HeirloomSpacing.lg)
                }
            }

            // Import Button
            Button {
                // Check for premium subscription
                guard subscriptionManager.isPremium else {
                    showSoftWall = true
                    return
                }

                Task {
                    await importFromURL()
                }
            } label: {
                HStack {
                    if isImporting {
                        ProgressView()
                            .tint(HeirloomColors.buttonTextLight)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Import Recipe")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(urlText.isEmpty || isImporting ? HeirloomColors.warmGray : HeirloomColors.tomato)
                .foregroundStyle(HeirloomColors.buttonTextLight)
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
                                        .foregroundStyle(HeirloomColors.buttonTextLight)
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
            let response = try await cloudImportService.importWithFallback(from: urlText)

            await MainActor.run {
                if let recipe = response.toImportedRecipe() {
                    importedRecipe = recipe

                    // Log confidence and parser used
                    Log.info("Recipe imported", category: .network, metadata: [
                        "confidence": response.confidence * 100,
                        "parser": response.metadata.parserUsed.rawValue,
                        "domain": response.metadata.domain
                    ])
                    if let author = recipe.author {
                        Log.debug("Recipe author found", category: .network, metadata: ["author": author])
                    }
                    if let imageURL = recipe.imageURL {
                        Log.debug("Recipe image URL found", category: .network, metadata: ["imageURL": imageURL])
                    } else {
                        Log.debug("No image URL found", category: .network)
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
            parsedIngredients = try await aiIngredientParser.parseBatchToTuple(ingredientTexts)
        } catch {
            // Fallback to regex parsing on error (already handled in AIIngredientParser)
            Log.warning("Batch parsing encountered an error", category: .general, metadata: ["error": error.localizedDescription])
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
        recipe.detectAndApplyCategory()

        // Download and save image if available
        if let imageURLString = importedRecipe?.imageURL,
           let imageURL = URL(string: imageURLString) {
            await downloadAndSaveImage(from: imageURL, for: recipe)
        }

        // Save to database
        do {
            try modelContext.save()

            // Route to "From Web" collection
            if let sourceURLString = recipe.sourceURL, let sourceURL = URL(string: sourceURLString) {
                let router = CollectionRouter(modelContext: modelContext)
                router.routeURLImport(recipe, sourceURL: sourceURL)
            }

            // Sync to Firebase if active
            if backendConfig.isFirebaseActive {
                do {
                    try await firebaseSync.uploadRecipe(recipe)

                    // Upload image if it was downloaded
                    if recipe.imageFileName != nil {
                        if let imageURL = try await firebaseSync.uploadImage(for: recipe) {
                            recipe.firebaseImageURL = imageURL
                            try? modelContext.save()
                        }
                    }

                    Log.info("Imported recipe synced to Firebase", category: .firebase)
                } catch {
                    Log.warning("Failed to sync imported recipe to Firebase", category: .firebase, metadata: ["error": error.localizedDescription])
                    // Don't fail - local save succeeded
                }
            }

            toastManager.success(
                title: "Recipe imported!",
                message: "Added '\(recipe.title)' to your collection"
            )

            analytics.track(event: .recipeImported, properties: [
                "source": "url",
                "ingredient_count": ingredients.count,
                "has_image": importedRecipe?.imageURL != nil,
                "used_ai_parsing": aiConfig.enableAIParsing
            ])

            // Success feedback
            await MainActor.run {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                // Notify coordinator of recipe creation for cross-tab navigation
                tabCoordinator.didCreateRecipe()

                // Dismiss after coordinator is notified
                dismiss()
            }
        } catch {
            toastManager.error(
                title: "Failed to save recipe",
                message: error.localizedDescription
            )
        }
    }

    private func downloadAndSaveImage(from url: URL, for recipe: Recipe) async {
        Log.info("Downloading recipe image", category: .network, metadata: ["url": url.absoluteString])
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            Log.debug("Downloaded image data", category: .network, metadata: ["bytes": data.count])

            if let image = UIImage(data: data) {
                Log.debug("Created UIImage from data", category: .storage)
                let fileName = try await imageStorageService.saveImage(image, recipeId: recipe.id)
                Log.info("Saved image", category: .storage, metadata: ["fileName": fileName])
                await MainActor.run {
                    recipe.imageFileName = fileName
                    Log.debug("Set recipe image filename", category: .database, metadata: ["fileName": fileName])
                    try? modelContext.save()
                    Log.debug("Saved model context", category: .database)
                }
            } else {
                Log.warning("Failed to create UIImage from downloaded data", category: .storage)
            }
        } catch {
            Log.warning("Failed to download recipe image", category: .network, metadata: ["error": error.localizedDescription])
        }
    }
}

// MARK: - Metadata Item Component

struct MetadataItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: HeirloomSpacing.xs) {
            Image(systemName: icon)
                .font(HeirloomFonts.caption1)
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
