# Card Customization Service Plan
**Heirloom Recipe App - Phase: Card Personalization**
**Author**: Engineering Team
**Date**: 2026-01-04
**Status**: Ready for Implementation

---

## Executive Summary

Implement a comprehensive card customization system that allows users to personalize their recipe cards with stickers, annotations, drawings, and handwritten notes - similar to decorating physical recipe cards. The system must support full undo/redo, CRDT-based sync for multiplayer editing, and maintain the vintage aesthetic of the Heirloom app.

---

## 1. Architecture Overview

### 1.1 Core Principles
- **CRDT-Based**: All customizations are CRDT operations for conflict-free sync
- **Undo/Redo**: Complete operation history with unlimited undo/redo
- **Layer-Based**: Customizations rendered in layers above recipe content
- **Non-Destructive**: Original recipe remains unchanged
- **Performant**: Optimized rendering for 60fps card interactions

### 1.2 Service Architecture
```
┌─────────────────────────────────────────────────────┐
│                   UI Layer                          │
│  RecipeCardView + CustomizationOverlayView          │
└─────────────┬───────────────────────────────────────┘
              │
┌─────────────▼───────────────────────────────────────┐
│              Service Layer                          │
│  ┌─────────────────┐  ┌──────────────────┐         │
│  │ CardCustomization│  │  UndoService     │         │
│  │     Service     │◄─┤  (Enhanced)      │         │
│  └────────┬────────┘  └──────────────────┘         │
│           │                                          │
│  ┌────────▼────────┐  ┌──────────────────┐         │
│  │ StickerLibrary  │  │ AnnotationEngine │         │
│  │    Service      │  │     Service      │         │
│  └─────────────────┘  └──────────────────┘         │
└─────────────┬───────────────────────────────────────┘
              │
┌─────────────▼───────────────────────────────────────┐
│              Data Layer                              │
│  ┌─────────────────┐  ┌──────────────────┐         │
│  │ Customization   │  │   StickerAsset   │         │
│  │    (Model)      │  │     (Model)      │         │
│  └─────────────────┘  └──────────────────┘         │
└─────────────┬───────────────────────────────────────┘
              │
┌─────────────▼───────────────────────────────────────┐
│           CRDT + Sync Layer                         │
│  OperationLog → Firebase → Multi-Device Sync        │
└─────────────────────────────────────────────────────┘
```

---

## 2. Data Models

### 2.1 Customization Model
```swift
import Foundation
import SwiftData

@Model
class Customization {
    // MARK: - Identity
    var id: UUID
    var recipeId: UUID
    var deviceId: String
    var userId: String

    // MARK: - Type
    var type: CustomizationType

    // MARK: - Positioning
    var position: CGPoint          // Relative to card (0-1 normalized)
    var size: CGSize               // Relative size
    var rotation: Double           // Radians
    var zIndex: Int                // Layer order

    // MARK: - Content
    var content: CustomizationContent

    // MARK: - Metadata
    var createdAt: Date
    var modifiedAt: Date
    var isDeleted: Bool            // Soft delete for CRDT

    // MARK: - CRDT
    var vectorClock: VectorClock
    var lamportTimestamp: Int64

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
        self.type = type
        self.position = position
        self.size = size
        self.rotation = rotation
        self.zIndex = zIndex
        self.content = content
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.isDeleted = false
        self.vectorClock = vectorClock
        self.lamportTimestamp = vectorClock.lamportTimestamp
    }
}

enum CustomizationType: String, Codable {
    case sticker           // Pre-made sticker asset
    case drawing           // Freehand drawing/doodle
    case text              // Text annotation
    case photo             // User photo overlay
    case shape             // Basic shapes (heart, star, etc.)
}

enum CustomizationContent: Codable {
    case sticker(assetId: String, tintColor: String?)
    case drawing(path: DrawingPath, strokeColor: String, strokeWidth: Double)
    case text(content: String, font: String, fontSize: Double, color: String)
    case photo(imageId: UUID, opacity: Double)
    case shape(shapeType: ShapeType, fillColor: String, strokeColor: String)
}

struct DrawingPath: Codable {
    var points: [CGPoint]
    var smoothed: Bool

    // SVG-like path for resolution independence
    var svgPath: String {
        // Convert points to SVG path string
        // "M x1,y1 L x2,y2 L x3,y3 Z"
    }
}

enum ShapeType: String, Codable {
    case heart
    case star
    case circle
    case rectangle
    case arrow
}
```

### 2.2 Sticker Asset Model
```swift
import Foundation
import SwiftData

@Model
class StickerAsset {
    // MARK: - Identity
    var id: String                 // e.g., "vintage_spoon_01"
    var name: String
    var category: StickerCategory

    // MARK: - Asset
    var assetName: String          // Asset catalog name
    var svgData: Data?             // SVG for resolution independence
    var previewImage: Data?        // PNG thumbnail

    // MARK: - Properties
    var supportsTinting: Bool
    var defaultSize: CGSize        // Suggested size (normalized)
    var tags: [String]

    // MARK: - Metadata
    var isPremium: Bool
    var sortOrder: Int
    var isEnabled: Bool

    init(
        id: String,
        name: String,
        category: StickerCategory,
        assetName: String,
        supportsTinting: Bool = false,
        defaultSize: CGSize,
        tags: [String] = [],
        isPremium: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.assetName = assetName
        self.supportsTinting = supportsTinting
        self.defaultSize = defaultSize
        self.tags = tags
        self.isPremium = isPremium
        self.sortOrder = sortOrder
        self.isEnabled = true
    }
}

enum StickerCategory: String, Codable {
    case vintage           // Vintage kitchen items (rolling pins, mixers, etc.)
    case decorative        // Borders, corners, flourishes
    case seasonal          // Holiday-themed
    case icons             // Hearts, stars, checkmarks
    case botanical         // Herbs, flowers, leaves
    case utensils          // Spoons, forks, knives, whisks
    case typography        // Decorative letters, labels
    case frames            // Photo frame overlays
}
```

