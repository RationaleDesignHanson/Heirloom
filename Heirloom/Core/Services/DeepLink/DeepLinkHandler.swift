import Foundation
import SwiftUI
import CloudKit

/// Handles deep links and universal links for the app with robust lifecycle handling
/// Supports: recipe sharing (heirloom://share/...), CloudKit shares, universal links
/// Handles all app states: cold launch, background, foreground
@MainActor
class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()

    // MARK: - Published State

    @Published var pendingShareURL: URL?
    @Published var pendingShareMetadata: CKShare.Metadata?
    @Published var showShareAcceptanceSheet = false

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
    }

    // MARK: - App Lifecycle

    /// Call when app is ready to handle URLs (views are loaded)
    func markAppReady() {
        print("✅ App marked as ready for deep links")
        isAppReady = true

        // Process all queued URLs
        if !queuedURLs.isEmpty {
            print("📱 Processing \(queuedURLs.count) queued URL(s)")
            for url in queuedURLs {
                print("  - \(url.absoluteString)")
                processURL(url)
            }
            queuedURLs.removeAll()
        }

        // Process any queued activity
        if let activity = queuedActivity {
            print("📱 Processing queued user activity")
            processUserActivity(activity)
            queuedActivity = nil
        }
    }

    // MARK: - URL Handling

    /// Handle incoming URL (called from App scene)
    func handle(_ url: URL) {
        print("📥 DeepLinkHandler received URL: \(url.absoluteString)")

        // DUPLICATE PREVENTION: Check if this is a duplicate within the time window
        if let lastURL = lastProcessedURL,
           let lastTime = lastProcessedTime,
           lastURL.absoluteString == url.absoluteString,
           Date().timeIntervalSince(lastTime) < duplicateWindowSeconds {
            print("⚠️ Ignoring duplicate URL (processed \(Date().timeIntervalSince(lastTime))s ago)")
            return
        }

        if isAppReady {
            print("✅ App is ready, processing immediately")
            processURL(url)
        } else {
            print("⏳ App not ready, queuing URL for later")
            // Only add if not already in queue
            if !queuedURLs.contains(where: { $0.absoluteString == url.absoluteString }) {
                queuedURLs.append(url)
                print("  📝 Queue now has \(queuedURLs.count) URL(s)")
            } else {
                print("  ⚠️ URL already in queue, skipping")
            }
        }
    }

    /// Handle CloudKit user activity (for CKShare acceptance)
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

        // Record as processed (for duplicate prevention)
        lastProcessedURL = url
        lastProcessedTime = Date()

        // Determine URL type
        if url.scheme == "heirloom" {
            handleHeirloomURL(url)
        } else if url.scheme == "https" && url.host?.contains("icloud.com") == true {
            handleCloudKitShareURL(url)
        } else if url.scheme == "https" && url.host == "heirloom.app" {
            handleUniversalLink(url)
        } else {
            print("⚠️ Unknown URL scheme: \(url.scheme ?? "nil") - \(url.host ?? "nil")")
        }
    }

    private func processUserActivity(_ userActivity: NSUserActivity) {
        print("🔄 Processing user activity: \(userActivity.activityType)")

        // CloudKit share acceptance
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            print("✅ Extracted URL from user activity: \(url.absoluteString)")
            handleCloudKitShareURL(url)
        } else {
            print("⚠️ User activity has no webpage URL")
        }
    }

    // MARK: - Heirloom URL Scheme (heirloom://)

    private func handleHeirloomURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            print("❌ Invalid heirloom:// URL")
            return
        }

        // Parse: heirloom://share/{shareID}
        // The host is "share" and path is "/{shareID}"
        guard components.host == "share" else {
            print("❌ Invalid heirloom:// host: \(components.host ?? "nil")")
            return
        }

        // Extract shareID from path (remove leading /)
        let shareID = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !shareID.isEmpty else {
            print("❌ Empty share ID in heirloom:// URL")
            return
        }

        print("✅ Extracted share ID: \(shareID)")

        // Convert to CloudKit share URL
        guard let ckShareURL = convertToCloudKitURL(shareID: shareID) else {
            print("❌ Could not convert to CloudKit URL")
            return
        }

        handleCloudKitShareURL(ckShareURL)
    }

    // MARK: - CloudKit Share URL

    private func handleCloudKitShareURL(_ url: URL) {
        print("☁️ Handling CloudKit share URL: \(url.absoluteString)")

        // Store URL for acceptance flow
        pendingShareURL = url

        // Fetch share metadata
        Task {
            do {
                print("🔍 Fetching share metadata...")
                let metadata = try await fetchShareMetadata(url)

                await MainActor.run {
                    print("✅ Share metadata fetched successfully")
                    pendingShareMetadata = metadata
                    showShareAcceptanceSheet = true
                }

            } catch {
                print("❌ Failed to fetch share metadata: \(error.localizedDescription)")

                // Still show acceptance sheet even if metadata fetch fails
                // User can try to accept anyway
                await MainActor.run {
                    print("⚠️ Showing acceptance sheet without metadata")
                    showShareAcceptanceSheet = true
                }
            }
        }
    }

    // MARK: - Universal Links (heirloom.app)

    private func handleUniversalLink(_ url: URL) {
        print("🌐 Handling universal link: \(url.absoluteString)")

        // Parse: https://heirloom.app/r/{shareID}
        let pathComponents = url.pathComponents

        guard pathComponents.count >= 3,
              pathComponents[1] == "r" else {
            print("❌ Invalid universal link path")
            return
        }

        let shareID = pathComponents[2]
        print("✅ Extracted share ID from universal link: \(shareID)")

        // Convert to CloudKit share URL
        guard let ckShareURL = convertToCloudKitURL(shareID: shareID) else {
            print("❌ Could not convert universal link to CloudKit URL")
            return
        }

        handleCloudKitShareURL(ckShareURL)
    }

    // MARK: - Share Metadata

    /// Fetch metadata for a CloudKit share URL
    private func fetchShareMetadata(_ url: URL) async throws -> CKShare.Metadata {
        let container = CKContainer.default()

        return try await withCheckedThrowingContinuation { continuation in
            container.fetchShareMetadata(with: url) { metadata, error in
                if let error = error {
                    print("❌ Metadata fetch error: \(error)")
                    continuation.resume(throwing: error)
                } else if let metadata = metadata {
                    print("✅ Metadata fetched: \(metadata.share.recordID.recordName)")
                    continuation.resume(returning: metadata)
                } else {
                    print("❌ No metadata returned")
                    continuation.resume(throwing: DeepLinkError.noMetadata)
                }
            }
        }
    }

    // MARK: - Helpers

    /// Convert share ID to CloudKit URL
    /// In production, this would fetch the actual CKShare URL from your backend
    private func convertToCloudKitURL(shareID: String) -> URL? {
        // For now, we assume the shareID is actually the full CloudKit share URL
        // encoded in the heirloom:// or universal link

        // Decode if base64-encoded
        if let data = Data(base64Encoded: shareID),
           let urlString = String(data: data, encoding: .utf8) {
            // Trim whitespace/newlines from decoded string
            let trimmedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmedURLString) {
                print("✅ Decoded share URL: \(url.absoluteString)")
                return url
            } else {
                print("❌ Failed to parse decoded URL: '\(trimmedURLString)'")
            }
        }

        // Try direct parsing (for non-base64 encoded)
        if let url = URL(string: shareID), url.scheme == "https" {
            return url
        }

        print("❌ Could not decode shareID: \(shareID)")
        return nil
    }

    // MARK: - Public API

    /// Clear pending share (called after acceptance/decline)
    func clearPendingShare() {
        print("🧹 Clearing pending share")
        pendingShareURL = nil
        pendingShareMetadata = nil
        showShareAcceptanceSheet = false
    }

    /// Check if there's a pending share to accept
    var hasPendingShare: Bool {
        pendingShareURL != nil
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
