import SwiftUI
import SwiftData

/// Discovery feed showing trending, new, and popular recipes
struct DiscoveryView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab: DiscoveryTab = .trending
    @State private var trendingRecipes: [TrendingRecipe] = []
    @State private var newRecipes: [Recipe] = []
    @State private var popularRecipes: [TrendingRecipe] = []

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                tabSelector

                // Content based on selected tab
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
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadContent()
            }
            .refreshable {
                await refreshContent()
            }
        }
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
                switch selectedTab {
                case .trending:
                    ForEach(trendingRecipes) { trending in
                        TrendingRecipeCard(
                            trending: trending,
                            onTap: { navigateToRecipe(trending.recipe) }
                        )
                    }

                case .new:
                    ForEach(newRecipes, id: \.id) { recipe in
                        NewRecipeCard(
                            recipe: recipe,
                            onTap: { navigateToRecipe(recipe) }
                        )
                    }

                case .popular:
                    ForEach(popularRecipes) { trending in
                        PopularRecipeCard(
                            trending: trending,
                            onTap: { navigateToRecipe(trending.recipe) }
                        )
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

            Text("Loading \(selectedTab.displayName.lowercased()) recipes...")
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
                .font(HeirloomFonts.headline)
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
                    .foregroundStyle(.white)
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
            Image(systemName: selectedTab.emptyIcon)
                .font(.system(size: 64))
                .foregroundStyle(HeirloomColors.warmGray)

            Text(selectedTab.emptyTitle)
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(selectedTab.emptyMessage)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HeirloomSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(HeirloomSpacing.xl)
    }

    // MARK: - Computed Properties

    private var currentContent: [Any] {
        switch selectedTab {
        case .trending:
            return trendingRecipes
        case .new:
            return newRecipes
        case .popular:
            return popularRecipes
        }
    }

    // MARK: - Data Loading

    private func loadContent() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            switch selectedTab {
            case .trending:
                let trending = try await TrendingService.shared.fetchTrendingRecipes(
                    limit: 20,
                    context: modelContext
                )

                await MainActor.run {
                    trendingRecipes = trending
                }

                // Track analytics
                AnalyticsService.shared.track(event: .discoveryFeedViewed, properties: [
                    "tab": "trending",
                    "count": trending.count
                ])

            case .new:
                let recipes = try await TrendingService.shared.fetchRecentRecipes(
                    limit: 20,
                    context: modelContext
                )

                await MainActor.run {
                    newRecipes = recipes
                }

                AnalyticsService.shared.track(event: .discoveryFeedViewed, properties: [
                    "tab": "new",
                    "count": recipes.count
                ])

            case .popular:
                let popular = try await TrendingService.shared.fetchPopularRecipes(
                    limit: 20,
                    context: modelContext
                )

                await MainActor.run {
                    popularRecipes = popular
                }

                AnalyticsService.shared.track(event: .discoveryFeedViewed, properties: [
                    "tab": "popular",
                    "count": popular.count
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

            print("❌ Failed to load \(selectedTab.rawValue) recipes: \(error)")
        }
    }

    private func refreshContent() async {
        // Clear cache and reload
        TrendingService.shared.clearCache()
        await loadContent()
    }

    private func navigateToRecipe(_ recipe: Recipe) {
        // TODO: Implement navigation to recipe detail
        print("Navigate to recipe: \(recipe.title)")

        // Track analytics
        AnalyticsService.shared.track(event: .trendingRecipeViewed, properties: [
            "recipe_id": recipe.id.uuidString,
            "recipe_title": recipe.title,
            "discovery_tab": selectedTab.rawValue
        ])
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

// MARK: - Trending Recipe Card

private struct TrendingRecipeCard: View {
    let trending: TrendingRecipe
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: HeirloomSpacing.md) {
                // Recipe image
                if let imageData = trending.recipe.images.first?.data,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 32))
                        .foregroundStyle(HeirloomColors.warmGray)
                        .frame(width: 80, height: 80)
                        .background(HeirloomColors.cream)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Recipe details
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    // Title with trending badge
                    HStack {
                        Text(trending.recipe.title)
                            .font(HeirloomFonts.headline)
                            .foregroundStyle(HeirloomColors.primaryText)
                            .lineLimit(2)

                        Spacer()

                        if !trending.displayBadge.isEmpty {
                            Text(trending.displayBadge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(HeirloomColors.tomato)
                                .cornerRadius(4)
                        }
                    }

                    // Engagement stats
                    HStack(spacing: HeirloomSpacing.sm) {
                        statLabel(icon: "eye.fill", value: trending.recentViews)
                        statLabel(icon: "flame.fill", value: trending.recentCooks)
                        statLabel(icon: "square.and.arrow.up", value: trending.recentShares)
                    }

                    // Trending score bar
                    HStack(spacing: 4) {
                        Text("Score:")
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(HeirloomColors.secondaryText)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                Capsule()
                                    .fill(HeirloomColors.cream)
                                    .frame(height: 4)

                                // Fill
                                Capsule()
                                    .fill(HeirloomColors.tomato)
                                    .frame(
                                        width: geometry.size.width * (trending.trendingScore / 100),
                                        height: 4
                                    )
                            }
                        }
                        .frame(height: 4)

                        Text("\(Int(trending.trendingScore))")
                            .font(HeirloomFonts.caption2Bold)
                            .foregroundStyle(HeirloomColors.tomato)
                    }
                }
            }
            .padding(HeirloomSpacing.md)
            .background(HeirloomColors.cardBackground)
            .cornerRadius(12)
            .shadow(
                color: HeirloomShadows.card.color,
                radius: HeirloomShadows.card.radius,
                x: HeirloomShadows.card.x,
                y: HeirloomShadows.card.y
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statLabel(icon: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(HeirloomColors.secondaryText)

            Text("\(value)")
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }
}

