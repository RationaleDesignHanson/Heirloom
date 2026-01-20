import SwiftUI
import PhotosUI

struct UnifiedVideoImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var paywallManager: PaywallManager

    @State private var selectedItem: PhotosPickerItem?
    @State private var importState: ImportState = .selecting
    @State private var currentMode: ExtractionMode?
    @State private var importedRecipe: Recipe?
    @State private var analysisResult: VideoImportAnalysisResult?
    @State private var videoURL: URL?
    @State private var processor: PendingImportProcessor?

    enum ImportState {
        case selecting
        case analyzing(stage: String)
        case premiumRequired(audioReasoning: String, ocrReasoning: String)
        case extracting(mode: ExtractionMode, progress: Float)
        case success
        case error(String)
    }

    var body: some View {
        NavigationStack {
            VStack {
                switch importState {
                case .selecting:
                    videoSelectionView
                case .analyzing(let stage):
                    analysisView(stage: stage)
                case .premiumRequired(let audioReasoning, let ocrReasoning):
                    premiumRequiredView(audioReasoning: audioReasoning, ocrReasoning: ocrReasoning)
                case .extracting(let mode, let progress):
                    extractionView(mode: mode, progress: progress)
                case .success:
                    successView
                case .error(let message):
                    errorView(message: message)
                }
            }
            .navigationTitle("Import Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                // Initialize processor
                self.processor = await PendingImportProcessor.make(
                    subscriptionManager: subscriptionManager,
                    paywallManager: paywallManager
                )
            }
        }
    }

    // MARK: - Selection View

    private var videoSelectionView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "video.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("Select a cooking video")
                .font(.headline)

            Text("Heirloom will automatically extract the recipe and credit the creator.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            PhotosPicker(selection: $selectedItem, matching: .videos) {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)

            Button {
                checkClipboardForURL()
            } label: {
                Label("Paste Video Link", systemImage: "link")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.horizontal)

            Spacer()

            // Tip
            GroupBox {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Tip: Share videos from TikTok or Instagram directly to Heirloom, or screen record them.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            if let item = newValue {
                processSelectedVideo(item)
            }
        }
    }

    // MARK: - Analysis View

    private func analysisView(stage: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text(stage)
                .font(.headline)
            Text("Determining best extraction method...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Premium Required View (KEY PAYWALL UX)

    private func premiumRequiredView(audioReasoning: String, ocrReasoning: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Visual Analysis Needed")
                .font(.title2.bold())

            // Explanation box
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    // Audio result
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "waveform")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Audio Analysis")
                                .font(.subheadline.bold())
                            Text(audioReasoning)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // OCR result
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "text.viewfinder")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("On-Screen Text")
                                .font(.subheadline.bold())
                            Text(ocrReasoning)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal)

            // Explanation
            Text("This video doesn't have clear speech or recipe text, so we need to analyze the visual content frame-by-frame. This is a premium feature.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Upgrade button
            Button {
                Task { @MainActor in
                    paywallManager.show(for: .visualVideoExtraction)
                }
            } label: {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("Upgrade to Premium")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)

            // Try different video
            Button {
                importState = .selecting
                selectedItem = nil
                videoURL = nil
            } label: {
                Text("Try a Different Video")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.horizontal)

            Spacer()

            // Hint for free users
            GroupBox {
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.yellow)
                    Text("Tip: Videos with spoken instructions or visible recipe text can be imported for free!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
        // Listen for subscription changes (user may have upgraded)
        .onChange(of: subscriptionManager.isPremium) { _, isPremium in
            if isPremium, let url = videoURL {
                // User upgraded! Proceed with extraction
                proceedWithVisualExtraction(videoURL: url)
            }
        }
    }

    // MARK: - Extraction View

    private func extractionView(mode: ExtractionMode, progress: Float) -> some View {
        VStack(spacing: 20) {
            Spacer()

            // Mode indicator
            HStack {
                Image(systemName: mode.iconSystemName)
                Text(mode.displayName)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            ProgressView(value: progress)
                .frame(width: 200)

            Text("Extracting recipe...")
                .font(.headline)

            Text("\(Int(progress * 100))%")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Recipe Imported!")
                .font(.headline)

            if let recipe = importedRecipe,
               let attribution = recipe.provenanceMetadata?.sourceAttribution {
                Text("From \(attribution)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Import Failed")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                importState = .selecting
                selectedItem = nil
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Processing

    private func processSelectedVideo(_ item: PhotosPickerItem) {
        importState = .analyzing(stage: "Loading video...")

        Task {
            do {
                guard let processor = self.processor else {
                    throw ImportError.extractionFailed("Processor not initialized")
                }

                // Load video
                guard let videoData = try await item.loadTransferable(type: VideoTransferable.self) else {
                    throw ImportError.noVideoFile
                }

                self.videoURL = videoData.url

                importState = .analyzing(stage: "Analyzing audio...")

                // Step 1: Analyze video to determine mode
                let result = try await processor.analyzeVideo(at: videoData.url)

                switch result {
                case .canProceedFree(let mode, let transcript, let onScreenText):
                    // FREE TIER - proceed directly
                    importState = .extracting(mode: mode, progress: 0)

                    let pendingImport = PendingVideoImport(
                        sourceType: .photoLibrary,
                        localVideoURL: videoData.url
                    )

                    let recipe = try await processor.processImport(
                        pendingImport,
                        mode: mode,
                        transcript: transcript,
                        onScreenText: onScreenText
                    )

                    importedRecipe = recipe
                    importState = .success

                case .requiresPremium(let audioReasoning, let ocrReasoning):
                    // PREMIUM REQUIRED - show paywall screen
                    if subscriptionManager.isPremium {
                        // User is premium, proceed anyway
                        proceedWithVisualExtraction(videoURL: videoData.url)
                    } else {
                        // Show premium required screen
                        importState = .premiumRequired(
                            audioReasoning: audioReasoning,
                            ocrReasoning: ocrReasoning
                        )
                    }

                case .failed(let error):
                    importState = .error(error.localizedDescription)
                }

            } catch {
                importState = .error(error.localizedDescription)
            }
        }
    }

    private func proceedWithVisualExtraction(videoURL: URL) {
        importState = .extracting(mode: .visualFrames, progress: 0)

        Task {
            do {
                guard let processor = self.processor else {
                    throw ImportError.extractionFailed("Processor not initialized")
                }

                let pendingImport = PendingVideoImport(
                    sourceType: .photoLibrary,
                    localVideoURL: videoURL
                )

                let recipe = try await processor.processImport(
                    pendingImport,
                    mode: .visualFrames,
                    transcript: nil,
                    onScreenText: nil
                )

                importedRecipe = recipe
                importState = .success

            } catch {
                importState = .error(error.localizedDescription)
            }
        }
    }

    private func checkClipboardForURL() {
        guard let string = UIPasteboard.general.string,
              let platformInfo = PlatformDetector.detect(from: string) else {
            // Show alert that no valid URL found
            return
        }

        // Handle URL import (already paywalled via .urlImport trigger)
        processURL(platformInfo)
    }

    private func processURL(_ platformInfo: DetectedPlatformInfo) {
        // URL imports are already a hard paywall (.urlImport)
        // Check subscription first
        if !subscriptionManager.isPremium {
            Task { @MainActor in
                paywallManager.show(for: .urlImport)
            }
            return
        }

        // User is premium, show instructions for the platform
        // (they need to provide the video file since we can't download it)
    }
}

// MARK: - Video Transferable

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}
