import SwiftUI

/// Timeline view showing recipe lineage in chronological order
struct LineageTimelineView: View {
    let tree: LineageTree
    let onTapRecipe: (Recipe) -> Void
    var onTapContributor: ((ContributorInfo) -> Void)? = nil // Phase 8

    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }

    @State private var sortOrder: TimelineSortOrder = .generation
    @State private var selectedNodeID: UUID?

    private var sortedNodes: [LineageNode] {
        switch sortOrder {
        case .chronological:
            return tree.nodes.sorted { $0.recipe.dateAdded < $1.recipe.dateAdded }
        case .generation:
            return tree.nodes.sorted {
                if $0.generation == $1.generation {
                    return $0.recipe.dateAdded < $1.recipe.dateAdded
                }
                return $0.generation < $1.generation
            }
        case .popularity:
            return tree.nodes.sorted { $0.stats.popularityScore > $1.stats.popularityScore }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with stats
                headerSection

                // Timeline items
                LazyVStack(spacing: HeirloomSpacing.md) {
                    ForEach(Array(sortedNodes.enumerated()), id: \.element.id) { index, node in
                        TimelineItemView(
                            node: node,
                            isFirst: index == 0,
                            isLast: index == sortedNodes.count - 1,
                            parentNode: tree.parent(of: node.recipe.id),
                            isSelected: selectedNodeID == node.recipe.id,
                            onTapContributor: onTapContributor,
                            onTapRecipe: { onTapRecipe(node.recipe) }
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                if selectedNodeID == node.recipe.id {
                                    selectedNodeID = nil // Toggle off
                                } else {
                                    selectedNodeID = node.recipe.id
                                }
                            }
                        }
                    }
                }
                .padding(HeirloomSpacing.lg)
            }
        }
        .background(HeirloomColors.appBackground)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                sortMenu
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            Text("Recipe Lineage")
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(tree.stats.displaySummary)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(HeirloomSpacing.lg)
        .background(HeirloomColors.cream)
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $sortOrder) {
                ForEach(TimelineSortOrder.allCases, id: \.self) { order in
                    Label(order.displayName, systemImage: order.icon)
                        .tag(order)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 16))
                .foregroundStyle(HeirloomColors.tomato)
        }
    }
}

// MARK: - Timeline Item View

private struct TimelineItemView: View {
    let node: LineageNode
    let isFirst: Bool
    let isLast: Bool
    let parentNode: LineageNode?
    let isSelected: Bool
    var onTapContributor: ((ContributorInfo) -> Void)? = nil // Phase 8
    var onTapRecipe: (() -> Void)? = nil

    /// Whether this node has changes compared to its parent (for diff display)
    private var hasDiffData: Bool {
        node.version != nil && parentNode?.version != nil && node.generation > 0
    }

