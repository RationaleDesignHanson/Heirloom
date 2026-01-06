//
//  FlipAffordanceBadge.swift
//  Heirloom
//
//  Created by Claude on 1/5/26.
//

import SwiftUI

/// A badge that hints users can flip the card to see the back
/// Shows with pulse animation on first view, then remains subtle
struct FlipAffordanceBadge: View {
    // MARK: - Properties
    let position: BadgePosition
    let isFirstTime: Bool

    // MARK: - State
    @State private var isPulsing = false

    // MARK: - Initialization
    init(position: BadgePosition = .bottomRight, isFirstTime: Bool = false) {
        self.position = position
        self.isFirstTime = isFirstTime
    }

    // MARK: - Body
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption2)
                .fontWeight(.semibold)

            Text("Tap to flip")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.accentColor)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
        .scaleEffect(isPulsing ? 1.1 : 1.0)
        .opacity(isPulsing ? 1.0 : 0.9)
        .animation(
            isFirstTime ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default,
            value: isPulsing
        )
        .accessibilityLabel("Tap to flip card")
        .accessibilityHint("Double tap to see the other side of this recipe card")
        .onAppear {
            if isFirstTime {
                isPulsing = true
            }
        }
    }

    // MARK: - Badge Position
    enum BadgePosition {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight

        var alignment: Alignment {
            switch self {
            case .topLeft: return .topLeading
            case .topRight: return .topTrailing
            case .bottomLeft: return .bottomLeading
            case .bottomRight: return .bottomTrailing
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .topLeft:
                return EdgeInsets(top: 12, leading: 12, bottom: 0, trailing: 0)
            case .topRight:
                return EdgeInsets(top: 12, leading: 0, bottom: 0, trailing: 12)
            case .bottomLeft:
                return EdgeInsets(top: 0, leading: 12, bottom: 12, trailing: 0)
            case .bottomRight:
                return EdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 12)
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Add a flip affordance badge to any view
    func flipAffordance(
        position: FlipAffordanceBadge.BadgePosition = .bottomRight,
        isFirstTime: Bool = false
    ) -> some View {
        self.overlay(alignment: position.alignment) {
            FlipAffordanceBadge(position: position, isFirstTime: isFirstTime)
                .padding(position.padding)
        }
    }
}

// MARK: - First Time Experience

/// UserDefaults key for tracking if user has seen flip affordance
private let hasSeenFlipAffordanceKey = "HasSeenFlipAffordance"

extension FlipAffordanceBadge {
    /// Check if this is the user's first time seeing the flip affordance
    static var isFirstTimeExperience: Bool {
        !UserDefaults.standard.bool(forKey: hasSeenFlipAffordanceKey)
    }

    /// Mark that the user has seen the flip affordance
    static func markAsSeen() {
        UserDefaults.standard.set(true, forKey: hasSeenFlipAffordanceKey)
    }

    /// Reset the first-time experience (for testing)
    static func resetFirstTimeExperience() {
        UserDefaults.standard.removeObject(forKey: hasSeenFlipAffordanceKey)
    }
}

// MARK: - Preview

#Preview("Default Badge") {
    ZStack {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 350, height: 300)

        FlipAffordanceBadge(position: .bottomRight, isFirstTime: false)
            .padding()
    }
    .padding()
}

#Preview("First Time (Pulsing)") {
    ZStack {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [.green, .teal],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 350, height: 300)

        FlipAffordanceBadge(position: .bottomRight, isFirstTime: true)
            .padding()
    }
    .padding()
}

#Preview("All Positions") {
    VStack(spacing: 20) {
        ForEach([
            FlipAffordanceBadge.BadgePosition.topLeft,
            .topRight,
            .bottomLeft,
            .bottomRight
        ], id: \.self) { position in
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange)
                    .frame(width: 250, height: 150)

                FlipAffordanceBadge(position: position)
                    .padding()
            }
        }
    }
    .padding()
}

#Preview("Using View Extension") {
    RoundedRectangle(cornerRadius: 12)
        .fill(
            LinearGradient(
                colors: [.pink, .red],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .frame(width: 350, height: 300)
        .flipAffordance(position: .bottomRight, isFirstTime: true)
        .padding()
}

// Make BadgePosition hashable for ForEach
extension FlipAffordanceBadge.BadgePosition: Hashable {}
