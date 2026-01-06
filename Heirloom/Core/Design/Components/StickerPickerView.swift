//
//  StickerPickerView.swift
//  Heirloom
//
//  Created by Claude on 1/5/26.
//

import SwiftUI
import SwiftData

/// View for browsing and selecting stickers to add to recipe cards
struct StickerPickerView: View {
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Dependencies
    @StateObject private var libraryService: StickerLibraryService

    // MARK: - State
    @State private var selectedCategory: StickerCategory?
    @State private var searchQuery: String = ""
    @State private var showFavoritesOnly: Bool = false

    // MARK: - Callback
    let onStickerSelected: (StickerAsset) -> Void

    // MARK: - Computed Properties
    @State private var stickers: [StickerAsset] = []
    @State private var isLoading = false

    // MARK: - Initialization
    init(
        libraryService: StickerLibraryService = StickerLibraryService(),
        onStickerSelected: @escaping (StickerAsset) -> Void
    ) {
        _libraryService = StateObject(wrappedValue: libraryService)
        self.onStickerSelected = onStickerSelected
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar

                // Category Pills
                categoryPills

                Divider()

                // Stickers Grid
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if stickers.isEmpty {
                    emptyStateView
                } else {
                    stickerGrid
                }
            }
            .navigationTitle("Add Sticker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showFavoritesOnly.toggle()
                        loadStickers()
                    } label: {
                        Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                            .foregroundColor(showFavoritesOnly ? .red : .primary)
                    }
                }
            }
            .task {
                await initializeLibrary()
                loadStickers()
            }
            .onChange(of: searchQuery) { _, _ in
                loadStickers()
            }
            .onChange(of: selectedCategory) { _, _ in
                loadStickers()
            }
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search stickers...", text: $searchQuery)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }

    // MARK: - Category Pills
    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" pill
                CategoryPill(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                // Category pills
                ForEach(StickerCategory.allCases, id: \.self) { category in
                    CategoryPill(
                        title: category.displayName,
                        icon: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Sticker Grid
    private var stickerGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 16)
                ],
                spacing: 16
            ) {
                ForEach(stickers, id: \.id) { sticker in
                    StickerGridItem(sticker: sticker) {
                        handleStickerSelection(sticker)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Stickers Found")
                .font(.headline)

            if showFavoritesOnly {
                Text("You haven't favorited any stickers yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else if !searchQuery.isEmpty {
                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Check back later for new stickers")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Helper Methods

    private func initializeLibrary() async {
        do {
            try await libraryService.initializeDefaultLibrary(context: modelContext)
        } catch {
            Log.error("Failed to initialize sticker library", category: .database, metadata: [
                "error": error.localizedDescription
            ])
        }
    }

    private func loadStickers() {
        isLoading = true

        Task {
            do {
                var result: [StickerAsset]

                if showFavoritesOnly {
                    result = try libraryService.fetchFavoriteStickers(context: modelContext)
                } else if !searchQuery.isEmpty {
                    result = try libraryService.searchStickers(query: searchQuery, context: modelContext)
                } else if let category = selectedCategory {
                    result = try libraryService.fetchStickers(category: category, context: modelContext)
                } else {
                    result = try libraryService.fetchAllStickers(context: modelContext)
                }

                await MainActor.run {
                    stickers = result
                    isLoading = false
                }
            } catch {
                Log.error("Failed to load stickers", category: .database, metadata: [
                    "error": error.localizedDescription
                ])
                await MainActor.run {
                    stickers = []
                    isLoading = false
                }
            }
        }
    }

    private func handleStickerSelection(_ sticker: StickerAsset) {
        // Increment use count
        Task {
            do {
                try await libraryService.incrementUseCount(stickerId: sticker.id, context: modelContext)
            } catch {
                Log.error("Failed to increment sticker use count", category: .database)
            }
        }

        // Call selection callback
        onStickerSelected(sticker)

        // Dismiss picker
        dismiss()
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))

                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor : Color(.systemGray5)
            )
            .foregroundColor(
                isSelected ? .white : .primary
            )
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sticker Grid Item

struct StickerGridItem: View {
    let sticker: StickerAsset
    let onTap: () -> Void

    @State private var isFavorited: Bool

    init(sticker: StickerAsset, onTap: @escaping () -> Void) {
        self.sticker = sticker
        self.onTap = onTap
        _isFavorited = State(initialValue: sticker.isFavorited)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Sticker Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(width: 80, height: 80)

                    // Render sticker preview
                    if let previewData = sticker.previewImageData,
                       let uiImage = UIImage(data: previewData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                    } else {
                        // Fallback to SF Symbol
                        Image(systemName: fallbackIcon)
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                    }

                    // Premium badge
                    if sticker.isPremium {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.yellow)
                                    .padding(4)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                                    .padding(4)
                            }
                            Spacer()
                        }
                    }
                }

                // Sticker Name
                Text(sticker.name)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                toggleFavorite()
            } label: {
                Label(
                    isFavorited ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: isFavorited ? "heart.fill" : "heart"
                )
            }
        }
    }

    private var fallbackIcon: String {
        switch sticker.category {
        case .vintage: return "clock"
        case .decorative: return "sparkles"
        case .seasonal: return "snowflake"
        case .icons: return "heart.fill"
        case .botanical: return "leaf"
        case .utensils: return "fork.knife"
        case .typography: return "textformat"
        case .frames: return "photo"
        }
    }

    private func toggleFavorite() {
        sticker.toggleFavorite()
        isFavorited = sticker.isFavorited
    }
}

// MARK: - Preview

#Preview {
    StickerPickerView { sticker in
        print("Selected sticker: \(sticker.name)")
    }
}
