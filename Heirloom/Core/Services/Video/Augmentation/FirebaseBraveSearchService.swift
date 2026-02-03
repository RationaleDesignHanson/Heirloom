import Foundation
import FirebaseFunctions

/// Firebase-based Brave Search service
/// Proxies web recipe searches through Cloud Functions - API keys stay server-side
@MainActor
class FirebaseBraveSearchService {

    // MARK: - Properties

    private let functions: Functions

    // MARK: - Initialization

    init(functions: Functions? = nil) {
        self.functions = functions ?? Functions.functions()

        #if DEBUG
        // Use local emulator in debug mode if needed
        // self.functions.useEmulator(withHost: "localhost", port: 5001)
        #endif

        Log.info("Firebase Brave Search Service initialized", category: .network)
    }

    // MARK: - Search Methods

    /// Search web for recipes using Brave Search API via Firebase gateway
    /// - Parameters:
    ///   - query: Search query string
    ///   - count: Number of results to return (default: 10, max: 20)
    /// - Returns: Array of search results
    func search(query: String, count: Int = 10) async throws -> [BraveSearchResult] {
        guard !query.isEmpty else {
            throw BraveSearchError.invalidQuery
        }

        guard count > 0 && count <= 20 else {
            throw BraveSearchError.invalidCount
        }

        Log.debug("Calling braveSearch", category: .network, metadata: [
            "query": query,
            "count": count
        ])

        // Build request
        let data: [String: Any] = [
            "query": query,
            "count": count
        ]

        do {
            // Call Firebase Function
            let result = try await functions.httpsCallable("braveSearch").call(data)

            guard let response = result.data as? [String: Any] else {
                throw BraveSearchError.invalidResponse
            }

            // Parse response
            guard let resultsArray = response["results"] as? [[String: Any]] else {
                // Empty results is ok
                if let results = response["results"] as? [[String: Any]], results.isEmpty {
                    return []
                }
                throw BraveSearchError.invalidResponse
            }

            let searchResults = resultsArray.compactMap { resultDict -> BraveSearchResult? in
                guard let title = resultDict["title"] as? String,
                      let url = resultDict["url"] as? String else {
                    return nil
                }

                let description = resultDict["description"] as? String
                let age = resultDict["age"] as? String
                let language = resultDict["language"] as? String

                return BraveSearchResult(
                    title: title,
                    url: url,
                    description: description,
                    age: age,
                    language: language
                )
            }

            Log.info("Brave search complete", category: .network, metadata: [
                "resultCount": searchResults.count
            ])

            return searchResults

        } catch let error as NSError where error.domain == FunctionsErrorDomain {
            // Handle Firebase Function errors
            let code = FunctionsErrorCode(rawValue: error.code)

            switch code {
            case .unauthenticated:
                throw BraveSearchError.authenticationRequired
            case .resourceExhausted:
                throw BraveSearchError.rateLimitExceeded
            case .invalidArgument:
                throw BraveSearchError.invalidQuery
            default:
                Log.error("Brave Search API error", category: .network, error: error)
                throw BraveSearchError.apiError(error.localizedDescription)
            }
        } catch let error as BraveSearchError {
            throw error
        } catch {
            Log.error("Unexpected Brave Search error", category: .network, error: error)
            throw BraveSearchError.networkError(error)
        }
    }
}

// MARK: - Result Models

struct BraveSearchResult {
    let title: String
    let url: String
    let description: String?
    let age: String?
    let language: String?
}

// MARK: - Error Types

enum BraveSearchError: LocalizedError {
    case invalidQuery
    case invalidCount
    case invalidResponse
    case authenticationRequired
    case rateLimitExceeded
    case apiError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Invalid search query"
        case .invalidCount:
            return "Invalid result count (must be 1-20)"
        case .invalidResponse:
            return "Invalid response from Brave Search API"
        case .authenticationRequired:
            return "Authentication required to use search"
        case .rateLimitExceeded:
            return "Search rate limit exceeded. Please try again later."
        case .apiError(let message):
            return "Brave Search API error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
