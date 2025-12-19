import Foundation
@testable import Heirloom

/// Mock AnalyticsService for testing event tracking
/// Captures all tracked events for verification in tests
class MockAnalyticsService {

    // MARK: - Tracked Data

    /// All events that were tracked
    var trackedEvents: [(event: AnalyticsEvent, properties: [String: Any])] = []

    /// Count of events tracked
    var eventCount: Int {
        return trackedEvents.count
    }

    /// The most recent event tracked
    var lastEvent: (event: AnalyticsEvent, properties: [String: Any])? {
        return trackedEvents.last
    }

    // MARK: - Track Events

    /// Track an analytics event (mimics AnalyticsService.track)
    func track(event: AnalyticsEvent, properties: [String: Any] = [:]) {
        trackedEvents.append((event, properties))
    }

    // MARK: - Query Methods

    /// Check if a specific event was tracked
    func wasEventTracked(_ event: AnalyticsEvent) -> Bool {
        return trackedEvents.contains { $0.event == event }
    }

    /// Get all occurrences of a specific event
    func getEvents(_ event: AnalyticsEvent) -> [(event: AnalyticsEvent, properties: [String: Any])] {
        return trackedEvents.filter { $0.event == event }
    }

    /// Get count of a specific event
    func getEventCount(_ event: AnalyticsEvent) -> Int {
        return trackedEvents.filter { $0.event == event }.count
    }

    /// Check if an event was tracked with specific properties
    func wasEventTracked(
        _ event: AnalyticsEvent,
        withProperty key: String,
        value: Any? = nil
    ) -> Bool {
        return trackedEvents.contains { tracked in
            guard tracked.event == event else { return false }

            // Check if property exists
            guard tracked.properties[key] != nil else { return false }

            // If value specified, check if it matches
            if let expectedValue = value {
                guard let actualValue = tracked.properties[key] else { return false }

                // Compare values (handle different types)
                if let expectedString = expectedValue as? String,
                   let actualString = actualValue as? String {
                    return expectedString == actualString
                }
                if let expectedInt = expectedValue as? Int,
                   let actualInt = actualValue as? Int {
                    return expectedInt == actualInt
                }
                if let expectedBool = expectedValue as? Bool,
                   let actualBool = actualValue as? Bool {
                    return expectedBool == actualBool
                }
                if let expectedDouble = expectedValue as? Double,
                   let actualDouble = actualValue as? Double {
                    return abs(expectedDouble - actualDouble) < 0.001
                }

                // Generic comparison for other types
                return String(describing: actualValue) == String(describing: expectedValue)
            }

            return true
        }
    }

    /// Get properties from the last event of a specific type
    func getPropertiesForLastEvent(_ event: AnalyticsEvent) -> [String: Any]? {
        return trackedEvents.last(where: { $0.event == event })?.properties
    }

    // MARK: - Test Helpers

    /// Reset all tracked events
    func reset() {
        trackedEvents.removeAll()
    }

    /// Print all tracked events (for debugging)
    func dump() {
        print("MockAnalyticsService tracked events (\(eventCount)):")
        for (index, tracked) in trackedEvents.enumerated() {
            print("  [\(index + 1)] \(tracked.event.rawValue)")
            if !tracked.properties.isEmpty {
                print("      Properties: \(tracked.properties)")
            }
        }
    }

    /// Verify event sequence (events in specific order)
    func verifySequence(_ expectedEvents: [AnalyticsEvent]) -> Bool {
        guard trackedEvents.count >= expectedEvents.count else {
            print("❌ Expected at least \(expectedEvents.count) events, got \(trackedEvents.count)")
            return false
        }

        for (index, expectedEvent) in expectedEvents.enumerated() {
            if index >= trackedEvents.count {
                print("❌ Event sequence mismatch at index \(index)")
                return false
            }

            if trackedEvents[index].event != expectedEvent {
                print("❌ Expected '\(expectedEvent.rawValue)' at index \(index), got '\(trackedEvents[index].event.rawValue)'")
                return false
            }
        }

        return true
    }

    /// Verify that exactly N events of a type were tracked
    func verifyEventCount(_ event: AnalyticsEvent, count: Int) -> Bool {
        let actualCount = getEventCount(event)
        if actualCount != count {
            print("❌ Expected \(count) '\(event.rawValue)' events, got \(actualCount)")
            return false
        }
        return true
    }
}

// MARK: - Convenience Extensions

extension MockAnalyticsService {

    /// Quick check for AI success events
    var aiParseSuccessCount: Int {
        return getEventCount(.aiIngredientParseSuccess)
    }

    /// Quick check for AI failure events
    var aiParseFailureCount: Int {
        return getEventCount(.aiIngredientParseFailed)
    }

    /// Quick check for AI token usage events
    var aiTokenUsageCount: Int {
        return getEventCount(.aiTokensUsed)
    }

    /// Quick check for AI enhancement events
    var aiEnhancementSuccessCount: Int {
        return getEventCount(.aiEnhancementSuccess)
    }

    /// Quick check if any AI events were tracked
    var hasAnyAIEvents: Bool {
        return trackedEvents.contains { event in
            let eventName = event.event.rawValue
            return eventName.contains("AI") || eventName.contains("ai")
        }
    }
}
