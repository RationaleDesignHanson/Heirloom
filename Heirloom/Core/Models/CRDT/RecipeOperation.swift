//
//  RecipeOperation.swift
//  Heirloom
//
//  Created by Claude on 12/31/25.
//

import Foundation
import SwiftData
import FirebaseFirestore

/// Represents a single CRDT operation on a recipe
/// Operations are append-only and form a causal history of all edits
@Model
final class RecipeOperation: Codable, Identifiable {
    // MARK: - Properties

    /// Unique operation ID
    var id: UUID

    /// Recipe this operation belongs to
    var recipeId: UUID

    /// Device/user that performed this operation
    var deviceId: String

    /// Vector clock at the time of this operation
    var vectorClock: VectorClock

    /// Timestamp when operation was created
    var timestamp: Date

    /// Type of operation
    var operationType: OperationType

    /// Field that was modified (e.g., "title", "ingredients[2]", "instructions")
    var fieldPath: String

    /// Value before the operation (for undo/conflict resolution)
    var oldValue: OperationValue?

    /// Value after the operation
    var newValue: OperationValue?

    /// Optional metadata (e.g., user name, device name)
    var metadata: [String: String]

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        recipeId: UUID,
        deviceId: String,
        vectorClock: VectorClock,
        timestamp: Date = Date(),
        operationType: OperationType,
        fieldPath: String,
        oldValue: OperationValue? = nil,
        newValue: OperationValue? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.recipeId = recipeId
        self.deviceId = deviceId
        self.vectorClock = vectorClock
        self.timestamp = timestamp
        self.operationType = operationType
        self.fieldPath = fieldPath
        self.oldValue = oldValue
        self.newValue = newValue
        self.metadata = metadata
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case recipeId
        case deviceId
        case vectorClock
        case timestamp
        case operationType
        case fieldPath
        case oldValue
        case newValue
        case metadata
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.recipeId = try container.decode(UUID.self, forKey: .recipeId)
        self.deviceId = try container.decode(String.self, forKey: .deviceId)
        self.vectorClock = try container.decode(VectorClock.self, forKey: .vectorClock)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.operationType = try container.decode(OperationType.self, forKey: .operationType)
        self.fieldPath = try container.decode(String.self, forKey: .fieldPath)
        self.oldValue = try container.decodeIfPresent(OperationValue.self, forKey: .oldValue)
        self.newValue = try container.decodeIfPresent(OperationValue.self, forKey: .newValue)
        self.metadata = try container.decode([String: String].self, forKey: .metadata)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(recipeId, forKey: .recipeId)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(vectorClock, forKey: .vectorClock)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(operationType, forKey: .operationType)
        try container.encode(fieldPath, forKey: .fieldPath)
        try container.encodeIfPresent(oldValue, forKey: .oldValue)
        try container.encodeIfPresent(newValue, forKey: .newValue)
        try container.encode(metadata, forKey: .metadata)
    }

    // MARK: - Operation Helpers

    /// Check if this operation conflicts with another
    func conflicts(with other: RecipeOperation) -> Bool {
        // Same field, different devices, concurrent vector clocks = conflict
        guard fieldPath == other.fieldPath else { return false }
        guard deviceId != other.deviceId else { return false }
        return vectorClock.isConcurrent(with: other.vectorClock)
    }

    /// Check if this operation causally depends on another
    func dependsOn(_ other: RecipeOperation) -> Bool {
        return other.vectorClock.happenedBefore(vectorClock)
    }

    /// Create a user-friendly description of this operation
    var displayDescription: String {
        let userName = metadata["userName"] ?? "Someone"

        switch operationType {
        case .create:
            return "\(userName) created the recipe"
        case .update:
            return "\(userName) edited \(fieldDisplayName)"
        case .delete:
            return "\(userName) deleted \(fieldDisplayName)"
        case .addIngredient:
            if let value = newValue?.stringValue {
                return "\(userName) added ingredient: \(value)"
            }
            return "\(userName) added an ingredient"
        case .addInstruction:
            return "\(userName) added an instruction"
        case .addCustomization:
            return "\(userName) added a customization"
        case .modifyCustomization:
            return "\(userName) modified a customization"
        case .deleteCustomization:
            return "\(userName) deleted a customization"
        case .reorderCustomizations:
            return "\(userName) reordered customizations"
        }
    }

    /// User-friendly field name (converts "ingredients[2]" to "an ingredient")
    private var fieldDisplayName: String {
        if fieldPath.starts(with: "ingredients") {
            return "an ingredient"
        } else if fieldPath.starts(with: "instructions") {
            return "an instruction"
        } else if fieldPath == "title" {
            return "the title"
        } else if fieldPath == "notes" {
            return "the notes"
        } else if fieldPath == "prepTime" {
            return "prep time"
        } else if fieldPath == "cookTime" {
            return "cook time"
        } else if fieldPath == "servings" {
            return "servings"
        } else {
            return fieldPath
        }
    }
}

