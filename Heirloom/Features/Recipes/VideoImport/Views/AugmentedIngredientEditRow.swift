//
//  AugmentedIngredientEditRow.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/9/26.
//
//  Enhanced ingredient edit row with AI inference indicators and reasoning

import SwiftUI

struct AugmentedIngredientEditRow: View {
    let ingredient: ExtractedIngredient
    let augmentation: AugmentedIngredient?

    @Binding var quantity: String
    @Binding var unit: String
    @Binding var name: String

    @State private var showReasoning: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Main ingredient row
            HStack(spacing: 12) {
                // Quantity
                HStack(spacing: HeirloomSpacing.xs) {
                    TextField("Qty", text: $quantity)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .keyboardType(.decimalPad)

                    if let augmentation = augmentation, augmentation.inferredQuantity != nil {
                        confidenceDot(for: augmentation.inferredConfidence)
                    }
                }

                // Unit
                TextField("Unit", text: $unit)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)

                // Ingredient name
                TextField("Ingredient", text: $name)
                    .textFieldStyle(.roundedBorder)

                // Reasoning button (if augmented)
                if augmentation != nil {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showReasoning.toggle()
                        }
                    } label: {
                        Image(systemName: showReasoning ? "info.circle.fill" : "info.circle")
                            .font(HeirloomFonts.title2)
                            .foregroundStyle(.blue)
                    }
                }
            }

            // Augmentation info badge (if inferred quantity exists)
            if let augmentation = augmentation {
                if augmentation.inferredQuantity != nil {
                    inferredBadge(for: augmentation)

                    // Additional low confidence warning
                    if augmentation.inferredConfidence == .low || augmentation.inferredConfidence == .unknown {
                        lowConfidenceWarning(for: augmentation)
                    }
                } else {
                    // Show badge even when no quantity inferred (AI tried but couldn't infer)
                    noInferenceBadge(for: augmentation)
                }
            }

            // Expanded reasoning section
            if showReasoning, let augmentation = augmentation {
                reasoningSection(augmentation: augmentation)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func inferredBadge(for augmentation: AugmentedIngredient) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(HeirloomFonts.caption2)

            Text("AI-inferred from \(augmentation.sourceRecipes.count) similar recipe\(augmentation.sourceRecipes.count == 1 ? "" : "s")")
                .font(HeirloomFonts.caption2)

            confidenceDot(for: augmentation.inferredConfidence)

            Text(augmentation.inferredConfidence.shortDisplayText)
                .font(HeirloomFonts.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(inferenceBackgroundColor(for: augmentation.inferredConfidence))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func lowConfidenceWarning(for augmentation: AugmentedIngredient) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(HeirloomFonts.caption2)
                .foregroundStyle(.orange)

            Text("Low confidence - verify quantity")
                .font(HeirloomFonts.caption2)
                .foregroundStyle(.secondary)

            confidenceDot(for: augmentation.inferredConfidence)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func noInferenceBadge(for augmentation: AugmentedIngredient) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "questionmark.circle")
                .font(HeirloomFonts.caption2)
                .foregroundStyle(.gray)

            Text("Could not infer quantity - see reasoning")
                .font(HeirloomFonts.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func reasoningSection(augmentation: AugmentedIngredient) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Reasoning text
            Text("AI Reasoning:")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(augmentation.reasoning)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Source recipes
            if !augmentation.sourceRecipes.isEmpty {
                Divider()
                    .padding(.vertical, 4)

                Text("Supporting Recipes:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(augmentation.sourceRecipes, id: \.self) { recipeTitle in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(.green)

                        Text(recipeTitle)
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Confidence explanation
            Divider()
                .padding(.vertical, 4)

            confidenceExplanation(for: augmentation.inferredConfidence)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func confidenceExplanation(for confidence: InferenceConfidence) -> some View {
        HStack(spacing: HeirloomSpacing.sm) {
            confidenceDot(for: confidence)

            VStack(alignment: .leading, spacing: 2) {
                Text("Confidence: \(confidence.displayText)")
                    .font(.caption.weight(.semibold))

                Text(confidenceDescription(for: confidence))
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func confidenceDot(for confidence: InferenceConfidence) -> some View {
        Circle()
            .fill(confidenceColor(for: confidence))
            .frame(width: 8, height: 8)
    }

    // MARK: - Helpers

    private func confidenceColor(for confidence: InferenceConfidence) -> Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .yellow
        case .unknown: return .gray
        }
    }

    private func inferenceBackgroundColor(for confidence: InferenceConfidence) -> Color {
        switch confidence {
        case .high: return .green.opacity(0.1)
        case .medium: return .orange.opacity(0.1)
        case .low: return .yellow.opacity(0.1)
        case .unknown: return .gray.opacity(0.1)
        }
    }

    private func confidenceDescription(for confidence: InferenceConfidence) -> String {
        switch confidence {
        case .high:
            return "3+ similar recipes agree on this quantity (±20% variance)"
        case .medium:
            return "2 similar recipes agree, or strong contextual inference"
        case .low:
            return "Only 1 similar recipe, or high variance (>30%)"
        case .unknown:
            return "No similar recipes or conflicting data"
        }
    }
}

// MARK: - Preview

#Preview("With High Confidence Inference") {
    @Previewable @State var quantity = "2¼"
    @Previewable @State var unit = "cups"
    @Previewable @State var name = "all-purpose flour"

    ScrollView {
        AugmentedIngredientEditRow(
            ingredient: ExtractedIngredient(
                originalText: "some flour",
                item: "flour",
                quantity: nil,
                unit: nil,
                preparation: nil,
                confidence: .unknown
            ),
            augmentation: AugmentedIngredient(
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
                reasoning: "Three similar chocolate chip cookie recipes consistently use 2-2½ cups of all-purpose flour for approximately 48 cookies. The median value is 2¼ cups, which accounts for serving size and typical flour-to-sugar ratios in this recipe category.",
                sourceRecipes: [
                    "Classic Chocolate Chip Cookies",
                    "Best Chocolate Chip Cookies",
                    "Grandma's Chocolate Chip Cookies"
                ]
            ),
            quantity: $quantity,
            unit: $unit,
            name: $name
        )
        .padding()
    }
}

#Preview("With Medium Confidence") {
    @Previewable @State var quantity = "2"
    @Previewable @State var unit = "cups"
    @Previewable @State var name = "chocolate chips"

    AugmentedIngredientEditRow(
        ingredient: ExtractedIngredient(
            originalText: "chocolate chips",
            item: "chocolate chips",
            quantity: nil,
            unit: nil,
            preparation: nil,
            confidence: .unknown
        ),
        augmentation: AugmentedIngredient(
            originalIngredient: ExtractedIngredient(
                originalText: "chocolate chips",
                item: "chocolate chips",
                quantity: nil,
                unit: nil,
                preparation: nil,
                confidence: .unknown
            ),
            inferredQuantity: "2",
            inferredUnit: "cups",
            inferredConfidence: .medium,
            reasoning: "Two similar recipes use 1½-2 cups chocolate chips. Used higher end based on recipe context.",
            sourceRecipes: [
                "Classic Chocolate Chip Cookies",
                "Best Chocolate Chip Cookies"
            ]
        ),
        quantity: $quantity,
        unit: $unit,
        name: $name
    )
    .padding()
}

#Preview("Without Augmentation") {
    @Previewable @State var quantity = "2"
    @Previewable @State var unit = "cups"
    @Previewable @State var name = "sugar"

    AugmentedIngredientEditRow(
        ingredient: ExtractedIngredient(
            originalText: "2 cups sugar",
            item: "sugar",
            quantity: "2",
            unit: "cups",
            preparation: nil,
            confidence: .explicit
        ),
        augmentation: nil,
        quantity: $quantity,
        unit: $unit,
        name: $name
    )
    .padding()
}
