import Foundation

/// AI service errors with detailed context
/// Adapted from Zero Inbox's structured error handling pattern:
/// Input Validation → Logging → Graceful Fallbacks
enum AIError: LocalizedError, CustomStringConvertible {
    // MARK: - Configuration Errors
    case notConfigured(provider: String)
    case invalidAPIKey(provider: String)
    case missingConfiguration(field: String)

    // MARK: - Network Errors
    case networkError(underlying: Error)
    case timeout(duration: TimeInterval)
    case rateLimited(retryAfter: TimeInterval?)
    case unauthorized

    // MARK: - API Errors
    case apiError(statusCode: Int, message: String?)
    case invalidRequest(reason: String)
    case invalidResponse(reason: String)
    case quotaExceeded(provider: String, limit: Int? = nil, resetDate: Date? = nil)

    // MARK: - Processing Errors
    case parsingFailed(reason: String)
    case jsonDecodingFailed(underlying: Error)
    case promptTooLong(tokens: Int, limit: Int)
    case unsupportedModel(model: String)

    // MARK: - LocalizedError Conformance

    var errorDescription: String? {
        switch self {
        case .notConfigured(let provider):
            return "\(provider) AI service is not configured. Please add API key in settings."

        case .invalidAPIKey(let provider):
            return "\(provider) API key is invalid. Please check your configuration."

        case .missingConfiguration(let field):
            return "Missing required configuration: \(field)"

        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"

        case .timeout(let duration):
            return "Request timed out after \(duration) seconds"

        case .rateLimited(let retryAfter):
            if let retry = retryAfter {
                return "Rate limit exceeded. Retry after \(Int(retry)) seconds."
            }
            return "Rate limit exceeded. Please try again later."

        case .unauthorized:
            return "Unauthorized. Please check your API key."

        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message ?? "Unknown error")"

        case .invalidRequest(let reason):
            return "Invalid request: \(reason)"

        case .invalidResponse(let reason):
            return "Invalid response: \(reason)"

        case .quotaExceeded(let provider, let limit, let resetDate):
            if let limit = limit, let resetDate = resetDate {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                let resetTime = formatter.string(from: resetDate)
                return "Daily limit of \(limit) recipes reached. Resets at \(resetTime). Add your own API key for unlimited usage."
            }
            return "\(provider) API quota exceeded. Please check your billing."

        case .parsingFailed(let reason):
            return "Failed to parse AI response: \(reason)"

        case .jsonDecodingFailed(let error):
            return "Failed to decode JSON: \(error.localizedDescription)"

        case .promptTooLong(let tokens, let limit):
            return "Prompt too long: \(tokens) tokens (limit: \(limit))"

        case .unsupportedModel(let model):
            return "Unsupported model: \(model)"
        }
    }

    var description: String {
        errorDescription ?? "Unknown AI error"
    }

    // MARK: - Error Context

    /// Get error context for logging (adapted from Zero's logging pattern)
    var context: [String: Any] {
        var ctx: [String: Any] = ["error_type": String(describing: self)]

        switch self {
        case .notConfigured(let provider),
             .invalidAPIKey(let provider):
            ctx["provider"] = provider

        case .quotaExceeded(let provider, let limit, let resetDate):
            ctx["provider"] = provider
            if let limit = limit {
                ctx["limit"] = limit
            }
            if let resetDate = resetDate {
                ctx["reset_date"] = resetDate
            }

        case .missingConfiguration(let field):
            ctx["field"] = field

        case .networkError(let error):
            ctx["underlying_error"] = error.localizedDescription

        case .timeout(let duration):
            ctx["duration"] = duration

        case .rateLimited(let retryAfter):
            if let retry = retryAfter {
                ctx["retry_after"] = retry
            }

        case .apiError(let statusCode, let message):
            ctx["status_code"] = statusCode
            if let msg = message {
                ctx["message"] = msg
            }

        case .invalidRequest(let reason),
             .invalidResponse(let reason),
             .parsingFailed(let reason):
            ctx["reason"] = reason

        case .jsonDecodingFailed(let error):
            ctx["underlying_error"] = error.localizedDescription

        case .promptTooLong(let tokens, let limit):
            ctx["tokens"] = tokens
            ctx["limit"] = limit

        case .unsupportedModel(let model):
            ctx["model"] = model

        case .unauthorized:
            break
        }

        return ctx
    }

    // MARK: - Retry Logic (Zero's Pattern)

    /// Determine if this error is retryable
    var isRetryable: Bool {
        switch self {
        case .networkError, .timeout, .rateLimited:
            return true
        case .apiError(let statusCode, _):
            // Retry on 5xx server errors
            return statusCode >= 500
        default:
            return false
        }
    }

    /// Get recommended retry delay (exponential backoff)
    func retryDelay(attempt: Int) -> TimeInterval {
        switch self {
        case .rateLimited(let retryAfter):
            return retryAfter ?? pow(2.0, Double(attempt))
        default:
            return min(pow(2.0, Double(attempt)), 60) // Max 60 seconds
        }
    }
}

// MARK: - Error Recovery Extensions

extension AIError {
    /// Convert to user-friendly message
    var userMessage: String {
        switch self {
        case .notConfigured:
            return "AI features are not set up yet. Enable them in Settings."
        case .networkError, .timeout:
            return "Network connection issue. Please try again."
        case .rateLimited:
            return "Too many requests. Please wait a moment."
        case .quotaExceeded(_, let limit, _):
            if let limit = limit {
                return "Daily limit of \(limit) recipes reached. Add your own API key in Settings for unlimited usage."
            }
            return "AI service limit reached. Add your own API key in Settings."
        default:
            return "Something went wrong. Using standard parsing instead."
        }
    }

    /// Should this error be shown to the user?
    var shouldShowToUser: Bool {
        switch self {
        case .notConfigured, .quotaExceeded:
            return true
        case .networkError, .timeout, .rateLimited:
            return true
        case .unauthorized, .invalidAPIKey:
            return true // CRITICAL: Show API key issues to user
        default:
            return false // Log only, don't interrupt user
        }
    }

    /// Should the app attempt to fall back to the default API key?
    var shouldFallbackToDefaultKey: Bool {
        switch self {
        case .unauthorized, .invalidAPIKey:
            return true
        default:
            return false
        }
    }

    /// User-friendly message specifically for API key issues
    var apiKeyFixMessage: String? {
        switch self {
        case .unauthorized, .invalidAPIKey:
            return "Your personal API key appears to be invalid or expired. You can update it in Settings → AI Features, or remove it to use the shared key."
        default:
            return nil
        }
    }
}
