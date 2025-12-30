import Foundation
import SwiftData

/// Represents a specific user's version of a recipe with their modifications
/// Enables multi-version recipe editing with attribution and change tracking
@Model
final class RecipeVersion {
    // MARK: - Identity
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var lastModified: Date = Date()

    // MARK: - Ownership & Attribution

    /// CloudKit user record ID of version creator
    var creatorUserID: String = ""

    /// Display name at time of creation (e.g., "Mom", "Grandma Kay", "You")
    var creatorDisplayName: String = ""

    /// Year label for UI attribution (e.g., "2015", "2025")
    var creationYear: String = ""

    // MARK: - Relationship

    /// Parent recipe this version belongs to
    /// Note: Inverse relationship defined on Recipe.versions
    var recipe: Recipe?

    // MARK: - Version Content

    /// Title override (if changed from base)
    var title: String?

    /// Complete ingredient list for this version
    /// Stored as JSON to preserve order and allow field-level tracking
    var ingredientsData: Data?

    /// Complete instruction list for this version
    var instructionsData: Data?

    /// Servings modification
    var servings: String?

    /// Timing modifications
    var prepTime: String?
    var cookTime: String?

    /// Notes specific to this version
    var notes: String?

    // MARK: - Change Tracking

    /// Field-level change log for attribution
    /// Format: [fieldKey: [Change]]
    /// Example: {"ingredient-2": [Change(from: "butter", to: "olive oil", at: Date())]}
    var changeLogData: Data?

    // MARK: - Metadata

    /// Whether this is the canonical/base version (original recipe)
    var isBaseVersion: Bool = false

    /// Whether this version is actively maintained
    var isActive: Bool = true

    /// Sticker IDs added by this user
    var stickerIDs: [String] = []

    /// Times this specific version has been cooked
    var timesCooked: Int = 0

    /// Last time this version was cooked
    var lastCooked: Date?

    // MARK: - Initialization

    init(
        creatorUserID: String,
        creatorDisplayName: String,
        creationYear: String? = nil,
        isBaseVersion: Bool = false
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.lastModified = Date()
        self.creatorUserID = creatorUserID
        self.creatorDisplayName = creatorDisplayName
        self.creationYear = creationYear ?? String(Calendar.current.component(.year, from: Date()))
        self.isBaseVersion = isBaseVersion
        self.isActive = true
        self.stickerIDs = []
        self.timesCooked = 0
    }
}

// MARK: - Computed Properties

extension RecipeVersion {
    /// Decoded ingredients array
    var ingredients: [String]? {
        get {
            guard let data = ingredientsData else { return nil }
            return try? JSONDecoder().decode([String].self, from: data)
        }
        set {
            ingredientsData = try? JSONEncoder().encode(newValue)
            lastModified = Date()
        }
    }

    /// Decoded instructions array
    var instructions: [String]? {
        get {
            guard let data = instructionsData else { return nil }
            return try? JSONDecoder().decode([String].self, from: data)
        }
        set {
            instructionsData = try? JSONEncoder().encode(newValue)
            lastModified = Date()
        }
    }

    /// Decoded change log
    var changeLog: [String: [FieldChange]]? {
        get {
            guard let data = changeLogData else { return nil }
            return try? JSONDecoder().decode([String: [FieldChange]].self, from: data)
        }
        set {
            changeLogData = try? JSONEncoder().encode(newValue)
            lastModified = Date()
        }
    }

    /// Display label for version attribution (e.g., "Mom '15")
    var attributionLabel: String {
        let yearShort = String(creationYear.suffix(2))
        return "\(creatorDisplayName) '\(yearShort)"
    }

    /// Full attribution string (e.g., "Mom (2015)")
    var fullAttribution: String {
        return "\(creatorDisplayName) (\(creationYear))"
    }

    /// Number of fields changed in this version
    var changeCount: Int {
        return changeLog?.values.reduce(0) { $0 + $1.count } ?? 0
    }

    /// Whether this version has any changes tracked
    var hasChanges: Bool {
        return changeCount > 0
    }
}

// MARK: - Supporting Types

/// Represents a single field change with attribution
struct FieldChange: Codable, Hashable {
    /// Original value before change
    var from: String

    /// New value after change
    var to: String

    /// When this change occurred
    var changedAt: Date

    init(from: String, to: String, changedAt: Date = Date()) {
        self.from = from
        self.to = to
        self.changedAt = changedAt
    }
}

// MARK: - Helper Methods

extension RecipeVersion {
    /// Add or update a change for a specific field
    func recordChange(field: String, from oldValue: String, to newValue: String) {
        var log = changeLog ?? [:]
        var fieldChanges = log[field] ?? []

        // Add new change
        fieldChanges.append(FieldChange(from: oldValue, to: newValue))

        log[field] = fieldChanges
        changeLog = log
    }

    /// Get all changes for a specific field
    func getChanges(for field: String) -> [FieldChange] {
        return changeLog?[field] ?? []
    }

    /// Get the most recent change for a field
    func getLatestChange(for field: String) -> FieldChange? {
        return changeLog?[field]?.last
    }

    /// Clear all changes (used when resetting to base version)
    func clearChanges() {
        changeLog = nil
    }
}

// MARK: - Sample Data

#if DEBUG
extension RecipeVersion {
    /// Sample base version (original recipe)
    static func sampleBase() -> RecipeVersion {
        let version = RecipeVersion(
            creatorUserID: "user-original",
            creatorDisplayName: "Grandma Kay",
            creationYear: "1987",
            isBaseVersion: true
        )
        version.title = "Grandma's Lasagna"
        version.ingredients = [
            "2 cups ricotta cheese",
            "1 lb ground beef",
            "2 cups marinara sauce",
            "12 lasagna noodles",
            "2 cups mozzarella cheese"
        ]
        version.instructions = [
            "Preheat oven to 375°F",
            "Brown ground beef in large skillet",
            "Cook lasagna noodles according to package",
            "Layer noodles, meat, cheese, and sauce in 9x13 pan",
            "Bake for 45 minutes until bubbly and golden"
        ]
        version.servings = "8"
        version.prepTime = "30 min"
        version.cookTime = "45 min"
        return version
    }

    /// Sample contributor version (Mom's modifications)
    static func sampleContributor() -> RecipeVersion {
        let version = RecipeVersion(
            creatorUserID: "user-mom",
            creatorDisplayName: "Mom",
            creationYear: "2015",
            isBaseVersion: false
        )
        version.title = "Grandma's Lasagna"
        version.ingredients = [
            "2 cups ricotta cheese",
            "1 lb ground turkey", // Changed from beef
            "2 cups marinara sauce",
            "12 lasagna noodles",
            "2 cups mozzarella cheese"
        ]
        version.instructions = [
            "Preheat oven to 375°F",
            "Brown ground turkey in large skillet", // Changed
            "Cook lasagna noodles according to package",
            "Layer noodles, meat, cheese, and sauce in 9x13 pan",
            "Bake for 45 minutes until bubbly and golden"
        ]

        // Record changes
        version.recordChange(field: "ingredient-1", from: "1 lb ground beef", to: "1 lb ground turkey")
        version.recordChange(field: "instruction-1", from: "Brown ground beef in large skillet", to: "Brown ground turkey in large skillet")

        version.notes = "I always use turkey instead of beef — healthier and the kids love it!"
        version.stickerIDs = ["heart", "star"]
        version.timesCooked = 5

        return version
    }
}
#endif
