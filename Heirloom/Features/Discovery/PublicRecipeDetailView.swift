import SwiftUI
import SwiftData

/// Detail view for a public recipe with save functionality
struct PublicRecipeDetailView: View {
    let publicRecipeId: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PublicRecipeDetailViewModel

    init(publicRecipeId: String) {
        self.publicRecipeId = publicRecipeId
        self._viewModel = State(initialValue: PublicRecipeDetailViewModel(publicRecipeId: publicRecipeId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else if let recipe = viewModel.recipe {
                recipeContent(recipe)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadRecipe()
        }
        .alert("Recipe Saved!", isPresented: $viewModel.showSaveSuccess) {
            Button("View Recipe") {
                // TODO: Navigate to saved recipe
                dismiss()
            }
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("This recipe has been added to your collection.")
        }
        .alert("Error", isPresented: $viewModel.showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.saveErrorMessage ?? "Failed to save recipe. Please try again.")
        }
    }

    // MARK: - Recipe Content

    @ViewBuilder
    private func recipeContent(_ recipe: PublicRecipe) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero image
                heroImage(recipe)

                VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
                    // Title and creator
                    titleSection(recipe)

                    // Engagement stats
                    engagementStats(recipe)

                    Divider()

                    // Description
                    if let description = recipe.description, !description.isEmpty {
                        descriptionSection(description)
                        Divider()
                    }

                    // Metadata row (servings, times)
                    metadataRow(recipe)

                    Divider()

                    // Ingredients
                    ingredientsSection(recipe)

                    // Tags
                    if !recipe.tags.isEmpty {
                        Divider()
                        tagsSection(recipe)
                    }

                    // Save button
                    saveButton()
                }
                .padding(HeirloomSpacing.md)
            }
        }
        .background(HeirloomColors.appBackground)
    }

    // MARK: - Hero Image

    @ViewBuilder
    private func heroImage(_ recipe: PublicRecipe) -> some View {
        if let imageURL = recipe.imageURL {
            AsyncImage(url: URL(string: imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .clipped()
                case .failure:
                    placeholderImage
                case .empty:
                    ZStack {
                        Color.gray.opacity(0.1)
                            .frame(height: 300)
                        ProgressView()
                    }
                @unknown default:
                    placeholderImage
                }
            }
        } else {
            placeholderImage
        }
    }

    private var placeholderImage: some View {
        ZStack {
            HeirloomColors.cream
                .frame(height: 300)

            Image(systemName: "fork.knife")
                .font(.system(size: 64))
                .foregroundStyle(HeirloomColors.warmGray)
        }
    }

    // MARK: - Title Section

    @ViewBuilder
    private func titleSection(_ recipe: PublicRecipe) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text(recipe.title)
                .font(HeirloomFonts.largeTitle)
                .foregroundStyle(HeirloomColors.primaryText)

            // Creator info
            HStack(spacing: HeirloomSpacing.sm) {
                if let photoURL = recipe.creatorPhotoURL {
                    AsyncImage(url: URL(string: photoURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        default:
                            Circle()
                                .fill(HeirloomColors.warmGray.opacity(0.3))
                                .frame(width: 32, height: 32)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("by \(recipe.creatorName)")
                        .font(HeirloomFonts.subheadline)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Published \(recipe.publishedAt.formatted(.relative(presentation: .named)))")
                        .font(HeirloomFonts.caption)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Spacer()

                // TODO: Add creator profile navigation
            }
        }
    }

    // MARK: - Engagement Stats

    @ViewBuilder
    private func engagementStats(_ recipe: PublicRecipe) -> some View {
        HStack(spacing: HeirloomSpacing.lg) {
            statItem(icon: "eye.fill", value: recipe.viewCount, label: "Views")
            statItem(icon: "heart.fill", value: recipe.saveCount, label: "Saves")

            Spacer()
        }
    }

    @ViewBuilder
    private func statItem(icon: String, value: Int, label: String) -> some View {
        HStack(spacing: HeirloomSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(HeirloomColors.tomato)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(HeirloomFonts.headlineBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text(label)
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
    }

    // MARK: - Description

    @ViewBuilder
    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text("About")
                .font(HeirloomFonts.title3Bold)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(description)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Metadata Row

    @ViewBuilder
    private func metadataRow(_ recipe: PublicRecipe) -> some View {
        HStack(spacing: HeirloomSpacing.lg) {
            if let servings = recipe.servings {
                metadataItem(icon: "person.2.fill", label: "Servings", value: servings)
            }

            if let prepTime = recipe.prepTime {
                metadataItem(icon: "clock.fill", label: "Prep", value: "\(prepTime)m")
            }

            if let cookTime = recipe.cookTime {
                metadataItem(icon: "flame.fill", label: "Cook", value: "\(cookTime)m")
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func metadataItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: HeirloomSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(HeirloomColors.familyGreen)

            Text(value)
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(label)
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .frame(minWidth: 60)
    }

    // MARK: - Ingredients

    @ViewBuilder
    private func ingredientsSection(_ recipe: PublicRecipe) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("Ingredients")
                .font(HeirloomFonts.title3Bold)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
                        Text("•")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.tomato)

                        Text(ingredient)
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                    }
                }
            }
            .padding(.vertical, HeirloomSpacing.xs)
        }
    }

    // MARK: - Tags

    @ViewBuilder
    private func tagsSection(_ recipe: PublicRecipe) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text("Tags")
                .font(HeirloomFonts.title3Bold)
                .foregroundStyle(HeirloomColors.primaryText)

            FlowLayout(spacing: HeirloomSpacing.sm) {
                ForEach(recipe.tags, id: \.self) { tag in
                    Text(tag)
                        .font(HeirloomFonts.caption)
                        .foregroundStyle(HeirloomColors.primaryText)
                        .padding(.horizontal, HeirloomSpacing.sm)
                        .padding(.vertical, HeirloomSpacing.xs)
                        .background(HeirloomColors.cream)
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Save Button

    @ViewBuilder
    private func saveButton() -> some View {
        Button {
            Task {
                await viewModel.saveToMyRecipes(context: modelContext)
            }
        } label: {
            HStack(spacing: HeirloomSpacing.sm) {
                if viewModel.isSaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18))

                    Text("Save to My Recipes")
                        .font(HeirloomFonts.bodyBold)
                }
            }
            .foregroundStyle(HeirloomColors.buttonTextLight)
            .frame(maxWidth: .infinity)
            .padding()
            .background(HeirloomColors.tomato)
            .cornerRadius(12)
        }
        .disabled(viewModel.isSaving)
        .padding(.top, HeirloomSpacing.md)
    }

    // MARK: - Loading State

    private var loadingView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading recipe...")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error State

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.tomato)

            Text("Failed to Load Recipe")
                .font(HeirloomFonts.headline)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(message)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HeirloomSpacing.xl)

            Button {
                dismiss()
            } label: {
                Text("Go Back")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.buttonTextLight)
                    .padding(.horizontal, HeirloomSpacing.lg)
                    .padding(.vertical, HeirloomSpacing.sm)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - View Model

