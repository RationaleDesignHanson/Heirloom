import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseFirestore

/// Main Collections tab view showing heritage and user collections
struct CollectionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.firebaseAuth) private var firebaseAuth
    @EnvironmentObject private var notificationService: FirebaseNotificationService
    @EnvironmentObject private var tabCoordinator: TabNavigationCoordinator
    @EnvironmentObject private var themeUnlockTracker: ThemeUnlockTracker
    @EnvironmentObject private var syncService: FirebaseSyncService
    @ObservedObject private var screenRecordingService = ScreenRecordingResetService.shared
    @Query(sort: \RecipeCollection.createdDate) private var allCollections: [RecipeCollection]
    @Query(sort: \Recipe.dateAdded, order: .reverse) private var allRecipes: [Recipe]
    @Query(sort: \RecipeTheme.sortOrder) private var allThemes: [RecipeTheme]
    @Query private var allUserCredits: [UserCredits]

    // Global recipe search state
    @State private var searchText = ""

    @State private var showCreateCollection = false
    @State private var showRecipeGenerator = false
    @State private var showImportRecipe = false
    @State private var showBulkImport = false
    @State private var showCookbookScanner = false
    @State private var showVideoImport = false
    @State private var showReadRecipe = false
    @State private var selectedCollection: RecipeCollection?
    @State private var showRecipeCoachMark = false
    @State private var collectionToDelete: RecipeCollection?
    @State private var showDeleteConfirmation = false
    @State private var showHeritageUnlock = false
    @State private var showCollectionPicker = false
    @State private var generatedRecipe: Recipe?
    // TODO: Re-enable for theme unlocking in Phase A3
    // @State private var unlockTracker: ThemeUnlockTracker?
    @State private var isDownloadingRecipes = false
    @State private var downloadProgress: String = ""
    @State private var selectedCollectionForSettings: RecipeCollection?
    @State private var isGeneratingBackground = false
    @State private var generatingCollectionId: UUID?
    @State private var showAddRecipeMenu = false
    @State private var isRefreshingRecipes = false
    @State private var showRestoreFromFile = false
    @State private var isRestoringFromFile = false
    @State private var showSettings = false
    @State private var pendingRecipeNavigation: Recipe?
    @State private var selectedImportJobForReview: ImportJob?
    @State private var videoReviewData: VideoReviewData?
    @State private var jobForConfirmation: VideoProcessingJob?
    @State private var showProcessingQueue = false
    @State private var showNeedCreditsSheet = false
    @State private var showCreditsStore = false
    @State private var showPaywall = false
    @State private var pendingGenerationCollection: RecipeCollection?

    /// Cost for generating one AI background image
    private let aiBackgroundCost = 1

    /// Current user's credits
    private var userCredits: UserCredits? {
        guard let userId = firebaseAuth.currentUserId else { return nil }
        return allUserCredits.first { $0.userId == userId }
    }

    /// Whether user can afford AI background generation
    private var canAffordAIGeneration: Bool {
        guard let credits = userCredits else { return false }
        return credits.availableCredits >= aiBackgroundCost
    }

    /// Combined state for video review sheet to avoid timing issues
    struct VideoReviewData: Identifiable {
        let id = UUID()
        let job: VideoProcessingJob
        let enhanced: VideoRecipeExtraction.Enhanced
    }

    // Recipe invites (for "From Friends" collection)
    @State private var showSharedWithMe = false
    @State private var pendingInvitesCount: Int = 0

    private var subscriptionManager: SubscriptionManager { ServiceContainer.shared.resolve(SubscriptionManager.self) }
    private var collectionImageGenerator: CollectionImageGenerator { ServiceContainer.shared.resolve(CollectionImageGenerator.self) }
    private var imageStorageService: ImageStorageService { ServiceContainer.shared.resolve(ImageStorageService.self) }
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }
    private var undoService: UndoService { ServiceContainer.shared.resolve(UndoService.self) }
    @ObservedObject private var importJobManager = ServiceContainer.shared.resolve(ImportJobManager.self)
    private var videoJobManager: VideoProcessingJobManager { ServiceContainer.shared.resolve(VideoProcessingJobManager.self) }

    // MARK: - Filtered Collections

    /// Collections visible on the main list (no empty, no system)
    private var visibleCollections: [RecipeCollection] {
        allCollections
            .filter { collection in
                // Special case: "All Recipes" shows if there are ANY recipes in the system
                // (its recipeCount is always 0 since recipes aren't linked to it directly)
                if collection.isAllRecipes {
                    return !allRecipes.isEmpty
                }
                return collection.isVisibleInMainList
            }
            .sorted { a, b in
                // Sort by type priority first
                if a.type.sortPriority != b.type.sortPriority {
                    return a.type.sortPriority < b.type.sortPriority
                }
                // Then by creation date (newer first)
                return a.createdDate > b.createdDate
            }
    }

    /// Theme collections (shown in "Your Discoveries" section - AFTER My Collections)
    /// Hidden when screenRecordingService.hideThemeCollections is true (for clean screen recordings)
    var themeCollections: [RecipeCollection] {
        // Hide theme collections for screen recording mode
        guard !screenRecordingService.hideThemeCollections else { return [] }

        let selectedIds = themeUnlockTracker.selectedThemeIds

        return visibleCollections.filter { collection in
            guard collection.type == .theme else { return false }

            // Check if this theme collection matches a selected theme:
            // 1. Via sourceTheme relationship (preferred)
            if let firebaseId = collection.sourceTheme?.firebaseId, selectedIds.contains(firebaseId) {
                return true
            }
            // 2. Via sourceThemeId property (backup if relationship not set after sync)
            if let themeId = collection.sourceThemeId, selectedIds.contains(themeId) {
                return true
            }
            // 3. Via name matching against loaded themes (fallback for synced collections)
            if let matchingTheme = allThemes.first(where: { $0.name == collection.name && selectedIds.contains($0.firebaseId) }) {
                // Link the theme relationship for future use
                collection.sourceTheme = matchingTheme
                collection.sourceThemeId = matchingTheme.firebaseId
                return true
            }

            return false
        }
    }

    /// My Collections (shown BEFORE themes) - includes all import types and user-created
    /// Note: Empty collections are already filtered by isVisibleInMainList, no need to check recipe count here
    /// "All Recipes" appears last in this section, just above theme collections
    /// Hidden when screenRecordingService.hideDemoSeedCollections is true and collection.isDemoSeed is true
    private var myCollections: [RecipeCollection] {
        visibleCollections
            .filter { collection in
                // Hide demo seed collections when toggle is enabled
                if screenRecordingService.hideDemoSeedCollections && collection.isDemoSeed {
                    return false
                }

                return collection.isAllRecipes || // Shows when it has recipes (isVisibleInMainList controls this)
                collection.isFavorites || // System collection but should show in My Collections
                collection.type == .communityRecipes ||
                collection.type == .fromFriends ||
                collection.type == .videoImports ||
                collection.type == .webImports ||
                collection.type == .photoImports ||
                collection.type == .readRecipes ||
                collection.type == .cookbook ||
                collection.type == .userCreated
            }
            .sorted { lhs, rhs in
                // "All Recipes" always goes last
                if lhs.isAllRecipes { return false }
                if rhs.isAllRecipes { return true }
                // Favorites goes first
                if lhs.isFavorites { return true }
                if rhs.isFavorites { return false }
                // Otherwise maintain existing order (by type priority, then creation date)
                return false
            }
    }

    /// Get the set of demo seed collection IDs for filtering recipes
    private var demoSeedCollectionIds: Set<UUID> {
        Set(allCollections.filter { $0.isDemoSeed }.map { $0.id })
    }

    /// User-added recipes for first-time banner (excludes theme AND demo seed recipes)
    /// The banner should show when user has no personal recipes they've added themselves
    private var userAddedRecipes: [Recipe] {
        allRecipes.filter { recipe in
            // Exclude theme recipes
            guard recipe.sourceThemeId == nil else { return false }
            // Exclude recipes in demo seed collections
            let isInDemoSeed = recipe.collections?.contains { demoSeedCollectionIds.contains($0.id) } ?? false
            return !isInDemoSeed
        }
    }

    /// User recipes for display (includes theme recipes, excludes demo seed when toggle is on)
    /// Used for "All Recipes" count and thumbnails
    private var userRecipes: [Recipe] {
        allRecipes.filter { recipe in
            // Exclude locked theme recipes
            if recipe.isThemeRecipe && !themeUnlockTracker.isUnlocked(recipe) {
                return false
            }
            // When toggle is on, exclude recipes in demo seed collections
            if screenRecordingService.hideDemoSeedCollections {
                let isInDemoSeed = recipe.collections?.contains { demoSeedCollectionIds.contains($0.id) } ?? false
                if isInDemoSeed { return false }
            }
            return true
        }
    }

    // MARK: - Task #6: Grouped Collections by Category

    /// Collections grouped by category for organized display
    private var groupedCollections: [CollectionCategory: [RecipeCollection]] {
        var grouped: [CollectionCategory: [RecipeCollection]] = [:]

        for collection in visibleCollections {
            let category = collection.category
            if grouped[category] == nil {
                grouped[category] = []
            }
            grouped[category]?.append(collection)
        }

        // Sort collections within each category
        for (category, collections) in grouped {
            grouped[category] = collections.sorted { lhs, rhs in
                if lhs.displayOrder != rhs.displayOrder {
                    return lhs.displayOrder < rhs.displayOrder
                }
                return lhs.displayName < rhs.displayName
            }
        }

        return grouped
    }

    /// Categories to display, sorted by display order
    private var categoriesToShow: [CollectionCategory] {
        let categories = Set(visibleCollections.map { $0.category })
        return categories
            .filter { $0 != .system } // Hide system category
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    // Filter user collections (non-system, non-theme) - kept for existing functionality
    var userCollections: [RecipeCollection] {
        allCollections.filter { !$0.isSystemCollection && $0.type != .theme }
    }

    // System collections (All Recipes, Favorites, Quick Meals, etc.) - kept for existing functionality
    var systemCollections: [RecipeCollection] {
        let filtered = allCollections.filter { $0.isSystemCollection && $0.type != .theme }

        // Sort to ensure "All Recipes" appears first
        return filtered.sorted { lhs, rhs in
            if lhs.isAllRecipes { return true }
            if rhs.isAllRecipes { return false }
            return lhs.name < rhs.name
        }
    }

    // Filtered recipes for global search
    var searchResults: [Recipe] {
        guard !searchText.isEmpty else { return [] }

        // Filter out theme recipes when hideThemeCollections is enabled (screen recording mode)
        var searchableRecipes = screenRecordingService.hideThemeCollections
            ? allRecipes.filter { !$0.isThemeRecipe }
            : allRecipes

        // Also filter out recipes in demo seed collections when that toggle is enabled
        if screenRecordingService.hideDemoSeedCollections {
            searchableRecipes = searchableRecipes.filter { recipe in
                // Keep recipe if it's not in any demo seed collection
                guard let collections = recipe.collections else { return true }
                return !collections.contains { $0.isDemoSeed }
            }
        }

        return searchableRecipes.filter { recipe in
            // Search in title
            if recipe.title.localizedCaseInsensitiveContains(searchText) {
                return true
            }

            // Search in notes
            if recipe.notes?.localizedCaseInsensitiveContains(searchText) == true {
                return true
            }

            // Search in ingredients
            if let ingredients = recipe.ingredients {
                for ingredient in ingredients {
                    if ingredient.name.localizedCaseInsensitiveContains(searchText) {
                        return true
                    }
                }
            }

            return false
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Unified processing banner for all job types (video, import, generation)
                UnifiedProcessingBanner(
                    onVideoJobTap: { job in
                        openVideoReviewScreen(for: job)
                    },
                    onImportJobTap: { job in
                        selectedImportJobForReview = job
                    },
                    onGenerationJobTap: { job in
                        navigateToGeneratedRecipe(for: job)
                    }
                )

                // Scrollable content below
                ZStack {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Content: Search results or collections
                            if !searchText.isEmpty {
                                // Global recipe search results
                                searchResultsSection
                                    .padding(.vertical, HeirloomSpacing.lg)
                            } else {
                                // Normal collections content
                                VStack(spacing: HeirloomSpacing.xl) {
                                    // Unified Collections Section
                                    unifiedCollectionsSection
                                }
                                .padding(.vertical, HeirloomSpacing.lg)
                            }
                        }
                    }
                    .refreshable {
                        await performPullToRefresh()
                    }

                    // Loading overlay when syncing (first sync or refresh with empty data)
                    if syncService.isSyncing && !syncService.hasCompletedInitialSync {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading your recipes...")
                                .font(HeirloomFonts.body)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.9))
                    } else if isRefreshingRecipes && allRecipes.isEmpty {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Restoring from cloud...")
                                .font(HeirloomFonts.body)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.9))
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search recipes")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Collections")
                        .font(HeirloomFonts.title2)
                        .fontWeight(.semibold)
                }

                toolbarContent
            }
            .sheet(isPresented: $showCreateCollection) {
                CollectionEditorView()
                    .environmentObject(tabCoordinator)
            }
            .sheet(isPresented: $showRecipeGenerator) {
                RecipeGeneratorView(targetCollection: selectedCollection)
                    .environmentObject(tabCoordinator)
            }
            .sheet(isPresented: $showImportRecipe) {
                RecipeImportView(targetCollection: selectedCollection)
                    .environmentObject(tabCoordinator)
            }
            .sheet(isPresented: $showBulkImport) {
                BulkImportView()
                    .environmentObject(tabCoordinator)
            }
            .sheet(isPresented: $showCookbookScanner) {
                CookbookScannerView(targetCollection: selectedCollection)
                    .environmentObject(tabCoordinator)
            }
            .sheet(isPresented: $showVideoImport) {
                UnifiedVideoImportView(targetCollection: selectedCollection)
                    .environmentObject(notificationService)
                    .environmentObject(tabCoordinator)
            }
            .sheet(isPresented: $showReadRecipe) {
                ReadRecipeView(
                    dictationService: ServiceContainer.shared.resolve(VoiceDictationServiceProtocol.self)
                )
                .environmentObject(notificationService)
                .environmentObject(tabCoordinator)
            }
            .sheet(isPresented: $showProcessingQueue) {
                UnifiedProcessingQueueView(
                    onVideoJobTap: { job in
                        showProcessingQueue = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            openVideoReviewScreen(for: job)
                        }
                    },
                    onImportJobTap: { job in
                        showProcessingQueue = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            selectedImportJobForReview = job
                        }
                    },
                    onGenerationJobTap: { job in
                        showProcessingQueue = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            navigateToGeneratedRecipe(for: job)
                        }
                    }
                )
            }
            .sheet(isPresented: $showCollectionPicker) {
                if let recipe = generatedRecipe {
                    TagCollectionPickerView(recipe: recipe)
                }
            }
            // TODO: Re-enable for theme unlocking in Phase A3
            // .sheet(isPresented: $showHeritageUnlock) {
            //     ThemeUnlockView()
            //         .presentationDetents([.large])
            // }
            .sheet(item: $selectedCollectionForSettings) { collection in
                CollectionSettingsView(collection: collection)
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                        .environmentObject(tabCoordinator)
                }
            }
            .sheet(item: $selectedImportJobForReview) { job in
                NavigationStack {
                    ImportReviewView(manager: importJobManager, job: job)
                }
            }
            .sheet(item: $videoReviewData) { reviewData in
                VideoRecipeReviewView(
                    extraction: reviewData.enhanced.original,
                    enhancedExtraction: reviewData.enhanced,
                    onSave: { updatedExtraction in
                        Task { @MainActor in
                            await saveVideoRecipeAfterReview(extraction: updatedExtraction, enhanced: reviewData.enhanced, job: reviewData.job)
                            videoReviewData = nil
                            // Video recipes auto-route to "From Videos" collection - no picker needed
                        }
                    },
                    onCancel: {
                        videoReviewData = nil
                    }
                )
            }
            .sheet(item: $jobForConfirmation) { job in
                VideoConfirmationSheet(
                    job: job,
                    onConfirm: { dishNameHint in
                        try await videoJobManager.confirmAndStartProcessing(
                            job: job,
                            dishNameHint: dishNameHint,
                            context: modelContext
                        )
                        await MainActor.run {
                            jobForConfirmation = nil
                            toastManager.success(
                                title: "Video queued",
                                message: "Processing will begin shortly"
                            )
                        }
                    },
                    onCancel: {
                        jobForConfirmation = nil
                    }
                )
            }
            .sheet(isPresented: $showSharedWithMe) {
                SharedWithMeView()
                    .onDisappear {
                        // Refresh pending invites count after dismissing
                        Task {
                            await loadPendingInvitesCount()
                        }
                    }
            }
            .sheet(isPresented: $showNeedCreditsSheet) {
                NeedCreditsSheet(
                    creditsNeeded: aiBackgroundCost,
                    currentCredits: userCredits?.availableCredits ?? 0,
                    featureName: "AI Background Generation",
                    onBuyCredits: {
                        showNeedCreditsSheet = false
                        showCreditsStore = true
                    },
                    onCancel: {
                        showNeedCreditsSheet = false
                        pendingGenerationCollection = nil
                    },
                    onViewSubscription: {
                        showNeedCreditsSheet = false
                        showPaywall = true
                    }
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showCreditsStore, onDismiss: {
                // User might have purchased credits - UI will auto-update via @Query
                // If they now have credits and had a pending collection, generate
                if canAffordAIGeneration, let collection = pendingGenerationCollection {
                    Task {
                        await generateBackgroundForCollection(collection)
                    }
                    pendingGenerationCollection = nil
                }
            }) {
                if let userId = firebaseAuth.currentUserId {
                    let storeManager = CreditStoreManager(
                        logger: ServiceContainer.shared.resolve(LoggingService.self),
                        analytics: ServiceContainer.shared.resolve(AnalyticsService.self),
                        modelContext: modelContext,
                        userId: userId
                    )
                    CreditsStoreView(storeManager: storeManager, userCredits: userCredits)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(trigger: .urlImport)
            }
            .navigationDestination(for: RecipeCollection.self) { collection in
                CollectionDetailView(collection: collection)
                    .environmentObject(notificationService)
                    .environmentObject(tabCoordinator)
            }
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
                    .environmentObject(notificationService)
            }
            .navigationDestination(item: $pendingRecipeNavigation) { recipe in
                RecipeDetailView(recipe: recipe)
                    .environmentObject(notificationService)
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToRecipe)) { notification in
                if let recipeId = notification.userInfo?["recipeId"] as? UUID {
                    // Find the recipe and navigate to it
                    if let recipe = allRecipes.first(where: { $0.id == recipeId }) {
                        // Small delay to allow tab switch to complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            pendingRecipeNavigation = recipe
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .themeContentReady)) { _ in
                // Theme collections and recipes are ready (test account setup completed)
                // Ensure theme collection relationships are properly linked
                Log.info("Theme content ready notification received - refreshing collections", category: .ui)
                ensureThemeCollectionRelationships()
            }
            .overlay {
                coachMarkOverlay
            }
            .overlay {
                downloadingRecipesOverlay
            }
            .confirmationDialog(
                "Delete \(collectionToDelete?.name ?? "Collection")?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible,
                actions: deleteConfirmationActions,
                message: deleteConfirmationMessage
            )
            .confirmationDialog(
                "Add Recipe",
                isPresented: $showAddRecipeMenu,
                titleVisibility: .visible
            ) {
                Button("New Recipe") {
                    handleGenerateRecipe()
                }

                Button("Recipe Website Link") {
                    handleImportRecipe()
                }

                Button("Bulk Import") {
                    handleBulkImport()
                }

                Button("Scan Cookbook Page") {
                    handleCookbookScanner()
                }

                Button("Video Import") {
                    handleVideoImport()
                }

                Button("Processing Queue") {
                    showProcessingQueue = true
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                if let collection = selectedCollection {
                    Text("Choose how you'd like to add recipes to \(collection.name)")
                }
            }
            .fileImporter(
                isPresented: $showRestoreFromFile,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                Task {
                    await handleFileImport(result)
                }
            }
            .onAppear(perform: handleOnAppear)
            .onChange(of: syncService.hasCompletedInitialSync) { _, hasCompleted in
                // When sync completes:
                // 1. Ensure theme collections have their relationships set
                // 2. Download theme recipes if collections are empty (returning user)
                if hasCompleted {
                    Log.info("Sync completed - ensuring theme collection relationships", category: .collections)
                    ensureThemeCollectionRelationships()
                    checkAndDownloadThemeRecipesIfNeeded()
                }
            }
        }
    }

    /// Ensure all theme-type collections have their sourceTheme relationship established
    /// This is needed after Firebase sync downloads collections without the SwiftData relationship
    private func ensureThemeCollectionRelationships() {
        var needsSave = false

        for collection in allCollections where collection.type == .theme {
            // Skip if already linked
            if collection.sourceTheme != nil { continue }

            // Try to find matching theme by name
            if let matchingTheme = allThemes.first(where: { $0.name == collection.name }) {
                collection.sourceTheme = matchingTheme
                collection.sourceThemeId = matchingTheme.firebaseId
                matchingTheme.collection = collection
                needsSave = true
                Log.info("Linked theme collection after sync", category: .collections, metadata: [
                    "collection": collection.name,
                    "themeId": matchingTheme.firebaseId
                ])
            }
        }

        if needsSave {
            do {
                try modelContext.save()
                Log.info("Saved theme collection relationships", category: .collections)
            } catch {
                Log.error("Failed to save theme collection relationships", category: .collections, error: error)
            }
        }

        // After ensuring relationships, link recipes to collections
        linkThemeRecipesToCollections()
    }

    /// Link theme recipes to their theme collections based on matching sourceThemeId
    /// This ensures theme collections display their recipes after Firebase sync
    /// IMPORTANT: Only links UNLOCKED recipes based on current trial day to prevent showing future recipes
    private func linkThemeRecipesToCollections() {
        var needsSave = false
        var linkedCount = 0
        var unlinkedCount = 0

        // Get current trial day for unlock filtering
        let currentDay = themeUnlockTracker.currentTrialDay

        // Fetch all theme recipes
        let themeRecipeDescriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isThemeRecipe }
        )
        guard let themeRecipes = try? modelContext.fetch(themeRecipeDescriptor) else {
            Log.warning("Could not fetch theme recipes for linking", category: .collections)
            return
        }

        // For each theme collection, find and link matching recipes
        for collection in allCollections where collection.type == .theme {
            guard let themeId = collection.sourceThemeId else { continue }

            // Find recipes that belong to this theme AND are unlocked
            let matchingRecipes = themeRecipes.filter { recipe in
                guard recipe.sourceThemeId == themeId else { return false }
                // Only include recipes that are unlocked based on current trial day
                return themeUnlockTracker.isUnlocked(recipe)
            }

            // Get all recipes for this theme (including locked) for unlinking
            let allThemeRecipes = themeRecipes.filter { $0.sourceThemeId == themeId }

            // Link unlocked recipes to collection if not already linked
            for recipe in matchingRecipes {
                let alreadyLinked = collection.recipes?.contains(where: { $0.id == recipe.id }) ?? false
                if !alreadyLinked {
                    if collection.recipes == nil { collection.recipes = [] }
                    collection.recipes?.append(recipe)
                    linkedCount += 1
                    needsSave = true
                }
            }

            // IMPORTANT: Unlink locked recipes that may have been incorrectly linked
            // This handles the case where all recipes were linked before unlock day filtering was added
            let lockedRecipes = allThemeRecipes.filter { !themeUnlockTracker.isUnlocked($0) }
            for recipe in lockedRecipes {
                if let index = collection.recipes?.firstIndex(where: { $0.id == recipe.id }) {
                    collection.recipes?.remove(at: index)
                    unlinkedCount += 1
                    needsSave = true
                }
            }
        }

        if needsSave {
            do {
                try modelContext.save()
                Log.info("Linked theme recipes to collections", category: .collections, metadata: [
                    "linkedCount": linkedCount,
                    "unlinkedCount": unlinkedCount,
                    "currentDay": currentDay
                ])
            } catch {
                Log.error("Failed to link theme recipes to collections", category: .collections, error: error)
            }
        }
    }

    // MARK: - Theme Schedule Metadata Helper (Disabled until Phase A3)

    /// TODO: Re-implement for theme system in Phase A3
    /// Download theme recipes using persistence logic
    /// This is the shared code path for theme unlock and recovery
    private func downloadHeritageRecipesWithPersistence() async {
        // Implementation will be added in Phase A3
        /*
        // Show loading
        await MainActor.run {
            isDownloadingRecipes = true
            downloadProgress = "Preparing your heritage recipes..."
        }

        do {
            guard let authService = ServiceContainer.shared.resolveOptional(FirebaseAuthService.self),
                  authService.isAuthenticated else {
                await MainActor.run {
                    isDownloadingRecipes = false
                    Log.warning("User not authenticated, cannot download heritage recipes", category: .heritage)
                }
                return
            }

            // Initialize on-demand service
            let onDemandService = HeritageOnDemandService(
                modelContext: modelContext,
                firebaseAuth: authService
            )

            await MainActor.run {
                downloadProgress = "Loading your recipe collection..."
            }

            // Get user's schedule
            let schedule = try await onDemandService.getUserSchedule()

            Log.info("Retrieved user schedule", category: .heritage, metadata: [
                "scheduleId": schedule.scheduleId,
                "revealedCollections": schedule.revealedCollections.joined(separator: ", ")
            ])

            await MainActor.run {
                downloadProgress = "Downloading recipes..."
            }

            // Download Day 1 recipes
            let recipes = try await onDemandService.downloadRecipesForDay(day: 1, schedule: schedule)

            Log.info("Downloaded heritage recipes", category: .heritage, metadata: [
                "recipeCount": recipes.count
            ])
            DeviceLogger.shared.log("✅ [Heritage] Downloaded \(recipes.count) recipes from blind box reveal")

            // TODO: Re-enable for Phase A3
            // CRITICAL: Mark recipes as unlocked in ThemeUnlockTracker
            // This ensures the UI shows them as unlocked
            // await MainActor.run {
            //     let tracker = ServiceContainer.shared.resolve(ThemeUnlockTracker.self)
            //     for recipe in recipes {
            //         tracker.unlockedRecipeIds.insert(recipe.id.uuidString)
            //     }
            //     tracker.lastUnlockDate = Date()
            //     tracker.saveToStorage()
            //
            //     Log.info("Marked recipes as unlocked in tracker", category: .theme, metadata: [
            //         "unlockedCount": tracker.unlockedRecipeIds.count
            //     ])
            // }

            // CRITICAL: Store heritage schedule metadata locally for recovery system
            let downloadedRecipeIds = recipes.compactMap { $0.themeRecipeId }
            await MainActor.run {
                updateHeritageScheduleMetadata(
                    scheduleId: schedule.scheduleId,
                    newRecipeIds: downloadedRecipeIds,
                    currentDay: 1
                )
            }

            // CRITICAL: Triple-save with delays to force WAL checkpoint (EXACT copy from autoRevealBlindBoxesIfNeeded)
            try? await Task.sleep(nanoseconds: 100_000_000)
            try modelContext.save()
            Log.debug("First save complete", category: .heritage)

            try? await Task.sleep(nanoseconds: 100_000_000)
            try modelContext.save()
            Log.debug("Second save complete", category: .heritage)

            try? await Task.sleep(nanoseconds: 100_000_000)
            try modelContext.save()
            Log.info("✅ Heritage recipes saved to disk (3x saves)", category: .heritage)

            await MainActor.run {
                downloadProgress = "Securing your recipes..."
            }

            // Wait 3 seconds for iOS to checkpoint WAL (EXACT copy from autoRevealBlindBoxesIfNeeded)
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            Log.info("✅ Heritage setup complete - safe to continue", category: .heritage)

            await MainActor.run {
                isDownloadingRecipes = false
                downloadProgress = ""
            }
        } catch {
            await MainActor.run {
                Log.error("Failed to download heritage recipes", category: .heritage, metadata: [
                    "error": error.localizedDescription
                ])
                isDownloadingRecipes = false
                downloadProgress = ""
            }
        }
    }

    /// Update heritage schedule metadata whenever recipes are downloaded
    /// This ensures recovery system knows which recipes should exist
    private func updateHeritageScheduleMetadata(scheduleId: String, newRecipeIds: [String], currentDay: Int) {
        // Get existing expected IDs
        var expectedIds = UserDefaults.standard.array(forKey: "heritageExpectedRecipeIds") as? [String] ?? []

        // Add new recipe IDs (avoiding duplicates)
        for recipeId in newRecipeIds where !expectedIds.contains(recipeId) {
            expectedIds.append(recipeId)
        }

        // Update UserDefaults
        UserDefaults.standard.set(scheduleId, forKey: "heritageScheduleId")
        UserDefaults.standard.set(expectedIds, forKey: "heritageExpectedRecipeIds")
        UserDefaults.standard.set(currentDay, forKey: "heritageCurrentDay")
        UserDefaults.standard.set(Date(), forKey: "heritageLastDownloadDate")
        UserDefaults.standard.synchronize()

        Log.info("Updated heritage schedule metadata", category: .heritage, metadata: [
            "scheduleId": scheduleId,
            "totalExpectedRecipes": expectedIds.count,
            "currentDay": currentDay,
            "newlyAdded": newRecipeIds.count
        ])
        DeviceLogger.shared.log("✅ [Heritage] Schedule updated: \(expectedIds.count) total recipes expected")
        */
    }

    // MARK: - View Components

    // Global recipe search results
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            // Result count
            Text("\(searchResults.count) recipe\(searchResults.count == 1 ? "" : "s")")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
                .padding(.horizontal)

            // Recipe grid with collection tags
            if searchResults.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .padding(.top, 40)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: HeirloomSpacing.gridSpacing),
                    GridItem(.flexible())
                ], spacing: HeirloomSpacing.gridSpacing) {
                    ForEach(searchResults, id: \.id) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipe: recipe)
                                .environmentObject(notificationService)
                        } label: {
                            RecipeCardWithCollectionTags(recipe: recipe)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var unifiedCollectionsSection: some View {
        LazyVStack(spacing: HeirloomSpacing.lg) {
            // CTA banner (FIRST - shown until user adds their first recipe)
            // Only count user-added recipes (exclude theme AND demo seed collection recipes)
            if userAddedRecipes.isEmpty {
                ctaBanner
                    .padding(.bottom, HeirloomSpacing.sm)
            }

            // My Collections section (SECOND - appears above themes)
            if !myCollections.isEmpty {
                myCollectionsSection
            }

            // Theme collections section (THIRD - appears below My Collections)
            // Themes sync automatically on login, so no empty state needed
            if !themeCollections.isEmpty {
                themeSection
            }

            // Empty state (only if NO collections at all)
            if visibleCollections.isEmpty {
                emptyStateView
            }
        }
        .padding(.horizontal, HeirloomSpacing.lg)
    }

    // MARK: - CTA Banner

    private var ctaBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Add your own recipe")
                .font(HeirloomFonts.body)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Text("Press the + button above to import or generate recipes")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(HeirloomColors.familyGreen)
                .shadow(color: HeirloomColors.familyGreen.opacity(0.3), radius: 8, y: 4)
        )
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            // Theme collection cards (full width)
            ForEach(themeCollections) { collection in
                NavigationLink(value: collection) {
                    UnifiedCollectionCard(
                        collection: collection,
                        variant: .themed(
                            currentDay: themeUnlockTracker.currentTrialDay,
                            unlockTracker: themeUnlockTracker,
                            allRecipes: allRecipes,
                            allThemes: allThemes
                        )
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .contextMenu {
                    Button {
                        if canAffordAIGeneration {
                            Task {
                                await generateBackgroundForCollection(collection)
                            }
                        } else {
                            pendingGenerationCollection = collection
                            showNeedCreditsSheet = true
                        }
                    } label: {
                        Label("Generate with AI (\(aiBackgroundCost) credit)", systemImage: "sparkles")
                    }
                    .disabled(isGeneratingBackground)

                    Button {
                        selectedCollectionForSettings = collection
                    } label: {
                        Label("Collection Settings", systemImage: "gear")
                    }
                }
            }
        }
    }

    // MARK: - My Collections Section (imports, cookbooks, user-created)

    private var myCollectionsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            // Collection cards
            ForEach(myCollections) { collection in
                NavigationLink(value: collection) {
                    UnifiedCollectionCard(
                        collection: collection,
                        variant: .standard(
                            onAddRecipeTap: (collection.recipes?.count ?? 0) <= 1 && !collection.isAllRecipes
                                ? { handleAddRecipeToCollection(collection) }
                                : nil
                        ),
                        // Pass total recipe count for "All Recipes" collection (recipes aren't linked to it directly)
                        // Uses userRecipes to exclude theme collection recipes from the count
                        totalRecipeCount: collection.isAllRecipes ? userRecipes.count : nil,
                        // Pass user recipes (excluding theme) for "All Recipes" thumbnails
                        allRecipesForThumbnails: collection.isAllRecipes ? userRecipes : nil,
                        // For "From Friends" collection: show invite affordance when few recipes
                        onViewInvitesTap: collection.type == .fromFriends && (collection.recipes?.count ?? 0) <= 1
                            ? { showSharedWithMe = true }
                            : nil,
                        pendingInvitesCount: collection.type == .fromFriends ? pendingInvitesCount : 0
                    )
                }
                .buttonStyle(.plain)
                .task {
                    // Auto-generate AI thumbnail for single-recipe collections (Task #2)
                    await autoGenerateBackgroundIfNeeded(for: collection)
                }
                .contentShape(Rectangle())
                .contextMenu {
                    Button {
                        if canAffordAIGeneration {
                            Task {
                                await generateBackgroundForCollection(collection)
                            }
                        } else {
                            pendingGenerationCollection = collection
                            showNeedCreditsSheet = true
                        }
                    } label: {
                        Label("Generate with AI (\(aiBackgroundCost) credit)", systemImage: "sparkles")
                    }
                    .disabled(isGeneratingBackground)

                    Button {
                        selectedCollectionForSettings = collection
                    } label: {
                        Label("Collection Settings", systemImage: "gear")
                    }

                    if !collection.isSystemCollection && !collection.isAllRecipes {
                        Button(role: .destructive) {
                            collectionToDelete = collection
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Collection", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "rectangle.stack")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.warmGray)

            VStack(spacing: HeirloomSpacing.sm) {
                Text("No Collections Yet")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("Import recipes, have friends share with you, or create your own collections.")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await refreshRecipesFromFirebase()
                }
            } label: {
                HStack {
                    if isRefreshingRecipes {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "icloud.and.arrow.down")
                    }
                    Text(isRefreshingRecipes ? "Restoring..." : "Restore from Cloud")
                }
                .font(HeirloomFonts.bodyBold)
                .padding(.horizontal, HeirloomSpacing.lg)
                .padding(.vertical, HeirloomSpacing.md)
                .background(HeirloomColors.tomato)
                .foregroundStyle(.white)
                .cornerRadius(HeirloomSpacing.cardCornerRadius)
            }
            .disabled(isRefreshingRecipes)

            Button {
                showCreateCollection = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Create Collection")
                }
                .font(HeirloomFonts.body)
                .padding(.horizontal, HeirloomSpacing.lg)
                .padding(.vertical, HeirloomSpacing.md)
                .background(Color.clear)
                .foregroundStyle(HeirloomColors.tomato)
                .overlay(
                    RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                        .stroke(HeirloomColors.tomato, lineWidth: 2)
                )
            }

            Button {
                showRestoreFromFile = true
            } label: {
                HStack {
                    if isRestoringFromFile {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "doc.badge.arrow.up")
                    }
                    Text(isRestoringFromFile ? "Restoring..." : "Restore from File")
                }
                .font(HeirloomFonts.body)
                .padding(.horizontal, HeirloomSpacing.lg)
                .padding(.vertical, HeirloomSpacing.md)
                .background(Color.clear)
                .foregroundStyle(HeirloomColors.tomato)
                .overlay(
                    RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                        .stroke(HeirloomColors.tomato, lineWidth: 2)
                )
            }
            .disabled(isRestoringFromFile)

            Spacer()
        }
        .padding(.horizontal, HeirloomSpacing.xl)
    }

    // MARK: - Post-Trial Banner

    @ViewBuilder
    // TODO: Re-implement for theme system in Phase A3
    private func postTrialBanner(unlockedCount: Int) -> some View {
        EmptyView()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(HeirloomColors.primaryText)
            }
            .accessibilityLabel("Settings")
            .accessibilityHint("Open app settings")
        }

        // TODO: Re-enable theme unlock icon in Phase A3
        // Theme unlock icon with trial countdown
        // ToolbarItem(placement: .topBarTrailing) {
        //     if let tracker = unlockTracker, (tracker.totalRecipesRemaining > 0 || tracker.unlockedRecipeIds.count > 0) {
        //         Button {
        //             showHeritageUnlock = true
        //         } label: {
        //             HStack(spacing: HeirloomSpacing.xs) {
        //                 Image(systemName: "sparkles")
        //                     .foregroundStyle(.orange)
        //
        //                 if subscriptionManager.isInTrial, let daysRemaining = subscriptionManager.daysRemaining, daysRemaining > 0 {
        //                     Text("\(daysRemaining)d")
        //                         .font(HeirloomFonts.caption2)
        //                         .foregroundStyle(.orange)
        //                 }
        //             }
        //         }
        //         .accessibilityLabel("Theme Collection - \(subscriptionManager.isInTrial ? "\(subscriptionManager.daysRemaining ?? 0) days remaining" : "")")
        //     }
        // }

        ToolbarItem(placement: .primaryAction) {
            RecipeListToolbarActions(
                isSelectionMode: false,
                selectedCount: 0,
                filteredCount: 0,
                onSelectAllToggle: {},
                onGenerateRecipe: handleGenerateRecipe,
                onImportRecipe: handleImportRecipe,
                onBulkImport: handleBulkImport,
                onCookbookScanner: handleCookbookScanner,
                onVideoImport: handleVideoImport,
                onReadRecipe: handleReadRecipe,
                onAddCollection: handleAddCollection,
                onCollectionSettings: nil, // Not applicable in collections list view
                onProcessingQueue: { showProcessingQueue = true }
            )
        }
    }

    @ViewBuilder
    private var coachMarkOverlay: some View {
        if showRecipeCoachMark {
            CoachMarkView(
                message: "Tap to view. Edit to make it yours, or share to pass it on.",
                onDismiss: {
                    showRecipeCoachMark = false
                    UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasSeenRecipeCoachMark)
                }
            )
        }
    }

    /// Overlay shown during Heritage recipe downloads (daily drops, blind box reveals)
    /// For initial sign-in downloads, the blocking overlay in ContentView is used instead
    @ViewBuilder
    private var downloadingRecipesOverlay: some View {
        if isDownloadingRecipes {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: HeirloomSpacing.lg) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)

                    Text(downloadProgress)
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .multilineTextAlignment(.center)
                }
                .padding(HeirloomSpacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
                .padding(HeirloomSpacing.xl)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: isDownloadingRecipes)
        }
    }

    @ViewBuilder
    private func deleteConfirmationActions() -> some View {
        Button("Delete Collection Only", role: .destructive) {
            if let collection = collectionToDelete {
                Task {
                    await deleteCollectionKeepingRecipes(collection)
                }
            }
        }

        Button("Delete Collection & Recipes", role: .destructive) {
            if let collection = collectionToDelete {
                Task {
                    await deleteCollectionAndRecipes(collection)
                }
            }
        }

        Button("Cancel", role: .cancel) {
            collectionToDelete = nil
        }
    }

    @ViewBuilder
    private func deleteConfirmationMessage() -> some View {
        if let count = collectionToDelete?.recipeCount {
            Text("This collection has \(count) recipe\(count == 1 ? "" : "s").\n\nDelete collection only or delete with all recipes?")
        } else {
            Text("Choose what to delete")
        }
    }

    private func handleOnAppear() {
        // TODO: Re-enable for Phase A3
        // Initialize theme unlock tracker
        // if unlockTracker == nil {
        //     unlockTracker = ServiceContainer.shared.resolve(ThemeUnlockTracker.self)
        // }

        // Seed blind boxes if just completed onboarding
        seedBlindBoxesIfNeeded()

        // CRITICAL: Verify Heritage recipes exist if they should
        verifyHeritageRecipes()

        // Recreate theme collections if missing (can happen after account creation/deletion)
        // IMPORTANT: Wait for sync to complete first to avoid race condition where we create
        // empty theme collections before Firebase sync downloads recipes and links them.
        // This prevents the "0 recipes linked" issue seen in logs.
        // Only check theme collections if initial sync has ALREADY completed (from a previous session)
        // For fresh logins, the onChange(of: hasCompletedInitialSync) handler will create them after sync
        if syncService.hasCompletedInitialSync {
            // Check if ANY selected theme is missing its collection
            let selectedIds = Set(themeUnlockTracker.selectedThemeIds)
            let existingThemeIds = Set(themeCollections.compactMap { $0.sourceThemeId })
            let missingThemeIds = selectedIds.subtracting(existingThemeIds)

            if !missingThemeIds.isEmpty {
                Log.info("Sync already complete - some theme collections missing, recreating", category: .collections, metadata: [
                    "missing": Array(missingThemeIds).joined(separator: ", ")
                ])
                // Load themes first if missing (after app reinstall)
                Task {
                    if allThemes.isEmpty {
                        Log.info("Themes not loaded - fetching from Firebase", category: .collections)
                        let themeLoader = ThemeLoader()
                        _ = try? await themeLoader.loadThemes(into: modelContext)
                    }
                    await MainActor.run {
                        recreateThemeCollections()
                    }
                }
            }
        } else {
            Log.info("Initial sync not complete - deferring theme collection check to onChange handler", category: .collections)
        }

        // TODO: Re-enable coach marks after redesign
        // Show coach mark after 10 seconds if not seen before
        // if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasSeenRecipeCoachMark) {
        //     Task {
        //         try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        //         if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasSeenRecipeCoachMark) {
        //             showRecipeCoachMark = true
        //         }
        //     }
        // }

        // Load pending recipe invites count
        Task {
            await loadPendingInvitesCount()
        }
    }

    /// Load count of pending recipe invites for "From Friends" collection
    private func loadPendingInvitesCount() async {
        guard let userId = FirebaseAuth.Auth.auth().currentUser?.uid else {
            return
        }

        do {
            let firebaseShare = ServiceContainer.shared.resolve(FirebaseShareService.self)
            let shares = try await firebaseShare.fetchDirectSharesForUser(userId: userId)

            await MainActor.run {
                self.pendingInvitesCount = shares.count
            }

            Log.info("Loaded pending recipe invites count", category: .social, metadata: ["count": shares.count])
        } catch {
            Log.error("Failed to load pending recipe invites count", category: .social, error: error)
        }
    }

    /// Verify Heritage recipes exist in database, promote from cache if missing
    /// This checks the durable UserDefaults cache which survives force-quit
    private func verifyHeritageRecipes() {
        // Only verify if user has completed onboarding (otherwise they haven't downloaded Heritage yet)
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        guard hasCompletedOnboarding else {
            Log.debug("Skipping Heritage verification - onboarding not complete", category: .heritage)
            return
        }

        // TODO: Re-implement cache verification for theme recipes in Phase A3
        // Check immediately (no delay needed - cache is instant)
        // Task {
        //     await checkAndPromoteFromCache()
        // }
    }

    /// TODO: Re-implement cache verification for theme recipes in Phase A3
    /// Check durable cache vs SwiftData and promote missing recipes
    /// The cache survives force-quit because it's stored in UserDefaults with synchronize()
    private func checkAndPromoteFromCache() async {
        // Implementation will be added in Phase A3 for theme recipes
    }

    /// TODO: Re-implement for theme recipes in Phase A3
    /// Promote cached recipes to SwiftData by re-downloading from Firebase
    /// Uses cache metadata to identify which recipes to download
    private func promoteCachedRecipes(_ cachedRecipes: [String: Any]) async {
        // Implementation will be added in Phase A3 for theme recipes
    }

    // TODO: Re-implement theme seeding in Phase A3
    private func seedBlindBoxesIfNeeded() {
        // Theme seeding will be handled during onboarding in Phase B2
    }

    // TODO: Re-implement theme unlock in Phase A3
    private func revealBlindBox(_ collection: RecipeCollection) {
        // Theme unlock will be handled automatically based on user selection in Phase A3
    }

    // MARK: - Empty Theme State (Disabled until Phase A3)

    // TODO: Re-implement for theme system in Phase A3
    private var emptyHeritageState: some View {
        EmptyView()
    }

    // TODO: Re-implement for theme downloads in Phase A3
    private func downloadTodaysRecipes() {
        // Theme downloads will be handled automatically after user selection in Phase A3
    }

    private var emptyUserCollectionsView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.charcoal.opacity(0.3))

            Text("No Collections Yet")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("Create collections to organize your recipes")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                showCreateCollection = true
            } label: {
                Text("Create Collection")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.buttonTextLight)
                    .padding(.horizontal, HeirloomSpacing.lg)
                    .padding(.vertical, HeirloomSpacing.sm)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(HeirloomSpacing.cardCornerRadius)
            }
            .padding(.top, HeirloomSpacing.sm)
        }
        .padding(HeirloomSpacing.xl)
        .frame(maxWidth: .infinity)
    }


    // MARK: - Delete Actions

    private func deleteCollectionKeepingRecipes(_ collection: RecipeCollection) async {
        // Prevent deletion of system collections
        guard !collection.isSystemCollection else {
            await MainActor.run {
                toastManager.error(title: "Cannot delete", message: "System collections cannot be deleted")
            }
            return
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // NOTE: Do NOT delete from Firebase immediately!
        // UndoService handles Firebase deletion after the undo window expires.

        await MainActor.run {
            // Delete using UndoService
            undoService.deleteCollectionKeepingRecipes(collection, context: modelContext)

            // Get the undo item we just created
            guard let undoItem = undoService.pendingCollectionUndos.last else {
                Log.error("Failed to create undo item for collection deletion", category: .collections)
                return
            }

            // Show undo toast
            toastManager.showCollectionUndoToast(for: undoItem) { [undoItem] in
                undoService.undoCollectionDelete(undoItem)
                let successGenerator = UINotificationFeedbackGenerator()
                successGenerator.notificationOccurred(.success)
                toastManager.success(title: "Collection restored")
            }

            // Clear the deleted collection reference
            collectionToDelete = nil
        }
    }

    private func deleteCollectionAndRecipes(_ collection: RecipeCollection) async {
        // Prevent deletion of system collections
        guard !collection.isSystemCollection else {
            await MainActor.run {
                toastManager.error(title: "Cannot delete", message: "System collections cannot be deleted")
            }
            return
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        // NOTE: Do NOT delete from Firebase immediately!
        // UndoService handles Firebase deletion after the undo window expires.

        await MainActor.run {
            // Delete using UndoService
            undoService.deleteCollectionAndRecipes(collection, context: modelContext)

            // Get the undo item we just created
            guard let undoItem = undoService.pendingCollectionUndos.last else {
                Log.error("Failed to create undo item for collection deletion", category: .collections)
                return
            }

            // Show undo toast
            toastManager.showCollectionUndoToast(for: undoItem) { [undoItem] in
                undoService.undoCollectionDelete(undoItem)
                let successGenerator = UINotificationFeedbackGenerator()
                successGenerator.notificationOccurred(.success)
                let restoredCount = undoItem.deletedRecipeData.count
                toastManager.success(
                    title: "Collection restored",
                    message: "\(restoredCount) recipe\(restoredCount == 1 ? "" : "s") restored"
                )
            }

            // Clear the deleted collection reference
            collectionToDelete = nil
        }
    }

    // MARK: - Toolbar Action Handlers

    private func handleGenerateRecipe() {
        tabCoordinator.willCreateRecipe(from: .collectionsTab)
        showRecipeGenerator = true
    }

    private func handleImportRecipe() {
        tabCoordinator.willCreateRecipe(from: .collectionsTab)
        showImportRecipe = true
    }

    private func handleBulkImport() {
        tabCoordinator.willCreateRecipe(from: .collectionsTab)
        showBulkImport = true
    }

    private func handleCookbookScanner() {
        tabCoordinator.willCreateRecipe(from: .collectionsTab)
        showCookbookScanner = true
    }

    private func handleVideoImport() {
        tabCoordinator.willCreateRecipe(from: .collectionsTab)
        showVideoImport = true
    }

    private func handleReadRecipe() {
        tabCoordinator.willCreateRecipe(from: .collectionsTab)
        showReadRecipe = true
    }

    // MARK: - Video Job Review

    private func openVideoReviewScreen(for job: VideoProcessingJob) {
        // Handle jobs awaiting confirmation (analysis complete, needs user approval)
        if job.status == .awaitingConfirmation {
            jobForConfirmation = job
            return
        }

        // Handle failed jobs — retry if possible
        if job.status == .failed {
            if job.canRetry {
                Task {
                    do {
                        let jobManager = ServiceContainer.shared.resolve(VideoProcessingJobManager.self)
                        try await jobManager.retryJob(job, context: modelContext)
                        ServiceContainer.shared.resolve(ToastManager.self).success(title: "Retrying video")
                    } catch {
                        Log.error("Failed to retry job", category: .video, error: error)
                        ServiceContainer.shared.resolve(ToastManager.self).error(
                            title: "Cannot Retry",
                            message: error.localizedDescription
                        )
                    }
                }
            } else {
                ServiceContainer.shared.resolve(ToastManager.self).error(
                    title: "Cannot Retry",
                    message: "Maximum retries exceeded. Please delete and re-import."
                )
            }
            return
        }

        // Allow .completed jobs OR orphaned .saved jobs (auto-dismissed but never reviewed)
        let needsReview = job.status == .completed || (job.status == .saved && job.recipeID == nil)
        guard needsReview,
              let extractionData = job.extractionJSON else {
            Log.error("Cannot open review screen - job not ready for review or no extraction data", category: .video, metadata: [
                "jobId": job.id.uuidString,
                "status": job.status.rawValue,
                "hasRecipeID": String(job.recipeID != nil)
            ])
            return
        }

        do {
            // Try to decode enhanced extraction first (new format with augmentation)
            let enhanced = try JSONDecoder().decode(VideoRecipeExtraction.Enhanced.self, from: extractionData)
            videoReviewData = VideoReviewData(job: job, enhanced: enhanced)
        } catch {
            // Fallback: Try decoding old format (base extraction without augmentation)
            do {
                let baseExtraction = try JSONDecoder().decode(VideoRecipeExtraction.self, from: extractionData)
                // Wrap in Enhanced with empty augmentation
                let enhanced = VideoRecipeExtraction.Enhanced(
                    original: baseExtraction,
                    augmentedRecipe: nil,
                    similarRecipes: [],
                    webRecipes: []
                )
                videoReviewData = VideoReviewData(job: job, enhanced: enhanced)

                Log.info("Loaded old job format without augmentation", category: .video, metadata: [
                    "jobId": job.id.uuidString
                ])
            } catch {
                Log.error("Failed to decode extraction from job", category: .video, metadata: [
                    "jobId": job.id.uuidString,
                    "error": error.localizedDescription
                ])
            }
        }
    }

    private func navigateToGeneratedRecipe(for job: RecipeGenerationJob) {
        // Handle failed jobs by retrying
        if job.status == .failed {
            let service = ServiceContainer.shared.resolve(RecipeGenerationService.self)
            service.retryJob(job, context: modelContext)
            toastManager.success(title: "Retrying", message: "Regenerating \(job.dishName)...")
            return
        }

        // Only handle completed jobs with a recipe
        guard job.status == .completed,
              let recipeId = job.placeholderRecipeId else {
            Log.debug("Cannot navigate - job not completed or no recipe ID", category: .general, metadata: [
                "jobId": job.id.uuidString,
                "status": job.status.rawValue
            ])
            return
        }

        // Find the generated recipe by ID
        if let recipe = allRecipes.first(where: { $0.id == recipeId }) {
            pendingRecipeNavigation = recipe
        } else {
            Log.warning("Generated recipe not found", category: .general, metadata: [
                "recipeId": recipeId.uuidString,
                "jobId": job.id.uuidString
            ])
            toastManager.error(title: "Recipe not found", message: "The generated recipe could not be located")
        }
    }

    private func saveVideoRecipeAfterReview(
        extraction: VideoRecipeExtraction,
        enhanced: VideoRecipeExtraction.Enhanced,
        job: VideoProcessingJob
    ) async {
        do {
            // Use finalizeAfterReview which handles augmented ingredients
            try await videoJobManager.finalizeAfterReview(
                job: job,
                reviewedExtraction: extraction,
                enhanced: enhanced,
                context: modelContext
            )

            Log.info("Recipe saved successfully via finalizeAfterReview", category: .video, metadata: [
                "jobId": job.id.uuidString,
                "recipeId": job.recipeID?.uuidString ?? "nil"
            ])
            // Video recipes auto-route to "From Videos" collection - no picker needed
        } catch {
            Log.error("Failed to save recipe from job", category: .video, metadata: [
                "jobId": job.id.uuidString,
                "error": error.localizedDescription
            ])

            toastManager.error(
                title: "Failed to Save Recipe",
                message: error.localizedDescription
            )
        }
    }

    /// Handle tap on + affordance in collection card - routes to appropriate ingress based on collection type
    private func handleAddRecipeToCollection(_ collection: RecipeCollection) {
        // Store selected collection for adding recipe
        selectedCollection = collection

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Special case: "Generated Recipes" collection should open recipe generator directly
        if collection.name == "Generated Recipes" && collection.type == .userCreated {
            showRecipeGenerator = true
            Log.info("Opening recipe generator from Generated Recipes collection", category: .collections)
            return
        }

        // Smart routing: Open the appropriate import flow based on collection type
        switch collection.type {
        case .webImports:
            showImportRecipe = true
            Log.info("Opening web import from + affordance", category: .collections)

        case .videoImports:
            showVideoImport = true
            Log.info("Opening video import from + affordance", category: .collections)

        case .cookbook, .photoImports:
            // Both cookbook and photo imports use CookbookScannerView
            // (which has both camera and photo library picker)
            showCookbookScanner = true
            Log.info("Opening cookbook/photo scanner from + affordance", category: .collections, metadata: [
                "collectionType": collection.type.rawValue
            ])

        case .fromFriends:
            // Shared collections shouldn't show + affordance
            // But if somehow tapped, show generic menu
            showAddRecipeMenu = true
            Log.warning("+ affordance tapped on fromFriends collection", category: .collections)

        case .theme:
            // Theme collections use different card, but handle gracefully
            showAddRecipeMenu = true
            Log.info("Opening add recipe menu from theme collection", category: .collections)

        case .userCreated:
            // User-created collections show the full add menu with all options
            showAddRecipeMenu = true
            Log.info("Opening add recipe menu from user collection", category: .collections)

        default:
            // Fallback to standard add menu
            showAddRecipeMenu = true
            Log.info("Opening add recipe menu (default)", category: .collections)
        }

        Log.info("Add recipe triggered from collection card", category: .collections, metadata: [
            "collectionId": collection.id.uuidString,
            "collectionType": collection.type.rawValue
        ])
    }

    private func generateBackgroundForCollection(_ collection: RecipeCollection, silent: Bool = false) async {
        guard !isGeneratingBackground else {
            if !silent {
                toastManager.info(title: "Generation in Progress", message: "Please wait for the current generation to finish")
            }
            return
        }

        isGeneratingBackground = true
        generatingCollectionId = collection.id

        // Show toast that generation started (unless silent)
        if !silent {
            await MainActor.run {
                toastManager.info(title: "Generating Background", message: "Creating AI image for \(collection.name)...")
            }
        } else {
            Log.info("Auto-generating background for collection", category: .collections, metadata: [
                "collectionId": collection.id.uuidString,
                "collectionName": collection.name
            ])
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

                // Deduct credits for successful generation
                if let credits = userCredits {
                    do {
                        try credits.deductCredits(aiBackgroundCost)

                        // Track credit analytics
                        let analytics = ServiceContainer.shared.resolve(AnalyticsService.self)
                        let subscriptionManager = ServiceContainer.shared.resolve(SubscriptionManager.self)
                        CreditAnalytics.trackDeduction(
                            analytics: analytics,
                            userCredits: credits,
                            operationType: .aiBackground,
                            amount: aiBackgroundCost,
                            subscriptionManager: subscriptionManager
                        )

                        DeviceLogger.shared.log("💳 [Credits] Deducted \(aiBackgroundCost) credit for AI background generation", level: .info)
                    } catch {
                        DeviceLogger.shared.log("💳 [Credits] Failed to deduct credits: \(error.localizedDescription)", level: .error)
                    }
                }

                try? modelContext.save()

                isGeneratingBackground = false
                generatingCollectionId = nil

                if !silent {
                    toastManager.success(title: "Background Generated", message: "AI created a custom image for \(collection.name)")
                } else {
                    Log.info("Auto-generation completed", category: .collections, metadata: [
                        "collectionId": collection.id.uuidString,
                        "imagePath": imagePath
                    ])
                }
            }
        } catch {
            await MainActor.run {
                isGeneratingBackground = false
                generatingCollectionId = nil

                if !silent {
                    toastManager.error(title: "Generation Failed", message: error.localizedDescription)
                } else {
                    Log.warning("Auto-generation failed", category: .collections, metadata: [
                        "collectionId": collection.id.uuidString,
                        "error": error.localizedDescription
                    ])
                }
            }
        }
    }

    /// Check if collection should have AI background auto-generated (Task #2)
    private func shouldAutoGenerateBackground(for collection: RecipeCollection) -> Bool {
        // Skip collections that have preset backgrounds - use the hardcoded assets instead
        let typesWithPresetBackgrounds: [CollectionType] = [.cookbook, .videoImports, .fromFriends, .webImports, .photoImports, .readRecipes]
        if typesWithPresetBackgrounds.contains(collection.type) {
            return false
        }

        // Skip "Generated Recipes" collection - it has a bundled preset background
        if collection.name == "Generated Recipes" {
            return false
        }

        let recipeCount = collection.recipes?.count ?? 0

        // Must have exactly 1 recipe
        guard recipeCount == 1 else {
            return false
        }

        // Must not already have a background
        guard collection.generatedBackgroundImagePath == nil,
              collection.customBackgroundImagePath == nil else {
            return false
        }

        // If never attempted, should generate
        guard let lastGenDate = collection.lastImageGenerationDate else {
            return true
        }

        // If last generation was for different recipe count, content is stale
        if collection.lastRecipeCountAtGeneration != recipeCount {
            return true
        }

        // If last attempt was recent (within 5 minutes), don't retry
        // This prevents repeated failed attempts
        let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
        if lastGenDate > fiveMinutesAgo {
            return false
        }

        // Otherwise allow retry (maybe it failed before, user added content, etc.)
        return true
    }

    /// Auto-generate AI background for qualifying collections (Task #2)
    /// Only auto-generates for users with available credits
    private func autoGenerateBackgroundIfNeeded(for collection: RecipeCollection) async {
        // Don't auto-generate if user doesn't have credits
        guard canAffordAIGeneration else {
            return
        }

        guard shouldAutoGenerateBackground(for: collection) else {
            return
        }

        // Generate silently (no toasts, just logging)
        await generateBackgroundForCollection(collection, silent: true)
    }

    private func handleAddCollection() {
        tabCoordinator.willCreateCollection(from: .collectionsTab)
        showCreateCollection = true
    }

    private func refreshRecipesFromFirebase() async {
        guard !isRefreshingRecipes else {
            DeviceLogger.shared.log("🔄 [Collections] refreshRecipesFromFirebase skipped - already in progress", level: .info)
            return
        }

        await MainActor.run {
            isRefreshingRecipes = true
            toastManager.info(title: "Restoring from Cloud", message: "Downloading your recipes and collections...")
            DeviceLogger.shared.log("🔄 [Collections] Starting restore from cloud...", level: .info)
        }

        do {
            // 1. Trigger Firebase sync to download user recipes and collections
            DeviceLogger.shared.log("🔄 [Collections] Step 1: Syncing with Firebase CRDT...", level: .info)
            try await syncService.syncChangesWithCRDT()
            DeviceLogger.shared.log("🔄 [Collections] Step 1 complete: Firebase CRDT sync done", level: .info)

            // 2. Recreate theme collections based on user's selected themes
            DeviceLogger.shared.log("🔄 [Collections] Step 2: Recreating theme collections...", level: .info)
            await MainActor.run {
                recreateThemeCollections()
            }
            DeviceLogger.shared.log("🔄 [Collections] Step 2 complete: Theme collections recreated", level: .info)

            // 3. Re-download theme recipes from central database
            let selectedThemeIds = await MainActor.run {
                Array(themeUnlockTracker.selectedThemeIds)
            }

            DeviceLogger.shared.log("🔄 [Collections] Step 3: Re-downloading theme recipes (themes: \(selectedThemeIds.count))...", level: .info)
            if !selectedThemeIds.isEmpty {
                // CRITICAL: ThemeRecipeService is @MainActor and uses modelContext
                // We must await the download to ensure it completes before showing success
                let recipeService = await MainActor.run { ThemeRecipeService() }
                let recipes = try await recipeService.downloadRecipes(for: selectedThemeIds, into: modelContext)

                await MainActor.run {
                    try? modelContext.save()
                    DeviceLogger.shared.log("🔄 [Collections] Step 3 complete: Downloaded \(recipes.count) theme recipes", level: .info)
                    Log.info("Re-downloaded \(recipes.count) theme recipes", category: .collections)
                }
            } else {
                DeviceLogger.shared.log("🔄 [Collections] Step 3 skipped: No selected themes", level: .info)
            }

            await MainActor.run {
                isRefreshingRecipes = false
                let finalCount = allRecipes.count
                DeviceLogger.shared.log("🔄 [Collections] Restore complete! Final recipe count: \(finalCount)", level: .info)
                toastManager.success(title: "Restored", message: "Your recipes and collections have been restored from the cloud")
            }

            Log.info("Recipes refreshed from Firebase", category: .collections)
        } catch {
            await MainActor.run {
                isRefreshingRecipes = false
                DeviceLogger.shared.log("🔄 [Collections] Restore FAILED: \(error.localizedDescription)", level: .error)
                toastManager.error(title: "Restore Failed", message: error.localizedDescription)
            }

            Log.error("Failed to refresh recipes from Firebase", category: .collections, error: error)
        }
    }

    /// Pull-to-refresh handler - syncs with Firebase
    private func performPullToRefresh() async {
        DeviceLogger.shared.log("🔄 [Collections] Pull-to-refresh triggered - current recipe count: \(allRecipes.count)", level: .info)
        await refreshRecipesFromFirebase()
        DeviceLogger.shared.log("🔄 [Collections] Pull-to-refresh completed - final recipe count: \(allRecipes.count)", level: .info)
    }

    private func recreateThemeCollections() {
        // Get user's selected themes from ThemeUnlockTracker
        let selectedThemeIds = themeUnlockTracker.selectedThemeIds

        guard !selectedThemeIds.isEmpty else {
            Log.info("No selected themes to recreate collections for", category: .collections)
            return
        }

        // Filter to themes user has selected
        let selectedThemes = allThemes.filter { selectedThemeIds.contains($0.firebaseId) }

        for theme in selectedThemes {
            // Check if collection already exists
            let themeName = theme.name
            let collectionDescriptor = FetchDescriptor<RecipeCollection>(
                predicate: #Predicate<RecipeCollection> { collection in
                    collection.name == themeName && collection.collectionType == "theme"
                }
            )

            if let existing = try? modelContext.fetch(collectionDescriptor).first {
                // Link existing collection to theme
                existing.sourceTheme = theme
                existing.sourceThemeId = theme.firebaseId
                theme.collection = existing
                Log.info("Linked existing theme collection", category: .collections, metadata: ["theme": themeName])
            } else {
                // Create new collection
                let collection = RecipeCollection(
                    name: theme.name,
                    iconName: theme.iconName,
                    collectionType: .theme
                )
                collection.sourceTheme = theme
                collection.sourceThemeId = theme.firebaseId
                theme.collection = collection
                modelContext.insert(collection)
                Log.info("Created theme collection", category: .collections, metadata: ["theme": themeName])
            }
        }

        do {
            try modelContext.save()
            Log.info("Recreated \(selectedThemes.count) theme collections", category: .collections)
        } catch {
            Log.error("Failed to recreate theme collections", category: .collections, error: error)
        }

        // After creating collections, link recipes to them
        linkThemeRecipesToCollections()
    }

    /// Download theme recipes for a returning user after sign-in
    /// This is called when theme collections are created but recipes haven't been downloaded yet
    private func downloadThemeRecipesForReturningUser(themeIds: [String]) async {
        guard !themeIds.isEmpty else { return }

        Log.info("Downloading theme recipes for returning user", category: .collections, metadata: [
            "themeCount": themeIds.count
        ])

        do {
            let recipeService = await MainActor.run { ThemeRecipeService() }
            let recipes = try await recipeService.downloadRecipes(for: themeIds, into: modelContext)

            await MainActor.run {
                try? modelContext.save()
                Log.info("Downloaded theme recipes for returning user", category: .collections, metadata: [
                    "recipeCount": recipes.count
                ])
            }
        } catch {
            Log.error("Failed to download theme recipes for returning user", category: .collections, error: error)
        }
    }

    /// Check if theme collections are empty and download recipes if needed (returning user case)
    private func checkAndDownloadThemeRecipesIfNeeded() {
        let selectedIds: [String] = themeUnlockTracker.selectedThemeIds

        // Check if theme collections exist but are EMPTY (returning user case)
        let themeCollectionsEmpty: Bool = themeCollections.allSatisfy { ($0.recipes ?? []).isEmpty }

        if !selectedIds.isEmpty && themeCollectionsEmpty {
            Log.info("Sync completed - theme collections empty, downloading recipes (returning user)", category: .collections, metadata: [
                "selectedThemeCount": selectedIds.count,
                "themeCollectionCount": themeCollections.count
            ])

            Task {
                // First, ensure themes are loaded from Firebase (may be missing after app reinstall)
                if allThemes.isEmpty {
                    Log.info("Themes not loaded - fetching from Firebase for returning user", category: .collections)
                    let themeLoader = ThemeLoader()
                    _ = try? await themeLoader.loadThemes(into: modelContext)
                }

                // Now recreate collections (must be on main actor since we touch modelContext)
                await MainActor.run {
                    recreateThemeCollections()
                }

                // Download theme recipes - same as pull-to-refresh
                await downloadThemeRecipesForReturningUser(themeIds: selectedIds)
            }
        }
    }

    // MARK: - Restore from File

    private func handleFileImport(_ result: Result<[URL], Error>) async {
        await MainActor.run {
            isRestoringFromFile = true
            toastManager.info(title: "Restoring Backup", message: "Importing recipes from file...")
        }

        // CRITICAL: Wait for any ongoing Firebase sync to complete
        // This prevents recipes from being re-synced from Firebase during the restore
        // which would cause false duplicate detections
        Log.info("Waiting for Firebase sync to complete before restore", category: .collections)
        var waitTime = 0
        while syncService.isSyncing && waitTime < 20 {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            waitTime += 1
        }
        Log.info("Firebase sync check complete", category: .collections, metadata: ["waited": Double(waitTime) * 0.5])

        // CRITICAL: Ensure SwiftData context is saved before restore
        // This prevents stale deleted objects from being detected as duplicates
        await MainActor.run {
            try? modelContext.save()
            Log.info("Saved SwiftData context before restore", category: .collections)
        }

        do {
            // Handle file picker result
            let fileURL: URL
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    throw ImportError.noFileSelected
                }
                fileURL = url
                Log.info("File selected for import", category: .collections, metadata: ["path": url.lastPathComponent])
            case .failure(let error):
                Log.error("File picker failed", category: .collections, metadata: ["error": error.localizedDescription])
                throw error
            }

            // Check if file/directory exists
            var isDirectory: ObjCBool = false
            let fileExists = FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)
            Log.info("Checking file existence", category: .collections, metadata: [
                "url": fileURL.absoluteString,
                "path": fileURL.path,
                "exists": fileExists,
                "isDirectory": isDirectory.boolValue,
                "isFileURL": fileURL.isFileURL
            ])

            if !fileExists {
                Log.error("File/directory does not exist at path", category: .collections, metadata: ["path": fileURL.path])
                throw ImportError.fileNotFound
            }

            // Request access to security-scoped resource
            Log.info("Requesting security-scoped access", category: .collections)
            let hasAccess = fileURL.startAccessingSecurityScopedResource()
            Log.info("Security-scoped access result", category: .collections, metadata: ["hasAccess": hasAccess])

            if !hasAccess {
                Log.error("Failed to access security-scoped resource", category: .collections)
                throw ImportError.fileAccessDenied
            }
            defer {
                Log.debug("Stopping security-scoped access", category: .collections)
                fileURL.stopAccessingSecurityScopedResource()
            }

            // Determine JSON file path (either direct file or recipes.json in directory)
            let jsonURL: URL
            let imagesURL: URL?

            if isDirectory.boolValue {
                // Backup directory format: RecipeBackup_XXX/recipes.json + images/
                jsonURL = fileURL.appendingPathComponent("recipes.json")
                let potentialImagesURL = fileURL.appendingPathComponent("images")
                imagesURL = FileManager.default.fileExists(atPath: potentialImagesURL.path) ? potentialImagesURL : nil

                Log.info("Importing from backup directory", category: .collections, metadata: [
                    "jsonPath": jsonURL.path,
                    "hasImages": imagesURL != nil
                ])
            } else {
                // Legacy single JSON file format
                jsonURL = fileURL
                imagesURL = nil
                Log.info("Importing from JSON file", category: .collections)
            }

            // Read JSON data
            Log.info("Reading JSON data", category: .collections)
            let data = try Data(contentsOf: jsonURL)
            Log.info("JSON data read successfully", category: .collections, metadata: ["bytes": data.count])

            // Decode JSON - Try both export formats
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let recipesToImport: [(title: String, ingredients: [String], instructions: [String], servings: String?, prepTime: String?, cookTime: String?, notes: String?, dateAdded: Date, timesCooked: Int, isFavorite: Bool, sourceType: String?, sourceURL: String?, collectionName: String?, imageFileName: String?)]

            // Try new DataExportView format first
            if let exportData = try? decoder.decode(ExportData.self, from: data) {
                Log.info("Decoded DataExportView format", category: .collections, metadata: ["recipeCount": exportData.recipes.count])
                recipesToImport = exportData.recipes.map { recipe in
                    (
                        title: recipe.title,
                        ingredients: recipe.ingredients,
                        instructions: recipe.instructions,
                        servings: recipe.servings,
                        prepTime: recipe.prepTime,
                        cookTime: recipe.cookTime,
                        notes: recipe.notes,
                        dateAdded: recipe.dateAdded,
                        timesCooked: recipe.timesCooked,
                        isFavorite: recipe.isFavorite,
                        sourceType: recipe.sourceType,
                        sourceURL: recipe.sourceURL,
                        collectionName: nil, // DataExportView format doesn't include collection name
                        imageFileName: nil // DataExportView format doesn't include image filenames
                    )
                }
            }
            // Try legacy RecipeExporter format
            else if let legacyExport = try? decoder.decode(LegacyRecipeExport.self, from: data) {
                Log.info("Decoded RecipeExporter format", category: .collections, metadata: ["recipeCount": legacyExport.recipes.count])
                let isoFormatter = ISO8601DateFormatter()

                // Filter and convert recipes
                var convertedRecipes: [(title: String, ingredients: [String], instructions: [String], servings: String?, prepTime: String?, cookTime: String?, notes: String?, dateAdded: Date, timesCooked: Int, isFavorite: Bool, sourceType: String?, sourceURL: String?, collectionName: String?, imageFileName: String?)] = []

                for recipe in legacyExport.recipes {
                    // Skip theme recipes from legacy exports
                    guard !recipe.isHeritage else {
                        Log.debug("Skipping theme recipe from legacy export", category: .collections, metadata: ["title": recipe.title])
                        continue
                    }

                    guard let dateAdded = isoFormatter.date(from: recipe.createdDate) else {
                        Log.warning("Failed to parse date for recipe", category: .collections, metadata: ["title": recipe.title])
                        continue
                    }

                    convertedRecipes.append((
                        title: recipe.title,
                        ingredients: recipe.ingredients,
                        instructions: recipe.instructions,
                        servings: recipe.servings,
                        prepTime: recipe.prepTime,
                        cookTime: recipe.cookTime,
                        notes: recipe.notes,
                        dateAdded: dateAdded,
                        timesCooked: 0, // Legacy format doesn't have this
                        isFavorite: false, // Legacy format doesn't have this
                        sourceType: nil, // Legacy uses simple source string
                        sourceURL: recipe.source,
                        collectionName: recipe.collectionName, // IMPORTANT: Preserve original collection
                        imageFileName: recipe.imageFileName // NEW: For sidecar image restoration
                    ))
                }

                recipesToImport = convertedRecipes
            }
            // Neither format worked
            else {
                Log.error("Failed to decode backup file with any known format", category: .collections)
                throw ImportError.invalidFileFormat
            }

            // Import recipes
            var importedCount = 0
            var imagesRestoredCount = 0

            // Prepare image restoration if backup has images/ folder
            let shouldRestoreImages = imagesURL != nil
            let destinationImagesDir: URL? = {
                guard shouldRestoreImages else { return nil }
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                return documentsPath.appendingPathComponent("RecipeImages", isDirectory: true)
            }()

            if shouldRestoreImages, let destDir = destinationImagesDir {
                // Ensure RecipeImages directory exists
                if !FileManager.default.fileExists(atPath: destDir.path) {
                    try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
                }
                Log.info("Ready to restore images from backup", category: .collections, metadata: [
                    "imagesURL": imagesURL?.path ?? "none",
                    "destinationDir": destDir.path
                ])
            }

            for recipeData in recipesToImport {
                // Extract title for predicate (predicates can't capture tuple members)
                let recipeTitle = recipeData.title

                // CRITICAL: For backup restores, we SKIP duplicate detection entirely
                // Reason: After "Clear All Data", Firebase may sync recipes back before restore completes
                // The user explicitly wants to restore their backup - we should honor that intent
                // If they restore the same file twice, that's their choice
                Log.info("Importing recipe from backup", category: .collections, metadata: [
                    "title": recipeTitle
                ])

                // Create new recipe
                let recipe = Recipe()
                recipe.title = recipeData.title
                recipe.servings = recipeData.servings
                recipe.prepTime = recipeData.prepTime
                recipe.cookTime = recipeData.cookTime
                recipe.notes = recipeData.notes
                recipe.dateAdded = recipeData.dateAdded
                recipe.timesCooked = recipeData.timesCooked
                recipe.isFavorite = recipeData.isFavorite
                recipe.sourceURL = recipeData.sourceURL

                // Set source type
                if let sourceTypeStr = recipeData.sourceType,
                   let sourceType = RecipeSourceType(rawValue: sourceTypeStr) {
                    recipe.sourceType = sourceType
                }

                // Create ingredients
                var ingredients: [Ingredient] = []
                for (index, ingredientText) in recipeData.ingredients.enumerated() {
                    let ingredient = Ingredient(
                        originalText: ingredientText,
                        name: ingredientText,
                        quantity: nil,
                        unit: nil,
                        category: .other,
                        orderIndex: index
                    )
                    ingredient.recipe = recipe
                    ingredients.append(ingredient)
                }
                recipe.ingredients = ingredients

                // Set instructions
                recipe.instructions = recipeData.instructions

                // Insert into context and add to appropriate collection
                await MainActor.run {
                    modelContext.insert(recipe)

                    // CRITICAL: Restore recipe to its original collection based on backup data
                    // This ensures collections appear after restore matching the user's original setup
                    let collectionToUse: RecipeCollection? = {
                        // Priority 1: Use collectionName from backup (legacy format)
                        if let collectionName = recipeData.collectionName {
                            return findOrCreateCollection(named: collectionName, for: recipe)
                        }
                        // Priority 2: Infer from sourceURL (for DataExportView format)
                        else if let sourceURL = recipe.sourceURL, !sourceURL.isEmpty {
                            return findOrCreateCollection(named: "Web Imports", for: recipe)
                        }
                        // Priority 3: No collection (orphaned recipe)
                        else {
                            return nil
                        }
                    }()

                    if let collection = collectionToUse {
                        recipe.collections = [collection]
                        Log.info("Added recipe to collection during restore", category: .collections, metadata: [
                            "recipe": recipeData.title,
                            "collection": collection.name
                        ])
                    }
                }

                // Restore recipe image from backup if available
                if shouldRestoreImages,
                   let sourceImagesURL = imagesURL,
                   let destImagesDir = destinationImagesDir,
                   let originalImageFileName = recipeData.imageFileName {

                    let sourceImageURL = sourceImagesURL.appendingPathComponent(originalImageFileName)

                    // Check if image exists in backup
                    if FileManager.default.fileExists(atPath: sourceImageURL.path) {
                        // Generate new filename for this recipe instance
                        let timestamp = Int(Date().timeIntervalSince1970)
                        let newImageFileName = "recipe-\(recipe.id.uuidString)-\(timestamp).jpg"
                        let destImageURL = destImagesDir.appendingPathComponent(newImageFileName)

                        // Copy image from backup to app's RecipeImages directory
                        do {
                            try FileManager.default.copyItem(at: sourceImageURL, to: destImageURL)
                            recipe.imageFileName = newImageFileName
                            imagesRestoredCount += 1

                            Log.info("Restored recipe image from backup", category: .collections, metadata: [
                                "recipe": recipeData.title,
                                "originalFileName": originalImageFileName,
                                "newFileName": newImageFileName
                            ])
                        } catch {
                            Log.warning("Failed to copy image from backup", category: .collections, metadata: [
                                "recipe": recipeData.title,
                                "error": error.localizedDescription
                            ])
                        }
                    }
                }

                importedCount += 1
            }

            // Save context
            await MainActor.run {
                do {
                    try modelContext.save()
                    isRestoringFromFile = false

                    // Build success message
                    var message = "Imported \(importedCount) recipe\(importedCount == 1 ? "" : "s")"
                    if shouldRestoreImages {
                        message += " and \(imagesRestoredCount) image\(imagesRestoredCount == 1 ? "" : "s")"
                    } else {
                        message += ". Note: Images not included in JSON-only backups."
                    }

                    toastManager.success(title: "Backup Restored", message: message)
                    Log.info("Restored \(importedCount) recipes from backup", category: .collections, metadata: [
                        "imagesRestored": imagesRestoredCount,
                        "hadImages": shouldRestoreImages
                    ])
                } catch {
                    isRestoringFromFile = false
                    toastManager.error(title: "Save Failed", message: error.localizedDescription)
                    Log.error("Failed to save restored recipes", category: .collections, error: error)
                }
            }

        } catch {
            await MainActor.run {
                isRestoringFromFile = false

                // Check for user cancellation
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    // User cancelled - don't show error
                    Log.info("User cancelled file selection", category: .collections)
                    return
                }

                // Check for CocoaError (file access issues)
                if let cocoaError = error as? CocoaError {
                    Log.error("CocoaError during restore", category: .collections, metadata: [
                        "code": "\(cocoaError.code.rawValue)",
                        "description": cocoaError.localizedDescription
                    ])
                }

                let errorMessage: String
                if let importError = error as? ImportError {
                    errorMessage = importError.errorDescription ?? "Unknown error"
                } else {
                    // Provide user-friendly message for system errors
                    errorMessage = "Unable to read the file. Please make sure it's a valid Heirloom export file and try again."
                    Log.error("System error during restore", category: .collections, metadata: [
                        "error": error.localizedDescription,
                        "type": "\(type(of: error))"
                    ])
                }

                toastManager.error(title: "Restore Failed", message: errorMessage)
            }
        }
    }

    // MARK: - Collection Restoration Helper

    /// Find or create a collection based on the name from backup
    /// Maps collection names to appropriate collection types
    @MainActor
    private func findOrCreateCollection(named collectionName: String, for recipe: Recipe) -> RecipeCollection? {
        // Map collection names to collection types
        let collectionType: CollectionType = {
            switch collectionName {
            case "Web Imports", "From Web":
                return .webImports
            case "Video Imports", "From Videos":
                return .videoImports
            case "Cookbook Pages", "Cookbooks":
                return .cookbook
            case "Photo Imports", "From Photos":
                return .photoImports
            case "From Friends", "Shared Recipes":
                return .fromFriends
            default:
                // User-created custom collection
                return .userCreated
            }
        }()

        // Normalize collection name for system collections
        let normalizedName: String = {
            switch collectionType {
            case .webImports: return "Web Imports"
            case .videoImports: return "Video Imports"
            case .cookbook: return "Cookbook Pages"
            case .photoImports: return "Photo Imports"
            case .fromFriends: return "From Friends"
            case .userCreated: return collectionName // Keep original name
            default: return collectionName
            }
        }()

        // Look for existing collection with this type
        let collectionTypeStr = collectionType.rawValue
        let descriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate<RecipeCollection> { collection in
                collection.collectionType == collectionTypeStr
            }
        )

        if let existing = (try? modelContext.fetch(descriptor))?.first {
            return existing
        }

        // Create new collection
        let iconName: String = {
            switch collectionType {
            case .webImports: return "globe"
            case .videoImports: return "video"
            case .cookbook: return "book"
            case .photoImports: return "photo"
            case .fromFriends: return "person.2"
            case .userCreated: return "folder"
            default: return "folder"
            }
        }()

        let newCollection = RecipeCollection(
            name: normalizedName,
            iconName: iconName,
            collectionType: collectionType
        )
        modelContext.insert(newCollection)

        Log.info("Created collection during restore", category: .collections, metadata: [
            "name": normalizedName,
            "type": collectionType.rawValue
        ])

        return newCollection
    }

    enum ImportError: LocalizedError {
        case noFileSelected
        case invalidFileFormat
        case fileAccessDenied
        case fileNotFound

        var errorDescription: String? {
            switch self {
            case .noFileSelected:
                return "No file was selected"
            case .invalidFileFormat:
                return "Invalid backup file format. Please select a valid Heirloom export file."
            case .fileAccessDenied:
                return "Unable to access the file. Please try selecting it again."
            case .fileNotFound:
                return "The selected file no longer exists. If you exported to a temporary location, please save the export to Files app and try again."
            }
        }
    }

    // MARK: - Import Data Structures (matching export formats)

    // New DataExportView format
    private struct ExportData: Codable {
        let exportDate: Date
        let appVersion: String
        let recipes: [ExportRecipe]
        let privacyConsent: ExportPrivacyConsent
    }

    private struct ExportRecipe: Codable {
        let id: String
        let title: String
        let ingredients: [String]
        let instructions: [String]
        let servings: String?
        let prepTime: String?
        let cookTime: String?
        let notes: String?
        let dateAdded: Date
        let timesCooked: Int
        let isFavorite: Bool
        let sourceType: String?
        let sourceURL: String?
    }

    private struct ExportPrivacyConsent: Codable {
        let hasSharingConsent: Bool
        let hasAnalyticsConsent: Bool
        let consentDate: Date?
        let policyVersion: String
    }

    // Legacy RecipeExporter format (from Settings export)
    private struct LegacyRecipeExport: Codable {
        let metadata: LegacyExportMetadata
        let recipes: [LegacyExportableRecipe]
    }

    private struct LegacyExportMetadata: Codable {
        let exportDate: String
        let appVersion: String
        let recipeCount: Int
    }

    private struct LegacyExportableRecipe: Codable {
        let id: String
        let title: String
        let ingredients: [String]
        let instructions: [String]
        let collectionName: String?
        let isHeritage: Bool
        let createdDate: String
        let modifiedDate: String
        let source: String?
        let prepTime: String?
        let cookTime: String?
        let servings: String?
        let notes: String?
        let imageFileName: String? // NEW: For sidecar image restoration
    }

    private func handleAddNormalSample() {
        // Pick any recipe from the full library
        guard let sampleRecipe = SampleRecipeLibrary.all.randomElement() else { return }

        Task {
            await createSampleRecipe(from: sampleRecipe)
        }
    }

    private func createSampleRecipe(from sampleRecipe: SampleRecipeData) async {
        let sampleData = sampleRecipe.recipe
        let imageStorageService = ServiceContainer.shared.resolve(ImageStorageService.self)

        // Create a unique title variation by checking existing recipes
        var finalTitle = sampleData.title
        let existingTitles = allRecipes.map { $0.title }
        if existingTitles.contains(sampleData.title) {
            // Add a variation number if duplicate exists
            var counter = 2
            while existingTitles.contains("\(sampleData.title) (\(counter))") {
                counter += 1
            }
            finalTitle = "\(sampleData.title) (\(counter))"
        }

        // Create a NEW Recipe object
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

        // Insert recipe immediately and show picker
        await MainActor.run {
            modelContext.insert(recipe)
            try? modelContext.save()

            // Show collection picker immediately (don't wait for ingredients)
            generatedRecipe = recipe
            showCollectionPicker = true

            // Parse and add ingredients in background (non-blocking)
            Task {
                let aiIngredientParser = ServiceContainer.shared.resolve(AIIngredientParser.self)
                do {
                    let parsedResults = try await aiIngredientParser.parseBatch(sampleRecipe.ingredients)
                    await MainActor.run {
                        for (index, ingredientText) in sampleRecipe.ingredients.enumerated() {
                            let parsed = parsedResults[index]
                            let category = GroceryCategory.categorize(parsed.name)
                            let ingredient = Ingredient(
                                originalText: ingredientText,
                                name: parsed.name,
                                quantity: parsed.quantity,
                                unit: parsed.unit,
                                category: category,
                                orderIndex: index
                            )
                            ingredient.recipe = recipe
                            modelContext.insert(ingredient)
                        }
                        try? modelContext.save()
                        Log.debug("Background ingredient parsing completed for sample recipe", category: .general)
                    }
                } catch {
                    Log.error("Failed to parse ingredients for sample recipe", category: .general, metadata: ["error": error.localizedDescription])
                }
            }
        }
    }
}

