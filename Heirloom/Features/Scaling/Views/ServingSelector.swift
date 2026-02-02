//
//  ServingSelector.swift
//  Heirloom
//
//  Created for Smallify feature
//

import SwiftUI

// MARK: - Serving Selector

/// Interactive serving selector for recipes
/// - Scalable recipes: Shows stepper to adjust servings
/// - Locked recipes: Shows lock icon with explanation
struct ServingSelector: View {
    let recipe: Recipe
    @Binding var targetServings: Int
    @State private var showExplanation = false

    var body: some View {
        if recipe.isScalingAllowed {
            // Check if servings are unparseable
            let hasServingsIssue = recipe.scalingValidation.issues.contains { issue in
                if case .servingsUnparseable = issue { return true }
                return false
            }

            if hasServingsIssue {
                multiplierView
            } else {
                scalableView
            }
        } else {
            lockedView
        }
    }

    // MARK: - Multiplier View (for unparseable servings)

    private var multiplierView: some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Label
            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                Text("Scale")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)

                Text(multiplierText)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.charcoal)
            }

            Spacer()

            // Multiplier buttons
            HStack(spacing: 8) {
                ForEach([0.25, 0.5, 1.0, 2.0, 4.0], id: \.self) { multiplier in
                    Button {
                        setMultiplier(multiplier)
                    } label: {
                        Text(formatMultiplier(multiplier))
                            .font(.caption)
                            .fontWeight(currentMultiplier == multiplier ? .bold : .regular)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                currentMultiplier == multiplier
                                    ? HeirloomColors.tomato
                                    : Color.clear
                            )
                            .foregroundStyle(
                                currentMultiplier == multiplier
                                    ? .white
                                    : HeirloomColors.charcoal
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(
                                        currentMultiplier == multiplier
                                            ? Color.clear
                                            : HeirloomColors.warmGray.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .fill(.white)
                .heirloomShadow(HeirloomShadows.subtle)
        )
    }

    // MARK: - Scalable Recipe View

    private var scalableView: some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Label
            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                Text("Servings")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)

                Text("\(targetServings)")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.charcoal)
            }

            Spacer()

            // Stepper
            HStack(spacing: HeirloomSpacing.sm) {
                Button {
                    decrementServings()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(canDecrement ? HeirloomColors.tomato : HeirloomColors.warmGray.opacity(0.3))
                }
                .disabled(!canDecrement)

                Button {
                    incrementServings()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(canIncrement ? HeirloomColors.tomato : HeirloomColors.warmGray.opacity(0.3))
                }
                .disabled(!canIncrement)
            }
        }
        .padding(HeirloomSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .fill(.white)
                .heirloomShadow(HeirloomShadows.subtle)
        )
    }

    // MARK: - Locked Recipe View

    private var lockedView: some View {
        Button {
            showExplanation = true
        } label: {
            HStack(spacing: HeirloomSpacing.md) {
                // Lock Icon
                Image(systemName: "lock.fill")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.warmGray)

                // Label
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    Text("Servings")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)

                    Text("\(recipe.parsedServingCount) (fixed)")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.charcoal)
                }

                Spacer()

                // Info Icon
                Image(systemName: "info.circle")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.warmGray.opacity(0.5))
            }
            .padding(HeirloomSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                    .fill(HeirloomColors.warmGray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                            .strokeBorder(HeirloomColors.warmGray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showExplanation) {
            ScalingExplanationSheet(recipe: recipe)
        }
    }

    // MARK: - Stepper Logic

    private var canDecrement: Bool {
        guard let range = recipe.allowedServingRange else { return false }
        return targetServings > range.lowerBound
    }

    private var canIncrement: Bool {
        guard let range = recipe.allowedServingRange else { return false }
        return targetServings < range.upperBound
    }

    private func decrementServings() {
        guard canDecrement else { return }
        targetServings -= 1
    }

    private func incrementServings() {
        guard canIncrement else { return }
        targetServings += 1
    }

    // MARK: - Multiplier Logic

    private var currentMultiplier: Double {
        let base = Double(recipe.parsedServingCount)
        return Double(targetServings) / base
    }

    private var multiplierText: String {
        let mult = currentMultiplier
        if mult == 1.0 {
            return "1x"
        } else if mult < 1.0 {
            return String(format: "%.2gx", mult)
        } else {
            return String(format: "%.0fx", mult)
        }
    }

    private func formatMultiplier(_ multiplier: Double) -> String {
        if multiplier == 1.0 {
            return "1x"
        } else if multiplier < 1.0 {
            return String(format: "%.2gx", multiplier)
        } else {
            return String(format: "%.0fx", multiplier)
        }
    }

    private func setMultiplier(_ multiplier: Double) {
        let base = recipe.parsedServingCount
        let newServings = Int(Double(base) * multiplier)
        targetServings = max(1, newServings) // Ensure at least 1 serving
    }
}

