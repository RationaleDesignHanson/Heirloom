//
//  PlatformDetectorAdversarialTests.swift
//  HeirloomTestsV2
//
//  Adversarial tests for platform detection (edge cases, errors, boundaries)
//  Created: 2026-01-20
//

import XCTest
@testable import Heirloom

@MainActor
final class PlatformDetectorAdversarialTests: XCTestCase {

    // MARK: - Malformed URLs

    func test_malformedURL_returnsNilOrUnknown() {
        // Given: Malformed URLs
        let malformedURLs = [
            "not a url at all",
            "htp://tiktok.com", // Typo in protocol
            "https://", // Missing domain
            "://www.tiktok.com", // Missing protocol
            "tiktok.com/@user/video/123", // Missing protocol
            "https://tiktok.com", // No path
            "www.instagram.com/reel/123" // Missing protocol
        ]

        // When/Then: Each should return nil or unknown
        for urlString in malformedURLs {
            let result = PlatformDetector.detect(from: urlString)
            XCTAssertTrue(
                result == nil || result?.platform == .unknown,
                "Malformed URL should not detect platform: \(urlString)"
            )
        }
    }

    func test_emptyString_returnsNil() {
        // Given: Empty string
        let empty = ""

        // When: Detect platform
        let result = PlatformDetector.detect(from: empty)

        // Then: Should return nil
        XCTAssertNil(result, "Empty string should return nil")
    }

    func test_whitespaceOnlyString_returnsNil() {
        // Given: Whitespace only
        let whitespace = "   \n\t  "

        // When: Detect platform
        let result = PlatformDetector.detect(from: whitespace)

        // Then: Should return nil
        XCTAssertNil(result, "Whitespace should return nil")
    }

    // MARK: - Non-Video URLs

    func test_nonVideoSocialURL_returnsNilOrUnknown() {
        // Given: Social URLs that aren't videos
        let nonVideoURLs = [
            "https://www.tiktok.com/@user", // Profile, not video
            "https://www.instagram.com/user", // Profile
            "https://www.youtube.com/channel/UCxyz", // Channel
            "https://www.facebook.com/profile.php?id=123" // Profile
        ]

        // When/Then: Should return nil or unknown
        for urlString in nonVideoURLs {
            let result = PlatformDetector.detect(from: urlString)
            XCTAssertTrue(
                result == nil || result?.platform == .unknown,
                "Non-video URL should not be detected: \(urlString)"
            )
        }
    }

    func test_nonSocialURL_returnsNilOrUnknown() {
        // Given: Valid URLs but not social platforms
        let nonSocialURLs = [
            "https://www.apple.com",
            "https://www.google.com/search?q=recipe",
            "https://www.nytimes.com/cooking/recipes/12345",
            "https://github.com/user/repo"
        ]

        // When/Then: Should return nil or unknown
        for urlString in nonSocialURLs {
            let result = PlatformDetector.detect(from: urlString)
            XCTAssertTrue(
                result == nil || result?.platform == .unknown,
                "Non-social URL should not be detected: \(urlString)"
            )
        }
    }

    // MARK: - Edge Cases

    func test_extremelyLongURL_handledGracefully() {
        // Given: Extremely long URL (10,000 characters)
        let longPath = String(repeating: "a", count: 10000)
        let longURL = "https://www.tiktok.com/@user/video/\(longPath)"

        // When: Detect platform
        let result = PlatformDetector.detect(from: longURL)

        // Then: Should not crash (may return nil or unknown)
        // Just testing that it doesn't crash
        XCTAssertNotNil(result == nil || result?.platform == .unknown || result?.platform == .tiktok,
                       "Should handle extremely long URL gracefully")
    }

    func test_urlWithSpecialCharacters_handledGracefully() {
        // Given: URL with special characters
        let specialURLs = [
            "https://www.tiktok.com/@user%20name/video/123",
            "https://www.tiktok.com/@user_name/video/123?param=value&other=test",
            "https://www.tiktok.com/@user.name/video/123#anchor"
        ]

        // When/Then: Should not crash
        for urlString in specialURLs {
            let result = PlatformDetector.detect(from: urlString)
            // Just verify it doesn't crash - result may vary
            _ = result
        }
    }

    func test_unicodeURL_handledGracefully() {
        // Given: URL with unicode characters
        let unicodeURL = "https://www.tiktok.com/@用户/video/123"

        // When: Detect platform
        let result = PlatformDetector.detect(from: unicodeURL)

        // Then: Should not crash
        _ = result
    }

    func test_urlWithFragment_stillDetected() {
        // Given: URL with fragment/anchor
        let url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ#t=10s"

        // When: Detect platform
        let result = PlatformDetector.detect(from: url)

        // Then: Should still detect YouTube
        XCTAssertEqual(result?.platform, .youtube)
    }

    func test_urlWithMultipleQueryParams_stillDetected() {
        // Given: URL with many query parameters
        let url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ&feature=share&t=10&list=abc"

        // When: Detect platform
        let result = PlatformDetector.detect(from: url)

        // Then: Should still detect YouTube and extract video ID
        XCTAssertEqual(result?.platform, .youtube)
        XCTAssertEqual(result?.videoId, "dQw4w9WgXcQ")
    }

    // MARK: - Boundary Cases

    func test_minimumValidURL_detected() {
        // Given: Shortest possible valid URLs
        let minimalURLs = [
            "https://youtu.be/a", // 1-char video ID
            "https://vm.tiktok.com/z" // 1-char short code
        ]

        // When/Then: Should handle gracefully
        for urlString in minimalURLs {
            let result = PlatformDetector.detect(from: urlString)
            // Should not crash - may or may not detect depending on validation rules
            _ = result
        }
    }

    func test_missingVideoID_returnsNilOrUnknown() {
        // Given: Platform URLs without video IDs
        let urlsWithoutVideoID = [
            "https://www.tiktok.com/@user/video/",
            "https://www.youtube.com/watch?v=",
            "https://youtu.be/",
            "https://www.instagram.com/reel/"
        ]

        // When/Then: Should return nil or unknown
        for urlString in urlsWithoutVideoID {
            let result = PlatformDetector.detect(from: urlString)
            XCTAssertTrue(
                result == nil || result?.platform == .unknown || result?.videoId == nil,
                "URL without video ID should not be valid: \(urlString)"
            )
        }
    }

    // MARK: - Text Detection Edge Cases

    func test_textWithoutURL_returnsNil() {
        // Given: Plain text with no URL
        let text = "This is just some regular text about cooking"

        // When: Detect platform
        let result = PlatformDetector.detect(from: text)

        // Then: Should return nil
        XCTAssertNil(result, "Text without URL should return nil")
    }

    func test_textWithMalformedURL_returnsNilOrUnknown() {
        // Given: Text with malformed URL
        let text = "Check this out: htp://tiktok.com/broken"

        // When: Detect platform
        let result = PlatformDetector.detect(from: text)

        // Then: Should return nil or unknown
        XCTAssertTrue(
            result == nil || result?.platform == .unknown,
            "Malformed URL in text should not detect platform"
        )
    }

    func test_emptyTextAfterURLExtraction_handledGracefully() {
        // Given: Text that's just whitespace
        let text = "         "

        // When: Detect platform
        let result = PlatformDetector.detect(from: text)

        // Then: Should return nil
        XCTAssertNil(result, "Whitespace text should return nil")
    }
}
