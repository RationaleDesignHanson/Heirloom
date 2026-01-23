import Foundation
import SwiftUI
import SwiftData

/// Handles deep links and universal links for the app with robust lifecycle handling
/// Supports: recipe sharing (heirloom://share/...), Firebase shares, universal links
/// Handles all app states: cold launch, background, foreground
@MainActor
class DeepLinkHandler: ObservableObject {
    // MARK: - Dependencies

    private let firebaseShare: FirebaseShareService
    private let logger: LoggingService
    private var modelContext: ModelContext?

    // MARK: - Published State

    @Published var pendingShareURL: URL?
    @Published var pendingShareMetadata: [String: Any]?
    @Published var showShareAcceptanceSheet = false

    // URL import state (for share extension)
    @Published var pendingImportURL: URL?
    @Published var showURLImportSheet = false

    // PDF import state (for share extension)
    @Published var pendingPDFURL: URL?
    @Published var showPDFImportSheet = false

    // Image import state (for share extension)
    @Published var pendingImageURL: URL?
    @Published var showImageImportSheet = false

    // Video import state (for share extension video imports)
    @Published var pendingVideoImportID: UUID?
    @Published var showVideoImportSheet = false

    // PDF/Image import state (for share extension imports)
    @Published var pendingImportJobID: UUID?
    @Published var showImportProgressSheet = false

    // Image recipe selection state (for multi-recipe OCR review)
    @Published var pendingImageRecipeResult: AIRecipeExtractor.MultiRecipeExtractionResult?
    @Published var showImageRecipeSelectionSheet = false

    // Image extraction progress state (for loading UI)
    @Published var isExtractingImageRecipes = false
    @Published var imageExtractionProgress: String = ""

    // Text recipe selection state (for Notes plain text recipes)
    @Published var pendingTextRecipeResult: AIRecipeExtractor.MultiRecipeExtractionResult?
    @Published var showTextRecipeSelectionSheet = false

    // Text extraction progress state (for loading UI)
    @Published var isExtractingTextRecipes = false
    @Published var textExtractionProgress: String = ""

    // Video job state (for notifications)
    @Published var pendingVideoJobID: UUID?
    @Published var pendingVideoJobAction: VideoJobAction?
    @Published var showVideoJobSheet = false

    enum VideoJobAction: String {
        case review = "review"
        case retry = "retry"
        case viewError = "view-error"
    }

    // MARK: - Private State (for robust handling)

    private var isAppReady = false
    private var queuedURLs: [URL] = []  // Support multiple URLs
    private var queuedActivity: NSUserActivity?

    // MARK: - Duplicate URL Prevention

    private var lastProcessedURL: URL?
    private var lastProcessedTime: Date?
    private let duplicateWindowSeconds: TimeInterval = 2.0

    // MARK: - Initialization

    init(firebaseShare: FirebaseShareService, logger: LoggingService) {
        self.firebaseShare = firebaseShare
        self.logger = logger
        logger.log("DeepLinkHandler initialized", category: .general, level: .info, metadata: nil)
        DeviceLogger.shared.log("🔗 [DeepLink] DeepLinkHandler initialized")
    }

    // MARK: - App Lifecycle

    /// Set the ModelContext for video job creation
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    /// Call when app is ready to handle URLs (views are loaded)
    func markAppReady() {
        Log.info("App marked as ready for deep links", category: .general)
        DeviceLogger.shared.log("✅ [DeepLink] App marked as ready for deep links")
        isAppReady = true

        // Process all queued URLs
        if !queuedURLs.isEmpty {
            Log.info("Processing queued URLs", category: .general, metadata: ["count": queuedURLs.count])
            DeviceLogger.shared.log("📱 [DeepLink] Processing \(queuedURLs.count) queued URL(s)")
            for url in queuedURLs {
                Log.debug("Processing queued URL", category: .general, metadata: ["url": url.absoluteString])
                DeviceLogger.shared.log("  [DeepLink] - \(url.absoluteString)")
                processURL(url)
            }
            queuedURLs.removeAll()
        }

        // Process any queued activity
        if let activity = queuedActivity {
            Log.info("Processing queued user activity", category: .general)
            DeviceLogger.shared.log("📱 [DeepLink] Processing queued user activity")
            processUserActivity(activity)
            queuedActivity = nil
        }
    }

