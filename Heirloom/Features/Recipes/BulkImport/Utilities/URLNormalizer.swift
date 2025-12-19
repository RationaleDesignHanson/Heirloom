import Foundation

/// Utility for normalizing URLs to detect duplicates
/// Removes query parameters, fragments, and trailing slashes
struct URLNormalizer {

    /// Normalize a URL string for duplicate comparison
    /// - Parameter urlString: The URL string to normalize
    /// - Returns: Normalized URL string, or nil if invalid
    static func normalize(_ urlString: String) -> String? {
        // Clean up URL (trim whitespace, remove invisible characters)
        let cleanedURL = urlString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{200B}", with: "") // Zero-width space
            .replacingOccurrences(of: "\u{FEFF}", with: "") // Byte order mark

        // Parse URL components first
        guard var components = URLComponents(string: cleanedURL) else {
            return nil
        }

        // Must have a scheme (reject relative URLs like "not a url")
        guard let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }

        // Must have a host (reject URLs like "https://")
        guard let host = components.host, !host.isEmpty else {
            return nil
        }

        // Normalize scheme to https
        components.scheme = "https"

        // Remove query parameters and fragment
        components.query = nil
        components.fragment = nil

        // Get normalized URL string
        guard let normalizedURL = components.url?.absoluteString else {
            return nil
        }

        // Remove trailing slash
        let trimmed = normalizedURL.hasSuffix("/")
            ? String(normalizedURL.dropLast())
            : normalizedURL

        // Convert to lowercase for case-insensitive comparison
        return trimmed.lowercased()
    }

    /// Check if two URL strings are duplicates
    /// - Parameters:
    ///   - url1: First URL string
    ///   - url2: Second URL string
    /// - Returns: true if URLs are considered duplicates
    static func areDuplicates(_ url1: String, _ url2: String) -> Bool {
        guard let normalized1 = normalize(url1),
              let normalized2 = normalize(url2) else {
            return false
        }
        return normalized1 == normalized2
    }

    /// Extract domain from URL string
    /// - Parameter urlString: The URL string
    /// - Returns: Domain (e.g., "nytimes.com"), or nil if invalid
    static func extractDomain(_ urlString: String) -> String? {
        guard let normalized = normalize(urlString),
              let url = URL(string: normalized),
              let host = url.host() else {
            return nil
        }

        // Remove "www." prefix if present
        let domain = host.lowercased()
        if domain.hasPrefix("www.") {
            return String(domain.dropFirst(4))
        }

        return domain
    }

    /// Validate that a URL string is well-formed and can be imported
    /// - Parameter urlString: The URL string to validate
    /// - Returns: true if URL is valid for import
    static func isValidForImport(_ urlString: String) -> Bool {
        guard let normalized = normalize(urlString),
              let url = URL(string: normalized) else {
            return false
        }

        // Must have a scheme
        guard let scheme = url.scheme, ["http", "https"].contains(scheme) else {
            return false
        }

        // Must have a host
        guard let host = url.host(), !host.isEmpty else {
            return false
        }

        // Must have a path (not just domain)
        let path = url.path()
        guard !path.isEmpty && path != "/" else {
            return false
        }

        return true
    }
}

// MARK: - URL Extraction

extension URLNormalizer {
    /// Extract all valid recipe URLs from plain text
    /// Useful for pasting lists of URLs
    /// - Parameter text: Plain text containing URLs
    /// - Returns: Array of extracted and normalized URLs (duplicates removed)
    static func extractURLs(from text: String) -> [String] {
        var seen: Set<String> = []
        var results: [String] = []

        // Try NSDataDetector first for properly formatted URLs
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: text.utf16.count)
        )

        matches?.forEach { match in
            if let url = match.url?.absoluteString,
               isValidForImport(url),
               let normalized = normalize(url) {
                if !seen.contains(normalized) {
                    seen.insert(normalized)
                    results.append(normalized)
                }
            }
        }

        // Also try line-by-line parsing for URLs without proper protocols
        // Support multiple delimiters: newlines, commas, semicolons, spaces
        let separators = CharacterSet(charactersIn: ",;\n\r ")
        text.components(separatedBy: separators).forEach { component in
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmed.isEmpty else { return }

            // Try with https:// prefix if no scheme
            let candidate = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"

            if isValidForImport(candidate),
               let normalized = normalize(candidate) {
                if !seen.contains(normalized) {
                    seen.insert(normalized)
                    results.append(normalized)
                }
            }
        }

        return results
    }

    /// Clean up pasted text by extracting URLs and formatting them cleanly (one per line)
    /// - Parameter text: Messy text containing URLs
    /// - Returns: Cleaned text with one URL per line
    static func cleanupText(_ text: String) -> String {
        let urls = extractURLs(from: text)
        return urls.joined(separator: "\n")
    }
}
