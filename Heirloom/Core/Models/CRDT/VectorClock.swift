//
//  VectorClock.swift
//  Heirloom
//
//  Created by Claude on 12/31/25.
//

import Foundation
import SwiftData
import FirebaseFirestore

/// Vector clock for tracking causal relationships between recipe edits across devices
/// Used to determine which changes happened before/after/concurrently with other changes
@Model
final class VectorClock: Codable {
    // MARK: - Properties

    /// Device/user ID → timestamp mapping
    /// Tracks the logical clock value for each device that has edited this recipe
    var clocks: [String: Int64]

    /// When this vector clock was last updated
    var lastUpdated: Date

    // MARK: - Initialization

    init(clocks: [String: Int64] = [:]) {
        self.clocks = clocks
        self.lastUpdated = Date()
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case clocks
        case lastUpdated
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.clocks = try container.decode([String: Int64].self, forKey: .clocks)
        self.lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(clocks, forKey: .clocks)
        try container.encode(lastUpdated, forKey: .lastUpdated)
    }

    // MARK: - Vector Clock Operations

    /// Increment the clock for the current device
    func increment(deviceId: String) {
        let currentValue = clocks[deviceId] ?? 0
        clocks[deviceId] = currentValue + 1
        lastUpdated = Date()
    }

    /// Get the clock value for a specific device
    func value(for deviceId: String) -> Int64 {
        return clocks[deviceId] ?? 0
    }

    /// Merge with another vector clock (take maximum of each device's clock)
    func merge(with other: VectorClock) {
        for (deviceId, timestamp) in other.clocks {
            let currentValue = clocks[deviceId] ?? 0
            clocks[deviceId] = max(currentValue, timestamp)
        }
        lastUpdated = Date()
    }

    /// Determine causal relationship with another vector clock
    func compare(with other: VectorClock) -> ClockComparison {
        var thisGreater = false
        var otherGreater = false

        // Collect all device IDs from both clocks
        let allDeviceIds = Set(clocks.keys).union(Set(other.clocks.keys))

        for deviceId in allDeviceIds {
            let thisValue = clocks[deviceId] ?? 0
            let otherValue = other.clocks[deviceId] ?? 0

            if thisValue > otherValue {
                thisGreater = true
            } else if otherValue > thisValue {
                otherGreater = true
            }
        }

        if thisGreater && !otherGreater {
            return .after  // This clock is strictly after (causally later than) other
        } else if otherGreater && !thisGreater {
            return .before  // This clock is strictly before (causally earlier than) other
        } else if thisGreater && otherGreater {
            return .concurrent  // Clocks are concurrent (neither causally before/after)
        } else {
            return .equal  // Clocks are identical
        }
    }

    /// Check if this clock happened before another (causally precedes)
    func happenedBefore(_ other: VectorClock) -> Bool {
        return compare(with: other) == .before
    }

    /// Check if this clock is concurrent with another (neither causally before/after)
    func isConcurrent(with other: VectorClock) -> Bool {
        return compare(with: other) == .concurrent
    }

    /// Create a copy of this vector clock
    func copy() -> VectorClock {
        return VectorClock(clocks: self.clocks)
    }
}

// MARK: - Clock Comparison Result

enum ClockComparison {
    case before     // This clock causally precedes the other
    case after      // This clock causally follows the other
    case concurrent // Clocks are concurrent (conflict possible)
    case equal      // Clocks are identical
}

// MARK: - Firestore Serialization

extension VectorClock {
    /// Convert to Firestore-compatible dictionary
    func toFirestoreData() -> [String: Any] {
        return [
            "clocks": clocks,
            "lastUpdated": lastUpdated
        ]
    }

    /// Create from Firestore dictionary
    static func from(firestoreData: [String: Any]) -> VectorClock? {
        Log.debug("Parsing VectorClock from Firestore", category: .crdt)

        // Firestore returns numbers as Int, not Int64, so we need to convert
        guard let clocksDataAny = firestoreData["clocks"] as? [String: Any] else {
            Log.warning("Failed to parse VectorClock: missing or invalid 'clocks' field", category: .crdt)
            return nil
        }

        // Convert Int to Int64
        var clocksData: [String: Int64] = [:]
        for (key, value) in clocksDataAny {
            if let intValue = value as? Int {
                clocksData[key] = Int64(intValue)
            } else if let int64Value = value as? Int64 {
                clocksData[key] = int64Value
            } else {
                Log.warning("Invalid value type in VectorClock", category: .crdt, metadata: ["key": key])
                return nil
            }
        }

        // Handle both Date and Timestamp types
        var lastUpdated: Date
        if let date = firestoreData["lastUpdated"] as? Date {
            lastUpdated = date
        } else if let timestamp = firestoreData["lastUpdated"] as? Timestamp {
            lastUpdated = timestamp.dateValue()
        } else {
            Log.warning("Failed to parse VectorClock: missing or invalid 'lastUpdated' field", category: .crdt)
            return nil
        }

        let clock = VectorClock(clocks: clocksData)
        clock.lastUpdated = lastUpdated
        Log.debug("Successfully parsed VectorClock", category: .crdt, metadata: ["entryCount": clocksData.count])
        return clock
    }
}

// MARK: - CustomStringConvertible

extension VectorClock: CustomStringConvertible {
    var description: String {
        let clockStrings = clocks.map { "\($0): \($1)" }.sorted().joined(separator: ", ")
        return "VectorClock(\(clockStrings))"
    }
}

// MARK: - Equatable

extension VectorClock: Equatable {
    static func == (lhs: VectorClock, rhs: VectorClock) -> Bool {
        return lhs.clocks == rhs.clocks
    }
}
