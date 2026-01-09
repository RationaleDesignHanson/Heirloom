//
//  VideoProcessingView.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/8/26.
//
//  Displays processing progress with deterministic indicators

import SwiftUI
import SwiftData
import AVFoundation

struct VideoProcessingView: View {
    @ObservedObject var processor: VideoRecipeProcessor
    let videoURL: URL
    let sourceAttribution: VideoSourceAttribution
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var extraction: VideoRecipeExtraction?
    @State private var showReview = false
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var recipeImage: Data?  // Extracted video frame

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                // Processing indicator
                ProcessingIndicator(
                    state: processor.state,
                    progress: processor.progress
                )

                // Status text
                VStack(spacing: 12) {
                    Text(processor.state.displayTitle)
                        .font(.title2.bold())

                    Text(processor.state.displaySubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Cancel button
                if processor.canCancel {
                    Button("Cancel", role: .cancel) {
                        processor.cancel()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationBarBackButtonHidden()
            .task {
                do {
                    let result = try await processor.process(videoURL: videoURL)
                    extraction = result

                    // Extract a nice frame from the video for recipe image
                    recipeImage = await extractVideoFrame(from: videoURL)

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
                        enhancedExtraction: processor.enhancedExtraction,  // NEW: Pass augmentation data
                        onSave: { updatedExtraction in
                            saveToSwiftData(updatedExtraction)
                            dismiss()
                        },
                        onCancel: {
                            dismiss()
                        }
                    )
                }
            }
            .alert("Processing Failed", isPresented: $showError) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    // MARK: - Video Frame Extraction

    private func extractVideoFrame(from videoURL: URL) async -> Data? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero

        // Extract frame at 30% into the video (usually shows plated food)
        guard let duration = try? await asset.load(.duration) else {
            return nil
        }

        let targetTime = CMTimeMultiplyByFloat64(duration, multiplier: 0.3)

        do {
            let cgImage = try imageGenerator.copyCGImage(at: targetTime, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)

            // Resize to reasonable size for recipe card (max 1024px width)
            let resizedImage = uiImage.resized(toMaxWidth: 1024)

            return resizedImage?.jpegData(compressionQuality: 0.8)
        } catch {
            print("Failed to extract video frame: \(error)")
            return nil
        }
    }

    // MARK: - Save to SwiftData

    private func saveToSwiftData(_ extraction: VideoRecipeExtraction) {
        let recipe = Recipe(
            title: extraction.structuredRecipe.title,
            sourceType: .manual,  // Mark as manual since they reviewed/edited
            instructions: extraction.structuredRecipe.steps.map { $0.instruction },
            servings: extraction.structuredRecipe.servings
        )

        // Set provenance for video source
        recipe.provenance = ProvenanceMetadata(
            sourceType: .imported,  // Use imported for now (video type coming in main app integration)
            sourceURL: videoURL.absoluteString,
            sourceAttribution: "\(extraction.metadata.attribution.creatorName ?? "Unknown") - \(extraction.metadata.attribution.videoTitle ?? "Video")",
            generation: 0,
            sharedByName: nil,
            createdAt: Date()
        )

        // Set recipe image from extracted video frame
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

        // Create ingredients with augmented quantities
        for (index, ingredient) in extraction.structuredRecipe.ingredients.enumerated() {
            // Parse quantity string to Double for Ingredient model
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
            print("✅ Saved recipe: \(recipe.title) with \(recipe.ingredients?.count ?? 0) ingredients")
            print("   With image: \(recipeImage != nil ? "Yes" : "No")")
        } catch {
            print("❌ Failed to save recipe: \(error)")
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

// MARK: - Processing Indicator

struct ProcessingIndicator: View {
    let state: ProcessingState
    let progress: Double

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.blue.opacity(0.2), lineWidth: 8)
                .frame(width: 120, height: 120)

            // Progress circle or icon
            Group {
                switch state {
                case .transcribing(let transcribeProgress) where transcribeProgress > 0:
                    // Show progress ring for transcription
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color.blue.gradient,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3), value: progress)

                case .reviewing:
                    // Show checkmark when ready for review
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)

                case .failed:
                    // Show error icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.red)

                case .completed:
                    // Show success icon
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)

                default:
                    // Show spinner for other states
                    ProgressView()
                        .scaleEffect(2.0)
                        .tint(.blue)
                }
            }
        }
    }
}

// MARK: - Preview

// Previews commented out - require real VideoRecipeProcessor instance
// Use simulator to test this view

//#Preview("Processing") {
//    VideoProcessingView(
//        processor: VideoRecipeProcessor(...),
//        videoURL: URL(fileURLWithPath: "/tmp/test.mp4")
//    )
//}
