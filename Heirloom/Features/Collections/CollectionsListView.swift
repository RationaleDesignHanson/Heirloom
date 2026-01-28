import SwiftUI
import SwiftData
import FirebaseFirestore

/// Main Collections tab view showing heritage and user collections
struct CollectionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationService: FirebaseNotificationService
    @EnvironmentObject private var tabCoordinator: TabNavigationCoordinator
    @EnvironmentObject private var themeUnlockTracker: ThemeUnlockTracker
    @Query(sort: \RecipeCollection.createdDate) private var allCollections: [RecipeCollection]
    @Query(sort: \Recipe.dateAdded, order: .reverse) private var allRecipes: [Recipe]
    @Query(sort: \RecipeTheme.sortOrder) private var allThemes: [RecipeTheme]

    // Global recipe search state
    @State private var searchText = ""

    @State private var showCreateCollection = false
    @State private var showAddRecipe = false
    @State private var showImportRecipe = false
    @State private var showBulkImport = false
    @State private var showCookbookScanner = false
    @State private var showVideoImport = false
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

    private var subscriptionManager: SubscriptionManager { ServiceContainer.shared.resolve(SubscriptionManager.self) }
    private var collectionImageGenerator: CollectionImageGenerator { ServiceContainer.shared.resolve(CollectionImageGenerator.self) }
    private var imageStorageService: ImageStorageService { ServiceContainer.shared.resolve(ImageStorageService.self) }
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }

    // MARK: - Filtered Collections

    /// Collections visible on the main list (no empty, no system)
    private var visibleCollections: [RecipeCollection] {
        allCollections
            .filter { $0.isVisibleInMainList }
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
    var themeCollections: [RecipeCollection] {
        visibleCollections.filter { collection in
            collection.type == .theme &&
            themeUnlockTracker.selectedThemeIds.contains(collection.sourceTheme?.firebaseId ?? "")
        }
    }

    /// My Collections (shown BEFORE themes) - includes all import types and user-created
    private var myCollections: [RecipeCollection] {
        visibleCollections.filter { collection in
            let isRelevantType = collection.type == .fromFriends ||
                               collection.type == .videoImports ||
                               collection.type == .webImports ||
                               collection.type == .photoImports ||
                               collection.type == .cookbook ||
                               collection.type == .userCreated

            // For auto-generated collections, only show if they have recipes
            let shouldShow: Bool
            switch collection.type {
            case .webImports, .videoImports, .cookbook, .photoImports, .fromFriends:
                shouldShow = (collection.recipes?.count ?? 0) > 0
            case .userCreated, .theme:
                shouldShow = true // Always show user-created and theme collections
            default:
                shouldShow = false
            }

            return isRelevantType && shouldShow
        }
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

        return allRecipes.filter { recipe in
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
                // Fixed banners at top (don't scroll)
                VideoProcessingBottomBanner()
                ImportProgressBottomBanner()

                // Scrollable content below
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
            }
            .navigationTitle("Collections")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search recipes")
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showCreateCollection) {
                CollectionEditorView()
                    .environmentObject(tabCoordinator)
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
                    .environmentObject(notificationService)
                    .environmentObject(tabCoordinator)
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
            .navigationDestination(for: RecipeCollection.self) { collection in
                CollectionDetailView(collection: collection)
                    .environmentObject(notificationService)
                    .environmentObject(tabCoordinator)
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
            .onAppear(perform: handleOnAppear)
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
                    GridItem(.flexible(), spacing: HeirloomSpacing.gridSpacing)
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
            // My Collections section (FIRST - appears above themes)
            if !myCollections.isEmpty {
                myCollectionsSection
            }

            // Theme collections section (SECOND - appears below My Collections)
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

    // MARK: - Theme Section

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            // Trial progress banner
            if themeUnlockTracker.isInTrialPeriod {
                TrialProgressBanner()
                    .padding(.bottom, HeirloomSpacing.sm)
            }

            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(UXCopy.Collections.discoverySectionTitle)
                        .font(HeirloomFonts.title3)
                        .foregroundStyle(HeirloomColors.primaryText)
                }

                Spacer()

                // New unlocks badge
                if themeUnlockTracker.hasNewUnlocks {
                    Text(UXCopy.Unlock.newBadge)
                        .font(HeirloomFonts.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(HeirloomColors.tomato)
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                }
            }

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
                .contextMenu {
                    Button {
                        Task {
                            await generateBackgroundForCollection(collection)
                        }
                    } label: {
                        Label("Generate with AI", systemImage: "sparkles")
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
            // Section header
            Text("My Collections")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            // Collection cards
            ForEach(myCollections) { collection in
                NavigationLink(value: collection) {
                    UnifiedCollectionCard(
                        collection: collection,
                        variant: .standard(
                            onAddRecipeTap: (collection.recipes?.count ?? 0) == 1
                                ? { handleAddRecipeToCollection(collection) }
                                : nil
                        )
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        Task {
                            await generateBackgroundForCollection(collection)
                        }
                    } label: {
                        Label("Generate with AI", systemImage: "sparkles")
                    }
                    .disabled(isGeneratingBackground)

                    Button {
                        selectedCollectionForSettings = collection
                    } label: {
                        Label("Collection Settings", systemImage: "gear")
                    }

                    if !collection.isSystemCollection {
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
                showCreateCollection = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Create Collection")
                }
                .font(HeirloomFonts.bodyBold)
                .padding(.horizontal, HeirloomSpacing.lg)
                .padding(.vertical, HeirloomSpacing.md)
                .background(HeirloomColors.tomato)
                .foregroundStyle(.white)
                .cornerRadius(HeirloomSpacing.cardCornerRadius)
            }

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
                onAddRecipe: handleAddRecipe,
                onImportRecipe: handleImportRecipe,
                onBulkImport: handleBulkImport,
                onCookbookScanner: handleCookbookScanner,
                onVideoImport: handleVideoImport,
                onAddCollection: handleAddCollection,
                onAddNormalSample: handleAddNormalSample,
                onCollectionSettings: nil // Not applicable in collections list view
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

        // Show coach mark after 10 seconds if not seen before
        if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasSeenRecipeCoachMark) {
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasSeenRecipeCoachMark) {
                    showRecipeCoachMark = true
                }
            }
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

            // Clear the deleted collection reference
            await MainActor.run {
                collectionToDelete = nil
            }

        } catch {
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            await MainActor.run {
                toastManager.error(title: "Failed to delete collection", message: error.localizedDescription)
                generator.notificationOccurred(.error)
            }
        }
    }

    private func deleteCollectionAndRecipes(_ collection: RecipeCollection) async {
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

            // Clear the deleted collection reference
            await MainActor.run {
                collectionToDelete = nil
            }

        } catch {
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            await MainActor.run {
                toastManager.error(title: "Failed to delete", message: error.localizedDescription)
                generator.notificationOccurred(.error)
            }
        }
    }

    // MARK: - Toolbar Action Handlers

    private func handleAddRecipe() {
        tabCoordinator.willCreateRecipe(from: .collectionsTab)
        showAddRecipe = true
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

    /// Handle tap on + affordance in collection card - routes to appropriate ingress based on collection type
    private func handleAddRecipeToCollection(_ collection: RecipeCollection) {
        // Store selected collection for adding recipe
        selectedCollection = collection

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Route to appropriate ingress based on collection type
        switch collection.type {
        case .webImports:
            handleImportRecipe() // Opens RecipeImportView
            Log.info("Opening web import from + affordance", category: .collections)

        case .videoImports:
            handleVideoImport() // Opens UnifiedVideoImportView
            Log.info("Opening video import from + affordance", category: .collections)

        case .cookbook:
            handleCookbookScanner() // Opens CookbookScannerView
            Log.info("Opening cookbook scanner from + affordance", category: .collections)

        case .photoImports:
            handleBulkImport() // Opens BulkImportView
            Log.info("Opening bulk import from + affordance", category: .collections)

        case .userCreated:
            // For user-created collections, show the standard add menu
            handleAddRecipe()
            Log.info("Opening add recipe menu from + affordance", category: .collections)

        case .fromFriends:
            // Shared collections shouldn't show + affordance
            // But if somehow tapped, just navigate to collection
            Log.warning("+ affordance tapped on fromFriends collection", category: .collections)

        case .theme:
            // Theme collections use different card, but handle gracefully
            handleAddRecipe()
            Log.info("Opening add recipe menu from theme collection", category: .collections)

        default:
            // Fallback to standard add menu
            handleAddRecipe()
            Log.info("Opening add recipe menu (default)", category: .collections)
        }

        Log.info("Add recipe tapped from collection card", category: .collections, metadata: [
            "collectionId": collection.id.uuidString,
            "collectionType": collection.type.rawValue
        ])
    }

    private func generateBackgroundForCollection(_ collection: RecipeCollection) async {
        guard !isGeneratingBackground else {
            toastManager.info(title: "Generation in Progress", message: "Please wait for the current generation to finish")
            return
        }

        isGeneratingBackground = true
        generatingCollectionId = collection.id

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
                generatingCollectionId = nil
                toastManager.success(title: "Background Generated", message: "AI created a custom image for \(collection.name)")
            }
        } catch {
            await MainActor.run {
                isGeneratingBackground = false
                generatingCollectionId = nil
                toastManager.error(title: "Generation Failed", message: error.localizedDescription)
            }
        }
    }

    private func handleAddCollection() {
        tabCoordinator.willCreateCollection(from: .collectionsTab)
        showCreateCollection = true
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