    // MARK: - URL Handling

    /// Handle incoming URL (called from App scene)
    func handle(_ url: URL) {
        Log.info("Received deep link URL", category: .general, metadata: ["url": url.absoluteString])
        DeviceLogger.shared.log("📥 [DeepLink] DeepLinkHandler received URL: \(url.absoluteString)")

        // DUPLICATE PREVENTION: Check if this is a duplicate within the time window
        if let lastURL = lastProcessedURL,
           let lastTime = lastProcessedTime,
           lastURL.absoluteString == url.absoluteString,
           Date().timeIntervalSince(lastTime) < duplicateWindowSeconds {
            Log.warning("Ignoring duplicate URL", category: .general, metadata: ["timeSinceLastProcess": Date().timeIntervalSince(lastTime)])
            DeviceLogger.shared.log("⚠️ [DeepLink] Ignoring duplicate URL")
            return
        }

        if isAppReady {
            Log.debug("App ready, processing URL immediately", category: .general)
            DeviceLogger.shared.log("✅ [DeepLink] App is ready, processing immediately")
            processURL(url)
        } else {
            Log.debug("App not ready, queuing URL", category: .general)
            DeviceLogger.shared.log("⏳ [DeepLink] App not ready, queuing URL for later")
            // Only add if not already in queue
            if !queuedURLs.contains(where: { $0.absoluteString == url.absoluteString }) {
                queuedURLs.append(url)
                Log.debug("URL added to queue", category: .general, metadata: ["queueCount": queuedURLs.count])
                DeviceLogger.shared.log("  [DeepLink] Queue now has \(queuedURLs.count) URL(s)")
            } else {
                Log.debug("URL already in queue, skipping", category: .general)
                DeviceLogger.shared.log("  [DeepLink] URL already in queue, skipping")
            }
        }
    }

    /// Handle user activity (for universal links)
    func handle(_ userActivity: NSUserActivity) {
        Log.info("Received user activity", category: .general, metadata: ["activityType": userActivity.activityType])

        if isAppReady {
            Log.debug("App ready, processing user activity immediately", category: .general)
            processUserActivity(userActivity)
        } else {
            Log.debug("App not ready, queuing user activity", category: .general)
            queuedActivity = userActivity
        }
    }

    // MARK: - Private Processing

    private func processURL(_ url: URL) {
        Log.debug("Processing URL", category: .general, metadata: ["url": url.absoluteString])
        DeviceLogger.shared.log("🔄 [DeepLink] Processing URL: \(url.absoluteString)")

        // Record as processed (for duplicate prevention)
        lastProcessedURL = url
        lastProcessedTime = Date()

        // Determine URL type
        if url.scheme == "heirloom" {
            DeviceLogger.shared.log("🔗 [DeepLink] Detected heirloom:// URL scheme")
            handleHeirloomURL(url)
        } else if url.scheme == "https" && url.host == "heirloom.app" {
            DeviceLogger.shared.log("🌐 [DeepLink] Detected universal link (heirloom.app)")
            handleUniversalLink(url)
        } else {
            Log.warning("Unknown URL scheme", category: .general, metadata: ["scheme": url.scheme ?? "nil", "host": url.host ?? "nil"])
            DeviceLogger.shared.log("⚠️ [DeepLink] Unknown URL scheme: \(url.scheme ?? "nil") - \(url.host ?? "nil")")
        }
    }

