//
//  VideoProcessingView.swift
//  Heirloom
//
//  Created by Claude on 1/8/26.
//  Updated on 1/10/26 - Unified design with ASMR processing
//
//  Displays processing progress with beautiful, detailed UI

import SwiftUI
import SwiftData
import AVFoundation

struct VideoProcessingView: View {
    @ObservedObject var processor: VideoRecipeProcessor
    let videoURL: URL
    let sourceAttribution: VideoSourceAttribution
    let onComplete: (Recipe) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var extraction: VideoRecipeExtraction?
    @State private var showReview = false
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var recipeImage: Data?

    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Large progress ring
                        progressRingSection

                        // Important notice
                        if processor.progress < 1.0 {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.blue)
                                Text("Keep this screen open during processing")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }

                        // Current state description
                        stateDescriptionView

                        // Phase progress cards
                        phaseProgressSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Extracting Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if case .completed = processor.state {
                        EmptyView()
                    } else if processor.canCancel {
                        Button("Cancel") {
                            processor.cancel()
                            dismiss()
                        }
                    }
                }
            }
            .alert("Processing Failed", isPresented: $showError) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .task {
                do {
                    let result = try await processor.process(videoURL: videoURL)
                    extraction = result

                    // Extract frame for recipe image
                    recipeImage = await extractVideoFrame(from: videoURL)

                    // Wait a moment to show 100% before dismissing
                    try? await Task.sleep(nanoseconds: 1_000_000_000)

                    showReview = true
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            .fullScreenCover(isPresented: $showReview) {
                if let extraction = extraction {
                    VideoRecipeReviewView(
                        extraction: extraction,
                        enhancedExtraction: processor.enhancedExtraction,
                        onSave: { updatedExtraction in
                            let savedRecipe = saveToSwiftData(updatedExtraction)
                            onComplete(savedRecipe)
                        },
                        onCancel: {
                            dismiss()
                        }
                    )
                }
            }
        }
    }

    // MARK: - Progress Ring Section

    private var progressRingSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 180, height: 180)

                // Progress circle
                Circle()
                    .trim(from: 0, to: processor.progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: processor.progress)

                VStack(spacing: 8) {
                    Text("\(Int(processor.progress * 100))%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    if let phaseText = currentPhaseText {
                        Text(phaseText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Processing time estimate
            if processor.progress < 1.0 {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(estimatedTimeRemaining)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - State Description

    @ViewBuilder
    private var stateDescriptionView: some View {
        VStack(spacing: 8) {
            let (icon, title, subtitle, color) = stateInfo

            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color.gradient)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }

    // MARK: - Phase Progress Section

    private var phaseProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Processing Phases")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ProcessingPhaseCard(
                    phase: "Transcribing Audio",
                    description: "Converting speech to text",
                    phaseNumber: 1,
                    isActive: isPhaseActive(.transcribing(progress: 0)),
                    isComplete: isPhaseComplete(.transcribing(progress: 0))
                )

                ProcessingPhaseCard(
                    phase: "Extracting Recipe",
                    description: "Identifying ingredients and steps",
                    phaseNumber: 2,
                    isActive: isPhaseActive(.structuringRecipe),
                    isComplete: isPhaseComplete(.structuringRecipe)
                )

                ProcessingPhaseCard(
                    phase: "Augmenting Quantities",
                    description: "Filling missing measurements",
                    phaseNumber: 3,
                    isActive: isPhaseActive(.augmentingWithSimilarRecipes),
                    isComplete: isPhaseComplete(.augmentingWithSimilarRecipes)
                )

                ProcessingPhaseCard(
                    phase: "Finalizing",
                    description: "Saving your recipe",
                    phaseNumber: 4,
                    isActive: isPhaseActive(.reviewing(StructuredRecipe(title: "", description: nil, servings: nil, prepTime: nil, cookTime: nil, ingredients: [], steps: [], overallConfidence: 0, warnings: []))),
                    isComplete: isPhaseComplete(.reviewing(StructuredRecipe(title: "", description: nil, servings: nil, prepTime: nil, cookTime: nil, ingredients: [], steps: [], overallConfidence: 0, warnings: [])))
                )
            }
        }
    }

    // MARK: - Helpers

    private var currentPhaseText: String? {
        switch processor.state {
        case .extractingAudio:
            return "Phase 1/5"
        case .transcribing:
            return "Phase 2/5"
        case .analyzingFrames:
            return "Phase 3/5"
        case .structuringRecipe:
            return "Phase 4/5"
        case .augmentingWithSimilarRecipes:
            return "Phase 5/5"
        default:
            return nil
        }
    }

    private var stateInfo: (icon: String, title: String, subtitle: String, color: Color) {
        switch processor.state {
        case .idle:
            return ("video", "Ready", "Select a video to begin", .blue)
        case .extractingAudio:
            return ("waveform", "Extracting Audio", "Preparing audio for transcription", .blue)
        case .transcribing:
            return ("text.bubble", "Transcribing Video", processor.state.displaySubtitle, .blue)
        case .analyzingFrames:
            return ("photo.on.rectangle.angled", "Analyzing Frames", "Looking for on-screen text", .blue)
        case .structuringRecipe:
            return ("doc.text", "Creating Recipe", "Organizing ingredients and steps", .blue)
        case .augmentingWithSimilarRecipes:
            return ("sparkles", "Finding Similar Recipes", "Improving recipe accuracy", .blue)
        case .reviewing:
            return ("checkmark.circle.fill", "Ready to Review", "Recipe extracted successfully", .green)
        case .completed:
            return ("checkmark.circle.fill", "Extraction Complete", "Recipe ready to save", .green)
        case .failed:
            return ("exclamationmark.triangle.fill", "Processing Failed", processor.state.displaySubtitle, .red)
        }
    }

    private func isPhaseActive(_ phase: ProcessingState) -> Bool {
        switch (processor.state, phase) {
        case (.transcribing, .transcribing):
            return true
        case (.structuringRecipe, .structuringRecipe):
            return true
        case (.augmentingWithSimilarRecipes, .augmentingWithSimilarRecipes):
            return true
        case (.reviewing, .reviewing), (.completed, .reviewing):
            return true
        default:
            return false
        }
    }

    private func isPhaseComplete(_ phase: ProcessingState) -> Bool {
        let currentPhaseIndex = phaseIndex(processor.state)
        let checkPhaseIndex = phaseIndex(phase)
        return currentPhaseIndex > checkPhaseIndex || processor.progress >= 1.0
    }

    private func phaseIndex(_ state: ProcessingState) -> Int {
        switch state {
        case .idle, .extractingAudio:
            return 0
        case .transcribing:
            return 1
        case .analyzingFrames, .structuringRecipe:
            return 2
        case .augmentingWithSimilarRecipes:
            return 3
        case .reviewing, .completed:
            return 4
        case .failed:
            return -1
        }
    }

    private var estimatedTimeRemaining: String {
        // Average processing time ~2-4 minutes
        let totalEstimatedSeconds: Double = 180  // 3 minutes average
        let remainingProgress = max(0, 1.0 - processor.progress)
        let remainingSeconds = Int(totalEstimatedSeconds * remainingProgress)

        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60

        if minutes > 0 {
            return "~\(minutes)m \(seconds)s remaining"
        } else {
            return "~\(seconds)s remaining"
        }
    }

    // MARK: - Video Frame Extraction

    private func extractVideoFrame(from videoURL: URL) async -> Data? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero

        // Extract frame from first 2 seconds
        let targetTime = CMTime(seconds: 1.0, preferredTimescale: 600)

        do {
            let cgImage = try imageGenerator.copyCGImage(at: targetTime, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)
            let resizedImage = uiImage.resized(toMaxWidth: 1024)
            return resizedImage?.jpegData(compressionQuality: 0.8)
        } catch {
            print("Failed to extract video frame: \(error)")
            return nil
        }
    }

    // MARK: - Save to SwiftData

    private func saveToSwiftData(_ extraction: VideoRecipeExtraction) -> Recipe {
        let recipe = Recipe(
            title: extraction.structuredRecipe.title,
            sourceType: .manual,
            instructions: extraction.structuredRecipe.steps.map { $0.instruction },
            servings: extraction.structuredRecipe.servings
        )

        recipe.provenance = ProvenanceMetadata(
            sourceType: .imported,
            sourceURL: videoURL.absoluteString,
            sourceAttribution: "\(extraction.metadata.attribution.creatorName ?? "Unknown") - \(extraction.metadata.attribution.videoTitle ?? "Video")",
            generation: 0,
            sharedByName: nil,
            createdAt: Date()
        )

        // Set recipe image
        if let imageData = recipeImage, let uiImage = UIImage(data: imageData) {
            Task {
                do {
                    let imageService = ImageStorageService(imageCache: ImageCache())
                    let fileName = try await imageService.saveImage(uiImage, recipeId: recipe.id)
                    recipe.imageFileName = fileName
                    print("✅ Saved recipe image: \(fileName)")
                } catch {
                    print("⚠️ Failed to save recipe image: \(error)")
                }
            }
        }

        // Create ingredients
        for (index, ingredient) in extraction.structuredRecipe.ingredients.enumerated() {
            let quantityDouble = ingredient.quantity.flatMap { Double($0) }

            let ing = Ingredient(
                originalText: ingredient.originalText,
                name: ingredient.item,
                quantity: quantityDouble,
                unit: ingredient.unit,
                orderIndex: index
            )
            ing.recipe = recipe
            modelContext.insert(ing)
        }

        modelContext.insert(recipe)

        do {
            try modelContext.save()
            print("✅ Saved recipe: \(recipe.title)")
        } catch {
            print("❌ Failed to save recipe: \(error)")
        }

        return recipe
    }
}

// MARK: - Processing Phase Card

struct ProcessingPhaseCard: View {
    let phase: String
    let description: String
    let phaseNumber: Int  // NEW: 1, 2, 3, 4
    let isActive: Bool
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(isComplete ? 1.0 : 0.15))
                    .frame(width: 40, height: 40)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    // Show number for pending and active phases
                    ZStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 28, height: 28)

                        if isActive {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.white)
                        } else {
                            Text("\(phaseNumber)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(phase)
                    .font(.subheadline.bold())
                    .foregroundStyle(isActive ? .primary : .secondary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(isActive ? statusColor.opacity(0.05) : Color.clear)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? statusColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var statusColor: Color {
        if isComplete {
            return .green
        } else if isActive {
            return .blue
        } else {
            return .gray
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func resized(toMaxWidth maxWidth: CGFloat) -> UIImage? {
        let scale = maxWidth / size.width
        let newHeight = size.height * scale
        let newSize = CGSize(width: maxWidth, height: newHeight)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }

        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
