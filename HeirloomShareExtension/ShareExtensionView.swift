import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// SwiftUI view for Share Extension
struct ShareExtensionView: View {
    let extensionContext: NSExtensionContext?
    let onComplete: (Bool) -> Void

    @State private var state: ShareState = .loading
    @State private var errorMessage: String?
    @State private var detectedPlatform: String?

    enum ShareState {
        case loading
        case processingVideo
        case processingURL
        case processingPDF
        case processingImage
        case processingImageBatch(Int)  // Processing N images from Photos
        case processingBulk(Int)  // Processing N items from Notes
        case successVideo
        case successURL
        case successPDF
        case successImage
        case successImageBatch(Int)  // Successfully saved N images
        case successBulk(itemCount: Int)
        case error(String)
        case socialMediaInstructions(String)  // Show instructions for TikTok/IG
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Icon
                iconView

                // Status message
                statusView

                Spacer()

                // Action buttons
                if case .error = state {
                    Button("Cancel") {
                        onComplete(false)
                    }
                    .padding()
                } else if case .socialMediaInstructions = state {
                    Button("Got It") {
                        onComplete(false)
                    }
                    .padding()
                }
            }
            .padding()
            .navigationTitle("Import to Heirloom")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await processSharedContent()
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch state {
        case .loading:
            ProgressView()
                .scaleEffect(1.5)

        case .processingVideo:
            Image(systemName: "video.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

        case .processingURL:
            Image(systemName: "link.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

        case .processingPDF:
            Image(systemName: "doc.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

        case .processingImage:
            Image(systemName: "photo.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

        case .processingImageBatch:
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

        case .processingBulk:
            Image(systemName: "doc.on.doc.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

        case .successVideo, .successURL, .successPDF, .successImage, .successImageBatch, .successBulk:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)

        case .socialMediaInstructions:
            Image(systemName: "info.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch state {
        case .loading:
            Text("Loading...")
                .font(.headline)

        case .processingVideo:
            VStack(spacing: 8) {
                Text("Saving video...")
                    .font(.headline)
                ProgressView()
            }

        case .processingURL:
            VStack(spacing: 8) {
                Text("Processing URL...")
                    .font(.headline)
                ProgressView()
            }

        case .processingPDF:
            VStack(spacing: 8) {
                Text("Saving PDF...")
                    .font(.headline)
                ProgressView()
            }

        case .processingImage:
            VStack(spacing: 8) {
                Text("Saving image...")
                    .font(.headline)
                ProgressView()
            }

        case .processingImageBatch(let count):
            VStack(spacing: 8) {
                Text("Saving \(count) image\(count == 1 ? "" : "s")...")
                    .font(.headline)
                ProgressView()
            }

        case .processingBulk(let count):
            VStack(spacing: 8) {
                Text("Processing \(count) item\(count == 1 ? "" : "s")...")
                    .font(.headline)
                ProgressView()
            }

        case .successVideo:
            VStack(spacing: 8) {
                Text("Video Saved!")
                    .font(.headline)
                Text("Open Heirloom to import")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .successURL:
            VStack(spacing: 8) {
                Text("Saved!")
                    .font(.headline)
                Text("Opening Heirloom...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .successPDF:
            VStack(spacing: 8) {
                Text("PDF Saved!")
                    .font(.headline)
                Text("Open Heirloom to import")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .successImage:
            VStack(spacing: 8) {
                Text("Image Saved!")
                    .font(.headline)
                Text("Open Heirloom to import")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .successImageBatch(let count):
            VStack(spacing: 8) {
                Text("Saved \(count) Image\(count == 1 ? "" : "s")!")
                    .font(.headline)
                Text("Open Heirloom to import")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .successBulk(let itemCount):
            VStack(spacing: 8) {
                Text("Saved \(itemCount) Item\(itemCount == 1 ? "" : "s")!")
                    .font(.headline)
                Text("Opening Heirloom...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .error(let message):
            VStack(spacing: 8) {
                Text("Error")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

        case .socialMediaInstructions(let platformName):
            VStack(spacing: 12) {
                Text("How to Import from \(platformName)")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text("1.")
                        Text("Save the video to your Camera Roll")
                    }
                    HStack(alignment: .top) {
                        Text("2.")
                        Text("Open Heirloom → tap +")
                    }
                    HStack(alignment: .top) {
                        Text("3.")
                        Text("Select the video from your library")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text("We can't download videos directly from \(platformName) due to platform restrictions.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Content Processing

    private func processSharedContent() async {
        do {
            let content = try await loadSharedContent()

            switch content {
            case .video(let videoURL):
                state = .processingVideo
                try await handleVideo(videoURL)

            case .url(let url):
                state = .processingURL
                try await handleURL(url)

            case .pdf(let pdfURL):
                state = .processingPDF
                try await handlePDF(pdfURL)

            case .image(let imageURL):
                state = .processingImage
                try await handleImage(imageURL)

            case .imageBatch(let imageURLs):
                state = .processingImageBatch(imageURLs.count)
                try await handleImageBatch(imageURLs)

            case .bulkContent(let urls, let text, let hasRecipe):
                state = .processingBulk(urls.count + (hasRecipe ? 1 : 0))
                try await handleBulkContent(urls: urls, text: text, hasRecipe: hasRecipe)

            case .unsupported:
                state = .error("This content type is not supported")
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func loadSharedContent() async throws -> SharedContent {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            throw ShareError.noContent
        }

        // Check if we have multiple attachments (batch import)
        guard let attachments = extensionItem.attachments, !attachments.isEmpty else {
            throw ShareError.noContent
        }

        // PRIORITY 1: Check for actual video files (from Photos/Camera Roll)
        // This must come first to avoid treating video file:// URLs as web URLs
        if attachments[0].hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            let videoURL = try await loadVideo(from: attachments[0])
            return .video(videoURL)
        }

        // PRIORITY 2: Check for PDF files (from Files app, email, etc.)
        if attachments[0].hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            let pdfURL = try await loadPDF(from: attachments[0])
            return .pdf(pdfURL)
        }

        // PRIORITY 3: Check for images (from Photos, screenshots, etc.)
        // Handle both single and multiple images
        let imageAttachments = attachments.filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }

        if !imageAttachments.isEmpty {
            if imageAttachments.count == 1 {
                // Single image - use existing flow
                let imageURL = try await loadImage(from: imageAttachments[0])
                return .image(imageURL)
            } else {
                // Multiple images - use batch flow
                var imageURLs: [URL] = []
                for attachment in imageAttachments {
                    if let url = try? await loadImage(from: attachment) {
                        imageURLs.append(url)
                    }
                }
                if !imageURLs.isEmpty {
                    return .imageBatch(imageURLs)
                }
            }
        }

        // Fall back to first attachment for other types
        let itemProvider = attachments[0]

        // PRIORITY 4: Check for web URLs (http/https)
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            let url = try await loadURL(from: itemProvider)

            print("📋 Share Extension: Received URL with scheme: \(url.scheme ?? "nil")")
            print("📋 Share Extension: Full URL: \(url.absoluteString)")

            // Accept http/https URLs (web pages)
            if url.scheme == "http" || url.scheme == "https" {
                return .url(url)
            }

            // For Apple News and other special URL schemes, try to extract the actual web URL
            // Apple News often wraps URLs like: apple-news://article?id=...&url=<actual-url>
            if url.scheme == "apple-news" || url.scheme == "applenews" {
                // Try to extract the actual URL from query parameters
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let queryItems = components.queryItems,
                   let urlString = queryItems.first(where: { $0.name == "url" })?.value,
                   let actualURL = URL(string: urlString) {
                    print("📋 Share Extension: Extracted actual URL from Apple News: \(actualURL.absoluteString)")
                    return .url(actualURL)
                }

                // If we can't extract a URL, Apple News articles are still recipe-worthy content
                // Try to get the article URL from plain text if available
                print("📋 Share Extension: Apple News URL couldn't be parsed, checking plain text...")
            }

            // Ignore file:// and other local URLs
            if url.scheme != "file" {
                print("📋 Share Extension: Non-standard URL scheme '\(url.scheme ?? "nil")', checking if we can use it anyway")
            }
        }

        // PRIORITY 5: Check for plain text (might contain URLs or recipe text)
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            let text = try await loadText(from: itemProvider)

            print("📋 Share Extension: Received plain text: \(text.prefix(200))...")

            // Analyze content using NotesContentAnalyzer
            let analysis = NotesContentAnalyzer.analyze(text)

            if analysis.shouldUseBulkImport {
                // Multiple URLs or URLs + recipe text
                print("📋 Share Extension: Using bulk import (multiple URLs or URLs + recipe)")
                return .bulkContent(
                    urls: analysis.urls,
                    text: analysis.plainText,
                    hasRecipe: analysis.hasRecipeContent
                )
            } else if analysis.shouldUseTextImport {
                // Plain text recipe only
                print("📋 Share Extension: Using text import (recipe detected)")
                return .bulkContent(
                    urls: [],
                    text: analysis.plainText,
                    hasRecipe: true
                )
            } else if analysis.urls.count == 1 {
                // Single URL - use existing flow
                print("📋 Share Extension: Found single URL in text: \(analysis.urls[0])")
                if let url = URL(string: analysis.urls[0]) {
                    return .url(url)
                }
            } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Non-empty text with no clear recipe or URL structure
                // Still might be useful - treat as potential recipe text
                print("📋 Share Extension: Plain text with no clear structure, treating as potential recipe")
                return .bulkContent(
                    urls: [],
                    text: text,
                    hasRecipe: false
                )
            }
        }

        print("📋 Share Extension: No supported content type found - returning unsupported")
        return .unsupported
    }

    // MARK: - Video Handling

    private func handleVideo(_ videoURL: URL) async throws {
        // 1. Ensure shared container exists
        guard let sharedVideosURL = SharedConstants.sharedVideosURL else {
            throw ShareError.containerUnavailable
        }

        try FileManager.default.createDirectory(at: sharedVideosURL, withIntermediateDirectories: true)

        // 2. Copy video to shared container
        let pendingImportID = UUID()
        let videoExtension = videoURL.pathExtension
        let destinationURL = sharedVideosURL.appendingPathComponent("\(pendingImportID.uuidString).\(videoExtension)")

        try FileManager.default.copyItem(at: videoURL, to: destinationURL)

        // 3. Create pending import record
        let pendingImport = PendingVideoImport(
            id: pendingImportID,
            sourceType: .shareExtensionVideo,
            localVideoURL: destinationURL,
            originalURL: nil,
            detectedPlatform: .unknown
        )

        // 4. Save to pending imports directory
        try savePendingImport(pendingImport)

        // 5. Open main app
        try await openMainApp(withImportID: pendingImportID)
    }

    // MARK: - URL Handling

    private func handleURL(_ url: URL) async throws {
        print("⚠️ Share Extension: handleURL called with: \(url.absoluteString)")

        // STEP 1: Detect and resolve wrapped URLs (Apple News, AMP, Flipboard, Instapaper)
        let resolver = UniversalURLResolver()
        let resolvedURL: URL

        if let wrapper = await resolver.detectWrapper(url) {
            print("⚠️ Share Extension: Detected \(wrapper.displayName) URL")

            do {
                resolvedURL = try await resolver.resolve(url)
                print("✅ Share Extension: Resolved \(wrapper.displayName) URL to: \(resolvedURL.absoluteString)")
            } catch UniversalURLResolver.ResolutionError.paywallContent {
                let serviceName = wrapper == .appleNews ? "Apple News+" : "this service"
                state = .error("This recipe is only available in \(serviceName) and can't be imported. Try opening the recipe in Safari.")
                return
            } catch {
                print("❌ Share Extension: Resolution failed: \(error)")
                state = .error("Couldn't resolve the link. Try copying the recipe URL from Safari instead.")
                return
            }
        } else {
            // Not a wrapped URL, use original
            resolvedURL = url
        }

        // STEP 2: Check if this is a social media platform (TikTok, Instagram, YouTube, Facebook)
        let host = resolvedURL.host?.lowercased() ?? ""

        // Detect social media platforms
        let isSocialMedia = host.contains("tiktok") ||
                           host.contains("instagram") ||
                           host.contains("youtube") ||
                           host.contains("youtu.be") ||
                           host.contains("facebook") ||
                           host.contains("fb.watch")

        if isSocialMedia {
            // Social media: Show instructions (can't download videos from URLs)
            let platformName: String
            if host.contains("tiktok") {
                platformName = "TikTok"
            } else if host.contains("instagram") {
                platformName = "Instagram"
            } else if host.contains("youtube") || host.contains("youtu.be") {
                platformName = "YouTube"
            } else if host.contains("facebook") || host.contains("fb.watch") {
                platformName = "Facebook"
            } else {
                platformName = "this platform"
            }

            state = .socialMediaInstructions(platformName)
            return
        }

        // STEP 3: Not social media - assume it's a recipe URL
        // Use same polling mechanism as videos - more reliable than context.open()

        // Create pending import record with resolved URL
        let pendingImportID = UUID()
        let pendingImport = PendingVideoImport(
            id: pendingImportID,
            sourceType: .shareExtensionURL,
            localVideoURL: nil,
            originalURL: resolvedURL, // Use resolved URL
            detectedPlatform: .unknown
        )

        // 2. Save to pending imports directory
        try savePendingImport(pendingImport)

        state = .successURL

        // 3. Try to open main app using custom URL scheme
        //    The app will poll for pending imports on next launch if URL opening fails
        var components = URLComponents()
        components.scheme = "heirloom"
        components.host = "import"
        components.queryItems = [URLQueryItem(name: "id", value: pendingImportID.uuidString)]

        if let deepLinkURL = components.url {
            print("⚠️ Share Extension: Attempting to open URL: \(deepLinkURL.absoluteString)")

            // Wait a moment for UI to update
            try await Task.sleep(nanoseconds: 500_000_000)

            // Use responder chain workaround to access UIApplication
            // extensionContext.open() doesn't work for Share Extensions
            let opened = await openURL(deepLinkURL)
            print("⚠️ Share Extension: URL open result: \(opened)")
        } else {
            print("⚠️ Share Extension: Failed to create URL")
        }

        // Wait a bit then complete
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        onComplete(true)
    }

    // MARK: - PDF Handling

    private func handlePDF(_ pdfURL: URL) async throws {
        // 1. Ensure shared container exists
        guard let sharedVideosURL = SharedConstants.sharedVideosURL else {
            throw ShareError.containerUnavailable
        }

        try FileManager.default.createDirectory(at: sharedVideosURL, withIntermediateDirectories: true)

        // 2. Copy PDF to shared container
        let pendingImportID = UUID()
        let pdfExtension = pdfURL.pathExtension
        let destinationURL = sharedVideosURL.appendingPathComponent("\(pendingImportID.uuidString).\(pdfExtension)")

        try FileManager.default.copyItem(at: pdfURL, to: destinationURL)

        // 3. Create pending import record
        let pendingImport = PendingVideoImport(
            id: pendingImportID,
            sourceType: .shareExtensionPDF,
            localVideoURL: destinationURL,
            originalURL: nil,
            detectedPlatform: .unknown
        )

        // 4. Save to pending imports directory
        try savePendingImport(pendingImport)

        // 5. Open main app
        try await openMainApp(withImportID: pendingImportID, successState: .successPDF)
    }

    // MARK: - Image Handling

    private func handleImage(_ imageURL: URL) async throws {
        // 1. Ensure shared container exists
        guard let sharedVideosURL = SharedConstants.sharedVideosURL else {
            throw ShareError.containerUnavailable
        }

        try FileManager.default.createDirectory(at: sharedVideosURL, withIntermediateDirectories: true)

        // 2. Copy image to shared container
        let pendingImportID = UUID()
        let imageExtension = imageURL.pathExtension
        let destinationURL = sharedVideosURL.appendingPathComponent("\(pendingImportID.uuidString).\(imageExtension)")

        try FileManager.default.copyItem(at: imageURL, to: destinationURL)

        // 3. Create pending import record
        let pendingImport = PendingVideoImport(
            id: pendingImportID,
            sourceType: .shareExtensionImage,
            localVideoURL: destinationURL,
            originalURL: nil,
            detectedPlatform: .unknown
        )

        // 4. Save to pending imports directory
        try savePendingImport(pendingImport)

        // 5. Open main app
        try await openMainApp(withImportID: pendingImportID, successState: .successImage)
    }

    private func handleImageBatch(_ imageURLs: [URL]) async throws {
        // 1. Ensure shared container exists
        guard let sharedVideosURL = SharedConstants.sharedVideosURL else {
            throw ShareError.containerUnavailable
        }

        try FileManager.default.createDirectory(at: sharedVideosURL, withIntermediateDirectories: true)

        // 2. Copy all images to shared container
        let pendingImportID = UUID()
        var destinationURLs: [URL] = []

        for (index, imageURL) in imageURLs.enumerated() {
            let imageExtension = imageURL.pathExtension
            let destinationURL = sharedVideosURL.appendingPathComponent("\(pendingImportID.uuidString)_\(index).\(imageExtension)")

            try FileManager.default.copyItem(at: imageURL, to: destinationURL)
            destinationURLs.append(destinationURL)
        }

        // 3. Create pending import record with all image URLs
        var pendingImport = PendingVideoImport(
            id: pendingImportID,
            sourceType: .shareExtensionImageBatch,
            localVideoURL: nil,
            originalURL: nil,
            detectedPlatform: .unknown
        )
        pendingImport.imageURLs = destinationURLs

        // 4. Save to pending imports directory
        try savePendingImport(pendingImport)

        // 5. Open main app
        try await openMainApp(withImportID: pendingImportID, successState: .successImageBatch(imageURLs.count))
    }

    // MARK: - Bulk Content Handling

    private func handleBulkContent(urls: [String], text: String?, hasRecipe: Bool) async throws {
        let pendingImportID = UUID()

        // Create bulk content structure
        let bulkContent = BulkImportContent(
            urls: urls,
            plainText: text,
            hasRecipeText: hasRecipe
        )

        // Create pending import record
        var pendingImport = PendingVideoImport(
            id: pendingImportID,
            sourceType: .shareExtensionBulk,
            localVideoURL: nil,
            originalURL: nil,
            detectedPlatform: .unknown
        )
        pendingImport.bulkContent = bulkContent

        // Save to pending imports directory
        try savePendingImport(pendingImport)

        // Open main app
        try await openMainApp(withImportID: pendingImportID, successState: .successBulk(itemCount: bulkContent.totalItems))
    }

    // MARK: - Helpers

    private func savePendingImport(_ pendingImport: PendingVideoImport) throws {
        guard let pendingImportsURL = SharedConstants.pendingImportsURL else {
            throw ShareError.containerUnavailable
        }

        try FileManager.default.createDirectory(at: pendingImportsURL, withIntermediateDirectories: true)

        let fileURL = pendingImportsURL.appendingPathComponent("\(pendingImport.id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(pendingImport)
        try data.write(to: fileURL)

        // Post notification
        NotificationCenter.default.post(name: SharedConstants.pendingImportAddedNotification, object: nil)
    }

    private func openMainApp(withImportID id: UUID, successState: ShareState = .successVideo) async throws {
        // Create deep link: heirloom://import?id=<UUID>
        var components = URLComponents()
        components.scheme = "heirloom"
        components.host = "import"
        components.queryItems = [URLQueryItem(name: "id", value: id.uuidString)]

        guard let deepLinkURL = components.url else {
            // URL creation failed, but file is saved - complete successfully
            state = successState
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            onComplete(true)
            return
        }

        state = successState

        // Wait for file to be fully written to disk before firing deep link (increased from 0.5s to 1.5s)
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        print("⚠️ Share Extension (video): Attempting to open URL: \(deepLinkURL.absoluteString)")

        // Use responder chain workaround to access UIApplication
        let opened = await openURL(deepLinkURL)
        print("⚠️ Share Extension (video): URL open result: \(opened)")

        // Give the open attempt a moment to work before completing (increased from 0.5s to 1s)
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Complete extension successfully regardless of whether URL opening worked
        // The main app will detect the pending import when it becomes active
        onComplete(true)
    }

    // MARK: - Content Loading

    private func loadVideo(from provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { item, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: ShareError.invalidContent)
                }
            }
        }
    }

    private func loadURL(from provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: ShareError.invalidContent)
                }
            }
        }
    }

    private func loadText(from provider: NSItemProvider) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let text = item as? String {
                    continuation.resume(returning: text)
                } else {
                    continuation.resume(throwing: ShareError.invalidContent)
                }
            }
        }
    }

    private func loadPDF(from provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { item, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: ShareError.invalidContent)
                }
            }
        }
    }

    private func loadImage(from provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: ShareError.invalidContent)
                }
            }
        }
    }

    // MARK: - URL Opening Workaround

    /// Opens a URL using responder chain to access UIApplication
    /// This is a workaround since extensionContext.open() doesn't work for Share Extensions
    @MainActor
    private func openURL(_ url: URL) async -> Bool {
        // Use Objective-C runtime to access UIApplication.shared
        // This works despite APPLICATION_EXTENSION_API_ONLY = YES
        guard let sharedSelector = NSSelectorFromString("sharedApplication") as Optional,
              let shared = UIApplication.perform(sharedSelector)?.takeUnretainedValue() as? UIApplication else {
            print("⚠️ Share Extension: Failed to access UIApplication")
            return false
        }

        return await withCheckedContinuation { continuation in
            shared.open(url, options: [:]) { success in
                continuation.resume(returning: success)
            }
        }
    }
}

// MARK: - Supporting Types

enum SharedContent {
    case video(URL)
    case url(URL)
    case pdf(URL)
    case image(URL)
    case imageBatch([URL])  // Multiple images from Photos
    case bulkContent(urls: [String], text: String?, hasRecipe: Bool)
    case unsupported
}

enum ShareError: LocalizedError {
    case noContent
    case containerUnavailable
    case invalidContent
    case invalidDeepLink

    var errorDescription: String? {
        switch self {
        case .noContent: return "No content to share"
        case .containerUnavailable: return "Shared storage unavailable"
        case .invalidContent: return "Invalid content format"
        case .invalidDeepLink: return "Failed to create app link"
        }
    }
}
