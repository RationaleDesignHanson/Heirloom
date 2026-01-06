//
//  CardCustomizationService.swift
//  Heirloom
//
//  Created by Claude on 1/5/26.
//

import Foundation
import SwiftData
import SwiftUI

/// Protocol defining card customization operations
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

/// Service for managing recipe card customizations
@MainActor
final class CardCustomizationService: ObservableObject, CardCustomizationServiceProtocol {
    // MARK: - Dependencies
    private let deviceId: String

    // MARK: - State
    @Published private(set) var activeRecipeId: UUID?
    @Published private(set) var selectedCustomization: Customization?

    // MARK: - Initialization
    @MainActor
    init(
        deviceId: String? = nil
    ) {
        self.deviceId = deviceId ?? UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }

    // MARK: - Add Customizations

    func addSticker(
        to recipeId: UUID,
        stickerAssetId: String,
        position: CGPoint,
        size: CGSize,
        tintColor: String?,
        context: ModelContext
    ) async throws -> Customization {
        Log.info("Adding sticker to recipe", category: .database, metadata: [
            "recipeId": recipeId.uuidString,
            "stickerId": stickerAssetId
        ])

        let content = CustomizationContent.sticker(assetId: stickerAssetId, tintColor: tintColor)
        let zIndex = try getNextZIndex(for: recipeId, context: context)

        let customization = Customization(
            recipeId: recipeId,
            deviceId: deviceId,
            userId: "local", // TODO: Get from auth service
            type: .sticker,
            position: position,
            size: size,
            zIndex: zIndex,
            content: content,
            vectorClock: VectorClock()
        )

        context.insert(customization)
        try context.save()

        Log.info("Sticker added successfully", category: .database)
        return customization
    }

    func addDrawing(
        to recipeId: UUID,
        path: DrawingPath,
        strokeColor: String,
        strokeWidth: Double,
        position: CGPoint,
        context: ModelContext
    ) async throws -> Customization {
        Log.info("Adding drawing to recipe", category: .database, metadata: [
            "recipeId": recipeId.uuidString
        ])

        let content = CustomizationContent.drawing(
            path: path,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth
        )
        let zIndex = try getNextZIndex(for: recipeId, context: context)

        let customization = Customization(
            recipeId: recipeId,
            deviceId: deviceId,
            userId: "local",
            type: .drawing,
            position: position,
            size: CGSize(width: 1.0, height: 1.0), // Drawing uses full card
            zIndex: zIndex,
            content: content,
            vectorClock: VectorClock()
        )

        context.insert(customization)
        try context.save()

        Log.info("Drawing added successfully", category: .database)
        return customization
    }

    func addText(
        to recipeId: UUID,
        content textContent: String,
        position: CGPoint,
        font: String,
        fontSize: Double,
        color: String,
        context: ModelContext
    ) async throws -> Customization {
        Log.info("Adding text to recipe", category: .database, metadata: [
            "recipeId": recipeId.uuidString
        ])

        let content = CustomizationContent.text(
            content: textContent,
            font: font,
            fontSize: fontSize,
            color: color
        )
        let zIndex = try getNextZIndex(for: recipeId, context: context)

        let customization = Customization(
            recipeId: recipeId,
            deviceId: deviceId,
            userId: "local",
            type: .text,
            position: position,
            size: CGSize(width: 0.3, height: 0.1), // Default text size
            zIndex: zIndex,
            content: content,
            vectorClock: VectorClock()
        )

        context.insert(customization)
        try context.save()

        Log.info("Text added successfully", category: .database)
        return customization
    }

    func addPhoto(
        to recipeId: UUID,
        imageData: Data,
        position: CGPoint,
        size: CGSize,
        opacity: Double,
        context: ModelContext
    ) async throws -> Customization {
        Log.info("Adding photo to recipe", category: .database, metadata: [
            "recipeId": recipeId.uuidString
        ])

        // Generate unique image ID
        let imageId = UUID()

        // TODO: Save image data to ImageStorageService
        // For now, just store the reference

        let content = CustomizationContent.photo(imageId: imageId, opacity: opacity)
        let zIndex = try getNextZIndex(for: recipeId, context: context)

        let customization = Customization(
            recipeId: recipeId,
            deviceId: deviceId,
            userId: "local",
            type: .photo,
            position: position,
            size: size,
            zIndex: zIndex,
            content: content,
            vectorClock: VectorClock()
        )

        context.insert(customization)
        try context.save()

        Log.info("Photo added successfully", category: .database)
        return customization
    }

    // MARK: - Modify Customizations

    func move(
        customizationId: UUID,
        to position: CGPoint,
        context: ModelContext
    ) async throws {
        guard let customization = try fetchCustomization(id: customizationId, context: context) else {
            throw CustomizationError.notFound
        }

        customization.position = position
        customization.modifiedAt = Date()
        try context.save()

        Log.debug("Customization moved", category: .database, metadata: [
            "id": customizationId.uuidString
        ])
    }

    func resize(
        customizationId: UUID,
        to size: CGSize,
        context: ModelContext
    ) async throws {
        guard let customization = try fetchCustomization(id: customizationId, context: context) else {
            throw CustomizationError.notFound
        }

        customization.size = size
        customization.modifiedAt = Date()
        try context.save()

        Log.debug("Customization resized", category: .database)
    }

