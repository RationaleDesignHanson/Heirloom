import SwiftUI
import SwiftData

/// Displays a list of comments for a recipe with filtering, sorting, and search
struct RecipeCommentListView: View {
    let recipe: Recipe

    @Environment(\.modelContext) private var modelContext

    // Using concrete type for toast notifications
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }

    private var commentService: CommentService { ServiceContainer.shared.resolve(CommentService.self) }

    @State private var searchText = ""
    @State private var sortOption: CommentSortOption = .topRated
    @State private var filterType: CommentType?
    @State private var filterSource: CommentSource?
    @State private var filterSentiment: SentimentFilter?
    @State private var showFilters = false
    @State private var showAddComment = false

    // MARK: - Computed Properties

    private var allComments: [RecipeComment] {
        recipe.comments ?? []
    }

    private var filteredComments: [RecipeComment] {
        var comments = allComments

        // Apply search filter
        if !searchText.isEmpty {
            comments = commentService.searchComments(for: recipe, query: searchText)
        }

        // Apply type filter
        if let type = filterType {
            comments = comments.filter { $0.commentType == type }
        }

        // Apply source filter
        if let source = filterSource {
            comments = comments.filter { $0.source == source }
        }

        // Apply sentiment filter
        if let sentiment = filterSentiment {
            comments = comments.filter { comment in
                guard let score = comment.sentimentScore else { return false }
                switch sentiment {
                case .positive:
                    return score > 0.2
                case .neutral:
                    return score >= -0.2 && score <= 0.2
                case .negative:
                    return score < -0.2
                }
            }
        }

        // Filter out hidden comments
        comments = comments.filter { !$0.isHidden }

        return comments
    }

    private var sortedComments: [RecipeComment] {
        let comments = filteredComments

        switch sortOption {
        case .topRated:
            return comments.sorted { $0.voteScore > $1.voteScore }
        case .mostRecent:
            return comments.sorted { $0.createdAt > $1.createdAt }
        case .mostPositive:
            return comments.sorted {
                ($0.sentimentScore ?? 0) > ($1.sentimentScore ?? 0)
            }
        case .mostNegative:
            return comments.sorted {
                ($0.sentimentScore ?? 0) < ($1.sentimentScore ?? 0)
            }
        case .mostReplies:
            return comments.sorted {
                ($0.replies?.count ?? 0) > ($1.replies?.count ?? 0)
            }
        }
    }

    private var displayComments: [RecipeComment] {
        // Show only top-level comments (replies shown within RecipeCommentView)
        sortedComments.filter { $0.isTopLevel }
    }

    private var statistics: CommentStatistics {
        commentService.getStatistics(for: recipe)
    }

    private var hasActiveFilters: Bool {
        filterType != nil || filterSource != nil || filterSentiment != nil || !searchText.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Statistics header
            statisticsHeader

            Divider()

            // Search and filter bar
            searchAndFilterBar

            // Active filters chips
            if hasActiveFilters {
                activeFiltersRow
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            // Comments list
            if displayComments.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(displayComments) { comment in
                            RecipeCommentView(
                                comment: comment,
                                onUpvote: { upvoteComment(comment) },
                                onDownvote: { downvoteComment(comment) },
                                onPin: { togglePin(comment) },
                                onReply: { replyToComment(comment) }
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showAddComment = true
                } label: {
                    Label("Add Comment", systemImage: "plus.bubble.fill")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    sortMenu
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilters.toggle()
                } label: {
                    Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            filterSheet
        }
        .sheet(isPresented: $showAddComment) {
            AddCommentSheet(recipe: recipe, onSave: { text, authorName, commentType in
                addComment(text: text, authorName: authorName, commentType: commentType)
                showAddComment = false
            })
        }
    }

    // MARK: - Subviews

    private var statisticsHeader: some View {
        HStack(spacing: 20) {
            StatBadge(
                value: "\(statistics.totalComments)",
                label: "Comments",
                icon: "bubble.left.fill",
                color: .blue
            )

            if let avgSentiment = statistics.averageSentiment {
                StatBadge(
                    value: String(format: "%.0f%%", (avgSentiment + 1) / 2 * 100),
                    label: "Positive",
                    icon: sentimentIcon(avgSentiment),
                    color: sentimentColor(avgSentiment)
                )
            }

            StatBadge(
                value: "\(statistics.totalUpvotes)",
                label: "Upvotes",
                icon: "arrow.up.circle.fill",
                color: .green
            )

            StatBadge(
                value: "\(statistics.pinnedComments)",
                label: "Pinned",
                icon: "pin.fill",
                color: .orange
            )
        }
        .padding()
    }

    private var searchAndFilterBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search comments...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding()
    }

    private var activeFiltersRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HeirloomSpacing.sm) {
                if let type = filterType {
                    FilterChip(
                        label: type.displayName,
                        icon: commentTypeIcon(type),
                        color: commentTypeColor(type)
                    ) {
                        filterType = nil
                    }
                }

                if let source = filterSource {
                    FilterChip(
                        label: source.displayName,
                        icon: source.iconName,
                        color: .blue
                    ) {
                        filterSource = nil
                    }
                }

                if let sentiment = filterSentiment {
                    FilterChip(
                        label: sentiment.displayName,
                        icon: sentiment.iconName,
                        color: sentiment.color
                    ) {
                        filterSentiment = nil
                    }
                }

                if hasActiveFilters {
                    Button {
                        clearAllFilters()
                    } label: {
                        Text("Clear All")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var sortMenu: some View {
        ForEach(CommentSortOption.allCases, id: \.self) { option in
            Button {
                sortOption = option
            } label: {
                HStack {
                    Text(option.displayName)
                    if sortOption == option {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }

    private var filterSheet: some View {
        NavigationStack {
            Form {
                Section("Comment Type") {
                    Picker("Type", selection: $filterType) {
                        Text("All Types").tag(nil as CommentType?)
                        ForEach(CommentType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: commentTypeIcon(type))
                                .tag(type as CommentType?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Source") {
                    Picker("Source", selection: $filterSource) {
                        Text("All Sources").tag(nil as CommentSource?)
                        ForEach(CommentSource.allCases, id: \.self) { source in
                            Label(source.displayName, systemImage: source.iconName)
                                .tag(source as CommentSource?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Sentiment") {
                    Picker("Sentiment", selection: $filterSentiment) {
                        Text("All Sentiments").tag(nil as SentimentFilter?)
                        ForEach(SentimentFilter.allCases, id: \.self) { sentiment in
                            Label(sentiment.displayName, systemImage: sentiment.iconName)
                                .tag(sentiment as SentimentFilter?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if hasActiveFilters {
                    Section {
                        Button("Clear All Filters") {
                            clearAllFilters()
                            showFilters = false
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Filter Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showFilters = false
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            Spacer()

            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle" : "bubble.left")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(hasActiveFilters ? "No comments match your filters" : "No comments yet")
                .font(HeirloomFonts.title2)
                .fontWeight(.semibold)

            Text(hasActiveFilters ? "Try adjusting your filters" : "Be the first to add a comment!")
                .font(HeirloomFonts.body)
                .foregroundStyle(.secondary)

            if hasActiveFilters {
                Button {
                    clearAllFilters()
                } label: {
                    Text("Clear Filters")
                        .font(HeirloomFonts.body)
                        .fontWeight(.medium)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helper Functions

    private func sentimentIcon(_ score: Double) -> String {
        if score > 0.5 { return "face.smiling" }
        if score > 0.2 { return "hand.thumbsup.fill" }
        if score < -0.5 { return "exclamationmark.triangle.fill" }
        if score < -0.2 { return "hand.thumbsdown.fill" }
        return "minus.circle"
    }

    private func sentimentColor(_ score: Double) -> Color {
        if score > 0.2 { return .green }
        if score < -0.2 { return .red }
        return .secondary
    }

    private func commentTypeIcon(_ type: CommentType) -> String {
        switch type {
        case .tip: return "lightbulb.fill"
        case .modification: return "wrench.and.screwdriver.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .substitution: return "arrow.triangle.swap"
        case .timing: return "clock.fill"
        case .technique: return "hand.raised.fill"
        case .scaling: return "slider.horizontal.3"
        case .storage: return "refrigerator.fill"
        case .pairing: return "fork.knife"
        case .question: return "questionmark.circle.fill"
        case .review: return "star.fill"
        case .general: return "bubble.left.fill"
        }
    }

    private func commentTypeColor(_ type: CommentType) -> Color {
        switch type {
        case .tip: return .blue
        case .modification: return .purple
        case .warning: return .red
        case .substitution: return .orange
        case .timing: return .cyan
        case .technique: return .mint
        case .scaling: return .indigo
        case .storage: return .teal
        case .pairing: return .pink
        case .question: return .yellow
        case .review: return .orange
        case .general: return .gray
        }
    }

    private func clearAllFilters() {
        filterType = nil
        filterSource = nil
        filterSentiment = nil
        searchText = ""
    }

    // MARK: - Actions

    private func upvoteComment(_ comment: RecipeComment) {
        do {
            try commentService.upvoteComment(comment, context: modelContext)
        } catch {
            Log.error("Failed to upvote comment", category: .database, metadata: ["error": error.localizedDescription])
        }
    }

    private func downvoteComment(_ comment: RecipeComment) {
        do {
            try commentService.downvoteComment(comment, context: modelContext)
        } catch {
            Log.error("Failed to downvote comment", category: .database, metadata: ["error": error.localizedDescription])
        }
    }

    private func togglePin(_ comment: RecipeComment) {
        do {
            try commentService.togglePin(comment, context: modelContext)
        } catch {
            Log.error("Failed to toggle comment pin", category: .database, metadata: ["error": error.localizedDescription])
        }
    }

    private func replyToComment(_ comment: RecipeComment) {
        // TODO: Implement reply sheet
        Log.debug("Reply to comment requested", category: .ui, metadata: ["commentId": comment.id.uuidString])
    }

    private func addComment(text: String, authorName: String?, commentType: CommentType) {
        do {
            // Use CommentService which handles Firebase sync
            _ = try commentService.addComment(
                to: recipe,
                text: text,
                authorName: authorName,
                source: .user,
                commentType: commentType,
                context: modelContext
            )

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            toastManager.success(title: "Comment added!")
        } catch {
            toastManager.error(
                title: "Failed to add comment",
                message: error.localizedDescription
            )
        }
    }
}

// MARK: - Add Comment Sheet

struct AddCommentSheet: View {
    let recipe: Recipe
    let onSave: (String, String?, CommentType) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var commentText = ""
    @State private var commentType: CommentType = .general
    @State private var authorName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Comment") {
                    TextEditor(text: $commentText)
                        .frame(minHeight: 100)
                }

                Section("Comment Type") {
                    Picker("Type", selection: $commentType) {
                        ForEach(CommentType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Your Name (Optional)") {
                    TextField("Name", text: $authorName)
                }
            }
            .navigationTitle("Add Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveComment()
                    }
                    .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveComment() {
        onSave(
            commentText,
            authorName.isEmpty ? nil : authorName,
            commentType
        )
        dismiss()
    }
}

// MARK: - Supporting Views

private struct StatBadge: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: HeirloomSpacing.xs) {
            HStack(spacing: HeirloomSpacing.xs) {
                Image(systemName: icon)
                    .font(HeirloomFonts.caption1)
                Text(value)
                    .font(HeirloomFonts.bodyBold)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(color)

            Text(label)
                .font(HeirloomFonts.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FilterChip: View {
    let label: String
    let icon: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: HeirloomSpacing.xs) {
            Image(systemName: icon)
                .font(HeirloomFonts.caption2)
            Text(label)
                .font(HeirloomFonts.caption1)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(HeirloomFonts.caption2)
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Enums

enum CommentSortOption: CaseIterable {
    case topRated
    case mostRecent
    case mostPositive
    case mostNegative
    case mostReplies

    var displayName: String {
        switch self {
        case .topRated: return "Top Rated"
        case .mostRecent: return "Most Recent"
        case .mostPositive: return "Most Positive"
        case .mostNegative: return "Most Negative"
        case .mostReplies: return "Most Replies"
        }
    }
}

enum SentimentFilter: CaseIterable {
    case positive
    case neutral
    case negative

    var displayName: String {
        switch self {
        case .positive: return "Positive"
        case .neutral: return "Neutral"
        case .negative: return "Negative"
        }
    }

    var iconName: String {
        switch self {
        case .positive: return "hand.thumbsup.fill"
        case .neutral: return "minus.circle"
        case .negative: return "hand.thumbsdown.fill"
        }
    }

    var color: Color {
        switch self {
        case .positive: return .green
        case .neutral: return .gray
        case .negative: return .red
        }
    }
}

// MARK: - CommentSource Extension

extension CommentSource {
    var displayName: String {
        switch self {
        case .user: return "User"
        case .scraped: return "Web"
        case .ai: return "AI"
        case .imported: return "Imported"
        }
    }

    var iconName: String {
        switch self {
        case .user: return "person.fill"
        case .scraped: return "globe"
        case .ai: return "sparkles"
        case .imported: return "square.and.arrow.down"
        }
    }
}

// MARK: - CommentType Extension

extension CommentType {
    var displayName: String {
        switch self {
        case .general: return "General"
        case .tip: return "Tip"
        case .modification: return "Modification"
        case .timing: return "Timing"
        case .technique: return "Technique"
        case .substitution: return "Substitution"
        case .scaling: return "Scaling"
        case .storage: return "Storage"
        case .pairing: return "Pairing"
        case .warning: return "Warning"
        case .question: return "Question"
        case .review: return "Review"
        }
    }
}

// MARK: - Preview

#Preview("Comment List - Populated") {
    NavigationStack {
        RecipeCommentListView(recipe: {
            let recipe = Recipe.example

            // Add sample comments
            let comment1 = RecipeComment(
                text: "These turned out amazing! I doubled the vanilla and they were perfect.",
                authorName: "Sarah M.",
                source: .scraped,
                commentType: .modification
            )
            comment1.upvotes = 24
            comment1.sentimentScore = 0.85
            comment1.topics = ["vanilla", "flavor"]

            let comment2 = RecipeComment(
                text: "Pro tip: chill the dough for 30 minutes before baking.",
                authorName: "Chef Mike",
                source: .user,
                commentType: .tip
            )
            comment2.upvotes = 18
            comment2.sentimentScore = 0.75
            comment2.topics = ["technique", "dough"]
            comment2.isPinned = true

            let comment3 = RecipeComment(
                text: "Be careful not to overbake! Mine were dry after 12 minutes.",
                authorName: "Lisa K.",
                source: .scraped,
                commentType: .warning
            )
            comment3.upvotes = 8
            comment3.downvotes = 2
            comment3.sentimentScore = -0.4
            comment3.topics = ["timing", "texture"]

            recipe.comments = [comment1, comment2, comment3]

            return recipe
        }())
    }
    .modelContainer(for: Recipe.self, inMemory: true)
}

#Preview("Comment List - Empty") {
    NavigationStack {
        RecipeCommentListView(recipe: Recipe.example)
    }
    .modelContainer(for: Recipe.self, inMemory: true)
}
