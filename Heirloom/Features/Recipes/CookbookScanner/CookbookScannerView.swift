import SwiftUI
import VisionKit
import Vision
import PhotosUI

struct CookbookScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.firebaseSync) private var firebaseSync

    // Using concrete types for now since views call implementation-specific methods
    private var aiRecipeExtractor: AIRecipeExtractor { ServiceContainer.shared.resolve(AIRecipeExtractor.self) }
    private var aiIngredientParser: AIIngredientParser { ServiceContainer.shared.resolve(AIIngredientParser.self) }
    private var imageStorageService: ImageStorageService { ServiceContainer.shared.resolve(ImageStorageService.self) }
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }
    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }
    private var backendConfig: BackendConfig { ServiceContainer.shared.resolve(BackendConfig.self) }

    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var recognizedText: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showMultiRecipeSheet = false
    @State private var multiRecipeResult: AIRecipeExtractor.MultiRecipeExtractionResult?
    @State private var errorMessage: String?
    @State private var imageSource: ImageSource = .camera

    // Progress tracking
    @State private var processingStep: ProcessingStep = .preparing

    enum ImageSource {
        case camera
        case photoLibrary
    }

    enum ProcessingStep {
        case preparing
        case optimizing
        case detecting
        case extracting
        case complete

        var stepNumber: Int {
            switch self {
            case .preparing: return 0
            case .optimizing: return 1
            case .detecting: return 2
            case .extracting: return 3
            case .complete: return 4
            }
        }

        var totalSteps: Int { 3 }

        var description: String {
            switch self {
            case .preparing: return "Preparing..."
            case .optimizing: return "Optimizing image quality..."
            case .detecting: return "Detecting recipes..."
            case .extracting: return "Extracting recipe details..."
            case .complete: return "Complete!"
            }
        }

        var progress: Double {
            return Double(stepNumber) / Double(totalSteps + 1)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let image = capturedImage {
                    // Preview captured image
                    previewSection(image: image)
                } else {
                    // Instructions
                    instructionsSection
                }
            }
            .navigationTitle("Scan Cookbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if capturedImage != nil && !isProcessing {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Extract Recipe") {
                            processImage()
                        }
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView(capturedImage: $capturedImage)
                    .onDisappear {
                        if capturedImage != nil {
                            imageSource = .camera
                        }
                    }
            }
            .sheet(isPresented: $showMultiRecipeSheet) {
                if let result = multiRecipeResult {
                    RecipeSelectionView(
                        recipes: result.recipes,
                        sourceImage: result.sourceImage
                    )
                }
            }
            .alert("Scan Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            capturedImage = image
                            imageSource = .photoLibrary
                            selectedPhotoItem = nil
                        }
                    }
                }
            }
        }
    }

    // MARK: - Instructions Section

    private var instructionsSection: some View {
        VStack(spacing: HeirloomSpacing.xl) {
            Spacer()

            // Icon
            Image(systemName: "book.pages")
                .font(.system(size: 80))
                .foregroundStyle(HeirloomColors.tomato)

            // Instructions
            VStack(spacing: HeirloomSpacing.md) {
                Text("Capture Recipe Pages")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)

                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    instructionRow(
                        icon: "1.circle.fill",
                        text: "Take a clear photo of the recipe page"
                    )
                    instructionRow(
                        icon: "2.circle.fill",
                        text: "Make sure text is readable and well-lit"
                    )
                    instructionRow(
                        icon: "3.circle.fill",
                        text: "We'll extract the recipe text automatically"
                    )
                }
                .padding(.horizontal, HeirloomSpacing.xl)
            }

            Spacer()

            // Action Buttons
            VStack(spacing: HeirloomSpacing.md) {
                // Camera Button
                Button {
                    showCamera = true
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Open Camera")
                    }
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(HeirloomColors.tomato)
                    .cornerRadius(12)
                }

                // Photo Library Button
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Choose from Photos")
                    }
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.tomato)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(HeirloomColors.tomato, lineWidth: 2)
                    )
                }
            }
            .padding(.horizontal, HeirloomSpacing.lg)
            .padding(.bottom, HeirloomSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HeirloomColors.appBackground)
    }

    private func instructionRow(icon: String, text: String) -> some View {
        HStack(spacing: HeirloomSpacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(HeirloomColors.tomato)
                .frame(width: 30)

            Text(text)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)

            Spacer()
        }
    }

    // MARK: - Preview Section

    private func previewSection(image: UIImage) -> some View {
        VStack(spacing: 0) {
            // Image preview with better rendering
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width)
                        .clipped()
                }
            }
            .frame(maxHeight: .infinity)
            .background(Color.black.opacity(0.05))

            // Processing overlay with deterministic progress
            if isProcessing {
                VStack(spacing: HeirloomSpacing.md) {
                    // Progress bar
                    ProgressView(value: processingStep.progress)
                        .progressViewStyle(.linear)
                        .tint(HeirloomColors.tomato)

                    // Step indicator
                    HStack(spacing: HeirloomSpacing.xs) {
                        Text("Step \(processingStep.stepNumber)/\(processingStep.totalSteps)")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.tomato)
                            .fontWeight(.semibold)

                        Spacer()
                    }

                    // Current step description
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)

                        Text(processingStep.description)
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.secondaryText)

                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(HeirloomColors.cream)
            } else {
                // Actions
                VStack(spacing: HeirloomSpacing.sm) {
                    Button(imageSource == .camera ? "Retake Photo" : "Replace Photo") {
                        capturedImage = nil
                        processingStep = .preparing
                        errorMessage = nil
                        showCamera = true
                    }
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(HeirloomColors.cream)
            }
        }
    }

    // MARK: - Vision API Processing

    private func processImage() {
        guard let image = capturedImage else { return }

        isProcessing = true
        processingStep = .optimizing

        Task {
            do {
                // Step 1: Optimizing image (happens in AnthropicAIService)
                await MainActor.run {
                    processingStep = .detecting
                }

                // Step 2: Detect recipes with bounding boxes (vision API)
                Log.info("Detecting recipes with vision API", category: .ocr)
                let detected = try await aiRecipeExtractor.detectRecipes(from: image)

                Log.info("Found recipes in image", category: .ocr, metadata: ["count": detected.count])
                for (index, recipe) in detected.enumerated() {
                    Log.debug("Detected recipe", category: .ocr, metadata: ["index": index + 1, "title": recipe.title, "confidence": recipe.confidence.rawValue])
                }

                // Step 3: Extract each recipe using vision API + bounding box
                await MainActor.run {
                    processingStep = .extracting
                }

                Log.info("Extracting recipes with vision API", category: .ocr)
                let result = try await aiRecipeExtractor.extractRecipesFromImage(
                    image: image,
                    detectedRecipes: detected
                )

                await MainActor.run {
                    processingStep = .complete
                    isProcessing = false

                    // Success feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)

                    Log.info("Processing complete", category: .ocr, metadata: ["count": result.count])

                    // Route based on recipe count
                    if result.count == 0 {
                        // No recipes detected - show error
                        errorMessage = "No recipes detected in the image. Please try again with a clearer photo."
                        Log.warning("No recipes found in image", category: .ocr)

                    } else if result.count == 1 {
                        // Single recipe - auto-import directly (faster UX)
                        let recipe = result.recipes[0]
                        createRecipeFromExtraction(recipe, image: image)

                        // Track analytics
                        analytics.track(event: .recipeImported, properties: [
                            "source": "cookbook_scan",
                            "extraction_method": "vision_api",
                            "used_ai_extraction": true,
                            "recipe_count": 1,
                            "ingredient_count": recipe.ingredients.count,
                            "instruction_count": recipe.instructions.count
                        ])

                        Log.info("Single recipe auto-imported", category: .ocr, metadata: ["title": recipe.title])

                    } else {
                        // Multiple recipes - show RecipeSelectionView (matches web demo behavior)
                        multiRecipeResult = result
                        showMultiRecipeSheet = true

                        // Track analytics
                        analytics.track(event: .recipeScanned, properties: [
                            "source": "cookbook_scan",
                            "recipe_count": result.count,
                            "multi_recipe": true
                        ])

                        Log.info("Multiple recipes extracted", category: .ocr)
                        for (index, recipe) in result.recipes.enumerated() {
                            Log.debug("Extracted recipe details", category: .ocr, metadata: [
                                "index": index + 1,
                                "title": recipe.title,
                                "ingredientCount": recipe.ingredients.count,
                                "instructionCount": recipe.instructions.count
                            ])
                        }
                    }
                }

            } catch {
                await MainActor.run {
                    processingStep = .preparing
                    isProcessing = false

                    // Error feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)

                    errorMessage = error.localizedDescription

                    Log.error("Processing failed", category: .ocr, error: error)
                }
            }
        }
    }

    private func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        try requestHandler.perform([request])

        guard let observations = request.results else {
            throw OCRError.noTextFound
        }

        let recognizedStrings = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }

        return recognizedStrings.joined(separator: "\n")
    }

    // MARK: - Recipe Creation

    private func createRecipeFromExtraction(_ extracted: AIRecipeExtractor.ExtractedRecipe, image: UIImage) {
        // Create Recipe object
        let recipe = Recipe(
            title: extracted.title,
            sourceType: .cookbook,
            instructions: extracted.instructions,
            servings: extracted.servings,
            prepTime: extracted.prepTime,
            cookTime: extracted.cookTime
        )

        if let notes = extracted.notes {
            recipe.notes = notes
        }

        // Set provenance metadata for scanned recipes
        recipe.provenance = ProvenanceMetadata(
            sourceType: .scanned,
            sourceAttribution: "Scanned from cookbook",
            generation: 0
        )

        // Insert recipe first
        modelContext.insert(recipe)

        // Parse and create ingredients with AI
        Task {
            await createIngredients(for: recipe, ingredientTexts: extracted.ingredients)

            // Save the image
            await saveRecipeImage(image, for: recipe)

            // Save to database
            do {
                try modelContext.save()

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

                        Log.info("Scanned recipe synced to Firebase", category: .firebase, metadata: ["title": recipe.title])
                    } catch {
                        Log.warning("Failed to sync scanned recipe to Firebase", category: .firebase, metadata: ["error": error.localizedDescription])
                        // Don't fail - local save succeeded
                    }
                }

                toastManager.success(
                    title: "Recipe Added!",
                    message: "'\(recipe.title)' has been added to your collection"
                )

                // Dismiss scanner
                dismiss()

            } catch {
                toastManager.error(
                    title: "Failed to save recipe",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func createIngredients(for recipe: Recipe, ingredientTexts: [String]) async {
        // Use AI batch parsing for better accuracy
        let parsedIngredients: [(quantity: Double?, quantityMax: Double?, unit: String?, name: String)]

        do {
            parsedIngredients = try await aiIngredientParser.parseBatchToTuple(ingredientTexts)
        } catch {
            Log.warning("AI ingredient parsing failed, using fallback", category: .general, metadata: ["error": error.localizedDescription])
            parsedIngredients = ingredientTexts.map { IngredientParser.parse($0) }
        }

        // Create Ingredient objects
        for (index, text) in ingredientTexts.enumerated() {
            let parsed = parsedIngredients[index]

            let ingredient = Ingredient(
                originalText: text,
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

    private func saveRecipeImage(_ image: UIImage, for recipe: Recipe) async {
        do {
            let fileName = try await imageStorageService.saveImage(image, recipeId: recipe.id)
            await MainActor.run {
                recipe.imageFileName = fileName
                Log.info("Saved recipe image", category: .storage, metadata: ["fileName": fileName])
            }
        } catch {
            Log.warning("Failed to save recipe image", category: .storage, metadata: ["error": error.localizedDescription])
        }
    }

    // MARK: - Text Extraction (Legacy - kept for fallback)

    private func extractIngredients(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var ingredients: [String] = []
        var inIngredientsSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Check for section headers
            let lowercased = trimmed.lowercased()
            if lowercased.contains("ingredient") {
                inIngredientsSection = true
                continue
            } else if lowercased.contains("instruction") ||
                      lowercased.contains("direction") ||
                      lowercased.contains("method") ||
                      lowercased.contains("steps") {
                inIngredientsSection = false
                continue
            }

            // Add to ingredients if in section
            if inIngredientsSection {
                // Clean up common OCR artifacts
                let cleaned = trimmed
                    .replacingOccurrences(of: "^[•\\-\\*]\\s*", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)

                if !cleaned.isEmpty {
                    ingredients.append(cleaned)
                }
            }
        }

        return ingredients
    }

    private func extractInstructions(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var instructions: [String] = []
        var inInstructionsSection = false
        var currentInstruction = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Check for section headers
            let lowercased = trimmed.lowercased()
            if lowercased.contains("instruction") ||
               lowercased.contains("direction") ||
               lowercased.contains("method") ||
               lowercased.contains("steps") {
                inInstructionsSection = true
                continue
            } else if lowercased.contains("ingredient") ||
                      lowercased.contains("notes") {
                inInstructionsSection = false
                if !currentInstruction.isEmpty {
                    instructions.append(currentInstruction.trimmingCharacters(in: .whitespaces))
                    currentInstruction = ""
                }
                continue
            }

            // Add to instructions if in section
            if inInstructionsSection {
                // Check if line starts with a number (new step)
                if trimmed.range(of: "^\\d+[\\.\\)]\\s*", options: .regularExpression) != nil {
                    // Save previous instruction if exists
                    if !currentInstruction.isEmpty {
                        instructions.append(currentInstruction.trimmingCharacters(in: .whitespaces))
                    }
                    // Start new instruction (remove number prefix)
                    currentInstruction = trimmed.replacingOccurrences(
                        of: "^\\d+[\\.\\)]\\s*",
                        with: "",
                        options: .regularExpression
                    )
                } else {
                    // Continue current instruction
                    if !currentInstruction.isEmpty {
                        currentInstruction += " "
                    }
                    currentInstruction += trimmed
                }
            }
        }

        // Add final instruction
        if !currentInstruction.isEmpty {
            instructions.append(currentInstruction.trimmingCharacters(in: .whitespaces))
        }

        return instructions
    }

    enum OCRError: LocalizedError {
        case invalidImage
        case noTextFound

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "Invalid image format"
            case .noTextFound:
                return "No text found in image"
            }
        }
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.capturedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    CookbookScannerView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
