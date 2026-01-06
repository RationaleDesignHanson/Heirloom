//
//  StickerLibraryService.swift
//  Heirloom
//
//  Created by Claude on 1/5/26.
//

import Foundation
import SwiftData
import SwiftUI

/// Protocol defining sticker library operations
@MainActor
protocol StickerLibraryServiceProtocol {
    // MARK: - Initialization
    func initializeDefaultLibrary(context: ModelContext) async throws

    // MARK: - Fetch Stickers
    func fetchAllStickers(context: ModelContext) throws -> [StickerAsset]
    func fetchStickers(category: StickerCategory, context: ModelContext) throws -> [StickerAsset]
    func fetchFavoriteStickers(context: ModelContext) throws -> [StickerAsset]
    func fetchRecentlyUsedStickers(limit: Int, context: ModelContext) throws -> [StickerAsset]
    func searchStickers(query: String, context: ModelContext) throws -> [StickerAsset]

    // MARK: - Sticker Details
    func getSticker(id: String, context: ModelContext) throws -> StickerAsset?

    // MARK: - User Preferences
    func toggleFavorite(stickerId: String, context: ModelContext) async throws
    func incrementUseCount(stickerId: String, context: ModelContext) async throws

    // MARK: - Custom Stickers
    func importCustomSticker(
        name: String,
        imageData: Data,
        category: StickerCategory,
        supportsTinting: Bool,
        context: ModelContext
    ) async throws -> StickerAsset

    func deleteCustomSticker(id: String, context: ModelContext) async throws
}

/// Service for managing the sticker library
@MainActor
final class StickerLibraryService: ObservableObject, StickerLibraryServiceProtocol {
    // MARK: - State
    @Published private(set) var isLibraryInitialized = false

    // MARK: - Constants
    private static let defaultLibraryKey = "StickerLibraryInitialized_v1"

    // MARK: - Initialization

    func initializeDefaultLibrary(context: ModelContext) async throws {
        // Check if already initialized
        if UserDefaults.standard.bool(forKey: Self.defaultLibraryKey) {
            Log.info("Sticker library already initialized", category: .database)
            isLibraryInitialized = true
            return
        }

        Log.info("Initializing default sticker library", category: .database)

        // Create default stickers
        let defaultStickers = createDefaultStickerLibrary()

        for sticker in defaultStickers {
            context.insert(sticker)
        }

        try context.save()

        // Mark as initialized
        UserDefaults.standard.set(true, forKey: Self.defaultLibraryKey)
        isLibraryInitialized = true

        Log.info("Default sticker library initialized with \(defaultStickers.count) stickers", category: .database)
    }

    // MARK: - Fetch Stickers

    func fetchAllStickers(context: ModelContext) throws -> [StickerAsset] {
        let descriptor = FetchDescriptor<StickerAsset>(
            predicate: #Predicate<StickerAsset> { $0.isEnabled },
            sortBy: [
                SortDescriptor(\StickerAsset.categoryRawValue),
                SortDescriptor(\StickerAsset.sortOrder)
            ]
        )

        return try context.fetch(descriptor)
    }

    func fetchStickers(category: StickerCategory, context: ModelContext) throws -> [StickerAsset] {
        let categoryRaw = category.rawValue
        let descriptor = FetchDescriptor<StickerAsset>(
            predicate: #Predicate<StickerAsset> { sticker in
                sticker.isEnabled && sticker.categoryRawValue == categoryRaw
            },
            sortBy: [SortDescriptor(\StickerAsset.sortOrder)]
        )

