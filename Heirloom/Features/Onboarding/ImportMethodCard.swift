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

    @State private var isPressed = false

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
        .background(.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accentColor.opacity(0.15), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
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
