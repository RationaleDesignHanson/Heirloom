import Foundation

/// Metadata fetched from social platforms via oembed APIs
public struct SocialMetadata: Codable {
    public let platform: SocialPlatform
    public let creatorUsername: String?
    public let creatorDisplayName: String?
    public let title: String?
    public let thumbnailURL: URL?
    public let fetchedAt: Date

    public init(platform: SocialPlatform, creatorUsername: String?, creatorDisplayName: String?, title: String?, thumbnailURL: URL?, fetchedAt: Date) {
        self.platform = platform
        self.creatorUsername = creatorUsername
        self.creatorDisplayName = creatorDisplayName
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.fetchedAt = fetchedAt
    }
}

actor SocialMetadataService {

    private let urlSession: URLSession
    private var cache: [URL: (metadata: SocialMetadata, timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 3600 // 1 hour

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    /// Fetch metadata for a detected platform URL
    func fetchMetadata(for platformInfo: DetectedPlatformInfo) async throws -> SocialMetadata {
        // Check cache
        if let cached = cache[platformInfo.originalURL],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.metadata
        }

        let metadata: SocialMetadata

        switch platformInfo.platform {
        case .tiktok:
            metadata = try await fetchTikTokMetadata(platformInfo)
        case .instagram:
            metadata = try await fetchInstagramMetadata(platformInfo)
        case .youtube:
            metadata = try await fetchYouTubeMetadata(platformInfo)
        case .facebook:
            metadata = try await fetchFacebookMetadata(platformInfo)
        case .pinterest, .unknown:
            metadata = try await fetchGenericMetadata(platformInfo)
        }

        cache[platformInfo.originalURL] = (metadata, Date())
        return metadata
    }

    // MARK: - TikTok

    private func fetchTikTokMetadata(_ info: DetectedPlatformInfo) async throws -> SocialMetadata {
        let encodedURL = info.originalURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let oembedURL = URL(string: "https://www.tiktok.com/oembed?url=\(encodedURL)")!

        let (data, _) = try await urlSession.data(from: oembedURL)
        let response = try JSONDecoder().decode(TikTokOembedResponse.self, from: data)

        return SocialMetadata(
            platform: .tiktok,
            creatorUsername: response.authorName,
            creatorDisplayName: response.authorName,
            title: response.title,
            thumbnailURL: URL(string: response.thumbnailUrl ?? ""),
            fetchedAt: Date()
        )
    }

    // MARK: - Instagram

    private func fetchInstagramMetadata(_ info: DetectedPlatformInfo) async throws -> SocialMetadata {
        // Instagram oembed is limited and often blocked
        let encodedURL = info.originalURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let oembedURL = URL(string: "https://api.instagram.com/oembed?url=\(encodedURL)")!

        do {
            let (data, _) = try await urlSession.data(from: oembedURL)
            let response = try JSONDecoder().decode(InstagramOembedResponse.self, from: data)

            return SocialMetadata(
                platform: .instagram,
                creatorUsername: response.authorName,
                creatorDisplayName: response.authorName,
                title: response.title,
                thumbnailURL: URL(string: response.thumbnailUrl ?? ""),
                fetchedAt: Date()
            )
        } catch {
            // Fallback to URL-extracted info
            return SocialMetadata(
                platform: .instagram,
                creatorUsername: info.extractedUsername,
                creatorDisplayName: nil,
                title: nil,
                thumbnailURL: nil,
                fetchedAt: Date()
            )
        }
    }

    // MARK: - YouTube

    private func fetchYouTubeMetadata(_ info: DetectedPlatformInfo) async throws -> SocialMetadata {
        let encodedURL = info.originalURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let oembedURL = URL(string: "https://www.youtube.com/oembed?url=\(encodedURL)&format=json")!

        let (data, _) = try await urlSession.data(from: oembedURL)
        let response = try JSONDecoder().decode(YouTubeOembedResponse.self, from: data)

        return SocialMetadata(
            platform: .youtube,
            creatorUsername: nil,
            creatorDisplayName: response.authorName,
            title: response.title,
            thumbnailURL: URL(string: response.thumbnailUrl ?? ""),
            fetchedAt: Date()
        )
    }

    // MARK: - Facebook

    private func fetchFacebookMetadata(_ info: DetectedPlatformInfo) async throws -> SocialMetadata {
        // Facebook oembed is very limited
        return SocialMetadata(
            platform: .facebook,
            creatorUsername: nil,
            creatorDisplayName: nil,
            title: nil,
            thumbnailURL: nil,
            fetchedAt: Date()
        )
    }

    // MARK: - Generic Fallback

    private func fetchGenericMetadata(_ info: DetectedPlatformInfo) async throws -> SocialMetadata {
        return SocialMetadata(
            platform: .unknown,
            creatorUsername: info.extractedUsername,
            creatorDisplayName: nil,
            title: nil,
            thumbnailURL: nil,
            fetchedAt: Date()
        )
    }
}

// MARK: - Oembed Response Models

private struct TikTokOembedResponse: Codable {
    let title: String?
    let authorName: String
    let authorUrl: String?
    let thumbnailUrl: String?

    enum CodingKeys: String, CodingKey {
        case title
        case authorName = "author_name"
        case authorUrl = "author_url"
        case thumbnailUrl = "thumbnail_url"
    }
}

private struct InstagramOembedResponse: Codable {
    let title: String?
    let authorName: String?
    let thumbnailUrl: String?

    enum CodingKeys: String, CodingKey {
        case title
        case authorName = "author_name"
        case thumbnailUrl = "thumbnail_url"
    }
}

private struct YouTubeOembedResponse: Codable {
    let title: String
    let authorName: String
    let authorUrl: String?
    let thumbnailUrl: String?

    enum CodingKeys: String, CodingKey {
        case title
        case authorName = "author_name"
        case authorUrl = "author_url"
        case thumbnailUrl = "thumbnail_url"
    }
}
