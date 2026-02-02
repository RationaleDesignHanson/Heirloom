import SwiftUI
import SwiftData

/// Detail view showing recipes within a collection
/// Note: Uses VideoImportMode enum defined in RecipeListView.swift
struct CollectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationService: FirebaseNotificationService
    @EnvironmentObject private var tabCoordinator: TabNavigationCoordinator
    @EnvironmentObject private var syncService: FirebaseSyncService
    let collection: RecipeCollection

    @State private var showRecipeGenerator = false
    @State private var showImportRecipe = false
    @State private var showBulkImport = false
    @State private var showCookbookScanner = false
    @State private var showVideoImport = false
    @State private var showDeleteConfirmation = false
    @State private var showAddRecipeMenu = false
    @State private var showCollectionSettings = false
    @State private var showSettings = false
    @EnvironmentObject private var unlockTracker: ThemeUnlockTracker
    @State private var isGeneratingBackground = false

    // Services
    private var collectionImageGenerator: CollectionImageGenerator { ServiceContainer.shared.resolve(CollectionImageGenerator.self) }
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }

    // Context menu state
    @State private var recipeToDelete: Recipe?
    @State private var recipeForCollectionPicker: Recipe?

    // Batch selection state (for "All Recipes" collection)
    @State private var isSelectionMode = false
    @State private var selectedRecipeIDs: Set<UUID> = []
    @State private var showCollectionPicker = false
    @State private var showCollectionEditor = false
    @State private var existingCollectionIDs: Set<UUID> = []

    @Query private var allRecipes: [Recipe]
    @Query private var allCollections: [RecipeCollection]

    init(collection: RecipeCollection) {
        self.collection = collection
        // Fetch all recipes sorted by most recently added
        _allRecipes = Query(sort: \Recipe.dateAdded, order: .reverse)
    }

    // Count of user-added (non-theme) recipes
    private var userAddedRecipeCount: Int {
        recipes.filter { !$0.isThemeRecipe }.count
    }

    // Should show the "add your own" nudge
    private var shouldShowAddNudge: Bool {
        collection.type == .theme && userAddedRecipeCount == 0 && !recipes.isEmpty
    }

    // Recipes in this collection
    var recipes: [Recipe] {
        // Special handling for "All Recipes" collection - show all recipes
        if collection.isAllRecipes {
            return allRecipes
        }

        // For theme collections, query by sourceThemeId to avoid accessing collections relationship
        if collection.type == .theme {
            guard let themeId = collection.sourceThemeId else { return [] }
            let themeRecipes = allRecipes.filter { $0.sourceThemeId == themeId }
            return themeRecipes.filter { unlockTracker.isUnlocked($0) }
        }

        // For other collections, use the relationship
        let collectionRecipes = allRecipes.filter { recipe in
            recipe.collections?.contains(where: { $0.id == collection.id }) ?? false
        }

        return collectionRecipes
    }

    // Get Recipe objects for selected IDs
    private func getSelectedRecipes() -> [Recipe] {
        return allRecipes.filter { selectedRecipeIDs.contains($0.id) }
    }

    // Available collections for the picker (excludes "All Recipes", heritage, and theme collections)
    private var availableCollectionsForPicker: [RecipeCollection] {
        return allCollections.filter {
            !$0.isAllRecipes && !$0.isHeritageCollection && $0.type != .theme
        }
    }

    // Add selected recipes to a collection
    private func addRecipesToCollection(_ collection: RecipeCollection) {
        let selectedRecipes = getSelectedRecipes()

        for recipe in selectedRecipes {
            let alreadyInCollection = recipe.collections?.contains(where: { $0.id == collection.id }) ?? false

            if !alreadyInCollection {
                if recipe.collections == nil {
                    recipe.collections = []
                }
                recipe.collections?.append(collection)
            }
        }

        try? modelContext.save()

        // Reset selection state
        selectedRecipeIDs.removeAll()
        isSelectionMode = false
        showCollectionPicker = false
    }

    // Handle collection editor dismissal - add recipes to newly created collection
    private func handleCollectionEditorDismissal() {
        // Find newly created collection by comparing with existingCollectionIDs
        let currentCollectionIDs = Set(allCollections.map { $0.id })
        let newCollectionIDs = currentCollectionIDs.subtracting(existingCollectionIDs)

        // If a new collection was created, add selected recipes to it
        if let newCollectionID = newCollectionIDs.first,
           let newCollection = allCollections.first(where: { $0.id == newCollectionID }) {
            addRecipesToCollection(newCollection)
        }

        // Clear tracking set
        existingCollectionIDs.removeAll()
    }

    // MARK: - Recipe Card Helper

    @ViewBuilder
    private func recipeCard(for recipe: Recipe) -> some View {
        if isSelectionMode && collection.isAllRecipes {
            // Selection mode: tap to select/deselect
            RecipeCardView(recipe: recipe)
                .overlay(alignment: .topTrailing) {
                    if selectedRecipeIDs.contains(recipe.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .background(HeirloomColors.cardBackground)
                            .clipShape(Circle())
                            .padding(HeirloomSpacing.sm)
                    }
                }
                .onTapGesture {
                    if selectedRecipeIDs.contains(recipe.id) {
                        selectedRecipeIDs.remove(recipe.id)
                    } else {
                        selectedRecipeIDs.insert(recipe.id)
                    }
                }
        } else {
            // Normal mode: tap to navigate
            NavigationLink {
                RecipeDetailView(recipe: recipe)
                    .environmentObject(notificationService)
            } label: {
                RecipeCardView(recipe: recipe)
            }
            .buttonStyle(.plain)
            .contextMenu {
                recipeContextMenu(for: recipe)
            }
        }
    }

    // MARK: - Loading State

    private var isLoadingRecipes: Bool {
        syncService.loadingCollectionIds.contains(collection.id)
    }

    private var loadingProgress: FirebaseSyncService.SyncProgress? {
        syncService.syncProgress[collection.id]
    }

    @ViewBuilder
    private var loadingBanner: some View {
        if isLoadingRecipes, let progress = loadingProgress {
            HStack(spacing: HeirloomSpacing.sm) {
                ProgressView()
                    .scaleEffect(0.8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Loading Recipes...")
                        .font(HeirloomFonts.caption1Bold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("\(progress.loadedRecipes) of \(progress.totalRecipes) recipes loaded")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Spacer()
            }
            .padding(HeirloomSpacing.md)
            .background(HeirloomColors.amber.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, HeirloomSpacing.md)
        }
    }

    // MARK: - View Helpers

    @ViewBuilder
    private var recipesGridOrEmpty: some View {
        if recipes.isEmpty {
            emptyStateView
        } else {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: HeirloomSpacing.gridSpacing),
                GridItem(.flexible(), spacing: HeirloomSpacing.gridSpacing)
            ], spacing: HeirloomSpacing.gridSpacing) {
                ForEach(recipes, id: \.id) { recipe in
                    recipeCard(for: recipe)
                }
            }
            .padding(.horizontal, HeirloomSpacing.md)

            // Add recipe nudge (only for theme collections with no user recipes)
            if shouldShowAddNudge {
                addRecipeNudge
                    .padding(.top, HeirloomSpacing.lg)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // For "All Recipes": Show Select/Done button for batch operations
        if collection.isAllRecipes {
            ToolbarItem(placement: .primaryAction) {
                Button(isSelectionMode ? "Done" : "Select") {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        selectedRecipeIDs.removeAll()
                    }
                }
            }
        } else {
            // For other collections: Show add/import actions
            ToolbarItem(placement: .primaryAction) {
                RecipeListToolbarActions(
                    isSelectionMode: false,
                    selectedCount: 0,
                    filteredCount: recipes.count,
                    onSelectAllToggle: {},
                    onGenerateRecipe: {
                        tabCoordinator.willCreateRecipe(from: .collectionDetail)
                        showRecipeGenerator = true
                    },
                    onImportRecipe: {
                        tabCoordinator.willCreateRecipe(from: .collectionDetail)
                        showImportRecipe = true
                    },
                    onBulkImport: {
                        tabCoordinator.willCreateRecipe(from: .collectionDetail)
                        showBulkImport = true
                    },
                    onCookbookScanner: {
                        tabCoordinator.willCreateRecipe(from: .collectionDetail)
                        showCookbookScanner = true
                    },
                    onVideoImport: {
                        tabCoordinator.willCreateRecipe(from: .collectionDetail)
                        showVideoImport = true
                    },
                    onAddCollection: {}, // Not applicable within a collection detail view
                    onCollectionSettings: {
                        showCollectionSettings = true
                    },
                    onOpenSettings: { showSettings = true }
                )
            }
        }

        // Collection menu (settings, AI generation, delete)
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showCollectionSettings = true
                } label: {
                    Label("Collection Settings", systemImage: "gear")
                }

                Button {
                    Task {
                        await generateBackgroundForCollection()
                    }
                } label: {
                    Label("Generate with AI", systemImage: "sparkles")
                }
                .disabled(isGeneratingBackground)

                if !collection.isSystemCollection {
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Collection", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Collection Menu")
        }
    }

    @ViewBuilder
    private func recipeContextMenu(for recipe: Recipe) -> some View {
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

        Button {
            recipeForCollectionPicker = recipe
        } label: {
            Label("Add to Collection", systemImage: "folder.badge.plus")
        }

        // Only show "Remove from Collection" for non-system collections
        if !collection.isSystemCollection {
            Divider()

            Button {
                removeRecipeFromCollection(recipe)
            } label: {
                Label("Remove from Collection", systemImage: "minus.circle")
            }
        }

        Divider()

        Button(role: .destructive) {
            recipeToDelete = recipe
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
                // Loading banner (when syncing recipes)
                loadingBanner

                // Collection header
                collectionHeader

                // Recipes grid
                recipesGridOrEmpty
            }
            .padding(.vertical, HeirloomSpacing.lg)
        }
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showRecipeGenerator) {
            RecipeGeneratorView(
                generator: ServiceContainer.shared.resolve(AIRecipeGeneratorProtocol.self),
                imageGenerator: ServiceContainer.shared.resolve(RecipeImageGeneratorProtocol.self)
            )
            .environmentObject(tabCoordinator)
        }
        .sheet(isPresented: $showImportRecipe) {
            RecipeImportView()
                .environmentObject(tabCoordinator)
        }
        .sheet(isPresented: $showBulkImport) {
            BulkImportView()
                .environmentObject(tabCoordinator)
        }
        .sheet(isPresented: $showCookbookScanner) {
            CookbookScannerView()
                .environmentObject(tabCoordinator)
        }
        .sheet(isPresented: $showVideoImport) {
            UnifiedVideoImportView()
                .environmentObject(tabCoordinator)
        }
        .sheet(isPresented: $showCollectionSettings) {
            NavigationStack {
                CollectionSettingsView(collection: collection)
                    .environmentObject(tabCoordinator)
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .environmentObject(tabCoordinator)
            }
        }
        .confirmationDialog(
            "Add Recipe",
            isPresented: $showAddRecipeMenu,
            titleVisibility: .visible
        ) {
            Button("New Recipe") {
                tabCoordinator.willCreateRecipe(from: .collectionDetail)
                showRecipeGenerator = true
            }

            Button("Recipe Website Link") {
                tabCoordinator.willCreateRecipe(from: .collectionDetail)
                showImportRecipe = true
            }

            Button("Bulk Import") {
                tabCoordinator.willCreateRecipe(from: .collectionDetail)
                showBulkImport = true
            }

            Button("Scan Cookbook Page") {
                tabCoordinator.willCreateRecipe(from: .collectionDetail)
                showCookbookScanner = true
            }

            Button("Video Import") {
                tabCoordinator.willCreateRecipe(from: .collectionDetail)
                showVideoImport = true
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose how you'd like to add recipes to \(collection.name)")
        }
        .confirmationDialog(
            "Delete Recipe?",
            isPresented: Binding(
                get: { recipeToDelete != nil },
                set: { if !$0 { recipeToDelete = nil } }
            )
        ) {
            if let recipe = recipeToDelete {
                Button("Delete", role: .destructive) {
                    modelContext.delete(recipe)
                    try? modelContext.save()

                    let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                    toastManager.success(title: "Recipe deleted")

                    recipeToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                recipeToDelete = nil
            }
        } message: {
            if let recipe = recipeToDelete {
                Text("Are you sure you want to delete \"\(recipe.title)\"? This cannot be undone.")
            }
        }
        .sheet(item: $recipeForCollectionPicker) { recipe in
            NavigationStack {
                TagCollectionPickerView(recipe: recipe)
            }
        }
        .confirmationDialog(
            "Delete \(collection.name)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Collection Only", role: .destructive) {
                Task {
                    await deleteCollectionKeepingRecipes()
                }
            }

            Button("Delete Collection & Recipes", role: .destructive) {
                Task {
                    await deleteCollectionAndRecipes()
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose what to delete:\n• Collection Only: Recipes remain in your library\n• Collection & Recipes: Removes everything")
        }
        .safeAreaInset(edge: .bottom) {
            // Selection action bar (only for "All Recipes" when recipes are selected)
            if isSelectionMode && collection.isAllRecipes && !selectedRecipeIDs.isEmpty {
                HStack {
                    Text("\(selectedRecipeIDs.count) selected")
                        .font(HeirloomFonts.bodyBold)
                    Spacer()
                    Button("Add to Collection") {
                        showCollectionPicker = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color(.systemBackground))
                .shadow(radius: 8)
            }
        }
        .sheet(isPresented: $showCollectionPicker) {
            NavigationStack {
                List {
                    // "Create New Collection" option
                    Section {
                        Button {
                            // Track existing collections before opening editor
                            existingCollectionIDs = Set(allCollections.map { $0.id })
                            showCollectionEditor = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.blue)
                                Text("Create New Collection")
                                    .foregroundStyle(.primary)
                            }
                        }
                    }

                    // Existing collections
                    if !availableCollectionsForPicker.isEmpty {
                        Section("Existing Collections") {
                            ForEach(availableCollectionsForPicker) { collection in
                                Button {
                                    addRecipesToCollection(collection)
                                } label: {
                                    HStack {
                                        Image(systemName: collection.iconName)
                                            .foregroundStyle(collection.swiftUIColor)
                                        Text(collection.name)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Add to Collection")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showCollectionPicker = false
                        }
                    }
                }
                .sheet(isPresented: $showCollectionEditor) {
                    CollectionEditorView()
                        .environmentObject(tabCoordinator)
                }
                .onChange(of: showCollectionEditor) { _, isShowing in
                    // When editor dismisses, check if a new collection was created
                    if !isShowing {
                        handleCollectionEditorDismissal()
                    }
                }
            }
        }
        .onAppear {
            // TODO: Re-enable for Phase A3
            // if unlockTracker == nil {
            //     unlockTracker = ServiceContainer.shared.resolve(ThemeUnlockTracker.self)
            // }
        }
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

    // MARK: - Actions

    private func addNormalSampleRecipe() {
        // Pick any recipe from the full library
        guard let sampleRecipe = SampleRecipeLibrary.all.randomElement() else { return }

        Task {
            await createSampleRecipe(from: sampleRecipe, addToCollection: collection)
        }
    }

    private func generateBackgroundForCollection() async {
        guard !isGeneratingBackground else {
            toastManager.info(title: "Generation in Progress", message: "Please wait for the current generation to finish")
            return
        }

        isGeneratingBackground = true

        // Show toast that generation started
        await MainActor.run {
            toastManager.info(title: "Generating Background", message: "Creating AI image for \(collection.name)...")
        }

        do {
            // Generate AI image
            let imagePath = try await collectionImageGenerator.generateBackground(for: collection)

            await MainActor.run {
                // Update collection with generated image
                collection.generatedBackgroundImagePath = imagePath
                collection.lastImageGenerationDate = Date()
                collection.lastRecipeCountAtGeneration = collection.recipes?.count ?? 0
                collection.useCustomBackground = true
                try? modelContext.save()

                isGeneratingBackground = false
                toastManager.success(title: "Background Generated", message: "AI created a custom image for \(collection.name)")
            }
        } catch {
            await MainActor.run {
                isGeneratingBackground = false
                toastManager.error(title: "Generation Failed", message: error.localizedDescription)
            }
        }
    }

    private func createSampleRecipe(from sampleRecipe: SampleRecipeData, addToCollection: RecipeCollection) async {
        let sampleData = sampleRecipe.recipe
        let imageStorageService = ServiceContainer.shared.resolve(ImageStorageService.self)

        // Create a unique title variation by checking existing recipes
        var finalTitle = sampleData.title
        let existingTitles = recipes.map { $0.title }
        if existingTitles.contains(sampleData.title) {
            // Add a variation number if duplicate exists
            var counter = 2
            while existingTitles.contains("\(sampleData.title) (\(counter))") {
                counter += 1
            }
            finalTitle = "\(sampleData.title) (\(counter))"
        }

        // Create a NEW Recipe object (don't reuse the sample)
        let recipe = Recipe(
            title: finalTitle,
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
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                if let image = UIImage(data: data) {
                    let fileName = try await imageStorageService.saveImage(image, recipeId: recipe.id)
                    recipe.imageFileName = fileName
                }
            } catch {
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

        // Add to the specified collection
        await MainActor.run {
            recipe.collections = [addToCollection]
            try? modelContext.save()
        }
    }

    // MARK: - Delete Actions

    private func deleteCollectionKeepingRecipes() async {
        // Prevent deletion of system collections
        guard !collection.isSystemCollection else {
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            await MainActor.run {
                toastManager.error(title: "Cannot delete", message: "System collections cannot be deleted")
            }
            return
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        // Remove collection-recipe relationships
        if let recipes = collection.recipes {
            for recipe in recipes {
                recipe.collections?.removeAll { $0.id == collection.id }
            }
        }

        // Create tombstone BEFORE deleting (so we remember this was deleted)
        let collectionId = collection.id
        await MainActor.run {
            let tombstone = DeletedCollectionRecord(collectionId: collectionId)
            modelContext.insert(tombstone)
            Log.info("Created deletion tombstone", category: .collections, metadata: [
                "collectionId": collectionId.uuidString
            ])
        }

        // Delete collection
        await MainActor.run {
            modelContext.delete(collection)
            try? modelContext.save()
        }

        // Firebase sync
        let backendConfig = ServiceContainer.shared.resolve(BackendConfig.self)
        if backendConfig.isFirebaseActive {
            let firebaseSync = ServiceContainer.shared.resolve((any FirebaseSyncServiceProtocol).self)
            do {
                try await firebaseSync.deleteCollection(collectionId)

                // Mark tombstone as synced to Firebase
                await MainActor.run {
                    let descriptor = FetchDescriptor<DeletedCollectionRecord>(
                        predicate: #Predicate { record in
                            record.collectionId == collectionId
                        }
                    )
                    if let tombstone = try? modelContext.fetch(descriptor).first {
                        tombstone.syncedToFirebase = true
                        try? modelContext.save()
                        Log.info("Marked tombstone as synced to Firebase", category: .collections, metadata: [
                            "collectionId": collectionId.uuidString
                        ])
                    }
                }
            } catch {
                Log.error("Failed to delete collection from Firebase", category: .firebase, error: error, metadata: [
                    "collectionId": collectionId.uuidString
                ])
                // Don't throw - tombstone still prevents recreation
            }
        }

        // Success feedback
        let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
        await MainActor.run {
            toastManager.success(title: "Collection deleted", message: "Recipes remain in your library")
            generator.notificationOccurred(.success)
        }
    }

    private func deleteCollectionAndRecipes() async {
        // Prevent deletion of system collections
        guard !collection.isSystemCollection else {
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            await MainActor.run {
                toastManager.error(title: "Cannot delete", message: "System collections cannot be deleted")
            }
            return
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        do {
            let recipesToDelete = collection.recipes ?? []
            let recipeCount = recipesToDelete.count

            // Delete all recipes first
            for recipe in recipesToDelete {
                await MainActor.run {
                    modelContext.delete(recipe)
                }
            }

            // Create tombstone BEFORE deleting (so we remember this was deleted)
            let collectionId = collection.id
            await MainActor.run {
                let tombstone = DeletedCollectionRecord(collectionId: collectionId)
                modelContext.insert(tombstone)
                Log.info("Created deletion tombstone", category: .collections, metadata: [
                    "collectionId": collectionId.uuidString
                ])
            }

            // Delete collection
            await MainActor.run {
                modelContext.delete(collection)
                try? modelContext.save()
            }

            // Firebase sync
            let backendConfig = ServiceContainer.shared.resolve(BackendConfig.self)
            if backendConfig.isFirebaseActive {
                let firebaseSync = ServiceContainer.shared.resolve((any FirebaseSyncServiceProtocol).self)

                // Delete recipes from Firebase
                for recipe in recipesToDelete {
                    try await firebaseSync.deleteRecipe(recipe.id)
                }

                // Delete collection from Firebase
                do {
                    try await firebaseSync.deleteCollection(collectionId)

                    // Mark tombstone as synced to Firebase
                    await MainActor.run {
                        let descriptor = FetchDescriptor<DeletedCollectionRecord>(
                            predicate: #Predicate { record in
                                record.collectionId == collectionId
                            }
                        )
                        if let tombstone = try? modelContext.fetch(descriptor).first {
                            tombstone.syncedToFirebase = true
                            try? modelContext.save()
                            Log.info("Marked tombstone as synced to Firebase", category: .collections, metadata: [
                                "collectionId": collectionId.uuidString
                            ])
                        }
                    }
                } catch {
                    Log.error("Failed to delete collection from Firebase", category: .firebase, error: error, metadata: [
                        "collectionId": collectionId.uuidString
                    ])
                    // Don't throw - tombstone still prevents recreation
                }
            }

            // Success feedback
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            await MainActor.run {
                toastManager.success(
                    title: "Collection and \(recipeCount) recipe\(recipeCount == 1 ? "" : "s") deleted"
                )
                generator.notificationOccurred(.success)
            }

        } catch {
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            await MainActor.run {
                toastManager.error(title: "Failed to delete", message: error.localizedDescription)
                generator.notificationOccurred(.error)
            }
        }
    }

    // MARK: - Recipe Context Menu Actions

    private func toggleFavorite(_ recipe: Recipe) {
        recipe.isFavorite.toggle()
        recipe.lastModified = Date()

        do {
            try modelContext.save()

            // Sync to Firebase if active
            let backendConfig = ServiceContainer.shared.resolve(BackendConfig.self)
            if backendConfig.isFirebaseActive {
                Task {
                    do {
                        let firebaseSync = ServiceContainer.shared.resolve((any FirebaseSyncServiceProtocol).self)
                        try await firebaseSync.uploadRecipe(recipe)
                    } catch {
                        Log.error("Failed to sync favorite status", category: .sync, error: error)
                    }
                }
            }

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            let message = recipe.isFavorite ? "Added to favorites" : "Removed from favorites"
            toastManager.success(title: message)
        } catch {
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            toastManager.error(
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

                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()

                let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                toastManager.success(title: "Removed from shopping list")
            } catch {
                let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                toastManager.error(
                    title: "Failed to update shopping list",
                    message: error.localizedDescription
                )
            }
        } else {
            // Add to shopping list
            let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: recipe.parsedServingCount)
            modelContext.insert(cartRecipe)
            recipe.isInShoppingList = true

            do {
                try modelContext.save()

                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()

                let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                toastManager.success(title: "Added to shopping list")
            } catch {
                let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                toastManager.error(
                    title: "Failed to update shopping list",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func removeRecipeFromCollection(_ recipe: Recipe) {
        guard !collection.isSystemCollection else { return }

        recipe.collections?.removeAll { $0.id == collection.id }

        do {
            try modelContext.save()

            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            toastManager.success(title: "Removed from \(collection.name)")
        } catch {
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            toastManager.error(
                title: "Failed to remove",
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.warmGray)

            Text(emptyStateTitle)
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(emptyStateMessage)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HeirloomSpacing.xl)

            if let actionTitle = emptyStateActionTitle {
                Button {
                    handleEmptyStateAction()
                } label: {
                    Text(actionTitle)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, HeirloomSpacing.lg)
                        .padding(.vertical, HeirloomSpacing.md)
                        .background(HeirloomColors.tomato)
                        .cornerRadius(12)
                }
            }
        }
        .padding(.vertical, HeirloomSpacing.xxl)
    }

    private var emptyStateIcon: String {
        switch collection.type {
        case .theme:
            return "sparkles"
        case .fromFriends:
            return "person.2"
        case .videoImports:
            return "video"
        case .webImports:
            return "link"
        case .photoImports:
            return "photo"
        case .cookbook:
            return "book.closed"
        default:
            return "rectangle.stack"
        }
    }

    private var emptyStateTitle: String {
        switch collection.type {
        case .theme:
            return "Recipes Coming Soon"
        case .fromFriends:
            return "No Shared Recipes Yet"
        case .videoImports:
            return "No Video Imports Yet"
        case .webImports:
            return "No Web Imports Yet"
        case .photoImports:
            return "No Photo Imports Yet"
        case .cookbook:
            return "No Cookbook Recipes Yet"
        default:
            return "No Recipes Yet"
        }
    }

    private var emptyStateMessage: String {
        switch collection.type {
        case .theme:
            return "New \(collection.name) recipes unlock every few days during your trial. Check back soon!"
        case .fromFriends:
            return "When friends share recipes with you, they'll appear here. Share the app with friends to start collecting!"
        case .videoImports:
            return "Recipes from video transcriptions will appear here. Import a cooking video to get started."
        case .webImports:
            return "Recipes you save from websites will appear here. Try pasting a recipe URL to get started."
        case .photoImports:
            return "Recipes from photos (recipe cards, screenshots, handwritten recipes) will appear here. Snap a photo to get started."
        case .cookbook:
            return "Recipes from multi-page cookbook scans will appear here. Use the cookbook scanner to get started."
        default:
            return "Add recipes to this collection to see them here."
        }
    }

    private var emptyStateActionTitle: String? {
        switch collection.type {
        case .fromFriends:
            return "Share App"
        case .videoImports:
            return "Import Video"
        case .webImports:
            return "Import from Web"
        case .photoImports:
            return "Import Photo"
        case .cookbook:
            return "Scan Cookbook"
        case .userCreated:
            return "Add Recipe"
        default:
            return nil
        }
    }

    private func handleEmptyStateAction() {
        switch collection.type {
        case .fromFriends:
            // TODO: Implement share sheet for app
            break
        case .videoImports:
            tabCoordinator.willCreateRecipe(from: .collectionDetail)
            showVideoImport = true
        case .webImports:
            tabCoordinator.willCreateRecipe(from: .collectionDetail)
            showImportRecipe = true
        case .photoImports:
            // TODO: Implement single-photo OCR import
            tabCoordinator.willCreateRecipe(from: .collectionDetail)
            showImportRecipe = true  // For now, use URL import (can add photo picker later)
        case .cookbook:
            tabCoordinator.willCreateRecipe(from: .collectionDetail)
            showCookbookScanner = true
        case .userCreated:
            tabCoordinator.willCreateRecipe(from: .collectionDetail)
            showRecipeGenerator = true
        default:
            break
        }
    }

    // MARK: - Add Recipe Nudge

    private var addRecipeNudge: some View {
        VStack(spacing: 0) {
            // Divider with text
            HStack {
                Rectangle()
                    .fill(HeirloomColors.warmGray.opacity(0.2))
                    .frame(height: 1)

                Text(UXCopy.Nudges.addYourOwn)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .padding(.horizontal, HeirloomSpacing.sm)

                Rectangle()
                    .fill(HeirloomColors.warmGray.opacity(0.2))
                    .frame(height: 1)
            }
            .padding(.vertical, HeirloomSpacing.lg)

            // Nudge card
            Button {
                showAddRecipeMenu = true
            } label: {
                HStack(spacing: HeirloomSpacing.md) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(HeirloomColors.tomato.opacity(0.1))
                            .frame(width: 48, height: 48)

                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(HeirloomColors.tomato)
                    }

                    // Text
                    VStack(alignment: .leading, spacing: 4) {
                        Text(UXCopy.Nudges.addRecipeTitle)
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)

                        Text(UXCopy.Nudges.addRecipeSubtitle(themeName: collection.name))
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .lineLimit(2)
                    }

                    Spacer()

                    // Arrow
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HeirloomColors.tomato)
                }
                .padding(HeirloomSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(HeirloomColors.cardBackground)
                        .shadow(color: HeirloomColors.tomato.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(HeirloomColors.tomato.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, HeirloomSpacing.md)
    }
}

#Preview {
    @Previewable @State var collection = RecipeCollection(
        name: "Presidential Pantry",
        description: "Recipes from First Families",
        iconName: "building.columns.fill",
        color: "#8B0000",
        isSystemCollection: false,
        isAllRecipes: false,
        collectionType: .theme
    )

    NavigationStack {
        CollectionDetailView(collection: collection)
            .modelContainer(for: [Recipe.self, RecipeCollection.self])
    }
}
