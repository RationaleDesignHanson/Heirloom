import Foundation
import SwiftUI
import SwiftData

/// Handles deep links and universal links for recipe sharing
/// Supports: heirloom://share/{shareID} and https://heirloom.app/share/{shareID}
@MainActor
final class DeepLinkHandler: ObservableObject {
    // MARK: - Singleton

    nonisolated static let shared = DeepLinkHandler()

    private nonisolated init() {}

    // MARK: - State

    @Published var pendingShareURL: URL?
    @Published var pendingShareID: String?
    @Published var showReceiveSheet = false

    // MARK: - Deep Link Handling

    /// Handle incoming URL (deep link or universal link)
    /// - Parameter url: The incoming URL
    /// - Returns: True if handled, false otherwise
    func handleURL(_ url: URL) -> Bool {
        print("🔗 Deep link received: \(url.absoluteString)")

        // Check if it's a share URL (public database share)
        if let shareID = extractPublicShareID(from: url) {
            handlePublicShareURL(url, shareID: shareID)
            return true
        }

        // Check if it's a recipe detail URL
        if isRecipeDetailURL(url) {
            handleRecipeDetailURL(url)
            return true
        }

        print("⚠️ Unrecognized URL format")
        return false
    }

    /// Handle public database share URL
    /// - Parameters:
    ///   - url: The share URL
    ///   - shareID: Extracted share ID
    private func handlePublicShareURL(_ url: URL, shareID: String) {
        print("📥 Handling public share URL: \(shareID)")

        pendingShareURL = url
        pendingShareID = shareID
        showReceiveSheet = true
    }

    /// Handle recipe detail URL (for future use)
    /// - Parameter url: The recipe detail URL
    private func handleRecipeDetailURL(_ url: URL) {
        print("📖 Handling recipe detail URL...")

        // TODO: Navigate to recipe detail view
        // Extract recipe ID from URL and show detail view
    }

    // MARK: - URL Pattern Matching

    /// Extract share ID from public share URL
    /// - Parameter url: URL to check
    /// - Returns: Share ID if this is a valid share URL
    private func extractPublicShareID(from url: URL) -> String? {
        // Custom URL scheme: heirloom://share/{shareID}
        if url.scheme == "heirloom" && url.host() == "share" {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !path.isEmpty {
                return path
            }
        }

        // Universal link: https://heirloom.app/share/{shareID}
        if url.scheme == "https" && url.host() == "heirloom.app" {
            let components = url.pathComponents
            if let shareIndex = components.firstIndex(of: "share"),
               shareIndex + 1 < components.count {
                let shareID = components[shareIndex + 1]
                if !shareID.isEmpty && shareID != "/" {
                    return shareID
                }
            }
        }

        return nil
    }

    /// Check if URL is a recipe detail URL
    /// - Parameter url: URL to check
    /// - Returns: True if it's a recipe detail URL
    private func isRecipeDetailURL(_ url: URL) -> Bool {
        // heirloom://recipe/{recipeID}
        if url.scheme == "heirloom" && url.host() == "recipe" {
            return true
        }

        // https://heirloom.app/recipe/{recipeID}
        if url.scheme == "https" && url.host() == "heirloom.app" && url.pathComponents.contains("recipe") {
            return true
        }

        return false
    }

    // MARK: - Pending Share Management

    /// Clear pending share
    func clearPendingShare() {
        pendingShareURL = nil
        pendingShareID = nil
        showReceiveSheet = false
    }

    /// Check if there's a pending share to accept
    var hasPendingShare: Bool {
        pendingShareURL != nil && pendingShareID != nil
    }
}

// MARK: - Supporting Types

extension DeepLinkHandler {
    enum DeepLinkError: LocalizedError {
        case invalidURL
        case shareNotFound
        case expired

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "The link is not valid"
            case .shareNotFound:
                return "This shared recipe no longer exists"
            case .expired:
                return "This share link has expired"
            }
        }
    }

    enum DeepLinkType {
        case publicShare(shareID: String)
        case recipe(recipeID: String)
        case unknown
    }
}

// MARK: - URL Parsing Utilities

extension DeepLinkHandler {
    /// Determine the type of deep link
    /// - Parameter url: The URL to analyze
    /// - Returns: DeepLinkType
    func getLinkType(from url: URL) -> DeepLinkType {
        if let shareID = extractPublicShareID(from: url) {
            return .publicShare(shareID: shareID)
        }
        
        if let recipeID = extractRecipeID(from: url) {
            return .recipe(recipeID: recipeID)
        }
        
        return .unknown
    }
    
    /// Extract recipe ID from URL
    /// - Parameter url: The recipe URL
    /// - Returns: Recipe ID string
    func extractRecipeID(from url: URL) -> String? {
        // For heirloom://recipe/{recipeID}
        if url.scheme == "heirloom" && url.host() == "recipe" {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return path.isEmpty ? nil : path
        }

        // For https://heirloom.app/recipe/{recipeID}
        if url.host() == "heirloom.app" {
            let components = url.pathComponents
            if let recipeIndex = components.firstIndex(of: "recipe"),
               recipeIndex + 1 < components.count {
                let recipeID = components[recipeIndex + 1]
                return recipeID.isEmpty ? nil : recipeID
            }
        }

        return nil
    }
}

// MARK: - Environment Key

struct DeepLinkHandlerKey: EnvironmentKey {
    static let defaultValue = DeepLinkHandler.shared
}

extension EnvironmentValues {
    var deepLinkHandler: DeepLinkHandler {
        get { self[DeepLinkHandlerKey.self] }
        set { self[DeepLinkHandlerKey.self] = newValue }
    }
}
