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

                Section("Screen Recording") {
                    Toggle("Demo Seed Collection", isOn: $collection.isDemoSeed)
                        .onChange(of: collection.isDemoSeed) { _, _ in
                            try? modelContext.save()
                        }

                    Text("Mark this collection as a 'demo seed' to hide it when the \"Hide Demo Collections\" toggle is enabled in Settings. Use this for collections created specifically for screen recordings or demos.")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Section("Collection Card Image") {
                    Toggle("Use Custom Image", isOn: $collection.useCustomBackground)
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
                                    .foregroundStyle(isGeneratingImage ? .secondary : HeirloomColors.tomato)
                                Text("Generate with AI")
                                    .foregroundStyle(isGeneratingImage ? .secondary : .primary)
                                Spacer()
                                if isGeneratingImage {
                                    ProgressView()
                                        .tint(HeirloomColors.tomato)
                                }
                            }
                        }
                        .disabled(isGeneratingImage)
                        .opacity(isGeneratingImage ? 0.6 : 1.0)

                        if isGeneratingImage {
                            Text("Generating themed image...")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        }

                        // Preview current image
                        if let bgPath = collection.customBackgroundImagePath ?? collection.generatedBackgroundImagePath {
                            AsyncRecipeImage(
                                imageFileName: bgPath,
                                firebaseImageURL: nil,
                                placeholder: "photo"
                            )
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Button("Remove Custom Image", role: .destructive) {
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
                collection.useCustomBackground = true
                try? modelContext.save()
                toastManager.success(title: "Collection Image Updated")
            }
        } catch {
            await MainActor.run {
                toastManager.error(title: "Failed to save background", message: error.localizedDescription)
            }
        }
    }

    private func generateBackground() async {
        // Show starting toast
        await MainActor.run {
            toastManager.info(title: "Generating Image", message: "Creating a custom AI image for your collection...")
        }

        isGeneratingImage = true
        defer { isGeneratingImage = false }

        do {
            // Generate AI image (this can take 10-30 seconds)
            let imagePath = try await collectionImageGenerator.generateBackground(for: collection)

            await MainActor.run {
                // Update collection with generated image
                collection.generatedBackgroundImagePath = imagePath
                collection.lastImageGenerationDate = Date()
                collection.lastRecipeCountAtGeneration = collection.recipes?.count ?? 0
                collection.useCustomBackground = true
                try? modelContext.save()

                // Show success toast
                toastManager.success(title: "Image Generated", message: "AI created a beautiful image for your collection")
            }
        } catch {
            await MainActor.run {
                toastManager.error(title: "Generation Failed", message: error.localizedDescription)
            }
        }
    }
}
