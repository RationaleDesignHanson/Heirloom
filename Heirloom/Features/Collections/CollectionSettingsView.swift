import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct CollectionSettingsView: View {
    @Bindable var collection: RecipeCollection
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.firebaseAuth) private var firebaseAuth

    private var imageStorageService: ImageStorageService { ServiceContainer.shared.resolve(ImageStorageService.self) }
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }
    private var collectionImageGenerator: CollectionImageGenerator { ServiceContainer.shared.resolve(CollectionImageGenerator.self) }

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isProcessingImage = false
    @State private var isGeneratingImage = false
    @State private var showNeedCreditsSheet = false
    @State private var showCreditsStore = false
    @State private var showPaywall = false

    // Query for user credits
    @Query private var allUserCredits: [UserCredits]

    /// Cost for generating one AI background image
    private let aiBackgroundCost = 1

    /// Current user's credits
    private var userCredits: UserCredits? {
        guard let userId = firebaseAuth.currentUserId else { return nil }
        return allUserCredits.first { $0.userId == userId }
    }

    /// Whether user can afford AI background generation
    private var canAffordAIGeneration: Bool {
        guard let credits = userCredits else { return false }
        return credits.availableCredits >= aiBackgroundCost
    }

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
                            if canAffordAIGeneration {
                                Task {
                                    await generateBackground()
                                }
                            } else {
                                showNeedCreditsSheet = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(isGeneratingImage ? .secondary : HeirloomColors.tomato)
                                Text("Generate with AI")
                                    .foregroundStyle(isGeneratingImage ? .secondary : .primary)
                                Spacer()
                                Text("\(aiBackgroundCost) credit")
                                    .font(HeirloomFonts.caption1)
                                    .foregroundStyle(.secondary)
                                if isGeneratingImage {
                                    ProgressView()
                                        .tint(HeirloomColors.tomato)
                                }
                            }
                        }
                        .disabled(isGeneratingImage)

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
            .sheet(isPresented: $showNeedCreditsSheet) {
                needCreditsSheetContent
            }
            .sheet(isPresented: $showCreditsStore, onDismiss: {
                // User might have purchased credits - UI will auto-update via @Query
            }) {
                creditsStoreContent
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private var needCreditsSheetContent: some View {
        NeedCreditsSheet(
            creditsNeeded: aiBackgroundCost,
            currentCredits: userCredits?.availableCredits ?? 0,
            featureName: "AI Background Generation",
            onBuyCredits: {
                showNeedCreditsSheet = false
                showCreditsStore = true
            },
            onCancel: {
                showNeedCreditsSheet = false
            },
            onViewSubscription: {
                showNeedCreditsSheet = false
                showPaywall = true
            }
        )
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var creditsStoreContent: some View {
        if let userId = firebaseAuth.currentUserId {
            let storeManager = CreditStoreManager(
                logger: ServiceContainer.shared.resolve(LoggingService.self),
                analytics: ServiceContainer.shared.resolve(AnalyticsService.self),
                modelContext: modelContext,
                userId: userId
            )
            CreditsStoreView(storeManager: storeManager, userCredits: userCredits)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Unable to load credits store")
                    .font(.headline)
                Text("Please sign in to purchase credits")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    // MARK: - Photo Handling

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

                // Deduct credits for successful generation
                if let credits = userCredits {
                    do {
                        try credits.deductCredits(aiBackgroundCost)

                        // Track credit analytics
                        let analytics = ServiceContainer.shared.resolve(AnalyticsService.self)
                        let subscriptionManager = ServiceContainer.shared.resolve(SubscriptionManager.self)
                        CreditAnalytics.trackDeduction(
                            analytics: analytics,
                            userCredits: credits,
                            operationType: .aiBackground,
                            amount: aiBackgroundCost,
                            subscriptionManager: subscriptionManager
                        )

                        DeviceLogger.shared.log("💳 [Credits] Deducted \(aiBackgroundCost) credit for AI background generation", level: .info)
                    } catch {
                        DeviceLogger.shared.log("💳 [Credits] Failed to deduct credits: \(error.localizedDescription)", level: .error)
                    }
                }

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
