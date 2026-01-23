import Foundation
import UniformTypeIdentifiers

/// Analyzes text content from Notes to determine if it contains recipe URLs and/or recipe text
struct NotesContentAnalyzer {

    struct AnalysisResult {
        let urls: [String]
        let plainText: String?
        let hasRecipeContent: Bool
        let confidence: ConfidenceLevel

        var shouldUseBulkImport: Bool {
            urls.count >= 2 || (urls.count >= 1 && hasRecipeContent)
        }

        var shouldUseTextImport: Bool {
            urls.isEmpty && hasRecipeContent
        }
    }

    enum ConfidenceLevel {
        case high    // Multiple URLs or clear recipe structure
        case medium  // Single URL + text or recipe keywords
        case low     // Ambiguous content
        case none    // Not recipe content
    }

    /// Analyze text content to determine import strategy
    static func analyze(_ text: String) -> AnalysisResult {
        // 1. Extract URLs
        let urls = extractURLs(from: text)

        // 2. Extract remaining text (remove URLs)
        let plainText = removeURLs(from: text, urls: urls)

        // 3. Analyze text for recipe content
        let hasRecipe = detectRecipeContent(in: plainText)

        // 4. Calculate confidence
        let confidence = calculateConfidence(
            urlCount: urls.count,
            textLength: plainText.count,
            hasRecipe: hasRecipe
        )

        return AnalysisResult(
            urls: urls,
            plainText: plainText.isEmpty ? nil : plainText,
            hasRecipeContent: hasRecipe,
            confidence: confidence
        )
    }

    // MARK: - URL Extraction

    private static func extractURLs(from text: String) -> [String] {
        var urls: [String] = []
        var seen: Set<String> = []

        // Use NSDataDetector to find URLs
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        let matches = detector.matches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: text.utf16.count)
        )

        for match in matches {
            if let url = match.url?.absoluteString {
                // Only include http/https URLs
                if url.hasPrefix("http://") || url.hasPrefix("https://") {
                    // Normalize for deduplication (lowercase, no trailing slash)
                    let normalized = normalizeURL(url)
                    if !seen.contains(normalized) {
                        seen.insert(normalized)
                        urls.append(url)  // Store original URL
                    }
                }
            }
        }

        return urls
    }

    private static func normalizeURL(_ url: String) -> String {
        var normalized = url.lowercased()
        if normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }
        return normalized
    }

    private static func removeURLs(from text: String, urls: [String]) -> String {
        var cleaned = text

        // Remove each URL from the text
        for url in urls {
            cleaned = cleaned.replacingOccurrences(of: url, with: "")
        }

        // Clean up extra whitespace
        cleaned = cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return cleaned
    }

    // MARK: - Recipe Content Detection

    private static func detectRecipeContent(in text: String) -> Bool {
        // Minimum text length for a recipe
        guard text.count >= 100 else { return false }

        let lowercased = text.lowercased()

        // Recipe-related keywords
        let keywords = [
            // Ingredients
            "ingredient", "cup", "tablespoon", "teaspoon", "tsp", "tbsp",
            "ounce", "oz", "pound", "lb", "gram", "kg", "pinch", "dash",

            // Cooking actions
            "bake", "cook", "prepare", "mix", "stir", "whisk", "blend",
            "heat", "boil", "simmer", "fry", "sauté", "roast", "grill",

            // Recipe structure
            "recipe", "directions", "instructions", "method", "steps",

            // Time/measurement
            "minutes", "hours", "degrees", "temperature", "serves", "servings",
            "yield", "makes", "prep time", "cook time",

            // Kitchen equipment
            "oven", "pan", "pot", "bowl", "skillet",

            // Common ingredients
            "flour", "sugar", "salt", "pepper", "butter", "egg", "milk",
            "cheese", "chicken", "beef", "garlic", "onion"
        ]

        // Count keyword matches
        let matches = keywords.filter { lowercased.contains($0) }.count

        // Require at least 3 keyword matches for confidence
        return matches >= 3
    }

    // MARK: - Confidence Calculation

    private static func calculateConfidence(
        urlCount: Int,
        textLength: Int,
        hasRecipe: Bool
    ) -> ConfidenceLevel {
        // Multiple URLs = high confidence (recipe collection)
        if urlCount >= 2 {
            return .high
        }

        // Single URL + recipe text = medium confidence
        if urlCount == 1 && hasRecipe {
            return .medium
        }

        // Recipe text only = medium confidence
        if urlCount == 0 && hasRecipe {
            return .medium
        }

        // Single URL only = low confidence (might not be Notes-specific)
        if urlCount == 1 {
            return .low
        }

        // No URLs, no recipe content = none
        return .none
    }
}
