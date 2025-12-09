import SwiftUI
import SwiftData

struct RecipeListView: View {
    @Query(sort: \Recipe.dateAdded, order: .reverse)
    private var recipes: [Recipe]

    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var showAddRecipe = false
    @State private var showImportRecipe = false
    @State private var showCookbookScanner = false
    @State private var showFilters = false
    @State private var filters = RecipeFilters()

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    emptyState
                } else if filteredRecipes.isEmpty {
                    noResultsState
                } else {
                    recipeGrid
                }
            }
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search recipes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showFilters = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: filters.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.title3)
                                .foregroundStyle(filters.isActive ? HeirloomColors.tomato : HeirloomColors.primaryText)

                            if filters.activeFilterCount > 0 {
                                Text("\(filters.activeFilterCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 16, height: 16)
                                    .background(HeirloomColors.tomato)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showAddRecipe = true
                        } label: {
                            Label("New Recipe", systemImage: "square.and.pencil")
                        }

                        Button {
                            showImportRecipe = true
                        } label: {
                            Label("Import from URL", systemImage: "link")
                        }

                        Button {
                            showCookbookScanner = true
                        } label: {
                            Label("Scan Cookbook", systemImage: "book.pages")
                        }

                        Divider()

                        Button {
                            addSampleRecipe()
                        } label: {
                            Label("Add Sample Recipe", systemImage: "sparkles")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .sheet(isPresented: $showAddRecipe) {
                RecipeEditorView()
            }
            .sheet(isPresented: $showImportRecipe) {
                RecipeImportView()
            }
            .sheet(isPresented: $showCookbookScanner) {
                CookbookScannerView()
            }
            .sheet(isPresented: $showFilters) {
                RecipeFiltersView(filters: $filters)
            }
        }
    }

    // MARK: - Recipe Grid
    private var recipeGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: HeirloomSpacing.gridSpacing),
                    GridItem(.flexible(), spacing: HeirloomSpacing.gridSpacing)
                ],
                spacing: HeirloomSpacing.gridSpacing
            ) {
                ForEach(filteredRecipes, id: \.id) { recipe in
                    NavigationLink(value: recipe) {
                        RecipeCardView(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                    .id(recipe.id)
                    .contextMenu {
                        Button {
                            recipe.isFavorite.toggle()
                        } label: {
                            Label(
                                recipe.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                systemImage: recipe.isFavorite ? "heart.slash" : "heart.fill"
                            )
                        }

                        Button {
                            recipe.isInShoppingList.toggle()
                        } label: {
                            Label(
                                recipe.isInShoppingList ? "Remove from Shopping List" : "Add to Shopping List",
                                systemImage: recipe.isInShoppingList ? "cart.badge.minus" : "cart.badge.plus"
                            )
                        }

                        Divider()

                        Button(role: .destructive) {
                            deleteRecipe(recipe)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, HeirloomSpacing.md)
            .padding(.vertical, HeirloomSpacing.sm)
        }
        .refreshable {
            await refreshRecipes()
        }
        .background(HeirloomColors.appBackground)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        EmptyStateView.noRecipes {
            showAddRecipe = true
        }
    }

    // MARK: - No Results State
    private var noResultsState: some View {
        Group {
            if !searchText.isEmpty {
                EmptyStateView.noSearchResults(query: searchText) {
                    searchText = ""
                }
            } else if filters.isActive {
                EmptyStateView.noFilterResults {
                    filters = RecipeFilters()
                }
            }
        }
    }

    // MARK: - Computed Properties
    private var filteredRecipes: [Recipe] {
        var result = recipes

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply source type filter
        if !filters.sourceTypes.isEmpty {
            result = result.filter { recipe in
                guard let sourceType = recipe.sourceType else { return false }
                return filters.sourceTypes.contains(sourceType)
            }
        }

        // Apply favorites filter
        if filters.favoritesOnly {
            result = result.filter { $0.isFavorite }
        }

        // Apply shopping list filter
        if filters.inShoppingListOnly {
            result = result.filter { $0.isInShoppingList }
        }

        // Apply cooked filter
        if filters.cookedOnly {
            result = result.filter { $0.timesCooked > 0 }
        } else if filters.notCookedOnly {
            result = result.filter { $0.timesCooked == 0 }
        }

        // Apply sorting
        result.sort { recipe1, recipe2 in
            let ascending = filters.sortOrder == .ascending

            switch filters.sortOption {
            case .dateAdded:
                return ascending ? recipe1.dateAdded < recipe2.dateAdded : recipe1.dateAdded > recipe2.dateAdded
            case .title:
                return ascending ? recipe1.title < recipe2.title : recipe1.title > recipe2.title
            case .timesCooked:
                return ascending ? recipe1.timesCooked < recipe2.timesCooked : recipe1.timesCooked > recipe2.timesCooked
            case .lastCooked:
                let date1 = recipe1.lastCooked ?? Date.distantPast
                let date2 = recipe2.lastCooked ?? Date.distantPast
                return ascending ? date1 < date2 : date1 > date2
            }
        }

        return result
    }

    // MARK: - Actions

    private func refreshRecipes() async {
        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Simulate refresh (in reality, SwiftData query auto-updates)
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Success haptic
        let successGenerator = UINotificationFeedbackGenerator()
        successGenerator.notificationOccurred(.success)
    }

    private func deleteRecipe(_ recipe: Recipe) {
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        // Delete recipe
        modelContext.delete(recipe)

        do {
            try modelContext.save()

            // Success haptic
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.notificationOccurred(.success)

            ToastManager.shared.success(title: "Recipe deleted")

            // Track analytics
            AnalyticsService.shared.trackRecipeDeleted(recipeTitle: recipe.title)
        } catch {
            ToastManager.shared.error(
                title: "Failed to delete",
                message: error.localizedDescription
            )
        }
    }

    private func addSampleRecipe() {
        // Pick a random sample recipe from our library
        let sampleRecipes = SampleRecipeLibrary.all
        guard let sampleRecipe = sampleRecipes.randomElement() else { return }

        let recipe = sampleRecipe.recipe

        // Insert recipe first
        modelContext.insert(recipe)

        // Create and insert ingredients with proper parsing
        var ingredients: [Ingredient] = []
        for (index, text) in sampleRecipe.ingredients.enumerated() {
            // Parse the ingredient text
            let parsed = IngredientParser.parse(text)

            let ingredient = Ingredient(
                originalText: text,
                name: parsed.name,
                quantity: parsed.quantity,
                unit: parsed.unit,
                orderIndex: index
            )
            ingredient.quantityMax = parsed.quantityMax
            ingredient.recipe = recipe
            modelContext.insert(ingredient)
            ingredients.append(ingredient)
        }

        recipe.ingredients = ingredients

        do {
            try modelContext.save()
            print("✅ Sample recipe '\(recipe.title)' saved with \(ingredients.count) ingredients")
        } catch {
            print("❌ Failed to save sample recipe: \(error)")
        }
    }
}

// MARK: - Recipe Card View
struct RecipeCardView: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Recipe Image with async loading
            AsyncRecipeImage(
                imageFileName: recipe.imageFileName,
                placeholder: recipe.sourceType?.iconName ?? "fork.knife"
            )
            .aspectRatio(4/3, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipped()
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(HeirloomFonts.subheadline)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .frame(height: 40, alignment: .topLeading)

                Text(recipe.sourceDisplayName)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .lineLimit(1)
            }

            HStack {
                if recipe.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(HeirloomColors.familyGreen)
                        .font(.caption)
                }

                if recipe.timesCooked > 0 {
                    Label("\(recipe.timesCooked)", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(HeirloomColors.amber)
                }

                Spacer()
            }
            .frame(height: 20)
        }
        .padding(HeirloomSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(HeirloomSpacing.cardCornerRadius)
        .shadow(
            color: HeirloomShadows.card.color,
            radius: HeirloomShadows.card.radius,
            x: HeirloomShadows.card.x,
            y: HeirloomShadows.card.y
        )
    }
}

#Preview {
    RecipeListView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
