import Foundation

/// Parses OCR text to detect and extract recipe structure
/// Identifies title, ingredients, instructions, and metadata
@MainActor
final class RecipeStructureParser {

    init() {}

    // MARK: - Public API

    /// Parse raw OCR text into structured recipe components
    /// - Parameter text: Raw text from OCR
    /// - Returns: Structured recipe data
    func parse(_ text: String) async -> ParsedRecipe {
        Log.debug("Parsing recipe structure from OCR text", category: .ocr, metadata: ["textLength": text.count])

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return ParsedRecipe(
                title: nil,
                ingredients: [],
                instructions: [],
                servings: nil,
                prepTime: nil,
                cookTime: nil,
                confidence: 0
            )
        }

        // Detect sections
        let sections = detectSections(in: lines)

        // Extract title (usually first non-header line)
        let title = extractTitle(from: lines, sections: sections)

        // Extract metadata
        let metadata = extractMetadata(from: lines)

        // Extract ingredients
        let ingredients = extractIngredients(from: lines, sections: sections)

        // Extract instructions
        let instructions = extractInstructions(from: lines, sections: sections)

        // Calculate confidence
        let confidence = calculateConfidence(
            hasTitle: title != nil,
            ingredientCount: ingredients.count,
            instructionCount: instructions.count
        )

        let result = ParsedRecipe(
            title: title,
            ingredients: ingredients,
            instructions: instructions,
            servings: metadata.servings,
            prepTime: metadata.prepTime,
            cookTime: metadata.cookTime,
            confidence: confidence
        )

        Log.info("Recipe structure parsed", category: .ocr, metadata: [
            "hasTitle": title != nil,
            "ingredientCount": ingredients.count,
            "instructionCount": instructions.count,
            "confidence": confidence
        ])

