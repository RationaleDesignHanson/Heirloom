import SwiftUI
import SwiftData

/// Confirmation sheet for unpublishing a recipe from public discovery
struct UnpublishConfirmationSheet: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss

    @State private var isUnpublishing = false
    @State private var showError = false
    @State private var errorMessage: String?

    private var publicRecipeService: PublicRecipeServiceProtocol {
        ServiceContainer.shared.resolve((any PublicRecipeServiceProtocol).self)
    }

    private var discoveryService: DiscoveryServiceProtocol {
        ServiceContainer.shared.resolve((any DiscoveryServiceProtocol).self)
    }

    private var analytics: AnalyticsService {
        ServiceContainer.shared.resolve(AnalyticsService.self)
    }

    var body: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            // Warning icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.tomato)

            // Title
            Text("Unpublish Recipe?")
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.primaryText)

            // Message
            VStack(spacing: HeirloomSpacing.sm) {
                Text("This will remove \"\(recipe.title)\" from the public discovery feed.")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .multilineTextAlignment(.center)

                Text("Current stats: \(recipe.publicViewCount) views, \(recipe.publicSaveCount) saves")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, HeirloomSpacing.md)

            // What happens
            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                Text("What happens:")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                bulletPoint("Recipe removed from discovery")
                bulletPoint("Your local copy stays safe")
                bulletPoint("You can re-publish anytime")
                bulletPoint("Stats will reset if re-published")
            }
            .padding()
            .background(HeirloomColors.warmGray.opacity(0.1))
            .cornerRadius(8)

            // Buttons
            VStack(spacing: HeirloomSpacing.sm) {
                // Unpublish button
                Button(role: .destructive) {
                    Task {
                        await unpublish()
                    }
                } label: {
                    HStack {
                        if isUnpublishing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Text("Unpublish")
                                .font(HeirloomFonts.bodyBold)
                        }
                    }
                    .foregroundStyle(HeirloomColors.buttonTextLight)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(HeirloomColors.tomato)
                    .cornerRadius(12)
                }
                .disabled(isUnpublishing)

                // Cancel button
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(HeirloomColors.warmGray.opacity(0.2))
                        .cornerRadius(12)
                }
                .disabled(isUnpublishing)
            }
        }
        .padding(HeirloomSpacing.lg)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text(errorMessage ?? "Failed to unpublish recipe. Please try again.")
        }
    }

    @ViewBuilder
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.xs) {
            Text("•")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(text)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)
        }
    }

    private func unpublish() async {
        guard !isUnpublishing else { return }

        isUnpublishing = true
        errorMessage = nil

        do {
            try await publicRecipeService.unpublishRecipe(recipe)

            // Update local recipe
            recipe.isPublic = false
            recipe.publicRecipeId = nil

            Log.info("Recipe unpublished successfully", category: .social, metadata: [
                "recipeId": recipe.id.uuidString
            ])

            // Clear discovery cache to remove from all tabs
            discoveryService.clearCache()

            // Track analytics
            analytics.track(event: .recipeEdited, properties: [
                "recipe_id": recipe.id.uuidString,
                "view_count": recipe.publicViewCount,
                "save_count": recipe.publicSaveCount
            ])

            // Dismiss on success
            dismiss()

        } catch {
            isUnpublishing = false
            errorMessage = error.localizedDescription
            showError = true

            Log.error("Failed to unpublish recipe", category: .social, metadata: [
                "recipeId": recipe.id.uuidString,
                "error": error.localizedDescription
            ])
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Recipe.self, configurations: config)

    let recipe = Recipe(
        title: "Grandma's Apple Pie",
        sourceType: .scan,
        instructions: [],
        servings: "8",
        prepTime: "30",
        cookTime: "45"
    )
    recipe.isPublic = true
    recipe.publicRecipeId = "test-public-id"
    recipe.publicViewCount = 42
    recipe.publicSaveCount = 7

    container.mainContext.insert(recipe)

    return UnpublishConfirmationSheet(recipe: recipe)
        .modelContainer(container)
}
