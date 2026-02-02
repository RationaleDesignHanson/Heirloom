import SwiftUI

/// Lightweight diff viewer for imported recipes showing original vs current state
struct RecipeImportDiffView: View {
    let diff: RecipeDiff
    let currentRecipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("Original Imported Version")
                .font(HeirloomFonts.caption1.weight(.semibold))
                .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))

            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                // Title
                if diff.titleChanged {
                    DiffFieldView(
                        label: "Title",
                        original: diff.original.title,
                        current: currentRecipe.title
                    )
                }

                // Servings / Times
                HStack(spacing: HeirloomSpacing.md) {
                    if diff.servingsChanged {
                        DiffFieldView(
                            label: "Servings",
                            original: diff.original.servings,
                            current: currentRecipe.servings
                        )
                    }

                    if diff.prepTimeChanged {
                        DiffFieldView(
                            label: "Prep",
                            original: diff.original.prepTime,
                            current: currentRecipe.prepTime
                        )
                    }

                    if diff.cookTimeChanged {
                        DiffFieldView(
                            label: "Cook",
                            original: diff.original.cookTime,
                            current: currentRecipe.cookTime
                        )
                    }
                }

                // Ingredients
                if diff.ingredientsChanged {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                        Text("Ingredients")
                            .font(HeirloomFonts.caption2.weight(.medium))
                            .foregroundStyle(HeirloomColors.charcoal.opacity(0.7))

                        ForEach(diff.original.ingredients.indices, id: \.self) { index in
                            let ingredient = diff.original.ingredients[index]
                            let isRemoved = !currentRecipeContainsIngredient(ingredient)

                            Text("• \(ingredient.originalText)")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.charcoal.opacity(isRemoved ? 0.4 : 0.6))
                                .strikethrough(isRemoved, color: HeirloomColors.tomato.opacity(0.5))
                        }
                    }
                }

                // Instructions
                if diff.instructionsChanged {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                        Text("Instructions")
                            .font(HeirloomFonts.caption2.weight(.medium))
                            .foregroundStyle(HeirloomColors.charcoal.opacity(0.7))

                        ForEach(diff.original.instructions.indices, id: \.self) { index in
                            let instruction = diff.original.instructions[index]
                            let isRemoved = !currentRecipe.instructions.contains(instruction)

                            Text("\(index + 1). \(instruction)")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.charcoal.opacity(isRemoved ? 0.4 : 0.6))
                                .strikethrough(isRemoved, color: HeirloomColors.tomato.opacity(0.5))
                        }
                    }
                }

                // Notes
                if diff.notesChanged, let originalNotes = diff.original.notes {
                    DiffFieldView(
                        label: "Notes",
                        original: originalNotes,
                        current: currentRecipe.notes
                    )
                }
            }
            .padding(HeirloomSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                    .fill(HeirloomColors.cream.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                    .stroke(HeirloomColors.charcoal.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private func currentRecipeContainsIngredient(
        _ snapshot: RecipeSnapshot.IngredientSnapshot
    ) -> Bool {
        currentRecipe.ingredients?.contains(where: { ing in
            ing.originalText == snapshot.originalText
        }) ?? false
    }
}

private struct DiffFieldView: View {
    let label: String
    let original: String?
    let current: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(HeirloomFonts.caption2.weight(.medium))
                .foregroundStyle(HeirloomColors.charcoal.opacity(0.7))

            if let original = original {
                let isChanged = original != current
                Text(original)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.charcoal.opacity(isChanged ? 0.4 : 0.6))
                    .strikethrough(isChanged, color: HeirloomColors.tomato.opacity(0.5))
            }
        }
    }
}
