//
//  ShareViewController.swift
//  HeirloomShareExtension
//
//  Created by Matt Hanson on 12/31/25.
//

import UIKit
import UniformTypeIdentifiers

/// Share Extension view controller for importing recipes from shared URLs
/// Activates when user shares a URL from Safari or other apps
class ShareViewController: UIViewController {

    // MARK: - Properties

    private var sharedURL: URL?
    private let loadingLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        extractSharedURL()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Loading indicator
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)

        // Loading label
        loadingLabel.text = "Preparing recipe..."
        loadingLabel.font = .systemFont(ofSize: 18, weight: .medium)
        loadingLabel.textAlignment = .center
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingLabel)

        // Status label
        statusLabel.text = ""
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textAlignment = .center
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),

            loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
            loadingLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            loadingLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            statusLabel.topAnchor.constraint(equalTo: loadingLabel.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    // MARK: - URL Extraction

    private func extractSharedURL() {
        activityIndicator.startAnimating()

        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            showError("No content shared")
            return
        }

        // Check for URL
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.showError("Failed to load URL: \(error.localizedDescription)")
                        return
                    }

                    if let url = item as? URL {
                        self?.handleURL(url)
                    } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        self?.handleURL(url)
                    } else {
                        self?.showError("Invalid URL format")
                    }
                }
            }
        } else {
            showError("Please share a web URL")
        }
    }

    // MARK: - URL Handling

    private func handleURL(_ url: URL) {
        sharedURL = url

        // Check if it looks like a recipe URL
        let isLikelyRecipe = RecipeURLDetector.isLikelyRecipeURL(url)

        if isLikelyRecipe {
            statusLabel.text = "Detected recipe from \(url.host ?? "website")"
            openInMainApp(url)
        } else {
            // Show confirmation for non-recipe URLs
            showConfirmation(for: url)
        }
    }

    private func showConfirmation(for url: URL) {
        activityIndicator.stopAnimating()
        loadingLabel.text = "Import from URL?"
        statusLabel.text = url.absoluteString

        let alert = UIAlertController(
            title: "Import Recipe",
            message: "This URL doesn't look like a typical recipe site. Would you still like to try importing it?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Import", style: .default) { [weak self] _ in
            self?.openInMainApp(url)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.cancelSharing()
        })

        present(alert, animated: true)
    }

    private func openInMainApp(_ url: URL) {
        // Create deep link URL to open main app with import action
        let deepLinkURL = createDeepLink(for: url)

        // Save URL to shared container for main app to pick up
        saveURLToSharedContainer(url)

        statusLabel.text = "Opening Heirloom..."

        // Open main app via deep link
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(deepLinkURL, options: [:]) { [weak self] success in
                    if success {
                        self?.completeSharing()
                    } else {
                        self?.showError("Failed to open Heirloom app")
                    }
                }
                return
            }
            responder = responder?.next
        }

        // Fallback: complete with success
        completeSharing()
    }

    private func createDeepLink(for url: URL) -> URL {
        // Create deep link: heirloom://import?url=<encoded_url>
        var components = URLComponents()
        components.scheme = "heirloom"
        components.host = "import"
        components.queryItems = [
            URLQueryItem(name: "url", value: url.absoluteString)
        ]
        return components.url ?? URL(string: "heirloom://import")!
    }

    private func saveURLToSharedContainer(_ url: URL) {
        // Save URL to UserDefaults in shared app group
        let groupDefaults = UserDefaults(suiteName: "group.com.matthanson.heirloom.shared")
        groupDefaults?.set(url.absoluteString, forKey: "pendingImportURL")
        groupDefaults?.set(Date(), forKey: "pendingImportTimestamp")
        groupDefaults?.synchronize()
    }

    // MARK: - Completion

    private func completeSharing() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func cancelSharing() {
        let error = NSError(domain: "HeirloomShareExtension", code: 0, userInfo: [NSLocalizedDescriptionKey: "User cancelled"])
        extensionContext?.cancelRequest(withError: error)
    }

    private func showError(_ message: String) {
        activityIndicator.stopAnimating()
        loadingLabel.text = "Error"
        statusLabel.text = message

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.cancelSharing()
        }
    }
}

// MARK: - Recipe URL Detection

/// Helper to detect if a URL is likely a recipe
struct RecipeURLDetector {

    /// Common recipe website domains
    static let recipeHosts = [
        "allrecipes.com",
        "foodnetwork.com",
        "bonappetit.com",
        "seriouseats.com",
        "epicurious.com",
        "cooking.nytimes.com",
        "food.com",
        "yummly.com",
        "food52.com",
        "delish.com",
        "thekitchn.com",
        "cookieandkate.com",
        "minimalistbaker.com",
        "budgetbytes.com",
        "tasty.co",
        "bbc.co.uk/food",
        "bbcgoodfood.com",
        "simplyrecipes.com",
        "tasteofhome.com",
        "myrecipes.com"
    ]

    /// Keywords that suggest a recipe URL
    static let recipeKeywords = [
        "recipe",
        "recipes",
        "cooking",
        "baking",
        "dish",
        "food"
    ]

    /// Check if URL is likely a recipe
    static func isLikelyRecipeURL(_ url: URL) -> Bool {
        let urlString = url.absoluteString.lowercased()
        let host = url.host?.lowercased() ?? ""

        // Check if host is a known recipe site
        for recipeHost in recipeHosts {
            if host.contains(recipeHost) {
                return true
            }
        }

        // Check if URL contains recipe keywords
        for keyword in recipeKeywords {
            if urlString.contains(keyword) {
                return true
            }
        }

        return false
    }
}
