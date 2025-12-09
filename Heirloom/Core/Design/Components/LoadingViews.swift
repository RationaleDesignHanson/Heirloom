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
            SkeletonView(cornerRadius: 12)
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
                    .foregroundStyle(.white)
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
    let placeholder: String

    init(imageFileName: String?, placeholder: String = "photo") {
        self.imageFileName = imageFileName
        self.placeholder = placeholder
    }

    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    @State private var hasAttemptedLoad = false

    var body: some View {
        // Fixed container that never changes size
        Color.clear
            .overlay(
                ZStack {
                    if let image = loadedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if isLoading {
                        SkeletonView(cornerRadius: 0)
                    } else {
                        // Fallback placeholder
                        Rectangle()
                            .fill(HeirloomColors.warmGray.opacity(0.2))
                            .overlay {
                                Image(systemName: placeholder)
                                    .font(.system(size: 40))
                                    .foregroundStyle(HeirloomColors.warmGray)
                            }
                    }
                }
            )
            .clipped()
            .onAppear {
                if !hasAttemptedLoad {
                    hasAttemptedLoad = true
                    Task {
                        await loadImage()
                    }
                }
            }
            .transaction { transaction in
                transaction.animation = nil  // Disable all animations
            }
    }

    private func loadImage() async {
        guard let fileName = imageFileName else {
            await MainActor.run {
                isLoading = false
            }
            return
        }

        if let image = await ImageStorageService.shared.loadImage(fileName: fileName) {
            await MainActor.run {
                loadedImage = image
                isLoading = false
            }
        } else {
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Preview
#Preview("Skeleton Views") {
    ScrollView {
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
    .background(Color.white)
}

#Preview("Full Screen Loading") {
    FullScreenLoading(message: "Importing recipe...")
}
