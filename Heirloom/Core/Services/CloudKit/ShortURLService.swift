//
//  ShortURLService.swift
//  Heirloom
//
//  Short URL service for universal links (future use)
//  Maps short URLs (heirloom.app/r/{id}) to CloudKit share URLs
//

import Foundation
import CloudKit

/// Service for creating and resolving short universal links
/// FUTURE USE: Currently using CloudKit share URLs directly
/// When ready to deploy universal links:
/// 1. Uncomment associated domains in Heirloom.entitlements
/// 2. Deploy backend service to heirloom.app
/// 3. Deploy apple-app-site-association file
/// 4. Implement createShortURL() and resolveShortURL() methods
@MainActor
final class ShortURLService {
    // MARK: - Singleton

    static let shared = ShortURLService()

    private init() {}

    // MARK: - Configuration

    /// Base URL for short links (future use)
    private let baseURL = "https://heirloom.app"

    /// Backend API endpoint (future use)
    private let apiEndpoint = "https://api.heirloom.app/v1/shares"

    // MARK: - Short URL Creation (Stub)

    /// Create a short URL from a CloudKit share URL
    /// FUTURE IMPLEMENTATION: Will call backend service to store mapping
    /// - Parameter ckShareURL: The CloudKit share URL to shorten
    /// - Returns: Short universal link (heirloom.app/r/{id})
    func createShortURL(from ckShareURL: URL) async throws -> URL {
        // STUB: Currently not implemented
        // When ready to implement:
        // 1. Generate unique short ID (e.g., nanoid or base62)
        // 2. Store mapping in backend database (short ID -> CK share URL)
        // 3. Return https://heirloom.app/r/{shortID}

        throw ShortURLError.notImplemented
    }

    /// Resolve a short URL to its CloudKit share URL
    /// FUTURE IMPLEMENTATION: Will call backend service to fetch mapping
    /// - Parameter shortURL: The short URL (heirloom.app/r/{id})
    /// - Returns: Original CloudKit share URL
    func resolveShortURL(_ shortURL: URL) async throws -> URL {
        // STUB: Currently not implemented
        // When ready to implement:
        // 1. Extract short ID from URL path
        // 2. Query backend database for mapping
        // 3. Return original CloudKit share URL

        throw ShortURLError.notImplemented
    }

    // MARK: - Migration Helper

    /// Check if a URL is a short URL (vs CloudKit URL)
    func isShortURL(_ url: URL) -> Bool {
        return url.host == "heirloom.app" || url.host == "www.heirloom.app"
    }

    /// Check if a URL is a CloudKit share URL
    func isCloudKitShareURL(_ url: URL) -> Bool {
        return url.host?.contains("icloud.com") == true
    }
}

// MARK: - Errors

enum ShortURLError: LocalizedError {
    case notImplemented
    case invalidShortURL
    case mappingNotFound
    case backendUnavailable

    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Short URL service is not yet implemented. Using CloudKit share URLs directly."
        case .invalidShortURL:
            return "Invalid short URL format"
        case .mappingNotFound:
            return "Could not find CloudKit share URL for this short URL"
        case .backendUnavailable:
            return "Short URL backend service is unavailable"
        }
    }
}

// MARK: - Migration Guide

/*
 MIGRATION GUIDE: CloudKit URLs → Universal Links

 ## Current State (Phase 1)
 - Using CloudKit share URLs directly (https://www.icloud.com/share/...)
 - URL scheme: heirloom://share/{base64-encoded-ck-url}
 - No backend service required
 - Works immediately

 ## Target State (Phase 2)
 - Using short universal links (https://heirloom.app/r/{shortID})
 - Prettier URLs, better for sharing
 - Requires backend service + apple-app-site-association file

 ## Migration Steps

 ### 1. Backend Service
 Deploy a backend service (e.g., Cloudflare Workers, Vercel, or AWS Lambda) that:
 - Stores short ID → CloudKit URL mappings in a database (e.g., KV store, DynamoDB)
 - Provides API endpoints:
   - POST /v1/shares → Create short URL, returns shortID
   - GET /v1/shares/{shortID} → Resolve to CloudKit URL
 - Handles expiration (match CKShare expiration)

 ### 2. Apple App Site Association
 Deploy this file to heirloom.app/.well-known/apple-app-site-association:
 ```json
 {
   "applinks": {
     "apps": [],
     "details": [
       {
         "appID": "TEAM_ID.com.matthanson.heirloom",
         "paths": ["/r/*"]
       }
     ]
   }
 }
 ```

 ### 3. App Configuration
 - Uncomment associated domains in Heirloom.entitlements
 - Implement createShortURL() and resolveShortURL() in ShortURLService
 - Update RecipeShareService.generateShortLink() to use ShortURLService
 - Update DeepLinkHandler to resolve short URLs before processing

 ### 4. Testing
 - Verify apple-app-site-association is accessible via HTTPS
 - Test universal link opening from Safari, Messages, Notes
 - Test fallback to CloudKit URLs if short URL service fails
 - Test both new short URLs and old CloudKit URLs (backward compatibility)

 ### 5. Gradual Rollout
 - Continue supporting CloudKit URLs for existing shares
 - Generate short URLs for new shares only
 - Monitor backend service performance and costs
 - Add analytics to track short URL vs CloudKit URL usage

 ## Code Changes Required

 ### RecipeShareService.swift
 ```swift
 func generateShortLink(from share: CKShare) async throws -> URL {
     guard let ckURL = share.url else {
         throw ShareError.noShareURL
     }

     // Try to create short URL, fallback to CloudKit URL
     if let shortURL = try? await ShortURLService.shared.createShortURL(from: ckURL) {
         return shortURL
     }

     return ckURL // Fallback
 }
 ```

 ### DeepLinkHandler.swift
 ```swift
 private func handleUniversalLink(_ url: URL) {
     Task {
         // Resolve short URL to CloudKit URL
         let ckURL = try await ShortURLService.shared.resolveShortURL(url)
         handleCloudKitShareURL(ckURL)
     }
 }
 ```
 */
