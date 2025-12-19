import SwiftUI
import SwiftData

/// Displays a single recipe comment with sentiment, votes, and actions
struct RecipeCommentView: View {
    let comment: RecipeComment
    let onUpvote: () -> Void
    let onDownvote: () -> Void
    let onPin: () -> Void
    let onReply: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            commentTextView
            topicsView
            actionsBar
            repliesView
        }
        .padding(16)
        .background(comment.showOnCardBack ? HeirloomColors.cream.opacity(0.3) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            // Author avatar/icon
            Circle()
                .fill(commentTypeColor.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: commentTypeIcon)
                        .font(.caption)
                        .foregroundStyle(commentTypeColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(comment.displayAuthor)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 4) {
                    Text(comment.displayDate)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if comment.source == .scraped {
                        Text("• from web")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Sentiment indicator
            if let sentiment = comment.sentimentScore {
                sentimentIndicator(score: sentiment)
            }

            // Pinned indicator
            if comment.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var commentTextView: some View {
        Text(comment.text)
            .font(.subheadline)
            .lineSpacing(4)
    }

    @ViewBuilder
    private var topicsView: some View {
        if !comment.topics.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(comment.topics, id: \.self) { topic in
                        Text(topic)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(HeirloomColors.amber.opacity(0.3))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var actionsBar: some View {
        HStack(spacing: 16) {
            upvoteButton
            downvoteButton
            replyButton

            Spacer()

            pinButton
            moreMenu
        }
        .font(.subheadline)
    }

    private var upvoteButton: some View {
        Button(action: onUpvote) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.circle.fill")
                Text("\(comment.upvotes)")
                    .font(.caption)
                    .monospacedDigit()
            }
            .foregroundStyle(comment.upvotes > 0 ? .green : .secondary)
        }
    }

    private var downvoteButton: some View {
        Button(action: onDownvote) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                if comment.downvotes > 0 {
                    Text("\(comment.downvotes)")
                        .font(.caption)
                        .monospacedDigit()
                }
            }
            .foregroundStyle(.secondary)
        }
    }

    private var replyButton: some View {
        Button(action: onReply) {
            HStack(spacing: 4) {
                Image(systemName: "bubble.right")
                if let replyCount = comment.replies?.count, replyCount > 0 {
                    Text("\(replyCount)")
                        .font(.caption)
                        .monospacedDigit()
                }
            }
            .foregroundStyle(.secondary)
        }
    }

    private var pinButton: some View {
        Button(action: onPin) {
            Image(systemName: comment.isPinned ? "pin.slash" : "pin")
                .foregroundStyle(.secondary)
        }
    }

    private var moreMenu: some View {
        Menu {
            Button {
                // Copy text
            } label: {
                Label("Copy Text", systemImage: "doc.on.doc")
            }

            Button {
                toggleCardBackVisibility()
            } label: {
                Label(
                    comment.showOnCardBack ? "Remove from Card" : "Show on Card Back",
                    systemImage: comment.showOnCardBack ? "rectangle.portrait.slash" : "rectangle.portrait"
                )
            }

            Divider()

            Button(role: .destructive) {
                // Flag comment
            } label: {
                Label("Report", systemImage: "flag")
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var repliesView: some View {
        if let replies = comment.replies, !replies.isEmpty {
            Divider()
                .padding(.leading, 32)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(replies) { reply in
                    RecipeCommentView(
                        comment: reply,
                        onUpvote: { upvoteComment(reply) },
                        onDownvote: { downvoteComment(reply) },
                        onPin: { togglePin(reply) },
                        onReply: { }
                    )
                    .padding(.leading, 32)
                }
            }
        }
    }

    // MARK: - Helper Views

    private func sentimentIndicator(score: Double) -> some View {
        HStack(spacing: 2) {
            Image(systemName: sentimentIcon(score))
                .font(.caption)
            Text(String(format: "%.0f%%", abs(score) * 100))
                .font(.caption2)
                .monospacedDigit()
        }
        .foregroundStyle(sentimentColor(score))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(sentimentColor(score).opacity(0.1))
        .clipShape(Capsule())
    }

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

    private var commentTypeColor: Color {
        switch comment.commentType {
        case .tip: return .blue
        case .modification: return .purple
        case .warning: return .red
        case .substitution: return .orange
        case .timing: return .cyan
        default: return .gray
        }
    }

    private var commentTypeIcon: String {
        switch comment.commentType {
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
        default: return "bubble.left.fill"
        }
    }

    // MARK: - Actions

    private func upvoteComment(_ comment: RecipeComment) {
        do {
            try CommentService.shared.upvoteComment(comment, context: modelContext)
        } catch {
            print("Failed to upvote: \(error)")
        }
    }

    private func downvoteComment(_ comment: RecipeComment) {
        do {
            try CommentService.shared.downvoteComment(comment, context: modelContext)
        } catch {
            print("Failed to downvote: \(error)")
        }
    }

    private func togglePin(_ comment: RecipeComment) {
        do {
            try CommentService.shared.togglePin(comment, context: modelContext)
        } catch {
            print("Failed to toggle pin: \(error)")
        }
    }

    private func toggleCardBackVisibility() {
        do {
            try CommentService.shared.toggleCardBackVisibility(comment, context: modelContext)
        } catch {
            print("Failed to toggle card back visibility: \(error)")
        }
    }
}

// MARK: - Preview

#Preview("Comment Variations") {
    List {
        // Positive comment
        RecipeCommentView(
            comment: .sample(
                text: "This recipe is amazing! I doubled the garlic and it was perfect.",
                source: .user,
                commentType: .modification
            ),
            onUpvote: {},
            onDownvote: {},
            onPin: {},
            onReply: {}
        )

        // Tip comment
        RecipeCommentView(
            comment: {
                let comment = RecipeComment(
                    text: "Pro tip: Let the dough rest for 30 minutes before rolling for best results.",
                    authorName: "Sarah M.",
                    source: .scraped,
                    commentType: .tip
                )
                comment.upvotes = 24
                comment.sentimentScore = 0.8
                comment.topics = ["technique", "dough", "timing"]
                return comment
            }(),
            onUpvote: {},
            onDownvote: {},
            onPin: {},
            onReply: {}
        )

        // Warning comment
        RecipeCommentView(
            comment: {
                let comment = RecipeComment(
                    text: "Be careful not to overbake! Mine came out dry after 12 minutes.",
                    authorName: "Mike R.",
                    source: .scraped,
                    commentType: .warning
                )
                comment.upvotes = 8
                comment.downvotes = 2
                comment.sentimentScore = -0.3
                comment.topics = ["timing", "texture"]
                return comment
            }(),
            onUpvote: {},
            onDownvote: {},
            onPin: {},
            onReply: {}
        )
    }
    .modelContainer(for: RecipeComment.self, inMemory: true)
}
