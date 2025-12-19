import SwiftUI
import SwiftData
import Charts

/// Personal cooking statistics and insights
struct PersonalStatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.timesCooked, order: .reverse) private var recipes: [Recipe]

    @State private var stats: PersonalStats?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Calculating your stats...")
                } else if let stats = stats {
                    statsContent(stats)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Your Stats")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await calculateStats()
            }
        }
    }

    // MARK: - Stats Content

    @ViewBuilder
    private func statsContent(_ stats: PersonalStats) -> some View {
        ScrollView {
            VStack(spacing: HeirloomSpacing.lg) {
                // Overview cards
                overviewSection(stats)

                // Most cooked recipes
                mostCookedSection(stats)

                // Most shared recipes
                mostSharedSection(stats)

                // Cooking timeline
                cookingTimelineSection(stats)

                // Achievements
                achievementsSection(stats)
            }
            .padding(HeirloomSpacing.md)
        }
        .background(HeirloomColors.appBackground)
        .refreshable {
            await calculateStats()
        }
    }

    // MARK: - Overview Section

    @ViewBuilder
    private func overviewSection(_ stats: PersonalStats) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("Overview")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: HeirloomSpacing.md
            ) {
                statCard(
                    icon: "book.fill",
                    value: "\(stats.totalRecipes)",
                    label: "Recipes",
                    color: HeirloomColors.tomato
                )

                statCard(
                    icon: "flame.fill",
                    value: "\(stats.totalCooks)",
                    label: "Total Cooks",
                    color: HeirloomColors.amber
                )

                statCard(
                    icon: "square.and.arrow.up",
                    value: "\(stats.totalShares)",
                    label: "Shares",
                    color: .blue
                )

                statCard(
                    icon: "heart.fill",
                    value: "\(stats.favoriteCount)",
                    label: "Favorites",
                    color: HeirloomColors.familyGreen
                )
            }
        }
    }

    @ViewBuilder
    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: HeirloomSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(HeirloomColors.primaryText)

            Text(label)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
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

    // MARK: - Most Cooked Section

    @ViewBuilder
    private func mostCookedSection(_ stats: PersonalStats) -> some View {
        if !stats.mostCooked.isEmpty {
            VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(HeirloomColors.amber)

                    Text("Most Cooked")
                        .font(HeirloomFonts.title3)
                        .foregroundStyle(HeirloomColors.primaryText)
                }

                ForEach(Array(stats.mostCooked.prefix(5).enumerated()), id: \.element.id) { index, recipe in
                    RecipeRankCard(
                        recipe: recipe,
                        rank: index + 1,
                        metric: "\(recipe.timesCooked) times",
                        icon: "flame.fill",
                        color: HeirloomColors.amber
                    )
                }
            }
        }
    }

    // MARK: - Most Shared Section

    @ViewBuilder
    private func mostSharedSection(_ stats: PersonalStats) -> some View {
        if !stats.mostShared.isEmpty {
            VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.blue)

                    Text("Most Shared")
                        .font(HeirloomFonts.title3)
                        .foregroundStyle(HeirloomColors.primaryText)
                }

                ForEach(Array(stats.mostShared.prefix(5).enumerated()), id: \.element.id) { index, recipe in
                    RecipeRankCard(
                        recipe: recipe,
                        rank: index + 1,
                        metric: "\(recipe.totalShares) shares",
                        icon: "square.and.arrow.up",
                        color: .blue
                    )
                }
            }
        }
    }

    // MARK: - Cooking Timeline Section

    @ViewBuilder
    private func cookingTimelineSection(_ stats: PersonalStats) -> some View {
        if !stats.recentCookingActivity.isEmpty {
            VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                Text("Cooking Activity (Last 30 Days)")
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)

                Chart(stats.recentCookingActivity) { activity in
                    BarMark(
                        x: .value("Week", activity.weekLabel),
                        y: .value("Cooks", activity.count)
                    )
                    .foregroundStyle(HeirloomColors.tomato)
                }
                .frame(height: 200)
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
        }
    }

    // MARK: - Achievements Section

    @ViewBuilder
    private func achievementsSection(_ stats: PersonalStats) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("Achievements")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: HeirloomSpacing.md
            ) {
                ForEach(stats.achievements) { achievement in
                    AchievementBadge(achievement: achievement)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 64))
                .foregroundStyle(HeirloomColors.warmGray)

            Text("No Stats Yet")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("Start cooking recipes to see your stats here!")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HeirloomSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Calculate Stats

    private func calculateStats() async {
        isLoading = true

        await Task {
            // Calculate stats from local data
            let totalRecipes = recipes.count
            let totalCooks = recipes.reduce(0) { $0 + $1.timesCooked }
            let totalShares = recipes.reduce(0) { $0 + $1.totalShares }
            let favoriteCount = recipes.filter { $0.isFavorite }.count

            // Most cooked recipes
            let mostCooked = recipes
                .filter { $0.timesCooked > 0 }
                .sorted { $0.timesCooked > $1.timesCooked }

            // Most shared recipes
            let mostShared = recipes
                .filter { $0.totalShares > 0 }
                .sorted { $0.totalShares > $1.totalShares }

            // Recent cooking activity
            let recentActivity = calculateRecentActivity()

            // Achievements
            let achievements = calculateAchievements(
                totalRecipes: totalRecipes,
                totalCooks: totalCooks,
                totalShares: totalShares,
                favoriteCount: favoriteCount
            )

            let stats = PersonalStats(
                totalRecipes: totalRecipes,
                totalCooks: totalCooks,
                totalShares: totalShares,
                favoriteCount: favoriteCount,
                mostCooked: mostCooked,
                mostShared: mostShared,
                recentCookingActivity: recentActivity,
                achievements: achievements
            )

            await MainActor.run {
                self.stats = stats
                isLoading = false
            }

            // Track analytics
            AnalyticsService.shared.track(event: .featureUsed, properties: [
                "feature": "personal_stats",
                "total_recipes": totalRecipes,
                "total_cooks": totalCooks
            ])

        }.value
    }

    /// Calculate cooking activity for the last 30 days
    private func calculateRecentActivity() -> [CookingActivity] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        var weeklyActivity: [Int: Int] = [:]

        for recipe in recipes {
            guard let lastCooked = recipe.lastCooked,
                  lastCooked >= thirtyDaysAgo else {
                continue
            }

            let weekNumber = Calendar.current.component(.weekOfYear, from: lastCooked)
            weeklyActivity[weekNumber, default: 0] += 1
        }

        return weeklyActivity.map { week, count in
            CookingActivity(weekNumber: week, count: count)
        }
        .sorted { $0.weekNumber < $1.weekNumber }
    }

    /// Calculate achievements based on user's stats
    private func calculateAchievements(
        totalRecipes: Int,
        totalCooks: Int,
        totalShares: Int,
        favoriteCount: Int
    ) -> [Achievement] {
        var achievements: [Achievement] = []

        // Recipe collection achievements
        if totalRecipes >= 10 {
            achievements.append(Achievement(
                id: "collector_10",
                title: "Recipe Collector",
                description: "Added 10+ recipes",
                icon: "book.fill",
                color: HeirloomColors.tomato,
                isUnlocked: true
            ))
        }

        if totalRecipes >= 50 {
            achievements.append(Achievement(
                id: "collector_50",
                title: "Recipe Library",
                description: "Added 50+ recipes",
                icon: "books.vertical.fill",
                color: HeirloomColors.tomato,
                isUnlocked: true
            ))
        }

        // Cooking achievements
        if totalCooks >= 25 {
            achievements.append(Achievement(
                id: "chef_25",
                title: "Home Chef",
                description: "Cooked 25+ times",
                icon: "flame.fill",
                color: HeirloomColors.amber,
                isUnlocked: true
            ))
        }

        if totalCooks >= 100 {
            achievements.append(Achievement(
                id: "chef_100",
                title: "Master Chef",
                description: "Cooked 100+ times",
                icon: "star.fill",
                color: HeirloomColors.amber,
                isUnlocked: true
            ))
        }

        // Sharing achievements
        if totalShares >= 10 {
            achievements.append(Achievement(
                id: "sharer_10",
                title: "Recipe Sharer",
                description: "Shared 10+ recipes",
                icon: "square.and.arrow.up",
                color: .blue,
                isUnlocked: true
            ))
        }

        // Favorite achievements
        if favoriteCount >= 10 {
            achievements.append(Achievement(
                id: "favorites_10",
                title: "Favorites Curator",
                description: "10+ favorite recipes",
                icon: "heart.fill",
                color: HeirloomColors.familyGreen,
                isUnlocked: true
            ))
        }

        return achievements
    }
}

