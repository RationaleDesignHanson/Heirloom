import Foundation
import SwiftUI

/// Handles deep links and universal links for the app with robust lifecycle handling
/// Supports: recipe sharing (heirloom://share/...), Firebase shares, universal links
/// Handles all app states: cold launch, background, foreground
@MainActor
class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()

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
        print("🔗 DeepLinkHandler initialized")
        DeviceLogger.shared.log("🔗 [DeepLink] DeepLinkHandler initialized")
    }

    // MARK: - App Lifecycle

    /// Call when app is ready to handle URLs (views are loaded)
    func markAppReady() {
        print("✅ App marked as ready for deep links")
        DeviceLogger.shared.log("✅ [DeepLink] App marked as ready for deep links")
        isAppReady = true

        // Process all queued URLs
        if !queuedURLs.isEmpty {
            print("📱 Processing \(queuedURLs.count) queued URL(s)")
            DeviceLogger.shared.log("📱 [DeepLink] Processing \(queuedURLs.count) queued URL(s)")
            for url in queuedURLs {
                print("  - \(url.absoluteString)")
                DeviceLogger.shared.log("  [DeepLink] - \(url.absoluteString)")
                processURL(url)
            }
            queuedURLs.removeAll()
        }

        // Process any queued activity
        if let activity = queuedActivity {
            print("📱 Processing queued user activity")
            DeviceLogger.shared.log("📱 [DeepLink] Processing queued user activity")
            processUserActivity(activity)
            queuedActivity = nil
        }
    }

    // MARK: - URL Handling

    /// Handle incoming URL (called from App scene)
    func handle(_ url: URL) {
        print("📥 DeepLinkHandler received URL: \(url.absoluteString)")
        DeviceLogger.shared.log("📥 [DeepLink] DeepLinkHandler received URL: \(url.absoluteString)")

        // DUPLICATE PREVENTION: Check if this is a duplicate within the time window
        if let lastURL = lastProcessedURL,
           let lastTime = lastProcessedTime,
           lastURL.absoluteString == url.absoluteString,
           Date().timeIntervalSince(lastTime) < duplicateWindowSeconds {
            print("⚠️ Ignoring duplicate URL (processed \(Date().timeIntervalSince(lastTime))s ago)")
            DeviceLogger.shared.log("⚠️ [DeepLink] Ignoring duplicate URL")
            return
        }

        if isAppReady {
            print("✅ App is ready, processing immediately")
            DeviceLogger.shared.log("✅ [DeepLink] App is ready, processing immediately")
            processURL(url)
        } else {
            print("⏳ App not ready, queuing URL for later")
            DeviceLogger.shared.log("⏳ [DeepLink] App not ready, queuing URL for later")
            // Only add if not already in queue
            if !queuedURLs.contains(where: { $0.absoluteString == url.absoluteString }) {
                queuedURLs.append(url)
                print("  📝 Queue now has \(queuedURLs.count) URL(s)")
                DeviceLogger.shared.log("  [DeepLink] Queue now has \(queuedURLs.count) URL(s)")
            } else {
                print("  ⚠️ URL already in queue, skipping")
                DeviceLogger.shared.log("  [DeepLink] URL already in queue, skipping")
            }
        }
    }

    /// Handle user activity (for universal links)
    func handle(_ userActivity: NSUserActivity) {
        print("📥 DeepLinkHandler received user activity: \(userActivity.activityType)")

        if isAppReady {
            print("✅ App is ready, processing immediately")
            processUserActivity(userActivity)
        } else {
            print("⏳ App not ready, queuing user activity for later")
            queuedActivity = userActivity
        }
    }

    // MARK: - Private Processing

    private func processURL(_ url: URL) {
        print("🔄 Processing URL: \(url.absoluteString)")
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
            print("⚠️ Unknown URL scheme: \(url.scheme ?? "nil") - \(url.host ?? "nil")")
            DeviceLogger.shared.log("⚠️ [DeepLink] Unknown URL scheme: \(url.scheme ?? "nil") - \(url.host ?? "nil")")
        }
    }

    private func processUserActivity(_ userActivity: NSUserActivity) {
        print("🔄 Processing user activity: \(userActivity.activityType)")
        DeviceLogger.shared.log("🔄 [DeepLink] Processing user activity: \(userActivity.activityType)")

        // Universal link handling
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            print("✅ Extracted URL from user activity: \(url.absoluteString)")
            DeviceLogger.shared.log("✅ [DeepLink] Extracted URL from user activity: \(url.absoluteString)")
            processURL(url)
        } else {
            print("⚠️ User activity has no webpage URL")
            DeviceLogger.shared.log("⚠️ [DeepLink] User activity has no webpage URL")
        }
    }

    // MARK: - Heirloom URL Scheme (heirloom://)

    private func handleHeirloomURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            print("❌ Invalid heirloom:// URL")
            DeviceLogger.shared.log("❌ [DeepLink] Invalid heirloom:// URL")
            return
        }

        // Parse: heirloom://share/{shareID} OR heirloom://import?url=...
        if components.host == "share" {
            // Handle Firebase recipe share
            // Extract shareID from path (remove leading /)
            let shareID = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            guard !shareID.isEmpty else {
                print("❌ Empty share ID in heirloom:// URL")
                DeviceLogger.shared.log("❌ [DeepLink] Empty share ID in heirloom:// URL")
                return
            }

            print("✅ Extracted share ID: \(shareID)")
            DeviceLogger.shared.log("✅ [DeepLink] Extracted share ID: \(shareID)")

            handleFirebaseShare(shareID: shareID, originalURL: url)

        } else if components.host == "import" {
            // Handle URL import from share extension
            guard let urlString = components.queryItems?.first(where: { $0.name == "url" })?.value,
                  let importURL = URL(string: urlString) else {
                print("❌ Invalid import URL in heirloom:// URL")
                DeviceLogger.shared.log("❌ [DeepLink] Invalid import URL in heirloom:// URL")
                return
            }

            print("✅ Extracted import URL: \(importURL.absoluteString)")
            DeviceLogger.shared.log("✅ [DeepLink] Extracted import URL: \(importURL.absoluteString)")

            handleURLImport(importURL)

        } else {
            print("❌ Invalid heirloom:// host: \(components.host ?? "nil")")
            DeviceLogger.shared.log("❌ [DeepLink] Invalid heirloom:// host: \(components.host ?? "nil")")
        }
    }

    // MARK: - Firebase Share Handling

    private func handleFirebaseShare(shareID: String, originalURL: URL) {
        print("🔥 Handling Firebase share ID: \(shareID)")
        DeviceLogger.shared.log("🔥 [DeepLink] Handling Firebase share ID: \(shareID)")

        // Store URL for acceptance flow
        pendingShareURL = originalURL

        // Fetch share metadata from Firebase
        Task {
            do {
                print("🔍 Fetching share metadata from Firebase...")
                DeviceLogger.shared.log("🔍 [DeepLink] Fetching share metadata from Firebase...")
                let metadata = try await FirebaseShareService.shared.fetchShareMetadata(shareId: shareID)

                await MainActor.run {
                    print("✅ Share metadata fetched successfully")
                    DeviceLogger.shared.log("✅ [DeepLink] Share metadata fetched successfully")
                    pendingShareMetadata = metadata
                    showShareAcceptanceSheet = true
                    DeviceLogger.shared.log("📋 [DeepLink] Setting showShareAcceptanceSheet = true")
                }

            } catch {
                print("❌ Failed to fetch share metadata: \(error.localizedDescription)")
                DeviceLogger.shared.log("❌ [DeepLink] Failed to fetch share metadata: \(error.localizedDescription)", level: .error)

                // Still show acceptance sheet even if metadata fetch fails
                // User can try to accept anyway
                await MainActor.run {
                    print("⚠️ Showing acceptance sheet without metadata")
                    DeviceLogger.shared.log("⚠️ [DeepLink] Showing acceptance sheet without metadata")
                    showShareAcceptanceSheet = true
                    DeviceLogger.shared.log("📋 [DeepLink] Setting showShareAcceptanceSheet = true (no metadata)")
                }
            }
        }
    }

    // MARK: - URL Import Handling (from share extension)

    private func handleURLImport(_ url: URL) {
        print("🔗 Handling URL import from share extension: \(url.absoluteString)")
        DeviceLogger.shared.log("🔗 [DeepLink] Handling URL import from share extension: \(url.absoluteString)")

        // Store URL for import flow
        pendingImportURL = url
        showURLImportSheet = true

        print("✅ URL import sheet triggered")
        DeviceLogger.shared.log("✅ [DeepLink] URL import sheet triggered")
    }

    // MARK: - Universal Links (heirloom.app)

    private func handleUniversalLink(_ url: URL) {
        print("🌐 Handling universal link: \(url.absoluteString)")

        // Parse: https://heirloom.app/share/{shareID}
        let pathComponents = url.pathComponents

        guard pathComponents.count >= 3,
              pathComponents[1] == "share" else {
            print("❌ Invalid universal link path")
            return
        }

        let shareID = pathComponents[2]
        print("✅ Extracted share ID from universal link: \(shareID)")

        handleFirebaseShare(shareID: shareID, originalURL: url)
    }

    // MARK: - Public API

    /// Clear pending share (called after acceptance/decline)
    func clearPendingShare() {
        print("🧹 Clearing pending share")
        pendingShareURL = nil
        pendingShareMetadata = nil
        showShareAcceptanceSheet = false
    }

    /// Clear pending URL import (called after processing)
    func clearPendingImport() {
        print("🧹 Clearing pending URL import")
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
        print("🔄 Resetting deep link handler")
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

