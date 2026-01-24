//
//  ThreeTierExtractionView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-23.
//

import SwiftUI

/// Displays the 3-tier extraction cascade for video-to-recipe
/// Shows Listen (audio) → Read (OCR) → See (visual)
struct ThreeTierExtractionView: View {
    @State private var isAnimated = false

    var body: some View {
        HStack(spacing: HeirloomSpacing.sm) {
            // Tier 1: Audio
            extractionTier(
                icon: "waveform",
                label: "Listen",
                description: "Analyzes what they say",
                isPremium: false,
                delay: 0.0
            )

            // Tier 2: OCR
            extractionTier(
                icon: "doc.text.viewfinder",
                label: "Read",
                description: "Detects on-screen text",
                isPremium: false,
                delay: 0.1
            )

            // Tier 3: Visual
            extractionTier(
                icon: "eye.fill",
                label: "See",
                description: "Visual frame analysis",
                isPremium: false,
                delay: 0.2
            )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                isAnimated = true
            }
        }
    }

    @ViewBuilder
    private func extractionTier(
        icon: String,
        label: String,
        description: String,
        isPremium: Bool,
        delay: Double
    ) -> some View {
        VStack(spacing: HeirloomSpacing.xs) {
            // Icon
            ZStack {
                Circle()
                    .fill(HeirloomColors.tomato.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(HeirloomColors.tomato)
            }
            .scaleEffect(isAnimated ? 1.0 : 0.8)
            .opacity(isAnimated ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.3).delay(delay), value: isAnimated)

            // Label with Premium badge
            HStack(spacing: 4) {
                Text(label)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.charcoal)

                if isPremium {
                    PremiumBadge()
                }
            }

            // Description
            Text(description)
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        ThreeTierExtractionView()
            .padding()
            .background(HeirloomColors.cream)
            .cornerRadius(16)
    }
    .padding()
}
