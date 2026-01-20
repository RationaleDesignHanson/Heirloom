import Foundation

struct DetectedPlatformInfo {
    let platform: SocialPlatform
    let videoId: String?
    let originalURL: URL
    let isShortURL: Bool
    let extractedUsername: String?
}

enum PlatformDetector {

    // MARK: - Main Detection

    static func detect(from url: URL) -> DetectedPlatformInfo? {
        let urlString = url.absoluteString.lowercased()
        let host = url.host?.lowercased() ?? ""

        if let info = detectTikTok(url: url, urlString: urlString, host: host) {
            return info
        }
        if let info = detectInstagram(url: url, urlString: urlString, host: host) {
            return info
        }
        if let info = detectYouTube(url: url, urlString: urlString, host: host) {
            return info
        }
        if let info = detectFacebook(url: url, urlString: urlString, host: host) {
            return info
        }

        return nil
    }

    static func detect(from text: String) -> DetectedPlatformInfo? {
        guard let url = extractFirstURL(from: text) else { return nil }
        return detect(from: url)
    }

    static func extractFirstURL(from text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)

        if let match = detector?.firstMatch(in: text, options: [], range: range),
           let urlRange = Range(match.range, in: text) {
            return URL(string: String(text[urlRange]))
        }
        return nil
    }

    // MARK: - TikTok

    private static func detectTikTok(url: URL, urlString: String, host: String) -> DetectedPlatformInfo? {
        let tiktokHosts = ["tiktok.com", "www.tiktok.com", "m.tiktok.com", "vm.tiktok.com", "vt.tiktok.com"]
        guard tiktokHosts.contains(where: { host.contains($0) }) else { return nil }

        let isShort = host.contains("vm.tiktok.com") || host.contains("vt.tiktok.com")

        // Pattern: /@username/video/videoId
        let pattern = #"@([A-Za-z0-9_.]+)/video/(\d+)"#
        if let match = urlString.firstMatch(of: try! Regex(pattern)) {
            return DetectedPlatformInfo(
                platform: .tiktok,
                videoId: String(match.output.2),
                originalURL: url,
                isShortURL: isShort,
                extractedUsername: String(match.output.1)
            )
        }

        // Short URL without username
        return DetectedPlatformInfo(
            platform: .tiktok,
            videoId: nil,
            originalURL: url,
            isShortURL: isShort,
            extractedUsername: nil
        )
    }

    // MARK: - Instagram

    private static func detectInstagram(url: URL, urlString: String, host: String) -> DetectedPlatformInfo? {
        let instaHosts = ["instagram.com", "www.instagram.com", "instagr.am"]
        guard instaHosts.contains(where: { host.contains($0) }) else { return nil }

        // Pattern: /reel/shortcode or /reels/shortcode or /p/shortcode
        let patterns = [
            #"/reel/([A-Za-z0-9_-]+)"#,
            #"/reels/([A-Za-z0-9_-]+)"#,
            #"/p/([A-Za-z0-9_-]+)"#
        ]

        for pattern in patterns {
            if let match = urlString.firstMatch(of: try! Regex(pattern)) {
                return DetectedPlatformInfo(
                    platform: .instagram,
                    videoId: String(match.output.1),
                    originalURL: url,
                    isShortURL: host.contains("instagr.am"),
                    extractedUsername: nil
                )
            }
        }

        return DetectedPlatformInfo(
            platform: .instagram,
            videoId: nil,
            originalURL: url,
            isShortURL: false,
            extractedUsername: nil
        )
    }

    // MARK: - YouTube

    private static func detectYouTube(url: URL, urlString: String, host: String) -> DetectedPlatformInfo? {
        let ytHosts = ["youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"]
        guard ytHosts.contains(where: { host.contains($0) }) else { return nil }

        var videoId: String?

        // youtu.be/videoId
        if host.contains("youtu.be") {
            videoId = url.pathComponents.last
        }
        // youtube.com/watch?v=videoId
        else if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let v = components.queryItems?.first(where: { $0.name == "v" })?.value {
            videoId = v
        }
        // youtube.com/shorts/videoId
        else if urlString.contains("/shorts/") {
            let pattern = #"/shorts/([A-Za-z0-9_-]+)"#
            if let match = urlString.firstMatch(of: try! Regex(pattern)) {
                videoId = String(match.output.1)
            }
        }

        return DetectedPlatformInfo(
            platform: .youtube,
            videoId: videoId,
            originalURL: url,
            isShortURL: host.contains("youtu.be"),
            extractedUsername: nil
        )
    }

    // MARK: - Facebook

    private static func detectFacebook(url: URL, urlString: String, host: String) -> DetectedPlatformInfo? {
        let fbHosts = ["facebook.com", "www.facebook.com", "m.facebook.com", "fb.watch"]
        guard fbHosts.contains(where: { host.contains($0) }) else { return nil }

        // Pattern: /reel/videoId or /videos/videoId
        let patterns = [
            #"/reel/(\d+)"#,
            #"/videos/(\d+)"#
        ]

        for pattern in patterns {
            if let match = urlString.firstMatch(of: try! Regex(pattern)) {
                return DetectedPlatformInfo(
                    platform: .facebook,
                    videoId: String(match.output.1),
                    originalURL: url,
                    isShortURL: host.contains("fb.watch"),
                    extractedUsername: nil
                )
            }
        }

        return DetectedPlatformInfo(
            platform: .facebook,
            videoId: nil,
            originalURL: url,
            isShortURL: host.contains("fb.watch"),
            extractedUsername: nil
        )
    }
}
