//
//  OnboardingRecipeCard.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-10.
//

import SwiftUI
import SwiftData

/// Simplified recipe card for onboarding preview
/// Shows recipe image, title, and collection name
struct OnboardingRecipeCard: View {
    let recipe: Recipe
    let collection: RecipeCollection?

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Recipe Image
            ZStack(alignment: .topTrailing) {
                AsyncRecipeImage(
                    imageFileName: recipe.imageFileName,
                    firebaseImageURL: recipe.firebaseImageURL,
                    placeholder: recipe.sourceType?.iconName ?? "fork.knife"
                )
                .aspectRatio(4/3, contentMode: .fill)
                .frame(height: 120)
                .clipped()
                .cornerRadius(12)

                // Heritage badge overlay
                if recipe.isThemeRecipe {
                    Text("HERITAGE")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(HeirloomColors.familyGreen)
                        .cornerRadius(4)
                        .padding(HeirloomSpacing.sm)
                }
            }

            // Recipe title
            Text(recipe.title)
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .frame(height: 40, alignment: .topLeading)

            // Collection name
            if let collection = collection {
                HStack(spacing: HeirloomSpacing.xs) {
                    Image(systemName: collection.iconName)
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(collection.swiftUIColor)

                    Text(collection.name)
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HeirloomSpacing.sm)
        .background(Color(hex: "#F8F8F8"))
        .cornerRadius(HeirloomSpacing.cardCornerRadius)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @Query var recipes: [Recipe]
    @Previewable @Query var collections: [RecipeCollection]

    if let recipe = recipes.first, let collection = collections.first {
        OnboardingRecipeCard(recipe: recipe, collection: collection)
            .padding()
            .background(HeirloomColors.cream)
            .modelContainer(for: [Recipe.self, RecipeCollection.self], inMemory: true)
    } else {
        Text("No recipes available")
    }
}
