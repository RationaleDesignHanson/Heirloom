//
//  HTMLSanitizer.swift
//  Heirloom
//
//  Created by Claude Code on 1/7/26.
//  Security Phase 1: XSS prevention through HTML sanitization
//

import Foundation

/// HTML sanitizer to prevent XSS (Cross-Site Scripting) attacks
/// Removes dangerous HTML tags, JavaScript, and malicious content from user input
class HTMLSanitizer {
    static let shared = HTMLSanitizer()

    // MARK: - Dangerous Patterns

    /// HTML tags that enable script execution
    private let dangerousTags = [
        "<script", "</script>",
        "<iframe", "</iframe>",
        "<object", "</object>",
        "<embed", "</embed>",
        "<applet", "</applet>",
        "<meta", "</meta>",
        "<link", "</link>",
        "<style", "</style>",
        "<form", "</form>",
        "<input", "</input>",
        "<button", "</button>",
        "<textarea", "</textarea>",
        "<select", "</select>"
    ]

    /// Event handler attributes that execute JavaScript
    private let eventHandlers = [
        "onclick", "ondblclick", "onmousedown", "onmouseup", "onmouseover",
        "onmousemove", "onmouseout", "onmouseenter", "onmouseleave",
        "onload", "onunload", "onchange", "onsubmit", "onreset",
        "onselect", "onblur", "onfocus", "onkeydown", "onkeypress",
        "onkeyup", "onerror", "onabort", "ondrag", "ondrop"
    ]

    // MARK: - Sanitization Methods

    /// Sanitizes HTML input by removing dangerous tags and scripts
    /// - Parameter input: Raw user input potentially containing HTML
    /// - Returns: Sanitized string safe for display
    func sanitize(_ input: String) -> String {
        guard !input.isEmpty else { return input }

        var sanitized = input

        // Step 1: Decode HTML entities to catch encoded attacks
        sanitized = decodeHTMLEntities(sanitized)

        // Step 1.5: Normalize Unicode to prevent RLO and other exploits (SEC-7)
        sanitized = normalizeUnicode(sanitized)

        // Step 2: Remove dangerous HTML tags
        sanitized = removeDangerousTags(sanitized)

        // Step 3: Remove event handler attributes
        sanitized = removeEventHandlers(sanitized)

        // Step 4: Remove javascript: and data: URL schemes
        sanitized = removeDangerousURLSchemes(sanitized)

        // Step 5: Remove HTML comments (can hide malicious code)
        sanitized = removeHTMLComments(sanitized)

        // Step 6: Normalize whitespace
        sanitized = normalizeWhitespace(sanitized)

        return sanitized
    }

    /// Strips ALL HTML tags, leaving only plain text
    /// Use this for fields that should never contain HTML
    func stripAllHTML(_ input: String) -> String {
        guard !input.isEmpty else { return input }

        var stripped = input

        // Decode entities first
        stripped = decodeHTMLEntities(stripped)

        // Normalize Unicode to prevent RLO and other exploits (SEC-7)
        stripped = normalizeUnicode(stripped)

        // Remove all HTML tags using regex
        let htmlPattern = "<[^>]+>"
        stripped = stripped.replacingOccurrences(
            of: htmlPattern,
            with: "",
            options: [.regularExpression]
        )

        // Remove HTML comments
        stripped = removeHTMLComments(stripped)

        // Normalize whitespace
        stripped = normalizeWhitespace(stripped)

        return stripped
    }

    // MARK: - Private Helper Methods

    /// Removes dangerous HTML tags that can execute scripts
    private func removeDangerousTags(_ text: String) -> String {
        var result = text

        for tag in dangerousTags {
            // Remove opening and closing tags (case insensitive)
            result = result.replacingOccurrences(
                of: tag,
                with: "",
                options: [.caseInsensitive, .regularExpression]
            )

            // Also remove self-closing variants like <script/>
            let selfClosingTag = tag.replacingOccurrences(of: "<", with: "<") + "[^>]*?/>"
            result = result.replacingOccurrences(
                of: selfClosingTag,
                with: "",
                options: [.caseInsensitive, .regularExpression]
            )
        }

        return result
    }

    /// Removes event handler attributes that execute JavaScript
    private func removeEventHandlers(_ text: String) -> String {
        var result = text

        for handler in eventHandlers {
            // Pattern: onclick="..." or onclick='...' or onclick=javascript:...
            let patterns = [
                "\(handler)\\s*=\\s*\"[^\"]*\"",  // Double quotes
                "\(handler)\\s*=\\s*'[^']*'",    // Single quotes
                "\(handler)\\s*=\\s*[^\\s>]*"    // No quotes
            ]

            for pattern in patterns {
                result = result.replacingOccurrences(
                    of: pattern,
                    with: "",
                    options: [.regularExpression, .caseInsensitive]
                )
            }
        }

        return result
    }

