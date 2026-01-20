//
//  SimilarRecipesInfoView.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/9/26.
//
//  Expandable info card showing similar recipes used for AI augmentation

import SwiftUI

struct SimilarRecipesInfoView: View {
    let augmentedRecipe: AugmentedRecipe?
    let similarRecipes: [SimilarRecipeMatch]
    let webRecipes: [WebRecipeResult]

    @State private var isExpanded: Bool = false

    var body: some View {
        if wasAugmented {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(HeirloomFonts.title2)
                            .foregroundStyle(.orange.gradient)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Similar Recipe Enhancements")
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(.primary)

                            if let metadata = augmentedRecipe?.metadata {
                                Text(summaryText(for: metadata))
                                    .font(HeirloomFonts.caption1)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius))
                }
                .buttonStyle(.plain)

                // Expanded content
                if isExpanded {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                        // Confidence summary
                        if let metadata = augmentedRecipe?.metadata {
                            confidenceSummary(metadata: metadata)
                        }

                        Divider()

                        // Similar recipes list
                        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                            Text("Similar Recipes Used")
                                .font(.subheadline.weight(.semibold))

                            if !similarRecipes.isEmpty {
                                ForEach(similarRecipes) { match in
                                    localRecipeRow(match: match)
                                }
                            }

                            if !webRecipes.isEmpty {
                                ForEach(webRecipes) { webRecipe in
                                    webRecipeRow(webRecipe: webRecipe)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                            .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private var wasAugmented: Bool {
        augmentedRecipe != nil && (!similarRecipes.isEmpty || !webRecipes.isEmpty)
    }

    private func summaryText(for metadata: AugmentationMetadata) -> String {
        let count = metadata.totalInferences
        let confidence = metadata.averageConfidence.shortDisplayText
        return "Enhanced \(count) ingredient\(count == 1 ? "" : "s") · \(confidence) confidence"
    }

    @ViewBuilder
    private func confidenceSummary(metadata: AugmentationMetadata) -> some View {
        HStack(spacing: HeirloomSpacing.md) {
            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                Text("Enhancements")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(.secondary)
                Text("\(metadata.totalInferences)")
                    .font(.title3.bold())
            }

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                Text("Avg. Confidence")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: HeirloomSpacing.xs) {
                    confidenceDot(for: metadata.averageConfidence)
                    Text(metadata.averageConfidence.displayText)
                        .font(.subheadline.weight(.medium))
                }
            }

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                Text("Sources")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(.secondary)
                Text("\(metadata.localRecipesUsed + metadata.webRecipesUsed)")
                    .font(.title3.bold())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func localRecipeRow(match: SimilarRecipeMatch) -> some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: "book.closed.fill")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(match.recipe.title)
                    .font(HeirloomFonts.body)
                    .lineLimit(1)

                Text("\(match.similarityPercentage)% similar · Local recipe")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func webRecipeRow(webRecipe: WebRecipeResult) -> some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: "globe")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(.green)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(webRecipe.title)
                    .font(HeirloomFonts.body)
                    .lineLimit(1)

                Text("\(webRecipe.similarityPercentage)% similar · \(webRecipe.displayDomain)")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func confidenceDot(for confidence: InferenceConfidence) -> some View {
        Circle()
            .fill(confidenceColor(for: confidence))
            .frame(width: 8, height: 8)
    }

    private func confidenceColor(for confidence: InferenceConfidence) -> Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .yellow
        case .unknown: return .gray
        }
    }
}

// MARK: - Preview

#Preview("With Augmentation") {
    ScrollView {
        SimilarRecipesInfoView(
            augmentedRecipe: AugmentedRecipe(
                original: StructuredRecipe(
                    title: "Chocolate Chip Cookies",
                    description: nil,
                    servings: "48 cookies",
                    prepTime: nil,
                    cookTime: nil,
                    ingredients: [],
                    steps: [],
                    overallConfidence: 0.75,
                    warnings: []
                ),
                augmentedIngredients: [
                    AugmentedIngredient(
                        originalIngredient: ExtractedIngredient(
                            originalText: "some flour",
                            item: "flour",
                            quantity: nil,
                            unit: nil,
                            preparation: nil,
                            confidence: .unknown
                        ),
                        inferredQuantity: "2¼",
                        inferredUnit: "cups",
                        inferredConfidence: .high,
                        reasoning: "3 similar chocolate chip cookie recipes use 2-2½ cups flour",
                        sourceRecipes: ["Classic Chocolate Chip", "Best CC Cookies"]
                    )
                ],
                metadata: AugmentationMetadata(
                    localRecipesUsed: 2,
                    webRecipesUsed: 1,
                    totalInferences: 3,
                    averageConfidence: .high,
                    processingTime: 5.2
                )
            ),
            similarRecipes: [
                SimilarRecipeMatch(
                    recipe: Recipe(
                        title: "Classic Chocolate Chip Cookies",
                        sourceType: .manual,
                        instructions: [],
                        servings: "48 cookies"
                    ),
                    similarityScore: 0.87,
                    matchReasons: [.ingredientOverlap, .titleSimilarity]
                )
            ],
            webRecipes: [
                WebRecipeResult(
                    title: "Best Chocolate Chip Cookies",
                    sourceURL: "https://allrecipes.com/recipe/best-cc-cookies",
                    ingredients: [],
                    instructions: nil,
                    servings: "48 cookies",
                    similarityScore: 0.82
                )
            ]
        )
        .padding()
    }
}

#Preview("No Augmentation") {
    SimilarRecipesInfoView(
        augmentedRecipe: nil,
        similarRecipes: [],
        webRecipes: []
    )
    .padding()
}
