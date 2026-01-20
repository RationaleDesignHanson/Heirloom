//
//  PlatformDetectorBaselineTests.swift
//  HeirloomTestsV2
//
//  Baseline tests for platform detection (happy path scenarios)
//  Created: 2026-01-20
//

import XCTest
@testable import Heirloom

@MainActor
final class PlatformDetectorBaselineTests: XCTestCase {

    // MARK: - TikTok Detection

    func test_validTikTokURL_detectedCorrectly() {
        // Given: Valid TikTok URLs in various formats
        let validURLs = [
            "https://www.tiktok.com/@chef/video/1234567890",
            "https://tiktok.com/@user/video/9876543210",
            "https://m.tiktok.com/@creator/video/5555555555"
        ]

        // When/Then: Each should detect TikTok platform
        for urlString in validURLs {
            guard let url = URL(string: urlString) else {
                XCTFail("Invalid URL string: \(urlString)")
                continue
            }
            let result = PlatformDetector.detect(from: url)
            XCTAssertEqual(result?.platform, .tiktok, "Should detect TikTok for: \(urlString)")
            XCTAssertNotNil(result?.videoId, "Should extract video ID")
        }
    }

    func test_tiktokShortURL_detectedCorrectly() {
        // Given: TikTok short URL
        let url = URL(string: "https://vm.tiktok.com/ABC123")!

        // When: Detect platform
        let result = PlatformDetector.detect(from: url)

        // Then: Should detect TikTok and mark as short URL
        XCTAssertEqual(result?.platform, .tiktok)
        XCTAssertTrue(result?.isShortURL ?? false, "Should be marked as short URL")
    }

    func test_tiktokURL_extractsUsername() {
        // Given: TikTok URL with username
        let url = URL(string: "https://www.tiktok.com/@chef/video/1234567890")!

        // When: Detect platform
        let result = PlatformDetector.detect(from: url)

        // Then: Should extract username
        XCTAssertEqual(result?.extractedUsername, "chef", "Should extract username")
    }

    func test_tiktokURL_extractsVideoID() {
        // Given: TikTok URL with video ID
        let url = URL(string: "https://www.tiktok.com/@user/video/1234567890")!

        // When: Detect platform
        let result = PlatformDetector.detect(from: url)

        // Then: Should extract video ID
        XCTAssertEqual(result?.videoId, "1234567890", "Should extract video ID")
    }

    // MARK: - Instagram Detection

    func test_instagramReel_detectedCorrectly() {
        // Given: Instagram Reel URL
        let url = URL(string: "https://www.instagram.com/reel/ABC123xyz")!

        // When: Detect platform
        let result = PlatformDetector.detect(from: url)

        // Then: Should detect Instagram
        XCTAssertEqual(result?.platform, .instagram)
        XCTAssertEqual(result?.videoId, "ABC123xyz", "Should extract reel ID")
    }

    func test_instagramReelVariants_allDetected() {
        // Given: Various Instagram Reel URL formats
        let validURLs = [
            "https://www.instagram.com/reel/ABC123/",
            "https://instagram.com/reel/XYZ789",
            "https://www.instagram.com/p/POST123/" // Post format
        ]

        // When/Then: Each should detect Instagram
        for urlString in validURLs {
            guard let url = URL(string: urlString) else {
                XCTFail("Invalid URL string: \(urlString)")
                continue
            }
            let result = PlatformDetector.detect(from: url)
            XCTAssertEqual(result?.platform, .instagram, "Should detect Instagram for: \(urlString)")
        }
    }

    // MARK: - YouTube Detection

    func test_youtubeFullURL_detectedCorrectly() {
        // Given: Full YouTube URL
        let url = URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!

        // When: Detect platform
        let result = PlatformDetector.detect(from: url)

        // Then: Should detect YouTube
        XCTAssertEqual(result?.platform, .youtube)
        XCTAssertEqual(result?.videoId, "dQw4w9WgXcQ", "Should extract video ID")
    }

    func test_youtubeShortURL_detectedCorrectly() {
        // Given: YouTube short URL (youtu.be)
        let url = URL(string: "https://youtu.be/dQw4w9WgXcQ")!

        // When: Detect platform
        let result = PlatformDetector.detect(from: url)

        // Then: Should detect YouTube
        XCTAssertEqual(result?.platform, .youtube)
        XCTAssertEqual(result?.videoId, "dQw4w9WgXcQ")
        XCTAssertTrue(result?.isShortURL ?? false)
    }

    func test_youtubeShortsURL_detectedCorrectly() {
        // Given: YouTube Shorts URL
        let url = URL(string: "https://youtube.com/shorts/abc123XYZ")!

        // When: Detect platform
        let result = PlatformDetector.detect(from: url)

        // Then: Should detect YouTube
        XCTAssertEqual(result?.platform, .youtube)
        XCTAssertEqual(result?.videoId, "abc123XYZ")
    }

    // MARK: - Facebook Detection

    func test_facebookVideoURL_detectedCorrectly() {
        // Given: Facebook video URL
        let url = URL(string: "https://www.facebook.com/watch?v=123456789")!

        // When: Detect platform
        let result = PlatformDetector.detect(from: url)

        // Then: Should detect Facebook
        XCTAssertEqual(result?.platform, .facebook)
    }

    // MARK: - String Detection

    func test_urlInPlainText_detected() {
        // Given: Plain text with embedded URL
        let text = "Check out this recipe! https://vm.tiktok.com/ABC123 So good!"

        // When: Detect platform from text
        let result = PlatformDetector.detect(from: text)

        // Then: Should extract and detect URL
        XCTAssertEqual(result?.platform, .tiktok, "Should detect TikTok from embedded URL")
    }

    func test_multipleURLsInText_firstDetected() {
        // Given: Text with multiple URLs
        let text = """
        Check these out:
        https://www.tiktok.com/@user/video/111
        https://youtube.com/watch?v=222
        """

        // When: Detect platform
        let result = PlatformDetector.detect(from: text)

        // Then: Should detect first URL (TikTok)
        XCTAssertEqual(result?.platform, .tiktok, "Should detect first URL")
    }
}