// MARK: - Collection Row

struct CollectionRow: View {
    let collection: RecipeCollection
    var totalRecipeCount: Int? = nil // For "All Recipes" collection
    // TODO: Re-enable for theme unlocking in Phase A3
    // @State private var unlockTracker: ThemeUnlockTracker?

    @Environment(\.modelContext) private var modelContext
    @Query private var allRecipes: [Recipe] // Force context refresh

    private var displayCount: Int {
        // For "All Recipes" collection, show total count from parameter
        if collection.isAllRecipes, let count = totalRecipeCount {
            return count
        }
        // TODO: Re-implement for theme collections in Phase A3
        // For theme collections, show unlocked count only
        // if collection.type == .theme {
        //     guard let tracker = unlockTracker else { return 0 }
        //     let recipes = collection.recipes ?? []
        //     return recipes.filter { tracker.isUnlocked($0) }.count
        // }
        // For user collections, force refresh and use relationship count
        modelContext.processPendingChanges()
        return collection.recipes?.count ?? 0
    }

    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Icon (with subtle distinction for heritage)
            Image(systemName: collection.iconName)
                .font(HeirloomFonts.title2)
                .fontWeight(collection.isHeritageCollection ? .semibold : .regular)
                .foregroundStyle(collection.swiftUIColor)
                .frame(width: 32)