### 2.3 CRDT Operation Extensions
```swift
// Extend existing RecipeOperation enum
extension RecipeOperation {
    case addCustomization(Customization)
    case modifyCustomization(customizationId: UUID, changes: CustomizationChanges)
    case deleteCustomization(customizationId: UUID)
    case reorderCustomizations(recipeId: UUID, zIndexMap: [UUID: Int])
}

struct CustomizationChanges: Codable {
    var position: CGPoint?
    var size: CGSize?
    var rotation: Double?
    var zIndex: Int?
    var content: CustomizationContent?
}
```

---

## 3. Services

### 3.1 CardCustomizationService
**Purpose**: Core service for managing all card customizations

```swift
import Foundation
import SwiftData

@MainActor
protocol CardCustomizationServiceProtocol {
    // MARK: - Add Customizations
    func addSticker(
        to recipeId: UUID,
        stickerAssetId: String,
        position: CGPoint,
        size: CGSize,
        tintColor: String?,
        context: ModelContext
    ) async throws -> Customization

    func addDrawing(
        to recipeId: UUID,
        path: DrawingPath,
        strokeColor: String,
        strokeWidth: Double,
        position: CGPoint,
        context: ModelContext
    ) async throws -> Customization

    func addText(
        to recipeId: UUID,
        content: String,
        position: CGPoint,
        font: String,
        fontSize: Double,
        color: String,
        context: ModelContext
    ) async throws -> Customization

    func addPhoto(
        to recipeId: UUID,
        imageData: Data,
        position: CGPoint,
        size: CGSize,
        opacity: Double,
        context: ModelContext
    ) async throws -> Customization

    // MARK: - Modify Customizations
    func move(
        customizationId: UUID,
        to position: CGPoint,
        context: ModelContext
    ) async throws

    func resize(
        customizationId: UUID,
        to size: CGSize,
        context: ModelContext
    ) async throws

    func rotate(
        customizationId: UUID,
        by angle: Double,
        context: ModelContext
    ) async throws

    func updateContent(
        customizationId: UUID,
        content: CustomizationContent,
        context: ModelContext
    ) async throws

    // MARK: - Delete Customizations
    func delete(
        customizationId: UUID,
        context: ModelContext
    ) async throws

    func deleteAll(
        for recipeId: UUID,
        context: ModelContext
    ) async throws

    // MARK: - Query Customizations
    func fetchCustomizations(
        for recipeId: UUID,
        context: ModelContext
    ) throws -> [Customization]

    func fetchCustomization(
        id: UUID,
        context: ModelContext
    ) throws -> Customization?

    // MARK: - Layer Management
    func bringToFront(
        customizationId: UUID,
        context: ModelContext
    ) async throws

    func sendToBack(
        customizationId: UUID,
        context: ModelContext
    ) async throws

    func bringForward(
        customizationId: UUID,
        context: ModelContext
    ) async throws

    func sendBackward(
        customizationId: UUID,
        context: ModelContext
    ) async throws
}

@MainActor
final class CardCustomizationService: ObservableObject, CardCustomizationServiceProtocol {
    // MARK: - Dependencies
    private let undoService: UndoService
    private let imageStorage: ImageStorageService
    private let deviceId: String
    private let logger: LoggingService

    // MARK: - State
    @Published private(set) var activeRecipeId: UUID?
    @Published private(set) var selectedCustomization: Customization?

    init(
        undoService: UndoService,
        imageStorage: ImageStorageService,
        deviceId: String = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
        logger: LoggingService
    ) {
        self.undoService = undoService
        self.imageStorage = imageStorage
        self.deviceId = deviceId
        self.logger = logger
    }

    // Implementation details...
}
```

### 3.2 StickerLibraryService
**Purpose**: Manage sticker asset library and user collections

