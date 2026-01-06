//
//  BatchTagCollectionPickerView.swift
//  Heirloom
//
//  Created by Claude on 1/5/26.
//

import SwiftUI
import SwiftData

/// Batch version of TagCollectionPickerView for adding multiple recipes to tags/collections
struct BatchTagCollectionPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.firebaseSync) private var firebaseSync

    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(sort: \RecipeCollection.name) private var allCollections: [RecipeCollection]
    @Query private var allRecipes: [Recipe]

    let selectedRecipeIds: Set<UUID>
    let onComplete: () -> Void

    private var backendConfig: BackendConfig { ServiceContainer.shared.resolve(BackendConfig.self) }
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }

    @State private var showTagManagement = false
    @State private var showCollectionManagement = false

    private var selectedRecipes: [Recipe] {
        allRecipes.filter { selectedRecipeIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                // Summary Section
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(HeirloomColors.tomato)
                        Text("\(selectedRecipeIds.count) recipes selected")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.primaryText)
                    }
                } header: {
                    Text("Batch Operation")
                }

                // Tags Section
                Section {
                    if allTags.isEmpty {
                        HStack {
                            Text("No tags yet")
                                .font(HeirloomFonts.body)
                                .foregroundStyle(HeirloomColors.secondaryText)

                            Spacer()

                            Button("Create Tag") {
                                showTagManagement = true
                            }
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.tomato)
                        }
                    } else {
                        ForEach(allTags, id: \.id) { tag in
                            tagRow(tag)
                        }
                    }
                } header: {
                    HStack {
                        Text("Tags")
                        Spacer()
                        Button {
                            showTagManagement = true
                        } label: {
                            Text("Manage")
                                .font(HeirloomFonts.caption2)
                        }
                    }
                }

                // Collections Section
                Section {
                    if allCollections.isEmpty {
                        HStack {
                            Text("No collections yet")
                                .font(HeirloomFonts.body)
                                .foregroundStyle(HeirloomColors.secondaryText)

                            Spacer()

                            Button("Create Collection") {
                                showCollectionManagement = true
                            }
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.tomato)
                        }
                    } else {
                        ForEach(allCollections, id: \.id) { collection in
                            collectionRow(collection)
                        }
                    }
                } header: {
                    HStack {
                        Text("Collections")
                        Spacer()
                        Button {
                            showCollectionManagement = true
                        } label: {
                            Text("Manage")
                                .font(HeirloomFonts.caption2)
                        }
                    }
                }
            }
            .navigationTitle("Add to Tags & Collections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onComplete()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                        onComplete()
                    }
                }
            }
            .sheet(isPresented: $showTagManagement) {
                TagManagementView()
            }
            .sheet(isPresented: $showCollectionManagement) {
                CollectionManagementView()
            }
        }
    }

    // MARK: - Tag Row

    private func tagRow(_ tag: Tag) -> some View {
        Button {
            toggleTag(tag)
        } label: {
            HStack(spacing: HeirloomSpacing.md) {
                Circle()
                    .fill(tag.swiftUIColor)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tag.name)
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)

                    let taggedCount = countRecipesWithTag(tag)
                    if taggedCount > 0 {
                        Text("\(taggedCount) of \(selectedRecipeIds.count) already tagged")
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }

                Spacer()

                let taggedCount = countRecipesWithTag(tag)
                if taggedCount == selectedRecipeIds.count {
                    // All selected recipes have this tag
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(tag.swiftUIColor)
                        .font(.title3)
                } else if taggedCount > 0 {
                    // Some recipes have this tag
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(tag.swiftUIColor)
                        .font(.title3)
                } else {
                    // No recipes have this tag
                    Image(systemName: "circle")
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.3))
                        .font(.title3)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Collection Row

    private func collectionRow(_ collection: RecipeCollection) -> some View {
        Button {
            toggleCollection(collection)
        } label: {
            HStack(spacing: HeirloomSpacing.md) {
                Image(systemName: collection.iconName)
                    .font(.title3)
                    .foregroundStyle(collection.swiftUIColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.name)
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)

                    let collectedCount = countRecipesInCollection(collection)
                    if collectedCount > 0 {
                        Text("\(collectedCount) of \(selectedRecipeIds.count) already in collection")
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }

                Spacer()

                let collectedCount = countRecipesInCollection(collection)
                if collectedCount == selectedRecipeIds.count {
                    // All selected recipes are in this collection
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(collection.swiftUIColor)
                        .font(.title3)
                } else if collectedCount > 0 {
                    // Some recipes are in this collection
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(collection.swiftUIColor)
                        .font(.title3)
                } else {
                    // No recipes are in this collection
                    Image(systemName: "circle")
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.3))
                        .font(.title3)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helper Functions

    private func countRecipesWithTag(_ tag: Tag) -> Int {
        selectedRecipes.filter { recipe in
            recipe.tags?.contains(where: { $0.id == tag.id }) ?? false
        }.count
    }

    private func countRecipesInCollection(_ collection: RecipeCollection) -> Int {
        selectedRecipes.filter { recipe in
            recipe.collections?.contains(where: { $0.id == collection.id }) ?? false
        }.count
    }

    // MARK: - Actions

    private func toggleTag(_ tag: Tag) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        let recipesWithTag = countRecipesWithTag(tag)
        let shouldAdd = recipesWithTag < selectedRecipeIds.count

        var updatedCount = 0

        for recipe in selectedRecipes {
            let hasTag = recipe.tags?.contains(where: { $0.id == tag.id }) ?? false

            if shouldAdd && !hasTag {
                // Add tag to recipe
                if var tags = recipe.tags {
                    tags.append(tag)
                    recipe.tags = tags
                } else {
                    recipe.tags = [tag]
                }
                updatedCount += 1
            } else if !shouldAdd && hasTag {
                // Remove tag from recipe
                if var tags = recipe.tags {
                    tags.removeAll(where: { $0.id == tag.id })
                    recipe.tags = tags
                }
                updatedCount += 1
            }
        }

        do {
            try modelContext.save()

            // Show toast
            let action = shouldAdd ? "added to" : "removed from"
            toastManager.success(
                title: "Tag \(action) \(updatedCount) recipes",
                message: tag.name
            )

            // Sync to Firebase if active
            if backendConfig.isFirebaseActive {
                Task {
                    do {
                        // Sync the tag itself
                        try await firebaseSync.uploadTag(tag)

                        // Sync all updated recipes
                        for recipe in selectedRecipes {
                            try await firebaseSync.uploadRecipe(recipe)
                        }

                        Log.info("Batch tag toggle synced to Firebase", category: .firebase, metadata: [
                            "tagId": tag.id.uuidString,
                            "recipeCount": updatedCount,
                            "action": action
                        ])
                    } catch {
                        Log.warning("Failed to sync batch tag toggle to Firebase", category: .firebase, metadata: [
                            "error": error.localizedDescription,
                            "tagId": tag.id.uuidString
                        ])
                    }
                }
            }
        } catch {
            toastManager.error(
                title: "Failed to update tags",
                message: error.localizedDescription
            )
        }
    }

    private func toggleCollection(_ collection: RecipeCollection) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        let recipesInCollection = countRecipesInCollection(collection)
        let shouldAdd = recipesInCollection < selectedRecipeIds.count

        var updatedCount = 0

        for recipe in selectedRecipes {
            let hasCollection = recipe.collections?.contains(where: { $0.id == collection.id }) ?? false

            if shouldAdd && !hasCollection {
                // Add collection to recipe
                if var collections = recipe.collections {
                    collections.append(collection)
                    recipe.collections = collections
                } else {
                    recipe.collections = [collection]
                }
                updatedCount += 1
            } else if !shouldAdd && hasCollection {
                // Remove collection from recipe
                if var collections = recipe.collections {
                    collections.removeAll(where: { $0.id == collection.id })
                    recipe.collections = collections
                }
                updatedCount += 1
            }
        }

        do {
            try modelContext.save()

            // Show toast
            let action = shouldAdd ? "added to" : "removed from"
            toastManager.success(
                title: "\(updatedCount) recipes \(action) collection",
                message: collection.name
            )

            // Sync to Firebase if active
            if backendConfig.isFirebaseActive {
                Task {
                    do {
                        // Sync the collection itself
                        try await firebaseSync.uploadCollection(collection)

                        // Sync all updated recipes
                        for recipe in selectedRecipes {
                            try await firebaseSync.uploadRecipe(recipe)
                        }

                        Log.info("Batch collection toggle synced to Firebase", category: .firebase, metadata: [
                            "collectionId": collection.id.uuidString,
                            "recipeCount": updatedCount,
                            "action": action
                        ])
                    } catch {
                        Log.warning("Failed to sync batch collection toggle to Firebase", category: .firebase, metadata: [
                            "error": error.localizedDescription,
                            "collectionId": collection.id.uuidString
                        ])
                    }
                }
            }
        } catch {
            toastManager.error(
                title: "Failed to update collections",
                message: error.localizedDescription
            )
        }
    }
}
