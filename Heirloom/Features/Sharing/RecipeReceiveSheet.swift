import SwiftUI
import SwiftData

/// Sheet for previewing and accepting a shared recipe
/// Shows recipe preview with attribution and allows accept/decline
struct RecipeReceiveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.firebaseShare) private var firebaseShare

    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }

    let shareURL: URL
    let shareMetadata: [String: Any]?

    @State private var isAccepting = false
    @State private var isDeclining = false
    @State private var acceptError: Error?
    @State private var previewRecipe: RecipePreview?
    @State private var isLoadingPreview = true

    var body: some View {
        NavigationStack {
            ZStack {
                if isLoadingPreview {
                    loadingView
                } else if let preview = previewRecipe {
                    contentView(preview: preview)
                } else {
                    errorView
                }
            }
            .navigationTitle("Recipe Shared With You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(isAccepting)
                }
            }
            .alert("Accept Error", isPresented: .constant(acceptError != nil)) {
                Button("OK") {
                    acceptError = nil
                }
            } message: {
                if let error = acceptError {
                    Text(error.localizedDescription)
                }
            }
            .task {
                await loadPreview()
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading recipe preview...")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(HeirloomColors.warmGray)

            Text("Could not load recipe preview")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("You can still try to accept the share")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)

            acceptButton
        }
        .padding(HeirloomSpacing.xl)
    }

    // MARK: - Content View

    private func contentView(preview: RecipePreview) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeirloomSpacing.xl) {
                // Share Attribution
                attributionCard(preview: preview)

                // Recipe Preview
                recipePreviewCard(preview: preview)

                // Action Buttons
                VStack(spacing: HeirloomSpacing.md) {
                    acceptButton
                    declineButton
                }
                .padding(.top, HeirloomSpacing.md)
            }
            .padding(HeirloomSpacing.lg)
        }
        .background(HeirloomColors.cream)
    }

    // MARK: - Attribution Card

    private func attributionCard(preview: RecipePreview) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(HeirloomColors.tomato)

                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    if let sharerName = preview.sharerName {
                        Text(sharerName)
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)
                        Text("shared a recipe with you")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    } else {
                        Text("Someone shared a recipe with you")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)
                    }
                }

                Spacer()
            }

            if let message = preview.personalMessage, !message.isEmpty {
                Text(message)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .padding(HeirloomSpacing.md)
                    .background(HeirloomColors.warmGray.opacity(0.1))
                    .cornerRadius(12)
            }

            // Generation badge
            if let generation = preview.generation, generation > 0 {
                HStack(spacing: HeirloomSpacing.xs) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(HeirloomFonts.caption1)
                    Text("Generation \(generation + 1)")
                        .font(HeirloomFonts.caption1)
                }
                .foregroundStyle(HeirloomColors.familyGreen)
                .padding(.horizontal, HeirloomSpacing.sm)
                .padding(.vertical, HeirloomSpacing.xs)
                .background(HeirloomColors.familyGreen.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Recipe Preview Card

    private func recipePreviewCard(preview: RecipePreview) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            // Recipe thumbnail
            if let imageURLString = preview.imageURL, let imageURL = URL(string: imageURLString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(HeirloomColors.warmGray.opacity(0.2))
                            .aspectRatio(4/3, contentMode: .fill)
                            .overlay {
                                ProgressView()
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxHeight: 200)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(HeirloomColors.warmGray.opacity(0.2))
                            .aspectRatio(4/3, contentMode: .fill)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(HeirloomColors.warmGray)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
                .cornerRadius(12)
            }

            Text(preview.title)
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.primaryText)

            // Metadata
            HStack(spacing: HeirloomSpacing.md) {
                if let servings = preview.servings {
                    Label(servings, systemImage: "person.2")
                        .font(HeirloomFonts.caption1)
                }

                if let prepTime = preview.prepTime {
                    Label(prepTime, systemImage: "clock")
                        .font(HeirloomFonts.caption1)
                }

                if let cookTime = preview.cookTime {
                    Label(cookTime, systemImage: "flame")
                        .font(HeirloomFonts.caption1)
                }
            }
            .foregroundStyle(HeirloomColors.secondaryText)

            Divider()

            // Ingredients count
            if preview.ingredientCount > 0 {
                HStack {
                    Image(systemName: "list.bullet")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("\(preview.ingredientCount) ingredients")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)
                }
            }

            // Instructions count
            if preview.instructionCount > 0 {
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("\(preview.instructionCount) steps")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Action Buttons

    private var acceptButton: some View {
        Button {
            acceptShare()
        } label: {
            HStack {
                if isAccepting {
                    ProgressView()
                        .tint(HeirloomColors.buttonTextLight)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Add to My Recipes")
                }
            }
            .font(HeirloomFonts.bodyBold)
            .foregroundStyle(HeirloomColors.buttonTextLight)
            .frame(maxWidth: .infinity)
            .padding()
            .background(HeirloomColors.tomato)
            .cornerRadius(12)
        }
        .disabled(isAccepting || isDeclining)
    }

    private var declineButton: some View {
        Button {
            decline()
        } label: {
            Text("Decline")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .frame(maxWidth: .infinity)
                .padding()
                .background(HeirloomColors.warmGray.opacity(0.2))
                .cornerRadius(12)
        }
        .disabled(isAccepting || isDeclining)
    }

    // MARK: - Actions

    private func loadPreview() async {
        var metadata = shareMetadata

        // If no metadata provided, try to fetch it from Firebase
        if metadata == nil {
            do {
                let shareId = extractShareId(from: shareURL)
                metadata = try await firebaseShare.fetchShareMetadata(shareId: shareId)
                Log.info("Fetched share metadata for preview", category: .firebase, metadata: ["shareId": shareId])
            } catch {
                Log.warning("Failed to fetch share metadata, using generic preview", category: .firebase, metadata: ["error": error.localizedDescription])
                // Continue with nil metadata - will show generic preview
            }
        }

        // Try to load preview from share metadata
        if let metadata = metadata {
            let preview = RecipePreview(
                title: (metadata["recipeTitle"] as? String) ?? "Shared Recipe",
                servings: metadata["servings"] as? String,
                prepTime: metadata["prepTime"] as? String,
                cookTime: metadata["cookTime"] as? String,
                ingredientCount: (metadata["ingredientCount"] as? Int) ?? 0,
                instructionCount: (metadata["instructionCount"] as? Int) ?? 0,
                sharerName: metadata["ownerName"] as? String,
                personalMessage: metadata["personalMessage"] as? String,
                generation: metadata["generation"] as? Int,
                imageURL: metadata["firebaseImageURL"] as? String
            )

            await MainActor.run {
                previewRecipe = preview
                isLoadingPreview = false
            }
        } else {
            // No metadata available - show generic preview
            let genericPreview = RecipePreview(
                title: "Shared Recipe",
                servings: nil,
                prepTime: nil,
                cookTime: nil,
                ingredientCount: 0,
                instructionCount: 0,
                sharerName: "Someone",
                personalMessage: nil,
                generation: nil,
                imageURL: nil
            )

            await MainActor.run {
                previewRecipe = genericPreview
                isLoadingPreview = false
            }
        }
    }

    private func acceptShare() {
        isAccepting = true

        Task {
            do {
                // Extract shareId from URL (format: heirloom://share/{shareId})
                let shareId = extractShareId(from: shareURL)

                // Accept the share via FirebaseShareService
                let recipe = try await firebaseShare.acceptShare(
                    shareId: shareId,
                    context: modelContext
                )

                await MainActor.run {
                    isAccepting = false

                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)

                    toastManager.success(
                        title: "Recipe Added",
                        message: "'\(recipe.title)' added to your collection"
                    )

                    // Clear pending share
                    let deepLinkHandler = ServiceContainer.shared.resolve(DeepLinkHandler.self)
                    deepLinkHandler.clearPendingShare()

                    // Dismiss
                    dismiss()
                }

            } catch {
                await MainActor.run {
                    acceptError = error
                    isAccepting = false

                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)

                    Log.error("Failed to accept shared recipe", category: .firebase, metadata: ["error": error.localizedDescription])
                }
            }
        }
    }

    private func extractShareId(from url: URL) -> String {
        // Extract shareId from heirloom://share/{shareId}
        if url.scheme == "heirloom", url.host == "share" {
            return url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        // Or from https://heirloom.app/share/{shareId}
        else if url.host == "heirloom.app" {
            let pathComponents = url.pathComponents
            if pathComponents.count >= 3, pathComponents[1] == "share" {
                return pathComponents[2]
            }
        }
        return url.lastPathComponent
    }

    private func decline() {
        isDeclining = true

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Clear pending share
        let deepLinkHandler = ServiceContainer.shared.resolve(DeepLinkHandler.self)
        deepLinkHandler.clearPendingShare()

        // Dismiss
        dismiss()
    }
}

// MARK: - Recipe Preview Model

struct RecipePreview {
    let title: String
    let servings: String?
    let prepTime: String?
    let cookTime: String?
    let ingredientCount: Int
    let instructionCount: Int
    let sharerName: String?
    let personalMessage: String?
    let generation: Int?
    let imageURL: String? // Firebase image URL for thumbnail
}

// MARK: - Preview

#Preview {
    RecipeReceiveSheet(
        shareURL: URL(string: "https://www.icloud.com/share/test")!,
        shareMetadata: nil
    )
    .modelContainer(for: Recipe.self, inMemory: true)
}