// MARK: - Scaling Explanation Sheet

/// Sheet that explains why a recipe can't be scaled
struct ScalingExplanationSheet: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HeirloomSpacing.xl) {
                    // Header
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        Image(systemName: recipe.scalability.iconName)
                            .font(.system(size: 48))
                            .foregroundStyle(HeirloomColors.tomato)

                        Text("This Recipe Can't Be Scaled")
                            .font(HeirloomFonts.title2)
                            .foregroundStyle(HeirloomColors.charcoal)

                        if let category = recipe.category {
                            Text(category.rawValue)
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                                .padding(.horizontal, HeirloomSpacing.sm)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(HeirloomColors.warmGray.opacity(0.1))
                                )
                        }
                    }

                    // Explanation
                    if let warning = recipe.category?.minimumWarning {
                        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                            Text("Why?")
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(HeirloomColors.charcoal)

                            Text(warning)
                                .font(HeirloomFonts.body)
                                .foregroundStyle(HeirloomColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(HeirloomSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                                .fill(HeirloomColors.warning.opacity(0.1))
                        )
                    }

                    // Recommendation
                    VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                        Text("Recommendation")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.charcoal)

                        Text("For best results, make this recipe as written. If you need a different quantity, look for recipes specifically designed for that serving size.")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(HeirloomSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                            .fill(HeirloomColors.success.opacity(0.1))
                    )

                    // Examples of fixed recipes
                    if let category = recipe.category {
                        examplesSection(for: category)
                    }

                    Spacer()
                }
                .padding(HeirloomSpacing.lg)
            }
            .background(HeirloomColors.cream)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.tomato)
                }
            }
        }
    }

    // MARK: - Examples Section

    @ViewBuilder
    private func examplesSection(for category: RecipeCategory) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("Examples")
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.charcoal)

            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                switch category {
                case .laminated:
                    exampleItem(title: "Croissants", reason: "Butter layers require precise ratios")
                    exampleItem(title: "Puff Pastry", reason: "Folding technique is size-dependent")
                    exampleItem(title: "Danish Pastries", reason: "Lamination breaks down at different sizes")

                case .emulsion:
                    exampleItem(title: "Mayonnaise", reason: "Minimum 1 egg yolk needed for emulsification")
                    exampleItem(title: "Hollandaise", reason: "Temperature and ratio are critical")
                    exampleItem(title: "Aioli", reason: "Emulsion chemistry requires minimum volume")

                case .sourdough:
                    exampleItem(title: "Sourdough Bread", reason: "Starter ratios are specific to size")
                    exampleItem(title: "Sourdough Pancakes", reason: "Fermentation time varies with volume")

                case .candy:
                    exampleItem(title: "Caramels", reason: "Temperature control is batch-size dependent")
                    exampleItem(title: "Fudge", reason: "Crystallization requires specific volumes")
                    exampleItem(title: "Toffee", reason: "Sugar chemistry doesn't scale linearly")

                default:
                    EmptyView()
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .fill(.white)
                .heirloomShadow(HeirloomShadows.subtle)
        )
    }

    private func exampleItem(title: String, reason: String) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(HeirloomColors.tomato)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.charcoal)

                Text(reason)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
    }
}

// MARK: - Preview

#Preview("Scalable Recipe") {
    @Previewable @State var recipe: Recipe = {
        let recipe = Recipe.example
        recipe.category = .cookies
        recipe.scalability = .easy
        recipe.minimumServings = 4
        recipe.maximumServings = 96
        return recipe
    }()

    VStack {
        ServingSelector(
            recipe: recipe,
            targetServings: .constant(48)
        )
        .padding()
    }
    .background(HeirloomColors.cream)
}

#Preview("Locked Recipe") {
    @Previewable @State var recipe: Recipe = {
        let recipe = Recipe.example
        recipe.category = .laminated
        recipe.scalability = .locked
        return recipe
    }()

    VStack {
        ServingSelector(
            recipe: recipe,
            targetServings: .constant(12)
        )
        .padding()
    }
    .background(HeirloomColors.cream)
}
