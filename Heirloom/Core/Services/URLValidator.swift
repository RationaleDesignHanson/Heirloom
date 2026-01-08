//
//  URLValidator.swift
//  Heirloom
//
//  Created by Claude Code on 1/7/26.
//  Security Phase 1: URL validation to prevent injection and SSRF attacks
//

import Foundation

/// URL validator to prevent URL injection and SSRF (Server-Side Request Forgery) attacks
/// Validates URL schemes, blocks internal network addresses, and ensures safe URLs
class URLValidator {
    static let shared = URLValidator()

    // MARK: - Configuration

    /// URL schemes that are considered safe for recipe source URLs
    private let allowedSchemes = ["http", "https"]

    /// Dangerous URL schemes that enable code execution or data exfiltration
    private let blockedSchemes = [
        "javascript",
        "data",
        "vbscript",
        "file",
        "about",
        "blob",
        "chrome",
        "chrome-extension",
        "ftp",
        "sftp"
    ]

    /// Private IP address patterns for SSRF prevention
    private let privateIPPatterns = [
        "^127\\.",              // Loopback (127.0.0.0/8)
        "^10\\.",               // Private network (10.0.0.0/8)
        "^172\\.(1[6-9]|2[0-9]|3[0-1])\\.",  // Private network (172.16.0.0/12)
        "^192\\.168\\.",        // Private network (192.168.0.0/16)
        "^169\\.254\\.",        // Link-local (169.254.0.0/16)
        "^::1$",                // IPv6 loopback
        "^fe80:",               // IPv6 link-local
        "^fc00:",               // IPv6 unique local
        "^fd00:",               // IPv6 unique local
        "localhost"             // Localhost hostname
    ]

    // MARK: - Validation Methods

    /// Validates a URL string for safety
    /// - Parameter urlString: URL string to validate
    /// - Returns: Validated URL if safe
    /// - Throws: URLValidationError if URL is unsafe
    func validate(_ urlString: String?) throws -> URL? {
        // Empty URLs are allowed (optional field)
        guard let urlString = urlString, !urlString.isEmpty else {
            return nil
        }

        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return nil
        }

        // Step 1: Check for valid URL format
        guard let url = URL(string: trimmed) else {
            throw URLValidationError.invalidFormat(urlString: trimmed)
        }

        // Step 2: Validate URL scheme
        try validateScheme(url)

        // Step 3: Check for SSRF vulnerabilities (internal network)
        try validateHost(url)

        // Step 4: Check for suspicious patterns
        try validateForInjectionPatterns(url)

