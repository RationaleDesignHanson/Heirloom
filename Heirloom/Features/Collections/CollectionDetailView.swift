import SwiftUI
import SwiftData

/// Detail view showing recipes within a collection
/// Note: Uses VideoImportMode enum defined in RecipeListView.swift
struct CollectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationService: FirebaseNotificationService
    @EnvironmentObject private var tabCoordinator: TabNavigationCoordinator
    let collection: RecipeCollection

    @State private var showAddRecipe = false
    @State private var showImportRecipe = false
    @State private var showBulkImport = false
    @State private var showCookbookScanner = false
    @State private var showVideoImport = false
    @State private var showDeleteConfirmation = false
    @State private var unlockTracker: HeritageUnlockTracker?

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
        // Fetch all recipes (will filter in computed property)
        _allRecipes = Query(sort: \Recipe.title)
    }

    // Recipes in this collection
    var recipes: [Recipe] {
        // Special handling for "All Recipes" collection - show all recipes
        if collection.isAllRecipes {
            return allRecipes
        }

        let collectionRecipes = allRecipes.filter { recipe in
            recipe.collections?.contains(where: { $0.id == collection.id }) ?? false
        }

        // Filter out locked heritage recipes
        if collection.isHeritageCollection {
            guard let tracker = unlockTracker else { return collectionRecipes }
            return collectionRecipes.filter { tracker.isUnlocked($0) }
        }

        return collectionRecipes
    }

    // Get Recipe objects for selected IDs
    private func getSelectedRecipes() -> [Recipe] {
        return allRecipes.filter { selectedRecipeIDs.contains($0.id) }
    }

    // Available collections for the picker (excludes "All Recipes" and heritage collections)
    private var availableCollectionsForPicker: [RecipeCollection] {
        return allCollections.filter { !$0.isAllRecipes && !$0.isHeritageCollection }
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
                        GridItem(.flexible(), spacing: HeirloomSpacing.gridSpacing),
                        GridItem(.flexible(), spacing: HeirloomSpacing.gridSpacing)
                    ], spacing: HeirloomSpacing.gridSpacing) {
                        ForEach(recipes, id: \.id) { recipe in
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
                            }
                        }
                    }
                    .padding(.horizontal, HeirloomSpacing.md)
                }
            }
            .padding(.vertical, HeirloomSpacing.lg)
        }
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
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
                        onAddRecipe: {
                            tabCoordinator.willCreateRecipe(from: .collectionDetail)
                            showAddRecipe = true
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
                        onAddNormalSample: addNormalSampleRecipe,
                        onAddHeritageSample: addHeritageSampleRecipe
                    )
                }
            }

            // Delete button for non-system collections
            if !collection.isSystemCollection {
                ToolbarItem(placement: .secondaryAction) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete Collection")
                }
            }
        }
        .sheet(isPresented: $showAddRecipe) {
            RecipeEditorView()
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
            if unlockTracker == nil {
                unlockTracker = ServiceContainer.shared.resolve(HeritageUnlockTracker.self)
            }
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

    // MARK: - Heritage Recipe JSON Model

    private struct HeritageRecipeJSON: Codable {
        let id: String
        let title: String
        let heritageCollectionId: String
        let servings: String?
        let prepTime: String?
        let cookTime: String?
        let ingredients: [String]
        let instructions: [String]
        let historicalText: String?
        let historicalContext: String?
        let sourceAttribution: String?
        let sourceDate: String?
        let sourceURL: String?
        let imageURL: String?
        let tags: [String]?
    }

    // MARK: - Actions

    private func addNormalSampleRecipe() {
        // Pick any recipe from the full library
        guard let sampleRecipe = SampleRecipeLibrary.all.randomElement() else { return }

        Task {
            await createSampleRecipe(from: sampleRecipe, addToCollection: collection)
        }
    }

    private func addHeritageSampleRecipe() {
        Task {
            await createHeritageRecipe(addToCollection: collection)
        }
    }

    private func createHeritageRecipe(addToCollection: RecipeCollection) async {
        // Load heritage recipes from JSON
        guard let url = Bundle.main.url(forResource: "heritage-recipes", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return
        }

        struct HeritageRecipeData: Codable {
            let recipes: [HeritageRecipeJSON]
        }

        guard let heritageData = try? JSONDecoder().decode(HeritageRecipeData.self, from: data) else {
            return
        }

        // Get existing recipe titles to avoid duplicates
        let existingTitles = recipes.map { $0.title }

        // Filter out recipes that already exist
        let availableRecipes = heritageData.recipes.filter { !existingTitles.contains($0.title) }

        // Pick a random recipe that doesn't already exist
        guard let heritageRecipe = availableRecipes.randomElement() else {
            // If all recipes exist, pick any and add a number
            guard let heritageRecipe = heritageData.recipes.randomElement() else { return }
            await createHeritageRecipeFromJSON(heritageRecipe, addToCollection: addToCollection, titleExists: true)
            return
        }

        await createHeritageRecipeFromJSON(heritageRecipe, addToCollection: addToCollection, titleExists: false)
    }

    private func createHeritageRecipeFromJSON(_ json: HeritageRecipeJSON, addToCollection: RecipeCollection, titleExists: Bool) async {
        let imageStorageService = ServiceContainer.shared.resolve(ImageStorageService.self)

        // Create unique title if needed
        var finalTitle = json.title
        if titleExists {
            let existingTitles = recipes.map { $0.title }
            var counter = 2
            while existingTitles.contains("\(json.title) (\(counter))") {
                counter += 1
            }
            finalTitle = "\(json.title) (\(counter))"
        }

        // Create recipe
        let recipe = Recipe(
            title: finalTitle,
            sourceType: .heritage,
            sourceURL: json.sourceURL,
            instructions: json.instructions,
            servings: json.servings,
            prepTime: json.prepTime,
            cookTime: json.cookTime
        )

        recipe.sourceDate = json.sourceDate
        recipe.historicalContext = json.historicalContext
        recipe.notes = json.historicalText

        // Download and save image if available
        if let imageURLString = json.imageURL, let imageURL = URL(string: imageURLString) {
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                if let image = UIImage(data: data) {
                    let fileName = try await imageStorageService.saveImage(image, recipeId: recipe.id)
                    recipe.imageFileName = fileName
                }
            } catch {
                // Continue without image
            }
        }

        // Insert recipe
        await MainActor.run {
            modelContext.insert(recipe)
        }

        // Create and insert ingredients
        var ingredients: [Ingredient] = []
        for (index, text) in json.ingredients.enumerated() {
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

        // Add to collection
        await MainActor.run {
            recipe.collections = [addToCollection]
            try? modelContext.save()
        }
    }

    private func createSampleRecipe(from sampleRecipe: SampleRecipeData, addToCollection: RecipeCollection, isHeritage: Bool = false) async {
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
            sourceType: isHeritage ? .heritage : (sampleData.sourceType ?? .manual),
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

        do {
            // Remove collection-recipe relationships
            if let recipes = collection.recipes {
                for recipe in recipes {
                    recipe.collections?.removeAll { $0.id == collection.id }
                }
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
                try await firebaseSync.deleteCollection(collection.id)
            }

            // Success feedback
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            await MainActor.run {
                toastManager.success(title: "Collection deleted", message: "Recipes remain in your library")
                generator.notificationOccurred(.success)
            }

        } catch {
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            await MainActor.run {
                toastManager.error(title: "Failed to delete collection", message: error.localizedDescription)
                generator.notificationOccurred(.error)
            }
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
                try await firebaseSync.deleteCollection(collection.id)
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
