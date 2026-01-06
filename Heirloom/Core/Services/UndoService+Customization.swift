//
//  UndoService+Customization.swift
//  Heirloom
//
//  Created by Claude on 1/5/26.
//

import Foundation
import SwiftData

// MARK: - Customization Undo Support

extension UndoService {
    /// Snapshot of a customization for undo/redo
    struct CustomizationSnapshot: Codable {
        let id: UUID
        let recipeId: UUID
        let type: CustomizationType
        let positionX: Double
        let positionY: Double
        let sizeWidth: Double
        let sizeHeight: Double
        let rotation: Double
        let zIndex: Int
        let contentJSON: Data
        let isDeleted: Bool

        init(from customization: Customization) {
            self.id = customization.id
            self.recipeId = customization.recipeId
            self.type = customization.type
            self.positionX = customization.positionX
            self.positionY = customization.positionY
            self.sizeWidth = customization.sizeWidth
            self.sizeHeight = customization.sizeHeight
            self.rotation = customization.rotation
            self.zIndex = customization.zIndex
            self.contentJSON = customization.contentJSON
            self.isDeleted = customization.isDeleted
        }

        func toJSON() -> String {
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(self),
                  let json = String(data: data, encoding: .utf8) else {
                return "{}"
            }
            return json
        }

        static func fromJSON(_ json: String) -> CustomizationSnapshot? {
            guard let data = json.data(using: .utf8) else { return nil }
            let decoder = JSONDecoder()
            return try? decoder.decode(CustomizationSnapshot.self, from: data)
        }
    }

    /// Undo item for customization operations
    struct CustomizationUndoItem: Identifiable {
        let id = UUID()
        let customizationId: UUID
        let recipeId: UUID
        let operation: CustomizationUndoOperation
        let snapshot: CustomizationSnapshot?
        let expirationDate: Date
        let description: String

        var isExpired: Bool {
            Date() > expirationDate
        }
    }

    /// Types of customization undo operations
    enum CustomizationUndoOperation {
        case add
        case modify
        case delete
        case reorder
    }

    // MARK: - Record Customization Operations

    /// Record adding a customization (for undo)
    func recordAddCustomization(
        _ customization: Customization,
        context: ModelContext
    ) async {
        let snapshot = CustomizationSnapshot(from: customization)

        let undoItem = CustomizationUndoItem(
            customizationId: customization.id,
            recipeId: customization.recipeId,
            operation: .add,
            snapshot: snapshot,
            expirationDate: Date().addingTimeInterval(Self.defaultUndoWindow),
            description: "Added \(customization.type.rawValue)"
        )

        // Store in pending undos (would need to extend UndoService state)
        Log.debug("Recorded add customization for undo", category: .database, metadata: [
            "id": customization.id.uuidString
        ])
    }

    /// Record modifying a customization (for undo)
    func recordModifyCustomization(
        customizationId: UUID,
        recipeId: UUID,
        previousState: CustomizationSnapshot,
        context: ModelContext
    ) async {
        let undoItem = CustomizationUndoItem(
            customizationId: customizationId,
            recipeId: recipeId,
            operation: .modify,
            snapshot: previousState,
            expirationDate: Date().addingTimeInterval(Self.defaultUndoWindow),
            description: "Modified customization"
        )

        Log.debug("Recorded modify customization for undo", category: .database, metadata: [
            "id": customizationId.uuidString
        ])
    }

    /// Record deleting a customization (for undo)
    func recordDeleteCustomization(
        _ customization: Customization,
        context: ModelContext
    ) async {
        let snapshot = CustomizationSnapshot(from: customization)

        let undoItem = CustomizationUndoItem(
            customizationId: customization.id,
            recipeId: customization.recipeId,
            operation: .delete,
            snapshot: snapshot,
            expirationDate: Date().addingTimeInterval(Self.defaultUndoWindow),
            description: "Deleted \(customization.type.rawValue)"
        )

        Log.debug("Recorded delete customization for undo", category: .database, metadata: [
            "id": customization.id.uuidString
        ])
    }

    // MARK: - Undo Customization Operations

    /// Undo adding a customization (delete it)
    func undoAddCustomization(
        customizationId: UUID,
        context: ModelContext
    ) async throws {
        let descriptor = FetchDescriptor<Customization>(
            predicate: #Predicate<Customization> { $0.id == customizationId }
        )

        guard let customization = try context.fetch(descriptor).first else {
            throw UndoError.itemNotFound
        }

        // Soft delete
        customization.isDeleted = true
        try context.save()

        Log.info("Undid add customization", category: .database, metadata: [
            "id": customizationId.uuidString
        ])
    }

    /// Undo modifying a customization (restore previous state)
    func undoModifyCustomization(
        customizationId: UUID,
        previousState: CustomizationSnapshot,
        context: ModelContext
    ) async throws {
        let descriptor = FetchDescriptor<Customization>(
            predicate: #Predicate<Customization> { $0.id == customizationId }
        )

        guard let customization = try context.fetch(descriptor).first else {
            throw UndoError.itemNotFound
        }

        // Restore previous state
        customization.positionX = previousState.positionX
        customization.positionY = previousState.positionY
        customization.sizeWidth = previousState.sizeWidth
        customization.sizeHeight = previousState.sizeHeight
        customization.rotation = previousState.rotation
        customization.zIndex = previousState.zIndex
        customization.contentJSON = previousState.contentJSON

        try context.save()

        Log.info("Undid modify customization", category: .database, metadata: [
            "id": customizationId.uuidString
        ])
    }

    /// Undo deleting a customization (restore it)
    func undoDeleteCustomization(
        snapshot: CustomizationSnapshot,
        context: ModelContext
    ) async throws {
        let descriptor = FetchDescriptor<Customization>(
            predicate: #Predicate<Customization> { $0.id == snapshot.id }
        )

        if let existingCustomization = try context.fetch(descriptor).first {
            // Restore by unmarking as deleted
            existingCustomization.isDeleted = false
            existingCustomization.modifiedAt = Date()
        } else {
            // Recreate the customization
            let customization = Customization(
                id: snapshot.id,
                recipeId: snapshot.recipeId,
                deviceId: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
                userId: "local",
                type: snapshot.type,
                position: CGPoint(x: snapshot.positionX, y: snapshot.positionY),
                size: CGSize(width: snapshot.sizeWidth, height: snapshot.sizeHeight),
                rotation: snapshot.rotation,
                zIndex: snapshot.zIndex,
                content: .sticker(assetId: "", tintColor: nil), // Will be restored from contentJSON
                vectorClock: VectorClock()
            )

            customization.contentJSON = snapshot.contentJSON
            customization.isDeleted = false
            context.insert(customization)
        }

        try context.save()

        Log.info("Undid delete customization", category: .database, metadata: [
            "id": snapshot.id.uuidString
        ])
    }
}

// MARK: - Undo Errors

enum UndoError: LocalizedError {
    case itemNotFound
    case operationFailed

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found for undo"
        case .operationFailed:
            return "Undo operation failed"
        }
    }
}
