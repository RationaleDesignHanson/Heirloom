import SwiftUI

// MARK: - Skeleton Loading View
struct SkeletonView: View {
    @State private var isAnimating = false

    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 8) {
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        HeirloomColors.warmGray.opacity(0.3),
                        HeirloomColors.warmGray.opacity(0.1),
                        HeirloomColors.warmGray.opacity(0.3)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .opacity(isAnimating ? 0.5 : 1.0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Recipe Card Skeleton
struct RecipeCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Image skeleton
            SkeletonView(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .aspectRatio(4/3, contentMode: .fill)

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                // Title skeleton
                SkeletonView(cornerRadius: 4)
                    .frame(height: 20)
                    .frame(maxWidth: .infinity)

                // Subtitle skeleton
                SkeletonView(cornerRadius: 4)
                    .frame(height: 14)
                    .frame(width: 120)
            }
            .padding(.horizontal, HeirloomSpacing.sm)
            .padding(.bottom, HeirloomSpacing.sm)
        }
        .background(HeirloomColors.cream)
        .cornerRadius(HeirloomSpacing.cardCornerRadius)
    }
}

// MARK: - Loading Spinner with Message
struct LoadingSpinner: View {
    let message: String?

    init(message: String? = nil) {
        self.message = message
    }

    var body: some View {
        VStack(spacing: HeirloomSpacing.md) {
            ProgressView()
                .tint(HeirloomColors.tomato)
                .scaleEffect(1.5)

            if let message = message {
                Text(message)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(HeirloomSpacing.xl)
    }
}

// MARK: - Full Screen Loading
struct FullScreenLoading: View {
    let message: String

    init(message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: HeirloomSpacing.lg) {
                ProgressView()
                    .tint(HeirloomColors.tomato)
                    .scaleEffect(2)

                Text(message)
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.buttonTextLight)
            }
            .padding(HeirloomSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(HeirloomColors.charcoal)
            )
        }
    }
}

// MARK: - Shimmer Effect Modifier
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0),
                                .white.opacity(0.3),
                                .white.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: phase)
                    .onAppear {
                        withAnimation(
                            .linear(duration: 1.5)
                            .repeatForever(autoreverses: false)
                        ) {
                            phase = 400
                        }
                    }
            )
            .clipped()
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - Async Image with Loading
struct AsyncRecipeImage: View {
    let imageFileName: String?
    let firebaseImageURL: String?  // NEW: Firebase Storage URL
    let placeholder: String
    let isGenerating: Bool

    init(imageFileName: String?, firebaseImageURL: String? = nil, placeholder: String = "photo", isGenerating: Bool = false) {
        self.imageFileName = imageFileName
        self.firebaseImageURL = firebaseImageURL
        self.placeholder = placeholder
        self.isGenerating = isGenerating
    }

