//
//  Customization.swift
//  Heirloom
//
//  Created by Claude on 1/5/26.
//

import Foundation
import SwiftData
import SwiftUI

/// Represents a single customization on a recipe card (sticker, drawing, text, etc.)
/// Supports CRDT sync for multi-device collaboration
@Model
final class Customization {
    // MARK: - Identity

    /// Unique customization ID
    var id: UUID

    /// Recipe this customization belongs to
    var recipeId: UUID

    /// Device that created this customization
    var deviceId: String

    /// User that created this customization
    var userId: String

    // MARK: - Type

    /// Type of customization
    var typeRawValue: String

    /// Computed property for type
    var type: CustomizationType {
        get { CustomizationType(rawValue: typeRawValue) ?? .sticker }
        set { typeRawValue = newValue.rawValue }
    }

    // MARK: - Positioning

    /// Position relative to card (0-1 normalized coordinates)
    var positionX: Double
    var positionY: Double

    var position: CGPoint {
        get { CGPoint(x: positionX, y: positionY) }
        set {
            positionX = newValue.x
            positionY = newValue.y
        }
    }

    /// Size relative to card (0-1 normalized)
    var sizeWidth: Double
    var sizeHeight: Double

    var size: CGSize {
        get { CGSize(width: sizeWidth, height: sizeHeight) }
        set {
            sizeWidth = newValue.width
            sizeHeight = newValue.height
        }
    }

    /// Rotation in radians
    var rotation: Double

    /// Layer order (higher = rendered on top)
    var zIndex: Int

    // MARK: - Content

    /// Serialized JSON content
    var contentJSON: Data

    /// Computed property for content
    var content: CustomizationContent {
        get {
            guard let decoded = try? JSONDecoder().decode(CustomizationContent.self, from: contentJSON) else {
                return .sticker(assetId: "", tintColor: nil)
            }
            return decoded
        }
        set {
            guard let encoded = try? JSONEncoder().encode(newValue) else { return }
            contentJSON = encoded
        }
    }

    // MARK: - Metadata

    var createdAt: Date
    var modifiedAt: Date

    /// Soft delete for CRDT (never actually delete, just mark as deleted)
    var isDeleted: Bool

    // MARK: - CRDT

    /// Vector clock for causal ordering
    var vectorClock: VectorClock

    /// Lamport timestamp for total ordering
    var lamportTimestamp: Int64

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        recipeId: UUID,
        deviceId: String,
        userId: String,
        type: CustomizationType,
        position: CGPoint,
        size: CGSize,
        rotation: Double = 0,
        zIndex: Int,
        content: CustomizationContent,
        vectorClock: VectorClock
    ) {
        self.id = id
        self.recipeId = recipeId
        self.deviceId = deviceId
        self.userId = userId
        self.typeRawValue = type.rawValue
        self.positionX = position.x
        self.positionY = position.y
        self.sizeWidth = size.width
        self.sizeHeight = size.height
        self.rotation = rotation
        self.zIndex = zIndex

        // Encode content
        self.contentJSON = (try? JSONEncoder().encode(content)) ?? Data()

        self.createdAt = Date()
        self.modifiedAt = Date()
        self.isDeleted = false
        self.vectorClock = vectorClock
        self.lamportTimestamp = vectorClock.clocks.values.max() ?? 0
    }
}

// MARK: - Customization Type

enum CustomizationType: String, Codable {
    case sticker           // Pre-made sticker asset
    case drawing           // Freehand drawing/doodle
    case text              // Text annotation
    case photo             // User photo overlay
    case shape             // Basic shapes (heart, star, etc.)
}

// MARK: - Customization Content

enum CustomizationContent: Codable, Equatable {
    case sticker(assetId: String, tintColor: String?)
    case drawing(path: DrawingPath, strokeColor: String, strokeWidth: Double)
    case text(content: String, font: String, fontSize: Double, color: String)
    case photo(imageId: UUID, opacity: Double)
    case shape(shapeType: ShapeType, fillColor: String, strokeColor: String)

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type
        case assetId, tintColor
        case path, strokeColor, strokeWidth
        case content, font, fontSize, color
        case imageId, opacity
        case shapeType, fillColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "sticker":
            let assetId = try container.decode(String.self, forKey: .assetId)
            let tintColor = try container.decodeIfPresent(String.self, forKey: .tintColor)
            self = .sticker(assetId: assetId, tintColor: tintColor)

        case "drawing":
            let path = try container.decode(DrawingPath.self, forKey: .path)
            let strokeColor = try container.decode(String.self, forKey: .strokeColor)
            let strokeWidth = try container.decode(Double.self, forKey: .strokeWidth)
            self = .drawing(path: path, strokeColor: strokeColor, strokeWidth: strokeWidth)

        case "text":
            let content = try container.decode(String.self, forKey: .content)
            let font = try container.decode(String.self, forKey: .font)
            let fontSize = try container.decode(Double.self, forKey: .fontSize)
            let color = try container.decode(String.self, forKey: .color)
            self = .text(content: content, font: font, fontSize: fontSize, color: color)

        case "photo":
            let imageId = try container.decode(UUID.self, forKey: .imageId)
            let opacity = try container.decode(Double.self, forKey: .opacity)
            self = .photo(imageId: imageId, opacity: opacity)

        case "shape":
            let shapeType = try container.decode(ShapeType.self, forKey: .shapeType)
            let fillColor = try container.decode(String.self, forKey: .fillColor)
            let strokeColor = try container.decode(String.self, forKey: .strokeColor)
            self = .shape(shapeType: shapeType, fillColor: fillColor, strokeColor: strokeColor)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown customization content type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .sticker(let assetId, let tintColor):
            try container.encode("sticker", forKey: .type)
            try container.encode(assetId, forKey: .assetId)
            try container.encodeIfPresent(tintColor, forKey: .tintColor)

