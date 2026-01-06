import Foundation
import SwiftUI

// MARK: - Card Style Action Protocol
/// Protocol for all undoable card styling actions
protocol CardStyleAction {
    /// Human-readable description of the action (e.g., "Change Background Color")
    var description: String { get }

    /// Execute the action (apply the change)
    func execute(on style: inout RecipeCardStyle)

    /// Reverse the action (undo the change)
    func undo(on style: inout RecipeCardStyle)
}

// MARK: - Card Style Undo Manager
/// Manages undo/redo stack for card styling actions
/// Maximum history: 20 actions
@MainActor
class CardStyleUndoManager: ObservableObject {
    // MARK: - Published State
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false
    @Published private(set) var undoDescription: String?
    @Published private(set) var redoDescription: String?

    // MARK: - Dependencies

    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }

    // MARK: - Private State
    private var undoStack: [CardStyleAction] = []
    private var redoStack: [CardStyleAction] = []
    private let maxHistorySize = 20

    // MARK: - Execute Action
    /// Execute an action and add it to the undo stack
    func execute(_ action: CardStyleAction, on style: inout RecipeCardStyle) {
        // Execute the action
        action.execute(on: &style)

        // Add to undo stack
        undoStack.append(action)

        // Limit history size
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }

        // Clear redo stack (new action invalidates redo history)
        redoStack.removeAll()

        // Update state
        updateState()

        // Track analytics
        analytics.track(event: .featureUsed, properties: [
            "feature": "card_styling",
            "action": action.description,
            "undo_stack_size": undoStack.count
        ])
    }

    // MARK: - Undo
    /// Undo the most recent action
    func undo(on style: inout RecipeCardStyle) {
        guard let action = undoStack.popLast() else { return }

        // Undo the action
        action.undo(on: &style)

        // Move to redo stack
        redoStack.append(action)

        // Update state
        updateState()

        // Track analytics
        analytics.track(event: .featureUsed, properties: [
            "feature": "undo",
            "action": action.description,
            "undo_stack_size": undoStack.count
        ])
    }

    // MARK: - Redo
    /// Redo the most recently undone action
    func redo(on style: inout RecipeCardStyle) {
        guard let action = redoStack.popLast() else { return }

        // Execute the action again
        action.execute(on: &style)

        // Move back to undo stack
        undoStack.append(action)

        // Update state
        updateState()

        // Track analytics
        analytics.track(event: .featureUsed, properties: [
            "feature": "redo",
            "action": action.description,
            "redo_stack_size": redoStack.count
        ])
    }

    // MARK: - Clear History
    /// Clear all undo/redo history
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateState()
    }

    // MARK: - Private Helpers
    private func updateState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
        undoDescription = undoStack.last?.description
        redoDescription = redoStack.last?.description
    }
}

// MARK: - Background Actions

/// Change card background color
struct ChangeBackgroundColorAction: CardStyleAction {
    let oldColor: Color
    let newColor: Color

    var description: String { "Change Background Color" }

    func execute(on style: inout RecipeCardStyle) {
        style.backgroundColor = newColor
    }

    func undo(on style: inout RecipeCardStyle) {
        style.backgroundColor = oldColor
    }
}

/// Change background style
struct ChangeBackgroundStyleAction: CardStyleAction {
    let oldStyle: CardBackgroundStyle
    let newStyle: CardBackgroundStyle

    var description: String { "Change Background Style" }

    func execute(on style: inout RecipeCardStyle) {
        style.backgroundStyle = newStyle
    }

    func undo(on style: inout RecipeCardStyle) {
        style.backgroundStyle = oldStyle
    }
}

// MARK: - Sticker Actions

/// Add sticker
struct AddStickerAction: CardStyleAction {
    let sticker: RecipeCardSticker

    var description: String { "Add Sticker" }

    func execute(on style: inout RecipeCardStyle) {
        style.stickers.append(sticker)
    }

    func undo(on style: inout RecipeCardStyle) {
        style.stickers.removeAll { $0.id == sticker.id }
    }
}

/// Remove sticker
struct RemoveStickerAction: CardStyleAction {
    let sticker: RecipeCardSticker
    let index: Int

    var description: String { "Remove Sticker" }

    func execute(on style: inout RecipeCardStyle) {
        style.stickers.removeAll { $0.id == sticker.id }
    }

    func undo(on style: inout RecipeCardStyle) {
        if index < style.stickers.count {
            style.stickers.insert(sticker, at: index)
        } else {
            style.stickers.append(sticker)
        }
    }
}

/// Update sticker position
struct UpdateStickerPositionAction: CardStyleAction {
    let stickerId: UUID
    let oldPosition: CGPoint
    let newPosition: CGPoint

    var description: String { "Move Sticker" }

    func execute(on style: inout RecipeCardStyle) {
        if let index = style.stickers.firstIndex(where: { $0.id == stickerId }) {
            style.stickers[index].position = newPosition
        }
    }

    func undo(on style: inout RecipeCardStyle) {
        if let index = style.stickers.firstIndex(where: { $0.id == stickerId }) {
            style.stickers[index].position = oldPosition
        }
    }
}

