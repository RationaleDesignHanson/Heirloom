import SwiftUI
import SwiftData
import FirebaseFirestore

/// Main Collections tab view showing heritage and user collections
struct CollectionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationService: FirebaseNotificationService
    @EnvironmentObject private var tabCoordinator: TabNavigationCoordinator
    @Query(sort: \RecipeCollection.createdDate) private var allCollections: [RecipeCollection]
    @Query(sort: \Recipe.dateAdded, order: .reverse) private var allRecipes: [Recipe]

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
    @State private var unlockTracker: HeritageUnlockTracker?
    @State private var isDownloadingRecipes = false
    @State private var downloadProgress: String = ""
    private var subscriptionManager: SubscriptionManager { ServiceContainer.shared.resolve(SubscriptionManager.self) }

    // Filter heritage collections (founding collections)
    var heritageCollections: [RecipeCollection] {
        allCollections.filter { $0.isHeritageCollection }
    }

    // Filter blind box collections (unrevealed)
    var blindBoxCollections: [RecipeCollection] {
        heritageCollections.filter { $0.isBlindBox && !$0.isRevealed }
    }

    // Filter revealed heritage collections
    // Show collections that are either:
    // 1. Part of the blind box system and revealed
    // 2. Have at least 1 unlocked recipe (discovered through daily unlocks)
    var revealedHeritageCollections: [RecipeCollection] {
        guard let tracker = unlockTracker else {
            return heritageCollections.filter { $0.isBlindBox && $0.isRevealed }
        }

        return heritageCollections.filter { collection in
            // Show if it's a revealed blind box AND has unlocked recipes
            if collection.isBlindBox && collection.isRevealed {
                let recipes = collection.recipes ?? []
                let unlockedCount = recipes.filter { tracker.isUnlocked($0) }.count
                return unlockedCount > 0
            }

            // Show if it has at least 1 unlocked recipe (non-blind box heritage collections)
            let recipes = collection.recipes ?? []
            let unlockedCount = recipes.filter { tracker.isUnlocked($0) }.count
            return unlockedCount > 0
        }
    }

    // Filter user collections (non-system, non-heritage)
    var userCollections: [RecipeCollection] {
        allCollections.filter { !$0.isSystemCollection && !$0.isHeritageCollection }
    }

    // System collections (All Recipes, Favorites, Quick Meals, etc.)
    var systemCollections: [RecipeCollection] {
        let filtered = allCollections.filter { $0.isSystemCollection && !$0.isHeritageCollection }

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
            .sheet(isPresented: $showHeritageUnlock) {
                HeritageUnlockView()
                    .presentationDetents([.large])
            }
            .navigationDestination(item: $selectedCollection) { collection in
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

    // MARK: - Heritage Schedule Metadata Helper

    /// Download Heritage recipes using the EXACT same persistence logic as autoRevealBlindBoxesIfNeeded (which works)
    /// This is the shared code path for both blind box unlock and recovery
    private func downloadHeritageRecipesWithPersistence() async {
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

            // CRITICAL: Mark recipes as unlocked in HeritageUnlockTracker
            // This ensures the UI shows them as unlocked
            await MainActor.run {
                let tracker = ServiceContainer.shared.resolve(HeritageUnlockTracker.self)
                for recipe in recipes {
                    tracker.unlockedRecipeIds.insert(recipe.id.uuidString)
                }
                tracker.lastUnlockDate = Date()
                tracker.saveToStorage()

                Log.info("Marked recipes as unlocked in tracker", category: .heritage, metadata: [
                    "unlockedCount": tracker.unlockedRecipeIds.count
                ])
            }

            // CRITICAL: Store heritage schedule metadata locally for recovery system
            let downloadedRecipeIds = recipes.compactMap { $0.heritageRecipeId }
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
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            if heritageCollections.isEmpty && systemCollections.isEmpty && userCollections.isEmpty {
                emptyUserCollectionsView
            } else {
                LazyVStack(spacing: HeirloomSpacing.lg) {
                    // System collections (Favorites, Quick Meals, etc.) - shown first
                    ForEach(systemCollections, id: \.id) { collection in
                        NavigationLink(value: collection) {
                            CollectionCardView(collection: collection)
                        }
                        .buttonStyle(.plain)
                    }

                    // User collections (with delete context menu) - shown second
                    ForEach(userCollections, id: \.id) { collection in
                        NavigationLink(value: collection) {
                            CollectionCardView(collection: collection)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                collectionToDelete = collection
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete Collection", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, HeirloomSpacing.lg)

                    // Post-trial banner (if trial expired and has heritage content)
                    if subscriptionManager.isTrialExpired && !subscriptionManager.isPremium && !heritageCollections.isEmpty,
                       let tracker = unlockTracker {
                        postTrialBanner(unlockedCount: tracker.totalUnlockedCount)
                    }

                    // Empty heritage state - show download button when no collections exist
                    if heritageCollections.isEmpty && unlockTracker?.hasUnlocksAvailableToday == true {
                        emptyHeritageState
                    }

                    // Show single mystery collection button that reveals all blind boxes (legacy - won't show since seeding disabled)
                    if let firstBlindBox = blindBoxCollections.first {
                        BlindBoxCollectionRow(collection: firstBlindBox) {
                            revealBlindBox(firstBlindBox)
                        }
                    }

                    // Revealed heritage collections - shown last
                    ForEach(revealedHeritageCollections, id: \.id) { collection in
                        CollectionRow(collection: collection)
                            .onTapGesture {
                                // Show coach mark on first tap if not seen
                                if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasSeenRecipeCoachMark) {
                                    showRecipeCoachMark = true
                                } else {
                                    selectedCollection = collection
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    collectionToDelete = collection
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete Collection", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal, HeirloomSpacing.md)
            }
        }
    }

    // MARK: - Post-Trial Banner

    @ViewBuilder
    private func postTrialBanner(unlockedCount: Int) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)

                Text("You unlocked \(unlockedCount) heritage recipes")
                    .font(HeirloomFonts.body)
                    .fontWeight(.semibold)
            }

            Text("They're yours forever! Upgrade to unlock the remaining \(100 - unlockedCount) recipes or continue discovering them at $0.99 each.")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(.secondary)

            HStack(spacing: HeirloomSpacing.sm) {
                Button {
                    // Show PaywallView
                    showHeritageUnlock = true
                } label: {
                    Text("Upgrade to Premium")
                        .font(HeirloomFonts.caption1)
                        .fontWeight(.semibold)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .padding(.horizontal, HeirloomSpacing.md)
                        .padding(.vertical, HeirloomSpacing.sm)
                        .background(HeirloomColors.tomato)
                        .cornerRadius(8)
                }

                Button {
                    // Show individual purchase option
                    showHeritageUnlock = true
                } label: {
                    Text("Buy Individually")
                        .font(HeirloomFonts.caption1)
                        .fontWeight(.semibold)
                        .foregroundStyle(HeirloomColors.tomato)
                        .padding(.horizontal, HeirloomSpacing.md)
                        .padding(.vertical, HeirloomSpacing.sm)
                        .background(HeirloomColors.cream)
                        .cornerRadius(8)
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .fill(Color.orange.opacity(0.1))
        )
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Heritage unlock icon with trial countdown
        ToolbarItem(placement: .topBarTrailing) {
            if let tracker = unlockTracker, (tracker.totalRecipesRemaining > 0 || tracker.unlockedRecipeIds.count > 0) {
                Button {
                    showHeritageUnlock = true
                } label: {
                    HStack(spacing: HeirloomSpacing.xs) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.orange)

                        if subscriptionManager.isInTrial, let daysRemaining = subscriptionManager.daysRemaining, daysRemaining > 0 {
                            Text("\(daysRemaining)d")
                                .font(HeirloomFonts.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .accessibilityLabel("Heritage Collection - \(subscriptionManager.isInTrial ? "\(subscriptionManager.daysRemaining ?? 0) days remaining" : "")")
            }
        }

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
                onAddHeritageSample: handleAddHeritageSample
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
        // Initialize heritage unlock tracker
        if unlockTracker == nil {
            unlockTracker = ServiceContainer.shared.resolve(HeritageUnlockTracker.self)
        }

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

        // Check immediately (no delay needed - cache is instant)
        Task {
            await checkAndPromoteFromCache()
        }
    }

    /// Check durable cache vs SwiftData and promote missing recipes
    /// The cache survives force-quit because it's stored in UserDefaults with synchronize()
    private func checkAndPromoteFromCache() async {
        guard let authService = ServiceContainer.shared.resolveOptional(FirebaseAuthService.self),
              authService.isAuthenticated else {
            Log.debug("Cannot verify Heritage - not authenticated", category: .heritage)
            return
        }

        // Load cached recipes from durable storage
        let cache = ServiceContainer.shared.resolve(HeritageRecipeCache.self)
        let cachedRecipes = cache.getCachedRecipes()

        guard !cachedRecipes.isEmpty else {
            Log.debug("No cached recipes found - user hasn't downloaded Heritage yet", category: .heritage)
            return
        }

        // Count local Heritage recipes in SwiftData
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isHeritageRecipe == true }
        )
        let localCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        let cachedCount = cachedRecipes.count

        Log.info("Heritage cache verification", category: .heritage, metadata: [
            "cachedCount": cachedCount,
            "localCount": localCount
        ])
        DeviceLogger.shared.log("📊 [Heritage] Cache: \(cachedCount), SwiftData: \(localCount)")

        // If SwiftData has fewer recipes than cache, promote missing ones
        if localCount < cachedCount {
            Log.warning("🚨 Heritage recipes missing from SwiftData! Promoting from cache...", category: .heritage, metadata: [
                "cached": cachedCount,
                "found": localCount,
                "missing": cachedCount - localCount
            ])
            DeviceLogger.shared.log("🚨 [Heritage] \(cachedCount - localCount) recipes missing! Promoting from cache...")

            await promoteCachedRecipes(cachedRecipes)
        } else {
            Log.info("✅ Heritage recipes intact", category: .heritage, metadata: ["count": localCount])
            DeviceLogger.shared.log("✅ [Heritage] All \(localCount) recipes present")
        }
    }

    /// Promote cached recipes to SwiftData by re-downloading from Firebase
    /// Uses cache metadata to identify which recipes to download
    private func promoteCachedRecipes(_ cachedRecipes: [String: HeritageRecipeCache.CachedRecipe]) async {
        guard let authService = ServiceContainer.shared.resolveOptional(FirebaseAuthService.self),
              authService.isAuthenticated else {
            Log.error("Cannot promote recipes - not authenticated", category: .heritage)
            return
        }

        // Get existing recipe IDs in SwiftData
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isHeritageRecipe == true }
        )
        let existingRecipes = (try? modelContext.fetch(descriptor)) ?? []
        let existingIds = Set(existingRecipes.compactMap { $0.heritageRecipeId })

        // Find missing recipes (in cache but not in SwiftData)
        let missingRecipes = cachedRecipes.values.filter { !existingIds.contains($0.heritageRecipeId) }

        Log.info("Promoting missing recipes from cache", category: .heritage, metadata: [
            "missingCount": missingRecipes.count
        ])

        // Re-download missing recipes using HeritageOnDemandService
        let onDemandService = HeritageOnDemandService(
            modelContext: modelContext,
            firebaseAuth: authService
        )

        var promotedCount = 0
        for cachedRecipe in missingRecipes {
            do {
                // Download recipe from Firebase using its heritageRecipeId
                let recipe = try await onDemandService.downloadRecipe(recipeId: cachedRecipe.heritageRecipeId)
                promotedCount += 1

                Log.debug("Promoted recipe from cache", category: .heritage, metadata: [
                    "heritageRecipeId": cachedRecipe.heritageRecipeId,
                    "title": recipe.title
                ])
            } catch {
                Log.error("Failed to promote recipe from cache", category: .heritage, metadata: [
                    "heritageRecipeId": cachedRecipe.heritageRecipeId,
                    "error": error.localizedDescription
                ])
            }
        }

        // Save all promoted recipes
        await MainActor.run {
            do {
                try modelContext.save()
                Log.info("✅ Promoted recipes from cache", category: .heritage, metadata: [
                    "promotedCount": promotedCount,
                    "expectedCount": missingRecipes.count
                ])
                DeviceLogger.shared.log("✅ [Heritage] Promoted \(promotedCount)/\(missingRecipes.count) recipes from cache")
            } catch {
                Log.error("Failed to save promoted recipes", category: .heritage, error: error)
                DeviceLogger.shared.log("❌ [Heritage] Promotion save failed: \(error.localizedDescription)")
            }
        }
    }

    private func seedBlindBoxesIfNeeded() {
        // Only seed if user just completed onboarding
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let hasSeenBlindBoxes = UserDefaults.standard.bool(forKey: "hasSeenBlindBoxes")

        if hasCompletedOnboarding && !hasSeenBlindBoxes {
            let seeder = BlindBoxSeeder(modelContext: modelContext)
            do {
                try seeder.seedBlindBoxes()
                Log.info("Blind boxes created after onboarding", category: .ui)
            } catch {
                Log.error("Failed to seed blind boxes", category: .ui, metadata: ["error": error.localizedDescription])
            }
        }
    }

    private func revealBlindBox(_ collection: RecipeCollection) {
        // Reveal ALL blind boxes at once with a single tap
        let allBlindBoxes = heritageCollections.filter { $0.isBlindBox }

        for blindBox in allBlindBoxes {
            blindBox.isRevealed = true
            blindBox.revealedDate = Date()
        }

        do {
            try modelContext.save()

            // Initialize SubscriptionManager's trial (if not already started)
            let subscriptionManager = ServiceContainer.shared.resolve(SubscriptionManager.self)
            subscriptionManager.initializeTrialOnBlindBoxReveal()

            // Initialize heritage unlock tracker
            let unlockTracker = ServiceContainer.shared.resolve(HeritageUnlockTracker.self)

            // Start trial period if not started
            if unlockTracker.trialStartDate == nil {
                unlockTracker.startTrialPeriod()
            }

            // Download initial recipes using the EXACT same code path as autoRevealBlindBoxesIfNeeded (which WORKS)
            Task {
                await downloadHeritageRecipesWithPersistence()
            }
        } catch {
            Log.error("Failed to reveal blind boxes", category: .ui, metadata: ["error": error.localizedDescription])
        }
    }

    // MARK: - Empty Heritage State

    private var emptyHeritageState: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            // Icon
            Image(systemName: "gift.fill")
                .font(.system(size: 60))
                .foregroundStyle(HeirloomColors.familyGreen)

            // Title
            Text("Daily Heritage Recipes")
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.charcoal)

            // Description
            Text("Unlock 7 classic recipes today")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)

            // Trial countdown badge
            if let daysRemaining = unlockTracker?.daysRemainingInTrial {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text("\(daysRemaining) days left in trial")
                        .font(HeirloomFonts.caption1)
                }
                .foregroundStyle(HeirloomColors.familyGreen)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(HeirloomColors.familyGreen.opacity(0.1))
                )
            }

            // Download Button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                downloadTodaysRecipes()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Download Today's Recipes")
                }
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(HeirloomColors.familyGreen)
                .cornerRadius(12)
            }
        }
        .padding(40)
    }

    private func downloadTodaysRecipes() {
        // Initialize trial period if not started
        if let tracker = unlockTracker, tracker.trialStartDate == nil {
            tracker.startTrialPeriod()
        }

        // Initialize trial subscription if needed
        subscriptionManager.initializeTrialOnBlindBoxReveal()

        // Download recipes using the same persistence logic
        Task {
            await downloadHeritageRecipesWithPersistence()
        }
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

    private func handleAddHeritageSample() {
        Task {
            await createHeritageRecipe()
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

    // MARK: - Heritage Recipe Types

    private struct HeritageRecipeJSON: Codable {
        let id: String
        let title: String
        let heritageCollectionId: String
        let servings: String?
        let prepTime: String?
        let cookTime: String?
        let ingredients: [HeritageIngredientJSON]
        let instructions: [String]
        let description: String?
        let imageName: String?
    }

    private struct HeritageIngredientJSON: Codable {
        let originalText: String
        let name: String
        let quantity: Double?
        let unit: String?
    }

    private func createHeritageRecipe() async {
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
        let existingTitles = allRecipes.map { $0.title }

        // Filter out recipes that already exist
        let availableRecipes = heritageData.recipes.filter { !existingTitles.contains($0.title) }

        // Pick a random recipe that doesn't already exist
        guard let heritageRecipe = availableRecipes.randomElement() ?? heritageData.recipes.randomElement() else {
            return
        }

        let titleExists = availableRecipes.isEmpty

        await createHeritageRecipeFromJSON(heritageRecipe, titleExists: titleExists)
    }

    private func createHeritageRecipeFromJSON(_ json: HeritageRecipeJSON, titleExists: Bool) async {
        let imageStorageService = ServiceContainer.shared.resolve(ImageStorageService.self)

        await MainActor.run {
            let recipe = Recipe()
            recipe.title = titleExists ? "\(json.title) (\(Int.random(in: 2...100)))" : json.title
            recipe.servings = json.servings
            recipe.prepTime = json.prepTime
            recipe.cookTime = json.cookTime
            recipe.notes = json.description
            recipe.instructions = json.instructions
            recipe.isHeritageRecipe = true

            modelContext.insert(recipe)

            // Add ingredients
            for (index, ing) in json.ingredients.enumerated() {
                let category = GroceryCategory.categorize(ing.name)
                let ingredient = Ingredient(
                    originalText: ing.originalText,
                    name: ing.name,
                    quantity: ing.quantity,
                    unit: ing.unit,
                    category: category,
                    orderIndex: index
                )
                ingredient.recipe = recipe
                modelContext.insert(ingredient)
            }

            try? modelContext.save()

            // Show collection picker immediately (don't wait for image)
            generatedRecipe = recipe
            showCollectionPicker = true

            // Save heritage image in background if available
            if let imageName = json.imageName,
               let image = UIImage(named: imageName) {
                Task {
                    do {
                        let fileName = try await imageStorageService.saveImage(image, recipeId: recipe.id)
                        await MainActor.run {
                            recipe.imageFileName = fileName
                            try? modelContext.save()
                        }
                    } catch {
                        Log.error("Failed to save heritage recipe image", category: .storage, metadata: ["error": error.localizedDescription])
                    }
                }
            }
        }
    }
}

// MARK: - Collection Row

struct CollectionRow: View {
    let collection: RecipeCollection
    var totalRecipeCount: Int? = nil // For "All Recipes" collection
    @State private var unlockTracker: HeritageUnlockTracker?

    @Environment(\.modelContext) private var modelContext
    @Query private var allRecipes: [Recipe] // Force context refresh

    private var displayCount: Int {
        // For "All Recipes" collection, show total count from parameter
        if collection.isAllRecipes, let count = totalRecipeCount {
            return count
        }
        // For heritage collections, show unlocked count only
        if collection.isHeritageCollection {
            guard let tracker = unlockTracker else { return 0 }
            let recipes = collection.recipes ?? []
            return recipes.filter { tracker.isUnlocked($0) }.count
        }
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
            if unlockTracker == nil {
                unlockTracker = ServiceContainer.shared.resolve(HeritageUnlockTracker.self)
            }
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
