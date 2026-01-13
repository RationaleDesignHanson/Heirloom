//
//  BlindBoxSeeder.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-12.
//

import Foundation
import SwiftData

/// Service for creating blind box collections after onboarding
@MainActor
class BlindBoxSeeder {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Check if blind boxes have been seeded
    func isSeeded() -> Bool {
        UserDefaults.standard.bool(forKey: "hasSeenBlindBoxes")
    }

    /// Create 2 blind box collections for post-onboarding reveal
    /// - Box 1: Always "Literary Kitchen"
    /// - Box 2: Random from [Presidential Pantry, Ancient Table, American Foundation]
    func seedBlindBoxes() throws {
        guard !isSeeded() else {
            Log.info("Blind boxes already seeded", category: .storage)
            return
        }

        // Fetch all heritage collections
        let descriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { $0.heritageCollectionId != nil }
        )
        let heritageCollections = try modelContext.fetch(descriptor)

        // Box 1: Literary Kitchen (guaranteed)
        if let literaryKitchen = heritageCollections.first(where: {
            $0.heritageCollectionId == RecipeCollection.HeritageCollectionID.literaryKitchen.rawValue
        }) {
            literaryKitchen.isBlindBox = true
            literaryKitchen.isRevealed = false
            Log.info("Marked Literary Kitchen as blind box 1", category: .storage)
        } else {
            Log.warning("Literary Kitchen collection not found", category: .storage)
        }

        // Box 2: Random from remaining collections
        let remainingIds: [RecipeCollection.HeritageCollectionID] = [
            .presidentialPantry,
            .ancientTable,
            .americanFoundation
        ]

        guard let randomId = remainingIds.randomElement() else {
            Log.error("Failed to select random collection for blind box 2", category: .storage)
            throw BlindBoxError.noCollectionsAvailable
        }

        if let randomCollection = heritageCollections.first(where: {
            $0.heritageCollectionId == randomId.rawValue
        }) {
            randomCollection.isBlindBox = true
            randomCollection.isRevealed = false
            Log.info("Marked \(randomId.displayName) as blind box 2", category: .storage)
        } else {
            Log.warning("Random collection \(randomId.displayName) not found", category: .storage)
        }

        try modelContext.save()

        // Mark as seeded
        UserDefaults.standard.set(true, forKey: "hasSeenBlindBoxes")

        Log.info("Blind boxes seeded successfully", category: .storage, metadata: [
            "box1": "Literary Kitchen",
            "box2": randomId.displayName
        ])
    }

    // MARK: - Errors

    enum BlindBoxError: Error {
        case noCollectionsAvailable
    }
}
