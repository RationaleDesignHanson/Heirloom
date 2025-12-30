import SwiftUI
import SwiftData

struct RecipeListView: View {
    @Query(sort: \Recipe.dateAdded, order: .reverse)
    private var recipes: [Recipe]

    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var showAddRecipe = false
    @State private var showImportRecipe = false
    @State private var showJSONImport = false
    @State private var showBulkImport = false
    @State private var showCookbookScanner = false
    @State private var showFilters = false
    @State private var filters = RecipeFilters()
    @State private var recipeToDelete: Recipe?
    @State private var showDeleteConfirmation = false
    @StateObject private var undoService = UndoService.shared
    @State private var isSyncing = false
    @StateObject private var syncCoordinator = CloudKitSyncCoordinator.shared

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
                // Sync status indicator (Quick Win #7)
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        if isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .accessibilityLabel("Syncing recipes")
                        }

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
                                        .frame(width: 18, height: 18)
                                        .background(HeirloomColors.tomato)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .strokeBorder(.white, lineWidth: 1.5)
                                        )
                                        .offset(x: 6, y: -6)
                                }
                            }
                            .padding(4) // Add padding to prevent clipping
                        }
                        .accessibilityLabel(filters.isActive ? "Filters, \(filters.activeFilterCount) active" : "Filters")
                        .accessibilityHint("Opens filter options for recipes")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showAddRecipe = true
                        } label: {
                            Label("New Recipe", systemImage: "square.and.pencil")
                        }
                        .accessibilityLabel("New Recipe")
                        .accessibilityHint("Create a new recipe manually")

                        Button {
                            showImportRecipe = true
                        } label: {
                            Label("Import from URL", systemImage: "link")
                        }
                        .accessibilityLabel("Import from URL")
                        .accessibilityHint("Import a recipe from a website URL")

                        Button {
                            showJSONImport = true
                        } label: {
                            Label("Import from JSON", systemImage: "doc.badge.arrow.up")
                        }
                        .accessibilityLabel("Import from JSON")
                        .accessibilityHint("Import a recipe from a JSON file")

                        Button {
                            showBulkImport = true
                        } label: {
                            Label("Bulk Import", systemImage: "square.stack.3d.down.forward")
                        }
                        .accessibilityLabel("Bulk Import")
                        .accessibilityHint("Import multiple recipes from photos")

                        Button {
                            showCookbookScanner = true
                        } label: {
                            Label("Scan Cookbook", systemImage: "book.pages")
                        }
                        .accessibilityLabel("Scan Cookbook")
                        .accessibilityHint("Scan a recipe from a cookbook page")

                        Divider()

                        Button {
                            addSampleRecipe()
                        } label: {
                            Label("Add Sample Recipe", systemImage: "sparkles")
                        }
                        .accessibilityLabel("Add Sample Recipe")
                        .accessibilityHint("Add a sample recipe for testing")

                        Divider()

                        Button {
                            testAIAPI()
                        } label: {
                            Label("🧪 Test AI API", systemImage: "wand.and.stars")
                        }
                        .accessibilityLabel("Test AI API")
                        .accessibilityHint("Test the AI recipe extraction API")
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Recipe")
                    .accessibilityHint("Opens menu to add or import recipes")
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
            .fileImporter(
                isPresented: $showJSONImport,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleJSONImport(result: result)
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
            .confirmationDialog(
                "Delete Recipe?",
                isPresented: $showDeleteConfirmation,
                presenting: recipeToDelete
            ) { recipe in
                Button("Delete", role: .destructive) {
                    deleteRecipe(recipe)
                }
                Button("Cancel", role: .cancel) {}
            } message: { recipe in
                Text("Are you sure you want to delete \"\(recipe.title)\"? You can undo this action within 5 seconds.")
            }
            .onAppear {
                // Configure UndoService with model context
                undoService.configure(modelContext: modelContext)
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
                ForEach(Array(filteredRecipes.enumerated()), id: \.element.id) { index, recipe in
                    NavigationLink(value: recipe) {
                        RecipeCardView(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                    .id(recipe.id)
                    .accessibilityLabel("\(recipe.title), \(recipe.sourceDisplayName)")
                    .accessibilityHint("Opens recipe details")
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        // Quick Win #5: Swipe to delete
                        Button(role: .destructive) {
                            recipeToDelete = recipe
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            toggleFavorite(recipe)
                        } label: {
                            Label(
                                recipe.isFavorite ? "Unfavorite" : "Favorite",
                                systemImage: recipe.isFavorite ? "heart.slash" : "heart.fill"
                            )
                        }
                        .tint(.yellow)
                    }
                    .contextMenu {
                        Button {
                            toggleFavorite(recipe)
                        } label: {
                            Label(
                                recipe.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                systemImage: recipe.isFavorite ? "heart.slash" : "heart.fill"
                            )
                        }
                        .accessibilityLabel(recipe.isFavorite ? "Remove from Favorites" : "Add to Favorites")

                        Button {
                            toggleShoppingList(recipe)
                        } label: {
                            Label(
                                recipe.isInShoppingList ? "Remove from Shopping List" : "Add to Shopping List",
                                systemImage: recipe.isInShoppingList ? "cart.badge.minus" : "cart.badge.plus"
                            )
                        }
                        .accessibilityLabel(recipe.isInShoppingList ? "Remove from Shopping List" : "Add to Shopping List")

                        Divider()

                        Button(role: .destructive) {
                            recipeToDelete = recipe
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .accessibilityLabel("Delete \(recipe.title)")
                    }
                }
            }
            .padding(.horizontal, HeirloomSpacing.md)
            .padding(.vertical, HeirloomSpacing.sm)
        }
        .refreshable {
            await refreshRecipes()
        }
        .tint(HeirloomColors.tomato) // Set pull-to-refresh spinner color
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
            case .lastViewed:
                let date1 = recipe1.lastViewed ?? Date.distantPast
                let date2 = recipe2.lastViewed ?? Date.distantPast
                return ascending ? date1 < date2 : date1 > date2
            }
        }

        return result
    }

    // MARK: - Actions

    private func refreshRecipes() async {
        // Track analytics
        await MainActor.run {
            isSyncing = true
            AnalyticsService.shared.track(event: .featureUsed, properties: [
                "feature": "pull_to_refresh",
                "context": "recipe_list"
            ])
        }

        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Trigger CloudKit sync
        await syncCoordinator.processPendingOperations()

        // SwiftData query auto-updates, so recipes refresh automatically
        // Add small delay for better UX (feels more responsive)
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        // Success haptic
        let successGenerator = UINotificationFeedbackGenerator()
        successGenerator.notificationOccurred(.success)

        await MainActor.run {
            isSyncing = false
        }
    }

    private func deleteRecipe(_ recipe: Recipe) {
        // Haptic feedback for deletion action
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Use UndoService for soft delete with undo capability
        undoService.deleteRecipe(recipe, context: modelContext)

        // Show undo toast
        ToastManager.shared.showUndoToast(for: undoService.pendingUndos.last!) {
            // Undo action
            if let undoItem = undoService.pendingUndos.last {
                undoService.undoDelete(undoItem)

                // Success haptic for undo
                let successGenerator = UINotificationFeedbackGenerator()
                successGenerator.notificationOccurred(.success)

                ToastManager.shared.success(title: "Recipe restored")
            }
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
                    title: "Failed to remove from shopping list",
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

                // Check shopping list milestone
                checkShoppingListMilestone()
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

    private func handleJSONImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            do {
                // Import recipe from JSON
                let recipe = try RecipeExportService.shared.importRecipeFromJSON(url: url)

                // Insert into context
                modelContext.insert(recipe)
                try modelContext.save()

                // Success feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                ToastManager.shared.success(
                    title: "Recipe Imported",
                    message: recipe.title
                )

                // Track analytics
                AnalyticsService.shared.track(event: .featureUsed, properties: [
                    "feature": "json_import",
                    "recipe_title": recipe.title
                ])

                // Check milestones
                checkRecipeMilestones()
            } catch {
                // Error feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)

                ToastManager.shared.error(
                    title: "Import Failed",
                    message: error.localizedDescription
                )
            }
        case .failure(let error):
            ToastManager.shared.error(
                title: "Import Failed",
                message: error.localizedDescription
            )
        }
    }

    private func addSampleRecipe() {
        // Pick a random sample recipe from our library
        let sampleRecipes = SampleRecipeLibrary.all
        guard let sampleRecipe = sampleRecipes.randomElement() else { return }

        Task {
            await createSampleRecipe(from: sampleRecipe)
        }
    }

    private func createSampleRecipe(from sampleRecipe: SampleRecipeData) async {
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

        // Download and save image
        if let imageURL = URL(string: sampleRecipe.imageURL) {
            print("📥 Downloading sample recipe image...")
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                if let image = UIImage(data: data) {
                    let fileName = try await ImageStorageService.shared.saveImage(image, recipeId: recipe.id)
                    recipe.imageFileName = fileName
                    print("✅ Sample recipe image downloaded and saved")
                }
            } catch {
                print("⚠️ Failed to download sample recipe image: \(error.localizedDescription)")
                // Continue without image - not a fatal error
            }
        }

        // Insert recipe first
        await MainActor.run {
            modelContext.insert(recipe)
        }

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
            await MainActor.run {
                modelContext.insert(ingredient)
            }
            ingredients.append(ingredient)
        }

        recipe.ingredients = ingredients

        // Create card back with sample data
        let cardBack = RecipeCardBack()
        cardBack.recipe = recipe
        cardBack.noteToFriends = sampleRecipe.cardBack.noteToFriends
        cardBack.personalTips = sampleRecipe.cardBack.personalTips
        if let rating = sampleRecipe.cardBack.rating {
            cardBack.userRating = rating
        }
        recipe.cardBack = cardBack
        await MainActor.run {
            modelContext.insert(cardBack)
        }

        // Create comments from sample data
        for (index, commentText) in sampleRecipe.comments.enumerated() {
            let comment = RecipeComment(
                text: commentText,
                authorName: "Sample User"
            )
            comment.recipe = recipe
            comment.isPinned = true  // Make sample comments pinned for visibility
            comment.createdAt = Date().addingTimeInterval(-Double(index) * 3600)  // Stagger timestamps
            await MainActor.run {
                modelContext.insert(comment)
            }
        }

        do {
            try await MainActor.run {
                try modelContext.save()
            }

            // Success feedback
            await MainActor.run {
                ToastManager.shared.success(
                    title: "Sample Recipe Added",
                    message: recipe.title
                )

                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                print("✅ Sample recipe '\(recipe.title)' saved with \(ingredients.count) ingredients, card back, and \(sampleRecipe.comments.count) comments")

                // Check milestones
                checkRecipeMilestones()
            }
        } catch {
            await MainActor.run {
                ToastManager.shared.error(
                    title: "Failed to save recipe",
                    message: error.localizedDescription
                )
                print("❌ Failed to save sample recipe: \(error)")
            }
        }
    }

    private func checkRecipeMilestones() {
        let recipeCount = recipes.count

        // Check first recipe
        if recipeCount == 1 {
            MilestoneManager.shared.checkFirstRecipeAdded()
        }

        // Check milestone thresholds
        if recipeCount == 10 {
            MilestoneManager.shared.checkTenRecipes()
        } else if recipeCount == 50 {
            MilestoneManager.shared.checkFiftyRecipes()
        }
    }

    private func checkShoppingListMilestone() {
        // Count total shopping list recipes
        let descriptor = FetchDescriptor<ShoppingCartRecipe>()
        if let cartRecipes = try? modelContext.fetch(descriptor) {
            // Check first shopping list
            if cartRecipes.count == 1 {
                MilestoneManager.shared.checkFirstShoppingList()
            }
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
            // Recipe Image with async loading and favorite badge overlay
            ZStack(alignment: .topLeading) {
                AsyncRecipeImage(
                    imageFileName: recipe.imageFileName,
                    placeholder: recipe.sourceType?.iconName ?? "fork.knife"
                )
                .aspectRatio(4/3, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipped()
                .cornerRadius(12)
                .accessibilityHidden(true) // Hide image from VoiceOver, recipe title is more important

                // Favorite heart badge (top left overlay)
                if recipe.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.white)
                        .font(.title3)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(HeirloomColors.familyGreen)
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        )
                        .padding(8)
                        .accessibilityLabel("Favorite")
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.title)
                    .font(HeirloomFonts.subheadline)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .frame(minHeight: 34, alignment: .topLeading)

                Text(recipe.sourceDisplayName)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)

            HStack {
                if recipe.timesCooked > 0 {
                    Label("\(recipe.timesCooked)", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(HeirloomColors.amber)
                        .accessibilityLabel("Cooked \(recipe.timesCooked) times")
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
                    .accessibilityLabel("\(generationBadge(for: generation)) recipe")
                }
            }
            .frame(height: 20)
        }
        .padding(HeirloomSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(HeirloomColors.cream)
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