    func rotate(
        customizationId: UUID,
        by angle: Double,
        context: ModelContext
    ) async throws {
        guard let customization = try fetchCustomization(id: customizationId, context: context) else {
            throw CustomizationError.notFound
        }

        customization.rotation = angle
        customization.modifiedAt = Date()
        try context.save()

        Log.debug("Customization rotated", category: .database)
    }

    func updateContent(
        customizationId: UUID,
        content: CustomizationContent,
        context: ModelContext
    ) async throws {
        guard let customization = try fetchCustomization(id: customizationId, context: context) else {
            throw CustomizationError.notFound
        }

        customization.content = content
        customization.modifiedAt = Date()
        try context.save()

        Log.debug("Customization content updated", category: .database)
    }

    // MARK: - Delete Customizations

    func delete(
        customizationId: UUID,
        context: ModelContext
    ) async throws {
        guard let customization = try fetchCustomization(id: customizationId, context: context) else {
            throw CustomizationError.notFound
        }

        // Soft delete for CRDT
        customization.isDeleted = true
        customization.modifiedAt = Date()
        try context.save()

        Log.info("Customization deleted", category: .database, metadata: [
            "id": customizationId.uuidString
        ])
    }

    func deleteAll(
        for recipeId: UUID,
        context: ModelContext
    ) async throws {
        let customizations = try fetchCustomizations(for: recipeId, context: context)

        for customization in customizations where !customization.isDeleted {
            customization.isDeleted = true
            customization.modifiedAt = Date()
        }

        try context.save()

        Log.info("All customizations deleted for recipe", category: .database, metadata: [
            "recipeId": recipeId.uuidString,
            "count": "\(customizations.count)"
        ])
    }

    // MARK: - Query Customizations

    func fetchCustomizations(
        for recipeId: UUID,
        context: ModelContext
    ) throws -> [Customization] {
        let descriptor = FetchDescriptor<Customization>(
            predicate: #Predicate<Customization> { customization in
                customization.recipeId == recipeId && !customization.isDeleted
            },
            sortBy: [SortDescriptor(\Customization.zIndex)]
        )

        return try context.fetch(descriptor)
    }

    func fetchCustomization(
        id: UUID,
        context: ModelContext
    ) throws -> Customization? {
        let descriptor = FetchDescriptor<Customization>(
            predicate: #Predicate<Customization> { customization in
                customization.id == id
            }
        )

        return try context.fetch(descriptor).first
    }

    // MARK: - Layer Management

    func bringToFront(
        customizationId: UUID,
        context: ModelContext
    ) async throws {
        guard let customization = try fetchCustomization(id: customizationId, context: context) else {
            throw CustomizationError.notFound
        }

        let maxZIndex = try getMaxZIndex(for: customization.recipeId, context: context)
        customization.zIndex = maxZIndex + 1
        customization.modifiedAt = Date()
        try context.save()

        Log.debug("Customization brought to front", category: .database)
    }

    func sendToBack(
        customizationId: UUID,
        context: ModelContext
    ) async throws {
        guard let customization = try fetchCustomization(id: customizationId, context: context) else {
            throw CustomizationError.notFound
        }

        let minZIndex = try getMinZIndex(for: customization.recipeId, context: context)
        customization.zIndex = minZIndex - 1
        customization.modifiedAt = Date()
        try context.save()

        Log.debug("Customization sent to back", category: .database)
    }

    func bringForward(
        customizationId: UUID,
        context: ModelContext
    ) async throws {
        guard let customization = try fetchCustomization(id: customizationId, context: context) else {
            throw CustomizationError.notFound
        }

        customization.zIndex += 1
        customization.modifiedAt = Date()
        try context.save()

        Log.debug("Customization brought forward", category: .database)
    }

    func sendBackward(
        customizationId: UUID,
        context: ModelContext
    ) async throws {
        guard let customization = try fetchCustomization(id: customizationId, context: context) else {
            throw CustomizationError.notFound
        }

        customization.zIndex -= 1
        customization.modifiedAt = Date()
        try context.save()

        Log.debug("Customization sent backward", category: .database)
    }

    // MARK: - Helper Methods

    private func getNextZIndex(for recipeId: UUID, context: ModelContext) throws -> Int {
        let maxZIndex = try getMaxZIndex(for: recipeId, context: context)
        return maxZIndex + 1
    }

    private func getMaxZIndex(for recipeId: UUID, context: ModelContext) throws -> Int {
        let customizations = try fetchCustomizations(for: recipeId, context: context)
        return customizations.map(\.zIndex).max() ?? 0
    }

    private func getMinZIndex(for recipeId: UUID, context: ModelContext) throws -> Int {
        let customizations = try fetchCustomizations(for: recipeId, context: context)
        return customizations.map(\.zIndex).min() ?? 0
    }
}

// MARK: - Errors

enum CustomizationError: LocalizedError {
    case notFound
    case invalidContent
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Customization not found"
        case .invalidContent:
            return "Invalid customization content"
        case .saveFailed:
            return "Failed to save customization"
        }
    }
}