    /// Removes javascript:, data:, and vbscript: URL schemes
    private func removeDangerousURLSchemes(_ text: String) -> String {
        var result = text

        let dangerousSchemes = [
            "javascript:",
            "data:",
            "vbscript:",
            "file://",
            "about:"
        ]

        for scheme in dangerousSchemes {
            result = result.replacingOccurrences(
                of: scheme,
                with: "blocked:",
                options: [.caseInsensitive]
            )
        }

        // Also catch encoded versions (%6A%61%76%61%73%63%72%69%70%74 = javascript)
        let encodedJSPattern = "(%6A|%6a)(%61|%41)(%76|%56)"
        result = result.replacingOccurrences(
            of: encodedJSPattern,
            with: "blocked",
            options: [.regularExpression, .caseInsensitive]
        )

        return result
    }

    /// Removes HTML comments <!-- ... -->
    private func removeHTMLComments(_ text: String) -> String {
        let commentPattern = "<!--[\\s\\S]*?-->"
        return text.replacingOccurrences(
            of: commentPattern,
            with: "",
            options: [.regularExpression]
        )
    }

    /// Decodes common HTML entities to catch encoded attacks
    private func decodeHTMLEntities(_ text: String) -> String {
        var result = text

        let entities: [String: String] = [
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&amp;": "&",
            "&#60;": "<",
            "&#62;": ">",
            "&#34;": "\"",
            "&#39;": "'",
            "&#38;": "&",
            "&#x3C;": "<",
            "&#x3E;": ">",
            "&#x22;": "\"",
            "&#x27;": "'",
            "&#x26;": "&"
        ]

        for (entity, character) in entities {
            result = result.replacingOccurrences(
                of: entity,
                with: character,
                options: [.caseInsensitive]
            )
        }

        return result
    }

    /// Normalizes whitespace (collapse multiple spaces/newlines)
    private func normalizeWhitespace(_ text: String) -> String {
        // Replace multiple spaces with single space
        var result = text.replacingOccurrences(
            of: " {2,}",
            with: " ",
            options: [.regularExpression]
        )

        // Replace multiple newlines with double newline
        result = result.replacingOccurrences(
            of: "\n{3,}",
            with: "\n\n",
            options: [.regularExpression]
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Normalizes Unicode and removes dangerous Unicode characters (SEC-7)
    /// Prevents attacks using RLO (Right-to-Left Override) and other Unicode exploits
    private func normalizeUnicode(_ text: String) -> String {
        var result = text

        // Remove dangerous Unicode formatting characters
        // U+202E: Right-to-Left Override (RLO) - can disguise malicious text
        // U+202D: Left-to-Right Override (LRO)
        // U+202C: Pop Directional Formatting (PDF)
        // U+202A: Left-to-Right Embedding (LRE)
        // U+202B: Right-to-Left Embedding (RLE)
        // U+200E: Left-to-Right Mark (LRM)
        // U+200F: Right-to-Left Mark (RLM)
        let dangerousUnicodeChars: [Unicode.Scalar] = [
            "\u{202E}", // RLO
            "\u{202D}", // LRO
            "\u{202C}", // PDF
            "\u{202A}", // LRE
            "\u{202B}", // RLE
            "\u{200E}", // LRM
            "\u{200F}"  // RLM
        ]

        for char in dangerousUnicodeChars {
            result = result.replacingOccurrences(of: String(char), with: "")
        }

        // Apply NFC (Canonical Decomposition followed by Canonical Composition)
        // This normalizes composed/decomposed Unicode variations
        result = result.precomposedStringWithCanonicalMapping

        return result
    }

    // MARK: - Validation Methods

    /// Checks if input contains potentially dangerous content
    /// Returns true if suspicious patterns are detected
    func containsDangerousContent(_ input: String) -> Bool {
        let lowercased = input.lowercased()

        // Check for dangerous tags
        for tag in dangerousTags {
            if lowercased.contains(tag) {
                return true
            }
        }

        // Check for javascript: scheme
        if lowercased.contains("javascript:") || lowercased.contains("data:text/html") {
            return true
        }

        // Check for event handlers
        for handler in eventHandlers {
            if lowercased.contains(handler) {
                return true
            }
        }

        return false
    }

    /// Validates that sanitization was effective
    /// Returns the original string only if it's safe after sanitization
    func validateAndSanitize(_ input: String) throws -> String {
        let sanitized = sanitize(input)

        // If sanitized version is much shorter, something was removed
        let removalPercentage = Double(input.count - sanitized.count) / Double(input.count)
        if removalPercentage > 0.3 {
            throw HTMLSanitizationError.suspiciousContentRemoved(
                original: input.count,
                sanitized: sanitized.count
            )
        }

        return sanitized
    }
}

// MARK: - Sanitization Errors

enum HTMLSanitizationError: LocalizedError {
    case suspiciousContentRemoved(original: Int, sanitized: Int)
    case containsMaliciousCode

    var errorDescription: String? {
        switch self {
        case .suspiciousContentRemoved(let original, let sanitized):
            let removed = original - sanitized
            return "Potentially dangerous content was detected and removed (\(removed) characters). Please review your input."

        case .containsMaliciousCode:
            return "Input contains potentially malicious code and cannot be saved."
        }
    }
}