@Observable
@MainActor
class PublicRecipeDetailViewModel {
    let publicRecipeId: String

    var recipe: PublicRecipe?
    var isLoading = false
    var errorMessage: String?

    var isSaving = false
    var showSaveSuccess = false
    var showSaveError = false
    var saveErrorMessage: String?

    private var discoveryService: DiscoveryServiceProtocol {
        ServiceContainer.shared.resolve((any DiscoveryServiceProtocol).self)
    }

    private var analytics: AnalyticsService {
        ServiceContainer.shared.resolve(AnalyticsService.self)
    }

    init(publicRecipeId: String) {
        self.publicRecipeId = publicRecipeId
    }

    func loadRecipe() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let fetchedRecipe = try await discoveryService.fetchPublicRecipe(id: publicRecipeId)

            recipe = fetchedRecipe
            isLoading = false

            // Track view (non-critical)
            if fetchedRecipe != nil {
                try? await discoveryService.trackView(publicRecipeId: publicRecipeId)

                // Track analytics
                analytics.track(event: .publicRecipeViewed, properties: [
                    "recipe_id": publicRecipeId,
                    "recipe_title": fetchedRecipe?.title ?? ""
                ])
            }

        } catch {
            errorMessage = error.localizedDescription
            isLoading = false

            Log.error("Failed to load public recipe", category: .social, metadata: [
                "recipeId": publicRecipeId,
                "error": error.localizedDescription
            ])
        }
    }

    func saveToMyRecipes(context: ModelContext) async {
        guard let recipe = recipe else { return }
        guard !isSaving else { return }

        isSaving = true
        saveErrorMessage = nil

        do {
            let savedRecipe = try await discoveryService.saveToMyRecipes(
                publicRecipe: recipe,
                context: context
            )

            isSaving = false
            showSaveSuccess = true

            Log.info("Saved public recipe to collection", category: .social, metadata: [
                "publicRecipeId": recipe.id,
                "recipeId": savedRecipe.id.uuidString
            ])

        } catch {
            isSaving = false
            saveErrorMessage = error.localizedDescription
            showSaveError = true

            Log.error("Failed to save public recipe", category: .social, metadata: [
                "publicRecipeId": recipe.id,
                "error": error.localizedDescription
            ])
        }
    }
}

// MARK: - FlowLayout (Tags)

/// Simple flow layout for wrapping tags
private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
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
