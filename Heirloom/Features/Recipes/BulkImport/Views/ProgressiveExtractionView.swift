import SwiftUI
import SwiftData

// Import ExtractedRecipe from AIRecipeExtractor
// (will be in scope when AIRecipeExtractor.swift is compiled first)

/// Progressive enhancement UI for low-confidence recipe extractions
/// Shows confidence score, preview, and enhancement options
struct ProgressiveExtractionView: View {

    // MARK: - Dependencies

    let extractedRecipe: ExtractedRecipe
    let sourceImage: UIImage
    @Binding var isPresented: Bool
    let onAccept: (ExtractedRecipe) -> Void
    let context: ModelContext

    // MARK: - State

    @State private var currentExtraction: ExtractedRecipe
    @State private var isEnhancing = false
    @State private var showManualCorrection = false
    @State private var showRescanOptions = false
    @State private var enhancementError: String?

    // MARK: - Services

    @State private var aiExtractor: AIRecipeExtractor?

    // MARK: - Init

    init(
        extractedRecipe: ExtractedRecipe,
        sourceImage: UIImage,
        isPresented: Binding<Bool>,
        onAccept: @escaping (ExtractedRecipe) -> Void,
        context: ModelContext
    ) {
        self.extractedRecipe = extractedRecipe
        self.sourceImage = sourceImage
        self._isPresented = isPresented
        self.onAccept = onAccept
        self.context = context
        self._currentExtraction = State(initialValue: extractedRecipe)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.lg) {
                    // Confidence indicator
                    confidenceCard

                    // Recipe preview
                    recipePreviewCard

                    // Enhancement options (if low confidence)
                    if extractionConfidence < 0.8 {
                        enhancementOptionsCard
                    }

                    // Error message
                    if let error = enhancementError {
                        errorCard(error)
                    }

                    // Accept button
                    acceptButton
                }
                .padding(HeirloomSpacing.md)
            }
            .background(HeirloomColors.appBackground)
            .navigationTitle("Review Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .task {
                // Load AI extractor service
                aiExtractor = ServiceContainer.shared.resolve(AIRecipeExtractor.self)
            }
        }
    }

    // MARK: - View Components

    private var confidenceCard: some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: confidenceIcon)
                .font(.title2)
                .foregroundStyle(confidenceColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("Extraction Confidence")
                    .font(HeirloomFonts.caption)
                    .foregroundStyle(HeirloomColors.secondaryText)

                Text("\(Int(extractionConfidence * 100))%")
                    .font(HeirloomFonts.title3Bold)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Spacer()

            // Confidence indicator bar
            confidenceBar
        }
        .padding(HeirloomSpacing.md)
        .background(confidenceColor.opacity(0.1))
        .cornerRadius(HeirloomSpacing.cardCornerRadius)
    }

    private var confidenceBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)

                // Progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(confidenceColor)
                    .frame(width: geometry.size.width * extractionConfidence, height: 8)
            }
        }
        .frame(width: 100, height: 8)
    }

    private var recipePreviewCard: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("Recipe Preview")
                .font(HeirloomFonts.headlineBold)
                .foregroundStyle(HeirloomColors.primaryText)

            Divider()

            // Title
            VStack(alignment: .leading, spacing: 4) {
                Text("Title")
                    .font(HeirloomFonts.captionBold)
                    .foregroundStyle(HeirloomColors.secondaryText)
                Text(currentExtraction.title)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            // Ingredients
            VStack(alignment: .leading, spacing: 8) {
                Text("Ingredients (\(currentExtraction.ingredients.count))")
                    .font(HeirloomFonts.captionBold)
                    .foregroundStyle(HeirloomColors.secondaryText)

                ForEach(Array(currentExtraction.ingredients.prefix(5).enumerated()), id: \.offset) { index, ingredient in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(HeirloomColors.warmGray)
                            .frame(width: 4, height: 4)
                        Text(ingredient)
                            .font(HeirloomFonts.caption)
                            .foregroundStyle(HeirloomColors.primaryText)
                    }
                }

                if currentExtraction.ingredients.count > 5 {
                    Text("+ \(currentExtraction.ingredients.count - 5) more")
                        .font(HeirloomFonts.caption)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .padding(.leading, 12)
                }
            }

            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Instructions (\(currentExtraction.instructions.count))")
                    .font(HeirloomFonts.captionBold)
                    .foregroundStyle(HeirloomColors.secondaryText)

                ForEach(Array(currentExtraction.instructions.prefix(3).enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(HeirloomFonts.captionBold)
                            .foregroundStyle(HeirloomColors.warmGray)
                        Text(instruction)
                            .font(HeirloomFonts.caption)
                            .foregroundStyle(HeirloomColors.primaryText)
                    }
                }

                if currentExtraction.instructions.count > 3 {
                    Text("+ \(currentExtraction.instructions.count - 3) more steps")
                        .font(HeirloomFonts.caption)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .padding(.leading, 20)
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(HeirloomSpacing.cardCornerRadius)
        .shadow(color: HeirloomShadows.card.color, radius: HeirloomShadows.card.radius, x: HeirloomShadows.card.x, y: HeirloomShadows.card.y)
    }

    private var enhancementOptionsCard: some View {
        VStack(spacing: HeirloomSpacing.md) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                Text("We detected some unclear text. Try these options:")
                    .font(HeirloomFonts.subheadline)
                    .foregroundStyle(HeirloomColors.primaryText)

                Spacer()
            }

            VStack(spacing: HeirloomSpacing.sm) {
                // Enhance with AI button
                Button {
                    Task { await enhanceWithAI() }
                } label: {
                    HStack {
                        if isEnhancing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }

                        Text(isEnhancing ? "Enhancing..." : "Enhance with AI")
                            .font(HeirloomFonts.bodyBold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HeirloomSpacing.md)
                    .background(HeirloomColors.tomato)
                    .foregroundStyle(.white)
                    .cornerRadius(HeirloomSpacing.cardCornerRadius)
                }
                .disabled(isEnhancing)

                // Manual correction button
                Button {
                    showManualCorrection = true
                } label: {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Manually Correct")
                            .font(HeirloomFonts.body)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HeirloomSpacing.md)
                    .background(HeirloomColors.warmGray.opacity(0.15))
                    .foregroundStyle(HeirloomColors.primaryText)
                    .cornerRadius(HeirloomSpacing.cardCornerRadius)
                }

                // Re-scan button
                Button {
                    showRescanOptions = true
                } label: {
                    HStack {
                        Image(systemName: "camera.viewfinder")
                        Text("Re-scan Recipe")
                            .font(HeirloomFonts.body)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HeirloomSpacing.md)
                    .background(HeirloomColors.warmGray.opacity(0.15))
                    .foregroundStyle(HeirloomColors.primaryText)
                    .cornerRadius(HeirloomSpacing.cardCornerRadius)
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(HeirloomSpacing.cardCornerRadius)
    }

    private func errorCard(_ message: String) -> some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(HeirloomFonts.caption)
                .foregroundStyle(HeirloomColors.secondaryText)

            Spacer()
        }
        .padding(HeirloomSpacing.md)
        .background(Color.red.opacity(0.1))
        .cornerRadius(HeirloomSpacing.cardCornerRadius)
    }

    private var acceptButton: some View {
        Button {
            onAccept(currentExtraction)
            isPresented = false
        } label: {
            Text("Accept Recipe")
                .font(HeirloomFonts.bodyBold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, HeirloomSpacing.md)
                .background(extractionConfidence >= 0.3 ? HeirloomColors.green : Color.gray)
                .foregroundStyle(.white)
                .cornerRadius(HeirloomSpacing.cardCornerRadius)
        }
        .disabled(extractionConfidence < 0.3 || isEnhancing)
    }

    // MARK: - Computed Properties

    private var extractionConfidence: Double {
        currentExtraction.confidence ?? 0.5
    }

    private var confidenceIcon: String {
        if extractionConfidence >= 0.8 {
            return "checkmark.circle.fill"
        } else if extractionConfidence >= 0.5 {
            return "exclamationmark.triangle.fill"
        } else {
            return "xmark.circle.fill"
        }
    }

    private var confidenceColor: Color {
        if extractionConfidence >= 0.8 {
            return HeirloomColors.green
        } else if extractionConfidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Actions

    private func enhanceWithAI() async {
        guard let aiExtractor = aiExtractor else { return }

        isEnhancing = true
        enhancementError = nil

        do {
            // Use Google Vision if available, otherwise use two-pass extraction
            let enhanced = try await aiExtractor.extract(from: sourceImage)

            // Update extraction
            currentExtraction = ExtractedRecipe(
                title: enhanced.title,
                servings: enhanced.servings,
                prepTime: enhanced.prepTime,
                cookTime: enhanced.cookTime,
                ingredientStructure: enhanced.ingredientStructure,
                instructions: enhanced.instructions,
                notes: enhanced.notes,
                confidence: min((extractionConfidence + 0.2), 1.0) // Boost confidence after enhancement
            )

            Log.info("✅ Recipe enhanced successfully", category: .ocr, metadata: [
                "original_confidence": extractionConfidence,
                "new_confidence": currentExtraction.confidence ?? 0.0
            ])

        } catch {
            enhancementError = "Enhancement failed: \(error.localizedDescription)"
            Log.error("Recipe enhancement failed", category: .ocr, metadata: [
                "error": error.localizedDescription
            ])
        }

        isEnhancing = false
    }
}

// MARK: - Preview

#Preview {
    let sampleRecipe = ExtractedRecipe(
        title: "Chocolate Chip Cookies",
        servings: "24 cookies",
        prepTime: "15 minutes",
        cookTime: "12 minutes",
        ingredientStructure: .flat([
            "2 cups all-purpose flour",
            "1 tsp baking soda",
            "1/2 tsp salt",
            "1 cup butter, softened"
        ]),
        instructions: [
            "Preheat oven to 375°F",
            "Mix dry ingredients",
            "Cream butter and sugars"
        ],
        notes: "Enhanced from handwritten recipe",
        confidence: 0.65
    )

    let sampleImage = UIImage(systemName: "photo")!

    return ProgressiveExtractionView(
        extractedRecipe: sampleRecipe,
        sourceImage: sampleImage,
        isPresented: .constant(true),
        onAccept: { _ in },
        context: ModelContext(try! ModelContainer(for: Recipe.self, RecipeCollection.self))
    )
}
