import SwiftUI
import PhotosUI

struct CollectionSettingsView: View {
    @Bindable var collection: RecipeCollection
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var imageStorageService: ImageStorageService { ServiceContainer.shared.resolve(ImageStorageService.self) }
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isProcessingImage = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Collection Name") {
                    TextField("Name", text: $collection.name)
                }

                Section("Description") {
                    TextField("Description", text: Binding(
                        get: { collection.desc ?? "" },
                        set: { collection.desc = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                }

                Section("Icon & Color") {
                    HStack {
                        Text("Icon")
                        Spacer()
                        Image(systemName: collection.iconName)
                            .foregroundStyle(collection.swiftUIColor)
                    }
                    // TODO: Add icon picker in future
                }

                Section("Background") {
                    Toggle("Use Custom Background", isOn: $collection.useCustomBackground)
                        .onChange(of: collection.useCustomBackground) { _, newValue in
                            if !newValue {
                                // Clear custom backgrounds when toggled off
                                collection.customBackgroundImagePath = nil
                            }
                            try? modelContext.save()
                        }

                    if collection.useCustomBackground {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack {
                                Image(systemName: "photo")
                                Text("Choose Photo")
                                Spacer()
                                if isProcessingImage {
                                    ProgressView()
                                }
                            }
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                await loadPhoto(from: newItem)
                            }
                        }

                        // Preview current background
                        if let bgPath = collection.customBackgroundImagePath {
                            AsyncRecipeImage(
                                imageFileName: bgPath,
                                firebaseImageURL: nil,
                                placeholder: "photo"
                            )
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Button("Remove Background", role: .destructive) {
                                collection.customBackgroundImagePath = nil
                                collection.useCustomBackground = false
                                try? modelContext.save()
                            }
                        }
                    }
                }

                Section {
                    Button("Done") {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Collection Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item = item else { return }

        isProcessingImage = true
        defer { isProcessingImage = false }

        do {
            // Load the image data
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                toastManager.error(title: "Failed to load image")
                return
            }

            // Save to local storage with collection-specific naming
            let fileName = "collection-bg-\(collection.id.uuidString).jpg"
            let savedPath = try await imageStorageService.saveImage(uiImage, fileName: fileName)

            await MainActor.run {
                collection.customBackgroundImagePath = savedPath
                try? modelContext.save()
                toastManager.success(title: "Background Updated")
            }
        } catch {
            await MainActor.run {
                toastManager.error(title: "Failed to save background", message: error.localizedDescription)
            }
        }
    }
}
