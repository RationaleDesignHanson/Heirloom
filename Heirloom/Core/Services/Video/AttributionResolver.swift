import Foundation

enum AttributionResolver {

    /// Resolve final attribution from multiple sources
    static func resolve(
        urlPlatformInfo: DetectedPlatformInfo?,
        watermarkResult: WatermarkDetector.WatermarkResult?,
        socialMetadata: SocialMetadata?
    ) -> (sourceURL: String?, sourceAttribution: String?, platform: SocialPlatform?) {

        var sourceURL: String?
        var sourceAttribution: String?
        var platform: SocialPlatform?

        // Priority 1: URL metadata (most reliable)
        if let platformInfo = urlPlatformInfo {
            sourceURL = platformInfo.originalURL.absoluteString
            platform = platformInfo.platform

            if let username = platformInfo.extractedUsername {
                sourceAttribution = "@\(username)"
            }
        }

        // Priority 2: Social metadata from oEmbed APIs
        if let social = socialMetadata {
            if let creator = social.creatorUsername {
                sourceAttribution = "@\(creator)"
            } else if let displayName = social.creatorDisplayName, sourceAttribution == nil {
                sourceAttribution = displayName
            }

            if platform == nil {
                platform = social.platform
            }
        }

        // Priority 3: High-confidence watermark detection (>60%)
        if sourceAttribution == nil,
           let watermark = watermarkResult,
           let username = watermark.username,
           watermark.confidence >= 0.6 {
            sourceAttribution = "@\(username)"
            if platform == nil {
                platform = watermark.platform
            }
        }

        return (sourceURL, sourceAttribution, platform)
    }

    /// Create ProvenanceMetadata from resolved attribution
    static func createProvenanceMetadata(
        urlPlatformInfo: DetectedPlatformInfo?,
        watermarkResult: WatermarkDetector.WatermarkResult?,
        socialMetadata: SocialMetadata?
    ) -> ProvenanceMetadata {

        let resolved = resolve(
            urlPlatformInfo: urlPlatformInfo,
            watermarkResult: watermarkResult,
            socialMetadata: socialMetadata
        )

        return ProvenanceMetadata(
            sourceType: .video,
            sourceURL: resolved.sourceURL,
            sourceAttribution: resolved.sourceAttribution
        )
    }
}