```swift
import Foundation
import SwiftData

@MainActor
protocol StickerLibraryServiceProtocol {
    // MARK: - Library Management
    func initializeDefaultLibrary(context: ModelContext) async throws
    func fetchAllStickers(context: ModelContext) throws -> [StickerAsset]
    func fetchStickers(category: StickerCategory, context: ModelContext) throws -> [StickerAsset]
    func searchStickers(query: String, context: ModelContext) throws -> [StickerAsset]

    // MARK: - User Collections
    func getFavoriteStickers(context: ModelContext) throws -> [StickerAsset]
    func addToFavorites(stickerId: String, context: ModelContext) async throws
    func removeFromFavorites(stickerId: String, context: ModelContext) async throws

    // MARK: - Custom Stickers
    func importCustomSticker(
        imageData: Data,
        name: String,
        category: StickerCategory,
        context: ModelContext
    ) async throws -> StickerAsset
}

@MainActor
final class StickerLibraryService: ObservableObject, StickerLibraryServiceProtocol {
    private let imageStorage: ImageStorageService
    private let logger: LoggingService

    init(
        imageStorage: ImageStorageService,
        logger: LoggingService
    ) {
        self.imageStorage = imageStorage
        self.logger = logger
    }

    func initializeDefaultLibrary(context: ModelContext) async throws {
        logger.info("Initializing default sticker library", category: .general)

        // Check if already initialized
        let descriptor = FetchDescriptor<StickerAsset>()
        let existing = try context.fetch(descriptor)
        guard existing.isEmpty else {
            logger.debug("Sticker library already initialized", category: .general)
            return
        }

        // Add vintage stickers
        let vintageStickers: [StickerAsset] = [
            StickerAsset(
                id: "vintage_rolling_pin",
                name: "Rolling Pin",
                category: .vintage,
                assetName: "sticker_rolling_pin",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.2, height: 0.15),
                tags: ["baking", "vintage", "kitchen"],
                sortOrder: 1
            ),
            StickerAsset(
                id: "vintage_whisk",
                name: "Whisk",
                category: .vintage,
                assetName: "sticker_whisk",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.15, height: 0.2),
                tags: ["mixing", "vintage", "kitchen"],
                sortOrder: 2
            ),
            StickerAsset(
                id: "vintage_mixer",
                name: "Stand Mixer",
                category: .vintage,
                assetName: "sticker_mixer",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.25, height: 0.25),
                tags: ["baking", "vintage", "appliance"],
                sortOrder: 3
            ),
            // Add more...
        ]

        // Add decorative stickers
        let decorativeStickers: [StickerAsset] = [
            StickerAsset(
                id: "corner_flourish_1",
                name: "Corner Flourish",
                category: .decorative,
                assetName: "sticker_corner_flourish",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.12, height: 0.12),
                tags: ["corner", "border", "elegant"],
                sortOrder: 1
            ),
            StickerAsset(
                id: "border_dotted",
                name: "Dotted Border",
                category: .decorative,
                assetName: "sticker_border_dotted",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.9, height: 0.05),
                tags: ["border", "frame"],
                sortOrder: 2
            ),
            // Add more...
        ]

        // Add botanical stickers
        let botanicalStickers: [StickerAsset] = [
            StickerAsset(
                id: "herb_rosemary",
                name: "Rosemary Sprig",
                category: .botanical,
                assetName: "sticker_rosemary",
                supportsTinting: false,
                defaultSize: CGSize(width: 0.15, height: 0.2),
                tags: ["herb", "fresh", "cooking"],
                sortOrder: 1
            ),
            StickerAsset(
                id: "herb_basil",
                name: "Basil Leaves",
                category: .botanical,
                assetName: "sticker_basil",
                supportsTinting: false,
                defaultSize: CGSize(width: 0.18, height: 0.15),
                tags: ["herb", "italian", "cooking"],
                sortOrder: 2
            ),
            // Add more...
        ]

        // Insert all stickers
        for sticker in vintageStickers + decorativeStickers + botanicalStickers {
            context.insert(sticker)
        }

        try context.save()
        logger.info("Sticker library initialized successfully", category: .general)
    }

    // Other implementations...
}
```

### 3.3 AnnotationEngine Service
**Purpose**: Handle drawing, text, and freehand annotations

```swift
import Foundation
import SwiftUI
import PencilKit

@MainActor
protocol AnnotationEngineProtocol {
    // MARK: - Drawing
    func startDrawing(
        at point: CGPoint,
        strokeColor: Color,
        strokeWidth: Double
    )

    func continueDrawing(to point: CGPoint)

    func finishDrawing(
        for recipeId: UUID,
        context: ModelContext
    ) async throws -> Customization

    func cancelDrawing()

    // MARK: - Path Smoothing
    func smoothPath(_ points: [CGPoint]) -> DrawingPath

    // MARK: - PencilKit Integration
    func convertPKDrawing(
        _ drawing: PKDrawing,
        for recipeId: UUID,
        context: ModelContext
    ) async throws -> [Customization]
}

@MainActor
final class AnnotationEngine: ObservableObject, AnnotationEngineProtocol {
    // MARK: - Dependencies
    private let customizationService: CardCustomizationService
    private let logger: LoggingService

    // MARK: - State
    @Published var currentPath: [CGPoint] = []
    @Published var currentStrokeColor: Color = .black
    @Published var currentStrokeWidth: Double = 2.0
    @Published var isDrawing: Bool = false

    init(
        customizationService: CardCustomizationService,
        logger: LoggingService
    ) {
        self.customizationService = customizationService
        self.logger = logger
    }

    func smoothPath(_ points: [CGPoint]) -> DrawingPath {
        // Catmull-Rom spline smoothing
        guard points.count > 2 else {
            return DrawingPath(points: points, smoothed: false)
        }

        var smoothedPoints: [CGPoint] = []
        let tension: CGFloat = 0.5

        for i in 0..<points.count - 1 {
            let p0 = i > 0 ? points[i - 1] : points[i]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i < points.count - 2 ? points[i + 2] : p2

            // Interpolate between p1 and p2
            for t in stride(from: 0.0, to: 1.0, by: 0.1) {
                let point = catmullRomInterpolate(
                    p0: p0, p1: p1, p2: p2, p3: p3,
                    t: t, tension: tension
                )
                smoothedPoints.append(point)
            }
        }

        smoothedPoints.append(points.last!)

        return DrawingPath(points: smoothedPoints, smoothed: true)
    }

    private func catmullRomInterpolate(
        p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint,
        t: CGFloat, tension: CGFloat
    ) -> CGPoint {
        let t2 = t * t
        let t3 = t2 * t

        let v0 = (p2 - p0) * tension
        let v1 = (p3 - p1) * tension

        let x = (2 * p1.x - 2 * p2.x + v0.x + v1.x) * t3 +
                (-3 * p1.x + 3 * p2.x - 2 * v0.x - v1.x) * t2 +
                v0.x * t + p1.x

        let y = (2 * p1.y - 2 * p2.y + v0.y + v1.y) * t3 +
                (-3 * p1.y + 3 * p2.y - 2 * v0.y - v1.y) * t2 +
                v0.y * t + p1.y

        return CGPoint(x: x, y: y)
    }

    // Other implementations...
}

private extension CGPoint {
    static func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func *(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}
```