        return result
    }

    // MARK: - Section Detection

    private func detectSections(in lines: [String]) -> RecipeSections {
        var sections = RecipeSections()

        for (index, line) in lines.enumerated() {
            let lowercased = line.lowercased()

            // Detect ingredients section
            if lowercased.contains("ingredient") {
                sections.ingredientsStart = index + 1
            }

            // Detect instructions section
            if lowercased.contains("instruction") || lowercased.contains("direction") || lowercased.contains("method") {
                sections.instructionsStart = index + 1
                // End ingredients section before instructions
                if sections.ingredientsStart != nil && sections.ingredientsEnd == nil {
                    sections.ingredientsEnd = index
                }
            }
        }

        // If no explicit sections found, use heuristics
        if sections.ingredientsStart == nil {
            // Look for first line with measurements (likely ingredients)
            for (index, line) in lines.enumerated() {
                if isMeasurementLine(line) {
                    sections.ingredientsStart = index
                    break
                }
            }
        }

        if sections.instructionsStart == nil && sections.ingredientsStart != nil {
            // Instructions usually start after a gap or when numbered lines appear
            for (index, line) in lines.enumerated() where index > (sections.ingredientsStart ?? 0) {
                if isInstructionLine(line) {
                    sections.instructionsStart = index
                    if sections.ingredientsEnd == nil {
                        sections.ingredientsEnd = index
                    }
                    break
                }
            }
        }

        return sections
    }

    // MARK: - Title Extraction

    private func extractTitle(from lines: [String], sections: RecipeSections) -> String? {
        // Title is usually the first 1-2 lines before any sections
        let titleEndIndex = min(sections.ingredientsStart ?? 3, 3)

        let titleLines = lines.prefix(titleEndIndex)
            .filter { line in
                // Filter out obvious non-title lines
                let lowercased = line.lowercased()
                return !lowercased.contains("serves") &&
                       !lowercased.contains("prep time") &&
                       !lowercased.contains("cook time") &&
                       !lowercased.contains("ingredient") &&
                       !isMeasurementLine(line)
            }

        return titleLines.first
    }

    // MARK: - Metadata Extraction

    private func extractMetadata(from lines: [String]) -> RecipeMetadata {
        var servings: String?
        var prepTime: String?
        var cookTime: String?

        for line in lines {
            let lowercased = line.lowercased()

            // Extract servings
            if lowercased.contains("serves") || lowercased.contains("servings") {
                servings = extractServings(from: line)
            }

            // Extract prep time
            if lowercased.contains("prep") && lowercased.contains("time") {
                prepTime = extractTime(from: line)
            }

            // Extract cook time
            if lowercased.contains("cook") && lowercased.contains("time") {
                cookTime = extractTime(from: line)
            }
        }

        return RecipeMetadata(
            servings: servings,
            prepTime: prepTime,
            cookTime: cookTime
        )
    }

    private func extractServings(from line: String) -> String? {
        // Match patterns like "Serves 4", "4 servings", "Serves: 4-6"
        let patterns = [
            #"(?:serves|servings):?\s*(\d+(?:-\d+)?)"#,
            #"(\d+(?:-\d+)?)\s*(?:serves|servings)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range(at: 1), in: line) {
                return String(line[range])
            }
        }

        return nil
    }

    private func extractTime(from line: String) -> String? {
        // Match patterns like "30 minutes", "1 hour", "1 hr 30 min"
        let patterns = [
            #"(\d+\s*(?:hours?|hrs?|minutes?|mins?)(?:\s*\d+\s*(?:minutes?|mins?))?)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range, in: line) {
                return String(line[range])
            }
        }

        return nil
    }

    // MARK: - Ingredient Extraction

    private func extractIngredients(from lines: [String], sections: RecipeSections) -> [String] {
        guard let start = sections.ingredientsStart else {
            // No explicit section, look for measurement lines
            return lines.filter { isMeasurementLine($0) }
        }

        let end = sections.ingredientsEnd ?? sections.instructionsStart ?? lines.count

        return Array(lines[start..<min(end, lines.count)])
            .filter { line in
                // Filter out section headers and empty lines
                !line.lowercased().contains("ingredient") &&
                !line.isEmpty
            }
    }

    // MARK: - Instruction Extraction

    private func extractInstructions(from lines: [String], sections: RecipeSections) -> [String] {
        guard let start = sections.instructionsStart else {
            // No explicit section, look for instruction-like lines
            return lines.filter { isInstructionLine($0) }
        }

        let instructionLines = Array(lines[start..<lines.count])
            .filter { line in
                // Filter out section headers
                let lowercased = line.lowercased()
                return !lowercased.contains("instruction") &&
                       !lowercased.contains("direction") &&
                       !lowercased.contains("method") &&
                       !line.isEmpty
            }

        // Clean up numbered/bulleted instructions
        return instructionLines.map { cleanInstructionText($0) }
    }

    // MARK: - Helper Methods

    private func isMeasurementLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()

        // Check for common measurement units
        let units = [
            "cup", "cups", "tablespoon", "tbsp", "teaspoon", "tsp",
            "ounce", "oz", "pound", "lb", "gram", "kg", "ml", "liter",
            "pinch", "dash", "clove", "slice"
        ]

        for unit in units {
            if lowercased.contains(unit) {
                return true
            }
        }

        // Check for fraction patterns (1/2, 1/4, etc.)
        let fractionPattern = #"\d+/\d+"#
        if let _ = try? NSRegularExpression(pattern: fractionPattern).firstMatch(
            in: line,
            range: NSRange(line.startIndex..., in: line)
        ) {
            return true
        }

        // Check for number followed by text (likely ingredient)
        let numberPattern = #"^\s*\d+"#
        if let _ = try? NSRegularExpression(pattern: numberPattern).firstMatch(
            in: line,
            range: NSRange(line.startIndex..., in: line)
        ) {
            return true
        }

        return false
    }

    private func isInstructionLine(_ line: String) -> Bool {
        // Check if line starts with a number (step number)
        let numberPattern = #"^\s*\d+\.?\s+"#
        if let _ = try? NSRegularExpression(pattern: numberPattern).firstMatch(
            in: line,
            range: NSRange(line.startIndex..., in: line)
        ) {
            return true
        }

        // Check for instruction keywords
        let instructionKeywords = [
            "preheat", "mix", "combine", "stir", "bake", "cook", "heat",
            "add", "pour", "blend", "whisk", "fold", "spread", "place"
        ]

        let lowercased = line.lowercased()
        for keyword in instructionKeywords {
            if lowercased.contains(keyword) {
                return true
            }
        }

        return false
    }

    private func cleanInstructionText(_ text: String) -> String {
        // Remove step numbers (e.g., "1.", "2)", "Step 1:")
        var cleaned = text

        let patterns = [
            #"^\s*\d+\.?\s+"#,  // "1. " or "1 "
            #"^\s*\d+\)\s+"#,    // "1) "
            #"^step\s*\d+:?\s*"# // "Step 1:" or "step 1"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: ""
                )
            }
        }

        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    private func calculateConfidence(
        hasTitle: Bool,
        ingredientCount: Int,
        instructionCount: Int
    ) -> Double {
        var score = 0.0

        // Title contributes 20%
        if hasTitle {
            score += 0.2
        }

        // Ingredients contribute 40%
        if ingredientCount > 0 {
            score += min(Double(ingredientCount) / 10.0, 1.0) * 0.4
        }

        // Instructions contribute 40%
        if instructionCount > 0 {
            score += min(Double(instructionCount) / 5.0, 1.0) * 0.4
        }

        return min(score, 1.0)
    }
}

