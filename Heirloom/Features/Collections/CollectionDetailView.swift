import SwiftUI
import SwiftData

/// Detail view showing recipes within a collection
struct CollectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let collection: RecipeCollection

    @Query private var allRecipes: [Recipe]

    init(collection: RecipeCollection) {
        self.collection = collection
        // Fetch all recipes (will filter in computed property)
        _allRecipes = Query(sort: \Recipe.title)
    }

    // Recipes in this collection
    var recipes: [Recipe] {
        allRecipes.filter { recipe in
            recipe.collections?.contains(where: { $0.id == collection.id }) ?? false
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
                // Collection header
                collectionHeader

                // Recipes grid
                if recipes.isEmpty {
                    emptyStateView
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: HeirloomSpacing.md),
                        GridItem(.flexible(), spacing: HeirloomSpacing.md)
                    ], spacing: HeirloomSpacing.md) {
                        ForEach(recipes, id: \.id) { recipe in
                            NavigationLink {
                                RecipeDetailView(recipe: recipe)
                            } label: {
                                RecipeGridCard(recipe: recipe)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, HeirloomSpacing.md)
                }
            }
            .padding(.vertical, HeirloomSpacing.lg)
        }
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Collection Header

    private var collectionHeader: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Image(systemName: collection.iconName)
                    .font(.largeTitle)
                    .foregroundStyle(collection.swiftUIColor)

                Spacer()

                if collection.isHeritageCollection {
                    Text("HERITAGE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(collection.swiftUIColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(collection.swiftUIColor.opacity(0.15))
                        .cornerRadius(6)
                }
            }

            if let description = collection.desc {
                Text(description)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            Text("\(recipes.count) recipe\(recipes.count == 1 ? "" : "s")")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding(.horizontal, HeirloomSpacing.md)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.charcoal.opacity(0.3))

            Text("No Recipes Yet")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("Recipes in this collection will appear here")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(HeirloomSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Recipe Grid Card

struct RecipeGridCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Image with blurhash placeholder
            ZStack {
                AsyncBlurhashImage(
                    recipe: recipe,
                    variant: .card,
                    contentMode: .fill
                )

                // Fallback icon if no image
                if recipe.imageFileName == nil {
                    Image(systemName: recipe.isHeritageRecipe ? "scroll.fill" : "fork.knife")
                        .font(.largeTitle)
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.2))
                }
            }
            .frame(height: 120)
            .background(recipe.isHeritageRecipe ? Color(hex: "#F0EDE6") : Color(hex: "#F8F8F8"))
            .cornerRadius(HeirloomSpacing.cardCornerRadius)
            .clipped()

            // Recipe title
            Text(recipe.title)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Heritage badge or metadata
            if recipe.isHeritageRecipe {
                HStack(spacing: 4) {
                    Image(systemName: "laurel.trailing")
                        .font(.system(size: 10))
                    Text("Heritage")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))
            } else if let servings = recipe.servings {
                Text(servings)
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
    }
}

#Preview {
    @Previewable @State var collection = RecipeCollection(
        name: "Presidential Pantry",
        description: "Recipes from First Families",
        iconName: "building.columns.fill",
        color: "#8B0000",
        isSystemCollection: true,
        heritageCollectionId: "presidential-pantry"
    )

    NavigationStack {
        CollectionDetailView(collection: collection)
            .modelContainer(for: [Recipe.self, RecipeCollection.self])
    }
}