### 3.4 Enhanced UndoService
**Purpose**: Extend existing undo service to support customization operations

```swift
// Add to existing UndoService.swift

extension UndoService {
    // MARK: - Customization Undo Operations

    func recordAddCustomization(
        _ customization: Customization,
        recipeId: UUID,
        context: ModelContext
    ) async {
        let operation = UndoOperation(
            id: UUID(),
            type: .addCustomization,
            timestamp: Date(),
            recipeId: recipeId,
            data: ["customizationId": customization.id.uuidString]
        )

        await addOperation(operation)
    }

    func recordModifyCustomization(
        customizationId: UUID,
        recipeId: UUID,
        previousState: CustomizationSnapshot,
        context: ModelContext
    ) async {
        let operation = UndoOperation(
            id: UUID(),
            type: .modifyCustomization,
            timestamp: Date(),
            recipeId: recipeId,
            data: [
                "customizationId": customizationId.uuidString,
                "previousState": previousState.toJSON()
            ]
        )

        await addOperation(operation)
    }

    func recordDeleteCustomization(
        _ customization: Customization,
        recipeId: UUID,
        context: ModelContext
    ) async {
        let snapshot = CustomizationSnapshot(from: customization)

        let operation = UndoOperation(
            id: UUID(),
            type: .deleteCustomization,
            timestamp: Date(),
            recipeId: recipeId,
            data: [
                "customizationId": customization.id.uuidString,
                "snapshot": snapshot.toJSON()
            ]
        )

        await addOperation(operation)
    }
}

struct CustomizationSnapshot: Codable {
    let id: UUID
    let recipeId: UUID
    let type: CustomizationType
    let position: CGPoint
    let size: CGSize
    let rotation: Double
    let zIndex: Int
    let content: CustomizationContent

    init(from customization: Customization) {
        self.id = customization.id
        self.recipeId = customization.recipeId
        self.type = customization.type
        self.position = customization.position
        self.size = customization.size
        self.rotation = customization.rotation
        self.zIndex = customization.zIndex
        self.content = customization.content
    }

    func toJSON() -> String {
        // Convert to JSON string
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}

// Add to UndoOperationType enum
extension UndoOperationType {
    case addCustomization
    case modifyCustomization
    case deleteCustomization
    case reorderCustomizations
}
```

---

## 4. UI Components

### 4.1 CustomizationOverlayView
**Purpose**: Render all customizations above recipe card

```swift
import SwiftUI

struct CustomizationOverlayView: View {
    let customizations: [Customization]
    let cardSize: CGSize
    @Binding var selectedCustomization: Customization?
    let onMove: (Customization, CGPoint) -> Void
    let onResize: (Customization, CGSize) -> Void
    let onRotate: (Customization, Double) -> Void
    let onDelete: (Customization) -> Void

    var body: some View {
        ZStack {
            // Render customizations in z-index order
            ForEach(sortedCustomizations, id: \.id) { customization in
                CustomizationItemView(
                    customization: customization,
                    cardSize: cardSize,
                    isSelected: selectedCustomization?.id == customization.id,
                    onTap: {
                        selectedCustomization = customization
                    },
                    onMove: { position in
                        onMove(customization, position)
                    },
                    onResize: { size in
                        onResize(customization, size)
                    },
                    onRotate: { angle in
                        onRotate(customization, angle)
                    }
                )
            }
        }
        .overlay {
            // Selection handles
            if let selected = selectedCustomization {
                SelectionHandlesView(
                    customization: selected,
                    cardSize: cardSize,
                    onResize: { size in
                        onResize(selected, size)
                    },
                    onRotate: { angle in
                        onRotate(selected, angle)
                    },
                    onDelete: {
                        onDelete(selected)
                    }
                )
            }
        }
    }

    private var sortedCustomizations: [Customization] {
        customizations
            .filter { !$0.isDeleted }
            .sorted { $0.zIndex < $1.zIndex }
    }
}
```

### 4.2 StickerPickerView
**Purpose**: Browse and select stickers to add to cards

