//
//  FilePathValidator.swift
//  Heirloom
//
//  Created by Claude Code on 1/7/26.
//  Security Phase 1: File path validation to prevent path traversal attacks
//

import Foundation

/// File path validator to prevent path traversal and directory escape attacks
/// Ensures file paths stay within allowed directories and don't access system files
class FilePathValidator {
    static let shared = FilePathValidator()

    // MARK: - Configuration

    /// Dangerous path components that indicate traversal attempts
    private let dangerousPathComponents = [
        "..",
        "../",
        "..\\",
        "./../",
        "..\\..\\",
        "%2e%2e",      // URL-encoded ..
        "%2e%2e/",
        "%2e%2e\\",
        "..%2f",
        "..%5c"
    ]

    /// Forbidden path prefixes (system directories)
    private let forbiddenPrefixes = [
        "/etc/",
        "/usr/",
        "/bin/",
        "/sbin/",
        "/var/",
        "/System/",
        "/Library/",
        "/private/",
        "~/"
    ]

    /// Allowed file extensions for recipe images
    private let allowedImageExtensions = [
        "jpg", "jpeg", "png", "gif", "webp", "heic", "heif"
    ]

    // MARK: - Validation Methods

    /// Validates a file path for safety
    /// - Parameter filePath: File path to validate
    /// - Returns: Sanitized file path if safe
    /// - Throws: FilePathValidationError if path is unsafe
    func validate(_ filePath: String?) throws -> String? {
        // Empty paths are allowed (optional field)
        guard let filePath = filePath, !filePath.isEmpty else {
            return nil
        }

        let trimmed = filePath.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return nil
        }

        // Step 1: Check for path traversal attempts
        try checkForTraversalAttempts(trimmed)

        // Step 2: Check for forbidden system directories
        try checkForForbiddenPaths(trimmed)

        // Step 3: Check for null bytes (path truncation attack)
        try checkForNullBytes(trimmed)

        // Step 4: Normalize path (resolve .. and .)
        let normalized = try normalizePath(trimmed)

