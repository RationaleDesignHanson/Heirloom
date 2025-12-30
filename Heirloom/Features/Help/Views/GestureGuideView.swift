import SwiftUI

// MARK: - Gesture Guide View
/// Comprehensive, searchable guide to all gestures in Heirloom
struct GestureGuideView: View {
    @State private var searchText = ""
    @State private var selectedCategory: GestureCategory? = nil
    @Environment(\.dismiss) private var dismiss

    private let gestureGuide = GestureGuide.shared

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    mainContent
                } else {
                    searchResults
                }
            }
            .searchable(text: $searchText, prompt: "Search gestures")
            .navigationTitle("Gestures Guide")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Track analytics
                AnalyticsService.shared.track(event: .helpSectionViewed, properties: [
                    "section": "gestures_guide"
                ])
            }
        }
    }

    // MARK: - Main Content
    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Master Heirloom's intuitive gestures")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)

                    Text("\(gestureGuide.allGestures.count) gestures across \(gestureGuide.categories.count) categories")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.warmGray)
                }
                .padding(.horizontal, HeirloomSpacing.lg)

                // Categories
                ForEach(gestureGuide.categories) { category in
                    categorySection(category)
                }
            }
            .padding(.vertical, HeirloomSpacing.lg)
        }
        .background(HeirloomColors.appBackground)
    }

    // MARK: - Category Section
    private func categorySection(_ category: GestureCategory) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            // Category Header
            HStack {
                Image(systemName: category.icon)
                    .foregroundStyle(HeirloomColors.tomato)
                    .font(.title3)

                Text(category.rawValue)
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)

                Spacer()

                Text("\(category.gestures.count)")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(HeirloomColors.warmGray.opacity(0.2))
                    )
            }
            .padding(.horizontal, HeirloomSpacing.lg)

            // Gestures
            VStack(spacing: HeirloomSpacing.sm) {
                ForEach(category.gestures) { gesture in
                    gestureRow(gesture)
                }
            }
        }
    }

    // MARK: - Gesture Row
    private func gestureRow(_ gesture: Gesture) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.md) {
            // Icon
            Image(systemName: gesture.icon)
                .font(.title2)
                .foregroundStyle(HeirloomColors.tomato)
                .frame(width: 32)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Gesture type badge + name
                HStack(spacing: 8) {
                    Text(gesture.gestureType.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(HeirloomColors.tomato)
                        .textCase(.uppercase)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(HeirloomColors.tomato.opacity(0.1))
                        )

                    Text(gesture.name)
                        .font(HeirloomFonts.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(HeirloomColors.primaryText)
                }

                Text(gesture.description)
                    .font(HeirloomFonts.footnote)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(HeirloomSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
        )
        .padding(.horizontal, HeirloomSpacing.lg)
    }

    // MARK: - Search Results
    private var searchResults: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                let results = gestureGuide.search(searchText)

                if results.isEmpty {
                    noResultsView
                } else {
                    // Results count
                    Text("\(results.count) \(results.count == 1 ? "gesture" : "gestures") found")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .padding(.horizontal, HeirloomSpacing.lg)
                        .padding(.top, HeirloomSpacing.md)

                    // Results
                    ForEach(results) { gesture in
                        gestureRow(gesture)
                    }
                }
            }
            .padding(.vertical, HeirloomSpacing.lg)
        }
        .background(HeirloomColors.appBackground)
        .onChange(of: searchText) { oldValue, newValue in
            if !newValue.isEmpty {
                // Track search
                AnalyticsService.shared.track(event: .helpSearchPerformed, properties: [
                    "query": newValue,
                    "context": "gestures_guide",
                    "result_count": gestureGuide.search(newValue).count
                ])
            }
        }
    }

    // MARK: - No Results
    private var noResultsView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "hand.raised.slash")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.warmGray)

            Text("No gestures found")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("Try searching for \"tap\", \"swipe\", or \"long press\"")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(HeirloomSpacing.xl)
    }
}

// MARK: - Preview
#Preview {
    GestureGuideView()
}
