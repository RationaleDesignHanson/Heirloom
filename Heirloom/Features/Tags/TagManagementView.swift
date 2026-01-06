import SwiftUI
import SwiftData

struct TagManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.firebaseSync) private var firebaseSync

    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }
    private var backendConfig: BackendConfig { ServiceContainer.shared.resolve(BackendConfig.self) }

    @Query(sort: \Tag.name) private var tags: [Tag]

    @State private var showCreateTag = false
    @State private var editingTag: Tag?

    var body: some View {
        NavigationStack {
            List {
                if tags.isEmpty {
                    emptyState
                } else {
                    ForEach(tags, id: \.id) { tag in
                        tagRow(tag)
                    }
                    .onDelete(perform: deleteTags)
                }
            }
            .navigationTitle("Manage Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateTag = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateTag) {
                TagEditorView()
            }
            .sheet(item: $editingTag) { tag in
                TagEditorView(tag: tag)
            }
        }
    }

    // MARK: - Tag Row

    private func tagRow(_ tag: Tag) -> some View {
        HStack(spacing: HeirloomSpacing.md) {
            Circle()
                .fill(tag.swiftUIColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("\(tag.recipeCount) recipe\(tag.recipeCount == 1 ? "" : "s")")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            Spacer()

            Button {
                editingTag = tag
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.3))
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Tags", systemImage: "tag")
        } description: {
            Text("Create tags to organize your recipes")
        } actions: {
            Button("Create Tag") {
                showCreateTag = true
            }
            .buttonStyle(.borderedProminent)
            .tint(HeirloomColors.tomato)
        }
    }

    // MARK: - Actions

    private func deleteTags(at offsets: IndexSet) {
        // Capture tag IDs before deleting
        let tagIdsToDelete = offsets.map { tags[$0].id }

        for index in offsets {
            let tag = tags[index]
            modelContext.delete(tag)
        }

        do {
            try modelContext.save()

            // Delete from Firebase if active
            if backendConfig.isFirebaseActive {
                Task {
                    for tagId in tagIdsToDelete {
                        do {
                            try await firebaseSync.deleteTag(tagId)
                        } catch {
                            Log.warning("Failed to delete tag from Firebase", category: .firebase, metadata: ["error": error.localizedDescription, "tagId": tagId])
                        }
                    }
                    Log.info("Tags deleted from Firebase", category: .firebase, metadata: ["count": tagIdsToDelete.count])
                }
            }

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            toastManager.success(title: "Tag deleted")
        } catch {
            toastManager.error(
                title: "Failed to delete tag",
                message: error.localizedDescription
            )
        }
    }
}

// MARK: - Tag Editor View

struct TagEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.firebaseSync) private var firebaseSync

    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }
    private var backendConfig: BackendConfig { ServiceContainer.shared.resolve(BackendConfig.self) }

    @State private var tag: Tag?
    @State private var name: String = ""
    @State private var selectedColor: String = Tag.predefinedColors[0]

    private var isEditing: Bool {
        tag != nil
    }

    init(tag: Tag? = nil) {
        self.tag = tag
        if let tag = tag {
            _name = State(initialValue: tag.name)
            _selectedColor = State(initialValue: tag.color)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tag Name") {
                    TextField("Enter tag name", text: $name)
                        .font(HeirloomFonts.body)
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

                if isEditing, let tag = tag {
                    Section {
                        HStack {
                            Text("Used in")
                                .font(HeirloomFonts.body)
                                .foregroundStyle(HeirloomColors.secondaryText)

                            Spacer()

                            Text("\(tag.recipeCount) recipe\(tag.recipeCount == 1 ? "" : "s")")
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(HeirloomColors.primaryText)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Tag" : "New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        saveTag()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
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

    private func saveTag() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let tagToSync: Tag
        if let existingTag = tag {
            // Update existing tag
            existingTag.name = trimmedName
            existingTag.color = selectedColor
            tagToSync = existingTag
        } else {
            // Create new tag
            let newTag = Tag(name: trimmedName, color: selectedColor)
            modelContext.insert(newTag)
            tagToSync = newTag
        }

        do {
            try modelContext.save()

            // Sync to Firebase if active
            if backendConfig.isFirebaseActive {
                Task {
                    do {
                        try await firebaseSync.uploadTag(tagToSync)
                        Log.info("Tag synced to Firebase", category: .firebase, metadata: ["tagId": tagToSync.id])
                    } catch {
                        Log.warning("Failed to sync tag to Firebase", category: .firebase, metadata: ["error": error.localizedDescription, "tagId": tagToSync.id])
                    }
                }
            }

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            toastManager.success(
                title: isEditing ? "Tag updated" : "Tag created"
            )

            dismiss()
        } catch {
            toastManager.error(
                title: "Failed to save tag",
                message: error.localizedDescription
            )
        }
    }
}

// MARK: - Preview

#Preview {
    TagManagementView()
        .modelContainer(for: Tag.self, inMemory: true)
        .toastContainer()
}

#Preview("Editor") {
    TagEditorView()
        .modelContainer(for: Tag.self, inMemory: true)
        .toastContainer()
}
