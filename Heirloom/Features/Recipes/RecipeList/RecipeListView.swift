import SwiftUI
import SwiftData

struct RecipeListView: View {
    @Query(sort: \Recipe.dateAdded, order: .reverse)
    private var recipes: [Recipe]

    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var showAddRecipe = false
    @State private var showImportRecipe = false
    @State private var showBulkImport = false
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
                            showBulkImport = true
                        } label: {
                            Label("Bulk Import", systemImage: "square.stack.3d.down.forward")
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

                        Divider()

                        Button {
                            testAIAPI()
                        } label: {
                            Label("🧪 Test AI API", systemImage: "wand.and.stars")
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
            .sheet(isPresented: $showBulkImport) {
                BulkImportView()
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
                            toggleFavorite(recipe)
                        } label: {
                            Label(
                                recipe.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                systemImage: recipe.isFavorite ? "heart.slash" : "heart.fill"
                            )
                        }

                        Button {
                            toggleShoppingList(recipe)
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

    private func toggleFavorite(_ recipe: Recipe) {
        recipe.isFavorite.toggle()
        recipe.lastModified = Date()

        do {
            try modelContext.save()

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            let message = recipe.isFavorite ? "Added to favorites" : "Removed from favorites"
            ToastManager.shared.success(title: message)
        } catch {
            ToastManager.shared.error(
                title: "Failed to update favorite",
                message: error.localizedDescription
            )
        }
    }

    private func toggleShoppingList(_ recipe: Recipe) {
        if let existingCartRecipe = recipe.shoppingCartRecipe(context: modelContext) {
            // Remove from shopping list
            modelContext.delete(existingCartRecipe)
            recipe.isInShoppingList = false

            do {
                try modelContext.save()

                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()

                ToastManager.shared.success(title: "Removed from shopping list")
            } catch {
                ToastManager.shared.error(
                    title: "Failed to remove",
                    message: error.localizedDescription
                )
            }
        } else {
            // Add to shopping list with original serving size
            let targetServings = recipe.parsedServingCount
            let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: targetServings)
            modelContext.insert(cartRecipe)
            recipe.isInShoppingList = true

            do {
                try modelContext.save()

                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()

                ToastManager.shared.success(title: "Added to shopping list")
            } catch {
                ToastManager.shared.error(
                    title: "Failed to add to shopping list",
                    message: error.localizedDescription
                )
            }
        }

        recipe.lastModified = Date()
        try? modelContext.save()
    }

    private func addSampleRecipe() {
        // Pick a random sample recipe from our library
        let sampleRecipes = SampleRecipeLibrary.all
        guard let sampleRecipe = sampleRecipes.randomElement() else { return }

        let sampleData = sampleRecipe.recipe

        // IMPORTANT: Create a NEW Recipe object (don't reuse the sample)
        // Reusing the same @Model instance causes SwiftData to crash/hang
        let recipe = Recipe(
            title: sampleData.title,
            sourceType: sampleData.sourceType ?? .manual,
            sourceURL: sampleData.sourceURL,
            instructions: sampleData.instructions,
            servings: sampleData.servings,
            prepTime: sampleData.prepTime,
            cookTime: sampleData.cookTime
        )

        // Copy additional properties
        recipe.sourcePerson = sampleData.sourcePerson
        recipe.sourceDate = sampleData.sourceDate
        recipe.sourceBookTitle = sampleData.sourceBookTitle
        recipe.timesCooked = sampleData.timesCooked
        recipe.isFavorite = sampleData.isFavorite
        recipe.notes = sampleData.notes

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
                category: GroceryCategory.categorize(parsed.name),
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

            // Success feedback
            ToastManager.shared.success(
                title: "Sample Recipe Added",
                message: recipe.title
            )

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            print("✅ Sample recipe '\(recipe.title)' saved with \(ingredients.count) ingredients")
        } catch {
            ToastManager.shared.error(
                title: "Failed to add sample recipe",
                message: error.localizedDescription
            )
            print("❌ Failed to save sample recipe: \(error)")
        }
    }

    // MARK: - AI API Test

    private func testAIAPI() {
        Task {
            print("\n🧪 Starting AI API Test...")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            // Enable AI features (API key should be configured via Settings)
            // For testing: Read API key from file at /Users/matthanson/Desktop/heriloom.txt
            if let apiKey = try? String(contentsOfFile: "/Users/matthanson/Desktop/heriloom.txt", encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines), !apiKey.isEmpty {
                AIConfiguration.shared.setAPIKey(apiKey, for: .anthropic)
                AIConfiguration.shared.enableAIParsing = true
                print("✅ AI parsing enabled for recipe imports")
            } else {
                print("⚠️ No API key found. Please add key to /Users/matthanson/Desktop/heriloom.txt")
                print("   Or configure via Settings once AI Settings UI is built")
            }

            // Step 1: Check configuration
            print("\n1️⃣ Checking configuration...")
            let config = AIConfiguration.shared

            if config.isConfigured(provider: .anthropic) {
                print("✅ Anthropic API key is configured")
            } else {
                print("❌ Anthropic API key NOT configured")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                return
            }

            // Step 2: Test simple completion
            print("\n2️⃣ Testing simple completion...")
            do {
                let service = AnthropicAIService.shared
                let response = try await service.complete(
                    prompt: "Say 'Hello from Heirloom!' in exactly 3 words.",
                    options: AICompletionOptions(
                        model: "claude-3-haiku-20240307",
                        temperature: 0.7,
                        maxTokens: 50,
                        systemMessage: "You are a helpful assistant.",
                        stopSequences: nil
                    )
                )

                print("✅ API call successful!")
                print("   Response: \(response.content)")
                print("   Model: \(response.model)")
                print("   Tokens used: \(response.usage.totalTokens)")
                print("   Cost: $\(response.usage.totalCost)")

            } catch let error as AIError {
                print("❌ API call failed: \(error.errorDescription ?? "Unknown error")")
                print("   Context: \(error.context)")
            } catch {
                print("❌ Unexpected error: \(error)")
            }

            // Step 3: Test structured completion (JSON response)
            print("\n3️⃣ Testing structured completion (JSON)...")

            struct IngredientTest: Codable {
                let quantity: Double?
                let unit: String?
                let name: String
            }

            do {
                let service = AnthropicAIService.shared
                let ingredient = try await service.completeStructured(
                    prompt: """
                    Parse this ingredient: "2 cups flour"

                    Return JSON:
                    {
                      "quantity": 2.0,
                      "unit": "cups",
                      "name": "flour"
                    }
                    """,
                    schema: IngredientTest.self
                )

                print("✅ Structured completion successful!")
                print("   Quantity: \(ingredient.quantity ?? 0)")
                print("   Unit: \(ingredient.unit ?? "none")")
                print("   Name: \(ingredient.name)")

            } catch let error as AIError {
                print("❌ Structured completion failed: \(error.errorDescription ?? "Unknown error")")
            } catch {
                print("❌ Unexpected error: \(error)")
            }

            // Step 4: Show usage statistics
            print("\n4️⃣ Usage statistics...")
            let tracker = AIUsageTracker.shared
            print("   Total tokens used: \(tracker.totalTokensUsed)")
            print("   Total cost: $\(tracker.totalCost)")
            print("   Request count: \(tracker.requestCount)")

            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("✅ Test complete!")
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

                // Generation badge for lineage
                if let generation = recipe.provenance?.generation, generation > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(generationColor(for: generation))

                        Text(generationBadge(for: generation))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(generationColor(for: generation))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(generationColor(for: generation).opacity(0.15))
                    )
                }
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

    // MARK: - Generation Badge Helpers

    private func generationBadge(for generation: Int) -> String {
        switch generation {
        case 1: return "1st Gen"
        case 2: return "2nd Gen"
        case 3: return "3rd Gen"
        default: return "\(generation)th Gen"
        }
    }

    private func generationColor(for generation: Int) -> Color {
        switch generation {
        case 1: return .blue
        case 2: return .green
        case 3: return .orange
        default: return HeirloomColors.warmGray
        }
    }
}

#Preview {
    RecipeListView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
