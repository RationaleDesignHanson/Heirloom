import Foundation

/// Mock URLSession for testing network requests without real HTTP calls
/// Allows tests to simulate success, failure, and various HTTP status codes
class MockURLSession {

    // MARK: - Mock Configuration

    /// The data to return from the request
    var dataToReturn: Data?

    /// The HTTP response to return
    var responseToReturn: HTTPURLResponse?

    /// The error to throw
    var errorToThrow: Error?

    /// Delay before returning (simulates network latency)
    var delayInSeconds: TimeInterval = 0

    /// Track the last request made
    var lastRequest: URLRequest?

    /// Track all requests made
    var requestHistory: [URLRequest] = []

    /// Call count
    var callCount: Int = 0

    // MARK: - URLSession Simulation

    /// Simulate URLSession.data(for:) method
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        callCount += 1
        lastRequest = request
        requestHistory.append(request)

        // Simulate network delay if configured
        if delayInSeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delayInSeconds * 1_000_000_000))
        }

        // Throw error if configured
        if let error = errorToThrow {
            throw error
        }

        // Return mocked data and response
        let data = dataToReturn ?? Data()
        let response = responseToReturn ?? HTTPURLResponse(
            url: request.url ?? URL(string: "https://api.anthropic.com")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!

        return (data, response)
    }

    // MARK: - Test Helpers

    /// Reset all mock state
    func reset() {
        dataToReturn = nil
        responseToReturn = nil
        errorToThrow = nil
        delayInSeconds = 0
        lastRequest = nil
        requestHistory.removeAll()
        callCount = 0
    }

    /// Configure mock to return successful response
    func mockSuccess(
        data: Data,
        statusCode: Int = 200,
        headers: [String: String]? = ["Content-Type": "application/json"]
    ) {
        dataToReturn = data
        errorToThrow = nil

        responseToReturn = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )
    }

    /// Configure mock to return error response
    func mockError(
        statusCode: Int,
        data: Data? = nil,
        headers: [String: String]? = nil
    ) {
        dataToReturn = data ?? Data()
        errorToThrow = nil

        responseToReturn = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )
    }

    /// Configure mock to throw network error
    func mockNetworkError(_ error: Error = URLError(.notConnectedToInternet)) {
        errorToThrow = error
        dataToReturn = nil
        responseToReturn = nil
    }

    /// Verify that a specific header was sent
    func verifyHeader(name: String, value: String) -> Bool {
        guard let request = lastRequest,
              let headers = request.allHTTPHeaderFields,
              let actualValue = headers[name] else {
            print("❌ Header '\(name)' not found in request")
            return false
        }

        if actualValue != value {
            print("❌ Header '\(name)' expected '\(value)', got '\(actualValue)'")
            return false
        }

        return true
    }

    /// Verify that request body contains specific JSON field
    func verifyJSONBody(contains key: String) -> Bool {
        guard let request = lastRequest,
              let body = request.httpBody,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            print("❌ Could not parse request body as JSON")
            return false
        }

        if json[key] == nil {
            print("❌ JSON body does not contain key '\(key)'")
            print("Actual keys: \(json.keys.joined(separator: ", "))")
            return false
        }

        return true
    }
}