        return url
    }

    /// Validates URL for use as a recipe source (stricter validation)
    func validateRecipeSourceURL(_ urlString: String?) throws -> URL? {
        guard let url = try validate(urlString) else {
            return nil
        }

        // Must have http or https scheme
        guard url.scheme == "http" || url.scheme == "https" else {
            throw URLValidationError.unsupportedScheme(
                scheme: url.scheme ?? "none",
                allowed: allowedSchemes
            )
        }

        // Must have a host
        guard url.host != nil else {
            throw URLValidationError.missingHost
        }

        return url
    }

    /// Quick check if URL is safe without throwing
    /// Returns true if URL passes validation
    func isSafe(_ urlString: String?) -> Bool {
        do {
            _ = try validate(urlString)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Private Validation Methods

    /// Validates URL scheme (allows only http/https)
    private func validateScheme(_ url: URL) throws {
        guard let scheme = url.scheme?.lowercased() else {
            throw URLValidationError.missingScheme
        }

        // Check if scheme is blocked
        if blockedSchemes.contains(scheme) {
            throw URLValidationError.blockedScheme(
                scheme: scheme,
                reason: "This URL scheme is not allowed for security reasons"
            )
        }

        // For recipe URLs, only allow http/https
        if !allowedSchemes.contains(scheme) {
            throw URLValidationError.unsupportedScheme(
                scheme: scheme,
                allowed: allowedSchemes
            )
        }
    }

    /// Validates host to prevent SSRF attacks on internal networks
    private func validateHost(_ url: URL) throws {
        guard let host = url.host?.lowercased() else {
            throw URLValidationError.missingHost
        }

        // Check for private/internal IP addresses
        for pattern in privateIPPatterns {
            if host.range(of: pattern, options: [.regularExpression]) != nil {
                throw URLValidationError.privateNetwork(
                    host: host,
                    reason: "Internal network addresses are not allowed"
                )
            }
        }

        // Check for localhost variants
        let localhostVariants = ["localhost", "local", "127.0.0.1", "::1", "0.0.0.0"]
        if localhostVariants.contains(host) {
            throw URLValidationError.privateNetwork(
                host: host,
                reason: "Localhost addresses are not allowed"
            )
        }
    }

    /// Validates URL for injection patterns and suspicious content
    private func validateForInjectionPatterns(_ url: URL) throws {
        let urlString = url.absoluteString.lowercased()

        // Check for double encoding attempts
        if urlString.contains("%25") {
            throw URLValidationError.suspiciousPattern(
                pattern: "double URL encoding",
                reason: "URL appears to contain encoded attack patterns"
            )
        }

        // Check for embedded credentials
        if url.user != nil || url.password != nil {
            throw URLValidationError.suspiciousPattern(
                pattern: "embedded credentials",
                reason: "URLs with embedded credentials are not allowed"
            )
        }

        // Check for @-symbol redirects (http://evil.com@legitimate.com)
        if let host = url.host, host.contains("@") {
            throw URLValidationError.suspiciousPattern(
                pattern: "@-symbol in host",
                reason: "URLs with @ symbols in the host are not allowed"
            )
        }

        // Check for unusual ports (common for attacks)
        if let port = url.port {
            // Block common internal service ports
            let blockedPorts = [22, 23, 25, 110, 143, 445, 3306, 5432, 6379, 27017]
            if blockedPorts.contains(port) {
                throw URLValidationError.suspiciousPattern(
                    pattern: "blocked port \(port)",
                    reason: "This port is not allowed for security reasons"
                )
            }
        }
    }

    // MARK: - Helper Methods

    /// Sanitizes a URL by removing suspicious parts
    /// Returns nil if URL cannot be made safe
    func sanitize(_ urlString: String?) -> String? {
        guard let urlString = urlString else { return nil }

        var sanitized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove javascript: and data: schemes
        let dangerousSchemes = ["javascript:", "data:", "vbscript:", "file:"]
        for scheme in dangerousSchemes {
            if sanitized.lowercased().hasPrefix(scheme) {
                return nil // Cannot sanitize, reject entirely
            }
        }

        // Remove embedded credentials
        if let url = URL(string: sanitized),
           let host = url.host,
           sanitized.contains("@") {
            // Reconstruct URL without credentials
            var components = URLComponents()
            components.scheme = url.scheme
            components.host = host
            components.path = url.path
            components.query = url.query
            components.fragment = url.fragment
            sanitized = components.string ?? sanitized
        }

        return sanitized
    }

    /// Extracts domain from URL for display purposes
    func extractDomain(_ url: URL?) -> String? {
        guard let url = url else { return nil }
        return url.host
    }
}

// MARK: - Validation Errors

enum URLValidationError: LocalizedError {
    case invalidFormat(urlString: String)
    case missingScheme
    case blockedScheme(scheme: String, reason: String)
    case unsupportedScheme(scheme: String, allowed: [String])
    case missingHost
    case privateNetwork(host: String, reason: String)
    case suspiciousPattern(pattern: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat(let urlString):
            return "Invalid URL format: \(urlString)"

        case .missingScheme:
            return "URL must include a scheme (http:// or https://)"

        case .blockedScheme(let scheme, let reason):
            return "URL scheme '\(scheme)' is blocked: \(reason)"

        case .unsupportedScheme(let scheme, let allowed):
            let allowedList = allowed.joined(separator: ", ")
            return "URL scheme '\(scheme)' is not supported. Allowed schemes: \(allowedList)"

        case .missingHost:
            return "URL must include a host/domain name"

        case .privateNetwork(let host, let reason):
            return "Cannot use internal network address '\(host)': \(reason)"

        case .suspiciousPattern(let pattern, let reason):
            return "Suspicious URL pattern detected (\(pattern)): \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidFormat:
            return "Please enter a valid URL starting with http:// or https://"

        case .missingScheme:
            return "Add http:// or https:// to the beginning of the URL"

        case .blockedScheme, .unsupportedScheme:
            return "Use a URL starting with http:// or https://"

        case .missingHost:
            return "Enter a complete URL including the domain name"

        case .privateNetwork:
            return "Use a public URL from the internet, not an internal network address"

        case .suspiciousPattern:
            return "This URL appears to be malformed. Please check the URL and try again"
        }
    }
}