// MARK: - Recipe Rank Card

private struct RecipeRankCard: View {
    let recipe: Recipe
    let rank: Int
    let metric: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 40, height: 40)

                Text("\(rank)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }

            // Recipe info
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(HeirloomFonts.subheadline)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(color)

                    Text(metric)
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(HeirloomColors.warmGray)
        }
        .padding(HeirloomSpacing.sm)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(8)
    }
}

// MARK: - Achievement Badge

private struct AchievementBadge: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? achievement.color : HeirloomColors.warmGray.opacity(0.3))
                    .frame(width: 64, height: 64)

                Image(systemName: achievement.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(achievement.isUnlocked ? .white : HeirloomColors.warmGray)
            }

            VStack(spacing: 4) {
                Text(achievement.title)
                    .font(HeirloomFonts.caption1Bold)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(achievement.description)
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(HeirloomSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
        .opacity(achievement.isUnlocked ? 1.0 : 0.6)
    }
}

// MARK: - Data Models

struct PersonalStats {
    let totalRecipes: Int
    let totalCooks: Int
    let totalShares: Int
    let favoriteCount: Int
    let mostCooked: [Recipe]
    let mostShared: [Recipe]
    let recentCookingActivity: [CookingActivity]
    let achievements: [Achievement]
}

struct CookingActivity: Identifiable {
    let id = UUID()
    let weekNumber: Int
    let count: Int

    var weekLabel: String {
        "Week \(weekNumber)"
    }
}

struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isUnlocked: Bool
}

// MARK: - Preview

#Preview {
    PersonalStatsView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