        return try context.fetch(descriptor)
    }

    func fetchFavoriteStickers(context: ModelContext) throws -> [StickerAsset] {
        let descriptor = FetchDescriptor<StickerAsset>(
            predicate: #Predicate<StickerAsset> { sticker in
                sticker.isEnabled && sticker.isFavorited
            },
            sortBy: [SortDescriptor(\StickerAsset.useCount, order: .reverse)]
        )

        return try context.fetch(descriptor)
    }

    func fetchRecentlyUsedStickers(limit: Int = 10, context: ModelContext) throws -> [StickerAsset] {
        let descriptor = FetchDescriptor<StickerAsset>(
            predicate: #Predicate<StickerAsset> { sticker in
                sticker.isEnabled && sticker.useCount > 0
            },
            sortBy: [SortDescriptor(\StickerAsset.useCount, order: .reverse)]
        )

        let allUsed = try context.fetch(descriptor)
        return Array(allUsed.prefix(limit))
    }

    func searchStickers(query: String, context: ModelContext) throws -> [StickerAsset] {
        let allStickers = try fetchAllStickers(context: context)

        if query.isEmpty {
            return allStickers
        }

        return allStickers.filter { $0.matches(searchQuery: query) }
    }

    // MARK: - Sticker Details

    func getSticker(id: String, context: ModelContext) throws -> StickerAsset? {
        let descriptor = FetchDescriptor<StickerAsset>(
            predicate: #Predicate<StickerAsset> { $0.id == id }
        )

        return try context.fetch(descriptor).first
    }

    // MARK: - User Preferences

    func toggleFavorite(stickerId: String, context: ModelContext) async throws {
        guard let sticker = try getSticker(id: stickerId, context: context) else {
            throw StickerLibraryError.stickerNotFound
        }

        sticker.toggleFavorite()
        try context.save()

        Log.debug("Toggled favorite for sticker", category: .database, metadata: [
            "id": stickerId,
            "isFavorited": "\(sticker.isFavorited)"
        ])
    }

    func incrementUseCount(stickerId: String, context: ModelContext) async throws {
        guard let sticker = try getSticker(id: stickerId, context: context) else {
            throw StickerLibraryError.stickerNotFound
        }

        sticker.incrementUseCount()
        try context.save()

        Log.debug("Incremented use count for sticker", category: .database, metadata: [
            "id": stickerId,
            "useCount": "\(sticker.useCount)"
        ])
    }

    // MARK: - Custom Stickers

    func importCustomSticker(
        name: String,
        imageData: Data,
        category: StickerCategory,
        supportsTinting: Bool,
        context: ModelContext
    ) async throws -> StickerAsset {
        Log.info("Importing custom sticker", category: .database, metadata: [
            "name": name,
            "category": category.rawValue
        ])

        // Generate unique ID
        let id = "custom_\(UUID().uuidString)"

        // Create sticker
        let sticker = StickerAsset(
            id: id,
            name: name,
            category: category,
            assetName: id,
            supportsTinting: supportsTinting,
            defaultSize: CGSize(width: 0.15, height: 0.15),
            tags: ["custom"],
            isPremium: false,
            sortOrder: 9999 // Custom stickers at end
        )

        // Store image data
        sticker.previewImageData = imageData
        sticker.svgData = nil // PNG/JPEG only for custom imports

        context.insert(sticker)
        try context.save()

        Log.info("Custom sticker imported successfully", category: .database)
        return sticker
    }

    func deleteCustomSticker(id: String, context: ModelContext) async throws {
        guard id.starts(with: "custom_") else {
            throw StickerLibraryError.cannotDeleteBuiltInSticker
        }

        guard let sticker = try getSticker(id: id, context: context) else {
            throw StickerLibraryError.stickerNotFound
        }

        context.delete(sticker)
        try context.save()

        Log.info("Custom sticker deleted", category: .database, metadata: ["id": id])
    }

    // MARK: - Default Library Creation

    private func createDefaultStickerLibrary() -> [StickerAsset] {
        var stickers: [StickerAsset] = []

        // MARK: - Vintage Category (15 stickers)
        stickers.append(contentsOf: [
            StickerAsset(
                id: "vintage_rolling_pin",
                name: "Rolling Pin",
                category: .vintage,
                assetName: "sticker_rolling_pin",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.25, height: 0.1),
                tags: ["baking", "kitchen", "utensil"],
                sortOrder: 0
            ),
            StickerAsset(
                id: "vintage_stand_mixer",
                name: "Stand Mixer",
                category: .vintage,
                assetName: "sticker_stand_mixer",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.2, height: 0.2),
                tags: ["baking", "appliance", "kitchen"],
                sortOrder: 1
            ),
            StickerAsset(
                id: "vintage_measuring_cups",
                name: "Measuring Cups",
                category: .vintage,
                assetName: "sticker_measuring_cups",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.15, height: 0.15),
                tags: ["measuring", "baking", "kitchen"],
                sortOrder: 2
            ),
            StickerAsset(
                id: "vintage_apron",
                name: "Apron",
                category: .vintage,
                assetName: "sticker_apron",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.15, height: 0.2),
                tags: ["clothing", "kitchen", "cooking"],
                sortOrder: 3
            ),
            StickerAsset(
                id: "vintage_cookbook",
                name: "Cookbook",
                category: .vintage,
                assetName: "sticker_cookbook",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.15, height: 0.18),
                tags: ["book", "recipes", "cooking"],
                sortOrder: 4
            ),
            StickerAsset(
                id: "vintage_coffee_grinder",
                name: "Coffee Grinder",
                category: .vintage,
                assetName: "sticker_coffee_grinder",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.12, height: 0.18),
                tags: ["coffee", "appliance", "kitchen"],
                sortOrder: 5
            ),
            StickerAsset(
                id: "vintage_teapot",
                name: "Teapot",
                category: .vintage,
                assetName: "sticker_teapot",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.18, height: 0.15),
                tags: ["tea", "drink", "kitchen"],
                sortOrder: 6
            ),
            StickerAsset(
                id: "vintage_scale",
                name: "Kitchen Scale",
                category: .vintage,
                assetName: "sticker_scale",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.15, height: 0.15),
                tags: ["measuring", "baking", "kitchen"],
                sortOrder: 7
            ),
            StickerAsset(
                id: "vintage_mixing_bowl",
                name: "Mixing Bowl",
                category: .vintage,
                assetName: "sticker_mixing_bowl",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.18, height: 0.12),
                tags: ["bowl", "baking", "kitchen"],
                sortOrder: 8
            ),
            StickerAsset(
                id: "vintage_pie_dish",
                name: "Pie Dish",
                category: .vintage,
                assetName: "sticker_pie_dish",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.18, height: 0.12),
                tags: ["baking", "pie", "dish"],
                sortOrder: 9
            ),
            StickerAsset(
                id: "vintage_butter_churn",
                name: "Butter Churn",
                category: .vintage,
                assetName: "sticker_butter_churn",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.12, height: 0.2),
                tags: ["butter", "vintage", "kitchen"],
                sortOrder: 10
            ),
            StickerAsset(
                id: "vintage_meat_grinder",
                name: "Meat Grinder",
                category: .vintage,
                assetName: "sticker_meat_grinder",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.15, height: 0.18),
                tags: ["meat", "appliance", "vintage"],
                sortOrder: 11
            ),
            StickerAsset(
                id: "vintage_cookie_jar",
                name: "Cookie Jar",
                category: .vintage,
                assetName: "sticker_cookie_jar",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.15, height: 0.18),
                tags: ["cookies", "jar", "storage"],
                sortOrder: 12
            ),
            StickerAsset(
                id: "vintage_oven_mitt",
                name: "Oven Mitt",
                category: .vintage,
                assetName: "sticker_oven_mitt",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.12, height: 0.15),
                tags: ["baking", "safety", "kitchen"],
                sortOrder: 13
            ),
            StickerAsset(
                id: "vintage_cast_iron",
                name: "Cast Iron Skillet",
                category: .vintage,
                assetName: "sticker_cast_iron",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.2, height: 0.15),
                tags: ["cooking", "pan", "skillet"],
                sortOrder: 14
            )
        ])

        // MARK: - Decorative Category (10 stickers)
        stickers.append(contentsOf: [
            StickerAsset(
                id: "decorative_corner_flourish_tl",
                name: "Corner Flourish (Top Left)",
                category: .decorative,
                assetName: "sticker_corner_tl",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.15, height: 0.15),
                tags: ["border", "corner", "flourish"],
                sortOrder: 0
            ),
            StickerAsset(
                id: "decorative_corner_flourish_tr",
                name: "Corner Flourish (Top Right)",
                category: .decorative,
                assetName: "sticker_corner_tr",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.15, height: 0.15),
                tags: ["border", "corner", "flourish"],
                sortOrder: 1
            ),
            StickerAsset(
                id: "decorative_divider_line",
                name: "Decorative Divider",
                category: .decorative,
                assetName: "sticker_divider",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.4, height: 0.05),
                tags: ["divider", "line", "separator"],
                sortOrder: 2
            ),
            StickerAsset(
                id: "decorative_banner_ribbon",
                name: "Banner Ribbon",
                category: .decorative,
                assetName: "sticker_banner",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.3, height: 0.1),
                tags: ["banner", "ribbon", "label"],
                sortOrder: 3
            ),
            StickerAsset(
                id: "decorative_frame_oval",
                name: "Oval Frame",
                category: .decorative,
                assetName: "sticker_frame_oval",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.25, height: 0.3),
                tags: ["frame", "border", "oval"],
                sortOrder: 4
            ),
            StickerAsset(
                id: "decorative_frame_scalloped",
                name: "Scalloped Frame",
                category: .decorative,
                assetName: "sticker_frame_scalloped",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.25, height: 0.3),
                tags: ["frame", "border", "scalloped"],
                sortOrder: 5
            ),
            StickerAsset(
                id: "decorative_swirl_left",
                name: "Swirl (Left)",
                category: .decorative,
                assetName: "sticker_swirl_left",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.12, height: 0.12),
                tags: ["flourish", "swirl", "decorative"],
                sortOrder: 6
            ),
            StickerAsset(
                id: "decorative_swirl_right",
                name: "Swirl (Right)",
                category: .decorative,
                assetName: "sticker_swirl_right",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.12, height: 0.12),
                tags: ["flourish", "swirl", "decorative"],
                sortOrder: 7
            ),
            StickerAsset(
                id: "decorative_laurel_wreath",
                name: "Laurel Wreath",
                category: .decorative,
                assetName: "sticker_laurel_wreath",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.25, height: 0.25),
                tags: ["wreath", "laurel", "frame"],
                sortOrder: 8
            ),
            StickerAsset(
                id: "decorative_rope_border",
                name: "Rope Border",
                category: .decorative,
                assetName: "sticker_rope_border",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.4, height: 0.05),
                tags: ["border", "rope", "decorative"],
                sortOrder: 9
            )
        ])

        // MARK: - Botanical Category (10 stickers)
        stickers.append(contentsOf: [
            StickerAsset(
                id: "botanical_basil",
                name: "Basil",
                category: .botanical,
                assetName: "sticker_basil",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.12, height: 0.15),
                tags: ["herb", "basil", "plant"],
                sortOrder: 0
            ),
            StickerAsset(
                id: "botanical_rosemary",
                name: "Rosemary",
                category: .botanical,
                assetName: "sticker_rosemary",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.08, height: 0.18),
                tags: ["herb", "rosemary", "plant"],
                sortOrder: 1
            ),
            StickerAsset(
                id: "botanical_thyme",
                name: "Thyme",
                category: .botanical,
                assetName: "sticker_thyme",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.1, height: 0.15),
                tags: ["herb", "thyme", "plant"],
                sortOrder: 2
            ),
            StickerAsset(
                id: "botanical_lavender",
                name: "Lavender",
                category: .botanical,
                assetName: "sticker_lavender",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.1, height: 0.2),
                tags: ["herb", "lavender", "flower"],
                sortOrder: 3
            ),
            StickerAsset(
                id: "botanical_lemon",
                name: "Lemon",
                category: .botanical,
                assetName: "sticker_lemon",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.12, height: 0.12),
                tags: ["fruit", "citrus", "lemon"],
                sortOrder: 4
            ),
            StickerAsset(
                id: "botanical_strawberry",
                name: "Strawberry",
                category: .botanical,
                assetName: "sticker_strawberry",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.1, height: 0.12),
                tags: ["fruit", "berry", "strawberry"],
                sortOrder: 5
            ),
            StickerAsset(
                id: "botanical_olive_branch",
                name: "Olive Branch",
                category: .botanical,
                assetName: "sticker_olive_branch",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.15, height: 0.18),
                tags: ["branch", "olive", "plant"],
                sortOrder: 6
            ),
            StickerAsset(
                id: "botanical_wheat",
                name: "Wheat",
                category: .botanical,
                assetName: "sticker_wheat",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.1, height: 0.2),
                tags: ["grain", "wheat", "plant"],
                sortOrder: 7
            ),
            StickerAsset(
                id: "botanical_tomato",
                name: "Tomato",
                category: .botanical,
                assetName: "sticker_tomato",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.12, height: 0.12),
                tags: ["vegetable", "tomato", "plant"],
                sortOrder: 8
            ),
            StickerAsset(
                id: "botanical_garlic",
                name: "Garlic",
                category: .botanical,
                assetName: "sticker_garlic",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.1, height: 0.12),
                tags: ["vegetable", "garlic", "plant"],
                sortOrder: 9
            )
        ])

        // MARK: - Utensils Category (10 stickers)
        stickers.append(contentsOf: [
            StickerAsset(
                id: "utensil_wooden_spoon",
                name: "Wooden Spoon",
                category: .utensils,
                assetName: "sticker_wooden_spoon",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.08, height: 0.25),
                tags: ["spoon", "wooden", "utensil"],
                sortOrder: 0
            ),
            StickerAsset(
                id: "utensil_whisk",
                name: "Whisk",
                category: .utensils,
                assetName: "sticker_whisk",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.1, height: 0.2),
                tags: ["whisk", "mixing", "utensil"],
                sortOrder: 1
            ),
            StickerAsset(
                id: "utensil_spatula",
                name: "Spatula",
                category: .utensils,
                assetName: "sticker_spatula",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.08, height: 0.22),
                tags: ["spatula", "flipping", "utensil"],
                sortOrder: 2
            ),
            StickerAsset(
                id: "utensil_ladle",
                name: "Ladle",
                category: .utensils,
                assetName: "sticker_ladle",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.1, height: 0.2),
                tags: ["ladle", "serving", "utensil"],
                sortOrder: 3
            ),
            StickerAsset(
                id: "utensil_fork",
                name: "Fork",
                category: .utensils,
                assetName: "sticker_fork",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.06, height: 0.25),
                tags: ["fork", "eating", "utensil"],
                sortOrder: 4
            ),
            StickerAsset(
                id: "utensil_knife",
                name: "Chef's Knife",
                category: .utensils,
                assetName: "sticker_knife",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.25, height: 0.08),
                tags: ["knife", "cutting", "utensil"],
                sortOrder: 5
            ),
            StickerAsset(
                id: "utensil_rolling_pin_simple",
                name: "Rolling Pin (Simple)",
                category: .utensils,
                assetName: "sticker_rolling_pin_simple",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.25, height: 0.08),
                tags: ["rolling pin", "baking", "utensil"],
                sortOrder: 6
            ),
            StickerAsset(
                id: "utensil_tongs",
                name: "Tongs",
                category: .utensils,
                assetName: "sticker_tongs",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.08, height: 0.2),
                tags: ["tongs", "grilling", "utensil"],
                sortOrder: 7
            ),
            StickerAsset(
                id: "utensil_peeler",
                name: "Peeler",
                category: .utensils,
                assetName: "sticker_peeler",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.08, height: 0.18),
                tags: ["peeler", "prep", "utensil"],
                sortOrder: 8
            ),
            StickerAsset(
                id: "utensil_can_opener",
                name: "Can Opener",
                category: .utensils,
                assetName: "sticker_can_opener",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.12, height: 0.15),
                tags: ["can opener", "tool", "utensil"],
                sortOrder: 9
            )
        ])

        // MARK: - Icons Category (5 stickers)
        stickers.append(contentsOf: [
            StickerAsset(
                id: "icon_heart",
                name: "Heart",
                category: .icons,
                assetName: "sticker_heart",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.12, height: 0.12),
                tags: ["heart", "love", "icon"],
                sortOrder: 0
            ),
            StickerAsset(
                id: "icon_star",
                name: "Star",
                category: .icons,
                assetName: "sticker_star",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.12, height: 0.12),
                tags: ["star", "favorite", "icon"],
                sortOrder: 1
            ),
            StickerAsset(
                id: "icon_checkmark",
                name: "Checkmark",
                category: .icons,
                assetName: "sticker_checkmark",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.1, height: 0.1),
                tags: ["check", "done", "icon"],
                sortOrder: 2
            ),
            StickerAsset(
                id: "icon_flame",
                name: "Flame",
                category: .icons,
                assetName: "sticker_flame",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.08, height: 0.15),
                tags: ["fire", "heat", "icon"],
                sortOrder: 3
            ),
            StickerAsset(
                id: "icon_snowflake",
                name: "Snowflake",
                category: .icons,
                assetName: "sticker_snowflake",
                supportsTinting: true,
                defaultSize: CGSize(width: 0.12, height: 0.12),
                tags: ["cold", "frozen", "icon"],
                sortOrder: 4
            )
        ])

        return stickers
    }
}

// MARK: - Errors

enum StickerLibraryError: LocalizedError {
    case stickerNotFound
    case cannotDeleteBuiltInSticker
    case importFailed

    var errorDescription: String? {
        switch self {
        case .stickerNotFound:
            return "Sticker not found"
        case .cannotDeleteBuiltInSticker:
            return "Cannot delete built-in sticker"
        case .importFailed:
            return "Failed to import custom sticker"
        }
    }
}
