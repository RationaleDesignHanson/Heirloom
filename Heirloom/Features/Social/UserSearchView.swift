//
//  UserSearchView.swift
//  Heirloom
//
//  Phase 7: User Discovery
//  Main user search interface
//

import SwiftUI

struct UserSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [UserSearchResult] = []
    @State private var isSearching = false
    @State private var selectedUser: UserSearchResult?
    @State private var showUserPreview = false
    @State private var currentFilters = SearchFilters()
    @State private var showFilters = false
    @StateObject private var historyManager = SearchHistoryManager()

    private var searchService: SearchServiceProtocol {
        ServiceContainer.shared.resolve(SearchServiceProtocol.self)
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Search bar
                searchBar

                if searchText.isEmpty && !historyManager.recentSearches.isEmpty {
                    recentSearchesView
                } else if isSearching {
                    loadingView
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    emptyStateView
                } else {
                    resultsListView
                }
            }
            .navigationTitle("Find Users")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: currentFilters.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundStyle(currentFilters.isActive ? HeirloomColors.tomato : .primary)
                    }
                }
            }
            .sheet(isPresented: $showUserPreview) {
                if let user = selectedUser {
                    UserProfilePreviewSheet(user: user)
                }
            }
            .sheet(isPresented: $showFilters) {
                SearchFiltersSheet(filters: $currentFilters)
                    .onDisappear {
                        // Re-run search with new filters
                        Task {
                            await performSearch(query: searchText)
                        }
                    }
            }
        }
    }

    private var searchBar: some View {
        TextField("Search by name", text: $searchText)
            .textFieldStyle(.roundedBorder)
            .padding()
            .onChange(of: searchText) { _, newValue in
                Task {
                    await performSearch(query: newValue)
                }
            }
    }

    private var resultsListView: some View {
        ScrollView {
            LazyVStack {
                ForEach(searchResults) { user in
                    UserSearchResultRow(user: user)
                        .onTapGesture {
                            selectedUser = user
                            showUserPreview = true
                        }
                }
            }
            .padding(.horizontal, HeirloomSpacing.md)
        }
    }

    private var loadingView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            ProgressView()
            Text("Searching...")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "person.fill.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.warmGray.opacity(0.3))

            Text("No users found")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("Try a different search term")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    private var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Text("Recent Searches")
                    .font(HeirloomFonts.caption1Bold)
                    .foregroundStyle(HeirloomColors.secondaryText)

                Spacer()

                Button("Clear") {
                    historyManager.clearAll()
                }
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.tomato)
            }
            .padding(.horizontal, HeirloomSpacing.md)

            ScrollView {
                LazyVStack(spacing: HeirloomSpacing.xs) {
                    ForEach(historyManager.recentSearches) { entry in
                        Button {
                            searchText = entry.query
                            if let filters = entry.filters {
                                currentFilters = filters
                            }
                        } label: {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundStyle(HeirloomColors.secondaryText)

                                Text(entry.query)
                                    .font(HeirloomFonts.body)
                                    .foregroundStyle(HeirloomColors.primaryText)

                                if entry.filters?.isActive == true {
                                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(HeirloomColors.tomato)
                                }

                                Spacer()

                                Button {
                                    historyManager.removeSearch(id: entry.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(HeirloomColors.warmGray)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding()
                            .background(HeirloomColors.cardBackground)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, HeirloomSpacing.md)
            }
        }
    }

    private func performSearch(query: String) async {
        guard !query.isEmpty, query.count >= 2 else {
            searchResults = []
            return
        }

        // Debounce
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

        isSearching = true

        do {
            let results = try await searchService.searchUsers(
                query: query,
                filters: currentFilters.isActive ? currentFilters : nil
            )
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false

                // Add to search history
                historyManager.addSearch(
                    query: query,
                    filters: currentFilters.isActive ? currentFilters : nil
                )
            }
        } catch {
            await MainActor.run {
                self.searchResults = []
                self.isSearching = false
            }
            Log.error("User search failed", category: .social, error: error)
        }
    }
}
