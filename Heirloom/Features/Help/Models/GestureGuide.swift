import SwiftUI

// MARK: - Gesture Guide
/// Comprehensive guide to all gestures available in Heirloom
struct GestureGuide {
    // MARK: - Gesture Categories
    let categories: [GestureCategory] = [
        .recipeList,
        .recipeDetail,
        .shoppingList,
        .cardPersonalization,
        .general
    ]

    // MARK: - All Gestures
    var allGestures: [Gesture] {
        categories.flatMap { $0.gestures }
    }

    // MARK: - Search
    func search(_ query: String) -> [Gesture] {
        let lowercaseQuery = query.lowercased()
        return allGestures.filter { gesture in
            gesture.name.lowercased().contains(lowercaseQuery) ||
            gesture.description.lowercased().contains(lowercaseQuery) ||
            gesture.category.rawValue.lowercased().contains(lowercaseQuery)
        }
    }
}

// MARK: - Gesture Category
enum GestureCategory: String, CaseIterable, Identifiable {
    case recipeList = "Recipe List"
    case recipeDetail = "Recipe Detail"
    case shoppingList = "Shopping List"
    case cardPersonalization = "Card Personalization"
    case general = "General"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .recipeList: return "square.grid.2x2"
        case .recipeDetail: return "doc.text"
        case .shoppingList: return "cart"
        case .cardPersonalization: return "paintbrush"
        case .general: return "hand.tap"
        }
    }

    var gestures: [Gesture] {
        switch self {
        case .recipeList:
            return [
                Gesture(
                    name: "Pull to Refresh",
                    gestureType: .swipe,
                    description: "Pull down on the recipe list to sync with CloudKit and refresh your recipes",
                    category: .recipeList,
                    icon: "arrow.down.circle"
                ),
                Gesture(
                    name: "Long Press Recipe Card",
                    gestureType: .longPress,
                    description: "Long press any recipe card to see quick actions: Add to Favorites, Add to Shopping List, or Delete",
                    category: .recipeList,
                    icon: "hand.point.up.left"
                ),
                Gesture(
                    name: "Tap Recipe Card",
                    gestureType: .tap,
                    description: "Tap any recipe card to view its full details",
                    category: .recipeList,
                    icon: "hand.tap"
                )
            ]

        case .recipeDetail:
            return [
                Gesture(
                    name: "Tap to Flip Card",
                    gestureType: .tap,
                    description: "Tap the recipe card to flip between front (photo) and back (notes, lineage, ratings)",
                    category: .recipeDetail,
                    icon: "arrow.triangle.2.circlepath"
                ),
                Gesture(
                    name: "Flip Button",
                    gestureType: .tap,
                    description: "Tap the flip button in the top-right corner to flip the recipe card with animation",
                    category: .recipeDetail,
                    icon: "arrow.2.squarepath"
                ),
                Gesture(
                    name: "Swipe to Delete Ingredient",
                    gestureType: .swipe,
                    description: "Swipe left on any ingredient to delete it from the recipe",
                    category: .recipeDetail,
                    icon: "arrow.left.circle"
                ),
                Gesture(
                    name: "Drag to Reorder",
                    gestureType: .drag,
                    description: "Long press and drag ingredients or instructions to reorder them",
                    category: .recipeDetail,
                    icon: "arrow.up.arrow.down"
                )
            ]

        case .shoppingList:
            return [
                Gesture(
                    name: "Tap to Check Off",
                    gestureType: .tap,
                    description: "Tap any ingredient to check it off your shopping list",
                    category: .shoppingList,
                    icon: "checkmark.circle"
                ),
                Gesture(
                    name: "Long Press Recipe",
                    gestureType: .longPress,
                    description: "Long press a recipe in your shopping list to remove it or hide/show its items",
                    category: .shoppingList,
                    icon: "hand.point.up.left"
                ),
                Gesture(
                    name: "Long Press Ingredient",
                    gestureType: .longPress,
                    description: "Long press an ingredient to check/uncheck, view recipes using it, or copy to clipboard",
                    category: .shoppingList,
                    icon: "doc.on.doc"
                ),
                Gesture(
                    name: "Tap Recipe Checkbox",
                    gestureType: .tap,
                    description: "Tap the checkbox next to a recipe to show or hide its ingredients in the list",
                    category: .shoppingList,
                    icon: "checkmark.square"
                )
            ]

        case .cardPersonalization:
            return [
                Gesture(
                    name: "Tap to Select",
                    gestureType: .tap,
                    description: "Tap color swatches, patterns, or options to select them",
                    category: .cardPersonalization,
                    icon: "hand.tap"
                ),
                Gesture(
                    name: "Drag Stickers",
                    gestureType: .drag,
                    description: "Drag stickers to position them anywhere on your recipe card",
                    category: .cardPersonalization,
                    icon: "hand.draw"
                ),
                Gesture(
                    name: "Pinch to Resize",
                    gestureType: .pinch,
                    description: "Pinch stickers to resize them on your recipe card",
                    category: .cardPersonalization,
                    icon: "arrow.up.left.and.arrow.down.right"
                ),
                Gesture(
                    name: "Rotate Stickers",
                    gestureType: .rotate,
                    description: "Rotate stickers with two fingers to adjust their angle",
                    category: .cardPersonalization,
                    icon: "arrow.triangle.2.circlepath.circle"
                ),
                Gesture(
                    name: "Long Press to Delete",
                    gestureType: .longPress,
                    description: "Long press a sticker or annotation to delete it from your card",
                    category: .cardPersonalization,
                    icon: "trash"
                )
            ]

        case .general:
            return [
                Gesture(
                    name: "Pull Down to Dismiss",
                    gestureType: .swipe,
                    description: "Pull down on any sheet or modal to dismiss it",
                    category: .general,
                    icon: "arrow.down"
                ),
                Gesture(
                    name: "Swipe Back",
                    gestureType: .swipe,
                    description: "Swipe from the left edge to go back to the previous screen",
                    category: .general,
                    icon: "arrow.backward"
                ),
                Gesture(
                    name: "Tap to Edit",
                    gestureType: .tap,
                    description: "Tap text fields to edit recipe details, notes, or search",
                    category: .general,
                    icon: "square.and.pencil"
                )
            ]
        }
    }
}

// MARK: - Gesture Type
enum GestureType: String, CaseIterable {
    case tap = "Tap"
    case longPress = "Long Press"
    case swipe = "Swipe"
    case drag = "Drag"
    case pinch = "Pinch"
    case rotate = "Rotate"

    var icon: String {
        switch self {
        case .tap: return "hand.tap"
        case .longPress: return "hand.point.up.left"
        case .swipe: return "hand.draw"
        case .drag: return "arrow.up.and.down.and.arrow.left.and.right"
        case .pinch: return "arrow.up.left.and.arrow.down.right"
        case .rotate: return "arrow.triangle.2.circlepath.circle"
        }
    }
}

// MARK: - Gesture Model
struct Gesture: Identifiable {
    let id = UUID()
    let name: String
    let gestureType: GestureType
    let description: String
    let category: GestureCategory
    let icon: String

    var displayTitle: String {
        "\(gestureType.rawValue): \(name)"
    }
}