/// Update sticker scale
struct UpdateStickerScaleAction: CardStyleAction {
    let stickerId: UUID
    let oldScale: CGFloat
    let newScale: CGFloat

    var description: String { "Resize Sticker" }

    func execute(on style: inout RecipeCardStyle) {
        if let index = style.stickers.firstIndex(where: { $0.id == stickerId }) {
            style.stickers[index].scale = newScale
        }
    }

    func undo(on style: inout RecipeCardStyle) {
        if let index = style.stickers.firstIndex(where: { $0.id == stickerId }) {
            style.stickers[index].scale = oldScale
        }
    }
}

/// Update sticker rotation
struct UpdateStickerRotationAction: CardStyleAction {
    let stickerId: UUID
    let oldRotation: Double
    let newRotation: Double

    var description: String { "Rotate Sticker" }

    func execute(on style: inout RecipeCardStyle) {
        if let index = style.stickers.firstIndex(where: { $0.id == stickerId }) {
            style.stickers[index].rotation = newRotation
        }
    }

    func undo(on style: inout RecipeCardStyle) {
        if let index = style.stickers.firstIndex(where: { $0.id == stickerId }) {
            style.stickers[index].rotation = oldRotation
        }
    }
}

// MARK: - Annotation Actions

/// Add annotation
struct AddAnnotationAction: CardStyleAction {
    let annotation: RecipeCardAnnotation

    var description: String { "Add Note" }

    func execute(on style: inout RecipeCardStyle) {
        style.annotations.append(annotation)
    }

    func undo(on style: inout RecipeCardStyle) {
        style.annotations.removeAll { $0.id == annotation.id }
    }
}

/// Remove annotation
struct RemoveAnnotationAction: CardStyleAction {
    let annotation: RecipeCardAnnotation
    let index: Int

    var description: String { "Remove Note" }

    func execute(on style: inout RecipeCardStyle) {
        style.annotations.removeAll { $0.id == annotation.id }
    }

    func undo(on style: inout RecipeCardStyle) {
        if index < style.annotations.count {
            style.annotations.insert(annotation, at: index)
        } else {
            style.annotations.append(annotation)
        }
    }
}

/// Update annotation text
struct UpdateAnnotationTextAction: CardStyleAction {
    let annotationId: UUID
    let oldText: String
    let newText: String

    var description: String { "Edit Note" }

    func execute(on style: inout RecipeCardStyle) {
        if let index = style.annotations.firstIndex(where: { $0.id == annotationId }) {
            style.annotations[index].text = newText
        }
    }

    func undo(on style: inout RecipeCardStyle) {
        if let index = style.annotations.firstIndex(where: { $0.id == annotationId }) {
            style.annotations[index].text = oldText
        }
    }
}

// MARK: - Love Marks Actions

/// Toggle coffee stain
struct ToggleCoffeeStainAction: CardStyleAction {
    let oldValue: Bool
    let newValue: Bool

    var description: String { newValue ? "Add Coffee Stain" : "Remove Coffee Stain" }

    func execute(on style: inout RecipeCardStyle) {
        style.hasCoffeeStain = newValue
    }

    func undo(on style: inout RecipeCardStyle) {
        style.hasCoffeeStain = oldValue
    }
}

/// Change coffee stain position
struct ChangeCoffeeStainPositionAction: CardStyleAction {
    let oldPosition: CoffeeStainPosition
    let newPosition: CoffeeStainPosition

    var description: String { "Move Coffee Stain" }

    func execute(on style: inout RecipeCardStyle) {
        style.coffeeStainPosition = newPosition
    }

    func undo(on style: inout RecipeCardStyle) {
        style.coffeeStainPosition = oldPosition
    }
}

/// Change worn edges intensity
struct ChangeWornEdgesAction: CardStyleAction {
    let oldIntensity: Double
    let newIntensity: Double

    var description: String { "Adjust Worn Edges" }

    func execute(on style: inout RecipeCardStyle) {
        style.wornEdgesIntensity = newIntensity
    }

    func undo(on style: inout RecipeCardStyle) {
        style.wornEdgesIntensity = oldIntensity
    }
}

/// Toggle auto love marks
struct ToggleAutoLoveMarksAction: CardStyleAction {
    let oldValue: Bool
    let newValue: Bool

    var description: String { newValue ? "Enable Auto Love Marks" : "Disable Auto Love Marks" }

    func execute(on style: inout RecipeCardStyle) {
        style.autoGenerateLoveMarks = newValue
    }

    func undo(on style: inout RecipeCardStyle) {
        style.autoGenerateLoveMarks = oldValue
    }
}

// MARK: - Card Back Actions

/// Change card back style
struct ChangeCardBackStyleAction: CardStyleAction {
    let oldStyle: CardBackgroundStyle
    let newStyle: CardBackgroundStyle

    var description: String { "Change Card Back Style" }

    func execute(on style: inout RecipeCardStyle) {
        style.cardBackStyle = newStyle
    }

    func undo(on style: inout RecipeCardStyle) {
        style.cardBackStyle = oldStyle
    }
}
