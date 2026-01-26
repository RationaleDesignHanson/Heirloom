//
//  ThemeLoader.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import Foundation
import SwiftData
import FirebaseFirestore

/// Loads available themes from Firebase
actor ThemeLoader {

    private let firestore = Firestore.firestore()

    /// Fetch all available themes from Firebase and save to local database
    func loadThemes(into context: ModelContext) async throws -> [RecipeTheme] {
        let snapshot = try await firestore
            .collection("themes")
            .order(by: "sortOrder")
            .getDocuments()

        var themes: [RecipeTheme] = []

        for document in snapshot.documents {
            if let theme = try? parseTheme(from: document) {
                // Check if already exists locally
                let firebaseId = theme.firebaseId
                let descriptor = FetchDescriptor<RecipeTheme>(
                    predicate: #Predicate { $0.firebaseId == firebaseId }
                )

                if let existing = try? context.fetch(descriptor).first {
                    // Update existing
                    updateTheme(existing, from: theme)
                    themes.append(existing)
                } else {
                    // Insert new
                    context.insert(theme)
                    themes.append(theme)
                }
            }
        }

        try context.save()
        return themes
    }

    private func parseTheme(from document: QueryDocumentSnapshot) throws -> RecipeTheme {
        let data = document.data()

        guard let name = data["name"] as? String,
              let tagline = data["tagline"] as? String,
              let description = data["description"] as? String,
              let iconName = data["iconName"] as? String,
              let categoryRaw = data["category"] as? String,
              let category = ThemeCategory(rawValue: categoryRaw),
              let totalRecipes = data["totalRecipes"] as? Int,
              let unlockSchedule = data["unlockSchedule"] as? [Int]
        else {
            throw ThemeLoadError.invalidData(document.documentID)
        }

        let theme = RecipeTheme(
            firebaseId: document.documentID,
            name: name,
            tagline: tagline,
            themeDescription: description,
            iconName: iconName,
            category: category,
            totalRecipes: totalRecipes,
            unlockSchedule: unlockSchedule
        )

        // Optional fields
        theme.coverImageURL = data["coverImageURL"] as? String
        theme.source = data["source"] as? String
        theme.era = data["era"] as? String
        theme.region = data["region"] as? String
        theme.sortOrder = data["sortOrder"] as? Int ?? 0

        return theme
    }

    private func updateTheme(_ existing: RecipeTheme, from new: RecipeTheme) {
        existing.name = new.name
        existing.tagline = new.tagline
        existing.themeDescription = new.themeDescription
        existing.iconName = new.iconName
        existing.category = new.category
        existing.totalRecipes = new.totalRecipes
        existing.unlockSchedule = new.unlockSchedule
        existing.coverImageURL = new.coverImageURL
        existing.source = new.source
        existing.era = new.era
        existing.region = new.region
        existing.sortOrder = new.sortOrder
        existing.updatedAt = Date()
    }
}

enum ThemeLoadError: Error {
    case invalidData(String)
    case networkError(Error)
}
