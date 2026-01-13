import SwiftUI

/// Holographic shimmer effect for premium button attention
/// Uses amber and gold brand colors for warm, sophisticated appeal
struct HolographicShimmerEffect: ViewModifier {
    /// Whether the shimmer animation is currently active
    let isActive: Bool

    /// Timer for periodic shimmer triggering
    let shimmerInterval: TimeInterval

    @State private var phase: CGFloat = 0
    @State private var isShimmering = false
    @State private var shimmerOpacity: CGFloat = 0
    @State private var shimmerTimer: Timer?

    init(isActive: Bool = true, shimmerInterval: TimeInterval = 12.0) {
        self.isActive = isActive
        self.shimmerInterval = shimmerInterval
    }

    func body(content: Content) -> some View {
        content
            .background(
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                Color.clear,
                                HeirloomColors.amber.opacity(0.6),
                                HeirloomColors.warning.opacity(0.8),
                                Color.white.opacity(0.6),
                                HeirloomColors.warning.opacity(0.8),
                                HeirloomColors.amber.opacity(0.6),
                                Color.clear
                            ],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        lineWidth: 2
                    )
                    .rotationEffect(.degrees(phase))
                    .opacity(shimmerOpacity)
                    .padding(-8)
            )
            .onAppear {
                startShimmerCycle()
            }
            .onDisappear {
                stopShimmerCycle()
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    startShimmerCycle()
                } else {
                    stopShimmerCycle()
                }
            }
    }

    private func startShimmerCycle() {
        guard isActive else { return }

        // Trigger immediate shimmer on appear
        triggerShimmer()

        // Set up periodic timer
        shimmerTimer = Timer.scheduledTimer(withTimeInterval: shimmerInterval, repeats: true) { _ in
            triggerShimmer()
        }
    }

    private func stopShimmerCycle() {
        shimmerTimer?.invalidate()
        shimmerTimer = nil
        isShimmering = false
        shimmerOpacity = 0
        phase = 0
    }

    private func triggerShimmer() {
        guard isActive else { return }

        // Reset rotation
        phase = 0
        isShimmering = true

        // Fade in the ring
        withAnimation(.easeIn(duration: 0.3)) {
            shimmerOpacity = 1.0
        }

        // Animate shimmer sweep around button (360 degree rotation)
        withAnimation(.linear(duration: 1.5)) {
            phase = 360
        }

        // Fade out the ring after sweep completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.4)) {
                shimmerOpacity = 0
            }
        }

        // Turn off shimmer state after everything completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            isShimmering = false
        }
    }
}

extension View {
    /// Apply holographic shimmer effect to a view
    /// - Parameters:
    ///   - isActive: Whether shimmer is currently enabled (pauses when false)
    ///   - shimmerInterval: Seconds between shimmer animations (default 12.0)
    func holographicShimmer(isActive: Bool = true, shimmerInterval: TimeInterval = 12.0) -> some View {
        modifier(HolographicShimmerEffect(isActive: isActive, shimmerInterval: shimmerInterval))
    }
}
