//
//  ASMRVideoImportView.swift
//  Heirloom
//
//  Created by Claude on 1/10/26.
//

import SwiftUI
import PhotosUI
import AVFoundation

/// Entry point for ASMR (silent video) recipe extraction
struct ASMRVideoImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var usageManager = ASMRUsageManager.shared

    // Processor will be initialized in init() with modelContext
    @StateObject private var processor: ASMRVideoProcessor

    init() {
        // Capture modelContext is not possible here since @Environment is only available in body
        // We'll pass it lazily when needed
        _processor = StateObject(wrappedValue: ASMRVideoProcessor())
    }

    @State private var selectedVideoURL: URL?
    @State private var userCaption = ""
    @State private var showVideoPicker = false
    @State private var showProcessing = false
    @State private var showPaywall = false
    @State private var showOnboarding = false
    @State private var videoThumbnail: UIImage?
    @State private var videoDuration: TimeInterval?
    @State private var isPreparingProcessing = false
    @State private var extractedRecipe: ASMRRecipeExtraction?
    @State private var showReview = false

    @AppStorage("has_seen_asmr_onboarding") private var hasSeenOnboarding = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with icon and explanation
                    headerSection

                    // Usage badge (shows credits remaining)
                    ASMRUsageBadge()

                    // Video selection
                    if selectedVideoURL == nil {
                        videoSelectionButton
                    } else {
                        videoPreviewSection
                    }

                    // Caption input (required for context)
                    if selectedVideoURL != nil {
                        captionInputSection
                    }

                    Spacer(minLength: 24)

                    // Process button
                    if selectedVideoURL != nil {
                        processButton
                    }
                }
                .padding()
            }
            .navigationTitle("Silent Video Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showOnboarding = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .photosPicker(
                isPresented: $showVideoPicker,
                selection: Binding(
                    get: { nil },
                    set: { newValue in
                        if let item = newValue {
                            loadVideo(from: item)
                        }
                    }
                ),
                matching: .videos
            )
            .fullScreenCover(isPresented: $showProcessing) {
                ASMRProcessingView(
                    videoURL: selectedVideoURL!,
                    userCaption: userCaption,
                    processor: processor,
                    skipSoundAnalysis: true,  // Always skip for "Video without Instructions" mode
                    onComplete: { extraction in
                        print("📊 Received extraction, dismissing processing...")
                        extractedRecipe = extraction
                        showProcessing = false
                        // Note: Review screen will be shown in onDisappear callback below
                    },
                    onCancel: {
                        showProcessing = false
                        extractedRecipe = nil
                    }
                )
                .onDisappear {
                    // Wait for dismissal animation to complete before showing review
                    // This prevents white screen issue caused by rapid sequential presentations
                    // Increased delay to 1.0s to ensure SwiftUI fully completes dismissal
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if let _ = extractedRecipe {
                            print("📊 Processing dismissed, now showing review...")
                            showReview = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showReview) {
                if let extraction = extractedRecipe {
                    VideoRecipeReviewView(
                        extraction: extraction,
                        enhancedExtraction: processor.enhancedExtraction,
                        onSave: { updatedExtraction in
                            print("📊 Saving recipe...")
                            _ = saveRecipeToSwiftData(updatedExtraction)
                            showReview = false
                            dismiss()
                        },
                        onCancel: {
                            showReview = false
                            extractedRecipe = nil
                        }
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                }
            }
            .sheet(isPresented: $showOnboarding) {
                onboardingSheet
            }
            .sheet(isPresented: $showPaywall) {
                // TODO: Show subscription paywall
                Text("Upgrade to Pro for more extractions")
            }
            .overlay {
                if isPreparingProcessing {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)

                            Text("Preparing video...")
                                .foregroundStyle(.white)
                                .font(.headline)
                        }
                        .padding(32)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(radius: 20)
                    }
                }
            }
            .onAppear {
                if !hasSeenOnboarding {
                    showOnboarding = true
                    hasSeenOnboarding = true
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)

            VStack(spacing: 4) {
                Text("Silent Video Import")
                    .font(.title2.bold())

                // Mode indicator badge
                Text("Video without Instructions")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.purple)
                    .cornerRadius(12)
            }

            Text("Extract recipes from ASMR or cooking videos without narration")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Video Selection

    private var videoSelectionButton: some View {
        Button {
            showVideoPicker = true
        } label: {
            VStack(spacing: 16) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Select Video")
                    .font(.headline)

                Text("Choose an ASMR or silent cooking video from your library")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(32)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .foregroundStyle(.blue.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }

    private var videoPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Selected Video")
                    .font(.headline)

                Spacer()

                Button {
                    selectedVideoURL = nil
                    userCaption = ""
                    videoThumbnail = nil
                    videoDuration = nil
                } label: {
                    Text("Change")
                        .font(.subheadline)
                }
            }

            HStack(spacing: 12) {
                // Video thumbnail
                if let thumbnail = videoThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "video")
                                .foregroundStyle(.secondary)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedVideoURL?.lastPathComponent ?? "Video")
                        .font(.subheadline)
                        .lineLimit(2)

                    if let duration = videoDuration {
                        Text(formatDuration(duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    // MARK: - Caption Input

    private var captionInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Video Description")
                    .font(.headline)

                Text("(Required)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Help us understand what's being cooked. This improves accuracy significantly.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("e.g., Making carbonara pasta", text: $userCaption, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...5)
        }
    }

    // MARK: - Process Button

    private var processButton: some View {
        VStack(spacing: 12) {
            Button {
                processVideo()
            } label: {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Extract Recipe")
                    Text("(5 credits)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canProcess ? Color.blue : Color.gray)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(!canProcess)

            if !canProcess && !userCaption.isEmpty && selectedVideoURL != nil {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text("Insufficient credits. Upgrade to continue.")
                        .font(.caption)
                }
                .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Onboarding Sheet

    private var onboardingSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: "eye.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.gradient)

                        Text("Vision-Based Recipe Extraction")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)

                    infoCard(
                        icon: "video.slash",
                        title: "For Silent Videos",
                        description: "Perfect for ASMR cooking videos, technique-focused content, or any video without narration."
                    )

                    infoCard(
                        icon: "text.bubble",
                        title: "Description Required",
                        description: "A brief description helps our AI understand what's being cooked and improves accuracy."
                    )

                    infoCard(
                        icon: "sparkles",
                        title: "5-Pass AI Analysis",
                        description: "We analyze your video in 5 specialized passes: dish identification, ingredient detection, culinary inference, action recognition, and synthesis."
                    )

                    infoCard(
                        icon: "star.circle",
                        title: "Credit System",
                        description: "Each extraction uses 5 credits. Free users get 5 credits/month (1 extraction), Pro users get 20 credits/month (4 extractions)."
                    )

                    infoCard(
                        icon: "checkmark.seal",
                        title: "Always Verify",
                        description: "You'll have a chance to review and edit the extracted recipe before saving. Validation notes will highlight any uncertainties."
                    )
                }
                .padding()
            }
            .navigationTitle("How It Works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got It") {
                        showOnboarding = false
                    }
                }
            }
        }
    }

    private func infoCard(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func processVideo() {
        guard canProcess else {
            if !usageManager.canStartExtraction() {
                showPaywall = true
            }
            return
        }

        // Show loading indicator briefly while SwiftUI prepares the processing screen
        isPreparingProcessing = true

        // Small delay to let UI update, then show processing screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPreparingProcessing = false
            showProcessing = true
        }
    }

    private var canProcess: Bool {
        selectedVideoURL != nil &&
        !userCaption.isEmpty &&
        userCaption.count >= 5 &&
        usageManager.canStartExtraction()
    }

    // MARK: - Save to SwiftData

    @discardableResult
    private func saveRecipeToSwiftData(_ extraction: VideoRecipeExtraction) -> Recipe {
        let recipe = Recipe(
            title: extraction.structuredRecipe.title,
            sourceType: .manual,
            instructions: extraction.structuredRecipe.steps.map { $0.instruction },
            servings: extraction.structuredRecipe.servings
        )

        recipe.provenance = ProvenanceMetadata(
            sourceType: .imported,
            sourceURL: selectedVideoURL?.absoluteString,
            sourceAttribution: "ASMR Video - \(extraction.metadata.attribution.captionText ?? "Silent video")",
            generation: 0,
            sharedByName: nil,
            createdAt: Date()
        )

        if let description = extraction.structuredRecipe.description {
            recipe.notes = description
        }

        Task {
            await extractAndSaveHeroImage(for: recipe, from: selectedVideoURL)
        }

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
            print("✅ Saved ASMR recipe: \(recipe.title)")
        } catch {
            print("⚠️ Failed to save ASMR recipe: \(error)")
        }

        return recipe
    }

    private func extractAndSaveHeroImage(for recipe: Recipe, from videoURL: URL?) async {
        guard let videoURL = videoURL else { return }

        do {
            let asset = AVAsset(url: videoURL)
            let captureTime: Double = 1.0
            let time = CMTime(seconds: captureTime, preferredTimescale: 600)

            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceAfter = .zero
            generator.requestedTimeToleranceBefore = .zero

            let cgImage = try await generator.image(at: time).image
            let heroImage = UIImage(cgImage: cgImage)

            let imageCache = ImageCache()
            let imageService = ImageStorageService(imageCache: imageCache)
            let fileName = try await imageService.saveImage(heroImage, recipeId: recipe.id)

            await MainActor.run {
                recipe.imageFileName = fileName
                try? modelContext.save()
                print("✅ Saved hero image for ASMR recipe: \(fileName)")
            }
        } catch {
            print("⚠️ Failed to extract hero image: \(error)")
        }
    }

    // MARK: - Helpers

    private func loadVideo(from item: PhotosPickerItem) {
        Task {
            guard let movie = try? await item.loadTransferable(type: VideoTransferable.self) else {
                return
            }

            selectedVideoURL = movie.url

            // Extract thumbnail and duration
            let asset = AVAsset(url: movie.url)

            // Get duration
            if let duration = try? await asset.load(.duration) {
                videoDuration = CMTimeGetSeconds(duration)
            }

            // Generate thumbnail
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true

            if let cgImage = try? await generator.image(at: CMTime(seconds: 0, preferredTimescale: 600)).image {
                videoThumbnail = UIImage(cgImage: cgImage)
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Video Transferable

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let copy = URL.documentsDirectory.appending(path: "imported_video_\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

// MARK: - Preview

#Preview {
    ASMRVideoImportView()
}
