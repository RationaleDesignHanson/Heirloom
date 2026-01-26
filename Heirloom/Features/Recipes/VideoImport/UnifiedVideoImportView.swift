import SwiftUI
import PhotosUI
import SwiftData

struct UnifiedVideoImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Optional: Import from Share Extension via deep link
    let pendingImportID: UUID?

    @State private var selectedItem: PhotosPickerItem?
    @State private var importState: ImportState = .selecting
    @State private var currentMode: ExtractionMode?
    @State private var importedRecipe: Recipe?
    @State private var analysisResult: VideoImportAnalysisResult?
    @State private var videoURL: URL?
    @State private var processor: PendingImportProcessor?

    // Services resolved on MainActor
    @State private var subscriptionManager: SubscriptionManager?
    @State private var paywallManager: PaywallManager?

    // Initialization state
    @State private var isProcessorReady = false

    // Collection picker
    @State private var showCollectionPicker = false

    init(pendingImportID: UUID? = nil) {
        self.pendingImportID = pendingImportID
    }

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
            .task { @MainActor in
                // Initialize services from ServiceContainer
                self.subscriptionManager = ServiceContainer.shared.resolve(SubscriptionManager.self)
                self.paywallManager = ServiceContainer.shared.resolve(PaywallManager.self)

                // If launched from Share Extension, initialize processor for pending import
                if let importID = pendingImportID {
                    guard let subManager = subscriptionManager, let pwManager = paywallManager else {
                        importState = .error("Failed to initialize services")
                        return
                    }

                    self.processor = await PendingImportProcessor.make(
                        subscriptionManager: subManager,
                        paywallManager: pwManager
                    )

                    // Process the pending import
                    await processPendingImport(importID)
                } else {
                    // For camera roll flow, mark ready immediately
                    // We'll use VideoProcessingJobManager instead of PendingImportProcessor
                    isProcessorReady = true
                }
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

            if !isProcessorReady {
                ProgressView()
                    .padding()
                Text("Initializing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                PhotosPicker(selection: $selectedItem, matching: .videos) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
            }

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
                    paywallManager?.show(for: .visualVideoExtraction)
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
        .onChange(of: subscriptionManager?.isPremium == true) { _, isPremium in
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
               let attribution = recipe.provenance?.sourceAttribution {
                Text("From \(attribution)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button("Add to Collection") {
                saveAndShowCollectionPicker()
            }
            .buttonStyle(.borderedProminent)

            Button("Done") {
                saveRecipeAndDismiss()
            }
            .buttonStyle(.bordered)
        }
        .sheet(isPresented: $showCollectionPicker) {
            if let recipe = importedRecipe {
                TagCollectionPickerView(recipe: recipe)
            }
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

    // MARK: - Recipe Saving

    private func saveAndShowCollectionPicker() {
        guard let recipe = importedRecipe else { return }

        // Insert recipe into SwiftData if not already inserted
        if recipe.modelContext == nil {
            modelContext.insert(recipe)

            // Insert ingredients
            if let ingredients = recipe.ingredients {
                for ingredient in ingredients {
                    modelContext.insert(ingredient)
                }
            }

            try? modelContext.save()
            Log.info("Video recipe saved to SwiftData", category: .video, metadata: [
                "recipeId": recipe.id.uuidString,
                "title": recipe.title
            ])
        }

        showCollectionPicker = true
    }

    private func saveRecipeAndDismiss() {
        guard let recipe = importedRecipe else {
            dismiss()
            return
        }

        // Insert recipe into SwiftData if not already inserted
        if recipe.modelContext == nil {
            modelContext.insert(recipe)

            // Insert ingredients
            if let ingredients = recipe.ingredients {
                for ingredient in ingredients {
                    modelContext.insert(ingredient)
                }
            }

            try? modelContext.save()
            Log.info("Video recipe saved to SwiftData", category: .video, metadata: [
                "recipeId": recipe.id.uuidString,
                "title": recipe.title
            ])

            // Show toast
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            toastManager.success(
                title: "Recipe Saved",
                message: "Find it in All Recipes"
            )
        }

        dismiss()
    }

    // MARK: - Processing

    private func processSelectedVideo(_ item: PhotosPickerItem) {
        // Use VideoProcessingJobManager for camera roll imports
        Task {
            do {
                // Load video using VideoPickerView's transferable
                guard let videoData = try await item.loadTransferable(type: VideoTransferable.self) else {
                    importState = .error("Could not load video")
                    return
                }

                // Get the job manager
                let jobManager = ServiceContainer.shared.resolve(VideoProcessingJobManager.self)

                // Create attribution (empty for now, will be collected in review)
                let attribution = VideoSourceAttribution(
                    sourceURL: nil,
                    captionText: nil
                )

                // Create and queue the job
                let job = try jobManager.createJob(
                    videoURL: videoData.url,
                    videoType: .standard,
                    userCaption: nil,
                    videoDuration: nil,
                    sourceAttribution: attribution,
                    context: modelContext
                )

                // Get queue position for user feedback
                let descriptor = FetchDescriptor<VideoProcessingJob>(
                    sortBy: [SortDescriptor(\.createdAt, order: .forward)]
                )
                let allJobs = try modelContext.fetch(descriptor)
                let activeJobs = allJobs.filter { $0.status == .pending || $0.status == .processing }
                let queuePosition = activeJobs.firstIndex(where: { $0.id == job.id }) ?? 0
                let totalInQueue = activeJobs.count

                // Show success
                importState = .success

                // Toast notification with queue info
                let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                toastManager.success(
                    title: "Video queued (\(queuePosition + 1) of \(totalInQueue))",
                    message: "You'll be notified when it's ready to review"
                )

                // Dismiss after a moment
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                dismiss()

            } catch {
                importState = .error(error.localizedDescription)
            }
        }
    }

    private func processPendingImport(_ importID: UUID) async {
        importState = .analyzing(stage: "Loading video from Share Extension...")

        // Load pending import
        guard let pendingImport = await PendingImportManager.shared.load(id: importID) else {
            importState = .error("Could not find pending import")
            return
        }

        guard let videoURL = pendingImport.localVideoURL else {
            importState = .error("No video file available")
            return
        }

        self.videoURL = videoURL

        // Process using same flow as photo library import
        do {
            guard let processor = self.processor else {
                throw VideoImportError.extractionFailed("Processor not initialized")
            }

            importState = .analyzing(stage: "Analyzing audio...")

            let result = try await processor.analyzeVideo(at: videoURL)

            switch result {
            case .canProceedFree(let mode, let transcript, let onScreenText):
                importState = .extracting(mode: mode, progress: 0)

                let recipe = try await processor.processImport(
                    pendingImport,
                    mode: mode,
                    transcript: transcript,
                    onScreenText: onScreenText
                )

                importedRecipe = recipe
                importState = .success

                // Clean up pending import
                await PendingImportManager.shared.delete(id: importID)

            case .requiresPremium(let audioReasoning, let ocrReasoning):
                if subscriptionManager?.isPremium == true {
                    proceedWithVisualExtraction(videoURL: videoURL)
                } else {
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

    private func proceedWithVisualExtraction(videoURL: URL) {
        importState = .extracting(mode: .visualFrames, progress: 0)

        Task {
            do {
                guard let processor = self.processor else {
                    throw VideoImportError.extractionFailed("Processor not initialized")
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
