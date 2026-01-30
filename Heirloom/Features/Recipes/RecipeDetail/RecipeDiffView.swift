import SwiftUI

/// Shows differences between two recipe versions with green highlighting
struct RecipeDiffView: View {
    let currentVersion: RecipeLineageVersion
    let comparedVersion: RecipeLineageVersion?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let compared = comparedVersion, compared.id != currentVersion.id {
                // Show diffs
                VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                    // Title diff
                    if currentVersion.title != compared.title {
                        titleDiff
                    }

                    // Servings diff
                    servingsDiff

                    // Timing diffs
                    timingDiffs

                    // Ingredients diff
                    ingredientsDiff

                    // Instructions diff
                    instructionsDiff

                    // Notes diff
                    notesDiff
                }
            }
        }
    }

    private var titleDiff: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
            HStack {
                Image(systemName: "text.badge.checkmark")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.success)
                Text("Title Changed")
                    .font(HeirloomFonts.caption1Bold)
                    .foregroundStyle(HeirloomColors.success)
            }

            Text(currentVersion.title)
                .font(HeirloomFonts.body)
                .padding(HeirloomSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(HeirloomColors.success.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(HeirloomColors.success.opacity(0.3), lineWidth: 1)
                )
        }
    }

    private var ingredientsDiff: some View {
        // Get current ingredients (from recipe OR recipeData)
        let currentIngredientTexts: [String]
        if let currentRecipe = currentVersion.recipe,
           let currentIngredients = currentRecipe.ingredients {
            currentIngredientTexts = currentIngredients.map { $0.originalText }
        } else if let data = currentVersion.recipeData,
                  let ingredientsData = data["ingredients"] as? [[String: Any]] {
            currentIngredientTexts = ingredientsData.compactMap { $0["originalText"] as? String }
        } else {
            currentIngredientTexts = []
        }

        return Group {
            if let comparedVersion = comparedVersion,
               currentVersion.id != comparedVersion.id {

                let diffs = calculateIngredientDiffsFromTexts(
                    currentTexts: currentIngredientTexts,
                    compared: comparedVersion
                )

                // Show if there are any changes
                if !diffs.isEmpty {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        HStack {
                            Image(systemName: "list.bullet.badge.plus")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.success)
                            Text("Ingredients Modified")
                                .font(HeirloomFonts.caption1Bold)
                                .foregroundStyle(HeirloomColors.success)
                        }

                        ForEach(diffs, id: \.0) { diff in
                            HStack(alignment: .top) {
                                Image(systemName: diff.1 == .added ? "plus.circle.fill" : "circle")
                                    .font(HeirloomFonts.caption1)
                                    .foregroundStyle(diff.1 == .removed ? .gray : HeirloomColors.success)

                                Text(diff.0)
                                    .font(HeirloomFonts.body)
                                    .strikethrough(diff.1 == .removed)
                                    .foregroundStyle(diff.1 == .removed ? .gray : .primary)
                            }
                            .padding(HeirloomSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(diff.1 != .removed ? HeirloomColors.success.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(diff.1 != .removed ? HeirloomColors.success.opacity(0.3) : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }

    private var instructionsDiff: some View {
        // Get current instructions (from recipe OR recipeData)
        let currentInstructions: [String]
        if let currentRecipe = currentVersion.recipe {
            currentInstructions = currentRecipe.instructions
        } else if let data = currentVersion.recipeData,
                  let instructions = data["instructions"] as? [String] {
            currentInstructions = instructions
        } else {
            currentInstructions = []
        }

        return Group {
            if let comparedVersion = comparedVersion {

                let diffs = calculateInstructionDiffs(
                    current: currentInstructions,
                    compared: comparedVersion
                )

                if !diffs.isEmpty {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        HStack {
                            Image(systemName: "list.number.badge.plus")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.success)
                            Text("Instructions Modified")
                                .font(HeirloomFonts.caption1Bold)
                                .foregroundStyle(HeirloomColors.success)
                        }

                        ForEach(Array(diffs.enumerated()), id: \.offset) { index, diff in
                            HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
                                Text("\(index + 1).")
                                    .font(HeirloomFonts.bodyBold)
                                    .foregroundStyle(diff.1 == .removed ? .gray : HeirloomColors.charcoal.opacity(0.6))
                                    .frame(width: 25, alignment: .leading)

                                Image(systemName: diff.1 == .added ? "plus.circle.fill" : "circle")
                                    .font(HeirloomFonts.caption1)
                                    .foregroundStyle(diff.1 == .removed ? .gray : HeirloomColors.success)

                                Text(diff.0)
                                    .font(HeirloomFonts.body)
                                    .strikethrough(diff.1 == .removed)
                                    .foregroundStyle(diff.1 == .removed ? .gray : .primary)
                            }
                            .padding(HeirloomSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(diff.1 != .removed ? HeirloomColors.success.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(diff.1 != .removed ? HeirloomColors.success.opacity(0.3) : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Diff Calculation

    /// Normalizes ingredient text for comparison by converting fractions to decimals
    /// This prevents false positives like "1/2 cup" vs "0.5 cup"
    private func normalizeIngredient(_ text: String) -> String {
        var normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Common fraction mappings
        let fractionMappings: [(String, String)] = [
            ("1/2", "0.5"),
            ("1/3", "0.33"),
            ("2/3", "0.67"),
            ("1/4", "0.25"),
            ("3/4", "0.75"),
            ("1/8", "0.13"),
            ("3/8", "0.38"),
            ("5/8", "0.63"),
            ("7/8", "0.88"),
            ("1/6", "0.17"),
            ("5/6", "0.83"),
            ("2/5", "0.4"),
            ("3/5", "0.6"),
            ("4/5", "0.8")
        ]

        // Replace fractions with decimals
        for (fraction, decimal) in fractionMappings {
            normalized = normalized.replacingOccurrences(of: fraction, with: decimal)
        }

        // Normalize decimal representations (0.50 → 0.5)
        let decimalPattern = "\\b0\\.(\\d*?)0+\\b"
        if let regex = try? NSRegularExpression(pattern: decimalPattern) {
            let range = NSRange(normalized.startIndex..., in: normalized)
            normalized = regex.stringByReplacingMatches(
                in: normalized,
                range: range,
                withTemplate: "0.$1"
            )
        }

        // Remove extra whitespace
        normalized = normalized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return normalized
    }

    /// Checks if two ingredients are equivalent after normalization
    private func ingredientsMatch(_ ingredient1: String, _ ingredient2: String) -> Bool {
        return normalizeIngredient(ingredient1) == normalizeIngredient(ingredient2)
    }

    private func calculateIngredientDiffsFromTexts(
        currentTexts: [String],
        compared: RecipeLineageVersion
    ) -> [(String, ChangeType)] {
        var diffs: [(String, ChangeType)] = []

        // Get compared ingredients (from recipe data if available)
        let comparedIngredients: [String]
        if let recipe = compared.recipe, let ingredients = recipe.ingredients {
            comparedIngredients = ingredients.map { $0.originalText }
            Log.debug("Using compared recipe ingredients for diff", category: .ui, metadata: [
                "count": comparedIngredients.count,
                "source": "recipe",
                "generation": compared.generation,
                "ingredients": comparedIngredients.joined(separator: " | ")
            ])
        } else if let data = compared.recipeData,
                  let ingredientsData = data["ingredients"] as? [[String: Any]] {
            comparedIngredients = ingredientsData.compactMap { $0["originalText"] as? String }
            Log.debug("Using compared recipe data ingredients for diff", category: .ui, metadata: [
                "count": comparedIngredients.count,
                "source": "recipeData",
                "generation": compared.generation,
                "ingredients": comparedIngredients.joined(separator: " | ")
            ])
        } else {
            comparedIngredients = []
            Log.warning("No ingredient data found in compared version, showing all as added", category: .ui, metadata: ["generation": compared.generation])
        }

        Log.debug("Comparing recipe ingredients", category: .ui, metadata: [
            "currentCount": currentTexts.count,
            "comparedCount": comparedIngredients.count,
            "currentIngredients": currentTexts.joined(separator: " | "),
            "comparedIngredients": comparedIngredients.joined(separator: " | ")
        ])

        // Find added ingredients (using normalized comparison)
        for text in currentTexts {
            let isInCompared = comparedIngredients.contains { ingredientsMatch(text, $0) }
            if !isInCompared {
                diffs.append((text, .added))
            }
        }

        // Find removed ingredients (using normalized comparison)
        for text in comparedIngredients {
            let isInCurrent = currentTexts.contains { ingredientsMatch(text, $0) }
            if !isInCurrent {
                diffs.append((text, .removed))
            }
        }

        return diffs
    }

    private func calculateInstructionDiffs(
        current: [String],
        compared: RecipeLineageVersion
    ) -> [(String, ChangeType)] {
        var diffs: [(String, ChangeType)] = []

        // Get compared instructions
        let comparedInstructions: [String]
        if let recipe = compared.recipe {
            comparedInstructions = recipe.instructions
        } else if let data = compared.recipeData,
                  let instructions = data["instructions"] as? [String] {
            comparedInstructions = instructions
        } else {
            comparedInstructions = []
        }

        // Find added or modified instructions
        for (index, instruction) in current.enumerated() {
            if index >= comparedInstructions.count {
                diffs.append((instruction, .added))
            } else if instruction != comparedInstructions[index] {
                diffs.append((instruction, .modified))
            }
        }

        // Find removed instructions
        if comparedInstructions.count > current.count {
            for index in current.count..<comparedInstructions.count {
                diffs.append((comparedInstructions[index], .removed))
            }
        }

        return diffs
    }

    // MARK: - Additional Field Diffs

    private var servingsDiff: some View {
        Group {
            if let comparedVersion = comparedVersion,
               let currentServings = currentVersion.recipe?.servings ?? currentVersion.recipeData?["servings"] as? String,
               let originalServings = comparedVersion.recipe?.servings ?? comparedVersion.recipeData?["servings"] as? String,
               currentServings != originalServings {

                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.success)
                        Text("Servings Changed")
                            .font(HeirloomFonts.caption1Bold)
                            .foregroundStyle(HeirloomColors.success)
                    }

                    HStack(spacing: HeirloomSpacing.sm) {
                        Text(originalServings)
                            .font(HeirloomFonts.body)
                            .foregroundStyle(.gray)
                            .strikethrough()

                        Image(systemName: "arrow.right")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.success)

                        Text(currentServings)
                            .font(HeirloomFonts.body)
                            .foregroundStyle(.primary)
                    }
                    .padding(HeirloomSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(HeirloomColors.success.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(HeirloomColors.success.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
    }

    private var timingDiffs: some View {
        Group {
            if let comparedVersion = comparedVersion {
                let currentPrepTime = currentVersion.recipe?.prepTime ?? currentVersion.recipeData?["prepTime"] as? String
                let originalPrepTime = comparedVersion.recipe?.prepTime ?? comparedVersion.recipeData?["prepTime"] as? String
                let currentCookTime = currentVersion.recipe?.cookTime ?? currentVersion.recipeData?["cookTime"] as? String
                let originalCookTime = comparedVersion.recipe?.cookTime ?? comparedVersion.recipeData?["cookTime"] as? String

                let hasPrepChange = currentPrepTime != originalPrepTime
                let hasCookChange = currentCookTime != originalCookTime

                if hasPrepChange || hasCookChange {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.success)
                            Text("Timing Changed")
                                .font(HeirloomFonts.caption1Bold)
                                .foregroundStyle(HeirloomColors.success)
                        }

                        if hasPrepChange, let current = currentPrepTime, let original = originalPrepTime {
                            HStack(spacing: HeirloomSpacing.xs) {
                                Text("Prep:")
                                    .font(HeirloomFonts.caption1Bold)
                                    .foregroundStyle(.secondary)

                                Text(original)
                                    .font(HeirloomFonts.body)
                                    .foregroundStyle(.gray)
                                    .strikethrough()

                                Image(systemName: "arrow.right")
                                    .font(HeirloomFonts.caption1)
                                    .foregroundStyle(HeirloomColors.success)

                                Text(current)
                                    .font(HeirloomFonts.body)
                                    .foregroundStyle(.primary)
                            }
                            .padding(HeirloomSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(HeirloomColors.success.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(HeirloomColors.success.opacity(0.3), lineWidth: 1)
                            )
                        }

                        if hasCookChange, let current = currentCookTime, let original = originalCookTime {
                            HStack(spacing: HeirloomSpacing.xs) {
                                Text("Cook:")
                                    .font(HeirloomFonts.caption1Bold)
                                    .foregroundStyle(.secondary)

                                Text(original)
                                    .font(HeirloomFonts.body)
                                    .foregroundStyle(.gray)
                                    .strikethrough()

                                Image(systemName: "arrow.right")
                                    .font(HeirloomFonts.caption1)
                                    .foregroundStyle(HeirloomColors.success)

                                Text(current)
                                    .font(HeirloomFonts.body)
                                    .foregroundStyle(.primary)
                            }
                            .padding(HeirloomSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(HeirloomColors.success.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(HeirloomColors.success.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }

    private var notesDiff: some View {
        Group {
            if let comparedVersion = comparedVersion,
               let currentNotes = currentVersion.recipe?.notes ?? currentVersion.recipeData?["notes"] as? String,
               let originalNotes = comparedVersion.recipe?.notes ?? comparedVersion.recipeData?["notes"] as? String,
               currentNotes != originalNotes {

                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    HStack {
                        Image(systemName: "note.text")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.success)
                        Text("Notes Changed")
                            .font(HeirloomFonts.caption1Bold)
                            .foregroundStyle(HeirloomColors.success)
                    }

                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        if !originalNotes.isEmpty {
                            Text(originalNotes)
                                .font(HeirloomFonts.body)
                                .foregroundStyle(.gray)
                                .strikethrough()
                                .padding(HeirloomSpacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }

                        if !currentNotes.isEmpty {
                            Text(currentNotes)
                                .font(HeirloomFonts.body)
                                .foregroundStyle(.primary)
                                .padding(HeirloomSpacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(HeirloomColors.success.opacity(0.1))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(HeirloomColors.success.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
    }
}

enum ChangeType {
    case added
    case modified
    case removed
}
