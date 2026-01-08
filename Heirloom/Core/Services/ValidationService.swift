//
//  ValidationService.swift
//  Heirloom
//
//  Created by Claude Code on 1/7/26.
//  Security Phase 1: Centralized input validation
//

import Foundation

/// Centralized validation service for all user inputs
/// Prevents injection attacks, enforces length limits, and validates data integrity
class ValidationService {
    static let shared = ValidationService()

    // MARK: - Configuration

    struct Limits {
        static let maxTitleLength = 500
        static let maxNotesLength = 10_000
        static let maxInstructionLength = 5_000
        static let maxCommentLength = 2_000
        static let maxIngredientNameLength = 200
        static let maxTagLength = 50
        static let maxArraySize = 1_000
        static let maxIngredients = 500
        static let maxInstructions = 200
        static let maxTags = 50
        static let maxComments = 1_000
    }

    // MARK: - String Validation

    /// Validates a recipe title
    func validateTitle(_ title: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError.emptyField("title")
        }

        guard trimmed.count <= Limits.maxTitleLength else {
            throw ValidationError.tooLong(
                field: "title",
                max: Limits.maxTitleLength,
                actual: trimmed.count
            )
        }
    }

    /// Validates recipe notes field
    func validateNotes(_ notes: String?) throws {
        guard let notes = notes, !notes.isEmpty else {
            return // Notes are optional
        }

        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= Limits.maxNotesLength else {
            throw ValidationError.tooLong(
                field: "notes",
                max: Limits.maxNotesLength,
                actual: trimmed.count
            )
        }
    }

    /// Validates instruction text
    func validateInstruction(_ text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError.emptyField("instruction")
        }

        guard trimmed.count <= Limits.maxInstructionLength else {
            throw ValidationError.tooLong(
                field: "instruction",
                max: Limits.maxInstructionLength,
                actual: trimmed.count
            )
        }
    }

    /// Validates comment text
    func validateComment(_ text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError.emptyField("comment")
        }

        guard trimmed.count <= Limits.maxCommentLength else {
            throw ValidationError.tooLong(
                field: "comment",
                max: Limits.maxCommentLength,
                actual: trimmed.count
            )
        }
    }

    /// Validates ingredient name
    func validateIngredientName(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError.emptyField("ingredient name")
        }

        guard trimmed.count <= Limits.maxIngredientNameLength else {
            throw ValidationError.tooLong(
                field: "ingredient name",
                max: Limits.maxIngredientNameLength,
                actual: trimmed.count
            )
        }
    }

    /// Validates tag text
    func validateTag(_ tag: String) throws {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError.emptyField("tag")
        }

        guard trimmed.count <= Limits.maxTagLength else {
            throw ValidationError.tooLong(
                field: "tag",
                max: Limits.maxTagLength,
                actual: trimmed.count
            )
        }
    }

    // MARK: - Numeric Validation

    /// Validates serving range (minimum and maximum servings)
    func validateServingRange(min: Int16?, max: Int16?) throws {
        guard let min = min, let max = max else {
            return // Optional fields
        }

        guard min > 0 else {
            throw ValidationError.invalidValue(
                field: "minimum servings",
                reason: "Must be greater than 0"
            )
        }

        guard max > 0 else {
            throw ValidationError.invalidValue(
                field: "maximum servings",
                reason: "Must be greater than 0"
            )
        }

        guard min <= max else {
            throw ValidationError.invalidRange(
                field: "servings",
                min: Int(min),
                max: Int(max)
            )
        }
    }

    /// Validates a quantity value
    func validateQuantity(_ quantity: Double?) throws {
        guard let quantity = quantity else {
            return // Optional
        }

        guard quantity >= 0 else {
            throw ValidationError.invalidValue(
                field: "quantity",
                reason: "Cannot be negative"
            )
        }
    }

    // MARK: - Array Validation

    /// Validates array size against limits
    func validateArraySize<T>(_ array: [T], field: String, max: Int) throws {
        guard array.count <= max else {
            throw ValidationError.tooManyItems(
                field: field,
                max: max,
                actual: array.count
            )
        }
    }

    /// Validates ingredients array
    func validateIngredients(_ ingredients: [Any]) throws {
        try validateArraySize(
            ingredients,
            field: "ingredients",
            max: Limits.maxIngredients
        )
    }

    /// Validates instructions array
    func validateInstructions(_ instructions: [Any]) throws {
        try validateArraySize(
            instructions,
            field: "instructions",
            max: Limits.maxInstructions
        )
    }

    /// Validates tags array
    func validateTags(_ tags: [Any]) throws {
        try validateArraySize(
            tags,
            field: "tags",
            max: Limits.maxTags
        )
    }

    /// Validates comments array
    func validateComments(_ comments: [Any]) throws {
        try validateArraySize(
            comments,
            field: "comments",
            max: Limits.maxComments
        )
    }

    // MARK: - Firestore Document Size Validation

    /// Checks if data will fit within Firestore's 1MB limit
    /// Returns the estimated size in bytes
    func estimateFirestoreDocumentSize(
        title: String,
        notes: String?,
        ingredients: [Any],
        instructions: [Any],
        tags: [Any]
    ) -> Int {
        var size = 0

        // Title (UTF-8 bytes + field name overhead)
        size += title.utf8.count + 10

        // Notes
        if let notes = notes {
            size += notes.utf8.count + 10
        }

        // Estimate arrays (rough approximation: 200 bytes per item)
        size += ingredients.count * 200
        size += instructions.count * 100
        size += tags.count * 50

        // Add overhead for document structure (fields, IDs, timestamps)
        size += 500

        return size
    }

    /// Validates that document will fit in Firestore (1MB limit)
    func validateFirestoreDocumentSize(estimatedSize: Int) throws {
        let maxSize = 1_048_576 // 1 MB in bytes

        guard estimatedSize <= maxSize else {
            throw ValidationError.documentTooLarge(
                estimatedSize: estimatedSize,
                maxSize: maxSize
            )
        }
    }
}

// MARK: - Validation Errors

enum ValidationError: LocalizedError {
    case emptyField(String)
    case tooLong(field: String, max: Int, actual: Int)
    case tooManyItems(field: String, max: Int, actual: Int)
    case invalidValue(field: String, reason: String)
    case invalidRange(field: String, min: Int, max: Int)
    case documentTooLarge(estimatedSize: Int, maxSize: Int)

    var errorDescription: String? {
        switch self {
        case .emptyField(let field):
            return "\(field.capitalized) cannot be empty"

        case .tooLong(let field, let max, let actual):
            return "\(field.capitalized) is too long (\(actual) characters). Maximum is \(max) characters."

        case .tooManyItems(let field, let max, let actual):
            return "Too many \(field) (\(actual) items). Maximum is \(max) items."

        case .invalidValue(let field, let reason):
            return "\(field.capitalized) is invalid: \(reason)"

        case .invalidRange(let field, let min, let max):
            return "\(field.capitalized) range is invalid: minimum (\(min)) must be less than or equal to maximum (\(max))"

        case .documentTooLarge(let estimatedSize, let maxSize):
            let sizeMB = Double(estimatedSize) / 1_048_576
            let maxMB = Double(maxSize) / 1_048_576
            return "Recipe is too large (\(String(format: "%.2f", sizeMB)) MB). Maximum size is \(String(format: "%.2f", maxMB)) MB. Consider removing some content."
        }
    }
}