    var body: some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.md) {
            // Timeline line and dot
            timelineIndicator

            // Recipe card + expandable diff
            VStack(alignment: .leading, spacing: 0) {
                recipeCard

                // Expandable diff section (shown when selected and has parent)
                if isSelected && hasDiffData {
                    diffSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: - Timeline Indicator

    private var timelineIndicator: some View {
        VStack(spacing: 0) {
            // Line above (if not first)
            if !isFirst {
                Rectangle()
                    .fill(node.generationColor.opacity(0.3))
                    .frame(width: 3)
                    .frame(height: 30)
            }

            // Generation dot
            ZStack {
                Circle()
                    .fill(node.generationColor)
                    .frame(width: 32, height: 32)

                if isSelected {
                    Circle()
                        .stroke(HeirloomColors.charcoal, lineWidth: 3)
                        .frame(width: 38, height: 38)
                }

                Text("G\(node.generation)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(HeirloomColors.buttonTextLight)
            }
            .frame(height: 32)

            // Line below (if not last)
            if !isLast {
                Rectangle()
                    .fill(node.generationColor.opacity(0.3))
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 40)
    }

    // MARK: - Recipe Card

    private var recipeCard: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Header with title and image thumbnail
            HStack {
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    Text(node.recipe.title)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)
                        .lineLimit(2)

                    // Phase 8: Contributor row
                    if let contributor = node.contributor {
                        contributorRow(contributor)
                    }

                    Text(node.generationBadge)
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(node.generationColor)
                }

                Spacer()

                // Recipe image thumbnail
                AsyncRecipeImage(
                    imageFileName: node.recipe.imageFileName,
                    firebaseImageURL: node.recipe.firebaseImageURL,
                    placeholder: node.recipe.sourceType?.iconName ?? "fork.knife"
                )
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Relationship to parent
            if let parent = parentNode {
                HStack(spacing: HeirloomSpacing.xs) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 12))
                        .foregroundStyle(HeirloomColors.secondaryText)

                    Text("Forked from")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)

                    Text(parent.recipe.title)
                        .font(HeirloomFonts.caption2Bold)
                        .foregroundStyle(HeirloomColors.tomato)
                        .lineLimit(1)
                }
            }

            // Stats + expand hint
            HStack(spacing: HeirloomSpacing.md) {
                statItem(icon: "flame.fill", value: node.stats.cookCount, label: "cooks")
                statItem(icon: "square.and.arrow.up", value: node.stats.shareCount, label: "shares")

                Spacer()

                if hasDiffData {
                    Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(HeirloomColors.warmGray)
                }

                // Date
                Text(node.recipe.dateAdded.formatted(date: .abbreviated, time: .omitted))
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
        .padding(HeirloomSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .fill(.white)
                .shadow(color: isSelected ? HeirloomColors.tomato.opacity(0.3) : .black.opacity(0.05), radius: isSelected ? 8 : 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .stroke(isSelected ? HeirloomColors.tomato : .clear, lineWidth: 2)
        )
    }

    // MARK: - Diff Section

    private var diffSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Section header
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(HeirloomColors.tomato)

                Text("Changes from \(parentNode?.contributor?.displayName ?? "Original")")
                    .font(HeirloomFonts.caption1Bold)
                    .foregroundStyle(HeirloomColors.primaryText)

                Spacer()
            }

            // Inline diff view comparing this node to its parent
            if let currentVersion = node.version,
               let parentVersion = parentNode?.version {
                RecipeDiffView(
                    currentVersion: currentVersion,
                    comparedVersion: parentVersion
                )
            }

            // View Recipe button
            if node.isCurrentUser {
                Button {
                    onTapRecipe?()
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("View Recipe")
                    }
                    .font(HeirloomFonts.caption1Bold)
                    .foregroundStyle(HeirloomColors.tomato)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HeirloomSpacing.sm)
                    .background(HeirloomColors.tomato.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .padding(.top, 0)
        .background(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .fill(HeirloomColors.cream)
        )
        .padding(.top, -4) // Tuck under the card
    }

    @ViewBuilder
    private func statItem(icon: String, value: Int, label: String) -> some View {
        HStack(spacing: HeirloomSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(HeirloomColors.tomato)

            Text("\(value)")
                .font(HeirloomFonts.caption1Bold)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(label)
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    // MARK: - Phase 8: Contributor Row

    @ViewBuilder
    private func contributorRow(_ contributor: ContributorInfo) -> some View {
        Button {
            if contributor.hasAccount {
                onTapContributor?(contributor)
            }
        } label: {
            HStack(spacing: HeirloomSpacing.xs) {
                // Avatar
                if let avatarURL = contributor.avatarURL, let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            contributorInitials(contributor.initials)
                        @unknown default:
                            contributorInitials(contributor.initials)
                        }
                    }
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
                } else {
                    contributorInitials(contributor.initials)
                }

                // Name
                Text(contributor.displayName)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(contributor.hasAccount ? HeirloomColors.tomato : HeirloomColors.secondaryText)

                // Connection indicator
                if contributor.isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(HeirloomColors.familyGreen)
                }
            }
        }
        .disabled(!contributor.hasAccount)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func contributorInitials(_ initials: String) -> some View {
        Circle()
            .fill(HeirloomColors.warmGray.opacity(0.3))
            .frame(width: 20, height: 20)
            .overlay(
                Text(initials)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(HeirloomColors.warmGray)
            )
    }
}

// MARK: - Sort Order

enum TimelineSortOrder: String, CaseIterable {
    case chronological = "chronological"
    case generation = "generation"
    case popularity = "popularity"

    var displayName: String {
        switch self {
        case .chronological: return "Date Added"
        case .generation: return "Generation"
        case .popularity: return "Popularity"
        }
    }

    var icon: String {
        switch self {
        case .chronological: return "calendar"
        case .generation: return "chart.tree"
        case .popularity: return "star.fill"
        }
    }
}

// MARK: - Container View (Tab Switcher)

/// Main lineage view with graph/timeline toggle
struct LineageContainerView: View {
    let recipe: Recipe
    let onTapRecipe: (Recipe) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var tree: LineageTree?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedContributor: ContributorInfo? // Phase 8
    @State private var showContributorProfile = false // Phase 8
    @State private var viewMode: LineageViewMode = .timeline