// MARK: - Supporting Types

extension RecipeStructureParser {

    /// Parsed recipe structure
    struct ParsedRecipe {
        let title: String?
        let ingredients: [String]
        let instructions: [String]
        let servings: String?
        let prepTime: String?
        let cookTime: String?
        let confidence: Double

        var isComplete: Bool {
            title != nil && !ingredients.isEmpty && !instructions.isEmpty
        }

        var confidencePercentage: String {
            String(format: "%.0f%%", confidence * 100)
        }

        var qualityDescription: String {
            if confidence >= 0.8 {
                return "Excellent"
            } else if confidence >= 0.6 {
                return "Good"
            } else if confidence >= 0.4 {
                return "Fair"
            } else {
                return "Poor"
            }
        }
    }

    private struct RecipeSections {
        var ingredientsStart: Int?
        var ingredientsEnd: Int?
        var instructionsStart: Int?
    }

    private struct RecipeMetadata {
        let servings: String?
        let prepTime: String?
        let cookTime: String?
    }
}

// MARK: - Convenience Extensions

extension RecipeStructureParser.ParsedRecipe {
    /// Get ingredients as parsed ingredient objects
    /// Uses existing AIIngredientParser for detailed parsing
    func parseIngredients() async throws -> [(quantity: Double?, quantityMax: Double?, unit: String?, name: String)] {
        let parser = await ServiceContainer.shared.resolve(AIIngredientParserProtocol.self)
        let parsed = try await parser.parseBatch(ingredients)
        return parsed.map { ($0.quantity, $0.quantityMax, $0.unit, $0.name) }
    }

    /// Summary of what was detected
    var summary: String {
        var parts: [String] = []

        if title != nil {
            parts.append("Title")
        }

        if !ingredients.isEmpty {
            parts.append("\(ingredients.count) ingredients")
        }

        if !instructions.isEmpty {
            parts.append("\(instructions.count) steps")
        }

        if servings != nil {
            parts.append("Servings")
        }

        if prepTime != nil {
            parts.append("Prep time")
        }

        if cookTime != nil {
            parts.append("Cook time")
        }

        return parts.isEmpty ? "No recipe data detected" : parts.joined(separator: ", ")
    }
}
