import SwiftUI
import SwiftData

/// Review and edit OCR results before saving as recipe
struct OCRReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.firebaseSync) private var firebaseSync

    // Using concrete type for now since view calls implementation-specific methods
    private var aiIngredientParser: AIIngredientParser { ServiceContainer.shared.resolve(AIIngredientParser.self) }
    private var imageStorageService: ImageStorageService { ServiceContainer.shared.resolve(ImageStorageService.self) }
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }
    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }
    private var backendConfig: BackendConfig { ServiceContainer.shared.resolve(BackendConfig.self) }

    let ocrResult: EnhancedOCRService.OCRResult
    let parsedRecipe: RecipeStructureParser.ParsedRecipe
    let originalImage: UIImage?

    @State private var title: String
    @State private var ingredients: [String]
    @State private var instructions: [String]
    @State private var servings: String
    @State private var prepTime: String
    @State private var cookTime: String
    @State private var isSaving = false
    @State private var showImagePreview = false

    init(
        ocrResult: EnhancedOCRService.OCRResult,
        parsedRecipe: RecipeStructureParser.ParsedRecipe,
        originalImage: UIImage?
    ) {
        self.ocrResult = ocrResult
        self.parsedRecipe = parsedRecipe
        self.originalImage = originalImage

        // Initialize state with parsed values
        _title = State(initialValue: parsedRecipe.title ?? "")
        _ingredients = State(initialValue: parsedRecipe.ingredients)
        _instructions = State(initialValue: parsedRecipe.instructions)
        _servings = State(initialValue: parsedRecipe.servings ?? "")
        _prepTime = State(initialValue: parsedRecipe.prepTime ?? "")
        _cookTime = State(initialValue: parsedRecipe.cookTime ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
                    // Quality Banner
                    qualityBanner

                    // Image Preview (if available)
                    if originalImage != nil {
                        imagePreviewSection
                    }

                    // Title Section
                    titleSection

                    // Metadata Section
                    metadataSection

                    // Ingredients Section
                    ingredientsSection

                    // Instructions Section
                    instructionsSection
                }
                .padding(HeirloomSpacing.md)
            }
            .background(HeirloomColors.appBackground)
            .navigationTitle("Review & Edit")
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
                    .disabled(isSaving || title.isEmpty)
                }
            }
            .sheet(isPresented: $showImagePreview) {
                imagePreviewSheet
            }
        }
    }

    // MARK: - Quality Banner

    private var qualityBanner: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: ocrResult.quality.icon)
                    .foregroundStyle(colorForQuality(ocrResult.quality))

                Text("OCR Quality: \(ocrResult.quality.displayName)")
                    .font(HeirloomFonts.subheadline)
                    .foregroundStyle(HeirloomColors.primaryText)

                Spacer()

                Text(ocrResult.confidencePercentage)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            // Parse quality
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(colorForParseQuality(parsedRecipe.confidence))

                Text("Parse Quality: \(parsedRecipe.qualityDescription)")
                    .font(HeirloomFonts.subheadline)
                    .foregroundStyle(HeirloomColors.primaryText)

                Spacer()

                Text(parsedRecipe.confidencePercentage)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            // Detected summary
            Text(parsedRecipe.summary)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cream)
        .cornerRadius(12)
    }

    // MARK: - Image Preview Section

    private var imagePreviewSection: some View {
        Button {
            showImagePreview = true
        } label: {
            if let image = originalImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                            .stroke(HeirloomColors.warmGray.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text("Recipe Title")
                .font(HeirloomFonts.subheadline)
                .foregroundStyle(HeirloomColors.secondaryText)

            TextField("Enter recipe title", text: $title, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(HeirloomFonts.body)
        }
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("Details")
                .font(HeirloomFonts.subheadline)
                .foregroundStyle(HeirloomColors.secondaryText)

            HStack(spacing: HeirloomSpacing.md) {
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    Text("Servings")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)

                    TextField("4", text: $servings)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }

                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    Text("Prep Time")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)

                    TextField("15 min", text: $prepTime)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    Text("Cook Time")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)

                    TextField("30 min", text: $cookTime)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    // MARK: - Ingredients Section

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Text("Ingredients (\(ingredients.count))")
                    .font(HeirloomFonts.subheadline)
                    .foregroundStyle(HeirloomColors.secondaryText)

                Spacer()

                Button {
                    ingredients.append("")
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(HeirloomColors.tomato)
                }
            }

            VStack(spacing: HeirloomSpacing.sm) {
                ForEach(Array(ingredients.enumerated()), id: \.offset) { index, ingredient in
                    HStack(spacing: HeirloomSpacing.sm) {
                        TextField("Ingredient", text: $ingredients[index], axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .font(HeirloomFonts.body)

                        Button {
                            ingredients.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Instructions Section

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Text("Instructions (\(instructions.count))")
                    .font(HeirloomFonts.subheadline)
                    .foregroundStyle(HeirloomColors.secondaryText)

                Spacer()

                Button {
                    instructions.append("")
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(HeirloomColors.tomato)
                }
            }

            VStack(spacing: HeirloomSpacing.sm) {
                ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
                        Text("\(index + 1)")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.buttonTextLight)
                            .frame(width: 28, height: 28)
                            .background(HeirloomColors.tomato)
                            .cornerRadius(14)

                        TextField("Step \(index + 1)", text: $instructions[index], axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .font(HeirloomFonts.body)
                            .lineLimit(5...10)

                        Button {
                            instructions.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Image Preview Sheet

    private var imagePreviewSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = originalImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .navigationTitle("Scanned Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showImagePreview = false
                    }
                }
            }
        }
    }

    // MARK: - Save Recipe

    private func saveRecipe() async {
        isSaving = true
        defer { isSaving = false }

        // Create Recipe object
        let recipe = Recipe(
            title: title,
            sourceType: .scan,  // Scanned from recipe card
            instructions: instructions.filter { !$0.isEmpty },
            servings: servings.isEmpty ? nil : servings,
            prepTime: prepTime.isEmpty ? nil : prepTime,
            cookTime: cookTime.isEmpty ? nil : cookTime
        )

        // Add notes about OCR quality
        var notes = ""
        if ocrResult.quality != .excellent {
            notes += "OCR Quality: \(ocrResult.quality.displayName) (\(ocrResult.confidencePercentage))\n"
        }
        if !parsedRecipe.isComplete {
            notes += "Parsed: \(parsedRecipe.summary)\n"
        }
        recipe.notes = notes.isEmpty ? nil : notes

        // Insert recipe first
        modelContext.insert(recipe)

        // Parse ingredients with AI (batch parsing for efficiency)
        await parseAndSaveIngredients(recipe: recipe, ingredientTexts: ingredients.filter { !$0.isEmpty })

        // Save scanned image
        if let image = originalImage {
            await saveImage(image, for: recipe)
        }

        // Create snapshot for edit tracking
        recipe.createSnapshot()

        // Save to database
        do {
            try modelContext.save()

            // Route to "From Photos" collection
            let router = CollectionRouter(modelContext: modelContext)
            router.routePhotoImport(recipe)

            // Sync to Firebase if active
            if backendConfig.isFirebaseActive {
                do {
                    try await firebaseSync.uploadRecipe(recipe)

                    // Upload scanned image if exists
                    if recipe.imageFileName != nil {
                        if let imageURL = try await firebaseSync.uploadImage(for: recipe) {
                            recipe.firebaseImageURL = imageURL
                            try? modelContext.save()
                        }
                    }

                    Log.info("Scanned recipe synced to Firebase", category: .firebase, metadata: ["title": recipe.title, "recipeId": recipe.id])
                } catch {
                    Log.warning("Failed to sync scanned recipe to Firebase", category: .firebase, metadata: ["error": error.localizedDescription, "title": recipe.title])
                }
            }

            await MainActor.run {
                toastManager.success(
                    title: "Recipe saved!",
                    message: "Scanned '\(recipe.title)'"
                )

                analytics.track(event: .recipeScanned, properties: [
                    "source": "ocr_scan",
                    "ocr_quality": ocrResult.quality.displayName,
                    "ocr_confidence": ocrResult.overallConfidence,
                    "parse_confidence": parsedRecipe.confidence,
                    "ingredient_count": ingredients.count,
                    "instruction_count": instructions.count,
                    "has_image": originalImage != nil
                ])

                // Success feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                dismiss()
            }
        } catch {
            await MainActor.run {
                toastManager.error(
                    title: "Failed to save recipe",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func parseAndSaveIngredients(recipe: Recipe, ingredientTexts: [String]) async {
        // Use AI batch parsing for better efficiency
        let parsedIngredients: [(quantity: Double?, quantityMax: Double?, unit: String?, name: String, preparation: String?)]

        do {
            parsedIngredients = try await aiIngredientParser.parseBatchToTuple(ingredientTexts)
        } catch {
            Log.warning("Batch ingredient parsing failed, falling back to local parser", category: .ocr, metadata: ["error": error.localizedDescription, "ingredientCount": ingredientTexts.count])
            parsedIngredients = ingredientTexts.map {
                let result = IngredientParser.parse($0)
                return (result.0, result.1, result.2, result.3, nil as String?)
            }
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
            ingredient.preparation = parsed.preparation
            ingredient.recipe = recipe
            modelContext.insert(ingredient)
            ingredients.append(ingredient)
        }

        recipe.ingredients = ingredients
    }

    private func saveImage(_ image: UIImage, for recipe: Recipe) async {
        do {
            let fileName = try await imageStorageService.saveImage(image, recipeId: recipe.id)
            await MainActor.run {
                recipe.imageFileName = fileName
            }
        } catch {
            Log.error("Failed to save scanned image", category: .storage, metadata: ["error": error.localizedDescription, "recipeId": recipe.id.uuidString])
        }
    }

    // MARK: - Helper Methods

    private func colorForQuality(_ quality: EnhancedOCRService.RecognitionQuality) -> Color {
        switch quality {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }

    private func colorForParseQuality(_ confidence: Double) -> Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .blue
        } else if confidence >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    OCRReviewView(
        ocrResult: EnhancedOCRService.OCRResult(
            recognizedText: "Sample recipe text",
            textRegions: [],
            overallConfidence: 0.92,
            quality: .excellent,
            textType: .printed,
            processingTime: 1.2
        ),
        parsedRecipe: RecipeStructureParser.ParsedRecipe(
            title: "Chocolate Chip Cookies",
            ingredients: ["2 cups flour", "1 cup sugar", "1/2 cup butter"],
            instructions: ["Mix ingredients", "Bake at 350°F"],
            servings: "24 cookies",
            prepTime: "15 minutes",
            cookTime: "12 minutes",
            confidence: 0.85
        ),
        originalImage: nil
    )
    .modelContainer(for: Recipe.self, inMemory: true)
}
