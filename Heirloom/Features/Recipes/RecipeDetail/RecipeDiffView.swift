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

                    // Ingredients diff
                    ingredientsDiff

                    // Instructions diff
                    instructionsDiff
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
        Group {
            if let currentRecipe = currentVersion.recipe,
               let currentIngredients = currentRecipe.ingredients,
               let comparedVersion = comparedVersion,
               currentVersion.id != comparedVersion.id {

                let diffs = calculateIngredientDiffs(
                    current: currentIngredients,
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
        Group {
            if let currentRecipe = currentVersion.recipe,
               let comparedVersion = comparedVersion {

                let diffs = calculateInstructionDiffs(
                    current: currentRecipe.instructions,
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

    private func calculateIngredientDiffs(
        current: [Ingredient],
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

        let currentTexts = current.map { $0.originalText }
        Log.debug("Comparing recipe ingredients", category: .ui, metadata: [
            "currentCount": currentTexts.count,
            "comparedCount": comparedIngredients.count,
            "currentIngredients": currentTexts.joined(separator: " | "),
            "comparedIngredients": comparedIngredients.joined(separator: " | ")
        ])

        // Find added ingredients
        for text in currentTexts where !comparedIngredients.contains(text) {
            diffs.append((text, .added))
        }

        // Find removed ingredients
        for text in comparedIngredients where !currentTexts.contains(text) {
            diffs.append((text, .removed))
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
}

enum ChangeType {
    case added
    case modified
    case removed
}
