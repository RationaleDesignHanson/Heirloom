import SwiftUI
import SwiftData
import FirebaseFirestore

/// Discovery feed showing trending, new, and popular public recipes
struct DiscoveryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var discoveryService: DiscoveryServiceProtocol {
        ServiceContainer.shared.resolve((any DiscoveryServiceProtocol).self)
    }

    private var analytics: AnalyticsService {
        ServiceContainer.shared.resolve(AnalyticsService.self)
    }

    @State private var selectedTab: DiscoveryTab = .trending
    @State private var trendingRecipes: [PublicRecipe] = []
    @State private var newRecipes: [PublicRecipe] = []
    @State private var popularRecipes: [PublicRecipe] = []

    @State private var searchQuery: String = ""
    @State private var searchResults: [PublicRecipe] = []
    @State private var isSearching: Bool = false

    @State private var isLoading = false
    @State private var errorMessage: String?

    // Pagination support
    @State private var trendingLastDoc: DocumentSnapshot?
    @State private var newLastDoc: DocumentSnapshot?
    @State private var popularLastDoc: DocumentSnapshot?
    @State private var searchLastDoc: DocumentSnapshot?
    @State private var isLoadingMore = false
    @State private var hasMoreResults = true

    // Navigation
    @State private var navigationPath = NavigationPath()
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                // Tab selector (only show when not searching)
                if !isSearching {
                    tabSelector
                }

                // Content
                if isLoading && currentContent.isEmpty {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if currentContent.isEmpty {
                    emptyStateView
                } else {
                    feedContent
                }
            }
            .navigationTitle(isSearching ? "Search Results" : "Discover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityHint("Open app settings")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(HeirloomColors.primaryText)
                    }
                    .accessibilityLabel("Discover Options")
                }
            }
            .navigationDestination(for: String.self) { publicRecipeId in
                // Navigate to PublicRecipeDetailView
                PublicRecipeDetailView(publicRecipeId: publicRecipeId)
            }
            .task {
                await loadContent()
            }
            .refreshable {
                await refreshContent()
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(HeirloomColors.secondaryText)

                TextField("Search recipes...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: searchQuery) { _, newValue in
                        handleSearchChange(newValue)
                    }

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        isSearching = false
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(HeirloomColors.warmGray)
                    }
                }
            }
            .padding(HeirloomSpacing.sm)
            .background(HeirloomColors.cream)
            .cornerRadius(10)
        }
        .padding(.horizontal, HeirloomSpacing.md)
        .padding(.vertical, HeirloomSpacing.sm)
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        Picker("Discovery Tab", selection: $selectedTab) {
            ForEach(DiscoveryTab.allCases, id: \.self) { tab in
                Text(tab.displayName)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, HeirloomSpacing.md)
        .padding(.vertical, HeirloomSpacing.sm)
        .onChange(of: selectedTab) { _, _ in
            Task {
                await loadContent()
            }
        }
    }

    // MARK: - Feed Content

    private var feedContent: some View {
        ScrollView {
            LazyVStack(spacing: HeirloomSpacing.md) {
                ForEach(currentContent, id: \.id) { recipe in
                    PublicRecipeCard(
                        recipe: recipe,
                        tab: selectedTab,
                        onTapCard: {
                            navigationPath.append(recipe.id)
                        },
                        onSave: {
                            Task {
                                await saveRecipe(recipe)
                            }
                        }
                    )
                }

                // Load more button
                if hasMoreResults && !isLoadingMore && !currentContent.isEmpty {
                    Button {
                        Task {
                            await loadMore()
                        }
                    } label: {
                        HStack {
                            Text("Load More")
                                .font(HeirloomFonts.bodyBold)

                            if isLoadingMore {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .foregroundStyle(HeirloomColors.tomato)
                        .padding()
                    }
                }
            }
            .padding(HeirloomSpacing.md)
        }
        .background(HeirloomColors.appBackground)
    }

    // MARK: - Loading State

    private var loadingView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            ProgressView()
                .scaleEffect(1.5)

            Text(isSearching ? "Searching..." : "Loading \(selectedTab.displayName.lowercased()) recipes...")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error State

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.tomato)

            Text("Failed to Load")
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(message)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HeirloomSpacing.xl)

            Button {
                Task {
                    await refreshContent()
                }
            } label: {
                Text("Try Again")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.buttonTextLight)
                    .padding(.horizontal, HeirloomSpacing.lg)
                    .padding(.vertical, HeirloomSpacing.sm)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: isSearching ? "magnifyingglass" : selectedTab.emptyIcon)
                .font(.system(size: 64))
                .foregroundStyle(HeirloomColors.warmGray)

            Text(isSearching ? "No Results Found" : selectedTab.emptyTitle)
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(isSearching
                ? "Try different keywords or check your spelling."
                : selectedTab.emptyMessage)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HeirloomSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(HeirloomSpacing.xl)
    }

    // MARK: - Computed Properties

    private var currentContent: [PublicRecipe] {
        if isSearching {
            return searchResults
        }

        switch selectedTab {
        case .trending:
            return trendingRecipes
        case .new:
            return newRecipes
        case .popular:
            return popularRecipes
        }
    }

    // MARK: - Search Handling

    @State private var searchTask: Task<Void, Never>?

    private func handleSearchChange(_ query: String) {
        // Cancel previous search task
        searchTask?.cancel()

        // Clear results immediately if query is empty
        if query.isEmpty {
            isSearching = false
            searchResults = []
            return
        }

        // Debounce search (300ms)
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))

            guard !Task.isCancelled else { return }

            await performSearch(query: query)
        }
    }

    private func performSearch(query: String) async {
        guard !query.isEmpty, query.count >= 3 else {
            await MainActor.run {
                isSearching = false
                searchResults = []
            }
            return
        }

        await MainActor.run {
            isSearching = true
            isLoading = true
            errorMessage = nil
        }

        do {
            let (recipes, lastDoc) = try await discoveryService.search(
                query: query,
                limit: 20,
                lastDocument: nil
            )

            await MainActor.run {
                searchResults = recipes
                searchLastDoc = lastDoc
                hasMoreResults = lastDoc != nil
                isLoading = false
            }

            // Track analytics
            analytics.track(event: .searchPerformed, properties: [
                "query": query,
                "results_count": recipes.count
            ])

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }

            Log.error("Search failed", category: .social, metadata: [
                "query": query,
                "error": error.localizedDescription
            ])
        }
    }

    // MARK: - Data Loading

    private func loadContent() async {
        guard !isLoading else { return }

        // Don't reload if searching
        if isSearching { return }

        isLoading = true
        errorMessage = nil

        do {
            switch selectedTab {
            case .trending:
                let (recipes, lastDoc) = try await discoveryService.fetchTrending(
                    limit: 20,
                    lastDocument: nil
                )

                await MainActor.run {
                    trendingRecipes = recipes
                    trendingLastDoc = lastDoc
                    hasMoreResults = lastDoc != nil
                }

                analytics.track(event: .discoveryFeedViewed, properties: [
                    "tab": "trending",
                    "count": recipes.count
                ])

            case .new:
                let (recipes, lastDoc) = try await discoveryService.fetchNew(
                    limit: 20,
                    lastDocument: nil
                )

                await MainActor.run {
                    newRecipes = recipes
                    newLastDoc = lastDoc
                    hasMoreResults = lastDoc != nil
                }

                analytics.track(event: .discoveryFeedViewed, properties: [
                    "tab": "new",
                    "count": recipes.count
                ])

            case .popular:
                let (recipes, lastDoc) = try await discoveryService.fetchPopular(
                    limit: 20,
                    lastDocument: nil
                )

                await MainActor.run {
                    popularRecipes = recipes
                    popularLastDoc = lastDoc
                    hasMoreResults = lastDoc != nil
                }

                analytics.track(event: .discoveryFeedViewed, properties: [
                    "tab": "popular",
                    "count": recipes.count
                ])
            }

            await MainActor.run {
                isLoading = false
            }

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }

            Log.error("Failed to load discovery recipes", category: .social, metadata: [
                "tab": selectedTab.rawValue,
                "error": error.localizedDescription
            ])
        }
    }

    private func loadMore() async {
        guard !isLoadingMore, hasMoreResults else { return }

        isLoadingMore = true

        do {
            if isSearching {
                let (recipes, lastDoc) = try await discoveryService.search(
                    query: searchQuery,
                    limit: 20,
                    lastDocument: searchLastDoc
                )

                await MainActor.run {
                    searchResults.append(contentsOf: recipes)
                    searchLastDoc = lastDoc
                    hasMoreResults = lastDoc != nil
                }

            } else {
                switch selectedTab {
                case .trending:
                    let (recipes, lastDoc) = try await discoveryService.fetchTrending(
                        limit: 20,
                        lastDocument: trendingLastDoc
                    )

                    await MainActor.run {
                        trendingRecipes.append(contentsOf: recipes)
                        trendingLastDoc = lastDoc
                        hasMoreResults = lastDoc != nil
                    }

                case .new:
                    let (recipes, lastDoc) = try await discoveryService.fetchNew(
                        limit: 20,
                        lastDocument: newLastDoc
                    )

                    await MainActor.run {
                        newRecipes.append(contentsOf: recipes)
                        newLastDoc = lastDoc
                        hasMoreResults = lastDoc != nil
                    }

                case .popular:
                    let (recipes, lastDoc) = try await discoveryService.fetchPopular(
                        limit: 20,
                        lastDocument: popularLastDoc
                    )

                    await MainActor.run {
                        popularRecipes.append(contentsOf: recipes)
                        popularLastDoc = lastDoc
                        hasMoreResults = lastDoc != nil
                    }
                }
            }

            await MainActor.run {
                isLoadingMore = false
            }

        } catch {
            await MainActor.run {
                isLoadingMore = false
            }

            Log.error("Failed to load more recipes", category: .social, metadata: [
                "tab": isSearching ? "search" : selectedTab.rawValue,
                "error": error.localizedDescription
            ])
        }
    }

    private func refreshContent() async {
        // Clear cache
        discoveryService.clearCache()

        // Reset pagination
        await MainActor.run {
            trendingLastDoc = nil
            newLastDoc = nil
            popularLastDoc = nil
            searchLastDoc = nil
            hasMoreResults = true
        }

        // Reload
        if isSearching {
            await performSearch(query: searchQuery)
        } else {
            await loadContent()
        }
    }

    // MARK: - Save Recipe

    @State private var toastManager = ServiceContainer.shared.resolve(ToastManager.self)

    private func saveRecipe(_ publicRecipe: PublicRecipe) async {
        do {
            let savedRecipe = try await discoveryService.saveToMyRecipes(
                publicRecipe: publicRecipe,
                context: modelContext
            )

            await MainActor.run {
                toastManager.success(
                    title: "Recipe Saved",
                    message: "Added \"\(savedRecipe.title)\" to your collection"
                )
            }

            // Track analytics
            analytics.track(event: .recipeCreated, properties: [
                "source": "discovery_feed",
                "public_recipe_id": publicRecipe.id,
                "tab": isSearching ? "search" : selectedTab.rawValue
            ])

        } catch let error as DiscoveryError {
            await MainActor.run {
                if case .alreadySaved = error {
                    toastManager.warning(
                        title: "Already Saved",
                        message: "You've already added this recipe to your collection"
                    )
                } else {
                    toastManager.error(
                        title: "Failed to Save",
                        message: error.localizedDescription
                    )
                }
            }
        } catch {
            await MainActor.run {
                toastManager.error(
                    title: "Failed to Save",
                    message: error.localizedDescription
                )
            }
        }
    }
}

