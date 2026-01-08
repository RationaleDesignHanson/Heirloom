//
//  CoachMarkView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-08.
//

import SwiftUI

/// Reusable coach mark component for user education
struct CoachMarkView: View {
    let message: String
    let onDismiss: () -> Void
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Coach mark card
            VStack(spacing: 20) {
                // Message
                Text(message)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.charcoal)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                // Got it button
                Button {
                    dismiss()
                } label: {
                    Text("Got it")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(HeirloomColors.tomato)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                opacity = 1
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.2)) {
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

/// Coach mark with arrow pointing to specific UI element
struct CoachMarkWithArrow: View {
    let message: String
    let targetFrame: CGRect
    let arrowDirection: ArrowDirection
    let onDismiss: () -> Void
    @State private var opacity: Double = 0

    enum ArrowDirection {
        case up, down, left, right
    }

    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Spotlight on target
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: targetFrame.width + 40, height: targetFrame.height + 40)
                .position(x: targetFrame.midX, y: targetFrame.midY)
                .blur(radius: 20)

            // Coach mark card with arrow
            VStack(spacing: 0) {
                if arrowDirection == .down {
                    arrow
                }

                VStack(spacing: 20) {
                    Text(message)
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.charcoal)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)

                    Button {
                        dismiss()
                    } label: {
                        Text("Got it")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(HeirloomColors.tomato)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .background(.white)
                .cornerRadius(16)

                if arrowDirection == .up {
                    arrow
                }
            }
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
            .position(x: targetFrame.midX, y: coachMarkYPosition)
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                opacity = 1
            }
        }
    }

    private var arrow: some View {
        Triangle()
            .fill(.white)
            .frame(width: 20, height: 10)
            .rotationEffect(.degrees(arrowDirection == .down ? 0 : 180))
    }

    private var coachMarkYPosition: CGFloat {
        switch arrowDirection {
        case .up:
            return targetFrame.minY - 150
        case .down:
            return targetFrame.maxY + 150
        case .left, .right:
            return targetFrame.midY
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.2)) {
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

/// Triangle shape for arrow
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Previews

#Preview("Simple Coach Mark") {
    CoachMarkView(
        message: "Tap to view. Edit to make it yours, or share to pass it on.",
        onDismiss: {}
    )
}

#Preview("Coach Mark with Arrow") {
    CoachMarkWithArrow(
        message: "Add a recipe from anywhere",
        targetFrame: CGRect(x: 300, y: 100, width: 44, height: 44),
        arrowDirection: .down,
        onDismiss: {}
    )
}