// MARK: - Operation Type

enum OperationType: String, Codable {
    case create           // Recipe created
    case update           // Field updated
    case delete           // Field or entity deleted
    case addIngredient    // Ingredient added (special case for array operations)
    case addInstruction   // Instruction added (special case for array operations)

    // MARK: - Customization Operations
    case addCustomization      // Customization added to recipe card
    case modifyCustomization   // Customization modified (position, size, rotation, etc.)
    case deleteCustomization   // Customization soft-deleted
    case reorderCustomizations // Z-index reordering of multiple customizations
}

// MARK: - Operation Value

/// Type-safe wrapper for operation values (supports string, int, double, bool, array)
enum OperationValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case stringArray([String])
    case jsonData(Data)  // For complex objects like Customization
    case null

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "string":
            let value = try container.decode(String.self, forKey: .value)
            self = .string(value)
        case "int":
            let value = try container.decode(Int.self, forKey: .value)
            self = .int(value)
        case "double":
            let value = try container.decode(Double.self, forKey: .value)
            self = .double(value)
        case "bool":
            let value = try container.decode(Bool.self, forKey: .value)
            self = .bool(value)
        case "stringArray":
            let value = try container.decode([String].self, forKey: .value)
            self = .stringArray(value)
        case "jsonData":
            let value = try container.decode(Data.self, forKey: .value)
            self = .jsonData(value)
        case "null":
            self = .null
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown OperationValue type: \(type)"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .string(let value):
            try container.encode("string", forKey: .type)
            try container.encode(value, forKey: .value)
        case .int(let value):
            try container.encode("int", forKey: .type)
            try container.encode(value, forKey: .value)
        case .double(let value):
            try container.encode("double", forKey: .type)
            try container.encode(value, forKey: .value)
        case .bool(let value):
            try container.encode("bool", forKey: .type)
            try container.encode(value, forKey: .value)
        case .stringArray(let value):
            try container.encode("stringArray", forKey: .type)
            try container.encode(value, forKey: .value)
        case .jsonData(let value):
            try container.encode("jsonData", forKey: .type)
            try container.encode(value, forKey: .value)
        case .null:
            try container.encode("null", forKey: .type)
        }
    }

    // MARK: - Convenience Accessors

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        if case .double(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var stringArrayValue: [String]? {
        if case .stringArray(let value) = self { return value }
        return nil
    }

    var jsonDataValue: Data? {
        if case .jsonData(let value) = self { return value }
        return nil
    }
}

// MARK: - Firestore Serialization

