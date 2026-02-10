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

    // Optional target collection for adding the recipe to a specific collection
    let targetCollection: RecipeCollection?

    @State private var urlText = ""
    @State private var isImporting = false
    @State private var importedRecipe: ImportedRecipe?
    @State private var importError: String?
    @State private var isSaving = false
    @State private var showSoftWall = false

    // Init for manual URL entry
    init() {
        self.url = nil
        self.targetCollection = nil
    }

    // Init for Share Extension (with pre-populated URL)
    init(url: URL) {
        self.url = url
        self.targetCollection = nil
    }

    // Init with target collection (for adding to specific collection)
    init(targetCollection: RecipeCollection?) {
        self.url = nil
        self.targetCollection = targetCollection
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

                                    Text(formatIngredientPreview(ingredient))
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

    /// Replace leading decimal quantities with Unicode fractions for display
    private func formatIngredientPreview(_ text: String) -> String {
        let fractions: [(String, String)] = [
            ("0.125", "⅛"), ("0.25", "¼"), ("0.333", "⅓"), ("0.33", "⅓"),
            ("0.5", "½"), ("0.667", "⅔"), ("0.67", "⅔"), ("0.75", "¾")
        ]

        // Match a leading decimal like "0.75 cup" or "1.5 cups"
        // Pattern: optional whole number + decimal fraction at the start
        guard let match = text.range(of: #"^(\d+)?\.(\d+)"#, options: .regularExpression) else {
            return text
        }

        let decimalStr = String(text[match])
        guard let value = Double(decimalStr) else { return text }

        let whole = Int(value)
        let fractional = value - Double(whole)

        // Try to match the fractional part to a Unicode fraction
        for (_, (threshold, symbol)) in fractions.enumerated() {
            guard let thresholdVal = Double(threshold) else { continue }
            if abs(fractional - thresholdVal) < 0.02 {
                let formatted = whole > 0 ? "\(whole) \(symbol)" : symbol
                return text.replacingCharacters(in: match, with: formatted)
            }
        }

        // No fraction match — return as-is
        return text
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

        // Check for duplicates before inserting
        let duplicateDetectionService = ServiceContainer.shared.resolve(DuplicateDetectionService.self)

        do {
            let duplicates = try duplicateDetectionService.findDuplicates(
                for: recipe,
                in: modelContext,
                threshold: 0.85
            )

            if !duplicates.isEmpty {
                let exactMatches = duplicates.filter { $0.matchType == .exactHash }
                let nearPerfectMatches = duplicates.filter { $0.similarityScore >= 0.95 }

                if !exactMatches.isEmpty {
                    // Exact duplicate - don't insert
                    let match = exactMatches[0]
                    Log.warning("⚠️ Web import blocked - exact duplicate", category: .network, metadata: [
                        "title": recipe.title,
                        "duplicate_id": match.recipe.id.uuidString,
                        "duplicate_title": match.recipe.title
                    ])

                    await MainActor.run {
                        isSaving = false
                        toastManager.warning(
                            title: "Recipe Already Exists",
                            message: "You already have '\(match.recipe.title)' in your collection"
                        )
                        dismiss()
                    }
                    return
                } else if !nearPerfectMatches.isEmpty {
                    // Near-perfect match - don't insert
                    let match = nearPerfectMatches[0]
                    Log.warning("⚠️ Web import blocked - near-identical duplicate", category: .network, metadata: [
                        "title": recipe.title,
                        "similarity_score": match.similarityScore,
                        "duplicate_id": match.recipe.id.uuidString,
                        "duplicate_title": match.recipe.title
                    ])

                    await MainActor.run {
                        isSaving = false
                        toastManager.warning(
                            title: "Very Similar Recipe Exists",
                            message: "'\(match.recipe.title)' is already in your collection"
                        )
                        dismiss()
                    }
                    return
                } else {
                    // Similar but not near-identical - insert with warning
                    Log.info("ℹ️ Web import - similar recipe exists (importing anyway)", category: .network, metadata: [
                        "title": recipe.title,
                        "similarity_score": duplicates[0].similarityScore,
                        "match_type": "\(duplicates[0].matchType)",
                        "similar_to": duplicates[0].recipe.title
                    ])
                }
            }
        } catch {
            // Duplicate detection failed - insert anyway (don't block import)
            Log.warning("⚠️ Web import duplicate detection failed, importing anyway", category: .network, metadata: [
                "title": recipe.title,
                "error": error.localizedDescription
            ])
        }

        // Insert recipe first
        modelContext.insert(recipe)

        // Create placeholder ingredients from raw text (fast - no AI)
        let ingredients: [Ingredient] = imported.ingredients.enumerated().map { (index, text) in
            let ingredient = Ingredient(
                originalText: text,
                name: text, // Will be parsed in background
                quantity: nil,
                unit: nil,
                category: .other,
                orderIndex: index
            )
            ingredient.recipe = recipe
            return ingredient
        }

        // Insert placeholder ingredients
        for ingredient in ingredients {
            modelContext.insert(ingredient)
        }
        recipe.ingredients = ingredients

        // CRITICAL: Parse ingredients immediately to ensure quantities are available for scaling
        // This prevents the bug where changing servings doesn't update volumes
        do {
            Log.info("Parsing ingredients immediately for accurate scaling", category: .network)
            let parsed = try await aiIngredientParser.parseBatch(imported.ingredients)

            // Update ingredients with parsed data
            for (index, ingredient) in ingredients.enumerated() {
                guard index < parsed.count else { continue }
                let parsedData = parsed[index]
                ingredient.quantity = parsedData.quantity
                ingredient.quantityMax = parsedData.quantityMax
                ingredient.unit = parsedData.unit
                ingredient.normalizedUnit = parsedData.normalizedUnit
                ingredient.name = parsedData.name
                ingredient.preparation = parsedData.preparation
                ingredient.category = parsedData.category
            }

            Log.info("Ingredients parsed successfully", category: .network, metadata: [
                "count": ingredients.count,
                "withQuantities": ingredients.filter { $0.quantity != nil }.count
            ])
        } catch {
            Log.error("Failed to parse ingredients immediately", category: .network, metadata: [
                "error": error.localizedDescription
            ])
            // Continue with placeholder ingredients - background parsing will retry
        }

        // Auto-detect recipe category
        recipe.detectAndApplyCategory()

        // Route to collection
        let router = CollectionRouter(modelContext: modelContext)
        if let collection = targetCollection {
            // Route to the specific collection the user selected
            router.routeToSpecificCollection(recipe, collection: collection)
            Log.info("Added recipe to target collection", category: .collections, metadata: [
                "recipe": recipe.title,
                "collection": collection.name
            ])
        } else if let sourceURLString = recipe.sourceURL, let sourceURL = URL(string: sourceURLString) {
            // Default: route to "From Web" collection
            router.routeURLImport(recipe, sourceURL: sourceURL)
        }

        // Download image BEFORE saving (so recipe has image immediately)
        if let imageURLString = imported.imageURL,
           let imageURL = URL(string: imageURLString) {
            do {
                Log.info("Downloading recipe image before save", category: .network, metadata: ["url": imageURLString])
                let (data, _) = try await URLSession.shared.data(from: imageURL)

                if let image = UIImage(data: data) {
                    let fileName = try await imageStorageService.saveImage(image, recipeId: recipe.id)
                    recipe.imageFileName = fileName
                    Log.info("Recipe image downloaded and saved", category: .storage, metadata: ["fileName": fileName])
                } else {
                    Log.warning("Failed to create UIImage from downloaded data", category: .storage)
                }
            } catch {
                Log.error("Failed to download recipe image", category: .network, metadata: ["error": error.localizedDescription])
                // Continue without image - don't fail the import
            }
        }

        // Create snapshot for edit tracking
        recipe.createSnapshot()

        // Save to database immediately (now with image if available)
        do {
            try modelContext.save()
        } catch {
            await MainActor.run {
                isSaving = false
            }
            toastManager.error(
                title: "Failed to save recipe",
                message: error.localizedDescription
            )
            return
        }

        // Attribute source
        if let urlString = recipe.sourceURL {
            let domain = KnownSource.extractDomain(from: urlString)
            ServiceContainer.shared.resolve(SourceAttributionService.self).registerSource(
                name: domain ?? "Unknown Website",
                kind: .website,
                domain: domain,
                discoveryMethod: "url_import",
                recipe: recipe
            )
        }

        // Show success and dismiss immediately
        toastManager.success(
            title: "Recipe imported!",
            message: "Added '\(recipe.title)' to your collection"
        )

        await MainActor.run {
            isSaving = false
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            // Notify coordinator of recipe creation for cross-tab navigation
            tabCoordinator.didCreateRecipe()

            // Dismiss immediately
            dismiss()
        }

        // Continue heavy operations in background (non-blocking)
        let recipeId = recipe.id
        let ingredientTexts = imported.ingredients
        let container = modelContext.container

        Task.detached {
            // Create background context
            let backgroundContext = ModelContext(container)

            // Fetch recipe in background context
            let descriptor = FetchDescriptor<Recipe>(predicate: #Predicate { $0.id == recipeId })
            guard let backgroundRecipe = try? backgroundContext.fetch(descriptor).first else {
                Log.error("Failed to fetch recipe in background", category: .database)
                return
            }

            // Parse ingredients with AI in background
            await RecipeImportView.parseIngredientsInBackground(
                recipe: backgroundRecipe,
                ingredientTexts: ingredientTexts,
                context: backgroundContext
            )

            // Image already downloaded before save - skip background download

            // Sync to Firebase in background
            await RecipeImportView.syncToFirebaseInBackground(
                recipe: backgroundRecipe,
                context: backgroundContext
            )
        }
    }

    // MARK: - Background Processing

    /// Parse ingredients with AI in background after recipe is saved
    private static func parseIngredientsInBackground(
        recipe: Recipe,
        ingredientTexts: [String],
        context: ModelContext
    ) async {
        // Skip if ingredients are already parsed (immediate parsing completed)
        if let ingredients = recipe.ingredients {
            let parsedCount = ingredients.filter { $0.quantity != nil }.count
            if parsedCount > 0 {
                Log.info("Skipping background parsing - ingredients already parsed", category: .general, metadata: [
                    "parsedCount": parsedCount,
                    "totalCount": ingredients.count
                ])
                return
            }
        }

        Log.info("Starting background ingredient parsing", category: .general, metadata: ["count": ingredientTexts.count])

        // Get services from container
        let aiIngredientParser: AIIngredientParser = ServiceContainer.shared.resolve(AIIngredientParser.self)
        let analytics: AnalyticsService = ServiceContainer.shared.resolve(AnalyticsService.self)
        let aiConfig: AIConfiguration = ServiceContainer.shared.resolve(AIConfiguration.self)

        // Use AI batch parsing for better efficiency
        let parsedIngredients: [(quantity: Double?, quantityMax: Double?, unit: String?, name: String, preparation: String?)]

        do {
            parsedIngredients = try await aiIngredientParser.parseBatchToTuple(ingredientTexts)
            Log.info("AI parsing successful", category: .general)
        } catch {
            Log.warning("Batch parsing encountered an error, using fallback", category: .general, metadata: ["error": error.localizedDescription])
            parsedIngredients = ingredientTexts.map {
                let result = IngredientParser.parse($0)
                return (result.0, result.1, result.2, result.3, nil as String?)
            }
        }

        // Update existing ingredients with parsed data
        await MainActor.run {
            guard let ingredients = recipe.ingredients else { return }

            for (index, ingredient) in ingredients.enumerated() {
                guard index < parsedIngredients.count else { break }
                let parsed = parsedIngredients[index]

                ingredient.name = parsed.name
                ingredient.quantity = parsed.quantity
                ingredient.quantityMax = parsed.quantityMax
                ingredient.unit = parsed.unit
                ingredient.preparation = parsed.preparation
            }

            // Save updated ingredients
            do {
                try context.save()
                Log.info("Background ingredient parsing complete", category: .general)
            } catch {
                Log.error("Failed to save parsed ingredients", category: .database, metadata: ["error": error.localizedDescription])
            }
        }

        // Track analytics
        analytics.track(event: .recipeImported, properties: [
            "source": "url",
            "ingredient_count": ingredientTexts.count,
            "used_ai_parsing": aiConfig.enableAIParsing
        ])
    }

    /// Download recipe image in background after recipe is saved
    private static func downloadAndSaveImageInBackground(
        from url: URL,
        recipeId: UUID,
        context: ModelContext
    ) async {
        Log.info("Starting background image download", category: .network, metadata: ["url": url.absoluteString])

        // Get service from container
        let imageStorageService: ImageStorageService = ServiceContainer.shared.resolve(ImageStorageService.self)

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            Log.debug("Downloaded image data", category: .network, metadata: ["bytes": data.count])

            guard let image = UIImage(data: data) else {
                Log.warning("Failed to create UIImage from downloaded data", category: .storage)
                return
            }

            Log.debug("Created UIImage from data", category: .storage)
            let fileName = try await imageStorageService.saveImage(image, recipeId: recipeId)
            Log.info("Saved image", category: .storage, metadata: ["fileName": fileName])

            // Update recipe with image filename
            await MainActor.run {
                // Fetch recipe in this context
                let descriptor = FetchDescriptor<Recipe>(predicate: #Predicate { $0.id == recipeId })
                guard let recipe = try? context.fetch(descriptor).first else {
                    Log.error("Failed to fetch recipe for image update", category: .database)
                    return
                }

                recipe.imageFileName = fileName
                Log.debug("Set recipe image filename", category: .database, metadata: ["fileName": fileName])

                do {
                    try context.save()
                    Log.info("Background image download complete", category: .storage)
                } catch {
                    Log.error("Failed to save image filename", category: .database, metadata: ["error": error.localizedDescription])
                }
            }
        } catch {
            Log.warning("Failed to download recipe image", category: .network, metadata: ["error": error.localizedDescription])
        }
    }

    /// Sync recipe to Firebase in background after recipe is saved
    private static func syncToFirebaseInBackground(
        recipe: Recipe,
        context: ModelContext
    ) async {
        // Get services from container
        let backendConfig: BackendConfig = ServiceContainer.shared.resolve(BackendConfig.self)
        let firebaseSync: any FirebaseSyncServiceProtocol = ServiceContainer.shared.resolve((any FirebaseSyncServiceProtocol).self)

        guard backendConfig.isFirebaseActive else {
            Log.debug("Firebase sync skipped (not active)", category: .firebase)
            return
        }

        Log.info("Starting background Firebase sync", category: .firebase, metadata: ["recipeId": recipe.id.uuidString])

        do {
            // Upload recipe
            try await firebaseSync.uploadRecipe(recipe)
            Log.info("Recipe uploaded to Firebase", category: .firebase)

            // Upload image if available
            if recipe.imageFileName != nil {
                do {
                    if let imageURL = try await firebaseSync.uploadImage(for: recipe) {
                        await MainActor.run {
                            recipe.firebaseImageURL = imageURL
                            try? context.save()
                        }
                        Log.info("Image uploaded to Firebase", category: .firebase, metadata: ["url": imageURL])
                    }
                } catch {
                    Log.warning("Failed to upload image to Firebase", category: .firebase, metadata: ["error": error.localizedDescription])
                }
            }

            Log.info("Background Firebase sync complete", category: .firebase)
        } catch {
            Log.warning("Failed to sync recipe to Firebase", category: .firebase, metadata: ["error": error.localizedDescription])
            // Don't fail - local save succeeded
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
