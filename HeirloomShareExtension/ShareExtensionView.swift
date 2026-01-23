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
        case successVideo
        case successURL
        case successPDF
        case successImage
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

        case .successVideo, .successURL, .successPDF, .successImage:
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

            case .unsupported:
                state = .error("This content type is not supported")
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func loadSharedContent() async throws -> SharedContent {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            throw ShareError.noContent
        }

        // PRIORITY 1: Check for actual video files (from Photos/Camera Roll)
        // This must come first to avoid treating video file:// URLs as web URLs
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            let videoURL = try await loadVideo(from: itemProvider)
            return .video(videoURL)
        }

        // PRIORITY 2: Check for PDF files (from Files app, email, etc.)
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            let pdfURL = try await loadPDF(from: itemProvider)
            return .pdf(pdfURL)
        }

        // PRIORITY 3: Check for images (from Photos, screenshots, etc.)
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            let imageURL = try await loadImage(from: itemProvider)
            return .image(imageURL)
        }

        // PRIORITY 4: Check for web URLs (http/https)
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            let url = try await loadURL(from: itemProvider)

            // Only handle http/https URLs (web pages)
            // Ignore file:// URLs (local files)
            if url.scheme == "http" || url.scheme == "https" {
                return .url(url)
            }
        }

        // PRIORITY 5: Check for plain text (might contain URL)
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            let text = try await loadText(from: itemProvider)
            if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
               (url.scheme == "http" || url.scheme == "https") {
                return .url(url)
            }
        }

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

        // Check if this is a social media platform (TikTok, Instagram, YouTube, Facebook)
        let host = url.host?.lowercased() ?? ""

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

        // Not social media - assume it's a recipe URL
        // Use same polling mechanism as videos - more reliable than context.open()

        // 1. Create pending import record with URL
        let pendingImportID = UUID()
        let pendingImport = PendingVideoImport(
            id: pendingImportID,
            sourceType: .shareExtensionURL,
            localVideoURL: nil,
            originalURL: url,
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

        // Wait a moment for UI to update
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        print("⚠️ Share Extension (video): Attempting to open URL: \(deepLinkURL.absoluteString)")

        // Use responder chain workaround to access UIApplication
        let opened = await openURL(deepLinkURL)
        print("⚠️ Share Extension (video): URL open result: \(opened)")

        // Give the open attempt a moment to work
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

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
