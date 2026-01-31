//
//  ServingsParser.swift
//  Heirloom
//
//  Created by Claude on 2026-01-30.
//

import Foundation

/// Enhanced parser for extracting serving counts from varied string formats
///
/// Handles multiple serving formats:
/// - "6 servings" → 6
/// - "Serves 4-6 people" → 4
/// - "Makes 2 dozen" → 24
/// - "Yield: 8 portions" → 8
///
/// Uses multiple strategies:
/// 1. Keyword-based extraction (serves, makes, yield, etc.)
/// 2. First reasonable number extraction
/// 3. Special unit handling (dozen)
/// 4. Filtering out non-serving numbers (temperatures, years)
struct ServingsParser {

    /// Attempts multiple strategies to extract serving count
    ///
    /// - Parameter servingsString: The raw servings string to parse
    /// - Returns: Extracted serving count, or nil if unparseable
    static func parse(_ servingsString: String?) -> Int? {
        guard let text = servingsString?.lowercased() else { return nil }

        // Strategy 1: Look for keywords followed by numbers
        if let count = extractWithKeywords(text) {
            return count
        }

        // Strategy 2: Extract first reasonable number
        if let count = extractFirstNumber(text) {
            return count
        }

        // Strategy 3: Handle "dozen" unit
        if let count = extractDozens(text) {
            return count
        }

        return nil
    }

    /// Extracts number after common serving keywords
    ///
    /// Examples:
    /// - "serves 6 people" → 6
    /// - "makes 12 cookies" → 12
    /// - "yield: 8 portions" → 8
    private static func extractWithKeywords(_ text: String) -> Int? {
        let keywords = ["serves", "servings", "makes", "yield", "portions", "people"]

        for keyword in keywords {
            if let range = text.range(of: keyword) {
                // Get text after keyword
                let afterKeyword = String(text[range.upperBound...])

                // Look for first number
                if let match = afterKeyword.range(of: #"\d+"#, options: .regularExpression) {
                    let numberString = String(afterKeyword[match])
                    if let number = Int(numberString), number > 0 && number <= 200 {
                        return number
                    }
                }
            }
        }

        return nil
    }

    /// Extracts first reasonable number, filtering out unlikely serving counts
    ///
    /// Filters out:
    /// - Temperature ranges (300-500)
    /// - Years (1900-2100)
    /// - Invalid ranges (0, negative, > 200)
    private static func extractFirstNumber(_ text: String) -> Int? {
        // Find all numbers
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .filter { $0 > 0 && $0 <= 200 }

        // Filter out likely non-serving numbers
        let filtered = numbers.filter { number in
            // Exclude common temperature ranges
            if number >= 300 && number <= 500 { return false }
            // Exclude years
            if number >= 1900 && number <= 2100 { return false }
            return true
        }

        return filtered.first
    }

    /// Handles "dozen" unit in servings strings
    ///
    /// Examples:
    /// - "Makes 2 dozen" → 24
    /// - "1 dozen cookies" → 12
    private static func extractDozens(_ text: String) -> Int? {
        // Match "2 dozen", "1 dozen", etc.
        if let match = text.range(of: #"(\d+)\s*dozen"#, options: .regularExpression) {
            let matchText = String(text[match])
            if let numberMatch = matchText.range(of: #"\d+"#, options: .regularExpression) {
                let numberString = String(matchText[numberMatch])
                if let dozens = Int(numberString) {
                    return dozens * 12
                }
            }
        }

        return nil
    }
}