    private func processUserActivity(_ userActivity: NSUserActivity) {
        Log.debug("Processing user activity", category: .general, metadata: ["activityType": userActivity.activityType])
        DeviceLogger.shared.log("🔄 [DeepLink] Processing user activity: \(userActivity.activityType)")

        // Universal link handling
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            Log.info("Extracted URL from user activity", category: .general, metadata: ["url": url.absoluteString])
            DeviceLogger.shared.log("✅ [DeepLink] Extracted URL from user activity: \(url.absoluteString)")
            processURL(url)
        } else {
            Log.warning("User activity has no webpage URL", category: .general)
            DeviceLogger.shared.log("⚠️ [DeepLink] User activity has no webpage URL")
        }
    }

    // MARK: - Heirloom URL Scheme (heirloom://)

    private func handleHeirloomURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            Log.error("Invalid heirloom:// URL format", category: .general)
            DeviceLogger.shared.log("❌ [DeepLink] Invalid heirloom:// URL")
            return
        }

        // Parse: heirloom://share/{shareID} OR heirloom://import?url=...
        if components.host == "share" {
            // Handle Firebase recipe share
            // Extract shareID from path (remove leading /)
            let shareID = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            guard !shareID.isEmpty else {
                Log.error("Empty share ID in heirloom:// URL", category: .general)
                DeviceLogger.shared.log("❌ [DeepLink] Empty share ID in heirloom:// URL")
                return
            }

            Log.info("Extracted share ID from deep link", category: .general, metadata: ["shareId": shareID])
            DeviceLogger.shared.log("✅ [DeepLink] Extracted share ID: \(shareID)")

            handleFirebaseShare(shareID: shareID, originalURL: url)

        } else if components.host == "import" {
            // Check for video import with ID (new Share Extension format)
            if let idString = components.queryItems?.first(where: { $0.name == "id" })?.value,
               let importID = UUID(uuidString: idString) {
                Log.info("Extracted video import ID from deep link", category: .general, metadata: ["importId": importID.uuidString])
                DeviceLogger.shared.log("✅ [DeepLink] Extracted video import ID: \(importID.uuidString)")

                handleVideoImport(importID)
                return
            }

            // Fallback: Handle URL import (old format)
            if let urlString = components.queryItems?.first(where: { $0.name == "url" })?.value,
               let importURL = URL(string: urlString) {
                Log.info("Extracted import URL from deep link", category: .general, metadata: ["importUrl": importURL.absoluteString])
                DeviceLogger.shared.log("✅ [DeepLink] Extracted import URL: \(importURL.absoluteString)")

                handleURLImport(importURL)
                return
            }

            Log.error("Invalid import parameters in heirloom:// URL", category: .general)
            DeviceLogger.shared.log("❌ [DeepLink] Invalid import parameters in heirloom:// URL")

        } else if components.host == "video-job" {
            // Handle video processing job notification
            // Format: heirloom://video-job/{jobId}/{action}
            let pathComponents = components.path.split(separator: "/")
            guard pathComponents.count == 2,
                  let jobID = UUID(uuidString: String(pathComponents[0])),
                  let action = VideoJobAction(rawValue: String(pathComponents[1])) else {
                Log.error("Invalid video-job URL format", category: .video)
                DeviceLogger.shared.log("❌ [DeepLink] Invalid video-job URL format")
                return
            }

            Log.info("Extracted video job from deep link", category: .video, metadata: [
                "jobId": jobID.uuidString,
                "action": action.rawValue
            ])
            DeviceLogger.shared.log("✅ [DeepLink] Video job: \(jobID.uuidString) - \(action.rawValue)")

            handleVideoJob(jobID: jobID, action: action)

        } else {
            Log.error("Invalid heirloom:// host", category: .general, metadata: ["host": components.host ?? "nil"])
            DeviceLogger.shared.log("❌ [DeepLink] Invalid heirloom:// host: \(components.host ?? "nil")")
        }
    }

    // MARK: - Firebase Share Handling

    private func handleFirebaseShare(shareID: String, originalURL: URL) {
        Log.info("Handling Firebase share", category: .firebase, metadata: ["shareId": shareID])
        DeviceLogger.shared.log("🔥 [DeepLink] Handling Firebase share ID: \(shareID)")

        // Store URL for acceptance flow
        pendingShareURL = originalURL

        // Fetch share metadata from Firebase
        Task {
            do {
                Log.debug("Fetching share metadata from Firebase", category: .firebase)
                DeviceLogger.shared.log("🔍 [DeepLink] Fetching share metadata from Firebase...")
                let metadata = try await firebaseShare.fetchShareMetadata(shareId: shareID)

                await MainActor.run {
                    Log.info("Share metadata fetched successfully", category: .firebase)
                    DeviceLogger.shared.log("✅ [DeepLink] Share metadata fetched successfully")
                    pendingShareMetadata = metadata
                    showShareAcceptanceSheet = true
                    DeviceLogger.shared.log("📋 [DeepLink] Setting showShareAcceptanceSheet = true")
                }

            } catch {
                Log.error("Failed to fetch share metadata", category: .firebase, error: error)
                DeviceLogger.shared.log("❌ [DeepLink] Failed to fetch share metadata: \(error.localizedDescription)", level: .error)

                // Still show acceptance sheet even if metadata fetch fails
                // User can try to accept anyway
                await MainActor.run {
                    Log.warning("Showing acceptance sheet without metadata", category: .ui)
                    DeviceLogger.shared.log("⚠️ [DeepLink] Showing acceptance sheet without metadata")
                    showShareAcceptanceSheet = true
                    DeviceLogger.shared.log("📋 [DeepLink] Setting showShareAcceptanceSheet = true (no metadata)")
                }
            }
        }
    }

    // MARK: - URL Import Handling (from share extension)

    private func handleURLImport(_ url: URL) {
        Log.info("Handling URL import from share extension", category: .general, metadata: ["url": url.absoluteString])
        DeviceLogger.shared.log("🔗 [DeepLink] Handling URL import from share extension: \(url.absoluteString)")

        // Store URL for import flow
        pendingImportURL = url
        showURLImportSheet = true

        Log.info("URL import sheet triggered", category: .ui)
        DeviceLogger.shared.log("✅ [DeepLink] URL import sheet triggered")
    }

    // MARK: - Video Import Handling (from share extension)

    private func handleVideoImport(_ importID: UUID) {
        Log.info("Handling import from share extension", category: .general, metadata: ["importId": importID.uuidString])
        DeviceLogger.shared.log("📥 [DeepLink] Handling import from share extension: \(importID.uuidString)")

        // Load the pending import to determine if it's a video or URL
        Task {
            let pendingImport = await PendingImportManager.shared.load(id: importID)

            guard let importData = pendingImport else {
                Log.error("Pending import not found", category: .general, metadata: ["importId": importID.uuidString])
                DeviceLogger.shared.log("❌ [DeepLink] Pending import not found: \(importID.uuidString)")
                return
            }

            // Check for bulk content import FIRST (no file URL)
            if importData.sourceType == .shareExtensionBulk {
                // Bulk content from Notes (URLs + optional text recipes)
                Log.info("Bulk content import detected", category: .general)
                DeviceLogger.shared.log("📋 [DeepLink] Bulk content import detected")

                guard let bulkContent = importData.bulkContent else {
                    Log.error("Bulk import missing content", category: .general)
                    DeviceLogger.shared.log("❌ [DeepLink] Bulk import missing content")
                    return
                }

                guard let context = modelContext else {
                    Log.error("ModelContext not available", category: .general)
                    DeviceLogger.shared.log("❌ [DeepLink] ModelContext not available - cannot process bulk import")
                    return
                }

                // Step 1: If there are URLs, create bulk URL import job
                if !bulkContent.urls.isEmpty {
                    Log.info("Processing URLs from bulk content", category: .general, metadata: ["count": bulkContent.urls.count])
                    DeviceLogger.shared.log("🔗 [DeepLink] Processing \(bulkContent.urls.count) URL(s) from bulk content")

                    do {
                        let importManager = ServiceContainer.shared.resolve(ImportJobManager.self)

                        // Create bulk URL import job
                        let job = try importManager.createJob(
                            urls: bulkContent.urls,
                            jobName: "Notes Import",
                            context: context
                        )

                        Log.info("Bulk URL import job created", category: .general, metadata: ["jobId": job.id.uuidString])
                        DeviceLogger.shared.log("✅ [DeepLink] Bulk URL import job created: \(job.id.uuidString)")

                        // Show import progress sheet
                        await MainActor.run {
                            pendingImportJobID = job.id
                            showImportProgressSheet = true
                        }

                        // Start the job (background task)
                        Task {
                            do {
                                try await importManager.startJob(job, context: context)
                                Log.info("Bulk URL import job completed", category: .general, metadata: ["jobId": job.id.uuidString])
                                DeviceLogger.shared.log("✅ [DeepLink] Bulk URL import job completed: \(job.id.uuidString)")
                            } catch {
                                Log.error("Failed to process bulk URL import job", category: .general, metadata: ["error": error.localizedDescription])
                                DeviceLogger.shared.log("❌ [DeepLink] Failed to process bulk URL import job: \(error.localizedDescription)")
                            }
                        }
                    } catch {
                        Log.error("Failed to create bulk URL import job", category: .general, metadata: ["error": error.localizedDescription])
                        DeviceLogger.shared.log("❌ [DeepLink] Failed to create bulk URL import job: \(error.localizedDescription)")
                    }
                }

                // Step 2: If there's recipe text, extract and show selection UI
                if bulkContent.hasRecipeText, let plainText = bulkContent.plainText {
                    Log.info("Processing recipe text from bulk content", category: .general, metadata: ["textLength": plainText.count])
                    DeviceLogger.shared.log("📝 [DeepLink] Processing recipe text from bulk content")

                    // Show loading UI
                    await MainActor.run {
                        isExtractingTextRecipes = true
                        textExtractionProgress = "Extracting recipes from text..."
                    }

                    do {
                        // Get AI extractor
                        let aiExtractor = ServiceContainer.shared.resolve(AIRecipeExtractor.self)

                        // Extract multiple recipes from plain text
                        Log.info("Extracting recipes from plain text", category: .general)
                        DeviceLogger.shared.log("🤖 [DeepLink] Extracting recipes from plain text")

                        let result = try await aiExtractor.extractMultipleRecipes(
                            from: plainText,
                            sourceImage: nil
                        )

                        Log.info("Recipe extraction complete", category: .general, metadata: ["count": result.recipes.count])
                        DeviceLogger.shared.log("✅ [DeepLink] Extracted \(result.recipes.count) recipe(s) from text")

                        // Hide loading UI and show recipe selection sheet
                        await MainActor.run {
                            isExtractingTextRecipes = false
                            textExtractionProgress = ""
                            pendingTextRecipeResult = result
                            showTextRecipeSelectionSheet = true
                        }
                    } catch {
                        Log.error("Failed to extract recipes from text", category: .general, metadata: ["error": error.localizedDescription])
                        DeviceLogger.shared.log("❌ [DeepLink] Failed to extract recipes from text: \(error.localizedDescription)")

                        // Hide loading UI on error
                        await MainActor.run {
                            isExtractingTextRecipes = false
                            textExtractionProgress = ""
                        }
                    }
                }

                // Clean up the pending import after processing
                await PendingImportManager.shared.delete(id: importID)

            } else if let fileURL = importData.localVideoURL {
                // Check source type to determine how to handle the file
                switch importData.sourceType {
                case .shareExtensionVideo:
                    // Video file import - add to background processing queue
                    Log.info("Video file import detected - adding to video queue", category: .general)
                    DeviceLogger.shared.log("🎥 [DeepLink] Video file import detected - adding to queue")

                    // Create a video processing job for background processing
                    guard let context = modelContext else {
                        Log.error("ModelContext not available", category: .general)
                        DeviceLogger.shared.log("❌ [DeepLink] ModelContext not available - cannot create video job")
                        return
                    }

                    do {
                        let jobManager = ServiceContainer.shared.resolve(VideoProcessingJobManager.self)

                        let job = try jobManager.createJob(
                            videoURL: fileURL,
                            videoType: .standard,
                            userCaption: nil,
                            videoDuration: nil,
                            sourceAttribution: nil,
                            context: context
                        )

                        try context.save()

                        // Clean up the pending import
                        await PendingImportManager.shared.delete(id: importID)

                        Log.info("Video processing job created", category: .general, metadata: ["jobId": job.id.uuidString])
                        DeviceLogger.shared.log("✅ [DeepLink] Video job created: \(job.id.uuidString)")
                    } catch {
                        Log.error("Failed to create video job", category: .general, metadata: ["error": error.localizedDescription])
                        DeviceLogger.shared.log("❌ [DeepLink] Failed to create video job: \(error.localizedDescription)")
                    }

                case .shareExtensionPDF:
                    // PDF file import - process directly using ImportJobManager
                    Log.info("PDF import detected - processing directly", category: .general, metadata: ["url": fileURL.absoluteString])
                    DeviceLogger.shared.log("📄 [DeepLink] PDF import detected - processing: \(fileURL.absoluteString)")

                    guard let context = modelContext else {
                        Log.error("ModelContext not available", category: .general)
                        DeviceLogger.shared.log("❌ [DeepLink] ModelContext not available - cannot process PDF")
                        return
                    }

                    do {
                        let importManager = ServiceContainer.shared.resolve(ImportJobManager.self)

                        // Create PDF import job (analysis phase)
                        let job = try await importManager.createAndAnalyzePDFJob(
                            pdfURLs: [fileURL],
                            jobName: "Shared Recipe",
                            cookbookName: "Shared Recipes",
                            context: context
                        )

                        // Clean up the pending import
                        await PendingImportManager.shared.delete(id: importID)

                        Log.info("PDF import job created", category: .general, metadata: ["jobId": job.id.uuidString])
                        DeviceLogger.shared.log("✅ [DeepLink] PDF import job created: \(job.id.uuidString)")

                        // Show import progress sheet
                        await MainActor.run {
                            pendingImportJobID = job.id
                            showImportProgressSheet = true
                        }

                        // Start extraction phase (background task)
                        Task {
                            do {
                                try await importManager.startJob(job, context: context)
                                Log.info("PDF import job completed", category: .general, metadata: ["jobId": job.id.uuidString])
                                DeviceLogger.shared.log("✅ [DeepLink] PDF import job completed: \(job.id.uuidString)")
                            } catch {
                                Log.error("Failed to process PDF import job", category: .general, metadata: ["error": error.localizedDescription])
                                DeviceLogger.shared.log("❌ [DeepLink] Failed to process PDF import job: \(error.localizedDescription)")
                            }
                        }
                    } catch {
                        Log.error("Failed to create PDF import job", category: .general, metadata: ["error": error.localizedDescription])
                        DeviceLogger.shared.log("❌ [DeepLink] Failed to create PDF import job: \(error.localizedDescription)")
                    }

                case .shareExtensionImage:
                    // Image file import - detect recipes and show selection UI (like camera scanner)
                    Log.info("Image import detected - detecting recipes", category: .general, metadata: ["url": fileURL.absoluteString])
                    DeviceLogger.shared.log("📸 [DeepLink] Image import detected - detecting recipes: \(fileURL.absoluteString)")

                    // Show loading UI
                    await MainActor.run {
                        isExtractingImageRecipes = true
                        imageExtractionProgress = "Loading image..."
                    }

                    do {
                        // Load the image
                        guard let image = UIImage(contentsOfFile: fileURL.path) else {
                            throw NSError(domain: "DeepLinkHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])
                        }

                        // Get AI extractor
                        let aiExtractor = ServiceContainer.shared.resolve(AIRecipeExtractor.self)

                        // Step 1: Detect recipes with bounding boxes (vision API)
                        await MainActor.run {
                            imageExtractionProgress = "Detecting recipes..."
                        }

                        Log.info("Detecting recipes in shared image", category: .general)
                        DeviceLogger.shared.log("🔍 [DeepLink] Detecting recipes in shared image")

                        let detected = try await aiExtractor.detectRecipes(from: image)

                        Log.info("Found recipes in image", category: .general, metadata: ["count": detected.count])
                        DeviceLogger.shared.log("✅ [DeepLink] Found \(detected.count) recipe(s) in image")

                        // Step 2: Extract each recipe using vision API + bounding box
                        await MainActor.run {
                            imageExtractionProgress = "Extracting \(detected.count) recipe\(detected.count == 1 ? "" : "s")..."
                        }

                        Log.info("Extracting recipes from image", category: .general)
                        DeviceLogger.shared.log("🤖 [DeepLink] Extracting recipes from image")

                        let result = try await aiExtractor.extractRecipesFromImage(
                            image: image,
                            detectedRecipes: detected
                        )

                        // Clean up the pending import
                        await PendingImportManager.shared.delete(id: importID)

                        Log.info("Recipe extraction complete", category: .general, metadata: ["count": result.recipes.count])
                        DeviceLogger.shared.log("✅ [DeepLink] Extracted \(result.recipes.count) recipe(s)")

                        // Hide loading UI and show recipe selection sheet
                        await MainActor.run {
                            isExtractingImageRecipes = false
                            imageExtractionProgress = ""
                            pendingImageRecipeResult = result
                            showImageRecipeSelectionSheet = true
                        }
                    } catch {
                        Log.error("Failed to extract recipes from image", category: .general, metadata: ["error": error.localizedDescription])
                        DeviceLogger.shared.log("❌ [DeepLink] Failed to extract recipes: \(error.localizedDescription)")

                        // Hide loading UI on error
                        await MainActor.run {
                            isExtractingImageRecipes = false
                            imageExtractionProgress = ""
                        }
                    }

                default:
                    // Legacy or unknown source type - treat as video for backwards compatibility
                    Log.warning("Unknown source type, treating as video", category: .general, metadata: ["sourceType": importData.sourceType.rawValue])
                    DeviceLogger.shared.log("⚠️ [DeepLink] Unknown source type: \(importData.sourceType.rawValue), treating as video")

                    guard let context = modelContext else {
                        Log.error("ModelContext not available", category: .general)
                        DeviceLogger.shared.log("❌ [DeepLink] ModelContext not available - cannot create video job")
                        return
                    }

                    do {
                        let jobManager = ServiceContainer.shared.resolve(VideoProcessingJobManager.self)

                        let job = try jobManager.createJob(
                            videoURL: fileURL,
                            videoType: .standard,
                            userCaption: nil,
                            videoDuration: nil,
                            sourceAttribution: nil,
                            context: context
                        )

                        try context.save()
                        await PendingImportManager.shared.delete(id: importID)

                        Log.info("Video processing job created", category: .general, metadata: ["jobId": job.id.uuidString])
                        DeviceLogger.shared.log("✅ [DeepLink] Video job created: \(job.id.uuidString)")
                    } catch {
                        Log.error("Failed to create video job", category: .general, metadata: ["error": error.localizedDescription])
                        DeviceLogger.shared.log("❌ [DeepLink] Failed to create video job: \(error.localizedDescription)")
                    }
                }
            } else if let url = importData.originalURL {
                // URL-only import (recipe URL) - show URL import sheet
                await MainActor.run {
                    Log.info("Recipe URL import detected", category: .general, metadata: ["url": url.absoluteString])
                    DeviceLogger.shared.log("🔗 [DeepLink] Recipe URL import detected: \(url.absoluteString)")

                    pendingImportURL = url
                    showURLImportSheet = true
                }

                // Clean up the pending import since we've extracted the URL
                await PendingImportManager.shared.delete(id: importID)
            } else {
                Log.error("Invalid pending import - no video or URL", category: .general)
                DeviceLogger.shared.log("❌ [DeepLink] Invalid pending import - no video or URL")
            }
        }
    }

    // MARK: - Video Job Handling (from notifications)

    private func handleVideoJob(jobID: UUID, action: VideoJobAction) {
        Log.info("Handling video job notification", category: .video, metadata: [
            "jobId": jobID.uuidString,
            "action": action.rawValue
        ])
        DeviceLogger.shared.log("🎥 [DeepLink] Handling video job: \(jobID.uuidString) - \(action.rawValue)")

        // Store job info for handling
        pendingVideoJobID = jobID
        pendingVideoJobAction = action
        showVideoJobSheet = true

        Log.info("Video job sheet triggered", category: .video)
        DeviceLogger.shared.log("✅ [DeepLink] Video job sheet triggered")
    }

    // MARK: - Universal Links (heirloom.app)

    private func handleUniversalLink(_ url: URL) {
        Log.info("Handling universal link", category: .general, metadata: ["url": url.absoluteString])

        let pathComponents = url.pathComponents

        // Parse: https://heirloom.app/share/{shareID}
        if pathComponents.count >= 3 && pathComponents[1] == "share" {
            let shareID = pathComponents[2]
            Log.info("Extracted share ID from universal link", category: .general, metadata: ["shareId": shareID])
            handleFirebaseShare(shareID: shareID, originalURL: url)
            return
        }

        // Parse: https://heirloom.app/import?id={UUID}
        if pathComponents.count >= 2 && pathComponents[1] == "import" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let queryItems = components.queryItems,
                  let importID = queryItems.first(where: { $0.name == "id" })?.value,
                  let uuid = UUID(uuidString: importID) else {
                Log.error("Invalid import ID in universal link", category: .general)
                DeviceLogger.shared.log("❌ [DeepLink] Invalid import ID in universal link")
                return
            }

            Log.info("Extracted import ID from universal link", category: .general, metadata: ["importId": importID])
            DeviceLogger.shared.log("✅ [DeepLink] Extracted import ID from universal link: \(importID)")

            // Handle video import same as custom URL scheme
            handleVideoImport(uuid)
            return
        }

        Log.error("Invalid universal link path", category: .general, metadata: ["path": url.path])
        DeviceLogger.shared.log("❌ [DeepLink] Invalid universal link path: \(url.path)")
    }

    // MARK: - Public API

    /// Clear pending share (called after acceptance/decline)
    func clearPendingShare() {
        Log.debug("Clearing pending share", category: .general)
        pendingShareURL = nil
        pendingShareMetadata = nil
        showShareAcceptanceSheet = false
    }

    /// Clear pending URL import (called after processing)
    func clearPendingImport() {
        Log.debug("Clearing pending URL import", category: .general)
        DeviceLogger.shared.log("🧹 [DeepLink] Clearing pending URL import")
        pendingImportURL = nil
        showURLImportSheet = false
    }

    /// Clear pending PDF import (called after processing)
    func clearPendingPDFImport() {
        Log.debug("Clearing pending PDF import", category: .general)
        DeviceLogger.shared.log("🧹 [DeepLink] Clearing pending PDF import")
        pendingPDFURL = nil
        showPDFImportSheet = false
    }

    /// Clear pending image import (called after processing)
    func clearPendingImageImport() {
        Log.debug("Clearing pending image import", category: .general)
        DeviceLogger.shared.log("🧹 [DeepLink] Clearing pending image import")
        pendingImageURL = nil
        showImageImportSheet = false
    }

    /// Clear pending import progress (called after viewing/dismissing)
    func clearImportProgress() {
        Log.debug("Clearing import progress sheet", category: .general)
        DeviceLogger.shared.log("🧹 [DeepLink] Clearing import progress sheet")
        pendingImportJobID = nil
        showImportProgressSheet = false
    }

    /// Clear pending image recipe selection (called after saving/dismissing)
    func clearImageRecipeSelection() {
        Log.debug("Clearing image recipe selection", category: .general)
        DeviceLogger.shared.log("🧹 [DeepLink] Clearing image recipe selection")
        pendingImageRecipeResult = nil
        showImageRecipeSelectionSheet = false
    }

    /// Clear pending text recipe selection (called after saving/dismissing)
    func clearTextRecipeSelection() {
        Log.debug("Clearing text recipe selection", category: .general)
        DeviceLogger.shared.log("🧹 [DeepLink] Clearing text recipe selection")
        pendingTextRecipeResult = nil
        showTextRecipeSelectionSheet = false
    }

    /// Clear pending video import (called after processing)
    func clearPendingVideoImport() {
        Log.debug("Clearing pending video import", category: .general)
        DeviceLogger.shared.log("🧹 [DeepLink] Clearing pending video import")
        pendingVideoImportID = nil
        showVideoImportSheet = false
    }

    /// Clear pending video job (called after handling)
    func clearPendingVideoJob() {
        Log.debug("Clearing pending video job", category: .video)
        DeviceLogger.shared.log("🧹 [DeepLink] Clearing pending video job")
        pendingVideoJobID = nil
        pendingVideoJobAction = nil
        showVideoJobSheet = false
    }

    /// Check if there's a pending share to accept
    var hasPendingShare: Bool {
        pendingShareURL != nil
    }

    /// Check if there's a pending URL import
    var hasPendingImport: Bool {
        pendingImportURL != nil
    }

    /// Check if there's a pending video job
    var hasPendingVideoJob: Bool {
        pendingVideoJobID != nil
    }

    /// Reset handler (for testing)
    func reset() {
        Log.info("Resetting deep link handler", category: .general)
        isAppReady = false
        queuedURLs.removeAll()
        queuedActivity = nil
        lastProcessedURL = nil
        lastProcessedTime = nil
        clearPendingShare()
        clearPendingImport()
        clearPendingVideoJob()
    }
}

// MARK: - Type Alias for Compatibility

/// Alias for DeepLinkCoordinator (same as DeepLinkHandler)
typealias DeepLinkCoordinator = DeepLinkHandler

// MARK: - Errors

enum DeepLinkError: LocalizedError {
    case invalidURL
    case noMetadata
    case unsupportedScheme

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noMetadata:
            return "Could not fetch share information"
        case .unsupportedScheme:
            return "Unsupported URL scheme"
        }
    }
}