// MARK: - New Recipe Card

private struct NewRecipeCard: View {
    let recipe: Recipe
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                // Recipe image
                if let imageData = recipe.images.first?.data,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 180)
                        .clipped()
                } else {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 48))
                        .foregroundStyle(HeirloomColors.warmGray)
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .background(HeirloomColors.cream)
                }

                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundStyle(HeirloomColors.amber)

                        Text("NEW")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(HeirloomColors.amber)

                        Spacer()

                        Text(recipe.dateAdded.formatted(.relative(presentation: .named)))
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    Text(recipe.title)
                        .font(HeirloomFonts.headline)
                        .foregroundStyle(HeirloomColors.primaryText)
                        .lineLimit(2)
                }
                .padding(.horizontal, HeirloomSpacing.sm)
                .padding(.bottom, HeirloomSpacing.sm)
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
        .buttonStyle(.plain)
    }
}

// MARK: - Popular Recipe Card

private struct PopularRecipeCard: View {
    let trending: TrendingRecipe
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: HeirloomSpacing.md) {
                // Rank badge
                ZStack {
                    Circle()
                        .fill(HeirloomColors.familyGreen)
                        .frame(width: 48, height: 48)

                    Image(systemName: "star.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }

                // Recipe details
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    Text(trending.recipe.title)
                        .font(HeirloomFonts.headline)
                        .foregroundStyle(HeirloomColors.primaryText)
                        .lineLimit(2)

                    HStack(spacing: HeirloomSpacing.sm) {
                        Label("\(trending.recentViews)", systemImage: "eye.fill")
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(HeirloomColors.secondaryText)

                        Label("\(trending.recentCooks)", systemImage: "flame.fill")
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(HeirloomColors.warmGray)
            }
            .padding(HeirloomSpacing.md)
            .background(HeirloomColors.cardBackground)
            .cornerRadius(12)
            .shadow(
                color: HeirloomShadows.card.color,
                radius: HeirloomShadows.card.radius,
                x: HeirloomShadows.card.x,
                y: HeirloomShadows.card.y
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    DiscoveryView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
