import SwiftUI
import PhotosUI
import UIKit

struct CollectionSettingsView: View {
    @Bindable var collection: RecipeCollection
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var imageStorageService: ImageStorageService { ServiceContainer.shared.resolve(ImageStorageService.self) }
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }
    private var collectionImageGenerator: CollectionImageGenerator { ServiceContainer.shared.resolve(CollectionImageGenerator.self) }

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isProcessingImage = false
    @State private var isGeneratingImage = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Collection Name") {
                    TextField("Name", text: $collection.name)
                        .disabled(!collection.isNameEditable)
                        .foregroundStyle(collection.isNameEditable ? .primary : .secondary)

                    if !collection.isNameEditable {
                        Text("System collection names cannot be changed")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
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

                        Button {
                            Task {
                                await generateBackground()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Generate with AI")
                                Spacer()
                                if isGeneratingImage {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isGeneratingImage)

                        if isGeneratingImage {
                            Text("Generating themed background...")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        }

                        // Preview current background
                        if let bgPath = collection.customBackgroundImagePath ?? collection.generatedBackgroundImagePath {
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

    private func generateBackground() async {
        isGeneratingImage = true
        defer { isGeneratingImage = false }

        do {
            // Generate AI image
            let imagePath = try await collectionImageGenerator.generateBackground(for: collection)

            await MainActor.run {
                // Update collection with generated image
                collection.generatedBackgroundImagePath = imagePath
                collection.lastImageGenerationDate = Date()
                collection.lastRecipeCountAtGeneration = collection.recipes?.count ?? 0
                collection.useCustomBackground = true
                try? modelContext.save()
                toastManager.success(title: "Background Generated", message: "AI created a custom image for your collection")
            }
        } catch {
            await MainActor.run {
                toastManager.error(title: "Generation Failed", message: error.localizedDescription)
            }
        }
    }
}
