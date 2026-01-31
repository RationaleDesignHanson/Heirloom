import SwiftUI
import SwiftData

/// Sheet for publishing a recipe to public discovery
struct PublishRecipeSheet: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PublishRecipeViewModel

    init(recipe: Recipe) {
        self.recipe = recipe
        self._viewModel = State(initialValue: PublishRecipeViewModel(recipe: recipe))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
                    // Validation status
                    validationSection

                    if viewModel.canPublish {
                        // Preview what gets shared
                        previewSection

                        // Privacy note
                        privacyNote

                        // Publish button
                        publishButton
                    }
                }
                .padding(HeirloomSpacing.md)
            }
            .background(HeirloomColors.appBackground)
            .navigationTitle("Share Publicly")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Recipe Published!", isPresented: $viewModel.showPublishSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your recipe is now visible in the public discovery feed!")
            }
            .alert("Error", isPresented: $viewModel.showPublishError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.publishErrorMessage ?? "Failed to publish recipe. Please try again.")
            }
        }
    }

    // MARK: - Validation Section

    @ViewBuilder
    private var validationSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: viewModel.canPublish ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(viewModel.canPublish ? HeirloomColors.familyGreen : HeirloomColors.tomato)

                Text(viewModel.canPublish ? "Ready to Share" : "Can't Share Publicly")
                    .font(HeirloomFonts.title3Bold)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            if let reason = viewModel.blockedReason {
                Text(reason)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
                    .background(HeirloomColors.tomato.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Preview Section

    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("What Gets Shared")
                .font(HeirloomFonts.title3Bold)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                previewItem(icon: "text.quote", text: "Recipe title")
                previewItem(icon: "photo", text: "Photo")
                previewItem(icon: "list.bullet", text: "Ingredient list")
                previewItem(icon: "person.circle", text: "Your name")

                if recipe.servings != nil || recipe.prepTime != nil || recipe.cookTime != nil {
                    previewItem(icon: "info.circle", text: "Servings and time")
                }

                if let tags = recipe.tags, !tags.isEmpty {
                    previewItem(icon: "tag", text: "Tags")
                }
            }
            .padding()
            .background(HeirloomColors.cream)
            .cornerRadius(8)

            Text("Not Shared")
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                notSharedItem(icon: "lock.fill", text: "Step-by-step instructions")
                notSharedItem(icon: "note.text", text: "Personal notes")
                notSharedItem(icon: "clock.arrow.circlepath", text: "Cooking history")
            }
            .padding()
            .background(HeirloomColors.warmGray.opacity(0.1))
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private func previewItem(icon: String, text: String) -> some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(HeirloomColors.familyGreen)
                .frame(width: 20)

            Text(text)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)
        }
    }

    @ViewBuilder
    private func notSharedItem(icon: String, text: String) -> some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(HeirloomColors.secondaryText)
                .frame(width: 20)

            Text(text)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    // MARK: - Privacy Note

    @ViewBuilder
    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(HeirloomColors.familyBlue)

                Text("Privacy Notice")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Text("Your recipe will be visible to all Heirloom users in the discovery feed. You can unpublish it anytime from the recipe menu.")
                .font(HeirloomFonts.caption)
                .foregroundStyle(HeirloomColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(HeirloomColors.familyBlue.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Publish Button

    @ViewBuilder
    private var publishButton: some View {
        Button {
            Task {
                await viewModel.publishRecipe()
            }
        } label: {
            HStack(spacing: HeirloomSpacing.sm) {
                if viewModel.isPublishing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 18))

                    Text("Share Publicly")
                        .font(HeirloomFonts.bodyBold)
                }
            }
            .foregroundStyle(HeirloomColors.buttonTextLight)
            .frame(maxWidth: .infinity)
            .padding()
            .background(HeirloomColors.tomato)
            .cornerRadius(12)
        }
        .disabled(viewModel.isPublishing)
    }
}

// MARK: - View Model

@Observable
@MainActor
class PublishRecipeViewModel {
    let recipe: Recipe

    var canPublish: Bool
    var blockedReason: String?

    var isPublishing = false
    var showPublishSuccess = false
    var showPublishError = false
    var publishErrorMessage: String?

    private var publicRecipeService: PublicRecipeServiceProtocol {
        ServiceContainer.shared.resolve((any PublicRecipeServiceProtocol).self)
    }

    private var analytics: AnalyticsService {
        ServiceContainer.shared.resolve(AnalyticsService.self)
    }

    init(recipe: Recipe) {
        self.recipe = recipe

        // Validate publishing eligibility
        let validation = ServiceContainer.shared
            .resolve((any PublicRecipeServiceProtocol).self)
            .validatePublishing(recipe)

        self.canPublish = validation.canPublish
        self.blockedReason = validation.reason
    }

    func publishRecipe() async {
        guard canPublish else { return }
        guard !isPublishing else { return }

        isPublishing = true
        publishErrorMessage = nil

        do {
            let publicRecipeId = try await publicRecipeService.publishRecipe(recipe)

            // Update local recipe with public metadata
            recipe.isPublic = true
            recipe.publicRecipeId = publicRecipeId
            recipe.publicPublishedAt = Date()

            isPublishing = false
            showPublishSuccess = true

            Log.info("Recipe published successfully", category: .social, metadata: [
                "recipeId": recipe.id.uuidString,
                "publicRecipeId": publicRecipeId
            ])

            // Track analytics
            analytics.track(event: .recipePublished, properties: [
                "recipe_id": recipe.id.uuidString,
                "public_recipe_id": publicRecipeId,
                "source_type": recipe.sourceType?.rawValue ?? "unknown"
            ])

        } catch {
            isPublishing = false
            publishErrorMessage = error.localizedDescription
            showPublishError = true

            Log.error("Failed to publish recipe", category: .social, metadata: [
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
    recipe.cameraOriginConfidence = .definitelyCamera

    container.mainContext.insert(recipe)

    return PublishRecipeSheet(recipe: recipe)
        .modelContainer(container)
}
