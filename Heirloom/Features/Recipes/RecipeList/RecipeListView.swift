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
    @State private var recipeToDelete: Recipe?
    @State private var showDeleteConfirmation = false
    @StateObject private var undoService = UndoService.shared
    @State private var isSyncing = false

    // Conflict resolution
    @State private var showConflictResolution = false
    @State private var conflictRecipeCRDT: RecipeCRDT?
    @State private var conflictList: [DetailedConflict] = []

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    if recipes.isEmpty {
                        emptyState
                            .frame(minHeight: geometry.size.height)
                    } else if filteredRecipes.isEmpty {
                        noResultsState
                            .frame(minHeight: geometry.size.height)
                    } else {
                        recipeGridContent
                    }
                }
                .background(HeirloomColors.appBackground)
            }
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search recipes")
            .refreshable {
                await refreshRecipes()
            }
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
            .onReceive(NotificationCenter.default.publisher(for: .recipeConflictsDetected)) { notification in
                handleConflictNotification(notification)
            }
            .sheet(isPresented: $showConflictResolution) {
                conflictResolutionSheet
            }
        }
    }

    // MARK: - Conflict Resolution Sheet
    @ViewBuilder
    private var conflictResolutionSheet: some View {
        if let recipeCRDT = conflictRecipeCRDT, !conflictList.isEmpty {
            ConflictResolutionWrapper(
                conflicts: conflictList,
                recipeCRDT: recipeCRDT
            )
        }
    }

    // MARK: - Recipe Grid Content
    private var recipeGridContent: some View {
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

        // Trigger Firebase sync to download and merge changes
        if BackendConfig.shared.isFirebaseActive {
            do {
                try await FirebaseSyncService.shared.syncChangesWithCRDT()
                Log.info("Pull-to-refresh sync complete", category: .sync)

                // Success haptic
                let successGenerator = UINotificationFeedbackGenerator()
                successGenerator.notificationOccurred(.success)
            } catch {
                Log.error("Pull-to-refresh sync failed", category: .sync, error: error)

                // Error haptic
                let errorGenerator = UINotificationFeedbackGenerator()
                errorGenerator.notificationOccurred(.error)
            }
        } else {
            // If Firebase not active, just add small delay for better UX
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            // Success haptic
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.notificationOccurred(.success)
        }

        await MainActor.run {
            isSyncing = false
        }
    }

    private func deleteRecipe(_ recipe: Recipe) {
        // Haptic feedback for deletion action
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Delete from Firebase if active
        if BackendConfig.shared.isFirebaseActive {
            Task {
                do {
                    try await FirebaseSyncService.shared.deleteRecipe(recipe.id)
                    Log.info("Recipe deleted from Firebase", category: .firebase, metadata: ["recipeId": recipe.id.uuidString])
                } catch {
                    Log.error("Failed to delete recipe from Firebase", category: .firebase, error: error, metadata: ["recipeId": recipe.id.uuidString])
                }
            }
        }

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

        Log.info("Toggling favorite", category: .ui, metadata: ["title": recipe.title, "isFavorite": recipe.isFavorite])
        Log.debug("Firebase backend active", category: .ui, metadata: ["isActive": BackendConfig.shared.isFirebaseActive])

        do {
            try modelContext.save()
            Log.debug("Local save successful", category: .database)

            // Sync favorite status to Firebase
            if BackendConfig.shared.isFirebaseActive {
                Log.debug("Firebase active, starting upload", category: .sync)
                Task {
                    do {
                        try await FirebaseSyncService.shared.uploadRecipe(recipe)
                        Log.info("Favorite status synced to Firebase", category: .sync, metadata: ["recipeId": recipe.id.uuidString])
                    } catch {
                        Log.error("Failed to sync favorite status", category: .sync, error: error)
                    }
                }
            } else {
                Log.debug("Firebase not active, skipping upload", category: .sync)
            }

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

                // Shopping cart is local-only (no Firebase sync needed for ephemeral data)

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

                // Shopping cart is local-only (no Firebase sync needed for ephemeral data)

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
            Log.info("Downloading sample recipe image", category: .network, metadata: ["url": sampleRecipe.imageURL])
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                if let image = UIImage(data: data) {
                    let fileName = try await ImageStorageService.shared.saveImage(image, recipeId: recipe.id)
                    recipe.imageFileName = fileName
                    Log.info("Sample recipe image downloaded and saved", category: .storage, metadata: ["fileName": fileName])
                }
            } catch {
                Log.warning("Failed to download sample recipe image", category: .network, metadata: ["error": error.localizedDescription])
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

            // Sync to Firebase if active
            if BackendConfig.shared.isFirebaseActive {
                do {
                    try await FirebaseSyncService.shared.uploadRecipe(recipe)
                    Log.info("Sample recipe synced to Firebase", category: .sync, metadata: ["recipeId": recipe.id.uuidString])

                    // Create root lineage for sample recipe
                    do {
                        try await FirebaseLineageService.shared.createRootLineage(
                            recipeId: recipe.id,
                            context: modelContext
                        )
                        Log.info("Sample recipe lineage created", category: .firebase, metadata: ["recipeId": recipe.id.uuidString])
                    } catch {
                        Log.warning("Failed to create sample recipe lineage", category: .firebase, metadata: ["error": error.localizedDescription])
                    }
                } catch {
                    Log.warning("Failed to sync sample recipe to Firebase", category: .sync, metadata: ["error": error.localizedDescription])
                    // Don't fail the save - local save succeeded
                }
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

                Log.info("Sample recipe saved", category: .ui, metadata: ["title": recipe.title, "ingredientCount": ingredients.count, "commentCount": sampleRecipe.comments.count])

                // Check milestones
                checkRecipeMilestones()
            }
        } catch {
            await MainActor.run {
                ToastManager.shared.error(
                    title: "Failed to save recipe",
                    message: error.localizedDescription
                )
                Log.error("Failed to save sample recipe", category: .database, error: error)
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

    private func handleConflictNotification(_ notification: Notification) {
        guard let conflictsDetected = notification.object as? [(crdt: RecipeCRDT, conflicts: [DetailedConflict])] else {
            Log.warning("Failed to parse conflict notification", category: .crdt)
            return
        }

        Log.info("Received conflict notification", category: .crdt, metadata: ["count": conflictsDetected.count])

        // For now, show the first conflict
        // TODO: In the future, show a list of all conflicting recipes
        if let first = conflictsDetected.first {
            conflictRecipeCRDT = first.crdt
            conflictList = first.conflicts
            showConflictResolution = true

            Log.info("Showing conflict resolution UI", category: .ui, metadata: ["title": first.crdt.recipe.title])
        }
    }
}

// MARK: - Conflict Resolution Wrapper
struct ConflictResolutionWrapper: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let conflicts: [DetailedConflict]
    let recipeCRDT: RecipeCRDT

    @State private var resolutions: [String: ConflictResolution.ResolutionChoice] = [:]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("⚠️ Conflict Detected")
                        .font(.title)
                    Text("Recipe: \(recipeCRDT.recipe.title)")
                        .font(.headline)
                    Text("\(conflicts.count) field(s) need resolution")
                        .font(.subheadline)

                    ForEach(Array(conflicts.enumerated()), id: \.offset) { index, conflict in
                        VStack(alignment: .leading) {
                            Text("Field: \(conflict.fieldPath)")
                                .font(.caption)
                                .bold()
                            Text("Local: \(conflict.localValue?.stringValue ?? "N/A")")
                                .font(.caption2)
                            Text("Remote: \(conflict.remoteValue?.stringValue ?? "N/A")")
                                .font(.caption2)

                            HStack {
                                Button("Keep Local") {
                                    resolutions[conflict.fieldPath] = .keepLocal
                                }
                                .buttonStyle(.bordered)

                                Button("Keep Remote") {
                                    resolutions[conflict.fieldPath] = .keepRemote
                                }
                                .buttonStyle(.bordered)
                            }

                            if let choice = resolutions[conflict.fieldPath] {
                                Text("✓ Choice: \(choiceDescription(choice))")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }

                    if allResolved {
                        Button("Save Resolution") {
                            Task {
                                await saveResolution()
                            }
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }

                    Button("Close for Now") {
                        dismiss()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Resolve Conflict")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var allResolved: Bool {
        resolutions.count == conflicts.count
    }

    private func choiceDescription(_ choice: ConflictResolution.ResolutionChoice) -> String {
        switch choice {
        case .keepLocal: return "Keep Local"
        case .keepRemote: return "Keep Remote"
        case .keepBoth: return "Keep Both"
        case .custom: return "Custom"
        }
    }

    private func applyValueToRecipe(_ value: OperationValue, forField fieldPath: String) {
        Log.debug("Applying value to field", category: .crdt, metadata: ["fieldPath": fieldPath])
        switch fieldPath {
        case "title":
            if let stringValue = value.stringValue {
                recipeCRDT.recipe.title = stringValue
                Log.debug("Set title", category: .crdt, metadata: ["value": stringValue])
            }
        case "notes":
            if let stringValue = value.stringValue {
                recipeCRDT.recipe.notes = stringValue
            } else if case .null = value {
                recipeCRDT.recipe.notes = nil
            }
        case "prepTime":
            if let stringValue = value.stringValue {
                recipeCRDT.recipe.prepTime = stringValue
            } else if case .null = value {
                recipeCRDT.recipe.prepTime = nil
            }
        case "cookTime":
            if let stringValue = value.stringValue {
                recipeCRDT.recipe.cookTime = stringValue
            } else if case .null = value {
                recipeCRDT.recipe.cookTime = nil
            }
        case "servings":
            if let stringValue = value.stringValue {
                recipeCRDT.recipe.servings = stringValue
            } else if case .null = value {
                recipeCRDT.recipe.servings = nil
            }
        default:
            Log.warning("Unknown field path in conflict resolution", category: .crdt, metadata: ["fieldPath": fieldPath])
        }
    }

    @MainActor
    private func saveResolution() async {
        Log.info("Starting conflict resolution save", category: .crdt)
        Log.debug("Recipe title before resolution", category: .crdt, metadata: ["title": recipeCRDT.recipe.title])

        // Build resolutions list and apply values directly
        let resolutionsList = conflicts.compactMap { conflict -> ConflictResolution? in
            guard let choice = resolutions[conflict.fieldPath] else { return nil }

            // Apply the chosen value directly to the recipe
            Log.debug("Applying conflict resolution choice", category: .crdt, metadata: ["choice": String(describing: choice), "fieldPath": conflict.fieldPath])
            switch choice {
            case .keepLocal:
                if let localValue = conflict.localValue {
                    applyValueToRecipe(localValue, forField: conflict.fieldPath)
                }
            case .keepRemote:
                if let remoteValue = conflict.remoteValue {
                    applyValueToRecipe(remoteValue, forField: conflict.fieldPath)
                }
            default:
                break
            }

            return ConflictResolution(
                fieldPath: conflict.fieldPath,
                localOperationId: conflict.operation1.id,
                remoteOperationId: conflict.operation2.id,
                choice: choice
            )
        }

        Log.debug("Recipe title after applying values", category: .crdt, metadata: ["title": recipeCRDT.recipe.title])
        Log.info("Applying resolutions to CRDT", category: .crdt, metadata: ["count": resolutionsList.count])

        // Apply resolutions to CRDT operation log
        CRDTMergeEngine.shared.applyUserResolution(resolutionsList, to: recipeCRDT)

        Log.debug("Recipe title after CRDT resolution", category: .crdt, metadata: ["title": recipeCRDT.recipe.title])

        // Clear conflict flags on the recipe
        Log.debug("Clearing conflict flags", category: .crdt)
        recipeCRDT.recipe.hasPendingConflicts = false
        recipeCRDT.recipe.showConflictBadge = false
        recipeCRDT.recipe.lastModified = Date()

        // Save to database
        do {
            Log.debug("Saving conflict resolution to database", category: .database)
            try modelContext.save()
            Log.info("Conflict resolution saved to database", category: .database)

            // Sync to Firebase
            if BackendConfig.shared.isFirebaseActive {
                Log.debug("Uploading resolved recipe to Firebase", category: .sync)
                try await FirebaseSyncService.shared.uploadRecipe(recipeCRDT.recipe)
                Log.info("Resolved recipe synced to Firebase", category: .sync)
            }

            // Show success
            ToastManager.shared.success(
                title: "Recipe Merged",
                message: "All conflicts resolved successfully"
            )

            Log.info("Conflict resolution complete", category: .crdt)
            dismiss()
        } catch {
            Log.error("Failed to save conflict resolution", category: .database, error: error)
            // Show error
            ToastManager.shared.error(
                title: "Failed to Save",
                message: error.localizedDescription
            )
        }
    }
}

// MARK: - Recipe Card View
struct RecipeCardView: View {
    let recipe: Recipe
    @EnvironmentObject private var notificationService: FirebaseNotificationService

    private var unreadCount: Int {
        notificationService.unreadCount(for: recipe.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Recipe Image with async loading and favorite badge overlay
            ZStack {
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

                // Notification badge (top right overlay)
                if unreadCount > 0 {
                    ZStack {
                        Circle()
                            .fill(HeirloomColors.tomato)
                            .frame(width: 24, height: 24)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

                        Text("\(unreadCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(8)
                    .accessibilityLabel("\(unreadCount) unread notification\(unreadCount == 1 ? "" : "s")")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }

                // Conflict warning badge (bottom left overlay)
                if recipe.showConflictBadge || recipe.hasPendingConflicts {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white)
                        .font(.title3)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(HeirloomColors.conflictAlert)
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        )
                        .padding(8)
                        .accessibilityLabel("Has unresolved conflicts")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
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
