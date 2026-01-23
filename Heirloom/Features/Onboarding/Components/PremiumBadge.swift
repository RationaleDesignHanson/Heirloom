//
//  PremiumBadge.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-23.
//

import SwiftUI

/// Premium badge component for indicating premium/paid features
/// Used in onboarding to highlight visual extraction tier
struct PremiumBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("Premium")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                colors: [HeirloomColors.tomato, HeirloomColors.amber],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        PremiumBadge()

        // Show in context
        HStack {
            Text("Visual extraction")
                .font(HeirloomFonts.body)
            PremiumBadge()
        }
        .padding()
        .background(HeirloomColors.cream)
        .cornerRadius(12)
    }
    .padding()
}
