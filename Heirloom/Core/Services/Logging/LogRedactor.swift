//
//  LogRedactor.swift
//  Heirloom
//
//  Phase 4: Code Quality & Cleanup
//  Redacts sensitive information from logs (emails, tokens, passwords)
//

import Foundation

/// Utility for redacting sensitive information from log messages
struct LogRedactor {
    // MARK: - Sensitive Patterns

    private static let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
    private static let uuidPattern = #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#
    private static let tokenPattern = #"\b(token|bearer|api[_-]?key|secret)["\s:=]+[A-Za-z0-9+/=_-]{20,}"#

    // Sensitive keys that should be redacted from metadata
    private static let sensitiveKeys: Set<String> = [
        "password",
        "token",
        "api_key",
        "apiKey",
        "secret",
        "bearer",
        "authorization",
        "auth_token",
        "authToken",
        "accessToken",
        "access_token",
        "refreshToken",
        "refresh_token",
        "credential",
        "sessionId",
        "session_id"
    ]

    // MARK: - Redaction

    /// Redact sensitive information from a string
    static func redact(_ message: String) -> String {
        var redacted = message

        // Redact emails
        redacted = redacted.replacingOccurrences(
            of: emailPattern,
            with: "[REDACTED_EMAIL]",
            options: .regularExpression
        )

        // Redact tokens and API keys (case insensitive)
        redacted = redacted.replacingOccurrences(
            of: tokenPattern,
            with: "[REDACTED_TOKEN]",
            options: [.regularExpression, .caseInsensitive]
        )

        // Keep UUIDs but optionally redact if needed
        // For now, UUIDs are considered non-sensitive for debugging

        return redacted
    }

    /// Redact sensitive keys from metadata dictionary
    static func redactMetadata(_ metadata: LogMetadata) -> LogMetadata {
        var redacted = metadata

        for (key, _) in metadata {
            let lowercaseKey = key.lowercased()
            if sensitiveKeys.contains(where: { lowercaseKey.contains($0) }) {
                redacted[key] = "[REDACTED]"
            }
        }

        return redacted
    }

    /// Check if a key is considered sensitive
    static func isSensitiveKey(_ key: String) -> Bool {
        let lowercaseKey = key.lowercased()
        return sensitiveKeys.contains(where: { lowercaseKey.contains($0) })
    }
}

// MARK: - String Extension

extension String {
    /// Convenience method to redact sensitive information
    var redacted: String {
        LogRedactor.redact(self)
    }
}

// MARK: - LogMetadata Extension

extension Dictionary where Key == String, Value == Any {
    /// Convenience method to redact sensitive metadata
    var redacted: [String: Any] {
        LogRedactor.redactMetadata(self)
    }
}
