import SwiftUI

/// Shows attribution for comments from recipe lineage
struct CommentAttributionView: View {
    let comment: RecipeComment
    let currentRecipeHash: String?

    var body: some View {
        if comment.isFromLineage {
            HStack(spacing: HeirloomSpacing.xs) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 10))
                    .foregroundStyle(HeirloomColors.secondaryText)

                Text(attributionText)
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)

                if let generationText = generationBadge {
                    Text("•")
                        .foregroundStyle(HeirloomColors.secondaryText.opacity(0.5))

                    Text(generationText)
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.tomato)
                }
            }
        }
    }

    private var attributionText: String {
        if let author = comment.authorName {
            return "via \(author)"
        }
        return "via shared recipe"
    }

    private var generationBadge: String? {
        // Could extract generation from originProvenanceHash if needed
        // For now, show that it's from lineage
        return "lineage"
    }
}

/// Expanded attribution card for lineage comments
struct CommentAttributionCard: View {
    let commentData: AggregatedCommentData

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Header
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(HeirloomColors.tomato)

                Text("From Recipe Lineage")
                    .font(HeirloomFonts.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(HeirloomColors.primaryText)

                Spacer()

                CommentScopeBadge(scope: commentData.shareScope, compact: true)
            }

            // Generation info
            HStack(spacing: HeirloomSpacing.md) {
                // Generation
                VStack(alignment: .leading, spacing: 2) {
                    Text("Generation")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)

                    Text(commentData.sourceDisplay)
                        .font(HeirloomFonts.caption1)
                        .fontWeight(.medium)
                        .foregroundStyle(HeirloomColors.primaryText)
                }

                Divider()
                    .frame(height: 24)

                // Author
                VStack(alignment: .leading, spacing: 2) {
                    Text("Author")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)

                    Text(commentData.authorName)
                        .font(HeirloomFonts.caption1)
                        .fontWeight(.medium)
                        .foregroundStyle(HeirloomColors.primaryText)
                }

                Spacer()
            }

            // Engagement
            if commentData.engagementScore > 0 {
                HStack(spacing: HeirloomSpacing.xs) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(HeirloomColors.tomato)

                    Text(commentData.engagementDisplay)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(HeirloomColors.cream.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(HeirloomColors.tomato.opacity(0.2), lineWidth: 1)
        )
    }
}

/// Aggregated lineage comments section header
struct LineageCommentsSectionHeader: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: "person.2.circle.fill")
                    .foregroundStyle(HeirloomColors.tomato)
                    .font(.system(size: 20))

                Text("Comments from Family")
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)

                Spacer()

                Text("\(count)")
                    .font(HeirloomFonts.subheadline)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(HeirloomColors.warmGray.opacity(0.2))
                    )
            }

            Text("Comments from others who have this recipe in their collection")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding(.vertical, HeirloomSpacing.sm)
    }
}

/// Endorsement button for lineage comments
struct CommentEndorsementButton: View {
    let endorsementCount: Int
    let isEndorsed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isEndorsed ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: 14))

                if endorsementCount > 0 {
                    Text("\(endorsementCount)")
                        .font(HeirloomFonts.caption1)
                        .fontWeight(.medium)
                }
            }
            .foregroundStyle(isEndorsed ? HeirloomColors.tomato : HeirloomColors.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isEndorsed ? HeirloomColors.tomato.opacity(0.15) : HeirloomColors.warmGray.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Attribution View") {
    VStack(spacing: HeirloomSpacing.md) {
        let comment = RecipeComment(
            text: "This recipe is amazing!",
            authorName: "Sarah M.",
            source: .user
        )
        comment.shareScope = .lineage
        comment.originProvenanceHash = "different-hash"

        CommentAttributionView(
            comment: comment,
            currentRecipeHash: "current-hash"
        )
    }
    .padding()
}

#Preview("Attribution Card") {
    let commentData = AggregatedCommentData(
        commentID: UUID(),
        text: "Great recipe! I added more garlic.",
        authorName: "Sarah M.",
        rootProvenanceHash: "abc123",
        generation: 2,
        originProvenanceHash: "xyz789",
        shareScope: .lineage,
        commentType: .modification,
        endorsementCount: 5,
        upvotes: 3,
        sentimentScore: 0.8,
        topics: ["garlic", "modification"],
        createdAt: Date(),
        lastEndorsedAt: Date()
    )

    VStack(spacing: HeirloomSpacing.lg) {
        CommentAttributionCard(commentData: commentData)

        Divider()

        LineageCommentsSectionHeader(count: 12)

        Divider()

        HStack {
            CommentEndorsementButton(
                endorsementCount: 5,
                isEndorsed: false,
                action: {}
            )

            CommentEndorsementButton(
                endorsementCount: 12,
                isEndorsed: true,
                action: {}
            )
        }
    }
    .padding()
}