        case .drawing(let path, let strokeColor, let strokeWidth):
            try container.encode("drawing", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(strokeColor, forKey: .strokeColor)
            try container.encode(strokeWidth, forKey: .strokeWidth)

        case .text(let content, let font, let fontSize, let color):
            try container.encode("text", forKey: .type)
            try container.encode(content, forKey: .content)
            try container.encode(font, forKey: .font)
            try container.encode(fontSize, forKey: .fontSize)
            try container.encode(color, forKey: .color)

        case .photo(let imageId, let opacity):
            try container.encode("photo", forKey: .type)
            try container.encode(imageId, forKey: .imageId)
            try container.encode(opacity, forKey: .opacity)

        case .shape(let shapeType, let fillColor, let strokeColor):
            try container.encode("shape", forKey: .type)
            try container.encode(shapeType, forKey: .shapeType)
            try container.encode(fillColor, forKey: .fillColor)
            try container.encode(strokeColor, forKey: .strokeColor)
        }
    }
}

// MARK: - Drawing Path

struct DrawingPath: Codable, Equatable {
    var points: [CGPointCodable]
    var smoothed: Bool

    init(points: [CGPoint], smoothed: Bool = false) {
        self.points = points.map { CGPointCodable(point: $0) }
        self.smoothed = smoothed
    }

    /// Convert to actual CGPoint array
    var cgPoints: [CGPoint] {
        points.map { $0.cgPoint }
    }

    /// SVG-like path for resolution independence
    var svgPath: String {
        guard !points.isEmpty else { return "" }

        var path = "M \(points[0].x),\(points[0].y)"

        for point in points.dropFirst() {
            path += " L \(point.x),\(point.y)"
        }

        return path
    }
}

// MARK: - CGPoint Codable Wrapper

struct CGPointCodable: Codable, Equatable {
    var x: Double
    var y: Double

    init(point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }

    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

// MARK: - Shape Type

enum ShapeType: String, Codable {
    case heart
    case star
    case circle
    case rectangle
    case arrow
}

// MARK: - Customization Changes

struct CustomizationChanges: Codable {
    var position: CGPointCodable?
    var size: CGSizeCodable?
    var rotation: Double?
    var zIndex: Int?
    var content: CustomizationContent?
}

// MARK: - CGSize Codable Wrapper

struct CGSizeCodable: Codable {
    var width: Double
    var height: Double

    init(size: CGSize) {
        self.width = size.width
        self.height = size.height
    }

    var cgSize: CGSize {
        CGSize(width: width, height: height)
    }
}

// MARK: - Firestore Serialization

extension Customization {
    /// Convert to Firestore-compatible dictionary
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": id.uuidString,
            "recipeId": recipeId.uuidString,
            "deviceId": deviceId,
            "userId": userId,
            "type": typeRawValue,
            "positionX": positionX,
            "positionY": positionY,
            "sizeWidth": sizeWidth,
            "sizeHeight": sizeHeight,
            "rotation": rotation,
            "zIndex": zIndex,
            "createdAt": createdAt,
            "modifiedAt": modifiedAt,
            "isDeleted": isDeleted,
            "vectorClock": vectorClock.toFirestoreData(),
            "lamportTimestamp": lamportTimestamp
        ]

        // Serialize content as JSON string
        if let contentString = String(data: contentJSON, encoding: .utf8) {
            data["contentJSON"] = contentString
        }

        return data
    }

    /// Create from Firestore dictionary
    static func from(firestoreData: [String: Any], vectorClock: VectorClock) -> Customization? {
        guard
            let idString = firestoreData["id"] as? String,
            let id = UUID(uuidString: idString),
            let recipeIdString = firestoreData["recipeId"] as? String,
            let recipeId = UUID(uuidString: recipeIdString),
            let deviceId = firestoreData["deviceId"] as? String,
            let userId = firestoreData["userId"] as? String,
            let typeRawValue = firestoreData["type"] as? String,
            let type = CustomizationType(rawValue: typeRawValue),
            let positionX = firestoreData["positionX"] as? Double,
            let positionY = firestoreData["positionY"] as? Double,
            let sizeWidth = firestoreData["sizeWidth"] as? Double,
            let sizeHeight = firestoreData["sizeHeight"] as? Double,
            let rotation = firestoreData["rotation"] as? Double,
            let zIndex = firestoreData["zIndex"] as? Int,
            let contentJSONString = firestoreData["contentJSON"] as? String,
            let contentData = contentJSONString.data(using: .utf8),
            let content = try? JSONDecoder().decode(CustomizationContent.self, from: contentData)
        else {
            Log.warning("Failed to parse Customization from Firestore", category: .crdt)
            return nil
        }

        let customization = Customization(
            id: id,
            recipeId: recipeId,
            deviceId: deviceId,
            userId: userId,
            type: type,
            position: CGPoint(x: positionX, y: positionY),
            size: CGSize(width: sizeWidth, height: sizeHeight),
            rotation: rotation,
            zIndex: zIndex,
            content: content,
            vectorClock: vectorClock
        )

        // Restore timestamps and flags
        if let createdAt = firestoreData["createdAt"] as? Date {
            customization.createdAt = createdAt
        }
        if let modifiedAt = firestoreData["modifiedAt"] as? Date {
            customization.modifiedAt = modifiedAt
        }
        if let isDeleted = firestoreData["isDeleted"] as? Bool {
            customization.isDeleted = isDeleted
        }
        if let lamportTimestamp = firestoreData["lamportTimestamp"] as? Int64 {
            customization.lamportTimestamp = lamportTimestamp
        }

        return customization
    }
}