```swift
import SwiftUI
import SwiftData

struct StickerPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \StickerAsset.sortOrder) private var allStickers: [StickerAsset]

    @State private var selectedCategory: StickerCategory = .vintage
    @State private var searchText: String = ""
    @State private var showFavoritesOnly: Bool = false

    let onStickerSelected: (StickerAsset) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText, placeholder: "Search stickers...")
                    .padding()

                // Category tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryTabButton(
                            category: .vintage,
                            isSelected: selectedCategory == .vintage
                        ) {
                            selectedCategory = .vintage
                        }

                        CategoryTabButton(
                            category: .decorative,
                            isSelected: selectedCategory == .decorative
                        ) {
                            selectedCategory = .decorative
                        }

                        CategoryTabButton(
                            category: .botanical,
                            isSelected: selectedCategory == .botanical
                        ) {
                            selectedCategory = .botanical
                        }

                        CategoryTabButton(
                            category: .utensils,
                            isSelected: selectedCategory == .utensils
                        ) {
                            selectedCategory = .utensils
                        }

                        CategoryTabButton(
                            category: .icons,
                            isSelected: selectedCategory == .icons
                        ) {
                            selectedCategory = .icons
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                // Sticker grid
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(filteredStickers, id: \.id) { sticker in
                            StickerGridItem(sticker: sticker) {
                                onStickerSelected(sticker)
                                dismiss()
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Sticker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFavoritesOnly.toggle()
                    } label: {
                        Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    private var filteredStickers: [StickerAsset] {
        allStickers
            .filter { $0.category == selectedCategory }
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) || $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } }
            .filter { !showFavoritesOnly || isFavorite($0) }
    }

    private func isFavorite(_ sticker: StickerAsset) -> Bool {
        // TODO: Check favorites list
        false
    }
}
```

### 4.3 AnnotationToolbar
**Purpose**: Toolbar for drawing, text, and annotation tools

```swift
import SwiftUI

struct AnnotationToolbar: View {
    @Binding var selectedTool: AnnotationTool
    @Binding var strokeColor: Color
    @Binding var strokeWidth: Double
    @Binding var isErasing: Bool

    let onAddSticker: () -> Void
    let onAddText: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let canUndo: Bool
    let canRedo: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Undo/Redo
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!canUndo)

            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!canRedo)

            Divider()

            // Tools
            ToolButton(
                tool: .draw,
                isSelected: selectedTool == .draw,
                icon: "pencil.tip"
            ) {
                selectedTool = .draw
                isErasing = false
            }

            ToolButton(
                tool: .erase,
                isSelected: isErasing,
                icon: "eraser"
            ) {
                isErasing.toggle()
            }

            Button(action: onAddSticker) {
                Image(systemName: "face.smiling")
            }

            Button(action: onAddText) {
                Image(systemName: "textformat")
            }

            Divider()

            // Stroke settings
            ColorPicker("", selection: $strokeColor)
                .labelsHidden()
                .frame(width: 30, height: 30)

            Slider(value: $strokeWidth, in: 1...10)
                .frame(width: 80)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

enum AnnotationTool {
    case select
    case draw
    case text
    case shape
}

struct ToolButton: View {
    let tool: AnnotationTool
    let isSelected: Bool
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isSelected ? .blue : .primary)
                .padding(8)
                .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
                .cornerRadius(8)
        }
    }
}
```

---

## 5. Implementation Phases

### Phase 1: Foundation (Week 1)
**Goal**: Set up data models, core services, and basic rendering

#### Tasks:
- [ ] Create `Customization` SwiftData model
- [ ] Create `StickerAsset` SwiftData model
- [ ] Create `CustomizationType` and `CustomizationContent` enums
- [ ] Extend CRDT `RecipeOperation` with customization operations
- [ ] Create `CardCustomizationService` with basic add/modify/delete
- [ ] Create `CustomizationOverlayView` with basic rendering
- [ ] Add customization operations to `UndoService`
- [ ] Unit tests for models and basic service operations

**Deliverable**: Can add/remove basic customizations programmatically

---

### Phase 2: Sticker System (Week 2)
**Goal**: Implement complete sticker library and selection UI

#### Tasks:
- [ ] Create `StickerLibraryService`
- [ ] Design and create initial 50+ sticker assets (SVG)
  - 15 vintage kitchen items
  - 10 decorative borders/flourishes
  - 10 botanical elements
  - 10 utensils
  - 5 icons (hearts, stars, etc.)
- [ ] Create `StickerPickerView` with category browsing
- [ ] Implement sticker rendering with SVG support
- [ ] Add sticker tinting/coloring support
- [ ] Implement drag-and-drop sticker placement
- [ ] Add resize/rotate gestures for stickers
- [ ] Create favorites system
- [ ] Unit tests for sticker library

**Deliverable**: Full sticker browsing and placement experience

---

### Phase 3: Drawing & Annotations (Week 3)
**Goal**: Implement freehand drawing and text annotations

#### Tasks:
- [ ] Create `AnnotationEngine` service
- [ ] Implement drawing path capture with touch tracking
- [ ] Add Catmull-Rom spline smoothing for drawing paths
- [ ] Create drawing canvas overlay view
- [ ] Implement PencilKit integration for Apple Pencil support
- [ ] Add stroke color/width picker
- [ ] Create text annotation placement and editing
- [ ] Add eraser tool
- [ ] Implement shape drawing (hearts, stars, arrows)
- [ ] Unit tests for path smoothing algorithms

