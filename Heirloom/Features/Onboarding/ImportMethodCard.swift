//
//  ImportMethodCard.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-10.
//

import SwiftUI

/// Card component for displaying recipe import methods in onboarding
struct ImportMethodCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
    var isEmphasized: Bool = false

    @State private var isPressed = false
    @State private var pulseAnimation = false

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Icon with background
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(accentColor)
                .frame(width: 48, height: 48)
                .background(accentColor.opacity(0.12))
                .cornerRadius(12)

            Spacer()

            // Title
            Text(title)
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            // Subtitle
            Text(subtitle)
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HeirloomSpacing.md)
        .frame(height: 150)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    accentColor.opacity(isEmphasized ? 0.5 : 0.15),
                    lineWidth: isEmphasized ? 2.5 : 1.5
                )
                .opacity(isEmphasized && pulseAnimation ? 0.7 : 1.0)
        )
        .shadow(color: .black.opacity(isEmphasized ? 0.12 : 0.06), radius: 8, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .onAppear {
            if isEmphasized {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: HeirloomSpacing.md) {
        ImportMethodCard(
            icon: "video.fill",
            title: "Video to recipe",
            subtitle: "Your favorite creators",
            accentColor: .purple
        )

        ImportMethodCard(
            icon: "camera.viewfinder",
            title: "Image scan",
            subtitle: "Cookbooks & family recipes",
            accentColor: .blue
        )
    }
    .padding()
    .background(HeirloomColors.cream)
}
