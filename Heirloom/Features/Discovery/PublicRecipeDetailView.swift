import SwiftUI
import SwiftData

/// Detail view for a public recipe (Phase 6 placeholder)
/// TODO: Fully implement in Phase 6 with save, track view, etc.
struct PublicRecipeDetailView: View {
    let publicRecipeId: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var recipe: PublicRecipe?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var discoveryService: DiscoveryServiceProtocol {
        ServiceContainer.shared.resolve((any DiscoveryServiceProtocol).self)
    }

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: HeirloomSpacing.md) {
                    ProgressView()
                        .scaleEffect(1.5)

                    Text("Loading recipe...")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let error = errorMessage {
                VStack(spacing: HeirloomSpacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(HeirloomColors.tomato)

                    Text("Failed to Load Recipe")
                        .font(HeirloomFonts.headline)

                    Text(error)
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, HeirloomSpacing.xl)

                    Button("Go Back") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let recipe = recipe {
                ScrollView {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
                        // Recipe image
                        if let imageURL = recipe.imageURL {
                            AsyncImage(url: URL(string: imageURL)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxHeight: 300)
                                        .clipped()
                                case .failure:
                                    Color.gray
                                        .frame(maxHeight: 300)
                                default:
                                    ProgressView()
                                        .frame(maxHeight: 300)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                            // Title
                            Text(recipe.title)
                                .font(HeirloomFonts.title)
                                .foregroundStyle(HeirloomColors.primaryText)

                            // Creator
                            if let creatorName = recipe.creatorName {
                                Text("by \(creatorName)")
                                    .font(HeirloomFonts.subheadline)
                                    .foregroundStyle(HeirloomColors.secondaryText)
                            }

                            // Stats
                            HStack(spacing: HeirloomSpacing.md) {
                                Label("\(recipe.viewCount)", systemImage: "eye.fill")
                                Label("\(recipe.saveCount)", systemImage: "heart.fill")

                                if let servings = recipe.servings {
                                    Label("\(servings)", systemImage: "person.2.fill")
                                }
                            }
                            .font(HeirloomFonts.caption)
                            .foregroundStyle(HeirloomColors.secondaryText)

                            Divider()

                            // Description
                            if let description = recipe.description {
                                Text(description)
                                    .font(HeirloomFonts.body)
                                    .foregroundStyle(HeirloomColors.primaryText)

                                Divider()
                            }

                            // Ingredients
                            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                                Text("Ingredients")
                                    .font(HeirloomFonts.headlineBold)
                                    .foregroundStyle(HeirloomColors.primaryText)

                                ForEach(recipe.ingredients, id: \.self) { ingredient in
                                    HStack(alignment: .top) {
                                        Text("•")
                                        Text(ingredient)
                                    }
                                    .font(HeirloomFonts.body)
                                }
                            }

                            // Save button (placeholder)
                            Button {
                                // TODO: Implement save in Phase 6
                                Log.debug("Save to my recipes tapped", category: .social)
                            } label: {
                                HStack {
                                    Image(systemName: "heart.fill")
                                    Text("Save to My Recipes")
                                }
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(HeirloomColors.buttonTextLight)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(HeirloomColors.tomato)
                                .cornerRadius(12)
                            }
                            .padding(.top, HeirloomSpacing.md)
                        }
                        .padding(HeirloomSpacing.md)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadRecipe()
        }
    }

    private func loadRecipe() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedRecipe = try await discoveryService.fetchPublicRecipe(id: publicRecipeId)

            await MainActor.run {
                recipe = fetchedRecipe
                isLoading = false
            }

            // Track view (Phase 6 will implement fully)
            if fetchedRecipe != nil {
                try? await discoveryService.trackView(publicRecipeId: publicRecipeId)
            }

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }

            Log.error("Failed to load public recipe", category: .social, metadata: [
                "recipeId": publicRecipeId,
                "error": error.localizedDescription
            ])
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PublicRecipeDetailView(publicRecipeId: "test-recipe-id")
            .modelContainer(for: Recipe.self, inMemory: true)
    }
}
