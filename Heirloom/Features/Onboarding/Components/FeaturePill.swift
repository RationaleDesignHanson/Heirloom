//
//  FeaturePill.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-23.
//

import SwiftUI

/// Compact feature pill for highlighting key app capabilities
/// Used in onboarding flexibility screen
struct FeaturePill: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(HeirloomColors.tomato)
                .frame(width: 32, height: 32)
                .background(HeirloomColors.tomato.opacity(0.1))
                .cornerRadius(8)

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.charcoal)

                Text(description)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
        .heirloomShadow(HeirloomShadows.subtle)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: HeirloomSpacing.md) {
        FeaturePill(
            icon: "arrow.triangle.branch",
            title: "Recipe Lineage",
            description: "Track recipe versions and edits"
        )

        FeaturePill(
            icon: "person.text.rectangle",
            title: "Creator Attribution",
            description: "Auto-credits original creators"
        )

        FeaturePill(
            icon: "calendar",
            title: "Meal Planning",
            description: "Plan weekly meals & dinner parties"
        )
    }
    .padding()
    .background(HeirloomColors.cream)
}
