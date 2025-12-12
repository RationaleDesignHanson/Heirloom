import SwiftUI
import VisionKit
import Vision

struct CookbookScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var recognizedText: String = ""

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
            // Image preview
            ScrollView {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)

            // Processing overlay
            if isProcessing {
                VStack(spacing: HeirloomSpacing.md) {
                    ProgressView()
                    Text("Extracting text...")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(HeirloomColors.cream)
            } else {
                // Actions
                VStack(spacing: HeirloomSpacing.sm) {
                    Button("Retake Photo") {
                        capturedImage = nil
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

    // MARK: - OCR Processing

    private func processImage() {
        guard let image = capturedImage else { return }

        isProcessing = true

        Task {
            do {
                // Step 1: Extract raw text using OCR
                let text = try await recognizeText(in: image)
                recognizedText = text

                // Step 2: Use AI to structure the recipe (if enabled)
                let extractedRecipe = try await AIRecipeExtractor.shared.extractRecipe(from: text)

                await MainActor.run {
                    isProcessing = false

                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)

                    // Create recipe from AI-extracted data
                    createRecipeFromExtraction(extractedRecipe, image: image)

                    // Track analytics
                    AnalyticsService.shared.track(event: .recipeImported, properties: [
                        "source": "cookbook_scan",
                        "text_length": text.count,
                        "used_ai_extraction": AIConfiguration.shared.enableAIEnhancement,
                        "ingredient_count": extractedRecipe.ingredients.count,
                        "instruction_count": extractedRecipe.instructions.count
                    ])
                }
            } catch {
                await MainActor.run {
                    isProcessing = false

                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)

                    ToastManager.shared.error(
                        title: "Processing Failed",
                        message: "Couldn't extract recipe from image. Try a clearer photo."
                    )
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

                ToastManager.shared.success(
                    title: "Recipe Added!",
                    message: "'\(recipe.title)' has been added to your collection"
                )

                // Dismiss scanner
                dismiss()

            } catch {
                ToastManager.shared.error(
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
            parsedIngredients = try await AIIngredientParser.shared.parseBatch(ingredientTexts)
        } catch {
            print("⚠️ AI ingredient parsing failed, using fallback: \(error.localizedDescription)")
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
            let fileName = try await ImageStorageService.shared.saveImage(image, recipeId: recipe.id)
            recipe.imageFileName = fileName
            print("✅ Saved recipe image: \(fileName)")
        } catch {
            print("⚠️ Failed to save recipe image: \(error.localizedDescription)")
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
