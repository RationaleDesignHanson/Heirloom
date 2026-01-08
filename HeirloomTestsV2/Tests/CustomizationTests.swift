import Testing
import Foundation
import SwiftData
import SwiftUI

@testable import Heirloom

@Suite("Customization Tests")
struct CustomizationTests {

    // MARK: - Test Setup Helper

    func createTestVectorClock(deviceId: String = "device-1", value: Int64 = 1) -> VectorClock {
        let clock = VectorClock()
        clock.clocks[deviceId] = value
        return clock
    }

    // MARK: - Customization Initialization Tests

    @Test("Customization initializes with all required fields")
    func testInit_WithAllFields_SetsProperties() {
        // Arrange
        let id = UUID()
        let recipeId = UUID()
        let clock = createTestVectorClock()
        let content = CustomizationContent.sticker(assetId: "sticker-1", tintColor: "#FF0000")

        // Act
        let customization = Customization(
            id: id,
            recipeId: recipeId,
            deviceId: "device-1",
            userId: "user-1",
            type: .sticker,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.2, height: 0.2),
            rotation: 0.5,
            zIndex: 10,
            content: content,
            vectorClock: clock
        )

        // Assert
        #expect(customization.id == id)
        #expect(customization.recipeId == recipeId)
        #expect(customization.deviceId == "device-1")
        #expect(customization.userId == "user-1")
        #expect(customization.type == .sticker)
        #expect(customization.positionX == 0.5)
        #expect(customization.positionY == 0.5)
        #expect(customization.sizeWidth == 0.2)
        #expect(customization.sizeHeight == 0.2)
        #expect(customization.rotation == 0.5)
        #expect(customization.zIndex == 10)
        #expect(customization.isDeleted == false)
    }

    @Test("Customization sets default rotation to 0")
    func testInit_DefaultRotation_IsZero() {
        // Act
        let customization = Customization(
            recipeId: UUID(),
            deviceId: "device-1",
            userId: "user-1",
            type: .sticker,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.2, height: 0.2),
            zIndex: 10,
            content: .sticker(assetId: "sticker-1", tintColor: nil),
            vectorClock: createTestVectorClock()
        )

        // Assert
        #expect(customization.rotation == 0)
    }

    @Test("Customization creates timestamps on initialization")
    func testInit_CreatesTimestamps() {
        // Arrange
        let before = Date()

        // Act
        let customization = Customization(
            recipeId: UUID(),
            deviceId: "device-1",
            userId: "user-1",
            type: .text,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.3, height: 0.1),
            zIndex: 5,
            content: .text(content: "Hello", font: "Helvetica", fontSize: 24, color: "#000000"),
            vectorClock: createTestVectorClock()
        )

        // Assert
        #expect(customization.createdAt >= before)
        #expect(customization.modifiedAt >= before)
    }

    @Test("Customization sets Lamport timestamp from vector clock max")
    func testInit_SetsLamportTimestampFromVectorClockMax() {
        // Arrange
        let clock = VectorClock()
        clock.clocks["device-1"] = 5
        clock.clocks["device-2"] = 10
        clock.clocks["device-3"] = 7

        // Act
        let customization = Customization(
            recipeId: UUID(),
            deviceId: "device-1",
            userId: "user-1",
            type: .sticker,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.2, height: 0.2),
            zIndex: 10,
            content: .sticker(assetId: "sticker-1", tintColor: nil),
            vectorClock: clock
        )

        // Assert
        #expect(customization.lamportTimestamp == 10)
    }

    // MARK: - Type Tests

    @Test("Customization type property reads and writes correctly")
    func testType_ReadWrite() {
        // Arrange
        let customization = Customization(
            recipeId: UUID(),
            deviceId: "device-1",
            userId: "user-1",
            type: .sticker,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.2, height: 0.2),
            zIndex: 10,
            content: .sticker(assetId: "sticker-1", tintColor: nil),
            vectorClock: createTestVectorClock()
        )

        // Act & Assert initial
        #expect(customization.type == .sticker)

        // Act & Assert change
        customization.type = .drawing
        #expect(customization.type == .drawing)
        #expect(customization.typeRawValue == "drawing")
    }

    @Test("CustomizationType enum has all cases")
    func testCustomizationType_AllCases() {
        // Assert
        #expect(CustomizationType.sticker.rawValue == "sticker")
        #expect(CustomizationType.drawing.rawValue == "drawing")
        #expect(CustomizationType.text.rawValue == "text")
        #expect(CustomizationType.photo.rawValue == "photo")
        #expect(CustomizationType.shape.rawValue == "shape")
    }

    // MARK: - Position Tests

    @Test("Customization position property reads normalized coordinates")
    func testPosition_ReadsNormalizedCoordinates() {
        // Arrange
        let customization = Customization(
            recipeId: UUID(),
            deviceId: "device-1",
            userId: "user-1",
            type: .sticker,
            position: CGPoint(x: 0.75, y: 0.25),
            size: CGSize(width: 0.2, height: 0.2),
            zIndex: 10,
            content: .sticker(assetId: "sticker-1", tintColor: nil),
            vectorClock: createTestVectorClock()
        )

        // Assert
        #expect(customization.position.x == 0.75)
        #expect(customization.position.y == 0.25)
    }

    @Test("Customization position property writes to storage")
    func testPosition_WritesToStorage() {
        // Arrange
        let customization = Customization(
            recipeId: UUID(),
            deviceId: "device-1",
            userId: "user-1",
            type: .sticker,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.2, height: 0.2),
            zIndex: 10,
            content: .sticker(assetId: "sticker-1", tintColor: nil),
            vectorClock: createTestVectorClock()
        )

        // Act
        customization.position = CGPoint(x: 0.8, y: 0.3)

        // Assert
        #expect(customization.positionX == 0.8)
        #expect(customization.positionY == 0.3)
    }

    // MARK: - Size Tests

    @Test("Customization size property reads normalized dimensions")
    func testSize_ReadsNormalizedDimensions() {
        // Arrange
        let customization = Customization(
            recipeId: UUID(),
            deviceId: "device-1",
            userId: "user-1",
            type: .sticker,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.3, height: 0.4),
            zIndex: 10,
            content: .sticker(assetId: "sticker-1", tintColor: nil),
            vectorClock: createTestVectorClock()
        )

        // Assert
        #expect(customization.size.width == 0.3)
        #expect(customization.size.height == 0.4)
    }

    @Test("Customization size property writes to storage")
    func testSize_WritesToStorage() {
        // Arrange
        let customization = Customization(
            recipeId: UUID(),
            deviceId: "device-1",
            userId: "user-1",
            type: .sticker,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.2, height: 0.2),
            zIndex: 10,
            content: .sticker(assetId: "sticker-1", tintColor: nil),
            vectorClock: createTestVectorClock()
        )

        // Act
        customization.size = CGSize(width: 0.5, height: 0.6)

        // Assert
        #expect(customization.sizeWidth == 0.5)
        #expect(customization.sizeHeight == 0.6)
    }

    // MARK: - Rotation and Z-Index Tests

    @Test("Customization stores rotation in radians")
    func testRotation_StoresRadians() {
        // Arrange
        let customization = Customization(
            recipeId: UUID(),
            deviceId: "device-1",
            userId: "user-1",
            type: .sticker,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.2, height: 0.2),
            rotation: 1.5708, // 90 degrees
            zIndex: 10,
            content: .sticker(assetId: "sticker-1", tintColor: nil),
            vectorClock: createTestVectorClock()
        )

        // Assert
        #expect(customization.rotation == 1.5708)
    }

    @Test("Customization stores zIndex for layer ordering")
    func testZIndex_StoresLayerOrder() {
        // Arrange
        let customization = Customization(
            recipeId: UUID(),
            deviceId: "device-1",
            userId: "user-1",
            type: .sticker,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.2, height: 0.2),
            zIndex: 42,
            content: .sticker(assetId: "sticker-1", tintColor: nil),
            vectorClock: createTestVectorClock()
        )

        // Assert
        #expect(customization.zIndex == 42)
    }

    // MARK: - Content Tests

    @Test("Customization stores sticker content")
    func testContent_Sticker_StoresAndRetrievesContent() {
        // Arrange
        let content = CustomizationContent.sticker(assetId: "sticker-123", tintColor: "#FF5733")
        let customization = Customization(
            recipeId: UUID(),
            deviceId: "device-1",
            userId: "user-1",
            type: .sticker,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.2, height: 0.2),
            zIndex: 10,
            content: content,
            vectorClock: createTestVectorClock()
        )

        // Act & Assert
        switch customization.content {
        case .sticker(let assetId, let tintColor):
            #expect(assetId == "sticker-123")
            #expect(tintColor == "#FF5733")
        default:
            Issue.record("Expected sticker content")
        }
    }

    @Test("Customization stores drawing content")
    func testContent_Drawing_StoresAndRetrievesContent() {
        // Arrange
        let path = DrawingPath(points: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)])
        let content = CustomizationContent.drawing(path: path, strokeColor: "#000000", strokeWidth: 2.0)
        let customization = Customization(
            recipeId: UUID(),
            deviceId: "device-1",
            userId: "user-1",
            type: .drawing,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.2, height: 0.2),
            zIndex: 10,
            content: content,
            vectorClock: createTestVectorClock()
        )

        // Act & Assert
        switch customization.content {
        case .drawing(let path, let strokeColor, let strokeWidth):
            #expect(path.points.count == 2)
            #expect(strokeColor == "#000000")
            #expect(strokeWidth == 2.0)
        default:
            Issue.record("Expected drawing content")
        }
    }

    @Test("Customization stores text content")
    func testContent_Text_StoresAndRetrievesContent() {
        // Arrange
        let content = CustomizationContent.text(
            content: "Hello World",
            font: "Helvetica",
            fontSize: 24.0,
            color: "#FF0000"
        )
        let customization = Customization(
            recipeId: UUID(),
            deviceId: "device-1",
            userId: "user-1",
            type: .text,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.3, height: 0.1),
            zIndex: 10,
            content: content,
            vectorClock: createTestVectorClock()
        )

        // Act & Assert
        switch customization.content {
        case .text(let text, let font, let fontSize, let color):
            #expect(text == "Hello World")
            #expect(font == "Helvetica")
            #expect(fontSize == 24.0)
            #expect(color == "#FF0000")
        default:
            Issue.record("Expected text content")
        }
    }

    @Test("Customization stores photo content")
    func testContent_Photo_StoresAndRetrievesContent() {
        // Arrange
        let imageId = UUID()
        let content = CustomizationContent.photo(imageId: imageId, opacity: 0.8)
        let customization = Customization(
            recipeId: UUID(),
            deviceId: "device-1",
            userId: "user-1",
            type: .photo,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.4, height: 0.3),
            zIndex: 10,
            content: content,
            vectorClock: createTestVectorClock()
        )

        // Act & Assert
        switch customization.content {
        case .photo(let storedImageId, let opacity):
            #expect(storedImageId == imageId)
            #expect(opacity == 0.8)
        default:
            Issue.record("Expected photo content")
        }
    }

    @Test("Customization stores shape content")
    func testContent_Shape_StoresAndRetrievesContent() {
        // Arrange
        let content = CustomizationContent.shape(
            shapeType: .heart,
            fillColor: "#FF0000",
            strokeColor: "#000000"
        )
        let customization = Customization(
            recipeId: UUID(),
            deviceId: "device-1",
            userId: "user-1",
            type: .shape,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.2, height: 0.2),
            zIndex: 10,
            content: content,
            vectorClock: createTestVectorClock()
        )

        // Act & Assert
        switch customization.content {
        case .shape(let shapeType, let fillColor, let strokeColor):
            #expect(shapeType == .heart)
            #expect(fillColor == "#FF0000")
            #expect(strokeColor == "#000000")
        default:
            Issue.record("Expected shape content")
        }
    }

    @Test("Customization content property can be updated")
    func testContent_CanBeUpdated() {
        // Arrange
        let customization = Customization(
            recipeId: UUID(),
            deviceId: "device-1",
            userId: "user-1",
            type: .sticker,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.2, height: 0.2),
            zIndex: 10,
            content: .sticker(assetId: "sticker-1", tintColor: nil),
            vectorClock: createTestVectorClock()
        )

        // Act
        customization.content = .text(content: "New Text", font: "Arial", fontSize: 18, color: "#000000")

        // Assert
        switch customization.content {
        case .text(let text, _, _, _):
            #expect(text == "New Text")
        default:
            Issue.record("Expected text content after update")
        }
    }

    // MARK: - Soft Delete Tests

    @Test("Customization initializes with isDeleted false")
    func testIsDeleted_InitiallyFalse() {
        // Act
        let customization = Customization(
            recipeId: UUID(),
            deviceId: "device-1",
            userId: "user-1",
            type: .sticker,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.2, height: 0.2),
            zIndex: 10,
            content: .sticker(assetId: "sticker-1", tintColor: nil),
            vectorClock: createTestVectorClock()
        )

        // Assert
        #expect(customization.isDeleted == false)
    }

    @Test("Customization can be marked as deleted")
    func testIsDeleted_CanBeMarkedDeleted() {
        // Arrange
        let customization = Customization(
            recipeId: UUID(),
            deviceId: "device-1",
            userId: "user-1",
            type: .sticker,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.2, height: 0.2),
            zIndex: 10,
            content: .sticker(assetId: "sticker-1", tintColor: nil),
            vectorClock: createTestVectorClock()
        )

        // Act
        customization.isDeleted = true

        // Assert
        #expect(customization.isDeleted == true)
    }

    // MARK: - VectorClock Tests

    @Test("VectorClock initializes with empty clocks")
    func testVectorClock_InitializesEmpty() {
        // Act
        let clock = VectorClock()

        // Assert
        #expect(clock.clocks.isEmpty)
    }

    @Test("VectorClock initializes with provided clocks")
    func testVectorClock_InitializesWithClocks() {
        // Act
        let clock = VectorClock(clocks: ["device-1": 5, "device-2": 10])

        // Assert
        #expect(clock.clocks["device-1"] == 5)
        #expect(clock.clocks["device-2"] == 10)
    }

    @Test("VectorClock increment increases value for device")
    func testVectorClock_Increment_IncreasesValue() {
        // Arrange
        let clock = VectorClock()

        // Act
        clock.increment(deviceId: "device-1")
        clock.increment(deviceId: "device-1")

        // Assert
        #expect(clock.value(for: "device-1") == 2)
    }

    @Test("VectorClock value returns 0 for unknown device")
    func testVectorClock_Value_Returns0ForUnknownDevice() {
        // Arrange
        let clock = VectorClock()

        // Act & Assert
        #expect(clock.value(for: "unknown") == 0)
    }

    @Test("VectorClock merge takes maximum of each device")
    func testVectorClock_Merge_TakesMaximum() {
        // Arrange
        let clock1 = VectorClock(clocks: ["device-1": 5, "device-2": 3])
        let clock2 = VectorClock(clocks: ["device-1": 2, "device-2": 7, "device-3": 4])

        // Act
        clock1.merge(with: clock2)

        // Assert
        #expect(clock1.value(for: "device-1") == 5) // max(5, 2)
        #expect(clock1.value(for: "device-2") == 7) // max(3, 7)
        #expect(clock1.value(for: "device-3") == 4) // max(0, 4)
    }

    @Test("VectorClock compare returns equal for identical clocks")
    func testVectorClock_Compare_ReturnsEqualForIdenticalClocks() {
        // Arrange
        let clock1 = VectorClock(clocks: ["device-1": 5, "device-2": 10])
        let clock2 = VectorClock(clocks: ["device-1": 5, "device-2": 10])

        // Act
        let comparison = clock1.compare(with: clock2)

        // Assert
        #expect(comparison == .equal)
    }

    @Test("VectorClock compare returns before when causally earlier")
    func testVectorClock_Compare_ReturnsBeforeWhenCausallyEarlier() {
        // Arrange
        let clock1 = VectorClock(clocks: ["device-1": 3, "device-2": 5])
        let clock2 = VectorClock(clocks: ["device-1": 5, "device-2": 7])

        // Act
        let comparison = clock1.compare(with: clock2)

        // Assert
        #expect(comparison == .before)
    }

    @Test("VectorClock compare returns after when causally later")
    func testVectorClock_Compare_ReturnsAfterWhenCausallyLater() {
        // Arrange
        let clock1 = VectorClock(clocks: ["device-1": 10, "device-2": 15])
        let clock2 = VectorClock(clocks: ["device-1": 5, "device-2": 7])

        // Act
        let comparison = clock1.compare(with: clock2)

        // Assert
        #expect(comparison == .after)
    }

    @Test("VectorClock compare returns concurrent when conflicting")
    func testVectorClock_Compare_ReturnsConcurrentWhenConflicting() {
        // Arrange
        let clock1 = VectorClock(clocks: ["device-1": 10, "device-2": 5])
        let clock2 = VectorClock(clocks: ["device-1": 5, "device-2": 10])

        // Act
        let comparison = clock1.compare(with: clock2)

        // Assert
        #expect(comparison == .concurrent)
    }

    @Test("VectorClock happenedBefore returns true when before")
    func testVectorClock_HappenedBefore_ReturnsTrueWhenBefore() {
        // Arrange
        let clock1 = VectorClock(clocks: ["device-1": 3])
        let clock2 = VectorClock(clocks: ["device-1": 5])

        // Act & Assert
        #expect(clock1.happenedBefore(clock2) == true)
    }

    @Test("VectorClock happenedBefore returns false when not before")
    func testVectorClock_HappenedBefore_ReturnsFalseWhenNotBefore() {
        // Arrange
        let clock1 = VectorClock(clocks: ["device-1": 5])
        let clock2 = VectorClock(clocks: ["device-1": 3])

        // Act & Assert
        #expect(clock1.happenedBefore(clock2) == false)
    }

    @Test("VectorClock isConcurrent returns true for concurrent clocks")
    func testVectorClock_IsConcurrent_ReturnsTrueForConcurrent() {
        // Arrange
        let clock1 = VectorClock(clocks: ["device-1": 10, "device-2": 5])
        let clock2 = VectorClock(clocks: ["device-1": 5, "device-2": 10])

        // Act & Assert
        #expect(clock1.isConcurrent(with: clock2) == true)
    }

    @Test("VectorClock copy creates independent copy")
    func testVectorClock_Copy_CreatesIndependentCopy() {
        // Arrange
        let clock1 = VectorClock(clocks: ["device-1": 5])

        // Act
        let clock2 = clock1.copy()
        clock2.increment(deviceId: "device-1")

        // Assert
        #expect(clock1.value(for: "device-1") == 5)
        #expect(clock2.value(for: "device-1") == 6)
    }

    @Test("VectorClock equality compares clocks correctly")
    func testVectorClock_Equality_ComparesCorrectly() {
        // Arrange
        let clock1 = VectorClock(clocks: ["device-1": 5, "device-2": 10])
        let clock2 = VectorClock(clocks: ["device-1": 5, "device-2": 10])
        let clock3 = VectorClock(clocks: ["device-1": 5, "device-2": 11])

        // Assert
        #expect(clock1 == clock2)
        #expect(clock1 != clock3)
    }

    // MARK: - Supporting Type Tests

    @Test("DrawingPath initializes with points")
    func testDrawingPath_InitializesWithPoints() {
        // Arrange
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 0)]

        // Act
        let path = DrawingPath(points: points)

        // Assert
        #expect(path.points.count == 3)
        #expect(path.smoothed == false)
    }

    @Test("DrawingPath converts to CGPoint array")
    func testDrawingPath_ConvertsToCGPointArray() {
        // Arrange
        let points = [CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.7, y: 0.8)]
        let path = DrawingPath(points: points)

        // Act
        let cgPoints = path.cgPoints

        // Assert
        #expect(cgPoints.count == 2)
        #expect(cgPoints[0].x == 0.5)
        #expect(cgPoints[1].y == 0.8)
    }

    @Test("DrawingPath generates SVG path string")
    func testDrawingPath_GeneratesSVGPath() {
        // Arrange
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 50), CGPoint(x: 200, y: 0)]
        let path = DrawingPath(points: points)

        // Act
        let svg = path.svgPath

        // Assert
        #expect(svg.contains("M 0.0,0.0"))
        #expect(svg.contains("L 100.0,50.0"))
        #expect(svg.contains("L 200.0,0.0"))
    }

    @Test("DrawingPath returns empty string for empty points")
    func testDrawingPath_EmptyPoints_ReturnsEmptyString() {
        // Arrange
        let path = DrawingPath(points: [])

        // Act
        let svg = path.svgPath

        // Assert
        #expect(svg == "")
    }

    @Test("ShapeType enum has all cases")
    func testShapeType_AllCases() {
        // Assert
        #expect(ShapeType.heart.rawValue == "heart")
        #expect(ShapeType.star.rawValue == "star")
        #expect(ShapeType.circle.rawValue == "circle")
        #expect(ShapeType.rectangle.rawValue == "rectangle")
        #expect(ShapeType.arrow.rawValue == "arrow")
    }

    @Test("CGPointCodable wraps CGPoint correctly")
    func testCGPointCodable_WrapsCGPoint() {
        // Arrange
        let point = CGPoint(x: 0.75, y: 0.25)

        // Act
        let codable = CGPointCodable(point: point)

        // Assert
        #expect(codable.x == 0.75)
        #expect(codable.y == 0.25)
        #expect(codable.cgPoint == point)
    }

    @Test("CGSizeCodable wraps CGSize correctly")
    func testCGSizeCodable_WrapsCGSize() {
        // Arrange
        let size = CGSize(width: 100, height: 200)

        // Act
        let codable = CGSizeCodable(size: size)

        // Assert
        #expect(codable.width == 100)
        #expect(codable.height == 200)
        #expect(codable.cgSize == size)
    }

    // MARK: - Codable Tests

    @Test("CustomizationContent sticker encodes and decodes")
    func testCustomizationContent_Sticker_EncodesAndDecodes() throws {
        // Arrange
        let content = CustomizationContent.sticker(assetId: "sticker-123", tintColor: "#FF0000")

        // Act
        let encoder = JSONEncoder()
        let data = try encoder.encode(content)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CustomizationContent.self, from: data)

        // Assert
        #expect(decoded == content)
    }

    @Test("CustomizationContent text encodes and decodes")
    func testCustomizationContent_Text_EncodesAndDecodes() throws {
        // Arrange
        let content = CustomizationContent.text(
            content: "Hello",
            font: "Arial",
            fontSize: 24,
            color: "#000000"
        )

        // Act
        let encoder = JSONEncoder()
        let data = try encoder.encode(content)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CustomizationContent.self, from: data)

        // Assert
        #expect(decoded == content)
    }

    @Test("CustomizationContent drawing encodes and decodes")
    func testCustomizationContent_Drawing_EncodesAndDecodes() throws {
        // Arrange
        let path = DrawingPath(points: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)])
        let content = CustomizationContent.drawing(path: path, strokeColor: "#000000", strokeWidth: 2.0)

        // Act
        let encoder = JSONEncoder()
        let data = try encoder.encode(content)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CustomizationContent.self, from: data)

        // Assert
        #expect(decoded == content)
    }

    @Test("VectorClock encodes and decodes via Codable")
    func testVectorClock_EncodesAndDecodes() throws {
        // Arrange
        let clock = VectorClock(clocks: ["device-1": 5, "device-2": 10])

        // Act
        let encoder = JSONEncoder()
        let data = try encoder.encode(clock)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VectorClock.self, from: data)

        // Assert
        #expect(decoded.value(for: "device-1") == 5)
        #expect(decoded.value(for: "device-2") == 10)
    }

    // MARK: - Firestore Serialization Tests

    @Test("Customization converts to Firestore data")
    func testCustomization_ToFirestoreData() {
        // Arrange
        let customization = Customization(
            recipeId: UUID(),
            deviceId: "device-1",
            userId: "user-1",
            type: .sticker,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.2, height: 0.2),
            zIndex: 10,
            content: .sticker(assetId: "sticker-1", tintColor: nil),
            vectorClock: createTestVectorClock()
        )

        // Act
        let data = customization.toFirestoreData()

        // Assert
        #expect(data["deviceId"] as? String == "device-1")
        #expect(data["userId"] as? String == "user-1")
        #expect(data["type"] as? String == "sticker")
        #expect(data["positionX"] as? Double == 0.5)
        #expect(data["positionY"] as? Double == 0.5)
        #expect(data["zIndex"] as? Int == 10)
        #expect(data["isDeleted"] as? Bool == false)
    }

    @Test("VectorClock converts to Firestore data")
    func testVectorClock_ToFirestoreData() {
        // Arrange
        let clock = VectorClock(clocks: ["device-1": 5, "device-2": 10])

        // Act
        let data = clock.toFirestoreData()

        // Assert
        let clocks = data["clocks"] as? [String: Int64]
        #expect(clocks?["device-1"] == 5)
        #expect(clocks?["device-2"] == 10)
        #expect(data["lastUpdated"] != nil)
    }

    @Test("VectorClock creates from Firestore data")
    func testVectorClock_FromFirestoreData() {
        // Arrange
        let firestoreData: [String: Any] = [
            "clocks": ["device-1": 5, "device-2": 10],
            "lastUpdated": Date()
        ]

        // Act
        let clock = VectorClock.from(firestoreData: firestoreData)

        // Assert
        #expect(clock != nil)
        #expect(clock?.value(for: "device-1") == 5)
        #expect(clock?.value(for: "device-2") == 10)
    }

    @Test("VectorClock handles Int to Int64 conversion from Firestore")
    func testVectorClock_HandlesIntToInt64Conversion() {
        // Arrange - Firestore returns Int, not Int64
        let firestoreData: [String: Any] = [
            "clocks": ["device-1": Int(5), "device-2": Int(10)],
            "lastUpdated": Date()
        ]

        // Act
        let clock = VectorClock.from(firestoreData: firestoreData)

        // Assert
        #expect(clock != nil)
        #expect(clock?.value(for: "device-1") == 5)
        #expect(clock?.value(for: "device-2") == 10)
    }

    @Test("VectorClock description provides readable format")
    func testVectorClock_Description_ProvidesReadableFormat() {
        // Arrange
        let clock = VectorClock(clocks: ["device-1": 5, "device-2": 10])

        // Act
        let description = clock.description

        // Assert
        #expect(description.contains("device-1: 5"))
        #expect(description.contains("device-2: 10"))
    }
}
