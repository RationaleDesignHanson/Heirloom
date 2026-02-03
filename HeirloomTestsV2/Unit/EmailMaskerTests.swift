//
//  EmailMaskerTests.swift
//  HeirloomTestsV2
//
//  Created: 2026-02-02
//  Tests for proportional email masking utility
//

import XCTest
@testable import Heirloom

final class EmailMaskerTests: XCTestCase {

    // MARK: - Short Usernames (1-4 chars)

    func testMaskVeryShortUsername() {
        XCTAssertEqual(EmailMasker.mask("a@example.com"), "a***@example.com")
        XCTAssertEqual(EmailMasker.mask("ab@example.com"), "a***@example.com")
    }

    func testMaskShortUsername() {
        // "john" = 4 chars, 40% = 1.6 → rounds to 2 chars
        XCTAssertEqual(EmailMasker.mask("john@example.com"), "jo***@example.com")

        // "jane" = 4 chars, 40% = 1.6 → rounds to 2 chars
        XCTAssertEqual(EmailMasker.mask("jane@example.com"), "ja***@example.com")
    }

    // MARK: - Medium Usernames (5-10 chars)

    func testMaskMediumUsername() {
        // "sarah" = 5 chars, 40% = 2 chars
        XCTAssertEqual(EmailMasker.mask("sarah@example.com"), "sa***@example.com")

        // "grandma" = 7 chars, 40% = 2.8 → rounds to 3 chars
        XCTAssertEqual(EmailMasker.mask("grandma@family.com"), "gra***@family.com")

        // "grandpop" = 8 chars, 40% = 3.2 → rounds to 3 chars
        XCTAssertEqual(EmailMasker.mask("grandpop@family.com"), "gra***@family.com")
    }

    // MARK: - Long Usernames (11+ chars)

    func testMaskLongUsername() {
        // "grandmother" = 11 chars, 40% = 4.4 → rounds to 4 chars
        XCTAssertEqual(EmailMasker.mask("grandmother@family.com"), "gran***@family.com")

        // "grandmother_betty" = 17 chars, 40% = 6.8 → rounds to 7 chars
        XCTAssertEqual(EmailMasker.mask("grandmother_betty@family.com"), "grandmo***@family.com")
    }

    // MARK: - Very Long Usernames (max cap at 10 chars)

    func testMaskVeryLongUsername() {
        // 31 chars: 40% = 12.4, but capped at max 10 chars
        let email = "this_is_a_really_long_email@example.com"
        let masked = EmailMasker.mask(email)

        // Should show first 10 chars + "***" + domain
        XCTAssertEqual(masked, "this_is_a_***@example.com")
    }

    // MARK: - Domain Preservation (for disambiguation)

    func testDomainAlwaysVisible() {
        // Different domains should remain distinguishable
        let masked1 = EmailMasker.mask("betty@family.com")
        let masked2 = EmailMasker.mask("betty@scammer.com")

        // Both mask username similarly
        XCTAssertTrue(masked1.hasPrefix("bet***@"))
        XCTAssertTrue(masked2.hasPrefix("bet***@"))

        // But domains are different and visible
        XCTAssertTrue(masked1.hasSuffix("@family.com"))
        XCTAssertTrue(masked2.hasSuffix("@scammer.com"))

        // They're different strings
        XCTAssertNotEqual(masked1, masked2)
    }

    // MARK: - Edge Cases

    func testInvalidEmailFormat() {
        // No @ symbol
        XCTAssertEqual(EmailMasker.mask("notanemail"), "notanemail")

        // Multiple @ symbols
        XCTAssertEqual(EmailMasker.mask("user@host@domain.com"), "user@host@domain.com")

        // Empty string
        XCTAssertEqual(EmailMasker.mask(""), "")
    }

    func testMinimumMasking() {
        // Even short usernames should mask at least 1 character
        let result = EmailMasker.mask("ab@x.com")
        XCTAssertFalse(result.starts(with: "ab@")) // Should not show full "ab"
        XCTAssertTrue(result.contains("***")) // Should have masking
    }

    // MARK: - Disambiguation Scenarios

    func testDisambiguatesSimilarNames() {
        // Same name, different email domains
        let results = [
            EmailMasker.mask("grandma@family.com"),
            EmailMasker.mask("grandma@smith-family.com"),
            EmailMasker.mask("grandma@jones.org")
        ]

        // All should show same username prefix
        XCTAssertTrue(results.allSatisfy { $0.hasPrefix("gra***@") })

        // But domains should be different
        XCTAssertTrue(results[0].contains("@family.com"))
        XCTAssertTrue(results[1].contains("@smith-family.com"))
        XCTAssertTrue(results[2].contains("@jones.org"))

        // All different
        XCTAssertEqual(Set(results).count, 3)
    }

    func testDisambiguatesDifferentUsernames() {
        // Different usernames, same domain
        let results = [
            EmailMasker.mask("grandma_betty@family.com"),
            EmailMasker.mask("grandma_susan@family.com"),
            EmailMasker.mask("grandma_mary@family.com")
        ]

        // All should have different visible parts
        XCTAssertTrue(results[0].hasPrefix("grandma_be***@"))
        XCTAssertTrue(results[1].hasPrefix("grandma_su***@"))
        XCTAssertTrue(results[2].hasPrefix("grandma_ma***@"))

        // All different
        XCTAssertEqual(Set(results).count, 3)
    }

    // MARK: - Batch Operations

    func testMaskAll() {
        let emails = [
            "john@example.com",
            "jane@example.com",
            "grandmother@family.com"
        ]

        let masked = EmailMasker.maskAll(emails)

        XCTAssertEqual(masked.count, 3)
        XCTAssertEqual(masked[0], "jo***@example.com")
        XCTAssertEqual(masked[1], "ja***@example.com")
        XCTAssertEqual(masked[2], "gran***@family.com")
    }

    // MARK: - Real-World Examples

    func testRealWorldEmailPatterns() {
        // Common email patterns
        XCTAssertEqual(EmailMasker.mask("user123@gmail.com"), "use***@gmail.com")
        XCTAssertEqual(EmailMasker.mask("firstname.lastname@company.com"), "firstn***@company.com")
        XCTAssertEqual(EmailMasker.mask("contact@business.org"), "con***@business.org")
    }

    // MARK: - Privacy Verification

    func testNeverShowsFullUsername() {
        // No matter how short, should never show the ENTIRE username
        let testCases = [
            "a@x.com",
            "ab@x.com",
            "abc@x.com",
            "abcd@x.com",
            "abcde@x.com"
        ]

        for email in testCases {
            let masked = EmailMasker.mask(email)
            let username = email.split(separator: "@")[0]

            // Masked version should not contain the full unmasked username
            XCTAssertTrue(masked.contains("***"), "Email '\(email)' should contain masking")
            XCTAssertFalse(masked.starts(with: "\(username)@"), "Should not show full username for '\(email)'")
        }
    }
}
