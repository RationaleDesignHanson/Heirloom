import SwiftUI
import VisionKit
import Vision
import PhotosUI

struct CookbookScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.firebaseSync) private var firebaseSync
    @EnvironmentObject private var tabCoordinator: TabNavigationCoordinator

    // Using concrete types for now since views call implementation-specific methods
    private var importManager: ImportJobManager { ServiceContainer.shared.resolve(ImportJobManager.self) }
    private var aiRecipeExtractor: AIRecipeExtractor { ServiceContainer.shared.resolve(AIRecipeExtractor.self) }
    private var aiIngredientParser: AIIngredientParser { ServiceContainer.shared.resolve(AIIngredientParser.self) }
    private var imageStorageService: ImageStorageService { ServiceContainer.shared.resolve(ImageStorageService.self) }
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }
    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }
    private var backendConfig: BackendConfig { ServiceContainer.shared.resolve(BackendConfig.self) }
    private var subscriptionManager: SubscriptionManager { ServiceContainer.shared.resolve(SubscriptionManager.self) }

    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var recognizedText: String = ""
    @State private var selectedPhotoItems: [PhotosPickerItem] = []  // Changed from single to array
    @State private var showMultiRecipeSheet = false
    @State private var multiRecipeResult: AIRecipeExtractor.MultiRecipeExtractionResult?
    @State private var errorMessage: String?
    @State private var imageSource: ImageSource = .camera
    @State private var showSoftWall = false
    @State private var cookbookName: String = "" // Custom cookbook name

    // Progress tracking
    @State private var processingStep: ProcessingStep = .preparing
    @StateObject private var progressInterpolator = PhotoProgressInterpolator()

    // Batch processing state
    @State private var isProcessingBatch = false
    @State private var totalBatchCount = 0
    @State private var processedBatchCount = 0
    @State private var currentBatchStatus = ""
    @State private var failedItems: [(index: Int, error: String)] = []
    @State private var showBatchSummary = false
    @State private var showPDFImport = false

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
        ZStack {
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
                            // Clear coordinator context on cancel
                            tabCoordinator.didCancelCreation()
                            dismiss()
                        }
                    }

                    // Only show Extract button for camera captures (photo library auto-starts)
                    if capturedImage != nil && !isProcessing && imageSource == .camera {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Extract Recipe") {
                                processImageWithQueue()
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
                .sheet(isPresented: $showPDFImport) {
                    PDFImportView(onJobCreated: {
                        // Dismiss CookbookScannerView when PDF job is created
                        // This allows user to see ImportProgressBottomBanner
                        dismiss()
                    })
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
                .onChange(of: selectedPhotoItems) { _, newItems in
                    // Check for premium subscription
                    guard subscriptionManager.isPremium else {
                        selectedPhotoItems = []
                        showSoftWall = true
                        return
                    }

                    guard !newItems.isEmpty else { return }

                    Task {
                        if newItems.count == 1 {
                            // Single photo mode - auto-start extraction
                            if let data = try? await newItems[0].loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                await MainActor.run {
                                    capturedImage = image
                                    imageSource = .photoLibrary
                                    selectedPhotoItems = []

                                    // Auto-start extraction for photo library (no extra tap needed)
                                    processImageWithQueue()
                                }
                            }
                        } else {
                            // Batch mode - process multiple photos
                            await processBatch(newItems)
                        }
                    }
                }
                .sheet(isPresented: $showSoftWall) {
                    SoftWallView(trigger: .cookbookScan)
                }
                .sheet(isPresented: $showBatchSummary) {
                    batchSummarySheet
                }
            }

            // Batch processing overlay
            if isProcessingBatch {
                batchProgressOverlay
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
                Text("Scan Recipe Images")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("For images only - use camera, camera roll photos, or PDFs")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, HeirloomSpacing.lg)

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

            // Cookbook Name Field
            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                Text("Cookbook Name (Optional)")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)

                TextField("e.g., Joy of Cooking", text: $cookbookName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, HeirloomSpacing.lg)

            Spacer()

            // Action Buttons
            VStack(spacing: HeirloomSpacing.md) {
                // Camera Button
                Button {
                    // Check for premium subscription
                    guard subscriptionManager.isPremium else {
                        showSoftWall = true
                        return
                    }
                    showCamera = true
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Open Camera")
                    }
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.buttonTextLight)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(HeirloomColors.tomato)
                    .cornerRadius(12)
                }

                // Photo Library Button (Multi-Select)
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Choose Photos")
                    }
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.tomato)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(HeirloomColors.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                            .stroke(HeirloomColors.tomato, lineWidth: 2)
                    )
                }

                // PDF Import Button
                Button {
                    showPDFImport = true
                } label: {
                    HStack {
                        Image(systemName: "doc.fill")
                        Text("Import PDF")
                    }
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.tomato)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(HeirloomColors.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
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
                .font(HeirloomFonts.title2)
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

    /// Process image using queue-based ImportJobManager
    private func processImageWithQueue() {
        guard let image = capturedImage else { return }

        Task {
            do {
                // Create import job with cookbook-specific or default collection name
                let collectionName = cookbookName.isEmpty ? "Cookbook Pages" : cookbookName
                Log.info("Creating cookbook import job", category: .import, metadata: [
                    "collectionName": collectionName,
                    "userEnteredName": cookbookName,
                    "isEmpty": cookbookName.isEmpty
                ])
                let job = try await importManager.createCameraImportJob(
                    images: [image],
                    collectionName: collectionName,
                    collectionType: .cookbook,
                    context: modelContext
                )

                // Start processing
                try await importManager.startJob(job, context: modelContext)

                // Dismiss CookbookScannerView and let user see ImportProgressBottomBanner
                await MainActor.run {
                    dismiss()

                    // Track analytics
                    analytics.track(event: .recipeImported, properties: [
                        "source": "cookbook_scan_single_queue",
                        "collection_name": collectionName
                    ])

                    Log.info("Cookbook import job started successfully", category: .import, metadata: [
                        "jobId": job.id.uuidString
                    ])
                }

            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    Log.error("Failed to create import job", category: .import, error: error)
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

    // MARK: - Batch Processing (Queue-Based)

    private func processBatch(_ items: [PhotosPickerItem]) async {
        Log.info("Starting batch import via queue", category: .import, metadata: [
            "count": items.count
        ])

        // Load all images first
        var images: [UIImage] = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }

        guard !images.isEmpty else {
            await MainActor.run {
                errorMessage = "Failed to load images from photo library"
            }
            return
        }

        do {
            // Create photo library import job for Photo Imports collection
            let job = try await importManager.createPhotoLibraryImportJob(
                images: images,
                collectionName: "Photo Imports",
                collectionType: .photoImports,
                context: modelContext
            )

            Log.info("Starting photo library import job", category: .import, metadata: [
                "jobId": job.id.uuidString,
                "imageCount": images.count
            ])

            // Start processing
            try await importManager.startJob(job, context: modelContext)

            await MainActor.run {
                selectedPhotoItems = []

                // Dismiss the scanner view after starting batch import
                dismiss()

                // Track analytics
                analytics.track(event: .recipeImported, properties: [
                    "source": "cookbook_scan_batch_queue",
                    "batch_size": images.count
                ])

                Log.info("Photo library batch import job started successfully", category: .import)
            }

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription

                Log.error("Photo library batch import failed", category: .import, metadata: [
                    "error": error.localizedDescription
                ])
            }
        }
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

    // MARK: - Batch Progress Overlay

    private var batchProgressOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            // Progress card
            VStack(spacing: HeirloomSpacing.lg) {
                // Header
                VStack(spacing: HeirloomSpacing.xs) {
                    Text("Batch Processing")
                        .font(HeirloomFonts.title3)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Processing \(processedBatchCount + 1) of \(totalBatchCount) photos")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Divider()

                // Overall batch progress
                VStack(spacing: HeirloomSpacing.sm) {
                    HStack {
                        Text("Overall Progress")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)

                        Spacer()

                        Text("\(Int(Double(processedBatchCount) / Double(totalBatchCount) * 100))%")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    ProgressView(value: Double(processedBatchCount) / Double(totalBatchCount))
                        .progressViewStyle(.linear)
                        .tint(HeirloomColors.familyGreen)
                }

                Divider()

                // Current photo progress
                VStack(spacing: HeirloomSpacing.sm) {
                    HStack {
                        Text("Current Photo")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)

                        Spacer()

                        Text("\(Int(progressInterpolator.interpolatedProgress * 100))%")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    ProgressView(value: progressInterpolator.interpolatedProgress)
                        .progressViewStyle(.linear)
                        .tint(HeirloomColors.tomato)

                    // Current step description
                    HStack(spacing: HeirloomSpacing.xs) {
                        ProgressView()
                            .scaleEffect(0.7)

                        Text(processingStep.description)
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)

                        Spacer()
                    }
                }

                // Cancel button
                Button {
                    cancelBatch()
                } label: {
                    Text("Cancel Batch")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.tomato)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(HeirloomColors.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                                .stroke(HeirloomColors.tomato, lineWidth: 2)
                        )
                }
            }
            .padding(HeirloomSpacing.xl)
            .background(HeirloomColors.cardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .padding(HeirloomSpacing.xl)
        }
    }

    // MARK: - Batch Summary Sheet

    private var batchSummarySheet: some View {
        NavigationStack {
            VStack(spacing: HeirloomSpacing.xl) {
                // Success icon
                ZStack {
                    Circle()
                        .fill(HeirloomColors.familyGreen.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(HeirloomColors.familyGreen)
                }
                .padding(.top, HeirloomSpacing.xl)

                // Summary text
                VStack(spacing: HeirloomSpacing.sm) {
                    Text("Batch Processing Complete")
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(HeirloomColors.primaryText)

                    let successCount = totalBatchCount - failedItems.count
                    Text("\(successCount) of \(totalBatchCount) photos processed successfully")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                }

                // Failed items list (if any)
                if !failedItems.isEmpty {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Failed Photos")
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(HeirloomColors.primaryText)
                        }

                        ForEach(failedItems, id: \.index) { item in
                            HStack {
                                Text("Photo \(item.index)")
                                    .font(HeirloomFonts.caption1)
                                    .foregroundStyle(HeirloomColors.secondaryText)

                                Spacer()

                                Text(item.error)
                                    .font(HeirloomFonts.caption2)
                                    .foregroundStyle(.red)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, HeirloomSpacing.xs)
                        }
                    }
                    .padding(HeirloomSpacing.md)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }

                Spacer()

                // Done button
                Button {
                    showBatchSummary = false
                    failedItems = []
                } label: {
                    Text("Done")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(HeirloomColors.tomato)
                        .cornerRadius(12)
                }
            }
            .padding(HeirloomSpacing.xl)
            .navigationTitle("Batch Complete")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func cancelBatch() {
        isProcessingBatch = false
        selectedPhotoItems = []
        progressInterpolator.stop()

        // Show toast or feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
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