extension RecipeOperation {
    /// Convert to Firestore-compatible dictionary
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": id.uuidString,
            "recipeId": recipeId.uuidString,
            "deviceId": deviceId,
            "vectorClock": vectorClock.toFirestoreData(),
            "timestamp": timestamp,
            "operationType": operationType.rawValue,
            "fieldPath": fieldPath,
            "metadata": metadata
        ]

        if let oldValue = oldValue {
            data["oldValue"] = oldValue.toFirestoreValue()
        }

        if let newValue = newValue {
            data["newValue"] = newValue.toFirestoreValue()
        }

        return data
    }

    /// Create from Firestore dictionary
    static func from(firestoreData: [String: Any]) -> RecipeOperation? {
        Log.debug("Parsing CRDT operation from Firestore", category: .crdt, metadata: ["keys": Array(firestoreData.keys).joined(separator: ", ")])

        guard let idString = firestoreData["id"] as? String else {
            Log.warning("Failed to parse CRDT operation: missing 'id'", category: .crdt)
            return nil
        }
        guard let id = UUID(uuidString: idString) else {
            Log.warning("Failed to parse CRDT operation: invalid UUID for 'id'", category: .crdt, metadata: ["id": idString])
            return nil
        }
        guard let recipeIdString = firestoreData["recipeId"] as? String else {
            Log.warning("Failed to parse CRDT operation: missing 'recipeId'", category: .crdt)
            return nil
        }
        guard let recipeId = UUID(uuidString: recipeIdString) else {
            Log.warning("Failed to parse CRDT operation: invalid UUID for 'recipeId'", category: .crdt, metadata: ["recipeId": recipeIdString])
            return nil
        }
        guard let deviceId = firestoreData["deviceId"] as? String else {
            Log.warning("Failed to parse CRDT operation: missing 'deviceId'", category: .crdt)
            return nil
        }
        guard let vectorClockData = firestoreData["vectorClock"] as? [String: Any] else {
            Log.warning("Failed to parse CRDT operation: missing 'vectorClock'", category: .crdt)
            return nil
        }
        guard let vectorClock = VectorClock.from(firestoreData: vectorClockData) else {
            Log.warning("Failed to parse CRDT operation: invalid vectorClock", category: .crdt)
            return nil
        }
        // Handle both Date and Timestamp types
        var timestamp: Date
        if let date = firestoreData["timestamp"] as? Date {
            timestamp = date
        } else if let firestoreTimestamp = firestoreData["timestamp"] as? Timestamp {
            timestamp = firestoreTimestamp.dateValue()
        } else {
            Log.warning("Failed to parse CRDT operation: missing or invalid 'timestamp'", category: .crdt)
            return nil
        }
        guard let operationTypeRaw = firestoreData["operationType"] as? String else {
            Log.warning("Failed to parse CRDT operation: missing 'operationType'", category: .crdt)
            return nil
        }
        guard let operationType = OperationType(rawValue: operationTypeRaw) else {
            Log.warning("Failed to parse CRDT operation: invalid operationType", category: .crdt, metadata: ["operationType": operationTypeRaw])
            return nil
        }
        guard let fieldPath = firestoreData["fieldPath"] as? String else {
            Log.warning("Failed to parse CRDT operation: missing 'fieldPath'", category: .crdt)
            return nil
        }

        let metadata = firestoreData["metadata"] as? [String: String] ?? [:]
        let oldValue = OperationValue.from(firestoreValue: firestoreData["oldValue"])
        let newValue = OperationValue.from(firestoreValue: firestoreData["newValue"])

        Log.debug("Successfully parsed CRDT operation", category: .crdt, metadata: ["fieldPath": fieldPath])
        return RecipeOperation(
            id: id,
            recipeId: recipeId,
            deviceId: deviceId,
            vectorClock: vectorClock,
            timestamp: timestamp,
            operationType: operationType,
            fieldPath: fieldPath,
            oldValue: oldValue,
            newValue: newValue,
            metadata: metadata
        )
    }
}

extension OperationValue {
    func toFirestoreValue() -> Any {
        switch self {
        case .string(let value):
            return ["type": "string", "value": value]
        case .int(let value):
            return ["type": "int", "value": value]
        case .double(let value):
            return ["type": "double", "value": value]
        case .bool(let value):
            return ["type": "bool", "value": value]
        case .stringArray(let value):
            return ["type": "stringArray", "value": value]
        case .jsonData(let value):
            // Convert Data to base64 string for Firestore
            return ["type": "jsonData", "value": value.base64EncodedString()]
        case .null:
            return ["type": "null"]
        }
    }

    static func from(firestoreValue: Any?) -> OperationValue? {
        guard let dict = firestoreValue as? [String: Any],
              let type = dict["type"] as? String else {
            return nil
        }

        switch type {
        case "string":
            guard let value = dict["value"] as? String else { return nil }
            return .string(value)
        case "int":
            guard let value = dict["value"] as? Int else { return nil }
            return .int(value)
        case "double":
            guard let value = dict["value"] as? Double else { return nil }
            return .double(value)
        case "bool":
            guard let value = dict["value"] as? Bool else { return nil }
            return .bool(value)
        case "stringArray":
            guard let value = dict["value"] as? [String] else { return nil }
            return .stringArray(value)
        case "jsonData":
            guard let base64String = dict["value"] as? String,
                  let data = Data(base64Encoded: base64String) else { return nil }
            return .jsonData(data)
        case "null":
            return .null
        default:
            return nil
        }
    }
}
