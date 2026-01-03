//
//  MergedRecipePreview.swift
//  Heirloom
//
//  Created by Claude on 12/31/25.
//

import SwiftUI

/// Preview of the merged recipe before committing resolution
/// Shows exactly what the recipe will look like after merge
struct MergedRecipePreview: View {
    let recipe: Recipe
    let resolutions: [ConflictResolution]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var showingChangeSummary = false
    @State private var showSuccessAnimation = false
    @State private var animateEntrance = false

    var body: some View {
        NavigationView {
            ZStack {
                // Main content
                ScrollView {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
                        // Success header
                        successHeader
                            .opacity(animateEntrance ? 1 : 0)
                            .offset(y: animateEntrance ? 0 : -20)

                        // Recipe preview (simplified card view)
                        recipePreviewCard
                            .opacity(animateEntrance ? 1 : 0)
                            .offset(y: animateEntrance ? 0 : -20)

                        // What changed disclosure
                        changeSummaryDisclosure
                            .opacity(animateEntrance ? 1 : 0)
                            .offset(y: animateEntrance ? 0 : -20)

                        // Confidence check
                        confidenceCheck
                            .opacity(animateEntrance ? 1 : 0)
                            .offset(y: animateEntrance ? 0 : -20)

                        // Action buttons
                        actionButtons
                            .opacity(animateEntrance ? 1 : 0)
                            .offset(y: animateEntrance ? 0 : -20)
                    }
                    .padding(HeirloomSpacing.lg)
                }
                .background(HeirloomColors.cream)

                // Success animation overlay
                if showSuccessAnimation {
                    successAnimationOverlay
                }
            }
            .navigationTitle("Preview Merged Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    animateEntrance = true
                }
            }
        }
    }

    // MARK: - Success Header

    private var successHeader: some View {
        HStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(HeirloomColors.conflictSafe)

            VStack(alignment: .leading, spacing: 4) {
                Text("Conflicts Resolved")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("Review the merged recipe below")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.conflictSafe.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Recipe Preview Card

    private var recipePreviewCard: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            // Title
            Text(recipe.title)
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.primaryText)

            // Metadata
            HStack(spacing: HeirloomSpacing.lg) {
                if let servings = recipe.servings {
                    metadataItem(icon: "person.2", text: servings)
                }
                if let prepTime = recipe.prepTime {
                    metadataItem(icon: "clock", text: prepTime)
                }
                if let cookTime = recipe.cookTime {
                    metadataItem(icon: "flame", text: cookTime)
                }
            }

            if let notes = recipe.notes {
                Divider()
                Text(notes)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            // Ingredients
            if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                Divider()

                Text("Ingredients (\(ingredients.count))")
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)

                ForEach(ingredients.sorted(by: { $0.orderIndex < $1.orderIndex }).prefix(5)) { ingredient in
                    HStack(alignment: .top, spacing: HeirloomSpacing.xs) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(HeirloomColors.tomato)
                            .padding(.top, 6)

                        Text(ingredient.originalText)
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.primaryText)
                    }
                }

                if ingredients.count > 5 {
                    Text("+ \(ingredients.count - 5) more")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .padding(.leading, HeirloomSpacing.md)
                }
            }

            // Instructions
            if !recipe.instructions.isEmpty {
                Divider()

                Text("Instructions")
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)

                ForEach(Array(recipe.instructions.prefix(3).enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: HeirloomSpacing.md) {
                        Text("\(index + 1)")
                            .font(HeirloomFonts.caption1Bold)
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(HeirloomColors.tomato)
                            .cornerRadius(12)

                        Text(instruction)
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.primaryText)
                    }
                }

                if recipe.instructions.count > 3 {
                    Text("+ \(recipe.instructions.count - 3) more steps")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .padding(.leading, HeirloomSpacing.md)
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(.white)
        .cornerRadius(12)
        .shadow(color: HeirloomColors.cardShadow, radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private func metadataItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(HeirloomColors.secondaryText)
            Text(text)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    // MARK: - Change Summary

    private var changeSummaryDisclosure: some View {
        Button {
            showingChangeSummary.toggle()
        } label: {
            HStack {
                Image(systemName: "list.bullet.circle")
                    .foregroundStyle(HeirloomColors.conflictInfo)

                Text("What Changed?")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                Spacer()

                Image(systemName: showingChangeSummary ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
            .padding(HeirloomSpacing.md)
            .background(HeirloomColors.conflictCardBackground)
            .cornerRadius(8)
        }
        .sheet(isPresented: $showingChangeSummary) {
            changeSummarySheet
        }
    }

    private var changeSummarySheet: some View {
        NavigationView {
            List {
                Section("Your Choices") {
                    ForEach(Array(resolutions.enumerated()), id: \.offset) { index, resolution in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(resolution.fieldPath.capitalized)
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(HeirloomColors.primaryText)

                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(HeirloomColors.conflictSafe)

                                Text(resolutionDescription(resolution.choice))
                                    .font(HeirloomFonts.caption1)
                                    .foregroundStyle(HeirloomColors.secondaryText)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingChangeSummary = false
                    }
                }
            }
        }
    }

    // MARK: - Confidence Check

    private var confidenceCheck: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text("Looks Good?")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("This is how your recipe will look after merging. You can undo this for 30 seconds after saving.")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.conflictInfo.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: HeirloomSpacing.md) {
            // Save button
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showSuccessAnimation = true
                }

                // Delay actual save to show animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    onConfirm()
                }
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save Merged Recipe")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(HeirloomColors.conflictSafe)
                .foregroundStyle(.white)
                .font(HeirloomFonts.bodyBold)
                .cornerRadius(12)
            }

            // Cancel button
            Button {
                onCancel()
            } label: {
                Text("Go Back")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(HeirloomColors.warmGray.opacity(0.2))
                    .foregroundStyle(HeirloomColors.primaryText)
                    .font(HeirloomFonts.body)
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Success Animation

    private var successAnimationOverlay: some View {
        ZStack {
            // Blur background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: HeirloomSpacing.lg) {
                // Checkmark with scale animation
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(HeirloomColors.conflictSafe)
                    .scaleEffect(showSuccessAnimation ? 1.0 : 0.5)
                    .opacity(showSuccessAnimation ? 1 : 0)

                VStack(spacing: HeirloomSpacing.xs) {
                    Text("Recipe Merged!")
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("All conflicts resolved")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
                .opacity(showSuccessAnimation ? 1 : 0)
                .offset(y: showSuccessAnimation ? 0 : 20)
            }
            .padding(HeirloomSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white)
                    .shadow(color: HeirloomColors.cardShadow, radius: 20, x: 0, y: 10)
            )
            .scaleEffect(showSuccessAnimation ? 1.0 : 0.9)
        }
        .transition(.opacity)
    }

    // MARK: - Helpers

    private func resolutionDescription(_ choice: ConflictResolution.ResolutionChoice) -> String {
        switch choice {
        case .keepLocal:
            return "Kept your version"
        case .keepRemote:
            return "Kept other version"
        case .keepBoth:
            return "Kept both changes"
        case .custom:
            return "Used custom value"
        }
    }
}

// MARK: - Preview

#Preview {
    let recipe = Recipe(
        title: "Grandma's Lasagna",
        sourceType: .manual,
        instructions: [
            "Preheat oven to 375°F",
            "Brown the ground beef",
            "Layer ingredients in baking dish"
        ],
        servings: "8 servings",
        prepTime: "30 min",
        cookTime: "45 min"
    )

    let resolutions = [
        ConflictResolution(
            fieldPath: "servings",
            localOperationId: UUID(),
            remoteOperationId: UUID(),
            choice: .keepLocal
        ),
        ConflictResolution(
            fieldPath: "cookTime",
            localOperationId: UUID(),
            remoteOperationId: UUID(),
            choice: .keepRemote
        )
    ]

    return MergedRecipePreview(
        recipe: recipe,
        resolutions: resolutions,
        onConfirm: { print("Confirmed") },
        onCancel: { print("Cancelled") }
    )
}
