import Foundation

/// Resolves wrapped URLs from aggregation services to their original publisher URLs
/// Supports: Apple News, Google AMP Cache, Flipboard, Instapaper
actor UniversalURLResolver {

    // MARK: - Types

    enum ResolutionError: Error, LocalizedError {
        case notWrappedURL
        case paywallContent
        case resolutionFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .notWrappedURL:
                return "URL is not from a supported aggregation service"
            case .paywallContent:
                return "Content is behind a paywall and cannot be accessed"
            case .resolutionFailed(let error):
                return "Failed to resolve URL: \(error.localizedDescription)"
            }
        }
    }

    enum URLWrapper: String {
        case appleNews = "Apple News"
        case googleAMP = "Google AMP"
        case flipboard = "Flipboard"
        case instapaper = "Instapaper"
        case unknown = "Unknown"

        var displayName: String { rawValue }
    }

    // MARK: - Configuration

    private let timeout: TimeInterval = 15.0
    private let maxRedirects = 10

    // Desktop user agent to trigger redirects instead of app deep links
    private let desktopUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    /// Configured URLSession for network requests
    private let session: URLSession

    // MARK: - Initialization

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Detects if a URL is from a supported aggregation service
    func detectWrapper(_ url: URL) -> URLWrapper? {
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()

        // Apple News
        if host.contains("apple.news") || host == "news.apple.com" {
            // Exclude Apple's own news/blog pages
            if host.contains("developer.apple.com") || host.contains("apple.com/newsroom") {
                return nil
            }
            return .appleNews
        }

        // Google AMP Cache
        if host.contains("cdn.ampproject.org") ||
           (host.contains("google.com") && path.contains("/amp/")) ||
           host == "cdn.ampproject.org" {
            return .googleAMP
        }

        // Flipboard
        if host.contains("flipboard.com") || host == "flip.it" || host.contains("share.flipboard.com") {
            return .flipboard
        }

        // Instapaper
        if host.contains("instapaper.com") && (path.contains("/read/") || path.contains("/text")) {
            return .instapaper
        }

        return nil
    }

    /// Resolves a wrapped URL to its original publisher URL
    func resolve(_ url: URL) async throws -> URL {
        guard let wrapper = detectWrapper(url) else {
            throw ResolutionError.notWrappedURL
        }

        print("🔗 [URLResolver] Resolving \(wrapper.displayName) URL: \(url.absoluteString)")

        do {
            let resolvedURL: URL

            switch wrapper {
            case .appleNews:
                resolvedURL = try await resolveAppleNews(url)
            case .googleAMP:
                resolvedURL = try await resolveGoogleAMP(url)
            case .flipboard:
                resolvedURL = try await resolveFlipboard(url)
            case .instapaper:
                resolvedURL = try await resolveInstapaper(url)
            case .unknown:
                throw ResolutionError.notWrappedURL
            }

            print("✅ [URLResolver] Resolved to: \(resolvedURL.absoluteString)")
            return resolvedURL

        } catch ResolutionError.paywallContent {
            print("🔒 [URLResolver] Paywall content detected")
            throw ResolutionError.paywallContent
        } catch {
            print("❌ [URLResolver] Resolution failed: \(error)")
            throw ResolutionError.resolutionFailed(underlying: error)
        }
    }

    // MARK: - Platform-Specific Resolvers

    private func resolveAppleNews(_ url: URL) async throws -> URL {
        // Try HTTP redirect first (works for most public articles)
        if let redirectURL = try? await followRedirectWithDesktopUA(url) {
            return redirectURL
        }

        // Fallback: Fetch HTML and parse for original URL
        let html = try await fetchHTML(from: url)

        // Check for paywall indicators
        if html.contains("apple-news-paywall") || html.contains("apple-news-subscriber-only") {
            throw ResolutionError.paywallContent
        }

        // Try to extract original URL from HTML
        if let extractedURL = extractOriginalURL(from: html, wrapper: .appleNews) {
            return extractedURL
        }

        throw ResolutionError.resolutionFailed(underlying: NSError(
            domain: "UniversalURLResolver",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Could not extract original URL from Apple News page"]
        ))
    }

    private func resolveGoogleAMP(_ url: URL) async throws -> URL {
        let host = url.host?.lowercased() ?? ""

        // Handle AMP Cache CDN URLs (e.g., example-com.cdn.ampproject.org)
        if host.contains(".cdn.ampproject.org") {
            if let decodedURL = decodeAMPCacheURL(url) {
                return decodedURL
            }
        }

        // Handle google.com/amp/s/ URLs
        if host.contains("google.com") && url.path.contains("/amp/") {
            // Extract URL from path: /amp/s/example.com/article -> https://example.com/article
            let path = url.path
            if let range = path.range(of: "/amp/s/") {
                let urlString = String(path[range.upperBound...])
                if let extractedURL = URL(string: "https://\(urlString)") {
                    return extractedURL
                }
            }
        }

        // Fallback: Fetch AMP page and extract canonical link
        let html = try await fetchHTML(from: url)
        if let canonicalURL = extractCanonicalURL(from: html) {
            return canonicalURL
        }

        throw ResolutionError.resolutionFailed(underlying: NSError(
            domain: "UniversalURLResolver",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Could not decode AMP Cache URL"]
        ))
    }

    private func resolveFlipboard(_ url: URL) async throws -> URL {
        // Try HTTP redirect first
        if let redirectURL = try? await followRedirectWithDesktopUA(url) {
            // If we got redirected to a non-Flipboard domain, use it
            if !(redirectURL.host?.contains("flipboard.com") ?? false) &&
               !(redirectURL.host?.contains("flip.it") ?? false) {
                return redirectURL
            }
        }

        // Fallback: Fetch HTML and parse Open Graph URL
        let html = try await fetchHTML(from: url)

        if let ogURL = extractOpenGraphURL(from: html) {
            return ogURL
        }

        if let canonicalURL = extractCanonicalURL(from: html) {
            return canonicalURL
        }

        throw ResolutionError.resolutionFailed(underlying: NSError(
            domain: "UniversalURLResolver",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Could not extract original URL from Flipboard page"]
        ))
    }

    private func resolveInstapaper(_ url: URL) async throws -> URL {
        // Instapaper URLs often redirect automatically
        if let redirectURL = try? await followRedirectWithDesktopUA(url) {
            // If we got redirected to a non-Instapaper domain, use it
            if !(redirectURL.host?.contains("instapaper.com") ?? false) {
                return redirectURL
            }
        }

        // Fallback: Fetch HTML and parse canonical link
        let html = try await fetchHTML(from: url)

        if let canonicalURL = extractCanonicalURL(from: html) {
            return canonicalURL
        }

        throw ResolutionError.resolutionFailed(underlying: NSError(
            domain: "UniversalURLResolver",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Could not extract original URL from Instapaper page"]
        ))
    }

    // MARK: - URL Decoding

    private func decodeAMPCacheURL(_ url: URL) -> URL? {
        guard let host = url.host else { return nil }

        // Format: example-com.cdn.ampproject.org/path
        // Extract domain prefix before .cdn.ampproject.org
        let components = host.components(separatedBy: ".cdn.ampproject.org")
        guard let domainPrefix = components.first else { return nil }

        var decodedDomain = domainPrefix

        // Handle punycode (starts with xn--)
        if decodedDomain.hasPrefix("xn--") {
            // TODO: Proper punycode decoding if needed
            // For now, skip punycode domains
            return nil
        }

        // Handle escaped domains (0-example-com-0 -> example.com)
        if decodedDomain.hasPrefix("0-") && decodedDomain.hasSuffix("-0") {
            decodedDomain = String(decodedDomain.dropFirst(2).dropLast(2))
        }

        // Convert hyphens back to dots (example-com -> example.com)
        // Be careful: some domains legitimately have hyphens
        // AMP Cache encodes example.com as example-com
        let lastHyphenIndex = decodedDomain.lastIndex(of: "-")
        if let lastIndex = lastHyphenIndex {
            let beforeLast = decodedDomain[..<lastIndex]
            let afterLast = decodedDomain[decodedDomain.index(after: lastIndex)...]

            // If the part after last hyphen looks like a TLD (2-3 chars), replace with dot
            if afterLast.count >= 2 && afterLast.count <= 3 {
                decodedDomain = beforeLast + "." + afterLast
            }
        }

        // Reconstruct URL with original domain
        var urlString = "https://\(decodedDomain)\(url.path)"
        if let query = url.query {
            urlString += "?\(query)"
        }

        return URL(string: urlString)
    }

    // MARK: - HTTP Utilities

    private func followRedirectWithDesktopUA(_ url: URL) async throws -> URL {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue(desktopUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.httpMethod = "GET"

        let (_, response) = try await session.data(for: request)

        // Get final URL after redirects
        if let httpResponse = response as? HTTPURLResponse,
           let finalURL = httpResponse.url,
           finalURL.absoluteString != url.absoluteString {
            return finalURL
        }

        // No redirect occurred
        return url
    }

    private func fetchHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue(desktopUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "UniversalURLResolver", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "UniversalURLResolver", code: 6, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "UniversalURLResolver", code: 7, userInfo: [NSLocalizedDescriptionKey: "Could not decode HTML"])
        }

        return html
    }

    // MARK: - HTML Parsing

    private func extractOriginalURL(from html: String, wrapper: URLWrapper) -> URL? {
        // Try universal patterns first
        if let canonicalURL = extractCanonicalURL(from: html) {
            return canonicalURL
        }

        if let ogURL = extractOpenGraphURL(from: html) {
            return ogURL
        }

        if let metaRefreshURL = extractMetaRefreshURL(from: html) {
            return metaRefreshURL
        }

        // Platform-specific patterns
        switch wrapper {
        case .appleNews:
            return extractFirstNonAppleURL(from: html)
        default:
            return nil
        }
    }

    private func extractCanonicalURL(from html: String) -> URL? {
        // <link rel="canonical" href="https://example.com/article">
        let pattern = #"<link[^>]+rel=["']canonical["'][^>]+href=["']([^"']+)["']"#
        return extractURLWithPattern(pattern, from: html)
    }

    private func extractOpenGraphURL(from html: String) -> URL? {
        // <meta property="og:url" content="https://example.com/article">
        let pattern = #"<meta[^>]+property=["']og:url["'][^>]+content=["']([^"']+)["']"#
        return extractURLWithPattern(pattern, from: html)
    }

    private func extractMetaRefreshURL(from html: String) -> URL? {
        // <meta http-equiv="refresh" content="0;URL=https://example.com/article">
        let pattern = #"<meta[^>]+http-equiv=["']refresh["'][^>]+content=["'][^"']*URL=([^"']+)["']"#
        return extractURLWithPattern(pattern, from: html)
    }

    private func extractFirstNonAppleURL(from html: String) -> URL? {
        // Find first https:// URL that isn't apple.com or apple.news
        let pattern = #"https?://(?!.*apple\.(com|news))[^\s"'<>]+"#
        return extractURLWithPattern(pattern, from: html)
    }

    private func extractURLWithPattern(_ pattern: String, from html: String) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range) else {
            return nil
        }

        // Extract captured group (the URL)
        let captureRange: NSRange
        if match.numberOfRanges > 1 {
            captureRange = match.range(at: 1)
        } else {
            captureRange = match.range
        }

        guard let swiftRange = Range(captureRange, in: html) else {
            return nil
        }

        let urlString = String(html[swiftRange])
        return URL(string: urlString)
    }
}
