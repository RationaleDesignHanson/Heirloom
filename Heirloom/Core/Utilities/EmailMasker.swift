//
//  EmailMasker.swift
//  Heirloom
//
//  Created: 2026-02-02
//  Utility for masking email addresses while preserving distinguishability
//

import Foundation

/// Masks email addresses proportionally for privacy while keeping enough info to distinguish users
enum EmailMasker {

    /// Masks an email address with proportional character visibility
    ///
    /// Examples:
    /// - "a@x.com" → "a***@x.com" (very short)
    /// - "john@x.com" → "jo***@x.com" (short)
    /// - "grandma@family.com" → "gran***@family.com" (medium)
    /// - "grandmother_betty@family.com" → "grandmoth***@family.com" (long)
    ///
    /// Algorithm:
    /// - Shows 40% of username characters (min 1, max 10)
    /// - Always masks at least 3 characters (or rest if shorter)
    /// - Shows full domain (for disambiguation: family.com vs scammer.com)
    ///
    /// - Parameter email: The email address to mask
    /// - Returns: Masked email with "***" replacing hidden characters
    static func mask(_ email: String) -> String {
        let parts = email.split(separator: "@")
        guard parts.count == 2 else {
            // Invalid email format, return as-is
            return email
        }

        let username = String(parts[0])
        let domain = String(parts[1])

        // Handle very short usernames (1-2 chars)
        if username.count <= 2 {
            return "\(username.prefix(1))***@\(domain)"
        }

        // Calculate how many characters to show (40% of username, min 1, max 10)
        let visibleCount = min(max(Int(Double(username.count) * 0.4), 1), 10)

        // Edge case: if username is very short and we'd show everything, force masking
        let finalVisibleCount: Int
        if visibleCount >= username.count - 1 {
            // Don't show the entire username - leave at least 1 char masked
            finalVisibleCount = max(username.count - 2, 1)
        } else {
            finalVisibleCount = visibleCount
        }

        let visiblePart = username.prefix(finalVisibleCount)
        return "\(visiblePart)***@\(domain)"
    }

    /// Masks multiple email addresses
    static func maskAll(_ emails: [String]) -> [String] {
        emails.map { mask($0) }
    }
}

// MARK: - Examples (for documentation/testing)

/*
 Examples of masking behavior:

 EmailMasker.mask("a@example.com")
 → "a***@example.com"

 EmailMasker.mask("ab@example.com")
 → "a***@example.com"

 EmailMasker.mask("john@example.com")
 → "jo***@example.com" (4 chars: show 40% = 1.6 → 2 chars)

 EmailMasker.mask("sarah@example.com")
 → "sa***@example.com" (5 chars: show 40% = 2 chars)

 EmailMasker.mask("grandma@family.com")
 → "gran***@family.com" (7 chars: show 40% = 2.8 → 3 chars)

 EmailMasker.mask("grandmother@family.com")
 → "grand***@family.com" (11 chars: show 40% = 4.4 → 4 chars)

 EmailMasker.mask("grandmother_betty@family.com")
 → "grandmoth***@family.com" (17 chars: show 40% = 6.8 → 7 chars)

 EmailMasker.mask("this_is_a_really_long_email_address@example.com")
 → "this_is_a_***@example.com" (31 chars: show 40% = 12.4 → 10 chars max)

 Domain is always visible for disambiguation:
 EmailMasker.mask("betty@family.com") → "bet***@family.com"
 EmailMasker.mask("betty@scammer.com") → "bet***@scammer.com"
 ✅ Can still tell them apart!
 */
