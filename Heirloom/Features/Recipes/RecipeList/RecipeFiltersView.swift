import SwiftUI

struct RecipeFiltersView: View {
    @Binding var filters: RecipeFilters
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Source Type Section
                sourceTypeSection

                // Status Section
                statusSection

                // Sort Section
                sortSection
            }
            .navigationTitle("Filter & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        filters = RecipeFilters()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Source Type Section

    private var sourceTypeSection: some View {
        Section {
            Toggle("All Sources", isOn: Binding(
                get: { filters.sourceTypes.isEmpty },
                set: { if $0 { filters.sourceTypes = [] } }
            ))
            .tint(HeirloomColors.tomato)

            if !filters.sourceTypes.isEmpty {
                ForEach(RecipeSourceType.allCases, id: \.self) { sourceType in
                    Toggle(isOn: Binding(
                        get: { filters.sourceTypes.contains(sourceType) },
                        set: { isOn in
                            if isOn {
                                filters.sourceTypes.insert(sourceType)
                            } else {
                                filters.sourceTypes.remove(sourceType)
                            }
                        }
                    )) {
                        Label(sourceType.displayName, systemImage: sourceType.iconName)
                    }
                    .tint(HeirloomColors.tomato)
                }
            }

            Button {
                if filters.sourceTypes.isEmpty {
                    filters.sourceTypes = Set(RecipeSourceType.allCases)
                } else {
                    filters.sourceTypes = []
                }
            } label: {
                Text(filters.sourceTypes.isEmpty ? "Select Specific Sources" : "Clear Selection")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.tomato)
            }
        } header: {
            Text("Source Type")
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        Section {
            Toggle("Favorites Only", isOn: $filters.favoritesOnly)
                .tint(HeirloomColors.tomato)

            Toggle("In Shopping List", isOn: $filters.inShoppingListOnly)
                .tint(HeirloomColors.tomato)

            Toggle("Cooked Before", isOn: $filters.cookedOnly)
                .tint(HeirloomColors.tomato)

            Toggle("Never Cooked", isOn: $filters.notCookedOnly)
                .tint(HeirloomColors.tomato)
                .disabled(filters.cookedOnly)
        } header: {
            Text("Status")
        } footer: {
            if filters.cookedOnly && filters.notCookedOnly {
                Text("Cannot filter for both cooked and never cooked")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Sort Section

    private var sortSection: some View {
        Section {
            LabeledContent("Sort By") {
                Picker("", selection: $filters.sortOption) {
                    ForEach(RecipeSortOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            Picker("Order", selection: $filters.sortOrder) {
                Label("Ascending", systemImage: "arrow.up").tag(SortOrder.ascending)
                Label("Descending", systemImage: "arrow.down").tag(SortOrder.descending)
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Sort")
        }
    }
}

// MARK: - Recipe Filters Model

struct RecipeFilters {
    var sourceTypes: Set<RecipeSourceType> = []
    var favoritesOnly: Bool = false
    var inShoppingListOnly: Bool = false
    var cookedOnly: Bool = false
    var notCookedOnly: Bool = false
    var sortOption: RecipeSortOption = .dateAdded
    var sortOrder: SortOrder = .descending

    var isActive: Bool {
        !sourceTypes.isEmpty ||
        favoritesOnly ||
        inShoppingListOnly ||
        cookedOnly ||
        notCookedOnly ||
        sortOption != .dateAdded ||
        sortOrder != .descending
    }

    var activeFilterCount: Int {
        var count = 0
        if !sourceTypes.isEmpty { count += 1 }
        if favoritesOnly { count += 1 }
        if inShoppingListOnly { count += 1 }
        if cookedOnly { count += 1 }
        if notCookedOnly { count += 1 }
        return count
    }
}

// MARK: - Sort Options

enum RecipeSortOption: String, CaseIterable {
    case dateAdded = "Date Added"
    case title = "Title"
    case timesCooked = "Times Cooked"
    case lastCooked = "Last Cooked"
    case lastViewed = "Last Viewed"

    var displayName: String {
        rawValue
    }
}

enum SortOrder {
    case ascending
    case descending
}

#Preview {
    RecipeFiltersView(filters: .constant(RecipeFilters()))
}
