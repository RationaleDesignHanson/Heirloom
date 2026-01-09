//
//  VideoRecipeReviewView.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/8/26.
//
//  Review and edit extracted recipe, add attribution

import SwiftUI

struct VideoRecipeReviewView: View {
    let extraction: VideoRecipeExtraction
    let enhancedExtraction: VideoRecipeExtraction.Enhanced?  // NEW: Augmentation data
    let onSave: (VideoRecipeExtraction) -> Void
    let onCancel: () -> Void

    @State private var editedTitle: String
    @State private var editedServings: String
    @State private var editedIngredients: [ExtractedIngredient]
    @State private var editedSteps: [ExtractedStep]

    // Attribution fields
    @State private var creatorName: String
    @State private var videoTitle: String
    @State private var selectedPlatform: VideoPlatform
    @State private var attributionNotes: String

    @State private var showTranscript = false

    init(
        extraction: VideoRecipeExtraction,
        enhancedExtraction: VideoRecipeExtraction.Enhanced? = nil,  // NEW
        onSave: @escaping (VideoRecipeExtraction) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.extraction = extraction
        self.enhancedExtraction = enhancedExtraction
        self.onSave = onSave
        self.onCancel = onCancel

        // Initialize state from extraction
        _editedTitle = State(initialValue: extraction.structuredRecipe.title)
        _editedServings = State(initialValue: extraction.structuredRecipe.servings ?? "")
        _editedIngredients = State(initialValue: extraction.structuredRecipe.ingredients)
        _editedSteps = State(initialValue: extraction.structuredRecipe.steps)

        // Initialize attribution fields
        _creatorName = State(initialValue: extraction.metadata.attribution.creatorName ?? "")
        _videoTitle = State(initialValue: extraction.metadata.attribution.videoTitle ?? "")
        _selectedPlatform = State(initialValue: extraction.metadata.attribution.platform ?? .cameraRoll)
        _attributionNotes = State(initialValue: extraction.metadata.attribution.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            List {
                // Attribution Section (Required)
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Attribution Required", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)

                        Text("Please credit the original creator of this recipe. This information will be displayed with the recipe.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    TextField("Creator Name *", text: $creatorName)
                        .textContentType(.name)

                    TextField("Video Title (optional)", text: $videoTitle)

                    Picker("Platform", selection: $selectedPlatform) {
                        ForEach(VideoPlatform.allCases, id: \.self) { platform in
                            Label(platform.displayName, systemImage: platform.iconName)
                                .tag(platform)
                        }
                    }

                    TextField("Additional Notes (optional)", text: $attributionNotes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Attribution")
                } footer: {
                    if creatorName.isEmpty {
                        Text("Creator name is required to save")
                            .foregroundStyle(.orange)
                    }
                }

                // Confidence warning if applicable
                if extraction.structuredRecipe.overallConfidence < 0.7 {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Low Confidence Extraction")
                                    .font(.subheadline.bold())
                                Text("Some items may need review. Fields marked with ⚠️ require verification.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Similar Recipes Augmentation Info (NEW - Week 4)
                if let enhanced = enhancedExtraction {
                    Section {
                        SimilarRecipesInfoView(
                            augmentedRecipe: enhanced.augmentedRecipe,
                            similarRecipes: enhanced.similarRecipes,
                            webRecipes: enhanced.webRecipes
                        )
                    }
                }

                // Title and Servings
                Section("Recipe Details") {
                    TextField("Recipe Name *", text: $editedTitle)
                        .font(.headline)

                    TextField("Servings (optional)", text: $editedServings)
                }

                // Ingredients (with augmentation support)
                Section {
                    ForEach(editedIngredients.indices, id: \.self) { index in
                        ingredientRow(for: index)
                    }
                    .onDelete { indices in
                        editedIngredients.remove(atOffsets: indices)
                    }

                    Button {
                        editedIngredients.append(ExtractedIngredient(
                            originalText: "",
                            item: "",
                            quantity: nil,
                            unit: nil,
                            preparation: nil,
                            confidence: .explicit
                        ))
                    } label: {
                        Label("Add Ingredient", systemImage: "plus")
                    }
                } header: {
                    HStack {
                        Text("Ingredients")
                        Spacer()
                        Text("\(editedIngredients.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                // Steps
                Section {
                    ForEach(editedSteps.indices, id: \.self) { index in
                        StepEditRow(step: $editedSteps[index], number: index + 1)
                    }
                    .onDelete { indices in
                        editedSteps.remove(atOffsets: indices)
                    }

                    Button {
                        editedSteps.append(ExtractedStep(
                            instruction: "",
                            duration: nil,
                            temperature: nil,
                            confidence: .explicit
                        ))
                    } label: {
                        Label("Add Step", systemImage: "plus")
                    }
                } header: {
                    HStack {
                        Text("Instructions")
                        Spacer()
                        Text("\(editedSteps.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                // Transcript (expandable)
                Section {
                    DisclosureGroup("View Original Transcript", isExpanded: $showTranscript) {
                        Text(extraction.transcript.text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                }

                // Processing info
                Section("Processing Details") {
                    LabeledContent("Provider", value: extraction.transcript.provider.displayName)
                    LabeledContent("Confidence", value: "\(Int(extraction.structuredRecipe.overallConfidence * 100))%")
                    LabeledContent("Processing Time", value: String(format: "%.1fs", extraction.processingTime))
                    LabeledContent("Estimated Cost", value: "$\(extraction.estimatedCost)")
                }
            }
            .navigationTitle("Review Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRecipe()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !editedTitle.trimmingCharacters(in: .whitespaces).isEmpty &&
        !creatorName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !editedIngredients.isEmpty &&
        !editedSteps.isEmpty
    }

    // MARK: - Ingredient Row Builder

    @ViewBuilder
    private func ingredientRow(for index: Int) -> some View {
        let ingredient = editedIngredients[index]

        // Find augmentation data for this ingredient (if available)
        let augmentation = enhancedExtraction?.augmentedRecipe?.augmentedIngredients.first {
            $0.originalIngredient.originalText == ingredient.originalText
        }

        // Use augmented row if augmentation data exists, otherwise use basic row
        if augmentation != nil {
            AugmentedIngredientEditRow(
                ingredient: ingredient,
                augmentation: augmentation,
                quantity: Binding(
                    get: { ingredient.quantity ?? "" },
                    set: { newValue in
                        editedIngredients[index] = ExtractedIngredient(
                            originalText: ingredient.originalText,
                            item: ingredient.item,
                            quantity: newValue.isEmpty ? nil : newValue,
                            unit: ingredient.unit,
                            preparation: ingredient.preparation,
                            confidence: ingredient.confidence
                        )
                    }
                ),
                unit: Binding(
                    get: { ingredient.unit ?? "" },
                    set: { newValue in
                        editedIngredients[index] = ExtractedIngredient(
                            originalText: ingredient.originalText,
                            item: ingredient.item,
                            quantity: ingredient.quantity,
                            unit: newValue.isEmpty ? nil : newValue,
                            preparation: ingredient.preparation,
                            confidence: ingredient.confidence
                        )
                    }
                ),
                name: Binding(
                    get: { ingredient.item },
                    set: { newValue in
                        editedIngredients[index] = ExtractedIngredient(
                            originalText: ingredient.originalText,
                            item: newValue,
                            quantity: ingredient.quantity,
                            unit: ingredient.unit,
                            preparation: ingredient.preparation,
                            confidence: ingredient.confidence
                        )
                    }
                )
            )
        } else {
            IngredientEditRow(ingredient: $editedIngredients[index])
        }
    }

    private func saveRecipe() {
        // Update attribution
        let updatedAttribution = VideoSourceAttribution(
            creatorName: creatorName.trimmingCharacters(in: .whitespaces),
            videoTitle: videoTitle.isEmpty ? nil : videoTitle.trimmingCharacters(in: .whitespaces),
            platform: selectedPlatform,
            sourceURL: extraction.metadata.attribution.sourceURL,
            notes: attributionNotes.isEmpty ? nil : attributionNotes.trimmingCharacters(in: .whitespaces),
            importDate: extraction.metadata.attribution.importDate,
            hasPermission: true
        )

        let updatedMetadata = VideoImportMetadata(
            attribution: updatedAttribution,
            videoDuration: extraction.metadata.videoDuration,
            transcriptionProvider: extraction.metadata.transcriptionProvider,
            transcriptionConfidence: extraction.metadata.transcriptionConfidence,
            processingCost: extraction.metadata.processingCost,
            processingTime: extraction.metadata.processingTime,
            transcriptText: extraction.metadata.transcriptText,
            detectedVisualElements: extraction.metadata.detectedVisualElements,
            processedAt: extraction.metadata.processedAt
        )

        let updatedRecipe = StructuredRecipe(
            title: editedTitle.trimmingCharacters(in: .whitespaces),
            description: extraction.structuredRecipe.description,
            servings: editedServings.isEmpty ? nil : editedServings.trimmingCharacters(in: .whitespaces),
            prepTime: extraction.structuredRecipe.prepTime,
            cookTime: extraction.structuredRecipe.cookTime,
            ingredients: editedIngredients,
            steps: editedSteps,
            overallConfidence: extraction.structuredRecipe.overallConfidence,
            warnings: extraction.structuredRecipe.warnings
        )

        let updatedExtraction = VideoRecipeExtraction(
            structuredRecipe: updatedRecipe,
            transcript: extraction.transcript,
            visualElements: extraction.visualElements,
            metadata: updatedMetadata,
            processingTime: extraction.processingTime,
            estimatedCost: extraction.estimatedCost
        )

        onSave(updatedExtraction)
    }
}

// MARK: - Ingredient Edit Row

struct IngredientEditRow: View {
    @Binding var ingredient: ExtractedIngredient

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Qty", text: Binding(
                    get: { ingredient.quantity ?? "" },
                    set: { ingredient = ExtractedIngredient(
                        originalText: ingredient.originalText,
                        item: ingredient.item,
                        quantity: $0.isEmpty ? nil : $0,
                        unit: ingredient.unit,
                        preparation: ingredient.preparation,
                        confidence: ingredient.confidence
                    )}
                ))
                .frame(width: 60)
                .textFieldStyle(.roundedBorder)

                TextField("Unit", text: Binding(
                    get: { ingredient.unit ?? "" },
                    set: { ingredient = ExtractedIngredient(
                        originalText: ingredient.originalText,
                        item: ingredient.item,
                        quantity: ingredient.quantity,
                        unit: $0.isEmpty ? nil : $0,
                        preparation: ingredient.preparation,
                        confidence: ingredient.confidence
                    )}
                ))
                .frame(width: 70)
                .textFieldStyle(.roundedBorder)

                TextField("Ingredient *", text: Binding(
                    get: { ingredient.item },
                    set: { ingredient = ExtractedIngredient(
                        originalText: ingredient.originalText,
                        item: $0,
                        quantity: ingredient.quantity,
                        unit: ingredient.unit,
                        preparation: ingredient.preparation,
                        confidence: ingredient.confidence
                    )}
                ))
                .textFieldStyle(.roundedBorder)
            }

            // Confidence indicator
            if ingredient.needsReview {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption2)
                    Text("Please verify - confidence: \(ingredient.confidence.displayName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Step Edit Row

struct StepEditRow: View {
    @Binding var step: ExtractedStep
    let number: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text("\(number).")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                TextField("Instruction *", text: Binding(
                    get: { step.instruction },
                    set: { step = ExtractedStep(
                        instruction: $0,
                        duration: step.duration,
                        temperature: step.temperature,
                        confidence: step.confidence
                    )}
                ), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            }

            // Confidence indicator
            if step.needsReview {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption2)
                    Text("Please verify - confidence: \(step.confidence.displayName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    let mockExtraction = VideoRecipeExtraction(
        structuredRecipe: StructuredRecipe(
            title: "Chocolate Chip Cookies",
            description: "Classic cookies",
            servings: "5 dozen",
            prepTime: "15 min",
            cookTime: "10 min",
            ingredients: [
                ExtractedIngredient(
                    originalText: "2 cups flour",
                    item: "flour",
                    quantity: "2",
                    unit: "cups",
                    preparation: nil,
                    confidence: .explicit
                )
            ],
            steps: [
                ExtractedStep(
                    instruction: "Mix ingredients",
                    duration: nil,
                    temperature: nil,
                    confidence: .explicit
                )
            ],
            overallConfidence: 0.85,
            warnings: []
        ),
        transcript: TranscriptionResult(
            text: "Today we're making chocolate chip cookies...",
            segments: [],
            confidence: 0.85,
            provider: .whisperKit
        ),
        visualElements: ["375°F"],
        metadata: VideoImportMetadata(
            attribution: VideoSourceAttribution(
                creatorName: nil,
                videoTitle: nil,
                platform: .cameraRoll,
                sourceURL: nil,
                notes: nil,
                hasPermission: true
            ),
            videoDuration: 180,
            transcriptionProvider: "WhisperKit",
            transcriptionConfidence: 0.85,
            processingCost: 0.02,
            processingTime: 45
        ),
        processingTime: 45,
        estimatedCost: 0.02
    )

    return VideoRecipeReviewView(
        extraction: mockExtraction,
        enhancedExtraction: nil,  // Can add mock enhanced extraction if needed
        onSave: { _ in },
        onCancel: {}
    )
}
