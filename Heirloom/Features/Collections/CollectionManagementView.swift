import SwiftUI
import SwiftData

struct CollectionManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \RecipeCollection.name) private var collections: [RecipeCollection]

    @State private var showCreateCollection = false
    @State private var editingCollection: RecipeCollection?

    var userCollections: [RecipeCollection] {
        collections.filter { !$0.isSystemCollection }
    }

    var systemCollections: [RecipeCollection] {
        collections.filter { $0.isSystemCollection }
    }

    var body: some View {
        NavigationStack {
            List {
                if !systemCollections.isEmpty {
                    Section("System Collections") {
                        ForEach(systemCollections, id: \.id) { collection in
                            collectionRow(collection, canEdit: false)
                        }
                    }
                }

                Section("My Collections") {
                    if userCollections.isEmpty {
                        emptyState
                    } else {
                        ForEach(userCollections, id: \.id) { collection in
                            collectionRow(collection, canEdit: true)
                        }
                        .onDelete(perform: deleteCollections)
                    }
                }
            }
            .navigationTitle("Collections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateCollection = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateCollection) {
                CollectionEditorView()
            }
            .sheet(item: $editingCollection) { collection in
                CollectionEditorView(collection: collection)
            }
        }
    }

    // MARK: - Collection Row

    private func collectionRow(_ collection: RecipeCollection, canEdit: Bool) -> some View {
        HStack(spacing: HeirloomSpacing.md) {
            Image(systemName: collection.iconName)
                .font(.title3)
                .foregroundStyle(collection.swiftUIColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text(collection.displayDescription)
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            Spacer()

            if canEdit {
                Button {
                    editingCollection = collection
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.3))
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: HeirloomSpacing.sm) {
                Text("No collections yet")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)

                Button("Create Collection") {
                    showCreateCollection = true
                }
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.tomato)
            }
            .padding(.vertical, HeirloomSpacing.md)
            Spacer()
        }
        .listRowBackground(Color.clear)
    }

    // MARK: - Actions

    private func deleteCollections(at offsets: IndexSet) {
        // Capture collection IDs before deleting
        let collectionIdsToDelete = offsets.map { userCollections[$0].id }

        for index in offsets {
            let collection = userCollections[index]
            modelContext.delete(collection)
        }

        do {
            try modelContext.save()

            // Delete from Firebase if active
            if BackendConfig.shared.isFirebaseActive {
                Task {
                    for collectionId in collectionIdsToDelete {
                        do {
                            try await FirebaseSyncService.shared.deleteCollection(collectionId)
                        } catch {
                            Log.warning("Failed to delete collection from Firebase", category: .firebase, metadata: ["error": error.localizedDescription, "collectionId": collectionId])
                        }
                    }
                    Log.info("Collections deleted from Firebase", category: .firebase, metadata: ["count": collectionIdsToDelete.count])
                }
            }

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            ToastManager.shared.success(title: "Collection deleted")
        } catch {
            ToastManager.shared.error(
                title: "Failed to delete collection",
                message: error.localizedDescription
            )
        }
    }
}

// MARK: - Collection Editor View

struct CollectionEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var collection: RecipeCollection?
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedIcon: String = RecipeCollection.predefinedIcons[0]
    @State private var selectedColor: String = Tag.predefinedColors[0]

    private var isEditing: Bool {
        collection != nil
    }

    init(collection: RecipeCollection? = nil) {
        self.collection = collection
        if let collection = collection {
            _name = State(initialValue: collection.name)
            _description = State(initialValue: collection.desc ?? "")
            _selectedIcon = State(initialValue: collection.iconName)
            _selectedColor = State(initialValue: collection.color)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Collection Name") {
                    TextField("Enter collection name", text: $name)
                        .font(HeirloomFonts.body)
                }

                Section("Description (Optional)") {
                    TextField("Add a description", text: $description, axis: .vertical)
                        .font(HeirloomFonts.body)
                        .lineLimit(2...4)
                }

                Section("Icon") {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 60))
                        ],
                        spacing: HeirloomSpacing.md
                    ) {
                        ForEach(RecipeCollection.predefinedIcons, id: \.self) { iconName in
                            iconButton(iconName)
                        }
                    }
                    .padding(.vertical, HeirloomSpacing.sm)
                }

                Section("Color") {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 50))
                        ],
                        spacing: HeirloomSpacing.md
                    ) {
                        ForEach(Tag.predefinedColors, id: \.self) { colorHex in
                            colorButton(colorHex)
                        }
                    }
                    .padding(.vertical, HeirloomSpacing.sm)
                }

                if isEditing, let collection = collection {
                    Section {
                        HStack {
                            Text("Recipes")
                                .font(HeirloomFonts.body)
                                .foregroundStyle(HeirloomColors.secondaryText)

                            Spacer()

                            Text("\(collection.recipeCount)")
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(HeirloomColors.primaryText)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Collection" : "New Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        saveCollection()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Icon Button

    private func iconButton(_ iconName: String) -> some View {
        Button {
            selectedIcon = iconName

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedIcon == iconName ? Color(hex: selectedColor).opacity(0.2) : .gray.opacity(0.1))
                        .frame(width: 60, height: 60)

                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundStyle(selectedIcon == iconName ? Color(hex: selectedColor) : .gray)
                }

                if selectedIcon == iconName {
                    Circle()
                        .fill(Color(hex: selectedColor))
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(.clear)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Color Button

    private func colorButton(_ colorHex: String) -> some View {
        Button {
            selectedColor = colorHex

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 50, height: 50)

                if selectedColor == colorHex {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func saveCollection() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)

        let collectionToSync: RecipeCollection
        if let existingCollection = collection {
            // Update existing collection
            existingCollection.name = trimmedName
            existingCollection.desc = trimmedDescription.isEmpty ? nil : trimmedDescription
            existingCollection.iconName = selectedIcon
            existingCollection.color = selectedColor
            collectionToSync = existingCollection
        } else {
            // Create new collection
            let newCollection = RecipeCollection(
                name: trimmedName,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                iconName: selectedIcon,
                color: selectedColor
            )
            modelContext.insert(newCollection)
            collectionToSync = newCollection
        }

        do {
            try modelContext.save()

            // Sync to Firebase if active
            if BackendConfig.shared.isFirebaseActive {
                Task {
                    do {
                        try await FirebaseSyncService.shared.uploadCollection(collectionToSync)
                        Log.info("Collection synced to Firebase", category: .firebase, metadata: ["collectionId": collectionToSync.id])
                    } catch {
                        Log.warning("Failed to sync collection to Firebase", category: .firebase, metadata: ["error": error.localizedDescription, "collectionId": collectionToSync.id])
                    }
                }
            }

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            ToastManager.shared.success(
                title: isEditing ? "Collection updated" : "Collection created"
            )

            dismiss()
        } catch {
            ToastManager.shared.error(
                title: "Failed to save collection",
                message: error.localizedDescription
            )
        }
    }
}

// MARK: - Preview

#Preview {
    CollectionManagementView()
        .modelContainer(for: RecipeCollection.self, inMemory: true)
        .toastContainer()
}

#Preview("Editor") {
    CollectionEditorView()
        .modelContainer(for: RecipeCollection.self, inMemory: true)
        .toastContainer()
}