        return normalized
    }

    /// Validates an image file path specifically
    /// Stricter validation including file extension checking
    func validateImagePath(_ filePath: String?) throws -> String? {
        guard let validated = try validate(filePath) else {
            return nil
        }

        // Check file extension
        let pathExtension = (validated as NSString).pathExtension.lowercased()

        guard !pathExtension.isEmpty else {
            throw FilePathValidationError.missingExtension
        }

        guard allowedImageExtensions.contains(pathExtension) else {
            throw FilePathValidationError.invalidExtension(
                extension: pathExtension,
                allowed: allowedImageExtensions
            )
        }

        return validated
    }

    /// Quick check if path is safe without throwing
    func isSafe(_ filePath: String?) -> Bool {
        do {
            _ = try validate(filePath)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Private Validation Methods

    /// Checks for path traversal patterns
    private func checkForTraversalAttempts(_ path: String) throws {
        let lowercased = path.lowercased()

        for dangerous in dangerousPathComponents {
            if lowercased.contains(dangerous) {
                throw FilePathValidationError.pathTraversal(
                    pattern: dangerous,
                    path: path
                )
            }
        }

        // Check for multiple slashes (path normalization bypass)
        if path.contains("//") || path.contains("\\\\") {
            throw FilePathValidationError.suspiciousPattern(
                pattern: "multiple slashes",
                reason: "Path contains suspicious slash sequences"
            )
        }
    }

    /// Checks for forbidden system directory access
    private func checkForForbiddenPaths(_ path: String) throws {
        for forbidden in forbiddenPrefixes {
            if path.hasPrefix(forbidden) {
                throw FilePathValidationError.forbiddenDirectory(
                    directory: forbidden,
                    reason: "Access to system directories is not allowed"
                )
            }
        }

        // Check for absolute paths (should be relative within app sandbox)
        if path.hasPrefix("/") {
            throw FilePathValidationError.absolutePath(
                path: path,
                reason: "Absolute paths are not allowed. Use relative paths within the app container."
            )
        }
    }

    /// Checks for null byte injection (path truncation attack)
    private func checkForNullBytes(_ path: String) throws {
        if path.contains("\0") || path.contains("%00") {
            throw FilePathValidationError.nullByteInjection(
                reason: "Null bytes in file paths are not allowed"
            )
        }
    }

    /// Normalizes path by resolving relative components
    private func normalizePath(_ path: String) throws -> String {
        // Split into components
        var components = path.components(separatedBy: "/")

        // Filter out empty and "." components
        components = components.filter { !$0.isEmpty && $0 != "." }

        // Check for ".." after filtering (should have been caught earlier)
        if components.contains("..") {
            throw FilePathValidationError.pathTraversal(
                pattern: "..",
                path: path
            )
        }

        // Reconstruct normalized path
        let normalized = components.joined(separator: "/")

        // Ensure normalized path isn't empty
        guard !normalized.isEmpty else {
            throw FilePathValidationError.invalidPath(
                path: path,
                reason: "Path resolves to empty string"
            )
        }

        return normalized
    }

    // MARK: - Helper Methods

    /// Sanitizes a file path by removing dangerous components
    /// Returns nil if path cannot be made safe
    func sanitize(_ filePath: String?) -> String? {
        guard let filePath = filePath else { return nil }

        var sanitized = filePath.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove path traversal attempts
        for dangerous in dangerousPathComponents {
            sanitized = sanitized.replacingOccurrences(of: dangerous, with: "")
        }

        // Remove null bytes
        sanitized = sanitized.replacingOccurrences(of: "\0", with: "")
        sanitized = sanitized.replacingOccurrences(of: "%00", with: "")

        // If path became empty or still contains suspicious patterns, reject
        if sanitized.isEmpty || sanitized.contains("..") {
            return nil
        }

        return sanitized
    }

    /// Extracts filename from path
    func extractFilename(_ filePath: String?) -> String? {
        guard let filePath = filePath else { return nil }
        return (filePath as NSString).lastPathComponent
    }

    /// Extracts file extension from path
    func extractExtension(_ filePath: String?) -> String? {
        guard let filePath = filePath else { return nil }
        let ext = (filePath as NSString).pathExtension
        return ext.isEmpty ? nil : ext.lowercased()
    }

    /// Validates that path is within a specific directory
    func isWithinDirectory(_ filePath: String, directory: String) -> Bool {
        let normalizedPath = (filePath as NSString).standardizingPath
        let normalizedDir = (directory as NSString).standardizingPath

        return normalizedPath.hasPrefix(normalizedDir)
    }
}

// MARK: - Validation Errors

enum FilePathValidationError: LocalizedError {
    case pathTraversal(pattern: String, path: String)
    case forbiddenDirectory(directory: String, reason: String)
    case absolutePath(path: String, reason: String)
    case nullByteInjection(reason: String)
    case suspiciousPattern(pattern: String, reason: String)
    case invalidPath(path: String, reason: String)
    case missingExtension
    case invalidExtension(extension: String, allowed: [String])

    var errorDescription: String? {
        switch self {
        case .pathTraversal(let pattern, _):
            return "Path contains traversal pattern '\(pattern)' which is not allowed for security reasons"

        case .forbiddenDirectory(let directory, let reason):
            return "Cannot access directory '\(directory)': \(reason)"

        case .absolutePath(_, let reason):
            return "Absolute file paths are not allowed: \(reason)"

        case .nullByteInjection(let reason):
            return "Invalid file path: \(reason)"

        case .suspiciousPattern(let pattern, let reason):
            return "Suspicious file path pattern detected (\(pattern)): \(reason)"

        case .invalidPath(_, let reason):
            return "Invalid file path: \(reason)"

        case .missingExtension:
            return "File path must include a file extension"

        case .invalidExtension(let ext, let allowed):
            let allowedList = allowed.joined(separator: ", ")
            return "File extension '.\(ext)' is not allowed. Allowed extensions: \(allowedList)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .pathTraversal:
            return "Use a relative file path without .. or directory traversal patterns"

        case .forbiddenDirectory:
            return "Only store files within the app's container directory"

        case .absolutePath:
            return "Use a relative path or just the filename"

        case .nullByteInjection, .suspiciousPattern:
            return "Use a simple filename without special characters"

        case .invalidPath:
            return "Provide a valid file path"

        case .missingExtension:
            return "Add a file extension (e.g., .jpg, .png)"

        case .invalidExtension(_, let allowed):
            let exampleExt = allowed.first ?? "jpg"
            return "Use an allowed file format such as .\(exampleExt)"
        }
    }
}