    // Using concrete type for image storage
    private var imageStorageService: ImageStorageService { ServiceContainer.shared.resolve(ImageStorageService.self) }
    private var networkMonitor: NetworkMonitor { ServiceContainer.shared.resolve(NetworkMonitor.self) }

    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    @State private var hasAttemptedLoad = false
    @State private var failedDueToNetwork = false  // Track if failure was network-related

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else if isLoading {
                    SkeletonView(cornerRadius: 0)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else if isGenerating {
                    // Image being generated in background
                    Rectangle()
                        .fill(HeirloomColors.warmGray.opacity(0.15))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .overlay {
                            VStack(spacing: 8) {
                                ProgressView()
                                    .tint(HeirloomColors.warmGray)
                                Text("Generating image...")
                                    .font(.caption2)
                                    .foregroundStyle(HeirloomColors.warmGray)
                            }
                        }
                } else if failedDueToNetwork && !networkMonitor.isConnected {
                    // Offline placeholder with message
                    Rectangle()
                        .fill(HeirloomColors.warmGray.opacity(0.15))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .overlay {
                            VStack(spacing: 6) {
                                Image(systemName: "wifi.slash")
                                    .font(.system(size: 28))
                                    .foregroundStyle(HeirloomColors.warmGray)
                                Text("Images unavailable offline")
                                    .font(.caption2)
                                    .foregroundStyle(HeirloomColors.warmGray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 8)
                        }
                } else {
                    // Fallback placeholder
                    Rectangle()
                        .fill(HeirloomColors.warmGray.opacity(0.2))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .overlay {
                            Image(systemName: placeholder)
                                .font(.system(size: 40))
                                .foregroundStyle(HeirloomColors.warmGray)
                        }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .onAppear {
            if !hasAttemptedLoad {
                hasAttemptedLoad = true
                Task {
                    await loadImage()
                }
            }
        }
        .onChange(of: imageFileName) { oldValue, newValue in
            // Reload image whenever imageFileName changes (not just nil→value)
            if oldValue != newValue {
                Log.debug("Image filename changed, reloading", category: .storage, metadata: [
                    "old": oldValue ?? "nil",
                    "new": newValue ?? "nil"
                ])

                // Reset state for new image
                loadedImage = nil
                isLoading = true

                Task {
                    await loadImage()
                }
            }
        }
        .onChange(of: firebaseImageURL) { oldValue, newValue in
            // Reload image whenever Firebase URL changes
            if oldValue != newValue {
                Log.debug("Firebase image URL changed, reloading", category: .storage, metadata: [
                    "old": oldValue ?? "nil",
                    "new": newValue ?? "nil"
                ])

                // Reset state for new image
                loadedImage = nil
                isLoading = true

                Task {
                    await loadImage()
                }
            }
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            // Retry loading when network comes back online
            if isConnected {
                retryLoadIfNeeded()
            }
        }
        .transaction { transaction in
            transaction.animation = nil  // Disable all animations
        }
    }

    private func loadImage() async {
        // Priority 0: Check for bundled preset images (prefix "preset-")
        if let fileName = imageFileName, fileName.hasPrefix("preset-") {
            let assetName = String(fileName.dropFirst(7)) // Remove "preset-" prefix
            Log.debug("AsyncRecipeImage: Loading bundled preset image", category: .storage, metadata: ["assetName": assetName])

            if let image = UIImage(named: assetName) {
                Log.debug("AsyncRecipeImage: Successfully loaded bundled preset", category: .storage, metadata: ["assetName": assetName])
                await MainActor.run {
                    loadedImage = image
                    isLoading = false
                }
                return
            } else {
                Log.debug("AsyncRecipeImage: Bundled preset not found", category: .storage, metadata: ["assetName": assetName])
            }
        }

        // Priority 1: Try loading from local file storage
        if let fileName = imageFileName {
            Log.debug("AsyncRecipeImage: Loading from local file", category: .storage, metadata: ["fileName": fileName])

            if let image = await imageStorageService.loadImage(fileName: fileName) {
                Log.debug("AsyncRecipeImage: Successfully loaded from local", category: .storage, metadata: ["fileName": fileName])
                await MainActor.run {
                    loadedImage = image
                    isLoading = false
                }
                return
            } else {
                Log.debug("AsyncRecipeImage: Local file not found, trying Firebase URL", category: .storage)
            }
        }

        // Priority 2: Try loading from Firebase URL
        if let urlString = firebaseImageURL,
           let url = URL(string: urlString) {
            Log.debug("AsyncRecipeImage: Loading from Firebase URL", category: .storage, metadata: ["url": urlString])

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    Log.debug("AsyncRecipeImage: Successfully loaded from Firebase", category: .storage)
                    await MainActor.run {
                        loadedImage = image
                        isLoading = false
                    }
                    return
                }
            } catch {
                Log.warning("AsyncRecipeImage: Failed to load from Firebase URL", category: .storage, metadata: [
                    "error": error.localizedDescription
                ])
                // Track if failure was due to network (for offline message)
                if !networkMonitor.isConnected {
                    await MainActor.run {
                        failedDueToNetwork = true
                    }
                }
            }
        }

        // Priority 3: Show placeholder (no image found)
        Log.debug("AsyncRecipeImage: No image source available, showing placeholder", category: .storage)
        await MainActor.run {
            isLoading = false
        }
    }

    /// Retry loading when network comes back online
    private func retryLoadIfNeeded() {
        guard failedDueToNetwork && networkMonitor.isConnected else { return }
        Log.debug("AsyncRecipeImage: Network restored, retrying image load", category: .storage)
        failedDueToNetwork = false
        isLoading = true
        Task {
            await loadImage()
        }
    }
}

// MARK: - Preview
#Preview("Skeleton Views") {
    ScrollView(.vertical) {
        VStack(spacing: HeirloomSpacing.lg) {
            Text("Recipe Card Skeleton")
                .font(HeirloomFonts.title2)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: HeirloomSpacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    RecipeCardSkeleton()
                }
            }

            Divider()
                .padding(.vertical)

            LoadingSpinner(message: "Loading recipes...")

            Divider()
                .padding(.vertical)

            Text("Skeleton Elements")
                .font(HeirloomFonts.title2)

            VStack(spacing: HeirloomSpacing.md) {
                SkeletonView()
                    .frame(height: 100)

                SkeletonView()
                    .frame(height: 20)
                    .frame(maxWidth: 200)
            }
        }
        .padding()
    }
    .background(HeirloomColors.cardBackground)
}

#Preview("Full Screen Loading") {
    FullScreenLoading(message: "Importing recipe...")
}
