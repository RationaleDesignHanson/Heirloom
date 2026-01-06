import SwiftUI

/// Async image view with blurhash placeholder
/// Shows beautiful progressive loading using native blurhash encoding/decoding
/// No external dependencies - fully self-contained implementation
struct AsyncBlurhashImage: View {
    let fileName: String?
    let blurhash: String?
    let variant: ImageStorageService.ImageVariant
    let contentMode: ContentMode

    @State private var loadedImage: UIImage?
    @State private var isLoading = true

    init(
        fileName: String?,
        blurhash: String?,
        variant: ImageStorageService.ImageVariant = .card,
        contentMode: ContentMode = .fill
    ) {
        self.fileName = fileName
        self.blurhash = blurhash
        self.variant = variant
        self.contentMode = contentMode
    }

    var body: some View {
        ZStack {
            // Blurhash placeholder (shows immediately)
            if let blurhash = blurhash,
               let blurhashImage = BlurHashEncoder.decode(blurhash, size: CGSize(width: 32, height: 32)) {
                Image(uiImage: blurhashImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(isLoading ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.3), value: isLoading)
            } else {
                // Fallback elegant gradient if no blurhash
                LinearGradient(
                    colors: [Color(hex: "#F0EDE6"), Color(hex: "#E8E4DC")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(isLoading ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.3), value: isLoading)
            }

            // Actual loaded image
            if let loadedImage = loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .opacity(isLoading ? 0.0 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: isLoading)
            }

            // Loading indicator
            if isLoading && loadedImage == nil && blurhash == nil {
                ProgressView()
                    .tint(HeirloomColors.charcoal.opacity(0.4))
            }
        }
        .task {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        guard let fileName = fileName else {
            isLoading = false
            return
        }

        // Get image from storage
        let imageService = ServiceContainer.shared.resolve(ImageStorageServiceProtocol.self)
        if let image = await imageService.loadImageVariant(fileName: fileName, variant: variant) {
            loadedImage = image
            isLoading = false
        } else {
            isLoading = false
        }
    }
}

// MARK: - Convenience Initializers

extension AsyncBlurhashImage {
    /// Create from Recipe model
    init(recipe: Recipe, variant: ImageStorageService.ImageVariant = .card, contentMode: ContentMode = .fill) {
        self.init(
            fileName: recipe.imageFileName,
            blurhash: recipe.blurhash,
            variant: variant,
            contentMode: contentMode
        )
    }
}

// MARK: - Preview

#Preview("With Blurhash") {
    AsyncBlurhashImage(
        fileName: nil,
        blurhash: "LGF5]+Yk^6#M@-5c,1J5@[or[Q6.",
        variant: .card
    )
    .frame(width: 200, height: 150)
    .cornerRadius(12)
}

#Preview("Without Blurhash") {
    AsyncBlurhashImage(
        fileName: nil,
        blurhash: nil,
        variant: .card
    )
    .frame(width: 200, height: 150)
    .cornerRadius(12)
}
