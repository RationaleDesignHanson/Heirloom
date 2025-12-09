import SwiftUI
import SwiftData

struct TagCollectionPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(sort: \RecipeCollection.name) private var allCollections: [RecipeCollection]

    @Bindable var recipe: Recipe

    @State private var showTagManagement = false
    @State private var showCollectionManagement = false

    var body: some View {
        NavigationStack {
            List {
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
            .navigationTitle("Organize Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
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

                Text(tag.name)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)

                Spacer()

                if isTagSelected(tag) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(tag.swiftUIColor)
                        .font(.title3)
                } else {
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

                Text(collection.name)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)

                Spacer()

                if isCollectionSelected(collection) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(collection.swiftUIColor)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.3))
                        .font(.title3)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func isTagSelected(_ tag: Tag) -> Bool {
        recipe.tags?.contains(where: { $0.id == tag.id }) ?? false
    }

    private func toggleTag(_ tag: Tag) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if var tags = recipe.tags {
            if let index = tags.firstIndex(where: { $0.id == tag.id }) {
                tags.remove(at: index)
            } else {
                tags.append(tag)
            }
            recipe.tags = tags
        } else {
            recipe.tags = [tag]
        }

        try? modelContext.save()
    }

    private func isCollectionSelected(_ collection: RecipeCollection) -> Bool {
        recipe.collections?.contains(where: { $0.id == collection.id }) ?? false
    }

    private func toggleCollection(_ collection: RecipeCollection) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if var collections = recipe.collections {
            if let index = collections.firstIndex(where: { $0.id == collection.id }) {
                collections.remove(at: index)
            } else {
                collections.append(collection)
            }
            recipe.collections = collections
        } else {
            recipe.collections = [collection]
        }

        try? modelContext.save()
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Recipe.self, Tag.self, RecipeCollection.self,
        configurations: config
    )

    let recipe = Recipe.example
    container.mainContext.insert(recipe)

    return TagCollectionPickerView(recipe: recipe)
        .modelContainer(container)
        .toastContainer()
}
