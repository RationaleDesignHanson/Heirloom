//
//  HeritageRecipeCleanupView.swift
//  Heirloom
//
//  Created by Claude on 1/5/26.
//

import SwiftUI
import SwiftData

/// View for reviewing and cleaning up unmodified heritage recipes
/// Shows recipes that have been in the app for 30+ days without being used
struct HeritageRecipeCleanupView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @StateObject private var cleanupService = HeritageRecipeCleanupService()
    @State private var selectedRecipes: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if cleanupService.isLoading {
                    loadingView
                } else if cleanupService.eligibleRecipes.isEmpty {
                    emptyStateView
                } else {
                    recipeListView
                }
            }
            .navigationTitle("Heritage Cleanup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if !cleanupService.eligibleRecipes.isEmpty {
                        Button("Remove (\(selectedRecipes.count))") {
                            showDeleteConfirmation = true
                        }
                        .disabled(selectedRecipes.isEmpty || isDeleting)
                    }
                }
            }
            .task {
                await loadEligibleRecipes()
            }
            .alert("Remove Recipes?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    Task {
                        await deleteSelectedRecipes()
                    }
                }
            } message: {
                Text("Are you sure you want to remove \(selectedRecipes.count) heritage recipe\(selectedRecipes.count == 1 ? "" : "s")? This action cannot be undone.")
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Finding eligible recipes...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("All Clean!")
                    .font(.title2.bold())

                Text("No heritage recipes are eligible for cleanup at this time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Text("Heritage recipes become eligible for cleanup after 30 days if they haven't been cooked, favorited, or annotated.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Recipe List View

    private var recipeListView: some View {
        List {
            Section {
                Text("These heritage recipes have been in your library for 30+ days without being used. Select recipes to remove them.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            Section("Eligible Recipes (\(cleanupService.eligibleRecipes.count))") {
                ForEach(cleanupService.eligibleRecipes) { recipe in
                    CleanupRecipeRow(
                        recipe: recipe,
                        isSelected: selectedRecipes.contains(recipe.id)
                    ) {
                        toggleSelection(for: recipe)
                    }
                }
            }

            Section {
                Button(action: selectAll) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Select All")
                    }
                }

                Button(action: deselectAll) {
                    HStack {
                        Image(systemName: "circle")
                        Text("Deselect All")
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadEligibleRecipes() async {
        do {
            _ = try await cleanupService.fetchRecipesForCleanup(context: modelContext)
        } catch {
            Log.error("Failed to fetch eligible recipes", category: .database, metadata: [
                "error": error.localizedDescription
            ])
        }
    }

    private func toggleSelection(for recipe: Recipe) {
        if selectedRecipes.contains(recipe.id) {
            selectedRecipes.remove(recipe.id)
        } else {
            selectedRecipes.insert(recipe.id)
        }
    }

    private func selectAll() {
        selectedRecipes = Set(cleanupService.eligibleRecipes.map { $0.id })
    }

    private func deselectAll() {
        selectedRecipes.removeAll()
    }

    private func deleteSelectedRecipes() async {
        isDeleting = true
        defer { isDeleting = false }

        let recipesToDelete = cleanupService.eligibleRecipes.filter { recipe in
            selectedRecipes.contains(recipe.id)
        }

        do {
            try await cleanupService.deleteRecipes(recipesToDelete, context: modelContext)

            // Clear selection
            selectedRecipes.removeAll()

            // Dismiss if no more recipes
            if cleanupService.eligibleRecipes.isEmpty {
                dismiss()
            }

            Log.info("Successfully deleted heritage recipes", category: .database, metadata: [
                "count": recipesToDelete.count
            ])
        } catch {
            Log.error("Failed to delete heritage recipes", category: .database, metadata: [
                "error": error.localizedDescription
            ])
        }
    }
}

// MARK: - Cleanup Recipe Row

private struct CleanupRecipeRow: View {
    let recipe: Recipe
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .secondary)

                // Recipe image
                if let imageURL = recipe.firebaseImageURL {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }

                // Recipe info
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    if let collectionId = recipe.heritageCollectionId {
                        Text(collectionId)
                            .font(.caption)
                            .foregroundStyle(.brown)
                    }

                    Text(daysOldText(for: recipe))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func daysOldText(for recipe: Recipe) -> String {
        let days = Calendar.current.dateComponents([.day], from: recipe.dateAdded, to: Date()).day ?? 0
        return "\(days) days in library"
    }
}

// MARK: - Preview

#Preview("With Recipes") {
    @Previewable @State var container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Recipe.self, configurations: config)

        // Create sample heritage recipes
        for i in 1...5 {
            let recipe = Recipe(title: "Heritage Recipe \(i)")
            recipe.isHeritageRecipe = true
            recipe.heritageCollectionId = "1950s-american-classics"
            recipe.dateAdded = Calendar.current.date(byAdding: .day, value: -35, to: Date())!
            container.mainContext.insert(recipe)
        }

        return container
    }()

    HeritageRecipeCleanupView()
        .modelContainer(container)
}

#Preview("Empty State") {
    @Previewable @State var container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Recipe.self, configurations: config)
    }()

    HeritageRecipeCleanupView()
        .modelContainer(container)
}