**Deliverable**: Full drawing and annotation capabilities

---

### Phase 4: Advanced Interactions (Week 4)
**Goal**: Polish interactions, selection, and manipulation

#### Tasks:
- [ ] Create `SelectionHandlesView` with corner/edge handles
- [ ] Implement multi-touch gestures (pinch-zoom, rotate)
- [ ] Add selection state management
- [ ] Implement layer reordering (bring to front, send to back)
- [ ] Create delete confirmation UI
- [ ] Add haptic feedback for interactions
- [ ] Implement snap-to-grid and alignment guides
- [ ] Add batch operations (select multiple, group move)
- [ ] Performance optimization for complex customizations
- [ ] Accessibility support (VoiceOver descriptions)

**Deliverable**: Polished, intuitive customization experience

---

### Phase 5: CRDT Sync & Collaboration (Week 5)
**Goal**: Enable multi-device sync and real-time collaboration

#### Tasks:
- [ ] Implement CRDT operations for all customization types
- [ ] Add customization sync to `FirebaseRecipeSync`
- [ ] Create conflict resolution for concurrent edits
- [ ] Implement real-time listeners for collaborative editing
- [ ] Add "other user cursors" indicators
- [ ] Create presence system (show who's editing)
- [ ] Implement optimistic updates with rollback
- [ ] Add offline queue for customization changes
- [ ] Stress test with multiple concurrent editors
- [ ] Integration tests for sync scenarios

**Deliverable**: Reliable multi-device sync and collaboration

---

### Phase 6: Photo Overlays & Advanced Features (Week 6)
**Goal**: Add photo customizations and premium features

#### Tasks:
- [ ] Implement photo picker integration
- [ ] Add photo cropping/masking for card placement
- [ ] Create opacity/blend mode controls
- [ ] Implement custom sticker import
- [ ] Add premium sticker packs (gated behind paywall)
- [ ] Create "save as template" feature
- [ ] Implement customization presets/themes
- [ ] Add "copy customizations" between recipes
- [ ] Create share sheet for customized cards
- [ ] Performance profiling and optimization

**Deliverable**: Complete feature set with premium options

---

## 6. Testing Strategy

### 6.1 Unit Tests
```swift
// CardCustomizationServiceTests.swift
@MainActor
final class CardCustomizationServiceTests: XCTestCase {
    var service: CardCustomizationService!
    var mockContext: ModelContext!

    override func setUp() async throws {
        let container = ServiceContainer(forTesting: true)
        service = container.resolve(CardCustomizationService.self)
        mockContext = createTestModelContext()
    }

    func testAddSticker() async throws {
        let recipeId = UUID()
        let customization = try await service.addSticker(
            to: recipeId,
            stickerAssetId: "vintage_spoon",
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.2, height: 0.15),
            tintColor: nil,
            context: mockContext
        )

        XCTAssertEqual(customization.type, .sticker)
        XCTAssertEqual(customization.recipeId, recipeId)
        XCTAssertFalse(customization.isDeleted)
    }

    func testMoveCustomization() async throws {
        // Test moving customization and verify CRDT operation
    }

    func testDeleteCustomization() async throws {
        // Test soft delete and CRDT tombstone
    }

    func testLayerOrdering() async throws {
        // Test z-index management
    }
}

// AnnotationEngineTests.swift
@MainActor
final class AnnotationEngineTests: XCTestCase {
    var engine: AnnotationEngine!

    func testPathSmoothing() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 5),
            CGPoint(x: 20, y: 10),
            CGPoint(x: 30, y: 8)
        ]

        let smoothed = engine.smoothPath(points)
        XCTAssertTrue(smoothed.smoothed)
        XCTAssertGreaterThan(smoothed.points.count, points.count)
    }
}
```

### 6.2 Integration Tests
```swift
// CustomizationSyncTests.swift
@MainActor
final class CustomizationSyncTests: XCTestCase {
    func testStickerSyncBetweenDevices() async throws {
        // Device A adds sticker
        // Device B receives sync
        // Verify sticker appears on Device B
    }

    func testConcurrentEditConflictResolution() async throws {
        // Device A moves sticker to position (0.5, 0.5)
        // Device B moves same sticker to (0.6, 0.6)
        // Verify CRDT LWW resolution
    }

    func testOfflineCustomizationQueue() async throws {
        // Add customizations while offline
        // Reconnect and verify sync
    }
}
```

### 6.3 UI Tests
```swift
// CustomizationUITests.swift
final class CustomizationUITests: XCTestCase {
    func testAddStickerFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Navigate to recipe
        // Tap customize button
        // Select sticker from picker
        // Verify sticker appears on card
    }

    func testDrawingFlow() throws {
        // Enter drawing mode
        // Draw path on card
        // Verify path renders
        // Undo and verify path removed
    }

    func testGestureManipulation() throws {
        // Add sticker
        // Drag to new position
        // Pinch to resize
        // Rotate gesture
        // Verify all transformations applied
    }
}
```

### 6.4 Performance Tests
```swift
// CustomizationPerformanceTests.swift
final class CustomizationPerformanceTests: XCTestCase {
    func testRenderingPerformanceWithManyCustomizations() {
        // Add 100 customizations
        // Measure rendering time
        // Assert < 16ms (60fps)
    }

    func testSmoothingPerformance() {
        // Measure path smoothing with 1000 points
        // Assert < 50ms
    }
}
```

---

## 7. Asset Requirements

### 7.1 Sticker Assets (SVG)
**Total Required**: 50+ stickers in initial release

#### Vintage Kitchen (15 stickers)
- Rolling pin
- Whisk
- Stand mixer
- Wooden spoon
- Measuring cups
- Mixing bowl
- Cookie cutter
- Pastry brush
- Sifter
- Vintage scale
- Mortar and pestle
- Vintage oven
- Apron
- Recipe book
- Kitchen timer

#### Decorative (10 stickers)
- Corner flourishes (4 styles)
- Border patterns (3 styles)
- Divider lines (3 styles)

#### Botanical (10 stickers)
- Rosemary sprig
- Basil leaves
- Thyme
- Parsley
- Sage
- Lavender
- Bay leaves
- Lemon
- Garlic bulb
- Tomato vine

#### Utensils (10 stickers)
- Fork
- Spoon
- Knife
- Chef's knife
- Ladle
- Spatula
- Tongs
- Peeler
- Grater
- Colander

#### Icons (5 stickers)
- Heart (solid)
- Heart (outline)
- Star
- Checkmark
- Ribbon banner

### 7.2 Design Specifications
- **Format**: SVG for resolution independence
- **Fallback**: PNG @3x for compatibility
- **Style**: Vintage, hand-drawn aesthetic
- **Colors**: Black outlines, support for tinting
- **Size**: Optimized for mobile (< 5KB per SVG)

---

## 8. API Reference

### 8.1 Service Registration
```swift
// Add to ServiceRegistration.swift

// MARK: - Customization Services

register(CardCustomizationService.self, lifecycle: .singleton) { container in
    let undoService = container.resolve(UndoService.self)
    let imageStorage = container.resolve(ImageStorageService.self)
    let logger = container.resolve(LoggingService.self)
    return CardCustomizationService(
        undoService: undoService,
        imageStorage: imageStorage,
        logger: logger
    )
}

register(StickerLibraryService.self, lifecycle: .singleton) { container in
    let imageStorage = container.resolve(ImageStorageService.self)
    let logger = container.resolve(LoggingService.self)
    return StickerLibraryService(
        imageStorage: imageStorage,
        logger: logger
    )
}

register(AnnotationEngine.self, lifecycle: .singleton) { container in
    let customizationService = container.resolve(CardCustomizationService.self)
    let logger = container.resolve(LoggingService.self)
    return AnnotationEngine(
        customizationService: customizationService,
        logger: logger
    )
}
```

---

## 9. Security & Privacy

### 9.1 User-Generated Content
- **Photo Overlays**: User photos stored in ImageStorageService, not synced by default
- **Custom Stickers**: Users can import images, stored locally only
- **Moderation**: No moderation needed (private content, not shared publicly)

### 9.2 Data Ownership
- All customizations are user-owned
- Can be deleted/exported via standard recipe export
- GDPR compliance: customizations included in user data export

---

## 10. Analytics & Metrics

### 10.1 Usage Tracking
- Customization feature adoption rate
- Most popular sticker categories
- Average customizations per recipe
- Drawing vs. sticker usage ratio
- Time spent in customization mode

### 10.2 Performance Metrics
- Rendering performance (fps during interactions)
- Sync latency for customizations
- Undo/redo operation time
- Sticker picker load time

---

## 11. Future Enhancements

### 11.1 Phase 7+ Ideas
- **AI-Generated Stickers**: User prompt → custom sticker
- **Augmented Reality**: Project recipe card in AR with customizations
- **Video Annotations**: Record video notes as overlays
- **Collaborative Templates**: Share customization templates with community
- **Seasonal Sticker Packs**: Holiday-themed releases
- **Handwriting Recognition**: Convert drawn text to editable text
- **Smart Sticker Suggestions**: AI suggests relevant stickers based on recipe
- **Animation**: Animated stickers (e.g., steam rising from pot)

---

## 12. Dependencies & Prerequisites

### Required:
- SwiftData (iOS 17+)
- SwiftUI
- Existing CRDT infrastructure (VectorClock, OperationLog)
- Existing UndoService
- ImageStorageService
- Firebase sync services

### New Dependencies:
- PencilKit (for Apple Pencil drawing)
- SVG rendering library (consider SwiftSVG or inline rendering)

### Asset Requirements:
- Design team to create initial 50+ sticker assets
- Asset catalog setup for stickers
- Fallback PNG assets for older devices

---

## 13. Success Criteria

### MVP Launch Criteria:
- [ ] 50+ stickers across 5 categories
- [ ] Sticker picker with search and favorites
- [ ] Drag-drop sticker placement
- [ ] Resize and rotate gestures
- [ ] Freehand drawing with smoothing
- [ ] Text annotations
- [ ] Layer management (z-order)
- [ ] Full undo/redo support
- [ ] CRDT sync for multi-device
- [ ] 60fps rendering performance
- [ ] < 100ms sync latency
- [ ] Zero data loss during sync conflicts
- [ ] Accessibility support (VoiceOver)
- [ ] 95%+ crash-free sessions
- [ ] < 5% of users report sync issues

### User Satisfaction:
- Target: 30% of users customize at least one recipe
- Target: 4.5+ star feature rating
- Target: < 1% support tickets related to customization

---

## 14. Timeline Summary

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Phase 1: Foundation | Week 1 | Basic customization infrastructure |
| Phase 2: Stickers | Week 2 | Full sticker system with 50+ assets |
| Phase 3: Drawing | Week 3 | Freehand drawing and text annotations |
| Phase 4: Interactions | Week 4 | Polished UX with gestures |
| Phase 5: Sync | Week 5 | Multi-device collaboration |
| Phase 6: Advanced | Week 6 | Photo overlays and premium features |

**Total**: 6 weeks to MVP

---

## 15. Risks & Mitigations

### Risk 1: Performance with Complex Customizations
**Impact**: High
**Probability**: Medium
**Mitigation**:
- Implement layer culling for off-screen customizations
- Use Metal for SVG rendering if needed
- Lazy loading for sticker assets
- Performance profiling at each phase

### Risk 2: CRDT Sync Conflicts
**Impact**: High
**Probability**: Low
**Mitigation**:
- Comprehensive integration tests for conflict scenarios
- LWW (Last-Write-Wins) with Lamport timestamps
- Optimistic updates with automatic rollback
- Clear conflict resolution rules documented

### Risk 3: Asset Creation Bottleneck
**Impact**: Medium
**Probability**: Medium
**Mitigation**:
- Start asset creation in parallel with Phase 1
- Use placeholder assets during development
- Consider outsourcing to design agency if needed
- MVP with 30 stickers acceptable, expand post-launch

### Risk 4: Apple Pencil Integration Complexity
**Impact**: Low
**Probability**: Low
**Mitigation**:
- PencilKit provides 90% of functionality
- Fallback to touch-based drawing if PencilKit fails
- Test on physical devices early

---

## Appendix A: Glossary

- **CRDT**: Conflict-free Replicated Data Type - allows concurrent edits without conflicts
- **Lamport Timestamp**: Logical clock for ordering distributed events
- **Vector Clock**: Tracks causal relationships between operations
- **LWW**: Last-Write-Wins conflict resolution strategy
- **Z-Index**: Layer ordering (higher = rendered on top)
- **Normalized Coordinates**: Position/size as 0-1 ratios relative to card dimensions
- **Soft Delete**: Mark as deleted without removing from database (for CRDT)
- **Catmull-Rom Spline**: Smoothing algorithm for drawing paths

---

## Appendix B: Code Examples

### Example: Adding a Sticker to a Recipe
```swift
@MainActor
func addVintageSpoonSticker() async {
    guard let recipe = selectedRecipe else { return }

    let customizationService = ServiceContainer.shared.resolve(CardCustomizationService.self)

    do {
        let sticker = try await customizationService.addSticker(
            to: recipe.id,
            stickerAssetId: "vintage_spoon",
            position: CGPoint(x: 0.8, y: 0.2),  // Top-right corner
            size: CGSize(width: 0.15, height: 0.12),
            tintColor: "#8B4513",  // Saddle brown
            context: modelContext
        )

        print("Sticker added: \(sticker.id)")
    } catch {
        print("Failed to add sticker: \(error)")
    }
}
```

### Example: Drawing on a Recipe
```swift
@MainActor
func handleDrawingGesture(points: [CGPoint]) async {
    let annotationEngine = ServiceContainer.shared.resolve(AnnotationEngine.self)

    // Smooth the path
    let smoothedPath = annotationEngine.smoothPath(points)

    // Create drawing customization
    let customizationService = ServiceContainer.shared.resolve(CardCustomizationService.self)

    do {
        let drawing = try await customizationService.addDrawing(
            to: recipe.id,
            path: smoothedPath,
            strokeColor: "#000000",
            strokeWidth: 2.0,
            position: .zero,  // Path already has absolute positions
            context: modelContext
        )

        print("Drawing added: \(drawing.id)")
    } catch {
        print("Failed to add drawing: \(error)")
    }
}
```

---

## Appendix C: Firebase Schema

### Firestore Collection: `customizations`
```json
{
  "id": "uuid",
  "recipeId": "uuid",
  "userId": "firebase_uid",
  "deviceId": "device_uuid",
  "type": "sticker | drawing | text | photo | shape",
  "position": {
    "x": 0.5,
    "y": 0.3
  },
  "size": {
    "width": 0.2,
    "height": 0.15
  },
  "rotation": 0.0,
  "zIndex": 1,
  "content": {
    "sticker": {
      "assetId": "vintage_spoon",
      "tintColor": "#8B4513"
    }
  },
  "createdAt": "timestamp",
  "modifiedAt": "timestamp",
  "isDeleted": false,
  "vectorClock": {
    "clocks": {
      "device_1": 42,
      "device_2": 38
    },
    "lastUpdated": "timestamp"
  },
  "lamportTimestamp": 1234567890
}
```

---

**End of Card Customization Service Plan**

This plan is ready for implementation. Proceed with Phase 1 to establish the foundation, then iterate through subsequent phases. Each phase builds on the previous, allowing for incremental delivery and testing.
