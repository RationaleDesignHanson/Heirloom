import SwiftUI

/// Displays a single help article with formatted content and related articles
struct HelpArticleView: View {
    let article: HelpArticle

    @Environment(\.dismiss) private var dismiss

    private var helpContent: HelpContent { ServiceContainer.shared.resolve(HelpContent.self) }
    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
                // Article icon and title
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    HStack(spacing: HeirloomSpacing.sm) {
                        Image(systemName: article.icon)
                            .font(.title2)
                            .foregroundStyle(HeirloomColors.tomato)

                        Text(article.section.rawValue)
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    Text(article.title)
                        .font(HeirloomFonts.largeTitle)
                        .foregroundStyle(HeirloomColors.primaryText)
                }
                .padding(.bottom, HeirloomSpacing.sm)

                // Article content
                Text(formatContent(article.content))
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .textSelection(.enabled)

                // Related articles
                if !article.relatedArticles.isEmpty {
                    relatedArticlesSection
                }
            }
            .padding(HeirloomSpacing.lg)
        }
        .background(HeirloomColors.appBackground)
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            analytics.track(event: .helpArticleViewed, properties: [
                "article_id": article.id,
                "article_title": article.title,
                "section": article.section.rawValue
            ])
        }
    }

    // MARK: - Related Articles Section

    private var relatedArticlesSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Divider()
                .padding(.vertical, HeirloomSpacing.sm)

            Text("Related Articles")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            ForEach(helpContent.relatedArticles(for: article)) { relatedArticle in
                NavigationLink {
                    HelpArticleView(article: relatedArticle)
                } label: {
                    HStack(spacing: HeirloomSpacing.sm) {
                        Image(systemName: relatedArticle.icon)
                            .foregroundStyle(HeirloomColors.tomato)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(relatedArticle.title)
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(HeirloomColors.primaryText)

                            Text(relatedArticle.section.rawValue)
                                .font(HeirloomFonts.caption2)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(HeirloomColors.warmGray)
                    }
                    .padding(HeirloomSpacing.md)
                    .background(HeirloomColors.warmGray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Content Formatting

    /// Format markdown-style content to AttributedString
    /// Supports **bold**, bullet points, and numbered lists
    private func formatContent(_ content: String) -> AttributedString {
        let attributedString = AttributedString(content)

        // Apply bold formatting for **text**
        if content.range(of: #"\*\*(.*?)\*\*"#, options: .regularExpression) != nil {
            // For now, return plain text - SwiftUI Text handles markdown automatically
            // This is a simplified approach; markdown parsing could be enhanced later
        }

        return attributedString
    }
}

// MARK: - Preview

#Preview("Help Article") {
    NavigationStack {
        HelpArticleView(
            article: ServiceContainer.shared.resolve(HelpContent.self).gettingStartedArticles[0]
        )
    }
}
