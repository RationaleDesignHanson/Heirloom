//
//  ProfileStatCard.swift
//  Heirloom
//
//  Social Layer Phase 5: Reusable stat card for profile display
//  Shows icon, value, and label in a compact card format
//

import SwiftUI

struct ProfileStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: HeirloomSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(HeirloomColors.primaryText)

            Text(label)
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(HeirloomSpacing.sm)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
        .shadow(
            color: HeirloomShadows.card.color,
            radius: HeirloomShadows.card.radius,
            x: HeirloomShadows.card.x,
            y: HeirloomShadows.card.y
        )
    }
}

#Preview {
    HStack(spacing: HeirloomSpacing.md) {
        ProfileStatCard(
            icon: "person.2.fill",
            value: "24",
            label: "Connections",
            color: HeirloomColors.tomato
        )

        ProfileStatCard(
            icon: "doc.text.fill",
            value: "156",
            label: "Recipes",
            color: .blue
        )

        ProfileStatCard(
            icon: "arrow.triangle.2.circlepath",
            value: "43",
            label: "Shared",
            color: .green
        )
    }
    .padding()
    .background(HeirloomColors.appBackground)
}