            // Collection info
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("\(displayCount) recipe\(displayCount == 1 ? "" : "s")")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.charcoal.opacity(0.3))
        }
        .padding(HeirloomSpacing.md)
        .background(
            // Subtle background tint for heritage collections
            collection.isHeritageCollection
                ? collection.swiftUIColor.opacity(0.03)
                : Color(hex: "#F8F8F8")
        )
        .cornerRadius(HeirloomSpacing.cardCornerRadius)
        .onAppear {
            // TODO: Re-enable for Phase A3
            // if unlockTracker == nil {
            //     unlockTracker = ServiceContainer.shared.resolve(ThemeUnlockTracker.self)
            // }
        }
    }
}

// MARK: - Recipe Card with Collection Tags

/// Recipe card that shows which collections the recipe belongs to
/// Used in global search results
struct RecipeCardWithCollectionTags: View {
    let recipe: Recipe

    private var recipeCollections: [RecipeCollection] {
        (recipe.collections ?? []).filter { !$0.isAllRecipes }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Standard recipe card (reuse existing component)
            RecipeCardView(recipe: recipe)

            // Collection tags (if any)
            if !recipeCollections.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(recipeCollections, id: \.id) { collection in
                            CollectionTag(collection: collection)
                        }
                    }
                }
            }
        }
    }
}

/// Small collection badge/tag
struct CollectionTag: View {
    let collection: RecipeCollection

    var body: some View {
        HStack(spacing: HeirloomSpacing.xs) {
            Image(systemName: collection.iconName)
                .font(.system(size: 10))
            Text(collection.name)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(collection.swiftUIColor.opacity(0.15))
        .foregroundStyle(collection.swiftUIColor)
        .cornerRadius(8)
    }
}

#Preview {
    CollectionsListView()
        .modelContainer(for: RecipeCollection.self, inMemory: true)
}
