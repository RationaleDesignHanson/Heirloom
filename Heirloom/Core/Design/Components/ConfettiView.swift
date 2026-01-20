import SwiftUI

// MARK: - Confetti View
/// Celebration animation with falling confetti particles
/// Used for milestone achievements like adding first recipe, completing collections
struct ConfettiView: View {
    let particleCount: Int
    let duration: Double

    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }

    @State private var isAnimating = false

    init(particleCount: Int = 50, duration: Double = 3.0) {
        self.particleCount = particleCount
        self.duration = duration
    }

    var body: some View {
        ZStack {
            ForEach(0..<particleCount, id: \.self) { index in
                ConfettiParticle(
                    color: confettiColors.randomElement() ?? .red,
                    startX: CGFloat.random(in: 0...1),
                    delay: Double.random(in: 0...0.5),
                    duration: duration
                )
                .opacity(isAnimating ? 0 : 1)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            isAnimating = true
        }
    }

    private var confettiColors: [Color] {
        [
            HeirloomColors.tomato,
            HeirloomColors.familyGreen,
            HeirloomColors.amber,
            .blue,
            .purple,
            .pink,
            .orange
        ]
    }
}

// MARK: - Confetti Particle
private struct ConfettiParticle: View {
    let color: Color
    let startX: CGFloat
    let delay: Double
    let duration: Double

    @State private var yOffset: CGFloat = -50
    @State private var xOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(x: xOffset, y: yOffset)
            .position(x: UIScreen.main.bounds.width * startX, y: 0)
            .onAppear {
                withAnimation(
                    .easeIn(duration: duration)
                    .delay(delay)
                ) {
                    yOffset = UIScreen.main.bounds.height + 50
                    xOffset = CGFloat.random(in: -100...100)
                    rotation = Double.random(in: 0...720)
                    scale = 0
                }
            }
    }
}

// MARK: - Confetti Modifier
extension View {
    /// Show confetti celebration animation
    /// - Parameters:
    ///   - isActive: Binding to control when confetti is shown
    ///   - particleCount: Number of confetti particles (default: 50)
    ///   - duration: Animation duration in seconds (default: 3.0)
    func confetti(
        isActive: Binding<Bool>,
        particleCount: Int = 50,
        duration: Double = 3.0
    ) -> some View {
        self.overlay {
            if isActive.wrappedValue {
                ConfettiView(particleCount: particleCount, duration: duration)
                    .onAppear {
                        // Auto-dismiss after animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.5) {
                            isActive.wrappedValue = false
                        }
                    }
            }
        }
    }
}

// MARK: - Milestone Celebration View
/// Complete milestone celebration with confetti, message, and haptics
struct MilestoneCelebrationView: View {
    let title: String
    let message: String
    let icon: String
    @Binding var isPresented: Bool

    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissWithAnimation()
                }

            // Celebration card
            VStack(spacing: HeirloomSpacing.lg) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundStyle(HeirloomColors.tomato)
                    .padding()
                    .background(
                        Circle()
                            .fill(HeirloomColors.tomato.opacity(0.1))
                    )

                // Title
                Text(title)
                    .font(HeirloomFonts.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .multilineTextAlignment(.center)

                // Message
                Text(message)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)

                // Dismiss button
                Button {
                    dismissWithAnimation()
                } label: {
                    Text("Awesome!")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(HeirloomColors.tomato)
                        .cornerRadius(12)
                }
            }
            .padding(HeirloomSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            )
            .padding(HeirloomSpacing.xl)
            .scaleEffect(isPresented ? 1 : 0.8)
            .opacity(isPresented ? 1 : 0)

            // Confetti overlay
            ConfettiView(particleCount: 60, duration: 3.0)
        }
        .onAppear {
            // Entrance animation
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                // Animation handled by scaleEffect and opacity above
            }

            // Celebration haptics
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            // Track analytics
            analytics.track(event: .featureUsed, properties: [
                "feature": "milestone_celebration",
                "milestone": title
            ])
        }
    }

    private func dismissWithAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            isPresented = false
        }
    }
}

// MARK: - Milestone Manager
/// Tracks and triggers milestone celebrations
@MainActor
class MilestoneManager: ObservableObject {
    @Published var showCelebration = false
    @Published var currentMilestone: Milestone?

    init() {}

    struct Milestone {
        let title: String
        let message: String
        let icon: String
        let key: String
    }

    // MARK: - Milestones

    func checkFirstRecipeAdded() {
        let key = "milestone_first_recipe"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        celebrate(Milestone(
            title: "Your First Recipe!",
            message: "You've added your first recipe to Heirloom. Start building your collection!",
            icon: "star.fill",
            key: key
        ))
    }

    func checkTenRecipes() {
        let key = "milestone_ten_recipes"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        celebrate(Milestone(
            title: "10 Recipes!",
            message: "Your collection is growing! You've added 10 recipes to Heirloom.",
            icon: "flame.fill",
            key: key
        ))
    }

    func checkFiftyRecipes() {
        let key = "milestone_fifty_recipes"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        celebrate(Milestone(
            title: "50 Recipes!",
            message: "Incredible! You have 50 recipes in your collection.",
            icon: "trophy.fill",
            key: key
        ))
    }

    func checkFirstShoppingList() {
        let key = "milestone_first_shopping_list"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        celebrate(Milestone(
            title: "First Shopping List!",
            message: "You've created your first shopping list. Happy cooking!",
            icon: "cart.fill",
            key: key
        ))
    }

    func checkFirstCardPersonalization() {
        let key = "milestone_first_card_personalization"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        celebrate(Milestone(
            title: "Card Personalized!",
            message: "You've personalized your first recipe card. Make each recipe uniquely yours!",
            icon: "paintbrush.fill",
            key: key
        ))
    }

    // MARK: - Celebration

    private func celebrate(_ milestone: Milestone) {
        // Mark as completed
        UserDefaults.standard.set(true, forKey: milestone.key)

        // Show celebration
        currentMilestone = milestone
        showCelebration = true

        Log.info("Milestone achieved", category: .general, metadata: ["title": milestone.title, "key": milestone.key])
    }
}

// MARK: - Milestone View Modifier
extension View {
    func milestonesCelebration() -> some View {
        self.overlay {
            MilestonesCelebrationWrapper()
        }
    }
}

/// Wrapper view that observes MilestoneManager to provide bindings
private struct MilestonesCelebrationWrapper: View {
    @ObservedObject var manager: MilestoneManager = ServiceContainer.shared.resolve(MilestoneManager.self)

    var body: some View {
        if manager.showCelebration,
           let milestone = manager.currentMilestone {
            MilestoneCelebrationView(
                title: milestone.title,
                message: milestone.message,
                icon: milestone.icon,
                isPresented: $manager.showCelebration
            )
            .transition(.opacity)
        }
    }
}

// MARK: - Preview
#Preview("Confetti") {
    ZStack {
        Color.gray.opacity(0.2)
        ConfettiView()
    }
}

#Preview("Milestone") {
    MilestoneCelebrationView(
        title: "Your First Recipe!",
        message: "You've added your first recipe to Heirloom. Start building your collection!",
        icon: "star.fill",
        isPresented: .constant(true)
    )
}
