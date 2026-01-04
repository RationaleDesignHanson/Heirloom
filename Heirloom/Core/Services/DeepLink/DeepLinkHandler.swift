import Foundation
import SwiftUI

/// Handles deep links and universal links for the app with robust lifecycle handling
/// Supports: recipe sharing (heirloom://share/...), Firebase shares, universal links
/// Handles all app states: cold launch, background, foreground
@MainActor
class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()

    // MARK: - Dependencies

    private let firebaseShare: FirebaseShareServiceProtocol
    private let logger: LoggingService

    // MARK: - Published State

    @Published var pendingShareURL: URL?
    @Published var pendingShareMetadata: [String: Any]?
    @Published var showShareAcceptanceSheet = false

    // URL import state (for share extension)
    @Published var pendingImportURL: URL?
    @Published var showURLImportSheet = false

    // MARK: - Private State (for robust handling)

    private var isAppReady = false
    private var queuedURLs: [URL] = []  // Support multiple URLs
    private var queuedActivity: NSUserActivity?

    // MARK: - Duplicate URL Prevention

    private var lastProcessedURL: URL?
    private var lastProcessedTime: Date?
    private let duplicateWindowSeconds: TimeInterval = 2.0

    // MARK: - Initialization

    private init() {
        // For singleton compatibility (to be removed later)
        self.firebaseShare = ServiceContainer.shared.resolve(FirebaseShareServiceProtocol.self)
        self.logger = ServiceContainer.shared.resolve(LoggingService.self)
        logger.log("DeepLinkHandler initialized", category: .general, level: .info, metadata: nil)
        DeviceLogger.shared.log("🔗 [DeepLink] DeepLinkHandler initialized")
    }

    init(firebaseShare: FirebaseShareServiceProtocol, logger: LoggingService) {
        self.firebaseShare = firebaseShare
        self.logger = logger
        logger.log("DeepLinkHandler initialized", category: .general, level: .info, metadata: nil)
        DeviceLogger.shared.log("🔗 [DeepLink] DeepLinkHandler initialized")
    }

    // MARK: - App Lifecycle

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
            // Handle URL import from share extension
            guard let urlString = components.queryItems?.first(where: { $0.name == "url" })?.value,
                  let importURL = URL(string: urlString) else {
                Log.error("Invalid import URL in heirloom:// URL", category: .general)
                DeviceLogger.shared.log("❌ [DeepLink] Invalid import URL in heirloom:// URL")
                return
            }

            Log.info("Extracted import URL from deep link", category: .general, metadata: ["importUrl": importURL.absoluteString])
            DeviceLogger.shared.log("✅ [DeepLink] Extracted import URL: \(importURL.absoluteString)")

            handleURLImport(importURL)

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

    // MARK: - Universal Links (heirloom.app)

    private func handleUniversalLink(_ url: URL) {
        Log.info("Handling universal link", category: .general, metadata: ["url": url.absoluteString])

        // Parse: https://heirloom.app/share/{shareID}
        let pathComponents = url.pathComponents

        guard pathComponents.count >= 3,
              pathComponents[1] == "share" else {
            Log.error("Invalid universal link path", category: .general)
            return
        }

        let shareID = pathComponents[2]
        Log.info("Extracted share ID from universal link", category: .general, metadata: ["shareId": shareID])

        handleFirebaseShare(shareID: shareID, originalURL: url)
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

    /// Check if there's a pending share to accept
    var hasPendingShare: Bool {
        pendingShareURL != nil
    }

    /// Check if there's a pending URL import
    var hasPendingImport: Bool {
        pendingImportURL != nil
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