    private var lineageService: RecipeLineageService { ServiceContainer.shared.resolve(RecipeLineageService.self) }
    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Building lineage tree...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                errorView(error)
            } else if let tree = tree {
                switch viewMode {
                case .timeline:
                    LineageTimelineView(
                        tree: tree,
                        onTapRecipe: onTapRecipe,
                        onTapContributor: { contributor in
                            selectedContributor = contributor
                            showContributorProfile = true
                        }
                    )
                case .graph:
                    LineageGraphView(tree: tree, onTapNode: onTapRecipe)
                }
            }
        }
        .navigationTitle("Recipe Lineage")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $viewMode) {
                    ForEach(LineageViewMode.allCases, id: \.self) { mode in
                        Label(mode.displayName, systemImage: mode.icon).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
        }
        .sheet(isPresented: $showContributorProfile) {
            if let contributor = selectedContributor {
                LineageContributorSheet(contributor: contributor)
            }
        }
        .task {
            await loadLineageTree()
        }
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.tomato)

            Text("Failed to Load Lineage")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(message)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HeirloomSpacing.xl)

            Button {
                Task {
                    await loadLineageTree()
                }
            } label: {
                Text("Retry")
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

    // MARK: - Load Lineage

    private func loadLineageTree() async {
        isLoading = true
        errorMessage = nil

        do {
            let loadedTree = try await lineageService.fetchLineageTree(
                for: recipe,
                context: modelContext
            )

            await MainActor.run {
                tree = loadedTree
                isLoading = false
            }

            // Track analytics
            analytics.track(event: .lineageViewed, properties: [
                "recipe_id": recipe.id.uuidString,
                "total_nodes": loadedTree.nodes.count,
                "max_generation": loadedTree.maxGeneration
            ])

        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }

            Log.error("Failed to load lineage tree", category: .general, metadata: ["error": error.localizedDescription, "recipeId": recipe.id.uuidString])
        }
    }
}

// MARK: - View Mode

enum LineageViewMode: String, CaseIterable {
    case graph = "graph"
    case timeline = "timeline"

    var displayName: String {
        switch self {
        case .graph: return "Graph"
        case .timeline: return "Timeline"
        }
    }

    var icon: String {
        switch self {
        case .graph: return "circle.hexagongrid"
        case .timeline: return "list.bullet"
        }
    }
}

// MARK: - Preview

#Preview {
    let rootRecipe = Recipe(title: "Original Chocolate Chip Cookies", sourceType: .manual)
    let child1 = Recipe(title: "Mom's Variation", sourceType: .family)
    let child2 = Recipe(title: "Gluten-Free Version", sourceType: .family)
    let grandchild = Recipe(title: "Vegan Adaptation", sourceType: .family)

    let nodes = [
        LineageNode(
            recipe: rootRecipe,
            generation: 0,
            position: .zero,
            stats: NodeStats(cookCount: 42, shareCount: 15, viewCount: 250, rating: 4.8),
            isCurrentUser: false,
            contributor: nil
        ),
        LineageNode(
            recipe: child1,
            generation: 1,
            position: .zero,
            stats: NodeStats(cookCount: 23, shareCount: 8, viewCount: 120, rating: 4.5),
            isCurrentUser: true,
            contributor: nil
        ),
        LineageNode(
            recipe: child2,
            generation: 1,
            position: .zero,
            stats: NodeStats(cookCount: 15, shareCount: 5, viewCount: 89, rating: 4.3),
            isCurrentUser: false,
            contributor: nil
        ),
        LineageNode(
            recipe: grandchild,
            generation: 2,
            position: .zero,
            stats: NodeStats(cookCount: 8, shareCount: 2, viewCount: 45, rating: 4.0),
            isCurrentUser: false,
            contributor: nil
        )
    ]

    let edges = [
        LineageEdge(fromID: rootRecipe.id, toID: child1.id, label: "Forked", createdAt: Date()),
        LineageEdge(fromID: rootRecipe.id, toID: child2.id, label: "Adapted", createdAt: Date()),
        LineageEdge(fromID: child1.id, toID: grandchild.id, label: "Remixed", createdAt: Date())
    ]

    let tree = LineageTree(root: rootRecipe, nodes: nodes, edges: edges)

    NavigationStack {
        LineageTimelineView(tree: tree) { recipe in
            Log.debug("Preview: Lineage recipe tapped", category: .ui, metadata: ["title": recipe.title])
        }
    }
}
