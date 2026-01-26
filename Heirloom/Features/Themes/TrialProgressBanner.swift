//
//  TrialProgressBanner.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import SwiftUI

struct TrialProgressBanner: View {
    @EnvironmentObject private var themeUnlockTracker: ThemeUnlockTracker

    private var daysRemaining: Int {
        themeUnlockTracker.daysRemaining
    }

    private var isTrialComplete: Bool {
        themeUnlockTracker.isTrialComplete
    }

    var body: some View {
        if !isTrialComplete {
            HStack(spacing: HeirloomSpacing.md) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(HeirloomColors.warmGray.opacity(0.2), lineWidth: 4)

                    Circle()
                        .trim(from: 0, to: CGFloat(themeUnlockTracker.currentTrialDay) / 14.0)
                        .stroke(HeirloomColors.tomato, style: StrokeStyle(
                            lineWidth: 4,
                            lineCap: .round
                        ))
                        .rotationEffect(.degrees(-90))

                    Text("\(themeUnlockTracker.currentTrialDay)")
                        .font(HeirloomFonts.caption1)
                        .fontWeight(.bold)
                        .foregroundStyle(HeirloomColors.primaryText)
                }
                .frame(width: 40, height: 40)

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(UXCopy.Unlock.dayProgress(themeUnlockTracker.currentTrialDay))
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text(bannerSubtitle)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HeirloomColors.warmGray)
            }
            .padding(HeirloomSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(HeirloomColors.cardBackground)
            )
        }
    }

    private var bannerSubtitle: String {
        if daysRemaining == 1 {
            return "Last day! Final recipes unlock tomorrow."
        } else if daysRemaining <= 3 {
            return "\(daysRemaining) days left in your discovery trial"
        } else {
            return "New recipes unlock every few days"
        }
    }
}
