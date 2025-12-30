import SwiftUI

/// Main help center view with sections, search, and FAQ
struct HelpView: View {
    @State private var searchText = ""
    @State private var showingFAQ = false
    @State private var showingGestureGuide = false

    private let helpContent = HelpContent.shared

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    mainContent
                } else {
                    searchResults
                }
            }
            .navigationTitle("Help Center")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search help articles")
            .sheet(isPresented: $showingFAQ) {
                FAQView()
            }
            .sheet(isPresented: $showingGestureGuide) {
                GestureGuideView()
            }
            .onAppear {
                AnalyticsService.shared.track(event: .helpCenterOpened)
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: HeirloomSpacing.lg) {
                // Welcome header
                headerSection

                // All help sections
                ForEach(HelpSection.allCases) { section in
                    sectionCard(for: section)
                }

                // Gesture Guide button
                gestureGuideButton

                // FAQ button
                faqButton
            }
            .padding(HeirloomSpacing.lg)
        }
        .background(HeirloomColors.appBackground)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(HeirloomColors.tomato)

                VStack(alignment: .leading, spacing: 4) {
                    Text("How can we help?")
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Browse topics or search for answers")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HeirloomSpacing.lg)
        .background(HeirloomColors.warmGray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Section Cards

    private func sectionCard(for section: HelpSection) -> some View {
        let articles = helpContent.articles(for: section)

        return NavigationLink {
            SectionDetailView(section: section)
        } label: {
            HStack(spacing: HeirloomSpacing.md) {
                // Section icon
                Image(systemName: section.icon)
                    .font(.title2)
                    .foregroundStyle(HeirloomColors.tomato)
                    .frame(width: 40, height: 40)
                    .background(HeirloomColors.tomato.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Section info
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.rawValue)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text(section.description)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                // Article count
                VStack(spacing: 2) {
                    Text("\(articles.count)")
                        .font(HeirloomFonts.title3)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("articles")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
                .frame(width: 60)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(HeirloomColors.warmGray)
            }
            .padding(HeirloomSpacing.md)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Gesture Guide Button

    private var gestureGuideButton: some View {
        Button {
            showingGestureGuide = true
            AnalyticsService.shared.track(event: .helpSectionViewed, properties: [
                "section": "gestures_guide"
            ])
        } label: {
            HStack {
                Image(systemName: "hand.tap.fill")
                    .font(.title2)
                    .foregroundStyle(HeirloomColors.tomato)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Gestures Guide")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Learn all the tap, swipe, and long-press actions")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(HeirloomColors.warmGray)
            }
            .padding(HeirloomSpacing.md)
            .background(HeirloomColors.tomato.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - FAQ Button

    private var faqButton: some View {
        Button {
            showingFAQ = true
            AnalyticsService.shared.track(event: .faqOpened)
        } label: {
            HStack {
                Image(systemName: "list.bullet.circle.fill")
                    .font(.title2)
                    .foregroundStyle(HeirloomColors.familyGreen)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Frequently Asked Questions")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Quick answers to common questions")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(HeirloomColors.warmGray)
            }
            .padding(HeirloomSpacing.md)
            .background(HeirloomColors.familyGreen.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search Results

    private var searchResults: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                let results = helpContent.search(searchText)

                if results.isEmpty {
                    noResultsView
                } else {
                    Text("Found \(results.count) \(results.count == 1 ? "result" : "results")")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .padding(.horizontal, HeirloomSpacing.lg)
                        .padding(.top, HeirloomSpacing.sm)

                    ForEach(results) { article in
                        NavigationLink {
                            HelpArticleView(article: article)
                        } label: {
                            searchResultRow(for: article)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, HeirloomSpacing.md)
        }
        .background(HeirloomColors.appBackground)
        .onAppear {
            AnalyticsService.shared.track(event: .helpSearchPerformed, properties: [
                "query": searchText,
                "results_count": helpContent.search(searchText).count
            ])
        }
    }

    // MARK: - Search Result Row

    private func searchResultRow(for article: HelpArticle) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: article.icon)
                    .foregroundStyle(HeirloomColors.tomato)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(article.title)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text(article.section.rawValue)
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(HeirloomColors.warmGray)
            }

            // Show snippet of content
            Text(article.content.prefix(150) + "...")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
                .lineLimit(2)
        }
        .padding(HeirloomSpacing.md)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
        .padding(.horizontal, HeirloomSpacing.lg)
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(HeirloomColors.warmGray)

            VStack(spacing: HeirloomSpacing.sm) {
                Text("No results found")
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("Try different keywords or browse by topic")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}

// MARK: - Section Detail View

/// Shows all articles for a specific section
private struct SectionDetailView: View {
    let section: HelpSection

    private let helpContent = HelpContent.shared

    var body: some View {
        List {
            Section {
                Text(section.description)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .listRowBackground(Color.clear)
            }

            Section {
                ForEach(helpContent.articles(for: section)) { article in
                    NavigationLink {
                        HelpArticleView(article: article)
                    } label: {
                        HStack(spacing: HeirloomSpacing.sm) {
                            Image(systemName: article.icon)
                                .foregroundStyle(HeirloomColors.tomato)
                                .frame(width: 24)

                            Text(article.title)
                                .font(HeirloomFonts.body)
                                .foregroundStyle(HeirloomColors.primaryText)
                        }
                    }
                }
            }
        }
        .navigationTitle(section.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AnalyticsService.shared.track(event: .helpSectionViewed, properties: [
                "section": section.rawValue
            ])
        }
    }
}

// MARK: - FAQ View

/// Displays frequently asked questions
private struct FAQView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private let helpContent = HelpContent.shared

    var body: some View {
        NavigationStack {
            List {
                let items = searchText.isEmpty ?
                    helpContent.faqItems :
                    helpContent.searchFAQ(searchText)

                if items.isEmpty {
                    Section {
                        Text("No matching questions found")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(HelpSection.allCases) { section in
                        let sectionItems = items.filter { $0.section == section }

                        if !sectionItems.isEmpty {
                            Section(section.rawValue) {
                                ForEach(sectionItems) { item in
                                    DisclosureGroup {
                                        Text(item.answer)
                                            .font(HeirloomFonts.body)
                                            .foregroundStyle(HeirloomColors.secondaryText)
                                            .padding(.vertical, HeirloomSpacing.sm)
                                    } label: {
                                        Text(item.question)
                                            .font(HeirloomFonts.bodyBold)
                                            .foregroundStyle(HeirloomColors.primaryText)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("FAQ")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search questions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Help View") {
    HelpView()
}

#Preview("FAQ") {
    FAQView()
}