// MARK: - Discovery Tabs

enum DiscoveryTab: String, CaseIterable {
    case trending = "trending"
    case new = "new"
    case popular = "popular"

    var displayName: String {
        switch self {
        case .trending: return "Trending"
        case .new: return "New"
        case .popular: return "Popular"
        }
    }

    var emptyIcon: String {
        switch self {
        case .trending: return "flame.fill"
        case .new: return "sparkles"
        case .popular: return "star.fill"
        }
    }

    var emptyTitle: String {
        switch self {
        case .trending: return "No Trending Recipes"
        case .new: return "No New Recipes"
        case .popular: return "No Popular Recipes"
        }
    }

    var emptyMessage: String {
        switch self {
        case .trending:
            return "Check back soon to see what recipes are heating up in the community!"
        case .new:
            return "No new recipes have been shared recently. Be the first to share!"
        case .popular:
            return "Start cooking and sharing recipes to see popular recipes appear here."
        }
    }
}

// MARK: - Public Recipe Card

private struct PublicRecipeCard: View {
    let recipe: PublicRecipe
    let tab: DiscoveryTab
    let onTapCard: () -> Void
    let onSave: () -> Void

    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            // Top row: Save button
            HStack {
                Spacer()

                Button {
                    isSaving = true
                    onSave()
                    // Reset after a delay (visual feedback)
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        isSaving = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isSaving ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(isSaving ? HeirloomColors.familyGreen : HeirloomColors.tomato)

                        Text(isSaving ? "Saved" : "Add")
                            .font(HeirloomFonts.caption1Bold)
                            .foregroundStyle(isSaving ? HeirloomColors.familyGreen : HeirloomColors.tomato)
                    }
                    .padding(.horizontal, HeirloomSpacing.sm)
                    .padding(.vertical, 6)
                    .background(
                        (isSaving ? HeirloomColors.familyGreen : HeirloomColors.tomato)
                            .opacity(0.1)
                    )
                    .cornerRadius(8)
                }
                .disabled(isSaving)
            }
            .padding(.horizontal, HeirloomSpacing.md)
            .padding(.top, HeirloomSpacing.md)
            .padding(.bottom, HeirloomSpacing.xs)

            // Card content (tappable)
            Button {
                onTapCard()
            } label: {
                HStack(spacing: HeirloomSpacing.md) {
                    // Recipe image (async load from URL)
                    AsyncImage(url: URL(string: recipe.imageURL ?? "")) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 80, height: 80)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius))
                        case .failure:
                            Image(systemName: "fork.knife")
                                .font(.system(size: 32))
                                .foregroundStyle(HeirloomColors.warmGray)
                                .frame(width: 80, height: 80)
                                .background(HeirloomColors.cream)
                                .clipShape(RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius))
                        @unknown default:
                            EmptyView()
                        }
                    }

                    // Recipe details
                    VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                        // Title with tab badge
                        HStack {
                            Text(recipe.title)
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(HeirloomColors.primaryText)
                                .lineLimit(2)

                            Spacer()

                            // Tab-specific badge
                            if tab == .trending {
                                Text("🔥")
                                    .font(.system(size: 16))
                            } else if tab == .new {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12))
                                    .foregroundStyle(HeirloomColors.amber)
                            } else if tab == .popular {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(HeirloomColors.familyGreen)
                            }
                        }

                        // Creator attribution
                        Text("by \(recipe.creatorName)")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)

                        // Engagement stats
                        HStack(spacing: HeirloomSpacing.sm) {
                            statLabel(icon: "eye.fill", value: recipe.viewCount)
                            statLabel(icon: "heart.fill", value: recipe.saveCount)

                            if let servings = recipe.servings {
                                HStack(spacing: 2) {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(HeirloomColors.secondaryText)

                                    Text("\(servings)")
                                        .font(HeirloomFonts.caption1)
                                        .foregroundStyle(HeirloomColors.secondaryText)
                                }
                            }
                        }

                        // Time metadata
                        if let prepTime = recipe.prepTime, let cookTime = recipe.cookTime {
                            HStack(spacing: HeirloomSpacing.xs) {
                                Text("⏱️ \(prepTime + cookTime)m")
                                    .font(HeirloomFonts.caption1)
                                    .foregroundStyle(HeirloomColors.secondaryText)
                            }
                        }
                    }
                }
                .padding(.horizontal, HeirloomSpacing.md)
                .padding(.bottom, HeirloomSpacing.md)
            }
            .buttonStyle(.plain)
        }
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
        .shadow(
            color: HeirloomShadows.card.color,
            radius: HeirloomShadows.card.radius,
            x: HeirloomShadows.card.x,
            y: HeirloomShadows.card.y
        )
    }

    @ViewBuilder
    private func statLabel(icon: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(HeirloomColors.secondaryText)

            Text("\(value)")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }
}

// MARK: - Preview

#Preview {
    DiscoveryView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
