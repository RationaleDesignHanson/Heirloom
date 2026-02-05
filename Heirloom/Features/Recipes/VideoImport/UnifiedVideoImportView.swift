import SwiftUI
import PhotosUI
import SwiftData

struct UnifiedVideoImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Optional: Import from Share Extension via deep link
    let pendingImportID: UUID?

    // Optional target collection for adding the recipe to a specific collection
    let targetCollection: RecipeCollection?

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

    // Cost analysis state
    @State private var videoCostAnalyzer: VideoCostAnalyzer?
    @State private var analyzedCreditCost: Int = 0
    @State private var analyzedMode: String = ""
    @State private var currentPendingImportID: UUID?  // For Share Extension cleanup

    // Initialization state
    @State private var isProcessorReady = false

    // Collection picker
    @State private var showCollectionPicker = false

    init(pendingImportID: UUID? = nil, targetCollection: RecipeCollection? = nil) {
        self.pendingImportID = pendingImportID
        self.targetCollection = targetCollection
    }

    /// Whether the sheet can be dismissed (false during analysis/extraction)
    private var canDismiss: Bool {
        switch importState {
        case .analyzing, .extracting:
            return false
        default:
            return true
        }
    }

    enum ImportState {
        case selecting
        case analyzing(stage: String)
        case costConfirmation(credits: Int, mode: String, reasoning: String)
        case insufficientCredits(needed: Int, available: Int)
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
                case .costConfirmation(let credits, let mode, let reasoning):
                    costConfirmationView(credits: credits, mode: mode, reasoning: reasoning)
                case .insufficientCredits(let needed, let available):
                    insufficientCreditsView(needed: needed, available: available)
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
                    // Hide cancel button during non-cancellable states
                    if canDismiss {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .interactiveDismissDisabled(!canDismiss)
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

    // MARK: - Cost Confirmation View

    private func costConfirmationView(credits: Int, mode: String, reasoning: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon based on mode
            Image(systemName: mode == "ASMR" ? "eye.circle.fill" : "waveform.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("\(mode) Mode")
                .font(.title2.bold())

            // Credit cost display
            GroupBox {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "creditcard")
                            .foregroundColor(.green)
                        Text("Cost: \(credits) credit\(credits == 1 ? "" : "s")")
                            .font(.headline)
                        Spacer()
                    }

                    Divider()

                    Text(reasoning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal)

            // Import button
            Button {
                proceedWithImport()
            } label: {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Import for \(credits) Credit\(credits == 1 ? "" : "s")")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)

            // Cancel button
            Button {
                importState = .selecting
                selectedItem = nil
                videoURL = nil
            } label: {
                Text("Cancel")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - Insufficient Credits View

    private func insufficientCreditsView(needed: Int, available: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Insufficient Credits")
                .font(.title2.bold())

            Text("This import requires \(needed) credit\(needed == 1 ? "" : "s"), but you only have \(available) available.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Purchase button
            Button {
                // TODO: Show credit purchase sheet
                let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                toastManager.info(title: "Coming Soon", message: "Credit purchases will be available shortly")
            } label: {
                HStack {
                    Image(systemName: "cart.fill")
                    Text("Get More Credits")
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

            // Hint about daily quota
            GroupBox {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                    Text("Your free daily credits reset at midnight")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
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
            // Check for duplicates before inserting
            let duplicateDetectionService = ServiceContainer.shared.resolve(DuplicateDetectionService.self)

            do {
                let duplicates = try duplicateDetectionService.findDuplicates(
                    for: recipe,
                    in: modelContext,
                    threshold: 0.85
                )

                if !duplicates.isEmpty {
                    let exactMatches = duplicates.filter { $0.matchType == .exactHash }
                    let nearPerfectMatches = duplicates.filter { $0.similarityScore >= 0.95 }

                    if !exactMatches.isEmpty {
                        // Exact duplicate found - don't insert
                        let match = exactMatches[0]
                        Log.warning("⚠️ Video import blocked - exact duplicate", category: .video, metadata: [
                            "title": recipe.title,
                            "duplicate_id": match.recipe.id.uuidString,
                            "duplicate_title": match.recipe.title
                        ])

                        let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                        toastManager.warning(
                            title: "Recipe Already Exists",
                            message: "You already have '\(match.recipe.title)' in your collection"
                        )
                        return
                    } else if !nearPerfectMatches.isEmpty {
                        // Near-perfect match found - don't insert
                        let match = nearPerfectMatches[0]
                        Log.warning("⚠️ Video import blocked - near-identical duplicate", category: .video, metadata: [
                            "title": recipe.title,
                            "similarity_score": match.similarityScore,
                            "duplicate_id": match.recipe.id.uuidString,
                            "duplicate_title": match.recipe.title
                        ])

                        let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                        toastManager.warning(
                            title: "Very Similar Recipe Exists",
                            message: "'\(match.recipe.title)' is already in your collection"
                        )
                        return
                    } else {
                        // Similar but not near-identical - insert with warning
                        Log.info("ℹ️ Video import - similar recipe exists (importing anyway)", category: .video, metadata: [
                            "title": recipe.title,
                            "similarity_score": duplicates[0].similarityScore,
                            "match_type": "\(duplicates[0].matchType)",
                            "similar_to": duplicates[0].recipe.title
                        ])
                    }
                }
            } catch {
                // Duplicate detection failed - insert anyway (don't block import)
                Log.warning("⚠️ Video import duplicate detection failed, importing anyway", category: .video, metadata: [
                    "title": recipe.title,
                    "error": error.localizedDescription
                ])
            }

            modelContext.insert(recipe)

            // Insert ingredients
            if let ingredients = recipe.ingredients {
                for ingredient in ingredients {
                    modelContext.insert(ingredient)
                }
            }

            try? modelContext.save()

            // Route to target collection if specified, otherwise to "From Videos"
            let router = CollectionRouter(modelContext: modelContext)
            if let collection = targetCollection {
                router.routeToSpecificCollection(recipe, collection: collection)
            } else {
                router.routeVideoImport(recipe)
            }

            Log.info("Video recipe saved to SwiftData and routed", category: .video, metadata: [
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
            // Check for duplicates before inserting
            let duplicateDetectionService = ServiceContainer.shared.resolve(DuplicateDetectionService.self)

            do {
                let duplicates = try duplicateDetectionService.findDuplicates(
                    for: recipe,
                    in: modelContext,
                    threshold: 0.85
                )

                if !duplicates.isEmpty {
                    let exactMatches = duplicates.filter { $0.matchType == .exactHash }
                    let nearPerfectMatches = duplicates.filter { $0.similarityScore >= 0.95 }

                    if !exactMatches.isEmpty {
                        // Exact duplicate found - don't insert
                        let match = exactMatches[0]
                        Log.warning("⚠️ Video import blocked - exact duplicate", category: .video, metadata: [
                            "title": recipe.title,
                            "duplicate_id": match.recipe.id.uuidString,
                            "duplicate_title": match.recipe.title
                        ])

                        let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                        toastManager.warning(
                            title: "Recipe Already Exists",
                            message: "You already have '\(match.recipe.title)' in your collection"
                        )
                        dismiss()
                        return
                    } else if !nearPerfectMatches.isEmpty {
                        // Near-perfect match found - don't insert
                        let match = nearPerfectMatches[0]
                        Log.warning("⚠️ Video import blocked - near-identical duplicate", category: .video, metadata: [
                            "title": recipe.title,
                            "similarity_score": match.similarityScore,
                            "duplicate_id": match.recipe.id.uuidString,
                            "duplicate_title": match.recipe.title
                        ])

                        let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                        toastManager.warning(
                            title: "Very Similar Recipe Exists",
                            message: "'\(match.recipe.title)' is already in your collection"
                        )
                        dismiss()
                        return
                    } else {
                        // Similar but not near-identical - insert with warning
                        Log.info("ℹ️ Video import - similar recipe exists (importing anyway)", category: .video, metadata: [
                            "title": recipe.title,
                            "similarity_score": duplicates[0].similarityScore,
                            "match_type": "\(duplicates[0].matchType)",
                            "similar_to": duplicates[0].recipe.title
                        ])
                    }
                }
            } catch {
                // Duplicate detection failed - insert anyway (don't block import)
                Log.warning("⚠️ Video import duplicate detection failed, importing anyway", category: .video, metadata: [
                    "title": recipe.title,
                    "error": error.localizedDescription
                ])
            }

            modelContext.insert(recipe)

            // Insert ingredients
            if let ingredients = recipe.ingredients {
                for ingredient in ingredients {
                    modelContext.insert(ingredient)
                }
            }

            try? modelContext.save()

            // Route to target collection if specified, otherwise to "From Videos"
            let router = CollectionRouter(modelContext: modelContext)
            if let collection = targetCollection {
                router.routeToSpecificCollection(recipe, collection: collection)
            } else {
                router.routeVideoImport(recipe)
            }

            Log.info("Video recipe saved to SwiftData and routed", category: .video, metadata: [
                "recipeId": recipe.id.uuidString,
                "title": recipe.title
            ])

            // Show toast
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            toastManager.success(
                title: "Recipe Saved",
                message: "Find it in From Videos"
            )
        }

        dismiss()
    }

    // MARK: - Processing

    private func processSelectedVideo(_ item: PhotosPickerItem) {
        Task { @MainActor in
            do {
                // Load video using VideoPickerView's transferable
                guard let videoData = try await item.loadTransferable(type: VideoTransferable.self) else {
                    importState = .error("Could not load video")
                    return
                }

                // Store video URL for later processing
                self.videoURL = videoData.url

                // STEP 1: Analyze video to determine mode and cost
                importState = .analyzing(stage: "Analyzing video...")

                // Initialize cost analyzer if needed
                if videoCostAnalyzer == nil {
                    videoCostAnalyzer = await VideoCostAnalyzer.makeDefault()
                }

                guard let analyzer = videoCostAnalyzer else {
                    importState = .error("Failed to initialize analyzer")
                    return
                }

                let costResult = await analyzer.analyze(videoAt: videoData.url)

                Log.info("Video cost analysis completed", category: .video, metadata: [
                    "canProceed": costResult.canProceed,
                    "creditCost": costResult.creditCost,
                    "modeName": costResult.modeName,
                    "reasoning": costResult.reasoning
                ])

                guard costResult.canProceed else {
                    if case .failed(let error) = costResult {
                        importState = .error(error.localizedDescription)
                    } else {
                        importState = .error("Analysis failed")
                    }
                    return
                }

                // Store analysis results
                analyzedCreditCost = costResult.creditCost
                analyzedMode = costResult.modeName

                // STEP 2: Check credit balance
                Log.info("Checking credit balance...", category: .video)
                let userCredits = try fetchOrCreateUserCredits()
                let availableCredits = userCredits.availableToday

                Log.info("Credit check complete", category: .video, metadata: [
                    "available": availableCredits,
                    "needed": costResult.creditCost
                ])

                if availableCredits < costResult.creditCost {
                    // Not enough credits
                    importState = .insufficientCredits(
                        needed: costResult.creditCost,
                        available: availableCredits
                    )
                    return
                }

                // STEP 3: Show cost confirmation
                Log.info("Setting cost confirmation state", category: .video, metadata: [
                    "credits": costResult.creditCost,
                    "mode": costResult.modeName
                ])

                importState = .costConfirmation(
                    credits: costResult.creditCost,
                    mode: costResult.modeName,
                    reasoning: costResult.reasoning
                )

                Log.info("Import state set to costConfirmation", category: .video)

            } catch {
                Log.error("Video import error", category: .video, metadata: [
                    "error": error.localizedDescription,
                    "errorType": String(describing: type(of: error))
                ])
                importState = .error(error.localizedDescription)
            }
        }
    }

    /// Called when user confirms the cost and wants to proceed
    private func proceedWithImport() {
        guard let videoURL = videoURL else {
            importState = .error("Video not found")
            return
        }

        Task { @MainActor in
            do {
                // Deduct credits first
                let userCredits = try fetchOrCreateUserCredits()
                try userCredits.deductCredits(analyzedCreditCost)
                try modelContext.save()

                Log.info("Credits deducted for video import", category: .video, metadata: [
                    "credits": analyzedCreditCost,
                    "mode": analyzedMode
                ])

                // Now queue the job
                let jobManager = ServiceContainer.shared.resolve(VideoProcessingJobManager.self)

                let attribution = VideoSourceAttribution(
                    sourceURL: nil,
                    captionText: nil
                )

                let job = try jobManager.createJob(
                    videoURL: videoURL,
                    videoType: analyzedMode == "ASMR" ? .asmr : .standard,
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

                // Clean up pending import if this came from Share Extension
                if let pendingID = currentPendingImportID {
                    await PendingImportManager.shared.delete(id: pendingID)
                    currentPendingImportID = nil
                }

                // Toast notification
                let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                toastManager.success(
                    title: "Video queued (\(queuePosition + 1) of \(totalInQueue))",
                    message: "\(analyzedCreditCost) credit\(analyzedCreditCost == 1 ? "" : "s") used"
                )

                // Dismiss after a moment
                try await Task.sleep(nanoseconds: 1_500_000_000)
                dismiss()

            } catch {
                importState = .error(error.localizedDescription)
            }
        }
    }

    /// Fetch or create UserCredits for current user
    private func fetchOrCreateUserCredits() throws -> UserCredits {
        guard let userId = FirebaseAuthService.shared.currentUserId else {
            throw CreditError.insufficientCredits(needed: 1, available: 0)
        }

        var descriptor = FetchDescriptor<UserCredits>()
        descriptor.predicate = #Predicate<UserCredits> { credits in
            credits.userId == userId
        }

        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }

        // Create new UserCredits
        let newCredits = UserCredits(userId: userId)
        modelContext.insert(newCredits)
        return newCredits
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
        self.currentPendingImportID = importID  // Store for cleanup after success

        // Use unified cost analysis flow (same as camera roll)
        importState = .analyzing(stage: "Analyzing video...")

        // Initialize cost analyzer if needed
        if videoCostAnalyzer == nil {
            videoCostAnalyzer = await VideoCostAnalyzer.makeDefault()
        }

        guard let analyzer = videoCostAnalyzer else {
            importState = .error("Failed to initialize analyzer")
            return
        }

        let costResult = await analyzer.analyze(videoAt: videoURL)

        guard costResult.canProceed else {
            if case .failed(let error) = costResult {
                importState = .error(error.localizedDescription)
            } else {
                importState = .error("Analysis failed")
            }
            return
        }

        // Store analysis results
        analyzedCreditCost = costResult.creditCost
        analyzedMode = costResult.modeName

        // Check credit balance
        do {
            let userCredits = try fetchOrCreateUserCredits()
            let availableCredits = userCredits.availableToday

            if availableCredits < costResult.creditCost {
                importState = .insufficientCredits(
                    needed: costResult.creditCost,
                    available: availableCredits
                )
                return
            }
        } catch {
            importState = .error("Failed to check credits: \(error.localizedDescription)")
            return
        }

        // Show cost confirmation (user will call proceedWithImport)
        importState = .costConfirmation(
            credits: costResult.creditCost,
            mode: costResult.modeName,
            reasoning: costResult.reasoning
        )

        // Note: proceedWithImport() handles the actual processing and credit deduction
        // Clean up pending import happens in proceedWithImport after success
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
