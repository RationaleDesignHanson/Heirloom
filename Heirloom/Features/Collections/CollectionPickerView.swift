import SwiftUI
import SwiftData

/// Sheet for selecting a collection to add recipes to
/// Used in batch selection mode from "All Recipes" collection
struct CollectionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let selectedRecipes: [Recipe]
    let onSelect: (RecipeCollection) -> Void

    @Query(filter: #Predicate<RecipeCollection> { collection in
        // Exclude "All Recipes" - can't manually add recipes to it
        collection.isAllRecipes == false
    }, sort: \RecipeCollection.name)
    private var availableCollections: [RecipeCollection]

    var body: some View {
        NavigationStack {
            List {
                // System collections section
                if !systemCollections.isEmpty {
                    Section("System Collections") {
                        ForEach(systemCollections) { collection in
                            CollectionRow(
                                collection: collection,
                                selectedRecipes: selectedRecipes,
                                onSelect: {
                                    addRecipesToCollection(collection)
                                }
                            )
                        }
                    }
                }

                // User collections section
                if !userCollections.isEmpty {
                    Section("My Collections") {
                        ForEach(userCollections) { collection in
                            CollectionRow(
                                collection: collection,
                                selectedRecipes: selectedRecipes,
                                onSelect: {
                                    addRecipesToCollection(collection)
                                }
                            )
                        }
                    }
                }

                // Empty state
                if availableCollections.isEmpty {
                    ContentUnavailableView(
                        "No Collections",
                        systemImage: "folder",
                        description: Text("Create a collection first to organize your recipes")
                    )
                }
            }
            .navigationTitle("Add to Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var systemCollections: [RecipeCollection] {
        availableCollections.filter { $0.isSystemCollection && !$0.isHeritageCollection }
    }

    private var userCollections: [RecipeCollection] {
        availableCollections.filter { !$0.isSystemCollection && !$0.isHeritageCollection }
    }

    // MARK: - Actions

    private func addRecipesToCollection(_ collection: RecipeCollection) {
        // Add all selected recipes to the chosen collection
        for recipe in selectedRecipes {
            // Only add if not already in collection
            let alreadyInCollection = recipe.collections?.contains(where: { $0.id == collection.id }) ?? false

            if !alreadyInCollection {
                if recipe.collections == nil {
                    recipe.collections = []
                }
                recipe.collections?.append(collection)
            }
        }

        // Save changes
        try? modelContext.save()

        // Notify parent and dismiss
        onSelect(collection)
        dismiss()
    }
}

// MARK: - Collection Row

private struct CollectionRow: View {
    let collection: RecipeCollection
    let selectedRecipes: [Recipe]
    let onSelect: () -> Void

    private var recipesAlreadyInCollection: Int {
        selectedRecipes.filter { recipe in
            recipe.collections?.contains(where: { $0.id == collection.id }) ?? false
        }.count
    }

    private var allRecipesInCollection: Bool {
        recipesAlreadyInCollection == selectedRecipes.count
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Collection icon
                Image(systemName: collection.iconName)
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(collection.swiftUIColor)
                    .frame(width: 32)

                // Collection name and stats
                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.name)
                        .font(.body)
                        .foregroundStyle(.primary)

                    if recipesAlreadyInCollection > 0 {
                        Text("\(recipesAlreadyInCollection) of \(selectedRecipes.count) already added")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(collection.recipeCount) recipes")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Checkmark if all recipes already in collection
                if allRecipesInCollection {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .disabled(allRecipesInCollection)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var selectedRecipes: [Recipe] = []

    CollectionPickerView(
        selectedRecipes: selectedRecipes,
        onSelect: { collection in
            print("Selected: \(collection.name)")
        }
    )
}
