import SwiftUI
import SwiftData

/// Mode for video import - determines processing approach
enum VideoImportMode: String, CaseIterable, Identifiable {
    case withInstructions = "Video with Instructions"
    case withoutInstructions = "Video without Instructions"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .withInstructions: return "video.fill"
        case .withoutInstructions: return "eye.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .withInstructions:
            return "Narration or on-screen text guides you through"
        case .withoutInstructions:
            return "ASMR or silent videos - watch & infer the recipe"
        }
    }

    var color: Color {
        switch self {
        case .withInstructions: return .blue
        case .withoutInstructions: return .purple
        }
    }
}

/// Bottom sheet for selecting video import mode
struct VideoImportModeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onModeSelected: (VideoImportMode) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Choose Video Type")
                        .font(.title2.bold())

                    Text("Select how to process your cooking video")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                // Mode options
                VStack(spacing: 16) {
                    ForEach(VideoImportMode.allCases) { mode in
                        ModeCard(mode: mode) {
                            onModeSelected(mode)
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Video to Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct ModeCard: View {
    let mode: VideoImportMode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(mode.color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: mode.icon)
                        .font(.title2)
                        .foregroundStyle(mode.color)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(mode.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct RecipeListView: View {
    @Query(sort: \Recipe.dateAdded, order: .reverse)
    private var recipes: [Recipe]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.firebaseSync) private var firebaseSync
    @Environment(\.firebaseLineage) private var firebaseLineage
    @EnvironmentObject private var tabCoordinator: TabNavigationCoordinator

    // Using concrete type for image storage
    private var imageStorageService: ImageStorageService { ServiceContainer.shared.resolve(ImageStorageService.self) }

    // Using concrete type for toast notifications
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }
    private var milestoneManager: MilestoneManager { ServiceContainer.shared.resolve(MilestoneManager.self) }

    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }
    private var crdtMergeEngine: CRDTMergeEngine { ServiceContainer.shared.resolve(CRDTMergeEngine.self) }
    private var backendConfig: BackendConfig { ServiceContainer.shared.resolve(BackendConfig.self) }

    @State private var searchText = ""
    @State private var showAddRecipe = false
    @State private var showImportRecipe = false
    @State private var showBulkImport = false
    @State private var showCookbookScanner = false
    @State private var showVideoImport = false
    @State private var showASMRVideoImport = false
    @State private var showVideoImportModeSheet = false
    @State private var selectedImportMode: VideoImportMode?
    @State private var showCreateCollection = false
    @State private var showFilters = false
    @State private var filters = RecipeFilters()
    @State private var recipeToDelete: Recipe?
    @State private var showDeleteConfirmation = false
    @StateObject private var undoService = ServiceContainer.shared.resolve(UndoService.self)
    @State private var isSyncing = false

    // Multi-select mode
    @State private var isSelectionMode = false
    @State private var selectedRecipeIds: Set<UUID> = []
    @State private var showBatchDeleteConfirmation = false
    @State private var showCollectionPicker = false

    // Single recipe collection picker
    @State private var recipeForCollectionPicker: Recipe?

    // Conflict resolution
    @State private var showConflictResolution = false
    @State private var conflictRecipeCRDT: RecipeCRDT?
    @State private var conflictList: [DetailedConflict] = []

    // Coach mark
    @State private var showToolbarCoachMark = false

    var body: some View {
        NavigationStack {
            mainContent
                .toolbar {
                    toolbarLeading
                    toolbarActions
                }
                .navigationDestination(for: Recipe.self) { recipe in
                    RecipeDetailView(recipe: recipe)
                }
                .modifier(sheetModifiers)
                .sheet(isPresented: $showVideoImportModeSheet) {
                    VideoImportModeSheet { mode in
                        selectedImportMode = mode
                        // Show appropriate import view based on mode
                        switch mode {
                        case .withInstructions:
                            showVideoImport = true
                        case .withoutInstructions:
                            showASMRVideoImport = true
                        }
                    }
                }
                .onAppear {
                    configureUndoService()
                    // Show toolbar coach mark on first visit
                    if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasSeenToolbarCoachMark) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showToolbarCoachMark = true
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .recipeConflictsDetected), perform: handleConflictNotification)
                .overlay(alignment: .bottom) {
                    selectionOverlay
                }
                .overlay {
                    if showToolbarCoachMark {
                        CoachMarkView(
                            message: "Add a recipe from anywhere — URL, photo, or type it in. Don't have one? Try our sample →",
                            onDismiss: {
                                showToolbarCoachMark = false
                                UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasSeenToolbarCoachMark)
                            }
                        )
                    }
                }
        }
    }

    // MARK: - View Builders

    @ViewBuilder
    private var mainContent: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Video processing banner at top
                    VideoProcessingBottomBanner()
                        .padding(.bottom, 8)
                        .zIndex(1)

                    // Main content
                    contentSwitcher(geometry: geometry)
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
    }

    @ViewBuilder
    private func contentSwitcher(geometry: GeometryProxy) -> some View {
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

    @ToolbarContentBuilder
    private var toolbarLeading: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            RecipeListToolbarLeading(
                isSelectionMode: isSelectionMode,
                isSyncing: isSyncing,
                showFilters: $showFilters,
                filters: filters,
                onCancelSelection: exitSelectionMode
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarActions: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            RecipeListToolbarActions(
                isSelectionMode: isSelectionMode,
                selectedCount: selectedRecipeIds.count,
                filteredCount: filteredRecipes.count,
                onSelectAllToggle: selectAllToggle,
                onAddRecipe: {
                    tabCoordinator.willCreateRecipe(from: .recipesTab)
                    showAddRecipe = true
                },
                onImportRecipe: {
                    tabCoordinator.willCreateRecipe(from: .recipesTab)
                    showImportRecipe = true
                },
                onBulkImport: {
                    tabCoordinator.willCreateRecipe(from: .recipesTab)
                    showBulkImport = true
                },
                onCookbookScanner: {
                    tabCoordinator.willCreateRecipe(from: .recipesTab)
                    showCookbookScanner = true
                },
                onVideoImport: {
                    tabCoordinator.willCreateRecipe(from: .recipesTab)
                    showVideoImportModeSheet = true
                },
                onAddCollection: {
                    tabCoordinator.willCreateCollection(from: .recipesTab)
                    showCreateCollection = true
                },
                onAddNormalSample: addSampleRecipe,
                onAddHeritageSample: addSampleRecipe
            )
        }
    }

    private var sheetModifiers: RecipeSheetModifiers {
        RecipeSheetModifiers(
            showAddRecipe: $showAddRecipe,
            showImportRecipe: $showImportRecipe,
            showBulkImport: $showBulkImport,
            showCookbookScanner: $showCookbookScanner,
            showVideoImport: $showVideoImport,
            showASMRVideoImport: $showASMRVideoImport,
            showCreateCollection: $showCreateCollection,
            showFilters: $showFilters,
            filters: $filters,
            showDeleteConfirmation: $showDeleteConfirmation,
            recipeToDelete: recipeToDelete,
            onDeleteRecipe: deleteRecipe,
            showBatchDeleteConfirmation: $showBatchDeleteConfirmation,
            selectedRecipeIds: selectedRecipeIds,
            onBatchDelete: batchDeleteRecipes,
            showCollectionPicker: $showCollectionPicker,
            onExitSelection: exitSelectionMode,
            recipeForCollectionPicker: $recipeForCollectionPicker,
            showConflictResolution: $showConflictResolution,
            conflictResolutionSheet: AnyView(conflictResolutionSheet)
        )
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        if isSelectionMode && !selectedRecipeIds.isEmpty {
            SelectionActionBar(
                selectedCount: selectedRecipeIds.count,
                onDelete: { showBatchDeleteConfirmation = true },
                onAddToCollection: { showCollectionPicker = true }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelectionMode)
        }
    }

    private func configureUndoService() {
        undoService.configure(modelContext: modelContext)
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
                Group {
                    if isSelectionMode {
                        RecipeCardView(
                            recipe: recipe,
                            isSelectionMode: true,
                            isSelected: selectedRecipeIds.contains(recipe.id)
                        )
                        .onTapGesture {
                            toggleSelection(for: recipe.id)
                        }
                    } else {
                        NavigationLink(value: recipe) {
                            RecipeCardView(recipe: recipe)
                        }
                        .buttonStyle(.plain)
                        .onLongPressGesture(minimumDuration: 0.5) {
                            enterSelectionMode(with: recipe.id)
                        }
                    }
                }
                .id(recipe.id)
                .accessibilityLabel("\(recipe.title), \(recipe.sourceDisplayName)")
                .accessibilityHint(isSelectionMode ? (selectedRecipeIds.contains(recipe.id) ? "Deselect recipe" : "Select recipe") : "Opens recipe details")
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

                    Button {
                        recipeForCollectionPicker = recipe
                    } label: {
                        Label("Add to Collection", systemImage: "folder.badge.plus")
                    }
                    .accessibilityLabel("Add \(recipe.title) to collection")

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

    // MARK: - Selection Action Toolbar
    private var selectionActionToolbar: some View {
        HStack(spacing: 16) {
            Button {
                showBatchDeleteConfirmation = true
            } label: {
                Label("Delete (\(selectedRecipeIds.count))", systemImage: "trash")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .cornerRadius(10)
            }
            .accessibilityLabel("Delete \(selectedRecipeIds.count) selected recipes")

            Button {
                showCollectionPicker = true
            } label: {
                Label("Add to Collection", systemImage: "folder.badge.plus")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(10)
            }
            .accessibilityLabel("Add \(selectedRecipeIds.count) recipes to collection")
        }
        .padding(.horizontal, HeirloomSpacing.md)
        .padding(.vertical, HeirloomSpacing.sm)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelectionMode)
    }

    // MARK: - Actions

    private func refreshRecipes() async {
        // Track analytics
        await MainActor.run {
            isSyncing = true
            analytics.track(event: .featureUsed, properties: [
                "feature": "pull_to_refresh",
                "context": "recipe_list"
            ])
        }

        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Trigger Firebase sync to download and merge changes
        if backendConfig.isFirebaseActive {
            do {
                try await firebaseSync.syncChangesWithCRDT()
                Log.info("Pull-to-refresh sync complete", category: .sync)

                // Success haptic
                let successGenerator = UINotificationFeedbackGenerator()
                successGenerator.notificationOccurred(.success)
            } catch {
                // Silently skip if user isn't authenticated - this is expected behavior
                // when the user hasn't signed in yet
                if case FirebaseSyncService.SyncError.notAuthenticated = error {
                    Log.info("Pull-to-refresh skipped: user not signed in", category: .sync)
                    // No error haptic - just silently complete the refresh
                } else {
                    // Show error feedback for actual sync/network errors
                    Log.error("Pull-to-refresh sync failed", category: .sync, error: error)

                    // Error haptic
                    let errorGenerator = UINotificationFeedbackGenerator()
                    errorGenerator.notificationOccurred(.error)
                }
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
        if backendConfig.isFirebaseActive {
            Task {
                do {
                    try await firebaseSync.deleteRecipe(recipe.id)
                    Log.info("Recipe deleted from Firebase", category: .firebase, metadata: ["recipeId": recipe.id.uuidString])
                } catch {
                    Log.error("Failed to delete recipe from Firebase", category: .firebase, error: error, metadata: ["recipeId": recipe.id.uuidString])
                }
            }
        }

        // Use UndoService for soft delete with undo capability
        undoService.deleteRecipe(recipe, context: modelContext)

        // Show undo toast
        toastManager.showUndoToast(for: undoService.pendingUndos.last!) {
            // Undo action
            if let undoItem = undoService.pendingUndos.last {
                undoService.undoDelete(undoItem)

                // Success haptic for undo
                let successGenerator = UINotificationFeedbackGenerator()
                successGenerator.notificationOccurred(.success)

                toastManager.success(title: "Recipe restored")
            }
        }
    }

    // MARK: - Selection Management

    private func enterSelectionMode(with recipeId: UUID) {
        withAnimation {
            isSelectionMode = true
            selectedRecipeIds.insert(recipeId)
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func exitSelectionMode() {
        withAnimation {
            isSelectionMode = false
            selectedRecipeIds.removeAll()
        }
    }

    private func toggleSelection(for recipeId: UUID) {
        withAnimation {
            if selectedRecipeIds.contains(recipeId) {
                selectedRecipeIds.remove(recipeId)
            } else {
                // Enforce 50 recipe limit
                if selectedRecipeIds.count >= 50 {
                    toastManager.error(title: "Selection limit reached", message: "You can select up to 50 recipes at once")
                    return
                }
                selectedRecipeIds.insert(recipeId)
            }
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func selectAllToggle() {
        withAnimation {
            if selectedRecipeIds.count == filteredRecipes.count {
                // Deselect all
                selectedRecipeIds.removeAll()
            } else {
                // Select all (up to 50)
                let recipesToSelect = filteredRecipes.prefix(50)
                selectedRecipeIds = Set(recipesToSelect.map { $0.id })

                if filteredRecipes.count > 50 {
                    toastManager.info(title: "Selected first 50 recipes", message: "Maximum selection limit is 50 recipes")
                }
            }
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func batchDeleteRecipes() {
        // Get recipes to delete
        let recipesToDelete = recipes.filter { selectedRecipeIds.contains($0.id) }
        let count = recipesToDelete.count

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        // Delete from Firebase if active
        if backendConfig.isFirebaseActive {
            Task {
                for recipe in recipesToDelete {
                    do {
                        try await firebaseSync.deleteRecipe(recipe.id)
                        Log.info("Recipe deleted from Firebase", category: .firebase, metadata: ["recipeId": recipe.id.uuidString])
                    } catch {
                        Log.error("Failed to delete recipe from Firebase", category: .firebase, error: error, metadata: ["recipeId": recipe.id.uuidString])
                    }
                }
            }
        }

        // Delete each recipe using UndoService
        for recipe in recipesToDelete {
            undoService.deleteRecipe(recipe, context: modelContext)
        }

        // Show undo toast for batch delete
        if let lastUndo = undoService.pendingUndos.last {
            toastManager.showUndoToast(for: lastUndo) {
                // Undo all deletions
                if let undoItem = undoService.pendingUndos.last {
                    undoService.undoDelete(undoItem)

                    // Success haptic for undo
                    let successGenerator = UINotificationFeedbackGenerator()
                    successGenerator.notificationOccurred(.success)

                    toastManager.success(title: "Recipes restored")
                }
            }
        }

        // Exit selection mode
        exitSelectionMode()

        Log.info("Batch deleted \(count) recipes", category: .ui)
    }

    private func toggleFavorite(_ recipe: Recipe) {
        recipe.isFavorite.toggle()
        recipe.lastModified = Date()

        Log.info("Toggling favorite", category: .ui, metadata: ["title": recipe.title, "isFavorite": recipe.isFavorite])
        Log.debug("Firebase backend active", category: .ui, metadata: ["isActive": backendConfig.isFirebaseActive])

        do {
            try modelContext.save()
            Log.debug("Local save successful", category: .database)

            // Sync favorite status to Firebase
            if backendConfig.isFirebaseActive {
                Log.debug("Firebase active, starting upload", category: .sync)
                Task {
                    do {
                        try await firebaseSync.uploadRecipe(recipe)
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
            toastManager.success(title: message)
        } catch {
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

                // Shopping cart is local-only (no Firebase sync needed for ephemeral data)

                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()

                toastManager.success(title: "Removed from shopping list")
            } catch {
                toastManager.error(
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

                toastManager.success(title: "Added to shopping list")

                // Check shopping list milestone
                checkShoppingListMilestone()
            } catch {
                toastManager.error(
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
                    let fileName = try await imageStorageService.saveImage(image, recipeId: recipe.id)
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
            if backendConfig.isFirebaseActive {
                do {
                    try await firebaseSync.uploadRecipe(recipe)
                    Log.info("Sample recipe synced to Firebase", category: .sync, metadata: ["recipeId": recipe.id.uuidString])

                    // Create root lineage for sample recipe
                    do {
                        try await firebaseLineage.createRootLineage(
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
                toastManager.success(
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
                toastManager.error(
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
            milestoneManager.checkFirstRecipeAdded()
        }

        // Check milestone thresholds
        if recipeCount == 10 {
            milestoneManager.checkTenRecipes()
        } else if recipeCount == 50 {
            milestoneManager.checkFiftyRecipes()
        }
    }

    private func checkShoppingListMilestone() {
        // Count total shopping list recipes
        let descriptor = FetchDescriptor<ShoppingCartRecipe>()
        if let cartRecipes = try? modelContext.fetch(descriptor) {
            // Check first shopping list
            if cartRecipes.count == 1 {
                milestoneManager.checkFirstShoppingList()
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
    @Environment(\.firebaseSync) private var firebaseSync

    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }
    private var crdtMergeEngine: CRDTMergeEngine { ServiceContainer.shared.resolve(CRDTMergeEngine.self) }
    private var backendConfig: BackendConfig { ServiceContainer.shared.resolve(BackendConfig.self) }

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
        crdtMergeEngine.applyUserResolution(resolutionsList, to: recipeCRDT)

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
            if backendConfig.isFirebaseActive {
                Log.debug("Uploading resolved recipe to Firebase", category: .sync)
                try await firebaseSync.uploadRecipe(recipeCRDT.recipe)
                Log.info("Resolved recipe synced to Firebase", category: .sync)
            }

            // Show success
            toastManager.success(
                title: "Recipe Merged",
                message: "All conflicts resolved successfully"
            )

            Log.info("Conflict resolution complete", category: .crdt)
            dismiss()
        } catch {
            Log.error("Failed to save conflict resolution", category: .database, error: error)
            // Show error
            toastManager.error(
                title: "Failed to Save",
                message: error.localizedDescription
            )
        }
    }
}

// MARK: - Recipe Card View
struct RecipeCardView: View {
    let recipe: Recipe
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
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

                // Language badge (bottom right overlay) - show for non-English recipes
                if let language = recipe.sourceLanguage, language != "en" {
                    Text(languageFlag(for: language))
                        .font(.title3)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(.white)
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        )
                        .padding(8)
                        .accessibilityLabel("Recipe in \(languageName(for: language))")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }

                // Selection checkbox (top right overlay)
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? HeirloomColors.tomato : HeirloomColors.warmGray)
                        .font(.title2)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(.white)
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        )
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(HeirloomFonts.subheadline)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .frame(height: 40, alignment: .topLeading)

                // Consolidated: Source, Times Cooked, and Generation Badge on one line
                HStack(spacing: 6) {
                    // Creator name link for video recipes
                    if recipe.sourceType == .video, let profileURL = recipe.creatorProfileURL {
                        Link(destination: profileURL) {
                            Text(recipe.sourceDisplayName)
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.tomato)
                                .underline()
                                .lineLimit(1)
                        }
                    } else {
                        Text(recipe.sourceDisplayName)
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .lineLimit(1)
                    }

                    if recipe.timesCooked > 0 {
                        Text("•")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)

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
            .accessibilityElement(children: .combine)
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
        .overlay(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .stroke(HeirloomColors.tomato, lineWidth: 2)
                .opacity(isSelected ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
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

    // MARK: - Language Badge Helpers

    private func languageFlag(for languageCode: String) -> String {
        switch languageCode {
        case "fr": return "🇫🇷"
        case "es": return "🇪🇸"
        case "de": return "🇩🇪"
        case "ja": return "🇯🇵"
        case "zh": return "🇨🇳"
        case "ko": return "🇰🇷"
        default: return "🌍"
        }
    }

    private func languageName(for languageCode: String) -> String {
        switch languageCode {
        case "fr": return "French"
        case "es": return "Spanish"
        case "de": return "German"
        case "ja": return "Japanese"
        case "zh": return "Chinese"
        case "ko": return "Korean"
        default: return languageCode.uppercased()
        }
    }
}

#Preview {
    RecipeListView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
