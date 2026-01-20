import XCTest
@testable import Heirloom

final class PlatformDetectorTests: XCTestCase {

    func testTikTokFullURL() {
        let url = URL(string: "https://www.tiktok.com/@chef/video/1234567890")!
        let result = PlatformDetector.detect(from: url)

        XCTAssertEqual(result?.platform, .tiktok)
        XCTAssertEqual(result?.extractedUsername, "chef")
        XCTAssertEqual(result?.videoId, "1234567890")
    }

    func testTikTokShortURL() {
        let url = URL(string: "https://vm.tiktok.com/ABC123")!
        let result = PlatformDetector.detect(from: url)

        XCTAssertEqual(result?.platform, .tiktok)
        XCTAssertTrue(result?.isShortURL ?? false)
    }

    func testInstagramReel() {
        let url = URL(string: "https://www.instagram.com/reel/ABC123xyz")!
        let result = PlatformDetector.detect(from: url)

        XCTAssertEqual(result?.platform, .instagram)
        XCTAssertEqual(result?.videoId, "ABC123xyz")
    }

    func testYouTubeShorts() {
        let url = URL(string: "https://youtube.com/shorts/dQw4w9WgXcQ")!
        let result = PlatformDetector.detect(from: url)

        XCTAssertEqual(result?.platform, .youtube)
        XCTAssertEqual(result?.videoId, "dQw4w9WgXcQ")
    }

    func testNonVideoURL() {
        let url = URL(string: "https://apple.com")!
        let result = PlatformDetector.detect(from: url)

        XCTAssertNil(result)
    }

    func testURLExtractionFromText() {
        let text = "Check out this recipe! https://vm.tiktok.com/ABC123 So good!"
        let result = PlatformDetector.detect(from: text)

        XCTAssertEqual(result?.platform, .tiktok)
    }
}
