//
//  AudioReactiveMicButton.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-10.
//

import SwiftUI

/// Compact mic button with concentric audio-reactive rings
struct AudioReactiveMicButton: View {
    enum MicState {
        case idle
        case recording
        case done
    }

    let state: MicState
    let audioLevel: CGFloat
    let isAvailable: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringPulseOpacity: CGFloat = 0.3

    private let buttonSize: CGFloat = 76

    var body: some View {
        VStack(spacing: 12) {
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                action()
            } label: {
                ZStack {
                    // Concentric rings (recording only)
                    if state == .recording {
                        ForEach(0..<3, id: \.self) { index in
                            ringView(index: index)
                        }
                    }

                    // Inner circle
                    Circle()
                        .fill(circleColor)
                        .frame(width: buttonSize, height: buttonSize)

                    // Icon
                    Image(systemName: iconName)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: buttonSize + 80, height: buttonSize + 80)
            }
            .disabled(!isAvailable && state == .idle)

            // Action hint
            Text(hintText)
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.warmGray)
        }
    }

    // MARK: - Ring View

    @ViewBuilder
    private func ringView(index: Int) -> some View {
        let baseRadius = buttonSize / 2 + 8 + CGFloat(index) * 14
        let baseOpacity: CGFloat = [0.4, 0.25, 0.12][index]
        let expansion: CGFloat = CGFloat(index + 1) * 6

        if reduceMotion {
            // Static rings with gentle opacity pulse
            Circle()
                .stroke(HeirloomColors.tomato, lineWidth: 2.5)
                .frame(
                    width: baseRadius * 2 + expansion * 0.5,
                    height: baseRadius * 2 + expansion * 0.5
                )
                .opacity(baseOpacity * ringPulseOpacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        ringPulseOpacity = 0.7
                    }
                }
        } else {
            // Audio-reactive rings
            let ringRadius = baseRadius + audioLevel * expansion
            Circle()
                .stroke(HeirloomColors.tomato, lineWidth: 2.5)
                .frame(width: ringRadius * 2, height: ringRadius * 2)
                .opacity(baseOpacity)
                .animation(.spring(response: 0.15, dampingFraction: 0.7), value: audioLevel)
        }
    }

    // MARK: - Computed Properties

    private var circleColor: Color {
        switch state {
        case .idle:
            return isAvailable ? HeirloomColors.warmGray : HeirloomColors.warmGray.opacity(0.5)
        case .recording:
            return HeirloomColors.tomato
        case .done:
            return HeirloomColors.familyGreen
        }
    }

    private var iconName: String {
        switch state {
        case .idle: return "mic.fill"
        case .recording: return "stop.fill"
        case .done: return "checkmark"
        }
    }

    private var hintText: String {
        switch state {
        case .idle: return "Tap to start recording"
        case .recording: return "Tap to stop"
        case .done: return "Tap Done to save"
        }
    }
}
