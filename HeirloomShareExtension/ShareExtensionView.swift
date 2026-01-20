import SwiftUI
import UniformTypeIdentifiers

/// SwiftUI view for Share Extension
struct ShareExtensionView: View {
    let extensionContext: NSExtensionContext?
    let onComplete: (Bool) -> Void

    @State private var state: ShareState = .loading
    @State private var errorMessage: String?
    @State private var detectedPlatform: SocialPlatform?

    enum ShareState {
        case loading
        case processingVideo
        case processingURL
        case success
        case error(String)
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

                // Action button (cancel/done)
                if case .error = state {
                    Button("Cancel") {
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
            if let platform = detectedPlatform {
                Image(systemName: platform.iconSystemName)
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
            } else {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
            }

        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)
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
                if let platform = detectedPlatform {
                    Text("Importing from \(platform.displayName)")
                        .font(.headline)
                } else {
                    Text("Processing URL...")
                        .font(.headline)
                }
                ProgressView()
            }

        case .success:
            Text("Opening Heirloom...")
                .font(.headline)

        case .error(let message):
            VStack(spacing: 8) {
                Text("Error")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
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

            case .url(let url, let platformInfo):
                detectedPlatform = platformInfo?.platform
                state = .processingURL
                try await handleURL(url, platformInfo: platformInfo)

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

        // Check for video
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            let videoURL = try await loadVideo(from: itemProvider)
            return .video(videoURL)
        }

        // Check for URL
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            let url = try await loadURL(from: itemProvider)
            let platformInfo = PlatformDetector.detect(from: url)
            return .url(url, platformInfo)
        }

        // Check for plain text (might contain URL)
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            let text = try await loadText(from: itemProvider)
            if let platformInfo = PlatformDetector.detect(from: text) {
                return .url(platformInfo.originalURL, platformInfo)
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

    private func handleURL(_ url: URL, platformInfo: DetectedPlatformInfo?) async throws {
        // 1. Create pending import record
        let pendingImportID = UUID()
        let pendingImport = PendingVideoImport(
            id: pendingImportID,
            sourceType: .shareExtensionURL,
            localVideoURL: nil,
            originalURL: url,
            detectedPlatform: platformInfo?.platform ?? .unknown
        )

        // 2. Save to pending imports directory
        try savePendingImport(pendingImport)

        // 3. Open main app
        try await openMainApp(withImportID: pendingImportID)
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

    private func openMainApp(withImportID id: UUID) async throws {
        // Create deep link: heirloom://import?id=<UUID>
        var components = URLComponents()
        components.scheme = "heirloom"
        components.host = "import"
        components.queryItems = [URLQueryItem(name: "id", value: id.uuidString)]

        guard let deepLinkURL = components.url else {
            throw ShareError.invalidDeepLink
        }

        state = .success

        // Wait a moment for UI to update
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Open main app (using extension context's async method)
        await extensionContext?.open(deepLinkURL)

        // Complete extension
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
}

// MARK: - Supporting Types

enum SharedContent {
    case video(URL)
    case url(URL, DetectedPlatformInfo?)
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
